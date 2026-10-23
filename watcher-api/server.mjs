// Watcher API: the backend for the Watcher app. Node 24, no packages.
// Listens on 127.0.0.1 only; Tailscale Serve publishes it to the tailnet on :8447 and
// tells us who is asking (Tailscale-User-Login). Requests without an identity are refused.
//
// Roles: admin (owner + anyone listed as admin), family, user (default for everyone else).
// History: one sample a minute in SQLite, rolled up to 5-minute and hourly averages,
// kept 24 h / 7 d / 30 d. Restart works only for the named services in RESTARTABLE.

import http from "node:http";
import { DatabaseSync } from "node:sqlite";
import { readFile, readdir, statfs, mkdir } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { homedir } from "node:os";
import { join, dirname } from "node:path";

const run = promisify(execFile);

const HOST = "127.0.0.1";
const PORT = Number(process.env.WATCH_PORT ?? 8090);
const OWNER = (process.env.WATCH_OWNER ?? "").toLowerCase();
const CONFIG_DIR = process.env.WATCH_CONFIG_DIR ?? join(homedir(), ".config", "homeserver");
const ROLES_FILE = join(CONFIG_DIR, "watcher-roles.json"); // { "login": "admin" | "family" | "user" }
const TS_OAUTH_FILE = join(CONFIG_DIR, "tailscale-oauth.json"); // read-only key, shared with the dashboard
const DB_FILE = process.env.WATCH_DB ?? join(homedir(), ".local", "share", "watcher", "watcher.db");
const DRY_RUN = process.env.WATCH_DRY_RUN === "1"; // tests: log restart/reboot commands instead of running them

const CHECK_EVERY_MS = 30_000;
const CHECK_TIMEOUT_MS = 3_000;
const SAMPLE_EVERY_MS = 60_000;
const DOWN_AFTER = 2; // failed checks in a row before a service counts as down
const OFFLINE_GAP_MS = 3 * 60_000; // no sample for this long = the server was off
const LIMITS = { disk: [90, 85], memory: [90, 80], temp: [85, 75] }; // [alert at, clear below]

// ---- Services ---------------------------------------------------------------
// `roles`: who sees the service in the app. Admin sees everything.

async function httpAnswers(url, okCodes = [200]) {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(CHECK_TIMEOUT_MS) });
    return { up: okCodes.includes(res.status), detail: `HTTP ${res.status}` };
  } catch (err) {
    return { up: false, detail: err.name === "TimeoutError" ? "no answer in 3 s" : "not answering" };
  }
}

async function unitActive(unit, user = false) {
  try {
    const { stdout } = await run("systemctl", [...(user ? ["--user"] : []), "is-active", unit], { timeout: CHECK_TIMEOUT_MS });
    return { up: stdout.trim() === "active", detail: stdout.trim() };
  } catch (err) {
    return { up: false, detail: (err.stdout ?? "").trim() || "check failed" };
  }
}

const both = (a, b, okText) => ({ up: a.up && b.up, detail: a.up && b.up ? okText : [a, b].filter((x) => !x.up).map((x) => x.detail).join(" · ") });

const SERVICES = [
  { id: "streaming", name: "Streaming", about: "Videos, movies, shows", roles: ["user", "family"], check: () => httpAnswers("http://127.0.0.1:8095/health") },
  {
    id: "files",
    name: "Files",
    about: "Upload, download, share",
    roles: ["family"],
    check: async () => both(await httpAnswers("http://127.0.0.1:8091/health"), await unitActive("smb"), "File Browser and Z: drive answering"),
  },
  {
    id: "netheron",
    name: "Netheron",
    about: "Agent workspace",
    check: async () => both(await httpAnswers("http://127.0.0.1:4141/health"), await httpAnswers("http://127.0.0.1:4142/api/version", [200, 401]), "Workspace and model proxy answering"),
  },
  // The dashboard refuses callers without a Tailscale identity (403), which still proves it answers.
  { id: "dashboard", name: "Dashboard", about: "Web dashboard", check: () => httpAnswers("http://127.0.0.1:8080/health", [200, 403]) },
  { id: "join-requests", name: "Join requests", about: "Public request page", check: () => httpAnswers("http://127.0.0.1:8097/request") },
  { id: "ntfy", name: "ntfy", about: "Old phone alerts", check: () => httpAnswers("http://127.0.0.1:2586/v1/health") },
  { id: "ssh", name: "SSH", about: "Remote terminal", check: () => unitActive("sshd") },
  {
    id: "tailscale",
    name: "Tailscale",
    about: "Private network",
    check: async () => {
      try {
        const { stdout } = await run("tailscale", ["status", "--json"], { timeout: CHECK_TIMEOUT_MS });
        const s = JSON.parse(stdout);
        return { up: s.BackendState === "Running", detail: s.BackendState };
      } catch {
        return { up: false, detail: "check failed" };
      }
    },
  },
];

