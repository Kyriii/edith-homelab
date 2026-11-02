# Edith — a hardened Debian home server

Edith is an old Dell Inspiron 15 laptop that I wiped and rebuilt as an always-on Linux server. She runs my small business's content-automation agents, blocks ads and trackers for every device in the house, and backs herself up to AWS every night.

I built this to get hands-on with the Linux, networking, security and AWS skills I'm studying for the **AWS Solutions Architect – Associate** exam.

---

## At a glance

| Area | What I did |
|---|---|
| **OS** | Wiped Windows, installed **Debian 13 (trixie)** from a USB I made with Rufus. Switched the disk controller from Intel RST to AHCI so Linux could see the NVMe drive. |
| **Always-on** | Masked all sleep/suspend targets so it runs lid-closed 24/7. Automatic daily security updates (`unattended-upgrades`). |
| **Remote access** | Managed headless from my PC over **SSH with keys only**. Password and root logins disabled. VS Code Remote-SSH for editing code on the server. |
| **Firewall** | `ufw`, **deny-by-default inbound**. Only SSH, DNS and the AdGuard dashboard are allowed, and only from the home subnet. Nothing is port-forwarded from the internet. |
| **Network** | Rebuilt the home network: ISP hub in **modem mode**, mesh Wi-Fi as the router (removed double NAT), fixed DHCP reservation for the server. |
| **DNS / ad-blocking** | **AdGuard Home** as the DNS server for the whole house via DHCP, with encrypted upstreams (DNS-over-HTTPS) in parallel and optimistic caching. ~17% of lookups blocked. |
| **Automation** | Cron runs my Python content agents: daily draft → Telegram approval → scheduled publish to Instagram (images handed off via S3 pre-signed URLs). |
| **Backups** | Nightly sync to **Amazon S3** — versioned, encrypted, private, with a lifecycle rule that expires old versions after 30 days. |
| **AWS security** | Dedicated **least-privilege IAM users** per job; access keys rotated; zero-spend budget and cost-anomaly monitoring. |
| **Firmware** | Updated the Dell BIOS (1.34 → 1.46) and Secure Boot key databases from Linux using `fwupd`. |

---

## Architecture

```
Internet
   │
ISP hub (modem mode)
   │
Mesh Wi-Fi router (DHCP: hands out Edith as DNS for every device)
   │
   ├── PC / phones / TV / smart devices ──DNS──► Edith : AdGuard Home ──DoH──► Cloudflare / Quad9
   │
   └── Edith (Debian)
         ├─ ufw: deny inbound except SSH/DNS/dashboard from LAN
         ├─ cron: content agents  ──► Telegram, Instagram API, Anthropic API, S3 (outbound only)
         └─ cron 03:00: backup.sh ──► Amazon S3 (versioned, encrypted, lifecycle)
```

All of Edith's work is **outbound**. Telegram approvals work by polling, so the firewall never has to open anything to the internet.

---

## Security decisions

- **Keys-only SSH.** A key can't be guessed; passwords can. `sudo` still asks for a password as a second lock.
- **Firewall even behind a router.** The router already blocks the internet, but the firewall protects Edith from *other devices on the LAN* (cheap IoT gear is the usual weak spot). Defence in depth.
- **Least privilege in AWS.** The backup user can list, read and write **one bucket only**. It deliberately *can't* delete old object versions, so a stolen key couldn't wipe the backup history. The publisher user is limited to its own bucket the same way.
- **Secrets live in one place.** API keys sit in a `chmod 600` file on the server only. I rotated the AWS key after finding the original in a Downloads folder, and deleted every old copy.

---

## Backups

`backup.sh` runs nightly from cron:

- syncs the agents' project folder to S3 (excluding the Python venv and caches)
- syncs a config folder: AdGuard settings, firewall rules, the crontab and the backup script itself
- a root cron job copies the root-owned config files into that folder five minutes earlier

So if the laptop dies, the code **and** the server setup can be rebuilt from S3.

See [`backup.sh`](backup.sh) and [`iam-backup-policy.json`](iam-backup-policy.json).

---

## Incident: the router change that took the house offline

**What happened:** while moving the network to the mesh router, I put the ISP hub into modem mode *before* the mesh had actually switched to router mode. Nothing was handing out IP addresses, so the whole house lost internet, and the hub's recovery page was unreachable.

**How I recovered:** factory-reset the hub (holding the reset pin ~15 s), waited for it to re-register with the ISP, then rebuilt its settings: Wi-Fi off, new admin password, the server's DHCP reservation.

**What I changed:** the next night I did it in the right order (mesh → router mode first, confirmed while still online, then hub → modem mode). It worked first time in about 10 minutes, with no outage beyond the hub's restart. I also verified the result properly instead of trusting the app: `tracert` to confirm single NAT, and `upnpc -s` to confirm UPnP and a public WAN IP.

**Lesson:** change the downstream device first, confirm it, then change the upstream one. And always know your rollback before you start.

---

## What's next

- CloudWatch logs + alarm (via SNS email) if a scheduled post fails
- Wired Ethernet for the server (it's DNS for the whole house now)
- Tailscale for secure remote access and ad-blocking away from home
- Docker, Uptime Kuma monitoring, Grafana/Prometheus dashboards
- GitHub Actions to auto-deploy agent code to the server

---

## Tools

Debian · Bash · cron · OpenSSH · ufw · AdGuard Home · fwupd · Python · AWS (S3, IAM, Budgets) · AWS CLI · Telegram Bot API · Instagram Graph API · Git
