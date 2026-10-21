// Home stream: the family streaming site. Node 24, no packages.
// Runs as the `streamer` user in a hardened systemd service (see streaming.service).
//
// Two doors, two rules:
//   127.0.0.1:8095  reached only through Tailscale Serve (:8445). Viewer = Tailscale identity.
//   0.0.0.0:8096    the living-room TV on home Wi-Fi. Identity headers are ignored here
//                   (anyone on Wi-Fi could fake them); only home-network addresses get the
//                   "Living room" profile, everyone else is refused.

import http from "node:http";
import { createReadStream } from "node:fs";
import { readdir, readFile, stat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { extname, join, relative, basename, dirname } from "node:path";

const OWNER = (process.env.STREAM_OWNER ?? "").toLowerCase();
const TAILNET_PORT = Number(process.env.STREAM_TAILNET_PORT ?? 8095);
const LAN_PORT = Number(process.env.STREAM_LAN_PORT ?? 8096);
const LAN_PREFIX = process.env.STREAM_LAN_PREFIX ?? "192.168.29."; // home Wi-Fi addresses
const LIBRARY = {
  family: process.env.STREAM_FAMILY_DIR ?? "",
  movies: process.env.STREAM_MOVIES_DIR ?? "",
  shows: process.env.STREAM_SHOWS_DIR ?? "",
};
const RESCAN_MS = 10 * 60_000;

const VIDEO_TYPES = {
  ".mp4": "video/mp4",
  ".m4v": "video/mp4",
  ".mov": "video/quicktime",
  ".webm": "video/webm",
  ".mkv": "video/x-matroska",
};

// ---- Library ----------------------------------------------------------------
// Family: every video under the family folder; its folder name is shown as a hint.
// Movies: every video under the movies folder.
// Shows:  <shows>/<Show name>/(Season N/)<episode>; seasons are grouped in milestone 2.

let library = { family: [], movies: [], shows: [], scannedAt: null };
const files = new Map(); // id -> { path, type, size }

const idFor = (path) => createHash("sha1").update(path).digest("base64url").slice(0, 12);
const titleFor = (path) =>
  basename(path, extname(path))
    .replace(/[._]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

async function walk(dir, out = []) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return out; // folder missing or not readable: an empty section
  }
  for (const e of entries) {
    if (e.name.startsWith(".")) continue;
    const full = join(dir, e.name);
    if (e.isDirectory()) await walk(full, out);
    else if (e.isFile() && VIDEO_TYPES[extname(e.name).toLowerCase()]) out.push(full);
  }
  return out;
}

async function entry(path, root) {
  const s = await stat(path);
  const id = idFor(path);
  files.set(id, { path, type: VIDEO_TYPES[extname(path).toLowerCase()], size: s.size });
  const rel = relative(root, path);
  const folder = dirname(rel) === "." ? "" : dirname(rel).split(/[\\/]/).pop();
  return { id, title: titleFor(path), folder, size: s.size, playable: [".mp4", ".m4v", ".webm"].includes(extname(path).toLowerCase()) };
}

async function scan() {
  files.clear();
  const byTitle = (a, b) => a.title.localeCompare(b.title, undefined, { numeric: true });
  const family = LIBRARY.family ? await Promise.all((await walk(LIBRARY.family)).map((p) => entry(p, LIBRARY.family))) : [];
  const movies = LIBRARY.movies ? await Promise.all((await walk(LIBRARY.movies)).map((p) => entry(p, LIBRARY.movies))) : [];
  const shows = [];
  if (LIBRARY.shows) {
    let names = [];
    try {
      names = (await readdir(LIBRARY.shows, { withFileTypes: true })).filter((e) => e.isDirectory() && !e.name.startsWith("."));
    } catch {}
    for (const d of names) {
      const root = join(LIBRARY.shows, d.name);
      const episodes = await Promise.all((await walk(root)).map((p) => entry(p, root)));
      if (episodes.length) shows.push({ name: d.name, episodes: episodes.sort(byTitle) });
    }
  }
  library = { family: family.sort(byTitle), movies: movies.sort(byTitle), shows: shows.sort((a, b) => a.name.localeCompare(b.name)), scannedAt: Date.now() };
  console.log(`library: ${family.length} family, ${movies.length} movies, ${shows.length} shows`);
}

