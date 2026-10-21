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
import { extname, join, relative, basename, dirname, sep } from "node:path";
import { DatabaseSync } from "node:sqlite";

const OWNER = (process.env.STREAM_OWNER ?? "").toLowerCase();
const TAILNET_PORT = Number(process.env.STREAM_TAILNET_PORT ?? 8095);
const LAN_PORT = Number(process.env.STREAM_LAN_PORT ?? 8096);
const LAN_PREFIX = process.env.STREAM_LAN_PREFIX ?? "192.168.29."; // home Wi-Fi addresses
const LIBRARY = {
  family: process.env.STREAM_FAMILY_DIR ?? "",
  movies: process.env.STREAM_MOVIES_DIR ?? "",
  shows: process.env.STREAM_SHOWS_DIR ?? "",
};
const STATE_DIR = process.env.STATE_DIRECTORY ?? "/var/lib/streaming"; // set by systemd's StateDirectory=
const RESCAN_MS = 10 * 60_000;
const CONTINUE_MIN_S = 30; // positions closer than this to the start or the end are not "in progress"

const VIDEO_TYPES = {
  ".mp4": "video/mp4",
  ".m4v": "video/mp4",
  ".mov": "video/quicktime",
  ".webm": "video/webm",
  ".mkv": "video/x-matroska",
};
const PLAYABLE = new Set([".mp4", ".m4v", ".webm"]);

// Folders that are camera or chat dumps rather than real albums: split them by year.
const DUMP_FOLDER = /^(camera|dcim|whatsapp.*|screenshots?|downloads?|videos?|movies|100andro|100media)$/i;

// ---- Resume positions -------------------------------------------------------

const db = new DatabaseSync(join(STATE_DIR, "state.db"));
db.exec(`CREATE TABLE IF NOT EXISTS progress (
  viewer TEXT NOT NULL, video TEXT NOT NULL,
  position REAL NOT NULL, duration REAL NOT NULL, updated INTEGER NOT NULL,
  PRIMARY KEY (viewer, video))`);
const saveProgress = db.prepare(
  `INSERT INTO progress (viewer, video, position, duration, updated) VALUES (?, ?, ?, ?, ?)
   ON CONFLICT (viewer, video) DO UPDATE SET position = excluded.position, duration = excluded.duration, updated = excluded.updated`,
);
const ownProgress = db.prepare(`SELECT video, position, duration, updated FROM progress WHERE viewer = ?`);
// The living-room TV continues from whoever watched each video most recently.
const latestProgress = db.prepare(
  `SELECT video, position, duration, MAX(updated) AS updated FROM progress GROUP BY video`,
);

function progressFor(who) {
  const rows = who.role === "living-room" ? latestProgress.all() : ownProgress.all(who.key);
  const map = {};
  for (const r of rows) map[r.video] = { position: r.position, duration: r.duration, updated: r.updated };
  return map;
}

// ---- Library ----------------------------------------------------------------

let library = { albums: [], movies: [], shows: [], scannedAt: null };
const files = new Map(); // id -> { path, type, size, subs: [{ path, lang, label }] }
const items = new Map(); // id -> the item as the page sees it

const idFor = (path) => createHash("sha1").update(path).digest("base64url").slice(0, 12);
const titleFor = (path) =>
  basename(path, extname(path))
    .replace(/[._]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

async function walk(dir, videos = [], subs = new Set()) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return { videos, subs }; // folder missing or not readable: an empty section
  }
  for (const e of entries) {
    if (e.name.startsWith(".")) continue;
    const full = join(dir, e.name);
    const ext = extname(e.name).toLowerCase();
    if (e.isDirectory()) await walk(full, videos, subs);
    else if (e.isFile() && VIDEO_TYPES[ext]) videos.push(full);
    else if (e.isFile() && ext === ".srt") subs.add(full);
  }
  return { videos, subs };
}

