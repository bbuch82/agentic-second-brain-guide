# Chapter 11: Advanced Tips

← [Previous: Daily Workflow](./10_DAILY_WORKFLOW.md) | [Home](./README.md) | [Back to Home](./README.md) →

---

This chapter covers the operational side -- keeping your system backed up, costs under control, performance tuned, and security tight. These are the things that separate a weekend project from a system you'll rely on for years.

---

## Table of Contents

- [Backup Strategy](#backup-strategy)
- [Cost Breakdown](#cost-breakdown)
- [Model Tuning](#model-tuning)
- [Advanced Memory: Vector Search and Embeddings](#advanced-memory-vector-search-and-embeddings)
- [Compaction and Context Management](#compaction-and-context-management)
- [Docker Updates and Maintenance](#docker-updates-and-maintenance)
- [Security Hardening](#security-hardening)
- [Performance at Scale (10k+ Files)](#performance-at-scale-10k-files)

---

## Backup Strategy

Your Second Brain contains years of thoughts, contacts, and insights. Losing it would be devastating. Run **two independent backup strategies** so that a single failure never costs you data.

### Layer 1: Git Auto-Push

Your Obsidian vault is already a Git repository (set up in [Chapter 6](./06_OBSIDIAN_SETUP.md)). Add an automated push to a private remote:

```bash
# Create a backup script
cat > /home/alex/SecondBrain/99_Assets/Scripts/git_backup.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

VAULT="/home/alex/SecondBrain"
cd "$VAULT"

# Stage all changes
git add -A

# Only commit if there are changes
if ! git diff --cached --quiet; then
    git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M')"
    git push origin main
    echo "[$(date)] Backup pushed successfully"
else
    echo "[$(date)] No changes to back up"
fi
SCRIPT

chmod +x /home/alex/SecondBrain/99_Assets/Scripts/git_backup.sh
```

Schedule it to run every 6 hours:

```bash
# Add to crontab
crontab -e

# Git backup every 6 hours
0 */6 * * * /home/alex/SecondBrain/99_Assets/Scripts/git_backup.sh >> /var/log/secondbrain/git-backup.log 2>&1
```

**Where to push:** A private GitHub or Gitea repository. If you're privacy-conscious, run your own Gitea instance on the same Hetzner account, or use a separate server.

### Layer 2: Hetzner Server Snapshots

Git handles text files well but doesn't version binary assets efficiently. Hetzner server snapshots give you full point-in-time recovery:

```bash
# Install hcloud CLI
# Download the latest release tarball from:
# https://github.com/hetznercloud/cli/releases
# Extract and move the binary to your PATH:
tar -xzf hcloud-linux-amd64.tar.gz
sudo mv hcloud /usr/local/bin/hcloud
chmod +x /usr/local/bin/hcloud

# Authenticate
hcloud context create secondbrain
# Enter your API token when prompted

# Create a snapshot of your server
hcloud server create-image --type snapshot --description "Weekly snapshot $(date +%Y-%m-%d)" <server-id>

# List existing snapshots
hcloud image list --type snapshot
```

Automate weekly snapshots:

```bash
# /home/alex/scripts/hetzner_snapshot.sh
#!/bin/bash
set -euo pipefail

SERVER_ID="your-server-id"
MAX_SNAPSHOTS=4  # Keep last 4 weeks

# Create new snapshot
hcloud server create-image --type snapshot \
  --description "Auto: $(date +%Y-%m-%d)" "$SERVER_ID"

# Clean up old snapshots (keep only MAX_SNAPSHOTS most recent)
SNAPSHOT_IDS=$(hcloud image list --type snapshot -o noheader -o columns=id | tail -n +$((MAX_SNAPSHOTS + 1)))
for id in $SNAPSHOT_IDS; do
    echo "Removing old snapshot $id"
    hcloud image delete "$id"
done

echo "[$(date)] Snapshot created, old ones cleaned"
```

```bash
# Weekly snapshot every Sunday at 3am
0 3 * * 0 /home/alex/scripts/hetzner_snapshot.sh >> /var/log/secondbrain/snapshot.log 2>&1
```

**Note:** Hetzner volumes do not support snapshots directly. Use server snapshots instead, or create snapshots via the Hetzner Cloud Console.

### Recovery Checklist

If something goes wrong, here's the priority order:

| Scenario | Recovery Method | Time to Recover |
|----------|----------------|-----------------|
| Accidental file deletion | `git checkout -- path/to/file` | 30 seconds |
| Corrupted vault | `git reset --hard HEAD~1` | 1 minute |
| Server disk failure | Restore from Hetzner server snapshot | 5-10 minutes |
| Complete server loss | New server + git clone + snapshot restore | 30-60 minutes |

---

## Cost Breakdown

One of the best things about this setup: it's remarkably affordable. Here's what Alex actually pays:

### Monthly Infrastructure

| Item | Cost | Notes |
|------|------|-------|
| Hetzner CX22 VPS | ~4.00/mo | 2 vCPU, 4 GB RAM, 40 GB disk |
| Hetzner Volume (20 GB) | ~0.96/mo | For vault data |
| Domain (optional) | ~1.00/mo | Amortized annual cost |
| **Infrastructure Total** | **~6.00/mo** | |

### Monthly API Costs

This is where it gets interesting. The cost depends heavily on which models you use and how much you interact:

| Usage Pattern | Model | Monthly Cost |
|---------------|-------|-------------|
| Daily messages (20-30/day) | Gemini 2.0 Flash | ~$2-4/mo |
| Wisdom extraction | Gemini 2.0 Flash | ~$0.50/mo |
| Weekly deep analysis | Gemini 2.5 Pro | ~$3-5/mo |
| Voice transcription | Whisper API | ~$1-2/mo |
| **API Total (light user)** | | **~$5-8/mo** |
| **API Total (heavy user)** | | **~$12-20/mo** |

### Why Gemini Flash Is the Sweet Spot

Gemini 2.0 Flash pricing (as of early 2026):

| Metric | Price |
|--------|-------|
| Input tokens | $0.10 per 1M tokens |
| Output tokens | $0.40 per 1M tokens |

For comparison, a typical daily interaction (30 messages, ~2,000 tokens each):

```
Daily input:  ~60,000 tokens = $0.006
Daily output: ~40,000 tokens = $0.016
Daily total:  $0.022
Monthly total: $0.66
```

That's less than a dollar a month for your daily AI interactions. Even with system prompts, context, and tool calls factored in, you're looking at $2-4/month for typical usage.

### Total Monthly Cost

| Tier | Monthly Cost | What You Get |
|------|-------------|--------------|
| Minimal | ~$8-10/mo | Server + Flash only, basic usage |
| Recommended | ~$12-15/mo | Server + Flash daily + Pro weekly analysis |
| Power user | ~$20-25/mo | Heavy usage, multiple subagents, deep analysis |

**Compare this to:** Notion AI ($10/mo), Mem.ai ($15/mo), or Reflect ($10/mo) -- and those don't give you full ownership, customization, or the agent capabilities.

---

## Model Tuning

Not every task needs the same model. Matching the right model to the right task saves money and improves response speed.

### Recommended Model Allocation

```yaml
# In your agent configuration

# Daily interactions - fast and cheap
daily_agent:
  model: "gemini-2.0-flash"
  use_for:
    - Message parsing and categorization
    - Todo extraction
    - Journal prompts
    - Quick Q&A about vault contents
    - Meal logging
    - Habit tracking

# Deep work - slower but more capable
analysis_agent:
  model: "gemini-2.5-pro"
  use_for:
    - Weekly intelligence briefings
    - Complex knowledge synthesis
    - Multi-document summarization
    - Strategic planning assistance
    - Writing longer content

# Subagent tasks - balance of speed and quality
subagents:
  model: "gemini-2.0-flash"
  use_for:
    - Web search and summarization
    - Contact enrichment
    - Reading note processing
```

### When to Upgrade Models

Switch from Flash to Pro when:

- The task requires reasoning across many documents
- You need nuanced analysis (not just extraction)
- Quality matters more than speed (e.g., weekly reports)
- The task involves creative writing or complex synthesis

Stay on Flash when:

- Parsing structured input (messages, todos, meals)
- Simple categorization and tagging
- Responding to straightforward questions
- Any high-frequency, low-complexity task

### Model Switching in Practice

Configure model selection in your `openclaw.json` agent configuration. Each agent profile can specify its own model:

```json
{
  "agents": {
    "chief_of_staff": {
      "model": "gemini-2.0-flash",
      "description": "Daily message parsing and briefing compilation"
    },
    "strategist": {
      "model": "gemini-2.5-pro",
      "description": "Weekly deep analysis and knowledge synthesis"
    }
  }
}
```

Refer to your OpenClaw documentation for the full set of configuration options.

---

## Advanced Memory: Vector Search and Embeddings

Out of the box, OpenClaw's agent can read and write files in the vault. But as your vault grows past a few hundred files, the agent cannot scan everything on every conversation. **Vector search** solves this by creating embeddings of your entire vault, letting the agent semantically search across thousands of files in milliseconds.

This section documents the `memorySearch` configuration block in `openclaw.json` that enables this capability.

### What Changed

The default `openclaw.json` has no `memorySearch` section. Adding one enables:

1. **Embedding generation** for all vault files using Google's embedding model
2. **A local SQLite vector store** that persists embeddings across sessions
3. **Hybrid search** combining vector similarity with keyword matching
4. **Session memory** so the agent remembers what happened in previous conversations
5. **Automatic re-indexing** when files change

### The Configuration

Add the `memorySearch` block inside `agents.defaults` in your `openclaw.json`:

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "enabled": true,
        "sources": ["memory", "sessions"],
        "extraPaths": ["/home/node/workspace"],
        "experimental": {
          "sessionMemory": true
        },
        "provider": "gemini",
        "model": "gemini-embedding-001",
        "chunking": {
          "tokens": 512,
          "overlap": 64
        },
        "sync": {
          "onSessionStart": true,
          "onSearch": true,
          "watch": true,
          "watchDebounceMs": 5000,
          "intervalMinutes": 5,
          "sessions": {
            "deltaBytes": 2048,
            "deltaMessages": 10
          }
        },
        "query": {
          "maxResults": 8,
          "minScore": 0.3,
          "hybrid": {
            "enabled": true,
            "vectorWeight": 0.7,
            "textWeight": 0.3,
            "candidateMultiplier": 3,
            "mmr": {
              "enabled": true,
              "lambda": 0.7
            },
            "temporalDecay": {
              "enabled": true,
              "halfLifeDays": 30
            }
          }
        },
        "cache": {
          "enabled": true,
          "maxEntries": 500
        }
      }
    }
  }
}
```

### Key Settings Explained

#### Sources and Paths

| Setting | Value | Purpose |
|---------|-------|---------|
| `sources` | `["memory", "sessions"]` | Index both the `memory/` directory and past conversation sessions |
| `extraPaths` | `["/home/node/workspace"]` | Index the **entire vault** (`/home/node/workspace` maps to `/opt/SecondBrain` inside Docker) |
| `experimental.sessionMemory` | `true` | Enable cross-session recall -- the agent remembers previous conversations |

The `extraPaths` setting is critical. Without it, the agent can only search its built-in memory store. With it pointing to the workspace, every Markdown file in your vault becomes searchable via semantic similarity.

#### Embedding Model

| Setting | Value | Purpose |
|---------|-------|---------|
| `provider` | `"gemini"` | Use Google's embedding API (same auth as your main model) |
| `model` | `"gemini-embedding-001"` | Google's text embedding model |

This uses the same Google API key you already configured. Embedding costs are minimal -- a few cents per month for a typical vault.

#### Chunking

| Setting | Value | Purpose |
|---------|-------|---------|
| `tokens` | `512` | Split files into 512-token chunks for embedding |
| `overlap` | `64` | Overlap 64 tokens between chunks to preserve context at boundaries |

Smaller chunks (256) give more precise search results but miss broader context. Larger chunks (1024) capture more context but may dilute the signal. 512 with 64 overlap is a good default.

#### Sync Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `onSessionStart` | `true` | Re-index changed files when a new conversation starts |
| `onSearch` | `true` | Check for changes before every search query |
| `watch` | `true` | Watch the filesystem for changes in real-time |
| `watchDebounceMs` | `5000` | Wait 5 seconds after a file change before re-indexing (batches rapid changes) |
| `intervalMinutes` | `5` | Full re-sync check every 5 minutes |
| `sessions.deltaBytes` | `2048` | Re-index a session after 2KB of new content |
| `sessions.deltaMessages` | `10` | Re-index a session after 10 new messages |

#### Hybrid Search

This is where the magic happens. Pure vector search finds semantically similar content. Pure keyword search finds exact matches. Hybrid combines both:

| Setting | Value | Purpose |
|---------|-------|---------|
| `hybrid.enabled` | `true` | Enable combined vector + keyword search |
| `vectorWeight` | `0.7` | Vector similarity contributes 70% of the final score |
| `textWeight` | `0.3` | Keyword matching contributes 30% |
| `candidateMultiplier` | `3` | Fetch 3x more candidates than `maxResults` before re-ranking |
| `mmr.enabled` | `true` | **Maximal Marginal Relevance** -- diversify results to avoid returning near-duplicates |
| `mmr.lambda` | `0.7` | Balance between relevance (1.0) and diversity (0.0) |
| `temporalDecay.enabled` | `true` | Boost recently modified files over stale ones |
| `temporalDecay.halfLifeDays` | `30` | A file's temporal boost halves every 30 days |

The temporal decay is particularly useful for a SecondBrain: when you ask about a project, the agent naturally prioritizes your recent notes over year-old entries about the same topic.

#### Query Defaults

| Setting | Value | Purpose |
|---------|-------|---------|
| `maxResults` | `8` | Return up to 8 relevant chunks per search |
| `minScore` | `0.3` | Ignore results below 0.3 similarity (filters noise) |

#### Cache

| Setting | Value | Purpose |
|---------|-------|---------|
| `cache.enabled` | `true` | Cache search results to avoid redundant embedding lookups |
| `cache.maxEntries` | `500` | Keep up to 500 cached queries |

### Where the Data Lives

The vector store is a SQLite database at:

```
/opt/openclaw/config/memory/main.sqlite
```

This file will grow with your vault. A vault with ~500 Markdown files produces a database of roughly 600-700 MB. This is normal -- embeddings are dense numerical vectors.

### The Result

With this configuration, the agent gains a `memory_search(query)` tool that:

1. Takes a natural language query (e.g., "what did I decide about the hiring strategy?")
2. Embeds the query using `gemini-embedding-001`
3. Searches the vector store using hybrid search (70% semantic, 30% keyword)
4. Applies MMR to diversify results
5. Applies temporal decay to prefer recent content
6. Returns the top 8 relevant chunks with file paths and content

This transforms the agent from "can read files you point it to" into "can find relevant information across your entire vault without you specifying where to look."

### Before and After

| Without memorySearch | With memorySearch |
|---------------------|-------------------|
| Agent searches files by name/path | Agent searches by meaning |
| "What did I write about X?" requires knowing the file | "What did I write about X?" searches everywhere |
| Agent forgets previous conversations | Agent recalls past sessions |
| Large vaults require manual file references | Large vaults are fully searchable |
| Agent reads files sequentially | Agent finds relevant chunks in milliseconds |

---

Long-running agents accumulate context. When the context window fills up, the agent loses track of earlier instructions. **Compaction** is how you prevent this.

### What Is Compaction?

Compaction summarizes older conversation history to make room for new context. Think of it as the agent "taking notes" on what happened so far, then clearing the full transcript.

### Configuration

Compaction behavior is configured in your `openclaw.json` file. Key settings:

```json
{
  "compaction": {
    "enabled": true,
    "preserve_system_prompt": true,
    "preserve_recent_tool_results": true
  }
}
```

With `preserve_system_prompt` enabled:
- System prompts are always preserved (never compacted)
- Recent tool results are kept in full
- Older context is summarized, not deleted

Refer to your OpenClaw documentation for all available compaction options and their defaults.

### Signs Compaction Needs Tuning

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Agent forgets vault structure | System prompt compacted | Enable `preserve_system_prompt` |
| Agent repeats actions | Recent context lost | Increase context preservation window |
| Agent stops using tools | Tool definitions compacted | Move tools to system prompt |
| Agent responses become generic | Too aggressive compaction | Reduce compaction frequency |

### Manual Compaction

You can also trigger compaction manually if your agent feels "sluggish":

```
/compact
```

This forces an immediate compaction cycle, clearing old context while preserving critical information.

---

## Docker Updates and Maintenance

Your Second Brain runs in Docker containers. Keep them updated without downtime.

### Checking for Updates

```bash
# Check current versions
docker compose ps

# Pull latest images
cd /home/alex/secondbrain-docker
docker compose pull

# Check what changed
docker compose images
```

### Rolling Updates (Zero Downtime)

```bash
# Update one service at a time
docker compose up -d --no-deps --build agent-core
docker compose up -d --no-deps --build telegram-bot

# Verify health
docker compose ps
docker compose logs --tail=20 agent-core
```

### Full Stack Update

For major version changes, do a full restart:

```bash
cd /home/alex/secondbrain-docker

# Pull all updates
docker compose pull

# Restart everything
docker compose down
docker compose up -d

# Verify
docker compose ps
docker compose logs --tail=50
```

### Automated Updates with Watchtower

For hands-off updates, use Watchtower:

```yaml
# Add to your docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * 1  # Monday 4am
      - WATCHTOWER_NOTIFICATIONS=email
    restart: unless-stopped
```

**Warning:** Only use Watchtower if you're pulling from stable, tagged images. Don't use it with `:latest` tags on critical services -- you could auto-update to a breaking change.

### Docker Housekeeping

Run monthly to reclaim disk space:

```bash
# Remove unused images
docker image prune -a --filter "until=720h"  # Remove images older than 30 days

# Remove unused volumes (careful - verify first!)
docker volume ls
docker volume prune --filter "label!=keep"

# Check disk usage
docker system df
```

---

## Security Hardening

Your Second Brain contains your most private thoughts, contacts, and plans. Lock it down.

### SSH Key Rotation

Rotate your SSH keys every 6 months:

```bash
# Generate a new key pair
ssh-keygen -t ed25519 -C "secondbrain-$(date +%Y-%m)" -f ~/.ssh/secondbrain_$(date +%Y%m)

# Copy to server
ssh-copy-id -i ~/.ssh/secondbrain_$(date +%Y%m).pub alex@your-server-ip

# Test the new key
ssh -i ~/.ssh/secondbrain_$(date +%Y%m) alex@your-server-ip

# Update your SSH config
cat >> ~/.ssh/config << EOF
Host secondbrain
    HostName your-server-ip
    User alex
    IdentityFile ~/.ssh/secondbrain_$(date +%Y%m)
    IdentitiesOnly yes
EOF

# Once verified, remove the old key from authorized_keys on the server
ssh secondbrain "sed -i '/old-key-comment/d' ~/.ssh/authorized_keys"
```

### fail2ban Tuning

fail2ban protects against brute-force attacks. Fine-tune it for your setup:

```bash
# /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 3600      # Ban for 1 hour
findtime = 600       # Within a 10-minute window
maxretry = 3         # After 3 failed attempts
ignoreip = 127.0.0.1/8 YOUR_HOME_IP

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 86400     # 24 hours for SSH brute force

[docker-auth]
enabled  = true
port     = http,https
filter   = docker-auth
logpath  = /var/log/docker-auth.log
maxretry = 5
bantime  = 3600
```

Check ban status:

```bash
# See current bans
sudo fail2ban-client status sshd

# Unban an IP if needed
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

### Additional Security Measures

**1. Disable password authentication entirely:**

```bash
# /etc/ssh/sshd_config
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3

# Restart SSH
sudo systemctl restart sshd
```

**2. Enable automatic security updates:**

```bash
# Ubuntu/Debian
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

**3. Set up a basic firewall:**

```bash
# UFW (Uncomplicated Firewall)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp    # If running a web interface
sudo ufw allow 443/tcp
sudo ufw enable

# Verify
sudo ufw status verbose
```

**4. API key security:**

Never store API keys in your vault or Git repository. Use environment variables or Docker secrets:

```bash
# Store in a protected env file
echo 'GEMINI_API_KEY=YOUR_GEMINI_KEY_HERE' >> /home/alex/.env.secondbrain
chmod 600 /home/alex/.env.secondbrain

# Reference in docker-compose.yml
services:
  agent-core:
    env_file:
      - /home/alex/.env.secondbrain
```

---

## Performance at Scale (10k+ Files)

After 1-2 years of use, your vault will grow significantly. Alex's vault hit 5,000 notes at 10 months. At 10,000+ files, you need to be intentional about performance.

### Obsidian Performance

**Symptoms of a slow vault:**
- Graph view takes >5 seconds to render
- Search results appear sluggishly
- Switching notes has noticeable lag
- Sync operations are slow

**Fixes:**

```
Settings > Files & Links:
  - Excluded files: 99_Assets/Scripts/*, .git/*
  - Detect all file extensions: OFF (only .md)

Settings > Core Plugins:
  - Disable plugins you don't actively use
  - Graph view: reduce max displayed nodes to 500

Settings > Appearance:
  - Disable translucency
  - Reduce animation duration
```

### Git Performance

Large repos with many small files slow down Git:

```bash
# Optimize the repository
cd /home/alex/SecondBrain
git gc --aggressive --prune=now
git repack -a -d --depth=250 --window=250

# Enable filesystem monitor for faster status
git config core.fsmonitor true
git config core.untrackedcache true

# Increase pack size for better compression
git config pack.windowMemory 256m
git config pack.threads 2
```

### Agent Performance

When your agent needs to search 10,000+ files, direct file scanning gets slow. Optimize with indexing:

```bash
# Build a search index (run nightly)
cat > /home/alex/SecondBrain/99_Assets/Scripts/build_index.sh << 'SCRIPT'
#!/bin/bash
VAULT="/home/alex/SecondBrain"

# Create a tag index
grep -rh "^tags:" "$VAULT" --include="*.md" | \
  sort | uniq -c | sort -rn > "$VAULT/99_Assets/tag_index.txt"

# Create a title index
find "$VAULT" -name "*.md" -not -path "*/.git/*" | \
  while read f; do
    title=$(head -5 "$f" | grep "^# " | head -1 | sed 's/^# //')
    echo "$f|$title"
  done > "$VAULT/99_Assets/file_index.txt"

echo "Index built: $(wc -l < "$VAULT/99_Assets/file_index.txt") files"
SCRIPT

chmod +x /home/alex/SecondBrain/99_Assets/Scripts/build_index.sh
```

### Vault Archival Strategy

Not everything needs to stay in your active vault. Archive old notes to keep the active set manageable:

```
SecondBrain/
├── 10_Journal/
│   ├── 2026/          <- Current year (active)
│   └── archive/
│       ├── 2025/      <- Previous year (archived)
│       └── 2024/
├── 11_Readings/
│   ├── active/        <- Currently relevant
│   └── archive/       <- Read and processed
```

Archive criteria:
- Journal entries older than 12 months
- Reading notes that have been fully wisdomized
- Completed project notes (after a 3-month cool-down)
- Contact entries for people you haven't interacted with in 1+ year

The archived files stay in the vault (still searchable) but are excluded from active processing by your agents.

### Performance Benchmarks

Here's what to expect at different vault sizes:

| Vault Size | Obsidian Load | Search Speed | Git Push | Sync Time |
|-----------|---------------|-------------|----------|-----------|
| 1,000 notes | <1s | Instant | 2-3s | 5s |
| 5,000 notes | 2-3s | <1s | 5-8s | 15s |
| 10,000 notes | 4-6s | 1-2s | 10-15s | 30s |
| 20,000 notes | 8-12s | 2-4s | 20-30s | 60s |

These numbers assume a Hetzner CX22 (2 vCPU, 4 GB RAM) and a laptop with 16 GB RAM for Obsidian.

---

## Quick Reference

Here's a maintenance schedule to keep everything running smoothly:

| Frequency | Task | How |
|-----------|------|-----|
| Every 6 hours | Git backup | Cron job |
| Daily | Nightly scripts (wisdomizer, habits) | Cron / systemd timer |
| Weekly | Server snapshot | Cron job |
| Weekly | Check fail2ban status | `fail2ban-client status` |
| Monthly | Docker image updates | `docker compose pull && up -d` |
| Monthly | Disk space check | `docker system df && df -h` |
| Monthly | Git gc | `git gc --prune=now` |
| Quarterly | Review archived notes | Manual |
| Every 6 months | SSH key rotation | Manual |
| Every 6 months | Review API costs | Check provider dashboard |

---

That covers the operational setup. With backups in two places, cost-optimized model selection, security hardening, and a scaling strategy, the infrastructure stays out of your way while you focus on the vault itself.

---

## Support This Guide

If this guide helped you build something useful, consider buying me a coffee.

<a href="https://buymeacoffee.com/bastianbuch" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50"></a>

---

← [Previous: Daily Workflow](./10_DAILY_WORKFLOW.md) | [Home](./README.md) | [Back to Home](./README.md) →