// ---- Who is watching --------------------------------------------------------

function viewerOnTailnet(req) {
  const login = String(req.headers["tailscale-user-login"] ?? "").toLowerCase();
  if (!login) return null;
  const name = String(req.headers["tailscale-user-name"] ?? "") || login.split("@")[0];
  return { role: OWNER && login === OWNER ? "owner" : "family", name };
}

function viewerOnLan(req) {
  const ip = (req.socket.remoteAddress ?? "").replace(/^::ffff:/, "");
  return ip.startsWith(LAN_PREFIX) ? { role: "living-room", name: "Living room" } : null;
}

// ---- HTTP -------------------------------------------------------------------

const SECURITY_HEADERS = {
  "Content-Security-Policy":
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; media-src 'self'; img-src 'self' data:; frame-ancestors 'none'",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
};

function send(res, code, body, type = "text/plain; charset=utf-8", extra = {}) {
  res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store", ...SECURITY_HEADERS, ...extra });
  res.end(body);
}

function sendVideo(req, res, file) {
  const range = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range ?? "");
  const headers = { "Content-Type": file.type, "Accept-Ranges": "bytes", "Cache-Control": "private, max-age=3600", ...SECURITY_HEADERS };
  if (!range) {
    res.writeHead(200, { ...headers, "Content-Length": file.size });
    return createReadStream(file.path).pipe(res);
  }
  let start = range[1] === "" ? file.size - Number(range[2]) : Number(range[1]);
  let end = range[1] !== "" && range[2] !== "" ? Number(range[2]) : file.size - 1;
  if (!(start >= 0 && start <= end && end < file.size)) {
    res.writeHead(416, { ...headers, "Content-Range": `bytes */${file.size}` });
    return res.end();
  }
  res.writeHead(206, { ...headers, "Content-Range": `bytes ${start}-${end}/${file.size}`, "Content-Length": end - start + 1 });
  const stream = createReadStream(file.path, { start, end });
  stream.on("error", () => res.destroy());
  res.on("close", () => stream.destroy());
  stream.pipe(res);
}

let pageHtml = null;
async function page() {
  pageHtml ??= await readFile(new URL("./public/index.html", import.meta.url), "utf8");
  return pageHtml;
}

function handler(identify) {
  return async (req, res) => {
    try {
      const who = identify(req);
      if (!who) return send(res, 403, "This page is only for the family.");
      if (req.method !== "GET" && req.method !== "HEAD") return send(res, 405, "Method not allowed");
      const path = new URL(req.url ?? "/", "http://x").pathname;

      if (path === "/" || path === "/index.html") return send(res, 200, await page(), "text/html; charset=utf-8");
      if (path === "/api/library") return send(res, 200, JSON.stringify({ viewer: who, ...library }), "application/json");
      if (path.startsWith("/video/")) {
        const file = files.get(path.slice(7));
        return file ? sendVideo(req, res, file) : send(res, 404, "Video not found");
      }
      if (path === "/health") return send(res, 200, "ok");
      return send(res, 404, "Not found");
    } catch (err) {
      console.error(err);
      return send(res, 500, "Something went wrong on the server.");
    }
  };
}

for (const [section, dir] of Object.entries(LIBRARY)) if (!dir) console.warn(`STREAM_${section.toUpperCase()}_DIR is not set`);
await scan();
setInterval(() => scan().catch((e) => console.error(`scan failed: ${e.message}`)), RESCAN_MS).unref();

const tailnet = http.createServer(handler(viewerOnTailnet));
tailnet.requestTimeout = 0;
tailnet.listen(TAILNET_PORT, "127.0.0.1", () => console.log(`tailnet door on 127.0.0.1:${TAILNET_PORT}`));

const lan = http.createServer(handler(viewerOnLan));
lan.requestTimeout = 0;
lan.listen(LAN_PORT, "0.0.0.0", () => console.log(`living-room door on :${LAN_PORT} (only ${LAN_PREFIX}*)`));
