# Chapter 01: Server Setup

[← README](./README.md) | [Home](./README.md) | [Next: OpenClaw Install →](./02_OPENCLAW_INSTALL.md)

---

> **Goal:** A hardened Hetzner VPS running Docker, ready to host your SecondBrain.

Your AI second brain needs a home -- a small, cheap, always-on server that you fully control. No shared hosting. No cloud functions. Just a Linux box with Docker that runs 24/7 for ~EUR 4/month.

---

## Table of Contents

- [Why Hetzner](#why-hetzner)
- [Step 1: Generate SSH Keys](#step-1-generate-ssh-keys)
- [Step 2: Create the Server](#step-2-create-the-server)
- [Step 3: First Login and Updates](#step-3-first-login-and-updates)
- [Step 4: Firewall with UFW](#step-4-firewall-with-ufw)
- [Step 5: Fail2ban for SSH Protection](#step-5-fail2ban-for-ssh-protection)
- [Step 6: Install Docker](#step-6-install-docker)
- [Step 7: Create Directory Structure](#step-7-create-directory-structure)
- [Step 8: Create a Dedicated User](#step-8-create-a-dedicated-user)
- [Verify Everything](#verify-everything)

---

## Why Hetzner

| Spec | CX22 |
|------|-------|
| vCPUs | 2 (shared) |
| RAM | 4 GB |
| Storage | 40 GB NVMe SSD |
| Traffic | 20 TB/month |
| Location | Falkenstein, Nuremberg, or Helsinki |
| Price | ~EUR 3.99/month |

This is more than enough. OpenClaw itself is lightweight -- the heavy lifting happens on Google's API servers. Your server just needs to run the agent process and store your vault files.

Alternatives that work fine: any VPS with 2+ GB RAM running Ubuntu 22.04 or later. DigitalOcean, Vultr, and OVH all work. The instructions below are Ubuntu-specific but adapt easily.

---

## Step 1: Generate SSH Keys

If you already have an SSH key pair, skip this step.

On your **local machine** (not the server):

```bash
ssh-keygen -t ed25519 -C "secondbrain-server"
```

Press Enter to accept the default path (`~/.ssh/id_ed25519`). Set a passphrase if you want extra security.

This creates two files:
- `~/.ssh/id_ed25519` -- your private key (never share this)
- `~/.ssh/id_ed25519.pub` -- your public key (upload this to Hetzner)

Copy the public key to your clipboard:

```bash
# macOS
cat ~/.ssh/id_ed25519.pub | pbcopy

# Linux
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard

# Windows (PowerShell)
Get-Content ~/.ssh/id_ed25519.pub | Set-Clipboard
```

---

## Step 2: Create the Server

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Create a new project called **SecondBrain**
3. Click **Add Server** with these settings:

| Setting | Value |
|---------|-------|
| Location | Falkenstein (cheapest) or your nearest |
| Image | Ubuntu 24.04 |
| Type | Shared vCPU - CX22 |
| SSH Key | Paste your public key from Step 1 |
| Name | `secondbrain` |

4. Click **Create & Buy Now**

Within 30 seconds you will have a server. Note the IP address -- you will need it for everything that follows.

Add it to your SSH config for convenience. On your local machine:

```bash
cat >> ~/.ssh/config << 'EOF'
Host secondbrain
    HostName YOUR_SERVER_IP_HERE
    User root
    IdentityFile ~/.ssh/id_ed25519
EOF
```

Replace `YOUR_SERVER_IP_HERE` with the actual IP.

---

## Step 3: First Login and Updates

```bash
ssh secondbrain
```

You should see the Ubuntu welcome message. Now update everything:

```bash
apt update && apt upgrade -y
```

Set the timezone to your location:

```bash
timedatectl set-timezone Europe/Berlin
```

> **Alex's note:** I use `Europe/Berlin` because that is where I live. If you are elsewhere, run `timedatectl list-timezones` to find yours. The timezone matters for automated routines like morning briefings.

Reboot if the kernel was updated:

```bash
reboot
```

Wait 10 seconds, then SSH back in.

---

## Step 4: Firewall with UFW

UFW (Uncomplicated Firewall) blocks everything except what you explicitly allow. Right now, you only need SSH.

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw enable
```

Type `y` to confirm. Verify:

```bash
ufw status verbose
```

Expected output:

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

> **Important:** Do not add any other ports yet. OpenClaw binds to localhost only, so it does not need a firewall rule. We will add ports later only if you set up a reverse proxy (Chapter 06).

---

## Step 5: Fail2ban for SSH Protection

Fail2ban watches your SSH logs and bans IP addresses that fail too many login attempts.

```bash
apt install -y fail2ban
```

Create a local configuration:

```bash
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
```

This bans any IP for 1 hour after 3 failed SSH attempts within 10 minutes.

Start and enable:

```bash
systemctl enable fail2ban
systemctl start fail2ban
```

Check status:

```bash
fail2ban-client status sshd
```

---

## Step 6: Install Docker

Install Docker Engine from the official repository. Do not use the Ubuntu `docker.io` package -- it is often outdated.

```bash
# Add Docker's GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verify the installation:

```bash
docker --version
docker compose version
```

You should see something like:

```
Docker version 27.x.x, build xxxxxxx
Docker Compose version v2.x.x
```

Docker is now running and will start automatically on boot.

---

## Step 7: Create Directory Structure

```bash
mkdir -p /opt/openclaw/config
mkdir -p /opt/SecondBrain
```

| Directory | Purpose |
|-----------|---------|
| `/opt/openclaw/` | Docker Compose file and runtime data |
| `/opt/openclaw/config/` | OpenClaw configuration (openclaw.json) |
| `/opt/SecondBrain/` | Your vault -- all the Markdown files |

Initialize the vault as a Git repository for version history:

```bash
cd /opt/SecondBrain
git init
git config user.name "SecondBrain"
git config user.email "secondbrain@localhost"
```

This gives you a full history of every change the AI makes to your vault. You can review diffs, revert changes, and understand exactly what happened and when.

---

## Step 8: Create a Dedicated User

Running containers as root is fine for setup, but OpenClaw should run as a non-root user inside the container. Create a user with UID 1000 to match the container's default:

```bash
useradd -u 1000 -m -s /bin/bash openclaw
```

Set ownership on the directories:

```bash
chown -R openclaw:openclaw /opt/openclaw
chown -R openclaw:openclaw /opt/SecondBrain
```

> **Why UID 1000?** Docker containers often run processes as UID 1000 by default. Matching UIDs between host and container avoids file permission issues when the container writes to mounted volumes.

---

## Verify Everything

Run through this checklist before moving on:

```bash
# SSH works
ssh secondbrain

# Firewall is active
ufw status

# Fail2ban is running
fail2ban-client status sshd

# Docker works
docker run --rm hello-world

# Directories exist with correct ownership
ls -la /opt/openclaw/
ls -la /opt/SecondBrain/

# Git is initialized
cd /opt/SecondBrain && git status
```

If all checks pass, your server is ready.

---

## What We Built

```
Hetzner CX22 (EUR 3.99/month)
├── Ubuntu 24.04
├── UFW (only port 22 open)
├── Fail2ban (SSH brute-force protection)
├── Docker + Docker Compose
├── /opt/openclaw/          ← agent runtime
│   └── config/             ← configuration files
└── /opt/SecondBrain/       ← your vault (git-tracked)
```

Your server is hardened, minimal, and ready for the next step.

---

[← README](./README.md) | [Home](./README.md) | [Next: OpenClaw Install →](./02_OPENCLAW_INSTALL.md)
