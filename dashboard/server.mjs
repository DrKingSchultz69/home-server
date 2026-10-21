// Homeserver dashboard backend: Node 24, no packages.
// Listens on 127.0.0.1 only; Tailscale Serve publishes it to the tailnet and
// tells us who is visiting (Tailscale-User-Login). Owner sees everything,
// other tailnet users see the family view, requests without an identity are refused.

import http from "node:http";
import { readFile, statfs } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { homedir, loadavg } from "node:os";
import { join } from "node:path";

const run = promisify(execFile);

const HOST = "127.0.0.1";
const PORT = Number(process.env.DASH_PORT ?? 8080);
const OWNER = (process.env.DASH_OWNER ?? "").toLowerCase();
const NETHERON_URL = process.env.DASH_NETHERON_URL ?? "";
const NETHERON_TOKEN_FILE = join(homedir(), ".mm", "token");
const NTFY_URL = process.env.DASH_NTFY_URL ?? ""; // e.g. http://127.0.0.1:2586/homeserver
const CHECK_EVERY_MS = 30_000;
const CHECK_TIMEOUT_MS = 3_000;
const STORAGE_EVERY_MS = 60 * 60_000;
const DISK_ALERT_PCT = 90;
const DISK_CLEAR_PCT = 85;

// ---- Services -------------------------------------------------------------
// `audience`: "owner" tiles are only shown to the owner, "family" tiles to everyone.
// `check` resolves to { up: boolean, detail: string }.

async function httpAnswers(url, okCodes) {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(CHECK_TIMEOUT_MS) });
    return { up: okCodes.includes(res.status), detail: `HTTP ${res.status}` };
  } catch (err) {
    return { up: false, detail: err.name === "TimeoutError" ? "no answer in 3 s" : "not answering" };
  }
}

async function commandSays(cmd, args, isUp, describe) {
  try {
    const { stdout } = await run(cmd, args, { timeout: CHECK_TIMEOUT_MS });
    return { up: isUp(stdout), detail: describe(stdout) };
  } catch (err) {
    // `systemctl is-active` exits non-zero when inactive; its stdout still says why.
    const out = err.stdout ?? "";
    return { up: false, detail: out.trim() || "check failed" };
  }
}

const SERVICES = [
  {
    id: "netheron",
    name: "Netheron",
    about: "Agent workspace",
    audience: "owner",
    link: "/go/netheron",
    check: async () => {
      const [proxy, ui] = await Promise.all([
        httpAnswers("http://127.0.0.1:4141/health", [200]),
        httpAnswers("http://127.0.0.1:4142/api/version", [200, 401]),
      ]);
      const up = proxy.up && ui.up;
      return { up, detail: up ? "Workspace and model proxy answering" : `Proxy: ${proxy.detail} · Workspace: ${ui.detail}` };
    },
  },
  {
    id: "tailscale",
    name: "Tailscale",
    about: "Private network",
    audience: "owner",
    check: () =>
      commandSays(
        "tailscale",
        ["status", "--json"],
        (out) => JSON.parse(out).BackendState === "Running",
        (out) => {
          const s = JSON.parse(out);
          const online = Object.values(s.Peer ?? {}).filter((p) => p.Online).length;
          return `${s.BackendState} · ${online} other device${online === 1 ? "" : "s"} online`;
        },
      ),
  },
  {
    id: "updates",
    name: "Security updates",
    about: "Daily automatic updates",
    audience: "owner",
    check: () =>
      commandSays(
        "systemctl",
        ["is-active", "dnf5-automatic.timer"],
        (out) => out.trim() === "active",
        (out) => (out.trim() === "active" ? "Daily timer active" : out.trim()),
      ),
  },
  {
    id: "files",
    name: "Files",
    about: "Browse, upload, download · also drive Z:",
    audience: "owner",
    link: process.env.DASH_FILES_URL || null,
    check: async () => {
      const [web, smb] = await Promise.all([
        httpAnswers("http://127.0.0.1:8091/health", [200]),
        commandSays("systemctl", ["is-active", "smb"], (out) => out.trim() === "active", (out) => out.trim()),
      ]);
      const up = web.up && smb.up;
      return { up, detail: up ? "File Browser and Z: drive answering" : `Browser: ${web.detail} · Z: drive: ${smb.detail}` };
    },
  },
  {
    id: "myfiles",
    name: "My files",
    about: "Upload and download your own files",
    audience: "family-only",
    link: process.env.DASH_FILES_URL || null,
    check: () => httpAnswers("http://127.0.0.1:8091/health", [200]),
  },
  {
    id: "streaming",
    name: "Streaming",
    about: "Family videos, movies, shows",
    audience: "family",
    link: process.env.DASH_STREAM_URL || null,
    check: async () => {
      const r = await httpAnswers("http://127.0.0.1:8095/health", [200]);
      return { up: r.up, detail: r.up ? "Library and player answering" : r.detail };
    },
  },
];

