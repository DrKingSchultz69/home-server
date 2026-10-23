# Learning Progress





## Remote access
- Introduced (AI explained): local network vs internet; router blocks incoming connections by default; three kinds of remote use (command line, web apps, full desktop); private network (Tailscale, WireGuard) vs publishing a service (Cloudflare Tunnel); plain WireGuard needs a forwarded port.
- Learner described: public IP -> router NAT -> port forwarding -> server private IP; risks of careless port forwarding (pivoting, exposed router admin, plaintext traffic, DoS). Part of the answer was pasted from another source, so treat it as introduced, not yet demonstrated.
- Learner conclusion (round 1): use an encrypted tunnel or overlay instead of opening router ports.
- Learner choice (round 2): "a published service with a login and better security" for permission-only access. No reasoning given yet; challenged against their own no-exposure requirement and Netheron's private-only rule.
- Learner answer (round 3): treat streaming differently from the rest; the other services "need login for that access". Family should stream away from home on their phones and other devices.
- Introduced (AI explained): reachability and login are separate layers; using both is called defense in depth. Streaming away from home uses the home connection's upload speed.
- Learner design (round 4): Netheron, SSH, files = approved devices only + login. Flow: after login, check whether the device is approved; if not, the user can request access, and the admin (learner) grants or removes it. Streaming site = anyone on the internet + login. Shows the learner can now separate reachability from login per service.
- Gap: the order in the flow (login first, then device check) means unapproved devices can reach the login page, so the services aren't really "approved devices only".
- Learner answer (round 5): the device check happens before reaching Netheron, SSH and files. But also: "anyone on the internet can reach my login pages, but only approved devices can log in". These two statements contradict each other unless the reachable login page is the private network's own sign-in, not the server's.
- Learner rule: approve only devices known to be safe.
- Learner requirement: the streaming site must not become a way into the rest of the server. Learner wants to follow Cloudflare's terms.
- Learner brought pasted research (apparently from another AI chat): Cloudflare's terms on video streaming, and layered isolation (separate Linux user, hardened rootless containers, binding to 127.0.0.1 or a Tailscale IP, separate container network, firewall, secrets hygiene). Treat as introduced, not demonstrated.
- AI flagged in the pasted plan: ufw is not Fedora's firewall (Fedora uses firewalld); "expose 80/443 publicly" conflicts with the no-open-ports requirement when a tunnel is used; --read-only needs writable folders for app config and cache; a rootless container should run under the separate streaming user, not the learner's account; some Cloudflare details (e.g. a "bypass caching" exception) need checking against Cloudflare's own terms page.
- Learner answer (round 6): Netheron, SSH and admin panels must never be public (resolves the login-page contradiction). Pasted a lost-device plan: device approval on, key expiry kept on, Tailscale SSH in check mode, access rules (phones reach streaming only; Netheron and SSH from the laptop only), strong SSO with 2FA, phone screen lock and remote wipe; on loss: remove the device in the admin console, sign out of all sessions, wipe, rotate keys. Asked "which is good option" for two compatible answers.
- Learner reasoning (own words): bind Netheron, SSH and files to a private-network IP instead of 0.0.0.0, "to protect against a pivot attack". Partly right: binding stops other devices (home Wi-Fi, the internet) but not a compromised process on the same machine. AI explained this.
- Streaming publishing: learner was stuck; AI offered options A–D with tradeoffs.
- Learner answer (round 7): streaming with no open ports while family can reach it away from home, "because I can save the URL and use it". No explicit option picked. Learner's own phone should reach Netheron, SSH and files. Pasted a five-layer table (VM, hardened container, network namespace + firewall, auth on Netheron, least-privilege secrets) and asked: isn't it too heavy for a home server, or will the attacker find a way anyway? A good question: it weighs cost against benefit.
- Introduced (AI explained): threat model, i.e. who realistically attacks a home server (automated bots vs a targeted attacker). How public the streaming is decides how many layers are needed. A VM costs RAM on 8 GB.
- Learner choice (round 8): streaming option A (family joins the private network); skip the VM layer. No reasons stated in this round; earlier rounds show the motivation (no open ports, streaming must not be a way in, RAM cost of a VM on 8 GB).
- Outcome: remote access design confirmed (Design checkpoint). See project-map.md.
- Needs reinforcement: what binding to an address does and doesn't protect against. The tradeoff between exposure (a login page reachable by anyone) and convenience (no app needed on each device). The learner still talks about "login" where the question is about reachability.

