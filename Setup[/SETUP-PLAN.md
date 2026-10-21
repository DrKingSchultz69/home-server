# Home Server Setup Plan

**Start here:** Phase 0, step 1. Plug a USB stick (8 GB or more) into this laptop.

Machine: desktop PC, Intel i5 7th gen, GT 710, 8 GB RAM, 1 TB SSD (Acer RE100).
Use: normal daily PC **and** always-on server.
OS: Fedora KDE Plasma.
Remote access: private network (Tailscale), approved devices only, nothing public.
Diagram: [`../diagrams/remote-access.html`](../diagrams/remote-access.html)

---

## Progress

Tick a box when a phase is done.

| # | Phase | Time | Who | Done |
|---|---|---|---|---|
| 0 | Prepare | 15 min | You | [x] |
| 1 | Make the boot USB | 20 min | You (on laptop) | [x] |
| 2 | BIOS settings | 10 min | You (at desktop) | [x] |
| 3 | Install Fedora | 45 min | You (at desktop) | [x] |
| 4 | First boot basics | 30 min | You (at desktop) | [x] |
| 5 | SSH from the laptop | 15 min | You + Claude | [x] |
| 5b | This repo + Claude on the server | 15 min | You | [x] |
| 6 | Tailscale (private network) | 30 min | You + Claude | [x] |
| 7 | Lock it down | 40 min | Claude, you approve | [x] |
| 8 | Netheron workspace | 1 hour | Decide together, then Claude | [x] |
| 8b | Server dashboard | 2 sessions | Decided together, Claude builds | [x] |
| 9 | File access | 30–60 min | Decide together, then Claude | [ ] |
| 10 | Streaming site | 1–2 evenings | Decide together, then build | [ ] |
| 11 | Family access | 20 min per person | You + Claude | [ ] |

**Total to a working, remote-reachable server (phases 0–7):** about 3.5 hours, across 1–2 sessions.
**Everything (phases 0–11):** about 3–4 sessions.

"Decide together" means learn mode: you design that piece first, then it gets built.

---

## Phase 0: Prepare (15 min)

1. Find a USB stick of 8 GB or more. **It will be erased.**
2. Check the desktop's 1 TB SSD (Acer RE100) for anything you need. Copy it elsewhere. **Installing Fedora wipes the SSD.**
3. Decide on the GT 710: remove it and plug the monitor into the motherboard (recommended: its NVIDIA driver no longer works with Fedora), or keep it.
4. Optional, can wait: buy another 8 GB DDR4 stick and a small SSD (240–500 GB).

**Done when:** the USB is in hand and the SSD has nothing you need.

---

## Phase 1: Make the boot USB (20 min, on this laptop)

1. Go to fedoraproject.org, open the **KDE Plasma Desktop** download page and download **Fedora Media Writer** for Windows.
2. Run Fedora Media Writer and choose **Fedora KDE Plasma Desktop** (latest version).
3. Select your USB stick and click **Write**. Wait until it finishes, which includes the download.

**Done when:** Media Writer says the USB is ready.

---

## Phase 2: BIOS settings (10 min, at the desktop)

1. Power on and press **Del** or **F2** repeatedly until the BIOS opens.
2. Set **onboard graphics (iGPU / IGD)** to **Enabled**. If keeping the GT 710, also enable **iGPU Multi-Monitor**.
3. Set **Restore on AC power loss** to **Power On**.
4. Set **SATA mode** to **AHCI**, not RAID or Intel RST.
5. Save and exit.

**Done when:** the PC restarts with those settings saved.

---

## Phase 3: Install Fedora (45 min, at the desktop)

1. Plug in the USB. At power-on, press **F12**, **F11** or **F8** for the boot menu and pick the USB.
2. Click **Install to Hard Drive**. Choose the 1 TB SSD (Acer RE100) and use the entire disk (default layout).
3. **Leave encryption off.** With it on, the server can't restart by itself after a power cut.
4. Create your user account and make it an **administrator**.
5. When it finishes, remove the USB and reboot.

**Done when:** you see the Fedora KDE desktop and can log in.

---

## Phase 4: First boot basics (30 min, at the desktop)

Open **Konsole** (the terminal). Run each command, one at a time.

1. Install all updates, then reboot:
   ```bash
   sudo dnf upgrade --refresh -y
   ```
2. Name the computer:
   ```bash
   sudo hostnamectl set-hostname homeserver
   ```
3. Stop it from ever sleeping:
   ```bash
   sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
   ```
4. Turn on SSH so the laptop can connect:
   ```bash
   sudo dnf install -y openssh-server && sudo systemctl enable --now sshd
   ```
5. Note the server's local IP address and write it in **Notes** at the bottom of this file:
   ```bash
   hostname -I
   ```

**Done when:** all 5 commands ran without errors.

---

## Phase 5: SSH from the laptop (15 min, on this laptop)

1. In PowerShell, connect with your username and IP. Type `yes` when asked, then your Fedora password:
   ```bash
   ssh yourusername@192.168.x.x
   ```
2. Type `exit`. Then create an SSH key on the laptop (press Enter at every prompt):
   ```bash
   ssh-keygen -t ed25519
   ```
3. Copy the key to the server. Replace the username and IP:
   ```bash
   type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh yourusername@192.168.x.x "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
   ```
4. Run the step 1 command again. It should connect **without** asking for a password.
5. Tell Claude your username and IP (**never the password**). From here, Claude can do setup over SSH.

**Done when:** `ssh yourusername@IP` logs in with no password prompt.

---

## Phase 5b: This repo + Claude on the server (15 min)

This folder lives in the private GitHub repo `DrKingSchultz69/home-server`, so Claude on the server gets the same plan and notes.

1. On the server, install the GitHub CLI and sign in (pick GitHub.com, HTTPS, log in with a browser):
   ```bash
   sudo dnf install -y gh git && gh auth login
   ```
2. Download the repo into `~/Server`:
   ```bash
   gh repo clone DrKingSchultz69/home-server ~/Server
   ```
3. Install Claude Code on the server (instructions at claude.com/claude-code), then run `claude` inside `~/Server`.
4. **Keep both machines in sync:** run `git pull` before you start working, and `git add -A && git commit -m "what changed" && git push` when you finish.

**Done when:** `claude` on the server can see `CLAUDE.md` and this plan.

---

## Phase 6: Tailscale, the private network (30 min)

1. **Claude, over SSH:** install Tailscale on the server and start it with Tailscale SSH turned on.
2. **You:** open the login link it prints and sign in. Use an account with **2FA through an authenticator app or hardware key, not SMS**.
3. **You:** install Tailscale on the laptop and the Galaxy S24, and sign in with the same account.
4. **You:** in the Tailscale admin console, turn on **Device approval**. Leave **key expiry** on.
5. **Test:** turn off Wi-Fi on the phone, use mobile data, and open the server's Tailscale address.

**Done when:** the phone reaches the server on mobile data.

---

## Phase 7: Lock it down (40 min)

All of these are from your confirmed design.

1. **Access rules (ACLs):** your laptop and phone reach everything; any other device reaches nothing yet. Claude drafts the rules, you paste them into the admin console.
2. **Tailscale SSH in check mode:** SSH asks you to sign in again, so an unlocked phone alone isn't enough.
3. **Firewall (firewalld):** on home Wi-Fi, block everything for now. Streaming gets opened in Phase 10. Then the local SSH from Phase 5 is closed, and SSH goes through Tailscale only.
4. **Automatic security updates:** turn on Fedora's automatic updates (dnf5 automatic), set to install security updates.
5. **Your phone:** strong screen lock, and **Find My Device** turned on for remote wipe.

**Done when:** SSH works through Tailscale only, and `ssh` to the home Wi-Fi IP is refused.

**Lost device plan** (keep this):
1. Tailscale admin console: remove the device. Its access is cut instantly.
2. Sign out of all sessions on your login account and change the password.
3. Remote wipe through Find My Device.
4. Rotate anything the device stored: SSH keys, app tokens, API keys.

---

## Phase 8: Netheron workspace (1 hour, decide together first)

Already decided:
- Netheron listens on the **Tailscale IP only**, never `0.0.0.0`. Port 4141 is never reachable from outside.
- Netheron keeps its own login and access token. Never "trust localhost".
- Your API keys stay in your user's files with `chmod 600`.

To decide together before building:
1. Where your projects live on the server (folder layout on the 1 TB SSD (Acer RE100)).
2. How many agents to run at once on 8 GB of RAM.

**Done when:** `/health` on port 4141 answers from your phone over Tailscale, and not from home Wi-Fi.

---

## Phase 9: File access (30–60 min, decide together first)

Already decided: files are reachable only from your laptop and phone, over Tailscale.

To decide together:
1. **How** you want to reach files: in a browser, synced folders, or a network drive in Windows.
2. Which folders, and whether any are shared with family.

**Done when:** you open a server file from your phone over Tailscale.

---

## Phase 10: Streaming site (1–2 evenings, decide together first)

Already decided:
- Reachable from **home Wi-Fi** (the TV) and **Tailscale** (family and you). Nothing public.
- The site has its own login.
- Isolation: separate `streamer` user with no shell, a rootless container running **as `streamer`**, media mounted read-only, its own container network, no access to the container socket. No VM.

To decide together:
1. Build your own streaming website, or use a ready-made media server.
2. Which video formats the TV's browser or app can play.
3. Whether your home **upload** speed handles family streaming away from home.

**Done when:** the TV plays a video over home Wi-Fi, and your phone plays one on mobile data.

---

## Phase 11: Family access (20 min per person)

1. Check how many users the **Tailscale free plan** allows.
2. Invite one family member and help them install Tailscale and sign in.
3. Approve their device in the admin console. **Only approve devices you know are safe.**
4. Add an access rule: their devices reach **streaming only**.
5. Test: they stream on mobile data, and **can't** reach Netheron, SSH or files.

**Done when:** one family member streams away from home. Then repeat for the others.

---

## Later (not now)

- Minecraft game server (about 3 GB of RAM: can't run at the same time as heavy AI work).
- Backups for the single SSD.
- Status dashboard and automatic restarts.
- Upgrades: +8 GB RAM, an SSD for Fedora.
- Fix the desktop's 100 Mbps Ethernet link (should be 1 Gbps). Already ruled out: the card (Realtek PCIe GBE, gigabit), "Speed & Duplex" (Auto), Energy Efficient Ethernet and Green Ethernet (both now Disabled), and the cable category (Cat 6 and Cat 6e). Next test: reseat the plug at both ends, then try the router port the laptop uses (the laptop gets 1 Gbps there).

---

## Notes

- Server local IP: 192.168.29.218 (Ethernet)
- Server Tailscale name: homeserver (100.114.125.48). Laptop: desktop-sb5io1v (100.91.27.57). Phone: shais-s24 (100.100.141.115).
- Fedora username: palani
