# 06 — Stage 1: Make It Autonomous

Stage 0 runs when you open it. This stage gives the vault a machine that does not
sleep, a chat interface so you can reach it from a phone, and two scheduled jobs. It
is the point where the system starts doing things you did not ask for that morning.

> A laptop's sleep schedule becomes your system's availability. That is the entire argument for a separate host.

**Verification note.** The commands in this chapter were transcribed from a running
installation rather than executed from zero while writing. Treat them as a correct
description that has not been re-tested end to end; expect to adjust a package name
or a path. Everything in Parts 3 through 6 was exercised against a live system.

---

## 1. The host

The smallest tier any provider sells is enough: 2 vCPU, 4 GB RAM, 40 GB disk, around
five euros a month. This workload is almost entirely waiting on network calls.

Create it with an SSH key rather than a password, and pick a location near you for
latency on interactive use.

```bash
ssh-keygen -t ed25519 -C "vault-host"      # if you do not have a key
ssh root@<host-ip>
```

## 2. Harden it before anything else runs

Do this first, not in an appendix. A machine holding a decade of your notes and a
model API key is worth attacking, and the window between provisioning and hardening
is the one that gets used.

```bash
adduser --disabled-password --gecos "" agent
usermod -aG sudo agent
install -d -m 700 -o agent -g agent /home/agent/.ssh
cp /root/.ssh/authorized_keys /home/agent/.ssh/
chown agent:agent /home/agent/.ssh/authorized_keys
chmod 600 /home/agent/.ssh/authorized_keys
```

Disable password and root login:

```bash
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh
```

Firewall closed except SSH:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable
```

Unattended security updates:

```bash
apt update && apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

Open a second terminal and confirm you can log in as `agent` **before closing the
first one.** Locking yourself out of a fresh box is cheap; locking yourself out of a
configured one is not.

## 3. Docker and the vault

```bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker agent
```

Then, as `agent`:

```bash
sudo install -d -o agent -g agent /opt/vault
cd /opt/vault
git clone <your-private-vault-remote> .
```

If the vault is not in a remote yet, push it from your laptop first. Chapter 07 makes
this bidirectional; for now the server needs a copy.

## 4. The runtime

An agent runtime is a process that holds a model connection, a set of tools that can
read and write files, a chat transport, and a scheduler. This guide uses OpenClaw;
anything with those four properties fits the same shape, because the vault is the
contract and the runtime is a client.

`docker-compose.yml`:

```yaml
services:
  agent:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: agent
    restart: unless-stopped
    env_file:
      - /etc/vault-secrets.env        # never inline secrets here
    volumes:
      - /opt/vault:/workspace         # the vault, read-write
      - ./config:/config
    ports:
      - "127.0.0.1:3578:3578"         # localhost only — see below
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:3578/health"]
      interval: 60s
      timeout: 5s
      retries: 3
```

**The `127.0.0.1:` prefix on the port is not cosmetic.** Docker publishes ports by
manipulating the firewall directly, so `- "3578:3578"` exposes the service to the
internet *past* the `ufw` rules configured above. Binding to loopback is what keeps it
private. This is the single most common way a self-hosted agent ends up reachable by
strangers.

The secrets file, root-owned and unreadable by anyone else:

```bash
sudo install -m 600 -o root -g root /dev/null /etc/vault-secrets.env
sudo tee /etc/vault-secrets.env > /dev/null <<'EOF'
MODEL_API_KEY=...
CHAT_BOT_TOKEN=...
CHAT_ALLOWED_ID=...
EOF
```

Start it:

```bash
docker compose up -d && docker compose ps
```

## 5. The chat interface

A chat transport is what makes the system reachable without a terminal, and it is what
turns capture from a task into a reflex. Any messaging platform with a bot API works;
the requirements are the same in each case:

| Requirement | Why |
|---|---|
| A bot token, in the secrets file | Never in the compose file or a note |
| An allow-list of exactly your own account ID | Without it, anyone who finds the bot can read your vault |
| Text and file upload | Files are how transcripts and documents arrive |

The allow-list is the part to get right on the first try. A bot with no sender check
is an open door to everything in `/opt/vault`.

Send it a message from your phone. `n: testing from the train` should produce a file in
the inbox, on the server, which you can verify over SSH.

## 6. Two scheduled jobs

Start with exactly two. They cover both directions — one reads to you, one writes for
you — and together they establish the pattern.

**A morning briefing, 07:00.** Reads today's date note and calendar file, sends a
short message. Its contract lives in a skill, and it must state what to do when an
input is stale rather than guessing — chapter 02's freshness rule, applied on the first
job you write.

**An evening entry, 21:00.** Writes into today's note and sets a completion marker:

```markdown
<!-- generated: 2026-03-15 -->
```

That marker is why this job comes second rather than fifth. It is the thing chapter
21's completeness check asserts on, and until something writes it there is nothing to
check.

Schedule them with the runtime's own scheduler if it has one, or with cron:

```bash
crontab -e
```

```
0 7 * * * docker exec agent /usr/local/bin/run-skill morning-briefing >> /var/log/agent-cron.log 2>&1
0 21 * * * docker exec agent /usr/local/bin/run-skill evening-weave >> /var/log/agent-cron.log 2>&1
```

Redirect both streams to a log. A cron job's output goes nowhere by default, and
chapter 20's eighth row is a daily error nobody read because it went to a log rather
than a channel — the log is the minimum, not the goal.

## 7. Verify, then wait

```bash
docker compose ps                              # up and healthy
docker compose logs --tail 30                  # no repeating errors
ls -la /opt/vault/00_Start/Inbox/              # the message from your phone
```

Then leave it for two days and look at what it produced. Read the briefing it sent and
the entries it wrote. This is the last stage where you can still evaluate the output by
eye against everything it did, and it is worth spending.

## What you have, and the risk you just took on

**Have:** a system that runs without you, reachable from a phone, producing something
every morning and every evening.

**Took on:** a machine you are responsible for, and the failure class that Part 5
exists for. From this moment the system can stop working without telling you — a job
that exits zero and does nothing, a token that expires, a briefing that reads
confidently from a stale file.

Two jobs and two days of watching is manageable by eye. Six jobs is not, and the
gap between assuming you would notice and nothing noticing for three weeks is smaller
than it feels. If you add nothing else, add the watchdog from chapter 21 before the third
scheduled job.

---

**Read next:** [07 — Stage 2: Close the Loop](./07_stage-2-close-the-loop.md), which
gets the vault onto your other devices without the two copies fighting.