## Local network access
- Learner noted: the living-room TV is on the same Wi-Fi as the server, so streaming there is local.
- Introduced (AI explained): devices on the same Wi-Fi reach the server by its private IP without any tunnel.

## SSH access
- Introduced (AI explained): Tailscale SSH vs OpenSSH; check mode; SELinux session context; why root login is a bigger target.
- Learner choice: option B (Tailscale SSH + check mode), reasons not stated. Confirmed at the Design checkpoint with AI additions.
- Needs reinforcement: what check mode adds over a key alone (asked, not yet answered).

## Netheron workspace
- Learner answers (round 1): projects live in ~/Workspace on the server and also stay on the laptop; Netheron should stay up to date (mechanism not stated); agents together get no more than 1 GB of RAM.
- Introduced (AI explained): memory limits with systemd (MemoryMax, cgroups); syncing with git (clone, pull, push, conflicts); Netheron ports (4141 proxy always loopback, 4142 workspace); Tailscale Serve vs --lan.
- Learner choices: box 2 GB now (C2, 3 agents), raise after RAM upgrade to fit 3-4; kill the biggest agent when full; access option A (Tailscale Serve, loopback only). Reasons mostly not stated; the learner needed the sync mechanism taught after two rounds.
- Outcome: Phase 8 design confirmed (Design checkpoint) with AI additions.

## Server dashboard
- Learner answers (round 1): show up/down per service plus RAM, CPU and disk; laptop and phone see it, family devices see only family things; build own page (option B); sign-in only for the dashboard, not for the services (meaning to clarify).
- Introduced (AI explained): what a dashboard is; frontend vs backend; why a static page cannot read RAM/CPU; service logins as defense in depth; Tailscale identity headers as the dashboard login; process-running vs health checks; polling cost vs freshness.
- Learner answers (round 3): keep Netheron's login (signed-in link instead); problems on the dashboard and as phone alerts; 5 s refresh but the process must stay light.
- Outcome: dashboard design confirmed (Design checkpoint) with AI additions; becomes Phase 8b.
- Learner answers (round 2): one page that changes by viewer; remove Netheron's login (later reversed); backend checks each service, reports problems to the user, and shows what is stored on disk; asked for an ideal refresh rate.

## File access
- Learner answers (round 1): all three ways: browser (open/upload/download from the dashboard), synced folders, and a Windows network drive Z:. Desktop backup should move to the server; some sharing with family (details open).
- Introduced (AI explained): web file manager vs folder sync vs network drive (SMB); each is another service and door; sync conflicts with git-managed folders; backup (one-way) vs sync (two-way); platform-specific folders like node_modules.
- Learner answers (round 3): Workspace = one-way backup (A); desktop backup folder ~/Files/Desktop backup; backup tool = hourly robocopy (R) over Samba.
- Outcome: Phase 9 design confirmed (Design checkpoint) with AI additions.
- Learner answers (round 2): automatic copy only for the Workspace folder; family gets family videos through the streaming site (rule unchanged, no shared file folder); after the desktop backup is on the server, the laptop copy is deleted.

## Streaming site
- Learner answers (round 1): library = family videos plus movies and shows; build their own so it can have a neo-brutalist look with skeuomorphic icons; TV is a Sony Bravia X80G (Android TV).
- Introduced (AI explained): library, player page, format fit; direct play vs transcoding vs ahead-of-time conversion; Intel Quick Sync; TV remote (D-pad) navigation; the parts a full build includes.
- Learner answers (rounds 2-3): build everything (A) because they want to own every part plus the look; unsure about formats (AI recommended ahead-of-time conversion); TV = simple app on the Bravia; v1 features: posters, resume, subtitles, seasons, search.
- Outcome: Phase 10 design confirmed (Design checkpoint) with AI additions; built in 3 milestones.