const status = new Map(); // id -> { up, detail, checkedAt }
const failures = new Map(); // id -> failed checks in a row
const DOWN_AFTER = 2; // a service is "down" only after this many failed checks in a row

// ---- Phone alerts (ntfy) ----------------------------------------------------
// One message per change: down, back up, disk over the limit. Never repeats.

async function alert(title, message, { priority = "default", tags = "" } = {}) {
  if (!NTFY_URL) return;
  try {
    await fetch(NTFY_URL, {
      method: "POST",
      body: message,
      headers: { Title: title, Priority: priority, Tags: tags },
      signal: AbortSignal.timeout(CHECK_TIMEOUT_MS),
    });
  } catch (err) {
    console.error(`alert not sent: ${title} (${err.message})`);
  }
}

async function checkAll() {
  await Promise.all(
    SERVICES.filter((s) => !s.planned).map(async (s) => {
      let result;
      try {
        result = await s.check();
      } catch {
        result = { up: false, detail: "check failed" };
      }
      // One slow or failed answer is not an outage (e.g. right after a restart, under the
      // CPU cap): keep the last state until DOWN_AFTER checks in a row have failed.
      const fails = result.up ? 0 : (failures.get(s.id) ?? 0) + 1;
      failures.set(s.id, fails);
      const before = status.get(s.id);
      if (!result.up && fails < DOWN_AFTER) {
        status.set(s.id, before ? { ...before, checkedAt: Date.now() } : { up: null, detail: "checking again", checkedAt: Date.now() });
        return;
      }
      status.set(s.id, { ...result, checkedAt: Date.now() });
      // No alert when there was no earlier known state (startup).
      if (before && before.up !== null && before.up !== result.up) {
        if (result.up) await alert(`${s.name} is back up`, result.detail, { tags: "white_check_mark" });
        else await alert(`${s.name} is down`, result.detail, { priority: "high", tags: "rotating_light" });
      }
    }),
  );
  await checkDisk();
}

let diskAlerted = false;
async function checkDisk() {
  const d = await disk();
  const pct = Math.round((100 * d.used) / d.total);
  if (!diskAlerted && pct >= DISK_ALERT_PCT) {
    diskAlerted = true;
    await alert(`Disk is ${pct}% full`, `${(d.used / 1024 ** 3).toFixed(0)} of ${(d.total / 1024 ** 3).toFixed(0)} GB used`, { priority: "high", tags: "floppy_disk" });
  } else if (diskAlerted && pct < DISK_CLEAR_PCT) {
    diskAlerted = false;
    await alert(`Disk back to ${pct}%`, "Below the warning level again.", { tags: "white_check_mark" });
  }
}

// ---- Alert history ----------------------------------------------------------
// ntfy keeps every alert for 30 days (cache-duration in ntfy/server.yml), so the
// dashboard reads its history from there instead of keeping a second copy.

let alertCache = { at: 0, items: [] };
async function recentAlerts() {
  if (!NTFY_URL) return [];
  if (Date.now() - alertCache.at < 30_000) return alertCache.items;
  try {
    const res = await fetch(`${NTFY_URL}/json?poll=1&since=720h`, { signal: AbortSignal.timeout(CHECK_TIMEOUT_MS) });
    const lines = (await res.text()).trim().split("\n").filter(Boolean);
    const items = lines
      .map((l) => JSON.parse(l))
      .filter((m) => m.event === "message")
      .map((m) => ({
        at: m.time * 1000,
        title: m.title || m.message,
        message: m.title ? m.message : "",
        kind: (m.tags ?? []).includes("white_check_mark") ? "ok" : (m.priority ?? 3) >= 4 ? "problem" : "info",
      }))
      .sort((a, b) => b.at - a.at)
      .slice(0, 10);
    alertCache = { at: Date.now(), items };
  } catch (err) {
    console.error(`alert history not read: ${err.message}`);
  }
  return alertCache.items;
}

// ---- What is stored ---------------------------------------------------------
// Once an hour, at the lowest CPU and disk priority, measure the biggest folders
// in the home folder. Everything else on the disk is shown as "System and apps".

let storage = null; // { items: [{ name, bytes }], measuredAt }

