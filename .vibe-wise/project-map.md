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
- In progress 2026-10-21: Samba active (hosts allow tailnet only; verified 445 open on the Tailscale IP, closed on home Wi-Fi); SELinux samba_share_t on ~/Files and ~/Backups; File Browser v2.63.23 (checksum verified) on 127.0.0.1:8091, proxy auth by Tailscale identity, root ~/Files. Deviation found in testing: File Browser auto-creates an empty account for any tailnet user, so an owner-only gate (files/gate/gate.mjs, files-gate.service, 127.0.0.1:8092) now refuses everyone else before File Browser; Tailscale Serve :8444 -> gate. Verified: no identity 403, family 403, owner signs in and lists files; test account and folder removed. Dashboard Files tile up with link to :8444. Deviation: ~/Backups is not in File Browser (single root); it is reachable as \\homeserver\Backups. Z: mapped on the laptop (\\homeserver\Files, reconnects at sign-in; write test passed). Still to do: desktop backup copy, Workspace backup task.

## Phase 10 streaming design (confirmed 2026-10-21)
- Learner decisions: library = family videos, movies, shows; build everything (option A) with a neo-brutalist look and skeuomorphic icons; Sony Bravia X80G (Android TV) gets a simple app driven by the remote's arrow keys; features: posters, resume, subtitles, shows by season, search; isolation from Phase 7 (streamer user, rootless container, media read-only, own network, own login).
- Approved AI additions: ahead-of-time nightly conversion of unplayable files to H.264/AAC mp4 with Quick Sync (no live transcoding); folders ~/Media/Family, ~/Media/Movies, ~/Media/Shows/<Show>/Season N; poster.jpg next to the video or an auto-grabbed frame (no outside movie database); .srt subtitles converted for the browser; resume per viewer in Node's built-in SQLite; remote family via Tailscale identity, TV at home as a 'Living room' profile without login; tailnet https :8445 plus one home Wi-Fi port for the TV; Android TV wrapper app built with the laptop's Android SDK and installed over Wi-Fi; code in streaming/ (Node 24, no packages, Podman container as streamer); milestones 1 library+player+TV app, 2 resume+subtitles+seasons, 3 posters+search+nightly conversion.
- Look approved 2026-10-21: design canvas https://claude.ai/artifact/ACxcaUstoNrtFz1fBRwonc (TV home, TV player, phone home, phone show): lavender ground #EDEBFF, ink #111111, yellow #FFD93D, pink #FF6FA8/#FF4F97, blue #5B8CFF, mint #3EE0A0; Archivo Black / Archivo / JetBrains Mono; 3-4 px black borders, hard offset shadows; skeuomorphic SVG icons (VHS, clapperboard, wooden TV, magnifier, glossy buttons); TV focus = 5 px outline. Milestone 1 implemented 2026-10-21 with isolation option C1 (learner chose a hardened systemd service over a Podman container, because container SELinux labels would break Samba/File Browser access to the same videos): /etc/systemd/system/streaming.service as system user streamer (no login), TemporaryFileSystem=/home with read-only binds of only streaming/ code and the Family/Movies/Shows folders, NoNewPrivileges, ProtectSystem=strict, no capabilities, MemoryMax 256M (about 35 MB used). Doors: 127.0.0.1:8095 via Tailscale Serve :8445 (Tailscale identity: owner/family) and :8096 on home Wi-Fi (firewalld port opened; Living room profile only for 192.168.29.*; identity headers ignored there). Sudoers rule lets palani run only systemctl restart streaming without a password. Verified: no identity 403, owner and family roles, Living room from 192.168.29.20, 403 via the Tailscale IP on :8096, seek returns 206. Library: 909 family videos (many dated Camera clips), Movies and Shows empty (~/Files/Movies, ~/Files/Shows). Home shows 8 per section + See all. Dashboard Streaming tile live. Not yet tested on the Bravia; TV app deferred until laptop disk space is freed.

## Dashboard redesign (2026-10-22)
- Learner choices: Bauhaus look in a control-room setting; keep the sections; add an alerts panel; mockup first (canvas https://claude.ai/artifact/MW9ke72LiXC3AmoG2p7Hwi, approved).
- Implemented: dashboard/public/index.html rebuilt (console black, primary red/yellow/blue, Jost + IBM Plex Mono; CPU circle, memory bars, disk triangle filled by area; status lights by shape and colour: blue square up, red triangle down, open circle not set up/checking); alerts panel reads ntfy history (cache-duration raised to 720h); CSP allows Google Fonts. Fix: a service is marked down only after 2 failed checks in a row (false alarms after restarts under the 5% CPU cap). Netheron token rotated again after it appeared in a log read; log reads now hide it.
