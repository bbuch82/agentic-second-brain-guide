# SecondBrain Guide

### A self-hosted AI agent that manages your Obsidian vault through Telegram.

---

Most productivity systems fail because they demand more of your time, not less. SecondBrain is different. It is an AI agent that lives on your own server, manages your own files, and works while you sleep. No cloud lock-in. No subscription. Just a private, intelligent system that grows with you.

This guide walks you through building it from scratch: a Hetzner VPS running OpenClaw (an open-source AI agent runtime) connected to a structured Obsidian vault, all orchestrated through Telegram. By the end, you will have a system that:

- Captures and processes everything you read, learn, and think
- Writes your daily journal entries and weekly reviews automatically
- Manages contacts, meetings, projects, and personal goals
- Answers questions about your own life using your own data
- Runs entirely on hardware you control for under EUR 5/month

---

## Architecture

```
┌─────────┐     ┌──────────┐     ┌──────────────────────────┐     ┌──────────────────┐
│         │     │          │     │    OpenClaw (Docker)      │     │                  │
│   You   │◄───►│ Telegram │◄───►│                          │◄───►│  SecondBrain     │
│         │     │          │     │  6 Specialist Agents      │     │  Vault           │
└─────────┘     └──────────┘     │  Google Gemini API        │     │  (Obsidian)      │
                                 │  Automated Routines       │     │                  │
                                 └──────────────────────────┘     └──────────────────┘
                                         ▲                                 ▲
                                         │        Your Hetzner VPS         │
                                         └─────────────────────────────────┘
```

---

## What You Get

### 6 Specialist Agents

| Agent | Role |
|-------|------|
| **Chief of Staff** | Runs weekly reviews, sets priorities, tracks projects and goals |
| **Librarian** | Processes readings, extracts wisdom, maintains your knowledge base, handles journaling via cron |
| **Scout** | Gathers intelligence, monitors industry trends, connects findings to your projects |
| **Confidante** | Personal reflection partner for private thoughts, family, and emotional well-being |
| **Strategist** | Tracks projects, goals, and deadlines across work and personal life |
| **Coder** | Writes and maintains automation scripts, vault tooling, and technical integrations |

### Automated Routines

- **Morning Briefing** -- your day at a glance, delivered to Telegram at 07:00
- **Evening Journal** -- auto-generated daily entry at 21:00
- **Weekly Review** -- comprehensive week summary every Sunday
- **Reading Pipeline** -- drop a URL or text, get structured notes automatically

### Full Obsidian Compatibility

Your vault is a folder of Markdown files. Open it in Obsidian on any device for graph views, backlinks, and visual exploration. The AI writes the same format you would by hand.

---

## Prerequisites

Before you start, you will need:

| Requirement | Details | Cost |
|-------------|---------|------|
| **Hetzner Cloud account** | For your VPS ([sign up](https://www.hetzner.com/cloud)) | ~EUR 4/month |
| **Google AI API key** | For Gemini models ([get key](https://aistudio.google.com/apikey)) | Free tier available |
| **Telegram account** | For the chat interface | Free |
| **Domain name** (optional) | For SSL and clean URLs | ~EUR 10/year |
| **Local machine** | macOS, Linux, or Windows with SSH | You have this |

Total running cost: **under EUR 5/month** for a fully private AI second brain.

---

## Table of Contents

| # | Chapter | What You Will Learn |
|---|---------|---------------------|
| 01 | [Server Setup](./01_SERVER_SETUP.md) | Provision and harden a Hetzner VPS with Docker |
| 02 | [OpenClaw Install](./02_OPENCLAW_INSTALL.md) | Deploy OpenClaw with docker-compose and configure the agent |
| 03 | [SecondBrain Structure](./03_SECONDBRAIN_STRUCTURE.md) | Design the vault folder hierarchy and naming conventions |
| 04 | [System Files](./04_SYSTEM_FILES.md) | Write the 8 files that define your agent's personality and rules |
| 05 | [Telegram Setup](./05_TELEGRAM_SETUP.md) | Connect Telegram as your primary chat interface |
| 06 | [Obsidian Setup](./06_OBSIDIAN_SETUP.md) | Configure Obsidian to work with your vault |
| 07 | [Cron Automation](./07_CRON_AUTOMATION.md) | Set up morning briefings, journals, and weekly reviews |
| 08 | [Subagent System](./08_SUBAGENT_SYSTEM.md) | Configure the 6 specialist agents and their capabilities |
| 09 | [Scripts & Tools](./09_SCRIPTS_AND_TOOLS.md) | Automation scripts for wisdom extraction, habit tracking, and more |
| 10 | [Daily Workflow](./10_DAILY_WORKFLOW.md) | Your day-to-day interaction patterns with the system |
| 11 | [Advanced Tips](./11_ADVANCED_TIPS.md) | Power-user patterns and customization ideas |

---

## Quick Start

If you want to get running as fast as possible:

```bash
# 1. Create your Hetzner server (Chapter 01)
# 2. SSH in and run:
curl -fsSL https://get.docker.com | sh
mkdir -p /opt/openclaw/config /opt/SecondBrain
cd /opt/openclaw

# 3. Copy the example files
# (see examples/docker-compose.yml and examples/openclaw.json in this repo)

# 4. Start it up
docker compose up -d

# 5. Pair your Telegram (Chapter 06)
```

Then follow the chapters in order to understand and customize everything.

---

## Meet Alex

Throughout this guide, we follow **Alex Chen**, VP of Product at a Berlin-based travel-tech startup called Wanderly. Alex juggles product strategy, a growing team, investor updates, a reading habit, and family life. The SecondBrain helps Alex stay on top of all of it without spending evenings organizing notes.

You will see Alex's examples in every chapter -- adapt them to your own life.

---

## Examples

The `examples/` directory contains ready-to-use configuration files:

- [`docker-compose.yml`](./examples/docker-compose.yml) -- Production-ready Docker Compose with security hardening
- [`openclaw.json`](./examples/openclaw.json) -- Full OpenClaw configuration with placeholder API keys

Copy these to your server and replace the `YOUR_*_HERE` placeholders with your actual values.

---

## Support This Guide

If this guide saved you time or taught you something new, consider buying me a coffee.

<a href="https://buymeacoffee.com/bastianbuch" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50"></a>

---

## Contributing

Found an error? Have an improvement? Open an issue or submit a pull request.

## License

This guide is released under the [MIT License](./LICENSE). Use it, adapt it, share it.

---

<p align="center">
  <strong>Ready?</strong> Start with <a href="./01_SERVER_SETUP.md">Chapter 01: Server Setup</a> →
</p>
