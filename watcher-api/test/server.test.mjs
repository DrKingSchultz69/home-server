// Run on the server: node --test test/   (Linux only: reads /proc and systemd)
// Starts its own copy on a spare port with a temporary database and dry-run restarts.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";

const PORT = 18090;
let dir, proc, output = "";

const call = (path, login, { method = "GET", body, app = true } = {}) =>
  fetch(`http://127.0.0.1:${PORT}${path}`, {
    method,
    headers: { ...(login ? { "Tailscale-User-Login": login } : {}), ...(app ? { "X-Watcher": "1" } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });

before(async () => {
  dir = await mkdtemp(join(tmpdir(), "watcher-test-"));
  await writeFile(join(dir, "watcher-roles.json"), JSON.stringify({ "fam@x": "family", "second@x": "admin" }));
  // An old sample: the server "was off" for an hour before this start.
  const db = new DatabaseSync(join(dir, "t.db"));
  db.exec("CREATE TABLE samples (res INTEGER NOT NULL, ts INTEGER NOT NULL, cpu REAL, mem REAL, disk REAL, temp REAL, PRIMARY KEY (res, ts)) WITHOUT ROWID");
  db.prepare("INSERT INTO samples VALUES (60, ?, 5, 50, 40, 40)").run(Math.floor(Date.now() / 1000) - 3600);
  db.close();
  proc = spawn(process.execPath, ["--disable-warning=ExperimentalWarning", "server.mjs"], {
    env: { ...process.env, WATCH_PORT: String(PORT), WATCH_OWNER: "owner@x", WATCH_CONFIG_DIR: dir, WATCH_DB: join(dir, "t.db"), WATCH_DRY_RUN: "1" },
  });
  proc.stdout.on("data", (d) => (output += d));
  proc.stderr.on("data", (d) => (output += d));
  for (let i = 0; i < 50; i++) {
    try {
      if ((await call("/health", "owner@x")).ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error(`server did not start:\n${output}`);
});

after(async () => {
  proc?.kill();
  await rm(dir, { recursive: true, force: true });
});

test("no Tailscale identity is refused", async () => {
  assert.equal((await call("/api/me", null)).status, 403);
});

test("roles: owner and listed admins are admin, listed family is family, everyone else user", async () => {
  assert.equal((await (await call("/api/me", "owner@x")).json()).role, "admin");
  assert.equal((await (await call("/api/me", "second@x")).json()).role, "admin");
  const fam = await (await call("/api/me", "fam@x")).json();
  assert.equal(fam.role, "family");
  assert.deepEqual(fam.services, ["streaming", "files"]);
  const usr = await (await call("/api/me", "new@x")).json();
  assert.equal(usr.role, "user");
  assert.deepEqual(usr.services, ["streaming"]);
});

test("status: users see only their services and no server numbers", async () => {
  const u = await (await call("/api/status", "new@x")).json();
  assert.deepEqual(u.services.map((s) => s.id), ["streaming"]);
  assert.equal(u.server, undefined);
  assert.deepEqual(u.services[0].restart, []);
  const a = await (await call("/api/status", "owner@x")).json();
  assert.ok(a.services.length >= 8);
  assert.ok(a.server.memory.total > 0);
  assert.deepEqual(a.services.find((s) => s.id === "files").restart, ["filebrowser", "files-gate", "smb"]);
  assert.deepEqual(a.services.find((s) => s.id === "tailscale").restart, []);
});

test("admin-only endpoints refuse family and users", async () => {
  for (const p of ["/api/stats", "/api/people", "/api/services/streaming/logs"]) {
    assert.equal((await call(p, "fam@x")).status, 403, p);
    assert.equal((await call(p, "new@x")).status, 403, p);
  }
  assert.equal((await call("/api/services/streaming/restart", "fam@x", { method: "POST" })).status, 403);
});

test("stats returns the sample history", async () => {
  const s = await (await call("/api/stats?range=24h", "owner@x")).json();
  assert.ok(s.points.length >= 1);
  assert.ok("cpu" in s.points[0] && "temp" in s.points[0]);
  assert.equal((await call("/api/stats?range=1y", "owner@x")).status, 400);
});

test("an offline gap at start is an outage alert everyone gets", async () => {
  const a = await (await call("/api/alerts?since=0", "owner@x")).json();
  const off = a.alerts.find((x) => x.kind === "offline");
  assert.ok(off && off.outage, JSON.stringify(a));
  const u = await (await call("/api/alerts?since=0", "new@x")).json();
  assert.ok(u.alerts.some((x) => x.kind === "offline"));
});

test("restart: only allowlisted names, only from the app, dry run here", async () => {
  assert.equal((await call("/api/services/streaming/restart", "owner@x", { method: "POST", app: false })).status, 403);
  assert.equal((await call("/api/services/tailscale/restart", "owner@x", { method: "POST" })).status, 404);
  assert.equal((await call("/api/services/rm-rf/restart", "owner@x", { method: "POST" })).status, 404);
  const r = await call("/api/services/streaming/restart", "owner@x", { method: "POST" });
  assert.equal(r.status, 200);
  await new Promise((r) => setTimeout(r, 100));
  assert.match(output, /\[dry run\] sudo -n \/usr\/bin\/systemctl restart streaming\.service/);
  await call("/api/services/netheron/restart", "owner@x", { method: "POST" });
  await new Promise((r) => setTimeout(r, 100));
  assert.match(output, /\[dry run\] systemctl --user restart netheron\.service/);
});

test("reboot needs an explicit confirm", async () => {
  assert.equal((await call("/api/server/reboot", "owner@x", { method: "POST", body: {} })).status, 400);
  assert.equal((await call("/api/server/reboot", "owner@x", { method: "POST", body: { confirm: "reboot" } })).status, 202);
  await new Promise((r) => setTimeout(r, 1300));
  assert.match(output, /\[dry run\] sudo -n \/usr\/bin\/systemctl reboot/);
});

test("logs come back as lines", async () => {
  const l = await (await call("/api/services/ssh/logs", "owner@x")).json();
  assert.ok(Array.isArray(l.lines));
});