// Restart allowlist: app name -> systemd unit. Tailscale is left out on purpose (owner's choice):
// restarting it would cut the app's own connection.
const RESTARTABLE = {
  netheron: { unit: "netheron.service", user: true },
  dashboard: { unit: "dashboard.service", user: true },
  ntfy: { unit: "ntfy.service", user: true },
  filebrowser: { unit: "filebrowser.service", user: true },
  "files-gate": { unit: "files-gate.service", user: true },
  "watcher-api": { unit: "watcher-api.service", user: true },
  streaming: { unit: "streaming.service", user: false },
  smb: { unit: "smb.service", user: false },
  sshd: { unit: "sshd.service", user: false },
  "join-requests": { unit: "join-requests.service", user: false },
};
// Which units' logs belong to an app service id (logs endpoint).
const LOG_UNITS = {
  streaming: ["streaming.service"],
  files: ["filebrowser.service", "files-gate.service", "smb.service"],
  netheron: ["netheron.service"],
  dashboard: ["dashboard.service"],
  "join-requests": ["join-requests.service"],
  ntfy: ["ntfy.service"],
  ssh: ["sshd.service"],
  tailscale: ["tailscaled.service"],
  "watcher-api": ["watcher-api.service"],
};
// Restart buttons per status entry (a service can be several units).
const RESTART_FOR = { files: ["filebrowser", "files-gate", "smb"], ssh: ["sshd"] };
const restartTargets = (id) => RESTART_FOR[id] ?? (RESTARTABLE[id] ? [id] : []);
const USER_UNITS = new Set(Object.values(RESTARTABLE).filter((r) => r.user).map((r) => r.unit));

// ---- Storage (SQLite) -------------------------------------------------------

await mkdir(dirname(DB_FILE), { recursive: true });
const db = new DatabaseSync(DB_FILE);
db.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE IF NOT EXISTS samples (
    res INTEGER NOT NULL,          -- seconds per sample: 60, 300 or 3600
    ts INTEGER NOT NULL,           -- bucket start, unix seconds
    cpu REAL, mem REAL, disk REAL, temp REAL,  -- percent, percent, percent, °C
    PRIMARY KEY (res, ts)
  ) WITHOUT ROWID;
  CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    at INTEGER NOT NULL,           -- unix ms
    kind TEXT NOT NULL,            -- down | up | warning | clear | offline
    service TEXT,                  -- service id, or NULL for the whole server
    title TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT '',
    outage INTEGER NOT NULL DEFAULT 0  -- 1 = breaks quiet hours
  );
  CREATE INDEX IF NOT EXISTS events_at ON events (at);
