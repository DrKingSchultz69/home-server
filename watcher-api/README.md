# Watcher API

Backend for the Watcher app (`watcher/app`). It checks every service, keeps 30 days of CPU, memory, disk and temperature history, records alerts, and lets admins read logs, restart services and reboot the server.

- **Address:** https://homeserver.tahr-triggerfish.ts.net:8447 (tailnet only, never Funnel). Listens on `127.0.0.1:8090`.
- **Who sees what:** Tailscale tells the API who is asking. The owner (`WATCH_OWNER`) is admin. Everyone else gets the role from `~/.config/homeserver/watcher-roles.json` (`{"login": "admin" | "family" | "user"}`), default **user**. User: Streaming. Family: Streaming + Files. Admin: everything.
- **History:** SQLite in `~/.local/share/watcher/watcher.db`. One sample a minute, rolled up to 5-minute averages (7 days) and hourly averages (30 days).
- **Alerts:** service down / back up, disk ≥ 90%, memory ≥ 90%, CPU ≥ 85 °C, and "server was offline" after a power cut or crash. `outage: true` alerts break quiet hours in the app.
- **Restart:** only the names in `RESTARTABLE` (Tailscale left out on purpose). System services and reboot go through the narrow sudo rule in `sudoers-watcher`.
- **Light:** user service capped at 80 MB RAM and 5% CPU.

## API

| Endpoint | Who |
|---|---|
| `GET /api/me` | everyone: login, role, services |
| `GET /api/status` | everyone (filtered by role); admins also get server numbers and restart targets |
| `GET /api/alerts?since=<ms>` | everyone (own services + server offline); admins all |
| `GET /api/version` | everyone: latest app version (`app-version.json`) |
| `GET /api/stats?range=24h\|7d\|30d` | admin |
| `GET /api/services/<id>/logs` | admin: last 200 lines |
| `GET /api/people` | admin: people and devices from Tailscale (read-only key) |
| `POST /api/services/<name>/restart` | admin, header `X-Watcher: 1` |
| `POST /api/server/reboot` body `{"confirm":"reboot"}` | admin, header `X-Watcher: 1` |

## Install or update on the server

```bash
cd ~/Server && git pull
sudo install -m 0440 watcher-api/sudoers-watcher /etc/sudoers.d/watcher && sudo visudo -c
ln -sf ~/Server/watcher-api/watcher-api.service ~/.config/systemd/user/watcher-api.service
systemctl --user daemon-reload && systemctl --user enable --now watcher-api && systemctl --user restart watcher-api
tailscale serve --bg --https=8447 http://127.0.0.1:8090
```

Then paste `files/tailscale-policy.hujson` into the Tailscale console (Access controls) so family devices may reach :8447.

## Test

On the server (reads `/proc` and systemd): `node --test test/server.test.mjs`. It runs its own copy on port 18090 with a temporary database and dry-run restarts.
