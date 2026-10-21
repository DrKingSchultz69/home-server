# Project Map

## Purpose
Turn a desktop PC into a home server that also stays usable as a normal daily PC.

## Requirements
- Hardware: Intel i5 7th gen, NVIDIA GT 710, 8 GB RAM, 1 TB SSD (Acer RE100).
- Dual use: normal desktop PC and always-on server at the same time.
- Wanted uses: websites/apps, files and media, game server, AI/dev tools.
- Main remote use: maintain files and projects on the server, and run Claude Code or Netheron in a workspace there.
- Netheron (per the learner's description): a local control room running Claude Code, Codex, OpenCode, Pi, Oh My Pi and a shell side by side. Ports 4141/4142/4143 (plus 5141–5143 for a test copy); 4141 must never be reachable from outside the server; data in ~/.mm; health checks at /health (4141) and /api/version (4142). It says to keep it private and to run fewer agents if memory is short.
- Devices: OMEN laptop and Galaxy S24 (learner), family members' phones and other devices, living-room TV.
- Family streams at home (TV on the same Wi-Fi) and away from home. Learner's idea: build their own streaming website on the server.
- Requirements stated by learner: no ports opened on the router; traffic encrypted; the streaming site must not become a way into Netheron, SSH or files; approve only devices known to be safe; follow Cloudflare's terms if Cloudflare is used.
- Learner request (2026-10-21): one dashboard page that lists every service the server provides, instead of copying links/tokens by hand. Design not yet decided.
- Management laptop: OMEN 16 (Windows 11), used to set up and reach the server.

## Components
- OS: Fedora (chosen by learner). KDE Plasma edition was proposed by AI; not explicitly confirmed.
- Remote access: Tailscale private network (chosen; confirmed at the Design checkpoint). Not yet implemented.
- Proposed by AI before learn mode started, not yet decided: Docker or Podman, Jellyfin, File Browser/Syncthing/Samba, Minecraft (Paper), Uptime Kuma, cloud-API AI agents. Removing the GT 710 was also an AI recommendation.

## Main Flow
Remote access design (chosen, not implemented):
- Learner's laptop and phone --(Tailscale + login)--> Netheron, SSH, files, streaming
- Family devices --(Tailscale, access rules: streaming only + streaming login)--> streaming website
- New device --> request access --> learner approves or removes it in the Tailscale admin console
- Living-room TV --(home Wi-Fi)--> streaming website
- Internet --X--> nothing (no router ports, nothing public)

## Data and Trust Boundaries
Chosen (learner decisions):
- Netheron, SSH and files bound to the Tailscale IP, never 0.0.0.0; never public.
- Device approval on; only devices known to be safe.
- Lost device plan: key expiry on, Tailscale SSH in check mode, 2FA on the sign-in account (not SMS), phone screen lock and remote wipe; on loss, remove the device, sign out of all sessions, wipe, rotate keys and tokens.
- Streaming isolation: hardened rootless container under a separate `streamer` user (drop all capabilities, no new privileges, media mounted read-only, no container socket), separate container network plus firewall, Netheron's own login (never "trust localhost"), least-privilege secrets (scoped keys, chmod 600). No VM (RAM cost on 8 GB).
Approved AI additions:
- Automatic security updates on Fedora.
- Streaming listens only on home Wi-Fi and Tailscale.
- firewalld blocks everything on home Wi-Fi except streaming.

## Build and Deployment
Fedora KDE Plasma 44 installed on the desktop (2026-10-21). Desktop files backed up to the laptop at C:\DesktopBackup (36,038 files, 150.8 GB, verified by size and date). GT 710 removed (its nouveau driver crashed the installer); monitor on the Intel onboard graphics. Phase 4 done: updates, hostname homeserver, sleep disabled, sshd enabled. User palani, LAN IP 192.168.29.218.

## Unknowns
- Whether Fedora is installed yet; RAM upgrade. The desktop has one 1 TB SSD (Acer RE100), not an HDD; the earlier "1 TB HDD" was wrong.
- Tailscale free-plan user limit vs the number of family members.
- Streaming: custom website vs a ready-made media server; video formats the TV browser can play; home upload speed for away-from-home streaming.
- Memory: Netheron running several agents on 8 GB alongside other services.
- Container runtime (Podman vs Docker) and where data lives on the 1 TB SSD (Acer RE100).

## Phase 7 SSH design (confirmed 2026-10-21)
- Learner chose option B: Tailscale SSH with check mode (Tailscale default rule, 12 h re-check). Trade-off accepted: sessions run in the unconfined_service_t SELinux context.
- Approved AI additions: remove root from the SSH rule (autogroup:nonroot only); block port 22 on the home Wi-Fi firewalld zone; fallback is the desktop's own keyboard; test sudo in a Tailscale SSH session before closing Wi-Fi SSH.
- Implemented 2026-10-21: tailscale0 in firewalld trusted zone; home Wi-Fi zone (FedoraWorkstation, enp3s0) now allows only dhcpv6-client and samba-client (ssh and 1025-65535 tcp/udp removed). Verified: LAN port 22 and 4141 closed, Tailscale SSH works, sudo works in Tailscale SSH sessions. Root removed from the SSH rule (verified: root refused, palani works). Automatic security updates on: dnf5-automatic.timer daily, security only, apply_updates=yes, reboot=never (owner reboots weekly). Phone screen lock + Find My Device on (owner confirmed). Phase 7 complete. Phase 5b done: repo cloned to ~/Server on the server (gh logged in as DrKingSchultz69), Claude Code 2.1.305 installed and signed in.

## Phase 8 Netheron design (confirmed 2026-10-21)
- Learner decisions: projects in ~/Workspace on server and laptop, synced with git; Netheron cloned from DrKingSchultz69/Cobble-Ingot into ~/Workspace/Netheron; systemd MemoryMax 2G now (3 agents), raised after a RAM upgrade to fit 3-4; when full, Linux kills the biggest agent; workspace (4142) reached via Tailscale Serve, Netheron stays on 127.0.0.1; 4141 never published.
- Approved AI additions: user service under palani with linger; Node.js 24+ from Fedora; Tailscale HTTPS certificates on; Phase 11 family rule must exclude the workspace; design-rule wording fixed.
- Implemented 2026-10-21: Node 24.18 (/usr/bin/node-24, symlinked as ~/.local/node24/bin/node); linger on; tailscale operator = palani. Laptop relay-redesign work committed and pushed (78c43a7, includes 48 MB research screenshots; .netheron/ ignored). Server ~/Workspace/Netheron on relay-redesign, npm ci done. User service ~/.config/systemd/user/netheron.service: enabled, MemoryMax=2G, Restart=on-failure, listens on 127.0.0.1:4141/4142/4143 only; workspace returns 401 without the token (~/.mm/token, mode 600, rotated after the trial run). Tailscale HTTPS on; tailscale serve --bg https://homeserver.tailaf7058.ts.net -> 127.0.0.1:4142 (tailnet only). Verified from the laptop: HTTPS answers 401 without token; 4141/4142 closed on the Tailscale IP; 443/4142 closed on home Wi-Fi. Phase 8 complete.

## Phase 8b dashboard design (confirmed 2026-10-21)
- Learner decisions: own page + backend (option B); shows per-service up/down, CPU, RAM, disk, and what is stored; problems on the page and as phone alerts; one page that changes by viewer (owner sees all, family sees family tiles); Netheron keeps its own login, reached through a signed-in link; CPU/RAM every 5 s; must stay light.
- Approved AI additions: Node 24 backend with no extra packages as a user service (MemoryMax 64M, CPUQuota 5%); service checks every 30 s, storage scan hourly at low priority; page pauses when hidden; health checks (answers, not just process); sign-in = Tailscale identity headers (owner full, others family, none refused), backend on 127.0.0.1 only; dashboard at https://homeserver.tailaf7058.ts.net and Netheron moved to :8443; owner-only cookie hand-off to Netheron; phone alerts via self-hosted ntfy on the tailnet (down/up, disk > 90%); v1 = page, status, resources, sign-in, Netheron link; v2 = storage breakdown + alerts.
- Code lives in this repo under dashboard/. Version 1 implemented 2026-10-21: dashboard.service (MemoryMax 64M, CPUQuota 5%, Nice 10; about 42 MB used; slow start under the CPU cap), Tailscale Serve 443 -> 127.0.0.1:8080, Netheron moved to :8443. Verified: no identity 403; owner sees all tiles and resources; family view shows streaming only and gets 403 on /go/netheron; owner /go/netheron sets HttpOnly Secure cookie and redirects to :8443; Netheron without cookie 401; 8080 closed on Wi-Fi and the Tailscale IP. Version 2 implemented 2026-10-21: hourly du storage breakdown (nice 19, ionice idle) shown to the owner; ntfy v2.32.0 (official release, sha256 verified) as user service ntfy.service (MemoryMax 32M, about 14 MB used) on 127.0.0.1:2586, Tailscale Serve :10000, topic homeserver; alerts on down/up and disk >= 90% (clears below 85%). Phone subscribed; test alert received. Phase 8b complete. Phase 11 family access rule must exclude :8443 (Netheron) and :10000 (ntfy).

## Phase 9 file access design (confirmed 2026-10-21)
- Learner decisions: browser (from the dashboard), network drive Z:, and an automatic one-way Workspace backup (laptop C:\Workspace -> server ~/Backups/laptop-workspace, skipping node_modules/.venv/.next/build) via hourly robocopy; git stays the real Workspace sync; family gets no file access (family videos via the streaming site); desktop backup moves to ~/Files/Desktop backup, verified, then the owner deletes the laptop copy (150 GB, too big for the Recycle Bin).
- Approved AI additions: File Browser (official release, checksum-verified, 64 MB box) rooted at ~/Files plus read-only ~/Backups, Tailscale-identity sign-in, owner only (tested with a fake family identity); Samba restricted to the tailnet with its own password, share \\homeserver\Files -> Z:; SELinux labels instead of disabling SELinux; Phase 11 family rule also blocks 445 and File Browser.
- In progress 2026-10-21: Samba active (hosts allow tailnet only; verified 445 open on the Tailscale IP, closed on home Wi-Fi); SELinux samba_share_t on ~/Files and ~/Backups; File Browser v2.63.23 (checksum verified) on 127.0.0.1:8091, proxy auth by Tailscale identity, root ~/Files. Deviation found in testing: File Browser auto-creates an empty account for any tailnet user, so an owner-only gate (files/gate/gate.mjs, files-gate.service, 127.0.0.1:8092) now refuses everyone else before File Browser; Tailscale Serve :8444 -> gate. Verified: no identity 403, family 403, owner signs in and lists files; test account and folder removed. Dashboard Files tile up with link to :8444. Deviation: ~/Backups is not in File Browser (single root); it is reachable as \\homeserver\Backups. Z: mapped on the laptop (\homeserverFiles, reconnects at sign-in; write test passed). Still to do: desktop backup copy, Workspace backup task.