async function scanStorage() {
  const home = homedir();
  try {
    const { stdout } = await run("nice", ["-n", "19", "ionice", "-c3", "du", "-x", "-B1", "-d1", home], {
      timeout: 15 * 60_000,
      maxBuffer: 1024 * 1024,
    }).catch((err) => ({ stdout: err.stdout ?? "" })); // du exits 1 on unreadable folders but still reports the rest
    const rows = stdout
      .trim()
      .split("\n")
      .map((line) => {
        const [bytes, path] = line.split("\t");
        return { bytes: Number(bytes), path };
      })
      .filter((r) => r.path && Number.isFinite(r.bytes));
    const homeTotal = rows.find((r) => r.path === home)?.bytes ?? 0;
    const folders = rows.filter((r) => r.path !== home).sort((a, b) => b.bytes - a.bytes);
    const top = folders.slice(0, 8).map((r) => ({ name: "~/" + r.path.slice(home.length + 1), bytes: r.bytes }));
    const otherHome = homeTotal - top.reduce((a, r) => a + r.bytes, 0);
    if (otherHome > 0) top.push({ name: "Other home files", bytes: otherHome });
    const d = await disk();
    const system = d.used - homeTotal;
    if (system > 0) top.push({ name: "System and apps", bytes: system });
    storage = { items: top, measuredAt: Date.now() };
  } catch (err) {
    console.error(`storage scan failed: ${err.message}`);
  }
}

// ---- Resources ------------------------------------------------------------
// CPU % is measured between two reads of /proc/stat; the page asks every 5 s,
// so no background sampler is needed.

let lastCpu = null;

async function cpuPercent() {
  const line = (await readFile("/proc/stat", "utf8")).split("\n", 1)[0];
  const nums = line.trim().split(/\s+/).slice(1).map(Number);
  const idle = nums[3] + (nums[4] ?? 0);
  const total = nums.reduce((a, b) => a + b, 0);
  const prev = lastCpu;
  lastCpu = { idle, total };
  if (!prev || total === prev.total) return null;
  return Math.round(100 * (1 - (idle - prev.idle) / (total - prev.total)));
}

async function memory() {
  const info = await readFile("/proc/meminfo", "utf8");
  const kb = (key) => Number(info.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))?.[1] ?? 0) * 1024;
  const total = kb("MemTotal");
  const available = kb("MemAvailable");
  return { total, used: total - available };
}

async function disk() {
  const s = await statfs("/");
  const total = s.blocks * s.bsize;
  return { total, used: total - s.bavail * s.bsize };
}

async function uptimeSeconds() {
  return Math.floor(Number((await readFile("/proc/uptime", "utf8")).split(" ")[0]));
}

let resourceCache = null;
async function resources() {
  // Several open tabs share one reading per second.
  if (resourceCache && Date.now() - resourceCache.at < 1_000) return resourceCache.value;
  const [cpu, mem, dsk, up] = await Promise.all([cpuPercent(), memory(), disk(), uptimeSeconds()]);
  const value = { cpu, memory: mem, disk: dsk, load: loadavg()[0], uptime: up };
  resourceCache = { at: Date.now(), value };
  return value;
}

// ---- Who is visiting --------------------------------------------------------

function viewer(req) {
  const login = String(req.headers["tailscale-user-login"] ?? "").toLowerCase();
  if (!login) return null;
  const name = String(req.headers["tailscale-user-name"] ?? "") || login.split("@")[0];
  return { role: OWNER && login === OWNER ? "owner" : "family", name };
}

// ---- HTTP -------------------------------------------------------------------

const SECURITY_HEADERS = {
  "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; frame-ancestors 'none'",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
  "Cache-Control": "no-store",
};

function send(res, code, body, type = "text/plain; charset=utf-8", extra = {}) {
  res.writeHead(code, { "Content-Type": type, ...SECURITY_HEADERS, ...extra });
  res.end(body);
}

let pageHtml = null;
async function page() {
  pageHtml ??= await readFile(new URL("./public/index.html", import.meta.url), "utf8");
  return pageHtml;
}
let accessHtml = null;
async function accessPage() {
  accessHtml ??= await readFile(new URL("./public/access.html", import.meta.url), "utf8");
  return accessHtml;
}

// ---- Access list (owner only, read-only) --------------------------------------
// Reads the tailnet's people and devices with a READ-ONLY Tailscale OAuth client.
// Approving and removing stay in the Tailscale admin console.

