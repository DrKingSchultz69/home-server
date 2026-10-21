// Owner-only gate in front of File Browser. Node 24, no packages.
// Tailscale Serve (:8444) -> this gate (127.0.0.1:8092) -> File Browser (127.0.0.1:8091).
// File Browser would quietly create an empty account for any tailnet user;
// this gate refuses everyone except the owner before File Browser sees them.

import http from "node:http";

const OWNER = (process.env.GATE_OWNER ?? "").toLowerCase();
const LISTEN_PORT = Number(process.env.GATE_PORT ?? 8092);
const TARGET_PORT = Number(process.env.GATE_TARGET_PORT ?? 8091);

const server = http.createServer((req, res) => {
  const login = String(req.headers["tailscale-user-login"] ?? "").toLowerCase();
  if (!OWNER || login !== OWNER) {
    res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" });
    return res.end("These files are private.");
  }
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
});

// Large uploads and downloads can take a long time.
server.requestTimeout = 0;
server.headersTimeout = 60_000;
if (!OWNER) console.warn("GATE_OWNER is not set: everyone is refused.");
server.listen(LISTEN_PORT, "127.0.0.1", () => console.log(`files gate on 127.0.0.1:${LISTEN_PORT} -> ${TARGET_PORT}`));
