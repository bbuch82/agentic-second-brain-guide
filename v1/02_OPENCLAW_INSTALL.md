# Chapter 02: OpenClaw Install

[← Server Setup](./01_SERVER_SETUP.md) | [Home](./README.md) | [Next: SecondBrain Structure →](./03_SECONDBRAIN_STRUCTURE.md)

---

> **Goal:** Deploy OpenClaw in Docker with a production-grade configuration and connect it to your vault.

OpenClaw is the engine that powers your SecondBrain. It is an open-source AI agent runtime that connects language models to your files, executes tools, manages conversations, and runs automated routines. Think of it as the brain; your vault is the memory.

This chapter walks through every line of the configuration so you understand exactly what your agent is doing and why.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [The docker-compose.yml](#the-docker-composeyml)
- [The openclaw.json](#the-openclawjson)
- [Deploy](#deploy)
- [Gateway Auth and Device Pairing](#gateway-auth-and-device-pairing)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              Docker Container                │
│                                              │
│  ┌──────────┐    ┌──────────────────────┐   │
│  │ OpenClaw │    │  /config/            │   │
│  │ Runtime  │───►│  openclaw.json       │   │
│  │          │    │  (your settings)     │   │
│  └────┬─────┘    └──────────────────────┘   │
│       │                                      │
│       ▼                                      │
│  ┌──────────┐    ┌──────────────────────┐   │
│  │ Gateway  │    │  /workspace/         │   │
│  │ :3578    │    │  /opt/SecondBrain    │   │
│  │ (local)  │    │  (your vault)        │   │
│  └──────────┘    └──────────────────────┘   │
│                                              │
└─────────────────────────────────────────────┘
         │
    localhost:3578
    (not exposed to internet)
```

The container exposes a single port on localhost for the gateway API. Telegram connects through this gateway. Your vault is mounted as a volume so the agent can read and write Markdown files directly.

---

## The docker-compose.yml

Here is the full production Compose file. Copy it to `/opt/openclaw/docker-compose.yml` or use the example file from [`examples/docker-compose.yml`](./examples/docker-compose.yml).

```yaml
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped

    # --- Security Hardening ---
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /tmp:size=100M,noexec,nosuid
      - /run:size=10M,noexec,nosuid

    # --- Resource Limits ---
    deploy:
      resources:
        limits:
          cpus: "1.5"
          memory: 2G
        reservations:
          cpus: "0.25"
          memory: 256M

    # --- Network ---
    ports:
      - "127.0.0.1:3578:3578"

    # --- Volumes ---
    volumes:
      - ./config/openclaw.json:/config/openclaw.json:ro
      - /opt/SecondBrain:/workspace
      - openclaw-data:/data

    # --- Environment ---
    environment:
      - OPENCLAW_CONFIG=/config/openclaw.json
      - TZ=Europe/Berlin

    # --- Health Check ---
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3578/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s

    # --- Logging ---
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  openclaw-data:
    driver: local
```

### Line-by-line Walkthrough

**Security hardening:**

| Setting | What It Does |
|---------|-------------|
| `read_only: true` | Makes the container filesystem read-only. The agent cannot modify its own binaries. |
| `no-new-privileges` | Prevents processes from gaining additional privileges via setuid/setgid. |
| `cap_drop: ALL` | Removes all Linux capabilities. The container cannot mount filesystems, change owners, or do anything privileged. |
| `tmpfs` mounts | Provides writable scratch space in RAM only. The `noexec` flag prevents executing binaries from temp directories. |

**Resource limits:**

| Setting | Value | Why |
|---------|-------|-----|
| CPU limit | 1.5 cores | Prevents runaway processes from starving the host |
| Memory limit | 2 GB | More than enough; OpenClaw typically uses 200-400 MB |
| CPU reservation | 0.25 cores | Guarantees minimum CPU even under host load |
| Memory reservation | 256 MB | Guarantees minimum memory |

**Network:**

```yaml
ports:
  - "127.0.0.1:3578:3578"
```

The `127.0.0.1` prefix is critical. It binds the port to localhost only. Without it, Docker would expose port 3578 to the internet, **bypassing UFW entirely**. This is a common Docker security pitfall.

**Volumes:**

| Mount | Purpose |
|-------|---------|
| `./config/openclaw.json:/config/openclaw.json:ro` | Configuration file, mounted read-only |
| `/opt/SecondBrain:/workspace` | Your vault. The agent reads and writes here. |
| `openclaw-data:/data` | Persistent data (conversation history, tokens, internal state) |

**Health check:** The gateway exposes a `/health` endpoint. Docker checks it every 30 seconds and restarts the container if it fails 3 times in a row.

**Logging:** JSON log files capped at 10 MB with 3 rotations. Prevents disk space exhaustion from verbose logs.

---

## The openclaw.json

This is the brain of your agent. Copy it to `/opt/openclaw/config/openclaw.json` or use the example from [`examples/openclaw.json`](./examples/openclaw.json).

```json
{
  "version": "1.0",
  "instance": {
    "name": "SecondBrain",
    "description": "Personal AI assistant managing an Obsidian vault",
    "workspace": "/workspace"
  },
  "auth": {
    "profiles": {
      "google": {
        "provider": "google",
        "api_key": "YOUR_GOOGLE_AI_API_KEY_HERE"
      }
    }
  },
  "models": {
    "default": {
      "profile": "google",
      "model": "gemini-2.0-flash",
      "temperature": 0.3,
      "max_output_tokens": 8192
    },
    "reasoning": {
      "profile": "google",
      "model": "gemini-2.5-pro",
      "temperature": 0.2,
      "max_output_tokens": 16384
    }
  },
  "agent": {
    "model": "default",
    "subagent_model": "reasoning",
    "system_files": [
      "SECURITY.md",
      "IDENTITY.md",
      "SOUL.md",
      "AGENTS.md",
      "TOOLS.md",
      "HEARTBEAT.md",
      "USER.md",
      "MEMORY.md"
    ],
    "compaction": {
      "enabled": true,
      "trigger_tokens": 80000,
      "target_tokens": 20000,
      "preserve_recent": 10
    },
    "subagents": {
      "max_concurrent": 3,
      "timeout_seconds": 120,
      "max_depth": 2
    }
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 3578,
    "auth": {
      "enabled": true,
      "token_hash": "YOUR_GATEWAY_TOKEN_HASH_HERE"
    }
  },
  "tools": {
    "file_read": { "enabled": true },
    "file_write": { "enabled": true },
    "file_search": { "enabled": true },
    "directory_list": { "enabled": true },
    "bash": {
      "enabled": true,
      "allowed_commands": ["git", "date", "wc", "sort", "head", "tail", "grep", "find"]
    },
    "web_fetch": { "enabled": false }
  },
  "routines": {
    "enabled": true,
    "config_path": "/workspace/HEARTBEAT.md"
  },
  "logging": {
    "level": "info",
    "file": "/data/openclaw.log"
  }
}
```

### Configuration Walkthrough

**Instance settings:**

- `name` -- displayed in logs and the gateway UI
- `workspace` -- the root path where the agent reads/writes files. Maps to your vault via the Docker volume mount.

**Auth profiles:**

You only need one: your Google AI API key. Get it from [Google AI Studio](https://aistudio.google.com/apikey).

```json
"google": {
  "provider": "google",
  "api_key": "YOUR_GOOGLE_AI_API_KEY_HERE"
}
```

> **Cost note:** Gemini Flash is extremely cheap (often free within daily limits). Gemini Pro costs more but is only used for subagent tasks that require deeper reasoning. Alex's typical usage costs under EUR 2/month.

**Model configuration:**

| Model | Used For | Why |
|-------|----------|-----|
| `gemini-2.0-flash` (default) | Main conversation, daily routines, file operations | Fast, cheap, good enough for 90% of tasks |
| `gemini-2.5-pro` (reasoning) | Subagent tasks: analysis, extraction, complex writing | Smarter, slower, used sparingly |

Low temperatures (0.2-0.3) keep the agent consistent and factual. Raise them if you want more creative writing.

**System files:**

```json
"system_files": [
  "SECURITY.md",
  "IDENTITY.md",
  "SOUL.md",
  "AGENTS.md",
  "TOOLS.md",
  "HEARTBEAT.md",
  "USER.md",
  "MEMORY.md"
]
```

These files from your vault root are loaded into the agent's system prompt on every conversation. They define who the agent is, what it can do, and how it behaves. See [Chapter 04: System Files](./04_SYSTEM_FILES.md) for the full breakdown.

**Compaction:**

```json
"compaction": {
  "enabled": true,
  "trigger_tokens": 80000,
  "target_tokens": 20000,
  "preserve_recent": 10
}
```

Long conversations consume tokens. Compaction automatically summarizes older messages when the context reaches 80,000 tokens, compressing down to 20,000 while preserving the 10 most recent exchanges. This keeps conversations flowing without hitting context limits or exploding costs.

**Subagents:**

```json
"subagents": {
  "max_concurrent": 3,
  "timeout_seconds": 120,
  "max_depth": 2
}
```

- `max_concurrent: 3` -- at most 3 subagents running at once (protects API rate limits)
- `timeout_seconds: 120` -- kill any subagent that takes longer than 2 minutes
- `max_depth: 2` -- subagents can spawn their own subagents, but only 2 levels deep

**Tools:**

The `bash` tool is restricted to a whitelist of safe commands. `git` is included so the agent can commit vault changes. `web_fetch` is disabled by default -- enable it in [Chapter 09](./09_SCRIPTS_AND_TOOLS.md) when you set up the reading pipeline.

**Routines:**

Points to your `HEARTBEAT.md` file, which defines scheduled tasks. See [Chapter 07: Cron Automation](./07_CRON_AUTOMATION.md).

---

## Deploy

SSH into your server and place the files:

```bash
ssh secondbrain
```

If you have not already, copy the example files:

```bash
# Create the config file
nano /opt/openclaw/config/openclaw.json
# (paste your openclaw.json contents)

# Create the compose file
nano /opt/openclaw/docker-compose.yml
# (paste your docker-compose.yml contents)
```

Or clone this guide repo and copy them:

```bash
cd /opt/openclaw
cp /path/to/SecondBrain-Guide/examples/docker-compose.yml .
cp /path/to/SecondBrain-Guide/examples/openclaw.json ./config/
```

**Edit the config** -- replace the placeholders:

```bash
nano /opt/openclaw/config/openclaw.json
```

At minimum, replace:
- `YOUR_GOOGLE_AI_API_KEY_HERE` with your actual Google AI API key

Start the container:

```bash
cd /opt/openclaw
docker compose up -d
```

Check that it is running:

```bash
docker compose ps
```

Expected output:

```
NAME        IMAGE                            STATUS                   PORTS
openclaw    ghcr.io/openclaw/openclaw:latest  Up 30 seconds (healthy)  127.0.0.1:3578->3578/tcp
```

View the logs:

```bash
docker compose logs -f
```

You should see the agent loading system files, initializing tools, and starting the gateway. Press `Ctrl+C` to exit the log view.

---

## Gateway Auth and Device Pairing

The gateway requires an auth token to prevent unauthorized access. Even though it only listens on localhost, this adds defense in depth.

**Generate a token:**

```bash
# Generate a random token
TOKEN=$(openssl rand -hex 32)
echo "Save this token somewhere safe: $TOKEN"

# Generate the hash for the config
echo -n "$TOKEN" | sha256sum | awk '{print $1}'
```

**Update the config** with the hash:

```bash
nano /opt/openclaw/config/openclaw.json
```

Replace `YOUR_GATEWAY_TOKEN_HASH_HERE` with the sha256 hash output.

**Restart to apply:**

```bash
cd /opt/openclaw
docker compose restart
```

**Test the gateway:**

```bash
curl -H "Authorization: Bearer YOUR_TOKEN_HERE" http://localhost:3578/health
```

You should get:

```json
{"status": "ok", "version": "x.x.x"}
```

Save your token securely. You will need it when setting up the Telegram integration in [Chapter 05](./05_TELEGRAM_SETUP.md).

---

## Troubleshooting

### Container keeps restarting

```bash
docker compose logs --tail 50
```

Common causes:
- **Invalid JSON** in openclaw.json -- use `jq . /opt/openclaw/config/openclaw.json` to validate
- **Bad API key** -- test it with `curl` against the Google AI API directly
- **Permission denied on /workspace** -- check ownership: `ls -la /opt/SecondBrain`

### Port already in use

```bash
ss -tlnp | grep 3578
```

If another process uses port 3578, either stop it or change the port in both `docker-compose.yml` and `openclaw.json`.

### Container is unhealthy

```bash
docker inspect openclaw --format='{{json .State.Health}}'
```

Check if the gateway is actually responding:

```bash
docker compose exec openclaw wget -q -O- http://localhost:3578/health
```

### Agent cannot write to vault

```bash
# Check host permissions
ls -la /opt/SecondBrain

# Check container user
docker compose exec openclaw id

# Fix permissions if needed
chown -R 1000:1000 /opt/SecondBrain
```

### High memory usage

Check current usage:

```bash
docker stats openclaw --no-stream
```

If memory is consistently above 1.5 GB, lower `trigger_tokens` in the compaction config or reduce `max_concurrent` subagents.

### Updating OpenClaw

```bash
cd /opt/openclaw
docker compose pull
docker compose up -d
```

This pulls the latest image and recreates the container. Your data persists in the named volume and your vault is on the host filesystem.

---

## What We Built

```
/opt/openclaw/
├── docker-compose.yml         ← container definition
├── config/
│   └── openclaw.json          ← agent brain config
└── (docker volume: openclaw-data)  ← persistent runtime data

Container: openclaw
├── Listening on localhost:3578
├── Connected to /opt/SecondBrain (your vault)
├── Using Gemini Flash (fast) + Pro (reasoning)
└── Security: read-only FS, no privileges, capped resources
```

The engine is running. Now we need to give it something to work with.

---

[← Server Setup](./01_SERVER_SETUP.md) | [Home](./README.md) | [Next: SecondBrain Structure →](./03_SECONDBRAIN_STRUCTURE.md)