`);

const insertSample = db.prepare("INSERT OR REPLACE INTO samples (res, ts, cpu, mem, disk, temp) VALUES (?, ?, ?, ?, ?, ?)");
const insertEvent = db.prepare("INSERT INTO events (at, kind, service, title, detail, outage) VALUES (?, ?, ?, ?, ?, ?)");

function addEvent(kind, service, title, detail = "", outage = false) {
  insertEvent.run(Date.now(), kind, service, title, detail, outage ? 1 : 0);
}

// Average the finished buckets of the finer resolution into the coarser one, then drop old rows.
function rollUp() {
  const now = Math.floor(Date.now() / 1000);
  for (const [from, to] of [[60, 300], [300, 3600]]) {
    const done = Math.floor(now / to) * to; // only buckets that have ended
    db.prepare(
      `INSERT OR REPLACE INTO samples (res, ts, cpu, mem, disk, temp)
       SELECT ?, (ts / ?) * ?, AVG(cpu), AVG(mem), AVG(disk), AVG(temp) FROM samples
       WHERE res = ? AND ts >= ? AND ts < ? GROUP BY ts / ?`,
    ).run(to, to, to, from, done - 2 * to, done, to);
  }
  const keep = { 60: 24 * 3600, 300: 7 * 24 * 3600, 3600: 30 * 24 * 3600 };
  for (const [res, secs] of Object.entries(keep)) db.prepare("DELETE FROM samples WHERE res = ? AND ts < ?").run(Number(res), now - secs);
  db.prepare("DELETE FROM events WHERE at < ?").run(Date.now() - 30 * 24 * 3600_000);
}

// ---- Resources --------------------------------------------------------------

let lastCpu = null;
async function cpuPercent() {
  const nums = (await readFile("/proc/stat", "utf8")).split("\n", 1)[0].trim().split(/\s+/).slice(1).map(Number);
  const idle = nums[3] + (nums[4] ?? 0);
  const total = nums.reduce((a, b) => a + b, 0);
  const prev = lastCpu;
  lastCpu = { idle, total };
  if (!prev || total === prev.total) return null;
  return Math.round(1000 * (1 - (idle - prev.idle) / (total - prev.total))) / 10;
}

async function memory() {
  const info = await readFile("/proc/meminfo", "utf8");
  const kb = (key) => Number(info.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))?.[1] ?? 0) * 1024;
  const total = kb("MemTotal");
  return { total, used: total - kb("MemAvailable") };
}

async function disk() {
  const s = await statfs("/");
  const total = s.blocks * s.bsize;
  return { total, used: total - s.bavail * s.bsize };
}

// CPU package temperature from the coretemp sensor (°C), or null if there isn't one.
let tempPath;
async function temperature() {
  if (tempPath === undefined) {
    tempPath = null;
    try {
      for (const h of await readdir("/sys/class/hwmon")) {
        const name = (await readFile(`/sys/class/hwmon/${h}/name`, "utf8")).trim();
        if (name === "coretemp") tempPath = `/sys/class/hwmon/${h}/temp1_input`;
      }
    } catch {}
  }
  if (!tempPath) return null;
  try {
    return Number(await readFile(tempPath, "utf8")) / 1000;
  } catch {
    return null;
  }
}

async function uptimeSeconds() {
  return Math.floor(Number((await readFile("/proc/uptime", "utf8")).split(" ")[0]));
}

const pct = (x) => Math.round((1000 * x.used) / x.total) / 10;

const raised = { disk: false, memory: false, temp: false };
function threshold(key, value, title, unit) {
  if (value == null) return;
  const [at, clear] = LIMITS[key];
  if (!raised[key] && value >= at) {
    raised[key] = true;
    addEvent("warning", null, `${title} at ${Math.round(value)}${unit}`, `Above the ${at}${unit} warning level.`);
  } else if (raised[key] && value < clear) {
    raised[key] = false;
    addEvent("clear", null, `${title} back to ${Math.round(value)}${unit}`, "Below the warning level again.");
  }
}

async function sample() {
  const [cpu, mem, dsk, temp] = await Promise.all([cpuPercent(), memory(), disk(), temperature()]);
  const ts = Math.floor(Date.now() / 60_000) * 60;
  insertSample.run(60, ts, cpu, pct(mem), pct(dsk), temp);
  threshold("disk", pct(dsk), "Disk", "%");
  threshold("memory", pct(mem), "Memory", "%");
  threshold("temp", temp, "CPU temperature", "°C");
  rollUp();
}

// ---- Service checks -----------------------------------------------------------

const status = new Map(); // id -> { up, detail, checkedAt }
const failures = new Map();

async function checkAll() {
  await Promise.all(
    SERVICES.map(async (s) => {
      let r;
      try {
        r = await s.check();
      } catch {
        r = { up: false, detail: "check failed" };
      }
      const fails = r.up ? 0 : (failures.get(s.id) ?? 0) + 1;
      failures.set(s.id, fails);
      const before = status.get(s.id);
      if (!r.up && fails < DOWN_AFTER) {
        status.set(s.id, before ? { ...before, checkedAt: Date.now() } : { up: null, detail: "checking again", checkedAt: Date.now() });
        return;
      }
      status.set(s.id, { ...r, checkedAt: Date.now() });
      if (before && before.up !== null && before.up !== r.up) {
        if (r.up) addEvent("up", s.id, `${s.name} is back up`, r.detail);
        else addEvent("down", s.id, `${s.name} is down`, r.detail, true);
      }
    }),
  );
}

// At start: if the last sample is old, the server was off (power cut, crash, shutdown).
function noteOfflineGap() {
  const last = db.prepare("SELECT MAX(ts) AS ts FROM samples WHERE res = 60").get()?.ts;
  if (!last) return;
  const gap = Date.now() - last * 1000;
  if (gap > OFFLINE_GAP_MS) {
    const mins = Math.round(gap / 60_000);
    const span = mins >= 120 ? `${Math.round(mins / 60)} h` : `${mins} min`;
    addEvent("offline", null, "Server was offline", `No contact for about ${span}. It's back now.`, true);
  }
}

