// Gate in front of File Browser. Node 24, no packages.
// Tailscale Serve (:8444) -> this gate (127.0.0.1:8092) -> File Browser (127.0.0.1:8091).
//
// Owner:  passes straight through and sees everything in ~/Files.
// Family: each person gets their own folder, ~/Files/Family/<name>, and nothing else.
//         The gate creates their File Browser account (scoped to that folder) on their first
//         visit, and turns their deletes into moves to ~/Files/Family/Recycle bin/<name>/,
//         which only the owner can empty.
// No Tailscale identity: refused.

import http from "node:http";
import { mkdir, rename, stat } from "node:fs/promises";
import { randomBytes } from "node:crypto";
import { join, resolve, basename, sep } from "node:path";

const OWNER = (process.env.GATE_OWNER ?? "").toLowerCase();
const LISTEN_PORT = Number(process.env.GATE_PORT ?? 8092);
const TARGET_PORT = Number(process.env.GATE_TARGET_PORT ?? 8091);
const FILES_ROOT = process.env.GATE_FILES_ROOT ?? "/home/palani/Files"; // File Browser's root
const FAMILY_DIR = "Family";
const RECYCLE_DIR = "Recycle bin";

// ---- File Browser admin calls (as the owner, through its proxy login) -------

function fb(method, path, { body, token, login = OWNER } = {}) {
  return new Promise((ok, fail) => {
    const data = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        host: "127.0.0.1",
        port: TARGET_PORT,
        method,
        path,
        headers: {
          "Tailscale-User-Login": login,
          ...(token ? { "X-Auth": token } : {}),
          ...(data ? { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let text = "";
        res.on("data", (c) => (text += c));
        res.on("end", () => ok({ status: res.statusCode, text }));
      },
    );
    req.on("error", fail);
    if (data) req.write(data);
    req.end();
  });
}

// A safe folder name from a login: "Anitha.R@gmail.com" -> "anitha.r".
const folderFor = (login) => login.split("@")[0].toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[.-]+/, "") || "member";

const ready = new Map(); // login -> folder name, once their account exists
async function ensureFamilyMember(login) {
  if (ready.has(login)) return ready.get(login);
  const folder = folderFor(login);
  await mkdir(join(FILES_ROOT, FAMILY_DIR, folder), { recursive: true });
  const auth = await fb("POST", "/api/login");
  if (auth.status !== 200) throw new Error(`owner login to File Browser failed (${auth.status})`);
  const token = auth.text.trim();
  const list = await fb("GET", "/api/users", { token });
  const users = list.status === 200 ? JSON.parse(list.text) : [];
  if (!users.some((u) => u.username === login)) {
    const created = await fb("POST", "/api/users", {
      token,
      body: {
        what: "user",
        which: [],
        data: {
          username: login,
          password: randomBytes(24).toString("base64url"), // never used: sign-in is the Tailscale identity
          scope: `/${FAMILY_DIR}/${folder}`,
          locale: "en",
          lockPassword: true,
          hideDotfiles: true,
          perm: { admin: false, execute: false, create: true, rename: true, modify: false, delete: true, share: false, download: true },
          commands: [],
        },
      },
    });
    if (created.status >= 300) throw new Error(`could not create File Browser user (${created.status} ${created.text})`);
    console.log(`family member set up: ${login} -> ${FAMILY_DIR}/${folder}`);
  }
  ready.set(login, folder);
  return folder;
}

// ---- Recycle bin --------------------------------------------------------------
// File Browser's DELETE /api/resources/<path> (path relative to the user's folder)
// becomes a move into the owner-only recycle bin.

async function recycle(folder, urlPath) {
  const rel = decodeURIComponent(urlPath.replace(/^\/api\/resources/, "")).replace(/^\/+/, "");
  const home = resolve(FILES_ROOT, FAMILY_DIR, folder);
  const target = resolve(home, rel);
  if (!rel || (target !== home && !target.startsWith(home + sep))) throw Object.assign(new Error("outside your folder"), { code: 400 });
  await stat(target); // 404 if missing
  const bin = join(FILES_ROOT, FAMILY_DIR, RECYCLE_DIR, folder);
  await mkdir(bin, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:T]/g, "-").slice(0, 19);
  await rename(target, join(bin, `${stamp} ${basename(target)}`));
}

// ---- Proxy ------------------------------------------------------------------

function forward(req, res) {
  const upstream = http.request(
    { host: "127.0.0.1", port: TARGET_PORT, method: req.method, path: req.url, headers: req.headers },
    (up) => {
      res.writeHead(up.statusCode ?? 502, up.headers);
      up.pipe(res);
    },
  );
  upstream.on("error", () => {
    if (!res.headersSent) res.writeHead(502, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("File Browser is not answering.");
  });
  req.pipe(upstream);
}

function refuse(res, code, text) {
  res.writeHead(code, { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" });
  res.end(text);
}

const server = http.createServer(async (req, res) => {
  const login = String(req.headers["tailscale-user-login"] ?? "").toLowerCase();
  if (!login || !OWNER) return refuse(res, 403, "These files are private.");
  if (login === OWNER) return forward(req, res);

  try {
    const folder = await ensureFamilyMember(login);
    const path = new URL(req.url ?? "/", "http://x").pathname;
    if (req.method === "DELETE" && path.startsWith("/api/resources/")) {
      await recycle(folder, path);
      res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
      return res.end("Moved to the recycle bin.");
    }
    // Family accounts have no admin rights in File Browser; keep its admin pages closed anyway.
    if (path.startsWith("/api/users") || path.startsWith("/api/settings")) return refuse(res, 403, "Not available.");
    return forward(req, res);
  } catch (err) {
    if (err.code === "ENOENT") return refuse(res, 404, "Not found.");
    if (err.code === 400) return refuse(res, 400, err.message);
    console.error(err);
    return refuse(res, 500, "Files are not available right now.");
  }
});

// Large uploads and downloads can take a long time.
server.requestTimeout = 0;
server.headersTimeout = 60_000;
if (!OWNER) console.warn("GATE_OWNER is not set: everyone is refused.");
server.listen(LISTEN_PORT, "127.0.0.1", () => console.log(`files gate on 127.0.0.1:${LISTEN_PORT} -> ${TARGET_PORT}`));
