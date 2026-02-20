# Chapter 06: Obsidian Setup and Sync

[← Telegram Setup](./05_TELEGRAM_SETUP.md) | [Home](./README.md) | [Next: Cron Automation →](./07_CRON_AUTOMATION.md)

---

> **Goal:** Install Obsidian, connect it to your vault via Git, sync to all your devices, and configure essential plugins.

Your SecondBrain vault is a folder of Markdown files on a server. The AI writes to it, schedules routines against it, and manages its structure. But you need a way to **read, browse, and occasionally edit** those files yourself. That is where Obsidian comes in.

Here is the key insight: **Obsidian is the read and browse layer. The AI is the automation layer.** You do not need to organize anything by hand. You open Obsidian to explore your knowledge graph, read your journal, check your contacts -- not to manually file notes into folders. The AI does that.

---

## Table of Contents

- [Why Obsidian](#why-obsidian)
- [Step 1: Desktop Installation](#step-1-desktop-installation)
- [Step 2: Git Sync Setup](#step-2-git-sync-setup)
- [Step 3: Mobile Sync -- iOS](#step-3-mobile-sync----ios)
- [Step 4: Mobile Sync -- Android](#step-4-mobile-sync----android)
- [Step 5: Alternative -- Obsidian Sync (Paid)](#step-5-alternative----obsidian-sync-paid)
- [Step 6: Essential Plugins](#step-6-essential-plugins)
- [Recommended Settings](#recommended-settings)
- [The Two-Layer Mental Model](#the-two-layer-mental-model)

---

## Why Obsidian

| Feature | Why It Matters for SecondBrain |
|---------|-------------------------------|
| **Local-first** | Files live on your machine. No cloud dependency. Works offline. |
| **Graph view** | Visualize connections between notes, people, projects, and ideas |
| **Wikilinks** | `[[Note Name]]` is the native link format -- your AI already writes these |
| **Plugin ecosystem** | Dataview, Calendar, Templates, and hundreds more |
| **Multi-platform** | macOS, Windows, Linux, iOS, Android |
| **Free for personal use** | Only Sync and Publish are paid features |

> **Alex's take:** "I tried Notion, Logseq, and plain VS Code. Obsidian won because it treats Markdown files as first-class citizens. My AI writes standard Markdown with `[[wikilinks]]`, and Obsidian renders them as a navigable knowledge graph. No import/export. No proprietary format. Just files."

---

## Step 1: Desktop Installation

### macOS / Windows / Linux

1. Download Obsidian from [obsidian.md](https://obsidian.md/)
2. Install and open it
3. Select **Open folder as vault**
4. Navigate to your cloned vault directory (we will set this up in Step 2)

Do not create a new vault from scratch. Your SecondBrain vault already has a structure that the AI maintains. You are opening an existing folder.

---

## Step 2: Git Sync Setup

This is the most reliable and flexible sync method. It uses a bare Git repository on your server as the central hub. Your desktop clones from it, and the Obsidian Git plugin auto-pushes and auto-pulls.

### 2.1: Create a Bare Repository on Your Server

SSH into your server:

```bash
ssh secondbrain
```

Create a bare repo that mirrors your vault:

```bash
git init --bare /opt/SecondBrain-sync.git
```

Add the bare repo as a remote in your vault:

```bash
cd /opt/SecondBrain
git remote add origin /opt/SecondBrain-sync.git
```

Make an initial commit and push:

```bash
cd /opt/SecondBrain
git add -A
git commit -m "Initial vault state"
git push -u origin main
```

### 2.2: Clone to Your Desktop

On your local machine:

```bash
git clone ssh://secondbrain/opt/SecondBrain-sync.git ~/SecondBrain
```

This clones the vault to `~/SecondBrain`. You will point Obsidian at this folder.

> **SSH key reminder:** This uses the same SSH key you set up in [Chapter 01](./01_SERVER_SETUP.md). If `ssh secondbrain` works from your terminal, this clone will work too.

### 2.3: Open the Vault in Obsidian

1. Open Obsidian
2. Click **Open folder as vault**
3. Select `~/SecondBrain`
4. Trust the vault when prompted

You should see your folder structure in the left sidebar.

### 2.4: Install the Obsidian Git Plugin

1. Go to **Settings** (gear icon) > **Community plugins**
2. Click **Turn on community plugins** if prompted
3. Click **Browse** and search for **Obsidian Git**
4. Install and enable it

### 2.5: Configure Obsidian Git

Go to **Settings** > **Obsidian Git** and set:

| Setting | Value | Why |
|---------|-------|-----|
| Auto pull interval | `5` (minutes) | Fetch AI changes frequently |
| Auto push on close | `true` | Push your edits when you close Obsidian |
| Auto push interval | `0` (disabled) | Rely on push-on-close instead of polling |
| Pull on startup | `true` | Always start with the latest vault state |
| Commit message | `obsidian: auto-sync` | Distinguishes your commits from the AI's |
| Auto commit on close | `true` | Stage and commit changes before pushing |

### 2.6: Server-Side Auto-Push

The AI writes to `/opt/SecondBrain` but the bare repo at `/opt/SecondBrain-sync.git` needs to stay in sync. Add a cron job on the server:

```bash
crontab -e
```

Add:

```cron
*/5 * * * * cd /opt/SecondBrain && git add -A && git diff --cached --quiet || (git commit -m "vault: auto-sync $(date +\%Y-\%m-\%d\ \%H:\%M)" && git push origin main) 2>/dev/null
```

This checks every 5 minutes for changes, commits them, and pushes to the bare repo. The `git diff --cached --quiet` check prevents empty commits.

### 2.7: Conflict Resolution

With auto-sync, conflicts are rare but possible. When they happen:

**Scenario:** You edited a file in Obsidian at the same time the AI edited it.

**Resolution:**

```bash
cd ~/SecondBrain
git pull --rebase origin main
```

If there is a conflict:

1. Open the conflicted file in a text editor
2. Look for conflict markers:
   ```
   <<<<<<< HEAD
   Your version of the line
   =======
   The AI's version of the line
   >>>>>>> origin/main
   ```
3. Choose the version you want (or merge both)
4. Remove the conflict markers
5. Commit and push:
   ```bash
   git add .
   git commit -m "resolve: merge conflict"
   git push origin main
   ```

**Pro tip:** To minimize conflicts, follow this rule: **let the AI own the structure, and you own the content edits.** Do not reorganize folders manually -- tell the AI to do it. If you want to edit a note, do it and push. The AI will not overwrite your manual edits unless a routine explicitly targets that file.

---

## Step 3: Mobile Sync -- iOS

On iOS, use **Working Copy** (a full Git client) alongside Obsidian.

### 3.1: Set Up Working Copy

1. Install [Working Copy](https://apps.apple.com/app/working-copy/id896694807) from the App Store (free for read-only, one-time purchase for push)
2. Add your SSH key or create a new one in **Settings** > **SSH Keys**
3. Copy the public key to your server:
   ```bash
   # On your server
   echo "YOUR_IOS_PUBLIC_KEY" >> ~/.ssh/authorized_keys
   ```
4. Clone the repo in Working Copy:
   - Tap **+** > **Clone repository**
   - URL: `ssh://secondbrain/opt/SecondBrain-sync.git`

### 3.2: Link to Obsidian

1. Open Obsidian on iOS
2. Create a new vault (any name)
3. Go back to Working Copy
4. Open the cloned repo > tap **Share** > **Link Repository to Obsidian**
5. Select the Obsidian vault you just created

Working Copy will mount the Git repository into Obsidian's file space. Any changes sync via Git.

### 3.3: Auto-Sync on iOS

Working Copy can auto-pull on a schedule. Go to **Repository Settings** > **Syncing** and enable:

- **Fetch on open**: Pull latest changes when you open the app
- **Push on change**: Push edits when you save (requires paid version)

---

## Step 4: Mobile Sync -- Android

On Android, use **Termux** with Git.

### 4.1: Install Termux

1. Install [Termux](https://f-droid.org/packages/com.termux/) from **F-Droid** (not the Play Store version, which is outdated)
2. Open Termux and install Git:
   ```bash
   pkg update && pkg install git openssh
   ```

### 4.2: Set Up SSH

Generate a key in Termux:

```bash
ssh-keygen -t ed25519 -C "secondbrain-android"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to your server:

```bash
# On your server
echo "THE_ANDROID_PUBLIC_KEY" >> ~/.ssh/authorized_keys
```

### 4.3: Clone the Vault

In Termux:

```bash
git clone ssh://YOUR_SERVER_IP/opt/SecondBrain-sync.git ~/storage/shared/SecondBrain
```

> **Note:** You need to grant Termux storage access first: `termux-setup-storage`

### 4.4: Open in Obsidian

1. Open Obsidian on Android
2. **Open folder as vault** > navigate to `SecondBrain` in your shared storage

### 4.5: Sync Script

Create a simple sync script in Termux:

```bash
cat > ~/sync-vault.sh << 'EOF'
#!/bin/bash
cd ~/storage/shared/SecondBrain
git pull --rebase origin main
git add -A
git diff --cached --quiet || git commit -m "mobile: auto-sync $(date +%Y-%m-%d\ %H:%M)"
git push origin main
echo "Sync complete: $(date)"
EOF
chmod +x ~/sync-vault.sh
```

Run it before and after using Obsidian:

```bash
~/sync-vault.sh
```

You can also set up a Termux cron job with `termux-job-scheduler`, but manual sync is simpler and more reliable on mobile.

---

## Step 5: Alternative -- Obsidian Sync (Paid)

If you prefer a zero-config solution, Obsidian Sync is a paid service (USD 4/month billed annually) that handles everything automatically.

### How It Works with SecondBrain

1. Set up Obsidian Sync on your desktop vault
2. Enable Sync on your mobile devices
3. All desktop and mobile devices stay in sync through Obsidian's servers

> **Note:** Obsidian Sync is for desktop and mobile clients only. There is no Obsidian CLI sync tool. The server-side vault (`/opt/SecondBrain`) syncs via Git, not Obsidian Sync. You will still need the Git-based server-side auto-push from Step 2.6.

### Pros

- Zero configuration -- just works
- End-to-end encrypted
- Built-in conflict resolution
- Works on all platforms

### Cons

- Costs money (USD 48/year)
- Your data transits Obsidian's servers (encrypted, but still third-party)
- Requires configuring the server-side sync separately
- Does not give you Git history

### Recommendation

**Use Git sync.** It is free, gives you full version history, and keeps everything on infrastructure you control. Obsidian Sync is a fine option if you value convenience over control, but it works against the self-hosted philosophy of this guide.

---

## Step 6: Essential Plugins

These plugins transform Obsidian from a text editor into a proper SecondBrain interface.

### Dataview

**What it does:** Query your notes like a database using inline code blocks.

**Install:** Community plugins > Browse > "Dataview" > Install > Enable

**Why you need it:** Your AI creates notes with YAML frontmatter (tags, dates, categories). Dataview lets you query across them.

Example -- show all unread books:

````markdown
```dataview
TABLE author, date-added
FROM "11_Readings"
WHERE status = "unread"
SORT date-added DESC
```
````

Example -- list all contacts you have not spoken to in 30 days:

````markdown
```dataview
TABLE last-contact, relationship
FROM "40_Network/People"
WHERE last-contact < date(today) - dur(30 days)
SORT last-contact ASC
```
````

### Calendar

**What it does:** Adds a calendar widget that links to daily notes.

**Install:** Community plugins > Browse > "Calendar" > Install > Enable

**Configuration:**
- Daily note folder: `10_Journal`
- Date format: `YYYY/MM/YYYY-MM-DD`

Click any date to jump to that day's journal entry (created automatically by the AI -- see [Chapter 07](./07_CRON_AUTOMATION.md)).

### Templates

**What it does:** Insert predefined templates into new notes.

**Install:** Settings > Core plugins > Enable "Templates"

**Configuration:**
- Template folder: `99_Assets/Templates`

Your AI already maintains templates in this folder. When you manually create a note (rare, but it happens), insert a template to match the vault's structure.

### Tag Wrangler

**What it does:** Rename, merge, and manage tags across the entire vault.

**Install:** Community plugins > Browse > "Tag Wrangler" > Install > Enable

Your AI uses tags extensively (`#project`, `#reading`, `#person`, `#health`). Tag Wrangler lets you rename a tag everywhere at once if the AI introduces an inconsistency.

### Obsidian Git

Already installed in Step 2. This is the sync backbone.

### Graph View

**What it does:** Built-in (no install needed). Visualizes your vault as a network graph.

**How to use:** Click the graph icon in the left sidebar or press `Ctrl+G` / `Cmd+G`.

**Why it matters:** The graph shows you connections the AI has built. When the Librarian cross-links a book note to a project note to a person note, the graph reveals patterns you would never see in a file tree.

**Recommended graph settings:**
- Filters: Show tags, attachments off
- Display: Arrow on links, text fade threshold 1.0
- Forces: Center force 0.5, repel force 10

---

## Recommended Settings

Go to **Settings** and configure:

### Editor

| Setting | Value | Why |
|---------|-------|-----|
| Default editing mode | Source mode | See raw Markdown, which matches what the AI writes |
| Show frontmatter | true | See YAML metadata at the top of notes |
| Fold heading | true | Collapse long sections in journal entries |
| Spell check | false | The AI handles spelling; your manual edits are brief |

### Files and Links

| Setting | Value | Why |
|---------|-------|-----|
| New link format | Wikilink | Matches the AI's `[[link]]` format |
| Use Wikilinks | true | Consistent with the vault's link style |
| Default location for new notes | Same folder as current file | Prevents orphan notes in the root |
| Deleted files | Move to .trash | Safety net -- never permanently delete |

### Appearance

| Setting | Value |
|---------|-------|
| Theme | Your choice (try "Minimal" for a clean look) |
| Font size | 16-18 (readability on larger screens) |
| Show tab title bar | true |

---

## The Two-Layer Mental Model

```
┌──────────────────────────────────────────────────────┐
│                    YOU + OBSIDIAN                      │
│                                                        │
│  Read journals ─ Browse knowledge graph ─ Quick edits  │
│  Search across vault ─ Explore connections             │
│                                                        │
│  ▲ You read and browse. Occasionally add a quick note. │
├──────────────────────────────────────────────────────┤
│                    AI + OPENCLAW                       │
│                                                        │
│  Create journals ─ Process readings ─ Update contacts  │
│  Run routines ─ Extract wisdom ─ Cross-link notes      │
│  Maintain structure ─ Enforce naming ─ Tag management  │
│                                                        │
│  ▲ The AI writes, organizes, and maintains.            │
└──────────────────────────────────────────────────────┘
```

This separation is what makes SecondBrain low-maintenance. The AI handles filing, linking, tagging, and organizing. You read the output and tell it what to do via Telegram.

Obsidian is your window into the vault. Telegram is your voice. The AI is the engine. Each layer does what it is best at.

---

[← Telegram Setup](./05_TELEGRAM_SETUP.md) | [Home](./README.md) | [Next: Cron Automation →](./07_CRON_AUTOMATION.md)