## Family join requests
- Learner request (2026-10-22): family should not need the owner to invite them; they type a web address, enter details, and the owner approves on the dashboard instead of the Tailscale console.
- Introduced (AI explained): a page reachable without Tailscale is public, conflicting with the "nothing is public" rule; Tailscale Funnel (public without router ports, only ports 443/8443/10000, whole port public); invites count as approval; dashboard key needs write access.
- Learner answers: option A (public request page, accepting a rule change for it); address https://homeserver.tahr-triggerfish.ts.net/request (dashboard moves off 443); form = name + email; phone alert on new request = yes; rejected people see "not approved".
- Outcome (2026-10-22): deployed. Policy with 8446 + funnel attr applied; new OAuth client (scopes users, devices:core:read; the old kxEBVL2… client's secret appeared in a screenshot, owner told to revoke it); joinreq service installed; Funnel :443 -> 127.0.0.1:8097, dashboard on Serve :8446. Tested: tailnet / redirects to :8446; test request listed on the dashboard, phone alert sent, cross-site approve blocked (403), bad input 400, duplicate 409, test removed. CLAUDE.md rule updated to "one public page". The tailnet-wide Funnel setting (console Settings → General → Funnel) was off and had to be turned on before public DNS appeared. Internet test via relay 103.84.155.153: / -> /request, /request 200, faked Tailscale header ignored, dashboard paths 404, ports 8443/8444/8445/8446/10000 unreachable.
- Also 2026-10-22: AnyDesk installed on the server but fails on Wayland (display_server_not_supported); KDE Remote Desktop (krdp, port 3389, tailnet only by firewall) turned on instead, sign-in pending a krdp user.

## Homeserver app (all platforms)
- Learner request (2026-10-23): one installable app (Windows .exe, Linux, Mac, Android) instead of many links. Their workflow: 1) sign in, or request access with Google/Apple sign-in; 2) show only the services the user may use (Dashboard, Streaming, Files); 3) admin area for maintaining and monitoring the server; 4) admin gets in-app/Android notifications when the server is down, back up, or has a problem; 5) professional Apple-like design.
- Introduced (AI explained): the app can only reach the server through Tailscale (rule), so "sign in" is really "is this device on the tailnet"; Google/Apple sign-in on the request page would prove the email is theirs (Apple needs a paid developer account); a dead server can't report itself down, so something outside it must watch; Tauri (one web-based codebase -> exe/AppImage/dmg/apk); unsigned apps show warnings on Windows/Mac.
- Learner answers (2026-10-23): 1) B, Tailscale built into the app (one app, nothing else to install); 2) A, request page uses email + Google sign-in only (no Apple); 3) wants no extra apps like ntfy, everything in one app, asked whether an outside checker or the app checking is more secure; 4) order: Windows + Android, then Linux, then macOS; asked for a framework comparison before choosing (mentions Android Studio for mobile).
- Introduced (AI explained): built-in Tailscale means a Go library (tsnet) inside the app, which every framework has to load; each app install becomes its own tailnet device; Android can't deliver alerts to a closed app instantly without Google's push service (FCM), periodic checks run about every 15 minutes.

- Learner answers (2026-10-23): 3) B, the app checks in about every 15 minutes and shows alerts itself (no ntfy app, no outside checker); 4) Flutter (Dart).
- Proposed (AI, awaiting approval): flow request (Google-verified) -> owner approves in app -> Tailscale invite -> sign in through built-in Tailscale -> app shows only allowed services; screens Welcome, Request, Home, Admin. Laptop has Android SDK but no Flutter, Go, or Visual Studio C++ yet.

## Pending decision
- Homeserver app: the owner will provide their own screen design (2026-10-23); my mockup is only a placeholder. Also still needed: their admin-area list. Nothing built yet.
