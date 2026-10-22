// Join requests: the ONE public page of the homeserver. Node 24, no packages.
// Runs as the `joinreq` user in a hardened systemd service (see join-requests.service).
//
// Two doors, two rules:
//   127.0.0.1:8097  public, through Tailscale Funnel (:443). Anyone on the internet can ask to
//                   join (name + email) and check their own request with a private status link.
//                   Nothing else is here: no files, no dashboard, no Tailscale key.
//   127.0.0.1:8098  admin, never published. Only the dashboard calls it, with a shared secret
//                   that systemd hands to this service (LoadCredential=admin-secret).
//
// Approving (the Tailscale invite) happens in the dashboard, not here.

import http from "node:http";
import { readFile, writeFile, rename } from "node:fs/promises";
import { createHash, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { join } from "node:path";

const PUBLIC_PORT = Number(process.env.REQ_PUBLIC_PORT ?? 8097);
const ADMIN_PORT = Number(process.env.REQ_ADMIN_PORT ?? 8098);
const DASHBOARD_URL = process.env.REQ_DASHBOARD_URL ?? "";
const STATE_DIR = process.env.STATE_DIRECTORY ?? "/var/lib/join-requests"; // set by systemd's StateDirectory=
const STATE_FILE = join(STATE_DIR, "requests.json");
const SECRET_FILE = join(process.env.CREDENTIALS_DIRECTORY ?? "", "admin-secret");

const MAX_WAITING = 10; // requests waiting at once
const MAX_PER_DAY = 20; // new requests in any 24 hours
const MAX_BODY = 2048;
const KEEP_DECIDED_MS = 30 * 24 * 3600_000; // decided requests are forgotten after 30 days
const DAY_MS = 24 * 3600_000;

// ---- State ------------------------------------------------------------------
// One JSON file, written only by this process (write to a temp file, then rename).

let requests = []; // { id, name, email, status: waiting|approved|rejected, createdAt, decidedAt, tokenHash }

async function load() {
  try {
    requests = JSON.parse(await readFile(STATE_FILE, "utf8"));
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
  }
}

async function save() {
  const now = Date.now();
  requests = requests.filter((r) => r.status === "waiting" || now - r.decidedAt < KEEP_DECIDED_MS);
  await writeFile(STATE_FILE + ".tmp", JSON.stringify(requests, null, 1));
  await rename(STATE_FILE + ".tmp", STATE_FILE);
}

const hash = (token) => createHash("sha256").update(token).digest("hex");
const publicView = ({ tokenHash, ...r }) => r;

// ---- Checks -----------------------------------------------------------------

const NAME_OK = /^[\p{L}\p{M}][\p{L}\p{M} .'-]{0,39}$/u;
const EMAIL_OK = /^[^\s@<>"]{1,64}@[a-z0-9-]+(\.[a-z0-9-]+)+$/;

function check(name, email) {
  if (!NAME_OK.test(name)) return "Please enter your name (letters only, up to 40).";
  if (email.length > 100 || !EMAIL_OK.test(email)) return "Please enter a valid email address.";
  return null;
}

// ---- Pages --------------------------------------------------------------------

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

function layout(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${esc(title)}</title>
<style>
:root { --ground: #16161A; --panel: #202026; --line: #34343C; --paper: #EDE8DC; --muted: #A9A49A; --red: #E1251B; --yellow: #F7C600; --blue: #2B5FD9; --ink: #111; color-scheme: dark; }
* { box-sizing: border-box; }
html, body { margin: 0; background: var(--ground); color: var(--paper); font: 500 17px/1.5 "Segoe UI", system-ui, sans-serif; }
main { max-width: 520px; margin: 0 auto; padding: 32px 18px 48px; display: grid; gap: 20px; }
h1 { margin: 0; font-size: 26px; font-weight: 800; letter-spacing: 0.12em; }
.panel { background: var(--panel); border: 2px solid var(--line); padding: 20px; display: grid; gap: 14px; }
label { display: grid; gap: 6px; font-weight: 700; }
input { font: inherit; padding: 12px; background: var(--ground); color: var(--paper); border: 2px solid var(--line); }
input:focus-visible, button:focus-visible, a:focus-visible { outline: 3px solid var(--yellow); outline-offset: 2px; }
button { font: inherit; font-weight: 800; letter-spacing: 0.04em; padding: 12px; background: var(--yellow); color: var(--ink); border: 0; cursor: pointer; }
.err { background: var(--red); padding: 12px 14px; font-weight: 700; }
.state { font-size: 22px; font-weight: 800; letter-spacing: 0.06em; }
.waiting { color: var(--yellow); } .approved { color: #7FA4FF; } .rejected { color: var(--red); }
.muted { color: var(--muted); }
.link { font-family: ui-monospace, Consolas, monospace; font-size: 14px; overflow-wrap: anywhere; background: var(--ground); border: 2px solid var(--line); padding: 10px; }
.trap { position: absolute; left: -9999px; }
a { color: var(--yellow); }
</style>
</head>
<body><main>
<svg width="54" height="34" viewBox="0 0 64 40" aria-hidden="true"><circle cx="16" cy="20" r="14" fill="#E1251B"/><rect x="26" y="7" width="26" height="26" fill="#F7C600"/><path d="M40 34 L58 6 L64 34 Z" fill="#2B5FD9"/></svg>
${body}
</main></body></html>`;
}

function formPage(error = "", name = "", email = "") {
  return layout(
    "Ask to join",
    `<h1>ASK TO JOIN</h1>
<p class="muted">Family only. Enter your name and the email you use for Google, Microsoft or Apple. You'll get an email when you're approved.</p>
${error ? `<div class="err" role="alert">${esc(error)}</div>` : ""}
<form class="panel" method="post" action="/request">
  <label>Your name <input name="name" required maxlength="40" autocomplete="name" value="${esc(name)}"></label>
  <label>Your email <input name="email" type="email" required maxlength="100" autocomplete="email" value="${esc(email)}"></label>
  <label class="trap" aria-hidden="true">Leave empty <input name="website" tabindex="-1" autocomplete="off"></label>
  <button type="submit">Send request</button>
</form>`,
  );
}

function sentPage(statusUrl) {
  return layout(
    "Request sent",
    `<h1>REQUEST SENT</h1>
<div class="panel">
  <p style="margin:0">Keep this link to check your request:</p>
  <div class="link">${esc(statusUrl)}</div>
  <p style="margin:0"><a href="${esc(statusUrl)}">Open my status page</a> and bookmark it.</p>
</div>`,
  );
}

function statusPage(r) {
  const text = {
    waiting: ["WAITING", "Your request is waiting for approval. Check back later."],
    approved: ["APPROVED", "Check your email for an invite from Tailscale. Install the Tailscale app, sign in with this email, then open https://homeserver.tahr-triggerfish.ts.net."],
    rejected: ["NOT APPROVED", "Your request was not approved."],
  }[r.status];
  return layout(
    "Request status",
    `<h1>YOUR REQUEST</h1>
<div class="panel">
  <div class="state ${r.status}">${text[0]}</div>
  <p style="margin:0">${esc(text[1])}</p>
  <p class="muted" style="margin:0">${esc(r.name)} · ${esc(r.email)}</p>
</div>`,
  );
}

// ---- HTTP helpers -----------------------------------------------------------

const HEADERS = {
  "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
  "Cache-Control": "no-store",
  "X-Robots-Tag": "noindex, nofollow",
};

function send(res, code, body, type = "text/html; charset=utf-8", extra = {}) {
  res.writeHead(code, { "Content-Type": type, ...HEADERS, ...extra });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(Object.assign(new Error("too big"), { code: 413 }));
        req.removeAllListeners("data");
        req.resume(); // drain and drop the rest, so the 413 still reaches them
      } else chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

// ---- Public door (Funnel) -----------------------------------------------------

const publicServer = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? "/", "http://x");
    const path = url.pathname;

    if (path === "/health") return send(res, 200, "ok", "text/plain");

    if (path === "/") {
      // On the tailnet, the plain address still means "my dashboard". Tailscale only adds this
      // header for tailnet visitors; a faked one just gets a redirect to a page it can't open.
      if (req.headers["tailscale-user-login"] && DASHBOARD_URL) return send(res, 302, "", "text/plain", { Location: DASHBOARD_URL });
      return send(res, 302, "", "text/plain", { Location: "/request" });
    }

    if (path === "/request" && req.method === "GET") return send(res, 200, formPage());

    if (path === "/request" && req.method === "POST") {
      const form = new URLSearchParams(await readBody(req));
      const name = (form.get("name") ?? "").trim().replace(/\s+/g, " ");
      const email = (form.get("email") ?? "").trim().toLowerCase();
      if (form.get("website")) return send(res, 200, sentPage("/request")); // a bot filled the hidden field
      const problem = check(name, email);
      if (problem) return send(res, 400, formPage(problem, name, email));

      const now = Date.now();
      if (requests.some((r) => r.email === email)) return send(res, 409, formPage("A request for this email already exists. Use the status link you were given.", name, email));
      if (requests.filter((r) => r.status === "waiting").length >= MAX_WAITING || requests.filter((r) => now - r.createdAt < DAY_MS).length >= MAX_PER_DAY) {
        return send(res, 429, formPage("Too many requests right now. Please try again tomorrow.", name, email));
      }

      const token = randomBytes(24).toString("base64url");
      requests.push({ id: randomUUID(), name, email, status: "waiting", createdAt: now, decidedAt: null, tokenHash: hash(token) });
      await save();
      const statusPath = `/request/status/${token}`;
      return send(res, 303, "", "text/plain", { Location: statusPath + "?new=1" });
    }

    const m = path.match(/^\/request\/status\/([A-Za-z0-9_-]{32})$/);
    if (m && req.method === "GET") {
      const r = requests.find((x) => x.tokenHash === hash(m[1]));
      if (!r) return send(res, 404, layout("Not found", `<h1>NOT FOUND</h1><p>This status link isn't valid. <a href="/request">Ask to join</a></p>`));
      if (url.searchParams.get("new")) return send(res, 200, sentPage(`https://${req.headers.host ?? ""}${path}`));
      return send(res, 200, statusPage(r));
    }

    return send(res, 404, layout("Not found", `<h1>NOT FOUND</h1><p><a href="/request">Ask to join</a></p>`));
  } catch (err) {
    if (err.code === 413) return send(res, 413, "Too big", "text/plain");
    console.error(err.message);
    return send(res, 500, "Something went wrong.", "text/plain");
  }
});

// ---- Admin door (dashboard only) ------------------------------------------------

let secret = null;
function authorized(req) {
  const given = Buffer.from(String(req.headers.authorization ?? ""));
  const want = Buffer.from(`Bearer ${secret}`);
  return secret && given.length === want.length && timingSafeEqual(given, want);
}

const adminServer = http.createServer(async (req, res) => {
  try {
    if (!authorized(req)) return send(res, 401, "no", "text/plain");
    const path = new URL(req.url ?? "/", "http://x").pathname;

    if (path === "/admin/requests" && req.method === "GET") {
      return send(res, 200, JSON.stringify(requests.map(publicView)), "application/json");
    }

    const m = path.match(/^\/admin\/requests\/([0-9a-f-]{36})$/);
    const r = m && requests.find((x) => x.id === m[1]);
    if (m && !r) return send(res, 404, "no such request", "text/plain");
    if (r && req.method === "POST") {
      const { status } = JSON.parse(await readBody(req));
      if (status !== "approved" && status !== "rejected") return send(res, 400, "bad status", "text/plain");
      r.status = status;
      r.decidedAt = Date.now();
      await save();
      return send(res, 200, JSON.stringify(publicView(r)), "application/json");
    }
    if (r && req.method === "DELETE") {
      requests = requests.filter((x) => x !== r);
      await save();
      return send(res, 204, "");
    }
    return send(res, 404, "Not found", "text/plain");
  } catch (err) {
    console.error(err.message);
    return send(res, 500, "error", "text/plain");
  }
});

secret = (await readFile(SECRET_FILE, "utf8")).trim();
if (secret.length < 32) throw new Error("admin secret is missing or too short");
await load();
publicServer.listen(PUBLIC_PORT, "127.0.0.1", () => console.log(`join requests (public) on 127.0.0.1:${PUBLIC_PORT}`));
adminServer.listen(ADMIN_PORT, "127.0.0.1", () => console.log(`join requests (admin) on 127.0.0.1:${ADMIN_PORT}`));