// ---- Who is asking --------------------------------------------------------------

async function roles() {
  try {
    return JSON.parse(await readFile(ROLES_FILE, "utf8"));
  } catch {
    return {};
  }
}

async function viewer(req) {
  const login = String(req.headers["tailscale-user-login"] ?? "").toLowerCase();
  if (!login) return null;
  const name = String(req.headers["tailscale-user-name"] ?? "") || login.split("@")[0];
  const listed = (await roles())[login];
  const role = OWNER && login === OWNER ? "admin" : ["admin", "family", "user"].includes(listed) ? listed : "user";
  return { login, name, role };
}

const canSee = (who, s) => who.role === "admin" || (s.roles ?? []).includes(who.role);

// ---- Tailscale (people and devices) ------------------------------------------------

let tsToken = { value: null, until: 0 };
async function tsApi(path) {
  if (!tsToken.value || Date.now() > tsToken.until) {
    const creds = JSON.parse(await readFile(TS_OAUTH_FILE, "utf8"));
    const res = await fetch("https://api.tailscale.com/api/v2/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ client_id: creds.client_id, client_secret: creds.client_secret, grant_type: "client_credentials" }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`Tailscale sign-in failed (HTTP ${res.status})`);
    const t = await res.json();
    tsToken = { value: t.access_token, until: Date.now() + Math.max(60, (t.expires_in ?? 3600) - 120) * 1000 };
  }
  const res = await fetch(`https://api.tailscale.com/api/v2${path}`, {
    headers: { Authorization: `Bearer ${tsToken.value}` },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`Tailscale API answered HTTP ${res.status}`);
  return res.json();
}

let peopleCache = { at: 0, value: null };
async function people() {
  if (peopleCache.value && Date.now() - peopleCache.at < 60_000) return peopleCache.value;
  const map = await roles();
  let value;
  try {
    const devices = ((await tsApi("/tailnet/-/devices?fields=all")).devices ?? []).map((d) => ({
      name: d.hostname || d.name,
      os: d.os,
      user: d.user,
      lastSeen: d.lastSeen,
      online: d.connectedToControl ?? null,
      authorized: d.authorized,
    }));
    const logins = [...new Set(devices.map((d) => d.user).filter(Boolean))];
    const list = logins.map((login) => {
      const own = devices.filter((d) => d.user === login);
      const seen = own.map((d) => d.lastSeen).filter(Boolean).sort().at(-1) ?? null;
      const role = login.toLowerCase() === OWNER ? "admin" : map[login.toLowerCase()] ?? "user";
      return { login, name: login.split("@")[0], role, online: own.some((d) => d.online), lastSeen: seen, devices: own };
    });
    value = { people: list.sort((a, b) => (a.role === "admin") === (b.role === "admin") ? a.login.localeCompare(b.login) : a.role === "admin" ? -1 : 1), error: null };
  } catch (err) {
    value = { people: [], error: err.code === "ENOENT" ? "No read-only Tailscale key on the server yet." : err.message };
  }
  peopleCache = { at: Date.now(), value };
  return value;
}

// ---- Actions --------------------------------------------------------------------

async function command(cmd, args) {
  if (DRY_RUN) {
    console.log(`[dry run] ${cmd} ${args.join(" ")}`);
    return;
  }
  await run(cmd, args, { timeout: 30_000 });
}

function restartArgs(name) {
  const r = RESTARTABLE[name];
  return r.user ? ["systemctl", ["--user", "restart", r.unit]] : ["sudo", ["-n", "/usr/bin/systemctl", "restart", r.unit]];
}

async function logs(id) {
  const units = LOG_UNITS[id];
  const args = ["--no-pager", "-o", "short-iso", "-n", "200"];
  for (const u of units) args.push(USER_UNITS.has(u) ? "--user-unit" : "-u", u);
  try {
    const { stdout } = await run("journalctl", args, { timeout: 10_000, maxBuffer: 2 * 1024 * 1024 });
    return stdout
      .split("\n")
      .filter((l) => l && !l.startsWith("-- "))
      .map((l) => {
        const m = l.match(/^(\S+)\s+\S+\s+([^:]+):\s?(.*)$/);
        return m ? { at: m[1], source: m[2], message: m[3] } : { at: null, source: "", message: l };
      });
  } catch (err) {
    return [{ at: null, source: "watcher-api", message: `Couldn't read logs: ${err.message}` }];
  }
}

const RANGES = {
  "24h": { res: 60, step: 300, secs: 24 * 3600 },
  "7d": { res: 300, step: 1800, secs: 7 * 24 * 3600 },
  "30d": { res: 3600, step: 7200, secs: 30 * 24 * 3600 },
};

function history(range) {
  const r = RANGES[range];
  const since = Math.floor(Date.now() / 1000) - r.secs;
  const rows = db
    .prepare(
      `SELECT (ts / ?) * ? AS t, AVG(cpu) AS cpu, AVG(mem) AS mem, AVG(disk) AS disk, AVG(temp) AS temp
       FROM samples WHERE res = ? AND ts >= ? GROUP BY ts / ? ORDER BY t`,
    )
    .all(r.step, r.step, r.res, since, r.step);
  const round = (v) => (v == null ? null : Math.round(v * 10) / 10);
  return rows.map((x) => ({ t: x.t * 1000, cpu: round(x.cpu), mem: round(x.mem), disk: round(x.disk), temp: round(x.temp) }));
}

async function current() {
  const [mem, dsk, temp, up] = await Promise.all([memory(), disk(), temperature(), uptimeSeconds()]);
  const last = db.prepare("SELECT cpu FROM samples WHERE res = 60 ORDER BY ts DESC LIMIT 1").get();
  return { cpu: last?.cpu ?? null, memory: mem, disk: dsk, temp, uptime: up };
}

async function appVersion() {
  try {
    return JSON.parse(await readFile(new URL("./app-version.json", import.meta.url), "utf8"));
  } catch {
    return { latest: null };
  }
}

// ---- HTTP -----------------------------------------------------------------------

function send(res, code, body) {
  const json = typeof body === "string" ? JSON.stringify({ error: body }) : JSON.stringify(body);
  res.writeHead(code, {
    "Content-Type": "application/json; charset=utf-8",
    "X-Content-Type-Options": "nosniff",
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
  });
  res.end(json);
}

// Identity is per connection, so a web page elsewhere could make an admin's browser send a POST.
// The app always sends X-Watcher: 1; a browser can't add that header cross-site without a CORS
// preflight, and this server never answers one.
const fromApp = (req) => req.headers["x-watcher"] === "1";

function readJson(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (c) => {
      data += c;
      if (data.length > 1024) req.destroy();
    });
    req.on("end", () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const who = await viewer(req);
    if (!who) return send(res, 403, "Open Watcher through Tailscale.");
    const url = new URL(req.url ?? "/", "http://x");
    const path = url.pathname;
    const admin = who.role === "admin";

    if (req.method === "POST") {
      if (!fromApp(req)) return send(res, 403, "Not available.");
      if (!admin) return send(res, 403, "Only admins can do that.");
      const restart = path.match(/^\/api\/services\/([a-z-]+)\/restart$/);
      if (restart) {
        const name = restart[1];
        if (!RESTARTABLE[name]) return send(res, 404, "That service can't be restarted from Watcher.");
        addEvent("warning", name, `Restart of ${name} requested`, `By ${who.name}.`);
        const [cmd, args] = restartArgs(name);
        // Restarting ourselves: answer first, the restart kills this process.
        if (name === "watcher-api") {
          send(res, 202, { ok: true, restarting: name });
          setTimeout(() => command(cmd, args).catch((e) => console.error(e.message)), 500);
          return;
        }
        try {
          await command(cmd, args);
        } catch (err) {
          return send(res, 502, `Restart failed: ${(err.stderr || err.message).trim().slice(0, 200)}`);
        }
        return send(res, 200, { ok: true, restarted: name });
      }
      if (path === "/api/server/reboot") {
        const body = await readJson(req).catch(() => ({}));
        if (body.confirm !== "reboot") return send(res, 400, 'Send {"confirm":"reboot"} to restart the server.');
        addEvent("warning", null, "Server restart requested", `By ${who.name}.`);
        send(res, 202, { ok: true, rebooting: true });
        setTimeout(() => command("sudo", ["-n", "/usr/bin/systemctl", "reboot"]).catch((e) => console.error(e.message)), 1_000);
        return;
      }
      return send(res, 404, "Not found");
    }

    if (req.method !== "GET") return send(res, 405, "Method not allowed");

    if (path === "/health") return send(res, 200, { ok: true });

    if (path === "/api/me") {
      const services = SERVICES.filter((s) => canSee(who, s)).map((s) => s.id);
      return send(res, 200, { ...who, services });
    }

    if (path === "/api/status") {
      const services = SERVICES.filter((s) => canSee(who, s)).map((s) => ({
        id: s.id,
        name: s.name,
        about: s.about,
        restart: admin ? restartTargets(s.id) : [],
        ...(status.get(s.id) ?? { up: null, detail: "first check pending", checkedAt: null }),
      }));
      const body = { services, now: Date.now() };
      if (admin) body.server = await current();
      return send(res, 200, body);
    }

    if (path === "/api/alerts") {
      const since = Number(url.searchParams.get("since") ?? 0) || Date.now() - 24 * 3600_000;
      const rows = db.prepare("SELECT * FROM events WHERE at > ? ORDER BY at DESC LIMIT 200").all(since);
      const visible = new Set(SERVICES.filter((s) => canSee(who, s)).map((s) => s.id));
      // Non-admins hear about their own services and about the whole server being offline.
      const items = rows
        .filter((e) => admin || (e.service ? visible.has(e.service) : e.kind === "offline" && e.outage))
        .map((e) => ({ id: e.id, at: e.at, kind: e.kind, service: e.service, title: e.title, detail: e.detail, outage: Boolean(e.outage) }));
      return send(res, 200, { alerts: items, now: Date.now() });
    }

    if (path === "/api/version") return send(res, 200, await appVersion());

    if (!admin && path.startsWith("/api/")) return send(res, 403, "Only admins can see that.");

    if (path === "/api/stats") {
      const range = url.searchParams.get("range") ?? "24h";
      if (!RANGES[range]) return send(res, 400, "range must be 24h, 7d or 30d");
      return send(res, 200, { range, points: history(range), now: await current() });
    }

    const logMatch = path.match(/^\/api\/services\/([a-z-]+)\/logs$/);
    if (logMatch) {
      if (!LOG_UNITS[logMatch[1]]) return send(res, 404, "Unknown service.");
      return send(res, 200, { service: logMatch[1], lines: await logs(logMatch[1]) });
    }

    if (path === "/api/people") return send(res, 200, await people());

    return send(res, 404, "Not found");
  } catch (err) {
    console.error(err);
    return send(res, 500, "Something went wrong on the server.");
  }
});

if (!OWNER) console.warn("WATCH_OWNER is not set: nobody is admin unless listed in watcher-roles.json.");
noteOfflineGap();
await cpuPercent(); // first reading; CPU % needs two
server.listen(PORT, HOST, () => console.log(`watcher-api on http://${HOST}:${PORT}${DRY_RUN ? " (dry run)" : ""}`));
await checkAll();
await sample();
setInterval(checkAll, CHECK_EVERY_MS).unref();
setInterval(() => sample().catch((e) => console.error(`sample failed: ${e.message}`)), SAMPLE_EVERY_MS).unref();
