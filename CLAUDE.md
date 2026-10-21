# Home Server Project

A desktop PC (Intel i5 7th gen, GT 710, 8 GB RAM, 1 TB SSD (Acer RE100)) becoming a home server that is also used as a normal daily PC. OS: Fedora KDE Plasma.

This folder is synced through a private GitHub repo, so Claude has the same context on the Windows laptop (`C:\Server`) and on the Fedora server.

## Read first

- `Setup[/SETUP-PLAN.md`: the step-by-step plan, 12 phases with checkboxes. Tick phases as they finish.
- `.vibe-wise/project-map.md`: requirements, confirmed design, and open decisions.
- `.vibe-wise/progress.md`: learning history. Check for a `## Pending decision` section before doing anything.
- `.vibe-wise/profile.md`: how the owner wants to work.
- `diagrams/remote-access.html`: diagram of the confirmed remote access design (source: `diagrams/remote-access.architecture.json`).

## How to work with the owner

- **Learn mode is on.** The owner designs each piece; Claude explains concepts, gives feedback, then implements what was agreed. Don't decide open design questions for them. Undecided items are marked "decide together" in the plan.
- The owner is a beginner with Linux and networking. Explain new concepts briefly.
- They have ADHD: lead with the next action, number steps (5 max per list), give concrete time estimates, restate where we are, no preamble or closing pleasantries.
- Work style is "a mix": the owner does some steps by hand, Claude does the rest.

## Confirmed design rules (don't break these)

- Nothing is public. No router ports are opened.
- Remote access only through Tailscale; only approved devices; owner's laptop and phone reach everything, family devices reach streaming only.
- Netheron listens on `127.0.0.1` only; its workspace (4142) reaches the tailnet through Tailscale Serve. Port 4141 (model proxy, no login) is never published anywhere. Files bind to the Tailscale side only, never `0.0.0.0`.
- The streaming site is isolated: separate `streamer` user, rootless container running as that user, media read-only, own network, its own login.
- Never commit secrets (API keys, tokens, passwords) to this repo.

## Machines

- Laptop: OMEN 16, Windows 11, folder `C:\Server`.
- Server: Fedora KDE 44, hostname `homeserver`, user `palani`, LAN IP `192.168.29.218`. GT 710 removed; uses Intel onboard graphics. Clone this repo into `~/Server`.
- Tailscale: homeserver = 100.114.125.48, laptop desktop-sb5io1v = 100.91.27.57, phone shais-s24 = 100.100.141.115 (tailnet owner shairaam12@gmail.com).
- From the laptop: `ssh homeserver` (now via the Tailscale IP) (key `~/.ssh/id_ed25519_homeserver`, no passphrase; defined in `~/.ssh/config`).
- Netheron: user service `netheron.service` (`systemctl --user status netheron`), MemoryMax 2G, repo `~/Workspace/Netheron` on branch `relay-redesign`. Workspace: https://homeserver.tailaf7058.ts.net (tailnet only, needs the token in `~/.mm/token`; never paste it into chat).
- The folder name `Setup[` contains a bracket. On Linux, quote it: `cd 'Setup['`.

## Status page

- Published artifact: https://claude.ai/artifact/MmioPgAyXnKfVT8PtRnpQP (source: `docs/homeserver-plan.html`). Republish it when a phase finishes.
