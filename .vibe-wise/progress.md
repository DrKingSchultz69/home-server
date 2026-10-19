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