// Subtitles: "<video name>.srt" or "<video name>.<lang>.srt" in the same folder.
function subtitlesFor(videoPath, subs) {
  const base = videoPath.slice(0, -extname(videoPath).length);
  const found = [];
  for (const s of subs) {
    if (!s.startsWith(base + ".")) continue;
    const middle = s.slice(base.length + 1, -4); // "" or "en" or "en.forced"
    const lang = /^[a-z]{2,3}$/i.test(middle) ? middle.toLowerCase() : "und";
    found.push({ path: s, lang, label: lang === "und" ? "Subtitles" : lang.toUpperCase() });
  }
  return found;
}

// Year from names like 20131114_111713, VID_20210103_070123, IMG-20200514, or a
// 13-digit millisecond timestamp; otherwise the file's own date.
function yearOf(path, mtime) {
  const name = basename(path);
  const ymd = /(?:^|[^0-9])((?:19|20)\d{2})(?:[01]\d)(?:[0-3]\d)(?:[^0-9]|$)/.exec(name);
  if (ymd) return ymd[1];
  const ms = /(?:^|[^0-9])(1[0-9]{12})(?:[^0-9]|$)/.exec(name);
  if (ms) return String(new Date(Number(ms[1])).getFullYear());
  return String(mtime.getFullYear());
}

async function entry(path, root, subs) {
  const s = await stat(path);
  const id = idFor(path);
  const ext = extname(path).toLowerCase();
  const subtitles = subtitlesFor(path, subs);
  files.set(id, { path, type: VIDEO_TYPES[ext], size: s.size, subs: subtitles });
  const parts = relative(root, path).split(sep);
  const top = parts.length > 1 ? parts[0] : "";
  const item = {
    id,
    title: titleFor(path),
    folder: parts.length > 1 ? parts[parts.length - 2] : "",
    playable: PLAYABLE.has(ext),
    subs: subtitles.map((x, n) => ({ n, lang: x.lang, label: x.label })),
    year: yearOf(path, s.mtime),
    top,
  };
  items.set(id, item);
  return item;
}

function albumsOf(family) {
  const groups = new Map();
  for (const v of family) {
    const name = !v.top ? "Unsorted" : DUMP_FOLDER.test(v.top) ? `${v.top} ${v.year}` : v.top;
    if (!groups.has(name)) groups.set(name, { name, dump: DUMP_FOLDER.test(v.top), year: v.year, items: [] });
    groups.get(name).items.push(v);
  }
  const byTitle = (a, b) => a.title.localeCompare(b.title, undefined, { numeric: true });
  const albums = [...groups.values()].map((g) => ({ name: g.name, count: g.items.length, dump: g.dump, year: g.year, items: g.items.sort(byTitle) }));
  // Named albums first (A-Z), then camera-style years (newest first).
  return albums.sort((a, b) => (a.dump !== b.dump ? (a.dump ? 1 : -1) : a.dump ? b.name.localeCompare(a.name, undefined, { numeric: true }) : a.name.localeCompare(b.name)));
}

async function scan() {
  files.clear();
  items.clear();
  const byTitle = (a, b) => a.title.localeCompare(b.title, undefined, { numeric: true });
  const section = async (root) => {
    if (!root) return [];
    const { videos, subs } = await walk(root);
    return Promise.all(videos.map((p) => entry(p, root, subs)));
  };
  const family = await section(LIBRARY.family);
  const movies = (await section(LIBRARY.movies)).sort(byTitle);
  const shows = [];
  if (LIBRARY.shows) {
    let names = [];
    try {
      names = (await readdir(LIBRARY.shows, { withFileTypes: true })).filter((e) => e.isDirectory() && !e.name.startsWith("."));
    } catch {}
    for (const d of names) {
      const episodes = (await section(join(LIBRARY.shows, d.name))).sort(byTitle);
      if (episodes.length) shows.push({ name: d.name, episodes });
    }
  }
  library = { albums: albumsOf(family), movies, shows: shows.sort((a, b) => a.name.localeCompare(b.name)), scannedAt: Date.now() };
  console.log(`library: ${family.length} family videos in ${library.albums.length} albums, ${movies.length} movies, ${shows.length} shows`);
}

// ---- Who is watching --------------------------------------------------------

