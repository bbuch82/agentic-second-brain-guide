# Chapter 05: Telegram Setup

[← System Files](./04_SYSTEM_FILES.md) | [Home](./README.md) | [Next: Obsidian Sync →](./06_OBSIDIAN_SETUP.md)

---

> **Goal:** Create a Telegram bot, connect it to OpenClaw, and have your first conversation with your SecondBrain.

Your SecondBrain needs a front door. Telegram is ideal: it runs on every device, supports rich formatting, delivers messages instantly, and -- critically -- its Bot API is free. You will create a private bot that only responds to you, turning Telegram into the command line for your life.

---

## Table of Contents

- [Why Telegram](#why-telegram)
- [Step 1: Create Your Bot with BotFather](#step-1-create-your-bot-with-botfather)
- [Step 2: Find Your User ID](#step-2-find-your-user-id)
- [Step 3: Configure OpenClaw](#step-3-configure-openclaw)
- [Step 4: Restart and Pair](#step-4-restart-and-pair)
- [Step 5: Test Your First Conversation](#step-5-test-your-first-conversation)
- [Security: Allowlist-Only Access](#security-allowlist-only-access)
- [Pro Tips](#pro-tips)
- [Troubleshooting](#troubleshooting)

---

## Why Telegram

| Feature | Why It Matters |
|---------|---------------|
| **Cross-platform** | iOS, Android, macOS, Windows, Linux, and web |
| **Bot API** | Free, well-documented, no rate limits for personal use |
| **Rich formatting** | Markdown, code blocks, inline keyboards |
| **Push notifications** | Your morning briefing wakes your phone, not the other way around |
| **Offline queue** | Messages sent while you have no signal are delivered later |
| **No vendor lock-in** | Your data still lives in your vault -- Telegram is just the interface |

> **Alex's take:** "I tried a web UI first. It was fine at my desk but useless on the train. Telegram means I can ask my SecondBrain a question from anywhere -- the grocery store, a meeting room, or bed at 11pm when I suddenly remember I forgot something."

---

## Step 1: Create Your Bot with BotFather

Open Telegram and search for **@BotFather** (the official Telegram bot for creating bots). Start a conversation and run:

```
/newbot
```

BotFather will ask two questions:

1. **Name** -- The display name users see. Use something like `Alex SecondBrain` or `My SecondBrain`.
2. **Username** -- Must end in `bot`. Use something unique like `alex_secondbrain_bot`.

BotFather responds with your **bot token**:

```
Done! Congratulations on your new bot. You will find it at t.me/alex_secondbrain_bot.
You can now add a description, about section and profile picture for your bot,
see /help for a list of things. By the way, when you've finished creating
your cool bot, ping our Bot Support if you want a better username for it.

Use this token to access the HTTP API:
7481923456:AAH_your_secret_token_string_here

Keep your token secure and store it safely.
```

**Save this token.** You will need it in Step 3. Never share it or commit it to a public repository.

---

## Step 2: Find Your User ID

Your Telegram user ID is a numeric identifier that the allowlist uses to restrict access. There are several ways to find it:

**Option A: @userinfobot**

1. Search for **@userinfobot** in Telegram
2. Start a conversation and send any message
3. It replies with your user ID:

```
Id: 123456789
First: Alex
Last: Chen
Lang: en
```

**Option B: @RawDataBot**

1. Search for **@RawDataBot** in Telegram
2. Send any message
3. Look for the `"id"` field in the JSON response under `"from"`

Write down the numeric ID (e.g., `123456789`). You will use it in the next step.

---

## Step 3: Configure OpenClaw

SSH into your server and edit the OpenClaw config:

```bash
nano /opt/openclaw/config/openclaw.json
```

Add the `telegram` section inside the top-level object:

```json
{
  "version": "1.0",
  "instance": { "..." : "..." },
  "auth": { "..." : "..." },
  "models": { "..." : "..." },
  "agent": { "..." : "..." },
  "gateway": { "..." : "..." },
  "tools": { "..." : "..." },
  "routines": { "..." : "..." },
  "telegram": {
    "botToken": "YOUR_TELEGRAM_BOT_TOKEN_HERE",
    "allowFrom": [123456789],
    "dmPolicy": "allowlist",
    "groupPolicy": "ignore",
    "streamMode": "partial",
    "parseMode": "Markdown",
    "maxMessageLength": 4000,
    "rateLimiting": {
      "maxMessagesPerMinute": 30,
      "cooldownMessage": "Slow down -- I'm still thinking about your last message."
    }
  }
}
```

### Configuration Breakdown

| Setting | Value | What It Does |
|---------|-------|-------------|
| `botToken` | Your BotFather token | Authenticates the bot with Telegram's API |
| `allowFrom` | Array of user IDs | **Only these users can interact with the bot** |
| `dmPolicy` | `"allowlist"` | Only allow direct messages from users in `allowFrom` |
| `groupPolicy` | `"ignore"` | Bot ignores all group chat messages |
| `streamMode` | `"partial"` | Sends partial responses as the agent thinks, then edits with the final answer |
| `parseMode` | `"Markdown"` | Formats responses with bold, italic, code blocks |
| `maxMessageLength` | `4000` | Splits long responses into multiple messages (Telegram limit is 4096) |

**The `streamMode` options:**

| Mode | Behavior |
|------|----------|
| `none` | Wait until the full response is ready, then send it all at once |
| `partial` | Send a "thinking..." message, update it periodically, replace with final answer |
| `full` | Stream every token as an edit (looks cool but hammers the Telegram API) |

`partial` is the sweet spot. You see activity within seconds, and the final message is clean.

---

## Step 4: Restart and Pair

Apply the new configuration:

```bash
cd /opt/openclaw
docker compose restart
```

Check the logs to confirm Telegram connected:

```bash
docker compose logs --tail 20
```

You should see something like:

```
INFO  Telegram bot connected: @alex_secondbrain_bot
INFO  Telegram allowlist: [123456789]
INFO  Telegram DM policy: allowlist
INFO  Telegram polling started
```

If you see errors, jump to [Troubleshooting](#troubleshooting).

---

## Step 5: Test Your First Conversation

Open Telegram, find your bot (`@alex_secondbrain_bot`), and send:

```
Hello! Who are you?
```

The bot should respond with something based on your IDENTITY.md and SOUL.md system files. If you have not created those yet (see [Chapter 04](./04_SYSTEM_FILES.md)), it will give a generic response.

Try a few more tests:

```
What files are in my vault?
```

```
Create a test note called "Hello World" with some sample content.
```

```
Read back the note you just created.
```

If all three work, your Telegram integration is fully operational. The bot can read files, write files, and carry a conversation.

> **Alex's first test:** "I asked it to summarize my week and it had nothing to summarize yet -- fair enough. But the fact that it responded at all, from my phone, querying files on my own server... that was the moment it clicked."

---

## Security: Allowlist-Only Access

This is the most important section in this chapter. Your SecondBrain has access to your entire vault -- personal journals, contacts, financial notes, everything. The security model must be airtight.

### What the Allowlist Does

```
Message from Telegram user 123456789 → Is 123456789 in allowFrom? → YES → Process
Message from Telegram user 999999999 → Is 999999999 in allowFrom? → NO  → Ignore silently
```

The bot does not respond, does not acknowledge, does not even log rejected messages by default. To the outside world, it appears offline.

### Rules

1. **Never add the bot to group chats.** The `groupPolicy: "ignore"` setting is a safety net, not a feature. Do not rely on it.

2. **Never share your bot token.** Anyone with the token can impersonate your bot and potentially intercept messages.

3. **Keep the allowlist minimal.** Only add user IDs you trust completely. If you want a family member to use the bot, consider creating a separate bot with a restricted config instead.

4. **Rotate the token periodically.** You can regenerate it via BotFather at any time:
   ```
   /revoke
   ```
   Then update `openclaw.json` and restart.

### Adding a Second User

If your partner also wants access:

```json
"allowFrom": [123456789, 987654321]
```

Both users share the same vault and conversation history. There is no user isolation -- treat this as "shared device" access, not multi-tenant.

---

## Pro Tips

### Set a Profile Picture

Send to @BotFather:

```
/setuserpic
```

Upload a square image (512x512 works best). A good avatar makes the bot feel more real in your chat list.

### Set a Description

```
/setdescription
```

This text appears when someone opens your bot for the first time. Something like:

```
Private AI assistant. This bot only responds to authorized users.
```

### Set Bot Commands

```
/setcommands
```

Then send a list of commands:

```
help - Show what I can do
briefing - Get your morning briefing
journal - Create today's journal entry
search - Search across your vault
people - Look up a contact
weekly - Generate weekly review
```

These commands appear as a menu when users type `/` in the chat. OpenClaw treats them as regular messages -- the agent reads the text and responds accordingly. No special routing needed.

### Pin Important Messages

When your bot sends a particularly useful response (like a weekly review), long-press and pin it. Telegram keeps pinned messages accessible at the top of the chat.

### Use Telegram's Search

Press the magnifying glass in the chat to search all past messages. Since your bot sends structured Markdown, searching for keywords like "Project Compass" or "Sarah Kim" works well.

### Mute Notifications for Scheduled Messages

Your bot will send automated messages (morning briefings, journals). If the 07:00 briefing wakes you up:

1. Open the bot chat
2. Tap the bot name at the top
3. Toggle **Notifications** to customize

On iOS/Android, you can set a "muted until" time to silence overnight messages.

---

## Troubleshooting

### Bot does not respond at all

1. **Check the logs:**
   ```bash
   docker compose logs --tail 50 | grep -i telegram
   ```

2. **Verify the token:**
   ```bash
   curl https://api.telegram.org/botYOUR_TOKEN_HERE/getMe
   ```
   You should get a JSON response with your bot's details. If you get `{"ok":false}`, the token is wrong.

3. **Check your user ID is in allowFrom:**
   ```bash
   cat /opt/openclaw/config/openclaw.json | grep allowFrom
   ```

4. **Check Docker networking:**
   ```bash
   docker compose exec openclaw wget -q -O- https://api.telegram.org/botYOUR_TOKEN_HERE/getMe
   ```
   If this fails, the container cannot reach the internet. Check DNS and firewall rules.

### Bot responds very slowly

- Check if `streamMode` is set to `"none"` (change to `"partial"`)
- Check if the Google AI API is slow: `docker compose logs --tail 20`
- Check CPU/memory: `docker stats openclaw --no-stream`

### "Unauthorized" errors in logs

The bot token is invalid or has been revoked. Generate a new one from @BotFather and update the config.

### Messages arrive out of order

Telegram guarantees delivery but not strict ordering under load. This rarely matters for normal use. If it does, reduce `rateLimiting.maxMessagesPerMinute` to serialize processing.

---

## What We Built

```
┌──────────┐         ┌──────────────────────────────┐
│          │         │     Your Hetzner VPS          │
│  Your    │◄───────►│                               │
│  Phone   │ TG API  │  OpenClaw ◄──► SecondBrain    │
│          │         │     │                         │
└──────────┘         │     ▼                         │
                     │  Allowlist: [123456789]       │
                     │  Policy: DM only              │
                     │  Stream: partial               │
                     └──────────────────────────────┘
```

You now have a secure, private, mobile interface to your AI agent. Every message you send goes through your server, is processed by your models, and the response comes from your data.

No one else can use it. No one else can see it. It is yours.

---

[← System Files](./04_SYSTEM_FILES.md) | [Home](./README.md) | [Next: Obsidian Sync →](./06_OBSIDIAN_SETUP.md)
