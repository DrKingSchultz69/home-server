# Homeserver dashboard

One page that shows every service on the server, whether it is up, and the server's CPU, memory and disk.

- **Address:** https://homeserver.tailaf7058.ts.net (tailnet only). Netheron moved to `:8443`.
- **Who sees what:** Tailscale tells the dashboard who is visiting. The owner (`DASH_OWNER`) sees everything; other tailnet users see the family tiles only; requests without a Tailscale identity are refused.
- **Netheron tile:** `/go/netheron` sets Netheron's own login cookie for the owner only, then opens Netheron. Netheron still checks it.
- **Light:** runs as a user service boxed to 64 MB RAM and 5% CPU. Services are checked every 30 s; the page refreshes every 5 s and stops while hidden.

## Files

| File | What it is |
|---|---|
| `server.mjs` | Backend (Node 24, no packages), listens on `127.0.0.1:8080` |
| `public/index.html` | The page |
| `dashboard.service` | systemd user service |

## Install or update on the server

```bash
cd ~/Server && git pull
ln -sf ~/Server/dashboard/dashboard.service ~/.config/systemd/user/dashboard.service
systemctl --user daemon-reload && systemctl --user enable --now dashboard && systemctl --user restart dashboard
tailscale serve --bg --https=443 http://127.0.0.1:8080
tailscale serve --bg --https=8443 http://127.0.0.1:4142
```

## Add a service tile

Add an entry to `SERVICES` in `server.mjs` with an `id`, `name`, `about`, `audience` (`"owner"` or `"family"`), an optional `link`, and a `check` that resolves to `{ up, detail }`. Planned services use `planned: true` instead of a check.

## Version 2: storage and phone alerts

- **Storage:** once an hour, at the lowest CPU and disk priority, `du` measures the biggest folders in the home folder; the owner sees them on the page.
- **Alerts:** ntfy (`ntfy/`) runs as a user service on `127.0.0.1:2586`, published on the tailnet at `:10000`. The backend posts to topic `homeserver` when a service goes down or comes back, and when disk passes 90%. Install ntfy from its official GitHub release and check the sha256 against `checksums.txt`.

```bash
ln -sf ~/Server/dashboard/ntfy/ntfy.service ~/.config/systemd/user/ntfy.service
systemctl --user daemon-reload && systemctl --user enable --now ntfy
tailscale serve --bg --https=10000 http://127.0.0.1:2586
```