function viewerOnTailnet(req) {
  const login = String(req.headers["tailscale-user-login"] ?? "").toLowerCase();
  if (!login) return null;
  const name = String(req.headers["tailscale-user-name"] ?? "") || login.split("@")[0];
  return { role: OWNER && login === OWNER ? "owner" : "family", name, key: login };
}

function viewerOnLan(req) {
  const ip = (req.socket.remoteAddress ?? "").replace(/^::ffff:/, "");
  return ip.startsWith(LAN_PREFIX) ? { role: "living-room", name: "Living room", key: "living-room" } : null;
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
    if (req.method === "HEAD") return res.end();
    return createReadStream(file.path).pipe(res);
  }
  const start = range[1] === "" ? file.size - Number(range[2]) : Number(range[1]);
  const end = range[1] !== "" && range[2] !== "" ? Number(range[2]) : file.size - 1;
  if (!(start >= 0 && start <= end && end < file.size)) {
    res.writeHead(416, { ...headers, "Content-Range": `bytes */${file.size}` });
    return res.end();
  }
  res.writeHead(206, { ...headers, "Content-Range": `bytes ${start}-${end}/${file.size}`, "Content-Length": end - start + 1 });
  if (req.method === "HEAD") return res.end();
  const stream = createReadStream(file.path, { start, end });
  stream.on("error", () => res.destroy());
  res.on("close", () => stream.destroy());
  stream.pipe(res);
}

// SRT -> WebVTT, which browsers understand.
async function sendSubtitles(res, sub) {
  const srt = (await readFile(sub.path, "utf8")).replace(/^﻿/, "").replace(/\r/g, "");
  const vtt = "WEBVTT\n\n" + srt.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2");
  send(res, 200, vtt, "text/vtt; charset=utf-8");
}

async function readJson(req, limit = 2048) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (body.length > limit) throw new Error("too large");
  }
  return JSON.parse(body || "{}");
}

function continueList(progress) {
  return Object.entries(progress)
    .filter(([id, p]) => items.has(id) && p.position > CONTINUE_MIN_S && p.position < p.duration - CONTINUE_MIN_S)
    .sort((a, b) => b[1].updated - a[1].updated)
    .slice(0, 8)
    .map(([id, p]) => ({ ...items.get(id), position: p.position, duration: p.duration }));
}

let pageHtml = null;
async function page() {
  pageHtml ??= await readFile(new URL("./public/index.html", import.meta.url), "utf8");
  return pageHtml;
}

function handler(identify) {
  return async (req, res) => {
    try {
      const path = new URL(req.url ?? "/", "http://x").pathname;
      // Health answers without identity so the dashboard can check it; it reveals nothing.
      if (path === "/health") return send(res, 200, "ok");
      const who = identify(req);
      if (!who) return send(res, 403, "This page is only for the family.");

      if (req.method === "POST" && path === "/api/progress") {
        if (!String(req.headers["content-type"] ?? "").startsWith("application/json")) return send(res, 415, "JSON only");
        const { id, position, duration } = await readJson(req);
        if (!items.has(id) || !(position >= 0) || !(duration > 0)) return send(res, 400, "Bad progress");
        saveProgress.run(who.key, id, Math.min(position, duration), duration, Date.now());
        return send(res, 204, "");
      }
      if (req.method !== "GET" && req.method !== "HEAD") return send(res, 405, "Method not allowed");

      if (path === "/" || path === "/index.html") return send(res, 200, await page(), "text/html; charset=utf-8");
      if (path === "/api/library") {
        const progress = progressFor(who);
        const viewer = { role: who.role, name: who.name };
        return send(res, 200, JSON.stringify({ viewer, ...library, progress, continue: continueList(progress) }), "application/json");
      }
      if (path.startsWith("/video/")) {
        const file = files.get(path.slice(7));
        return file ? sendVideo(req, res, file) : send(res, 404, "Video not found");
      }
      const subMatch = /^\/subs\/([A-Za-z0-9_-]{12})\/(\d+)\.vtt$/.exec(path);
      if (subMatch) {
        const sub = files.get(subMatch[1])?.subs[Number(subMatch[2])];
        return sub ? sendSubtitles(res, sub) : send(res, 404, "Subtitles not found");
      }
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