const TS_OAUTH_FILE = process.env.DASH_TS_OAUTH ?? join(homedir(), ".config", "homeserver", "tailscale-oauth.json");
let tsToken = { value: null, until: 0 };
let accessCache = { at: 0, value: null };

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
  const res = await fetch(`https://api.tailscale.com/api/v2${path}`, { headers: { Authorization: `Bearer ${tsToken.value}` }, signal: AbortSignal.timeout(10_000) });
  if (!res.ok) throw new Error(`Tailscale API ${path} answered HTTP ${res.status}`);
  return res.json();
}

async function accessList() {
  if (accessCache.value && Date.now() - accessCache.at < 60_000) return accessCache.value;
  let value;
  try {
    const [d, u] = await Promise.all([tsApi("/tailnet/-/devices?fields=all"), tsApi("/tailnet/-/users")]);
    const users = new Map((u.users ?? []).map((x) => [x.id, x]));
    const devices = (d.devices ?? []).map((x) => ({
      name: x.hostname || x.name,
      os: x.os,
      user: x.user,
      authorized: x.authorized,
      lastSeen: x.lastSeen,
      online: x.connectedToControl ?? null,
    }));
    const people = [...users.values()].map((x) => ({
      name: x.displayName || x.loginName,
      login: x.loginName,
      role: x.role,
      status: x.status,
      lastSeen: x.lastSeen,
      devices: devices.filter((dv) => dv.user === x.loginName),
    }));
    value = {
      configured: true,
      waiting: devices.filter((dv) => dv.authorized === false),
      people: people.sort((a, b) => (a.role === "owner" ? -1 : b.role === "owner" ? 1 : a.name.localeCompare(b.name))),
      checkedAt: Date.now(),
    };
  } catch (err) {
    value = { configured: err.code !== "ENOENT", error: err.code === "ENOENT" ? "No read-only Tailscale key on the server yet." : err.message, waiting: [], people: [], checkedAt: Date.now() };
  }
  accessCache = { at: Date.now(), value };
  return value;
}

const server = http.createServer(async (req, res) => {
  try {
    const who = viewer(req);
    if (!who) return send(res, 403, "Open this page through Tailscale.");
    const path = new URL(req.url ?? "/", "http://x").pathname;

    if (req.method !== "GET") return send(res, 405, "Method not allowed");

    if (path === "/") return send(res, 200, await page(), "text/html; charset=utf-8");

    if (path === "/access") {
      if (who.role !== "owner") return send(res, 403, "Not available.");
      return send(res, 200, await accessPage(), "text/html; charset=utf-8");
    }
    if (path === "/api/access") {
      if (who.role !== "owner") return send(res, 403, "Not available.");
      return send(res, 200, JSON.stringify(await accessList()), "application/json");
    }

    if (path === "/api/status") {
      const shown = (s) => (who.role === "owner" ? s.audience !== "family-only" : s.audience === "family" || s.audience === "family-only");
      const tiles = SERVICES.filter(shown).map((s) => ({
        id: s.id,
        name: s.name,
        about: s.about,
        link: s.link ?? null,
        planned: Boolean(s.planned),
        ...(s.planned ? {} : status.get(s.id) ?? { up: null, detail: "first check pending", checkedAt: null }),
      }));
      const body = { viewer: who, services: tiles, now: Date.now() };
      if (who.role === "owner") {
        body.resources = await resources();
        body.storage = storage;
        body.alerts = await recentAlerts();
      }
      return send(res, 200, JSON.stringify(body), "application/json");
    }

    if (path === "/go/netheron") {
      if (who.role !== "owner" || !NETHERON_URL) return send(res, 403, "Not available.");
      const token = (await readFile(NETHERON_TOKEN_FILE, "utf8")).trim();
      // Netheron's own login cookie. Cookies are shared across ports of the same
      // host name, so Netheron on :8443 receives it. Only the owner ever gets it.
      const cookie = `mm_token=${encodeURIComponent(token)}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=31536000`;
      return send(res, 302, "", "text/plain", { Location: NETHERON_URL, "Set-Cookie": cookie });
    }

    if (path === "/health") return send(res, 200, "ok");

    return send(res, 404, "Not found");
  } catch (err) {
    console.error(err);
    return send(res, 500, "Something went wrong on the server.");
  }
});

if (!OWNER) console.warn("DASH_OWNER is not set: everyone gets the family view.");
if (!NTFY_URL) console.warn("DASH_NTFY_URL is not set: no phone alerts.");
server.listen(PORT, HOST, () => console.log(`dashboard on http://${HOST}:${PORT}`));
await checkAll();
setInterval(checkAll, CHECK_EVERY_MS).unref();
// First storage scan a minute after start, so a reboot isn't slowed down.
setTimeout(() => {
  scanStorage();
  setInterval(scanStorage, STORAGE_EVERY_MS).unref();
}, 60_000).unref();
