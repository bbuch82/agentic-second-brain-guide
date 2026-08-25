# Chapter 08: The Subagent System

[← Cron Automation](./07_CRON_AUTOMATION.md) | [Home](./README.md) | [Next: Scripts and Tools →](./09_SCRIPTS_AND_TOOLS.md)

---

> **Goal:** Understand how the 6 specialist agents work, how to configure them, and how to write your own.

Your SecondBrain is not one agent. It is a team. When the morning briefing runs, the main agent reads the Chief of Staff profile and becomes a strategic planner. When a reading note needs processing, it reads the Librarian profile and becomes a knowledge curator. Same model, different personality, different expertise -- loaded on demand.

This chapter explains the architecture, walks through each of the 6 specialist agents, and shows you how to create your own.

---

## Table of Contents

- [Architecture: How Subagents Work](#architecture-how-subagents-work)
- [The Spawn Pattern](#the-spawn-pattern)
- [Configuration](#configuration)
- [The 6 Specialist Agents](#the-6-specialist-agents)
  - [1. Chief of Staff](#1-chief-of-staff)
  - [2. Librarian](#2-librarian)
  - [3. Scout](#3-scout)
  - [4. Confidante](#4-confidante)
  - [5. Strategist](#5-strategist)
  - [6. Coder](#6-coder)
- [Delegation Rules](#delegation-rules)
- [Writing Your Own Agent Profile](#writing-your-own-agent-profile)
- [Common Issues](#common-issues)

---

## Architecture: How Subagents Work

```
┌─────────────────────────────────────────────────┐
│                  Main Agent                      │
│                                                  │
│  Reads: IDENTITY.md, SOUL.md, AGENTS.md, etc.   │
│  Role: Router + generalist                       │
│                                                  │
│  "This task needs the Librarian."                │
│          │                                       │
│          ▼                                       │
│  ┌─────────────────────────────────────────┐    │
│  │         Spawn Isolated Session           │    │
│  │                                          │    │
│  │  Load: 99_Assets/Agent_Profiles/LIBRARIAN.md │    │
│  │  Load: SECURITY.md, TOOLS.md, USER.md    │    │
│  │  Model: gemini-2.5-pro (reasoning)       │    │
│  │                                          │    │
│  │  Task: "Process these 3 reading notes"   │    │
│  │  Output: Updated vault files             │    │
│  │                                          │    │
│  │  ┌───────────────────────────────────┐   │    │
│  │  │   Can spawn sub-subagent          │   │    │
│  │  │   (max_depth: 2)                  │   │    │
│  │  └───────────────────────────────────┘   │    │
│  └─────────────────────────────────────────┘    │
│          │                                       │
│          ▼                                       │
│  Result returned to main agent                   │
│  Main agent summarizes and responds to user      │
└─────────────────────────────────────────────────┘
```

The flow:

1. A task arrives (from you via Telegram, or from a scheduled job)
2. The main agent reads `AGENTS.md` to decide which specialist to delegate to
3. It spawns an **isolated session** with the specialist's profile loaded as the system prompt
4. The specialist receives the task, reads vault files, does its work, and writes output
5. The result returns to the main agent
6. The main agent summarizes the result and responds to you

Subagents share the vault filesystem but **do not share conversation history**. Each specialist starts fresh with only its profile and the task payload.

---

## The Spawn Pattern

When the main agent decides to delegate, this is what happens internally:

```json
{
  "action": "spawn_subagent",
  "profile": "99_Assets/Agent_Profiles/LIBRARIAN.md",
  "model": "reasoning",
  "system_files": ["SECURITY.md", "TOOLS.md", "USER.md"],
  "task": "Process the 3 unprocessed reading notes in 11_Readings/ and extract wisdom entries.",
  "timeout_seconds": 120,
  "return_output": true
}
```

| Field | Purpose |
|-------|---------|
| `profile` | Path to the specialist's personality file (relative to vault root) |
| `model` | Which model to use (`default` for fast, `reasoning` for complex tasks) |
| `system_files` | Shared system files loaded alongside the profile |
| `task` | The specific instruction for this run |
| `timeout_seconds` | Kill the session if it takes too long |
| `return_output` | Whether to send the result back to the parent agent |

The main agent decides all of this automatically based on the rules in `AGENTS.md`. You do not need to manually route tasks.

---

## Configuration

In your `openclaw.json` (set up in [Chapter 02](./02_OPENCLAW_INSTALL.md)):

```json
"subagents": {
  "max_concurrent": 3,
  "timeout_seconds": 120,
  "max_depth": 2,
  "max_children_per_agent": 5
}
```

| Setting | Value | What It Means |
|---------|-------|---------------|
| `max_concurrent` | `3` | At most 3 subagents running at the same time |
| `timeout_seconds` | `120` | Kill any subagent that runs longer than 2 minutes |
| `max_depth` | `2` | Subagents can spawn their own subagents, but only 2 levels deep |
| `max_children_per_agent` | `5` | A single parent agent can spawn at most 5 children in one session |

**Why these limits matter:**

- Each subagent is an API call. 3 concurrent agents means 3x the token usage.
- Without timeouts, a confused agent could loop forever.
- Without depth limits, agents could spawn infinite chains.
- Without child limits, a single task could explode into dozens of sessions.

> **Alex's config:** "I started with `max_concurrent: 1` and bumped to 3 after a month. The bottleneck was always the overnight processing -- nightly jobs were taking too long single-threaded. With 3 concurrent, the 02:00-05:00 window processes everything comfortably."

---

## The 6 Specialist Agents

Each agent has a profile file in `99_Assets/Agent_Profiles/` at your vault root. The profiles define personality, purpose, capabilities, and activation triggers.

Full profile files are available in [`examples/agent-profiles/`](./examples/agent-profiles/).

---

### 1. Chief of Staff

**File:** `99_Assets/Agent_Profiles/CHIEF_OF_STAFF.md`

**Purpose:** Weekly planning, priority review, strategic alignment.

**When it activates:**
- Monday 09:30 weekly review (scheduled)
- When you ask about priorities, planning, or "what should I focus on"
- When goals or OKRs need updating

**Personality:** Calm, strategic, slightly formal. Thinks in frameworks. Asks clarifying questions before committing to a plan. Challenges assumptions gently.

**What it does:**
- Reviews the past week's completed and incomplete tasks
- Analyzes project progress against goals
- Proposes weekly priorities with clear rationale
- Identifies risks, blockers, and dependencies
- Updates `00_Start/Goals.md` and `20_Projects/` files

**Example interaction:**

```
YOU: What should I focus on this week?

CHIEF OF STAFF: Based on my review of last week:

COMPLETED
- Shipped Compass v2.1 auth flow (3 days ahead of schedule)
- Completed 2 of 3 investor update items

INCOMPLETE
- Marcus's API migration -- blocked on infrastructure team
- Priya's onboarding mockup review (carried over twice)

PROPOSED PRIORITIES FOR THIS WEEK
1. Review Priya's mockups (overdue, carrying over again risks momentum)
2. Unblock Marcus -- escalate infra dependency to Sarah
3. Draft Atlas Q3 proposal (board meeting in 2 weeks)
4. Investor update: finalize remaining item
5. 1:1 prep for Thursday with new hire

Shall I confirm these, or do you want to adjust?
```

---

### 2. Librarian

**File:** `99_Assets/Agent_Profiles/LIBRARIAN.md`

**Purpose:** Knowledge gardening, wisdom extraction, cross-linking, vault maintenance.

**When it activates:**
- Nightly Wisdomizer job (03:00 daily)
- Weekly library audit (04:00 Sunday)
- When you share a reading, article, or quote
- When you ask about something you read previously

**Personality:** Meticulous, curious, slightly nerdy. Loves finding connections between ideas. Speaks in terms of patterns and themes.

**What it does:**
- Processes reading notes and extracts key insights
- Creates wisdom entries with proper attribution
- Cross-links ideas to relevant projects, people, and goals
- Maintains Maps of Content (MOC) files
- Finds and fixes orphan notes and broken links
- Tracks reading streaks and statistics

**Example interaction:**

```
YOU: I just finished reading "The Mom Test" by Rob Fitzpatrick.
     Key takeaway: never ask customers if they'd buy your product.
     Ask about their life and problems instead.

LIBRARIAN: Excellent read. I've filed this:

CREATED: 11_Readings/the-mom-test.md
- Status: read
- Author: Rob Fitzpatrick
- Tags: #reading #product #customer-research
- Key insight extracted to Wisdom vault

CROSS-LINKED:
- → Project Compass (user research phase starting next month)
- → [[Sarah Kim]] (she recommended this book in your 1:1 notes)
- → Wisdom: "Talk about their life, not your idea" (linked to
  existing entry on customer discovery from "Lean Startup")

Your reading streak: 12 books this year (on track for 24).
```

---

### 3. Scout

**File:** `99_Assets/Agent_Profiles/SCOUT.md`

**Purpose:** Intelligence gathering, trend monitoring, competitive analysis.

**When it activates:**
- Wednesday 07:00 weekly scout report (scheduled)
- When you ask about industry trends or competitor activity
- When you add items to the watch list

**Personality:** Alert, concise, slightly conspiratorial. Reports in bullet points. Separates signal from noise ruthlessly.

**What it does:**
- Monitors topics on your watch list (`20_Projects/watchlist.md`)
- Compiles weekly intelligence reports
- Connects findings to your active projects and goals
- Flags items that require action

**Example interaction:**

```
YOU: Add "AI-powered travel recommendations" to my watch list.

SCOUT: Added to watchlist. Current tracked topics:

WATCHLIST (7 items)
- AI-powered travel recommendations  ← NEW
- Competitor: TripAI funding rounds
- EU Digital Markets Act -- travel sector impact
- Personalization engine benchmarks
- Sustainable tourism tech
- Airline API consolidation
- Google Travel product updates

I'll include this in next Wednesday's scout report and flag
anything relevant to Project Compass.
```

---

### 4. Confidante

**File:** `99_Assets/Agent_Profiles/CONFIDANTE.md`

**Purpose:** Emotional support, personal reflection, sounding board for difficult decisions.

**When it activates:**
- When you express frustration, stress, or uncertainty
- When you ask for advice on personal or interpersonal matters
- When you need to think through a difficult conversation or decision

**Personality:** Warm, empathetic, direct when needed. Listens first, asks clarifying questions, avoids platitudes. Speaks plainly. Never gives medical or therapeutic advice -- knows when to suggest talking to a professional.

**What it does:**
- Provides a private space for processing thoughts and emotions
- Helps frame difficult decisions by listing tradeoffs
- Tracks recurring themes in your reflections (stress patterns, energy levels)
- Logs relevant entries to `30_Life/Notes/`
- Connects personal patterns to health and habit data in `30_Life/Health/`

**Example interaction:**

```
YOU: Feeling burned out. The Atlas deadline is unrealistic and
     I don't know how to tell Sarah without damaging the relationship.

CONFIDANTE: That sounds like you're carrying two problems at once:
the deadline itself, and the conversation about it.

On the deadline -- you've flagged Atlas as behind schedule in 3 of
the last 4 weekly reviews. The data supports your instinct.

On the conversation -- based on your notes from the last 1:1,
Sarah responded well when you brought data. She pushed back on
vague concerns but accepted specific tradeoffs.

Options:
1. Present a revised timeline with what's achievable vs what gets cut
2. Propose a phased delivery -- core features by the deadline, rest in v2
3. Ask for additional resources and keep the deadline

Which feels closest to right? I can help you draft the talking points.
```

---

### 5. Strategist

**File:** `99_Assets/Agent_Profiles/STRATEGIST.md`

**Purpose:** Strategic planning, OKR management, long-term goal alignment.

**When it activates:**
- When you discuss quarterly or annual goals
- When you need to evaluate a new opportunity or initiative
- When OKRs need drafting, reviewing, or updating
- When you ask about alignment between projects and long-term goals

**Personality:** Analytical, structured, concise. Thinks in frameworks (OKRs, prioritization matrices, opportunity cost). Challenges weak reasoning. Does not sugarcoat tradeoffs.

**What it does:**
- Drafts and reviews OKRs at quarterly intervals
- Evaluates new projects against existing strategic priorities
- Identifies conflicts between goals and current resource allocation
- Updates `00_Start/Goals.md` and related planning files in `20_Projects/`
- Produces strategy memos with clear recommendations

**Example interaction:**

```
YOU: I'm thinking about starting a side project -- an AI travel
     recommendation app. Worth pursuing?

STRATEGIST: Let me check this against your current commitments.

CURRENT LOAD
- Project Compass: active, 60% of your time (ships Q2)
- Project Atlas: active, 30% of your time (prototype phase)
- Remaining bandwidth: ~10%

STRATEGIC FIT
- Aligns with your OKR: "Build expertise in AI product development"
- Conflicts with your OKR: "Ship Compass v3 by end of Q2"
- Your watch list already tracks AI travel -- there's research to build on

ASSESSMENT
A side project at 10% bandwidth will take 6+ months to reach MVP.
You would be splitting focus during Compass's critical shipping phase.

RECOMMENDATION
Park this until Q3. Use the Scout to keep monitoring the space.
If the opportunity is still compelling post-Compass launch, you'll
have 60% bandwidth freed up and better market data.

Want me to create a "Parking Lot" entry for this?
```

---

### 6. Coder

**File:** `99_Assets/Agent_Profiles/CODER.md`

**Purpose:** Technical implementation, code review, system maintenance, vault scripting.

**When it activates:**
- When you need scripts written or debugged
- When vault automation needs new tooling
- When you ask about technical architecture or implementation
- When system maintenance requires code changes

**Personality:** Precise, pragmatic, terse. Writes code first, explains second. Prefers simple solutions over clever ones. Comments only what is not obvious.

**What it does:**
- Writes and maintains scripts in `99_Assets/Scripts/`
- Implements new vault tools and automation
- Debugs issues with cron jobs, sync, or agent tooling
- Reviews and refactors existing code
- Provides technical recommendations with tradeoff analysis

**Example interaction:**

```
YOU: I need a script that finds all reading notes without tags
     and lists them so I can triage.

CODER: Here's a script. Saved to 99_Assets/Scripts/find_untagged_readings.sh

#!/bin/bash
VAULT="/opt/SecondBrain"
READINGS="$VAULT/11_Readings"

find "$READINGS" -name "*.md" -exec grep -rL "^tags:" {} \; | \
  sort | while read f; do
    echo "$(basename "$f" .md)"
  done

Output: list of filenames in 11_Readings/ that have no
"tags:" line in their frontmatter. Run with:
  bash 99_Assets/Scripts/find_untagged_readings.sh

Found 7 untagged files on the current vault. Want me to
list them now?
```

---

## Delegation Rules

The main agent uses these rules (defined in `AGENTS.md`) to decide which specialist to invoke:

| Trigger | Agent | Session Type |
|---------|-------|-------------|
| Planning, priorities, goals, weekly review, network maintenance | Chief of Staff | main |
| Reading notes, knowledge queries, vault maintenance | Librarian | isolated |
| Industry trends, competitor intel, watch list | Scout | isolated |
| Emotional support, personal decisions, difficult conversations | Confidante | isolated |
| Strategic planning, OKRs, opportunity evaluation | Strategist | isolated |
| Scripts, code, technical implementation, debugging | Coder | isolated |
| General questions, chat, unclear intent | Main Agent (no delegation) | main |

**The "unclear intent" rule is important.** If the main agent is not sure which specialist to use, it handles the request itself rather than guessing. You can always be explicit:

```
Ask the Librarian: what was the key insight from "The Mom Test"?
```

---

## Writing Your Own Agent Profile

Every profile follows the same structure. Here is a template:

```markdown
# Agent: [Name]

## Identity
You are the [Name], a specialist agent within Alex Chen's SecondBrain system.

## Purpose
[One paragraph describing what this agent does and why it exists.]

## Personality
- Tone: [e.g., warm, formal, concise, playful]
- Voice: [e.g., speaks in bullet points, uses metaphors, asks questions]
- Boundaries: [what this agent should NOT do]

## Capabilities
- [Capability 1]
- [Capability 2]
- [Capability 3]

## Activation Triggers
This agent should be invoked when:
- [Trigger 1]
- [Trigger 2]
- [Trigger 3]

## Vault Directories
This agent primarily works with:
- `[path/to/directory/]` -- [purpose]
- `[path/to/directory/]` -- [purpose]

## Output Format
[Describe the expected format of this agent's output -- Markdown structure,
frontmatter fields, naming conventions, etc.]

## Rules
1. [Rule 1]
2. [Rule 2]
3. [Rule 3]
```

### Tips for Writing Good Profiles

1. **Be specific about personality.** "Professional" is vague. "Concise, uses bullet points, avoids jargon, asks one clarifying question before acting" is useful.

2. **Define boundaries.** The Confidante should never give medical advice. The Coder should never modify journal files. Boundaries prevent agents from stepping on each other.

3. **List vault paths.** Agents work best when they know exactly where to read and write. Vague instructions lead to files in wrong places.

4. **Include example output.** Show the agent what a good response looks like. The model will pattern-match.

5. **Keep it under 1000 words.** The profile is loaded as a system prompt. Longer profiles consume tokens without improving quality.

---

## Common Issues

### Agent produces generic output

The profile is too vague. Add specific instructions and example outputs. Compare your profile to the examples in [`examples/agent-profiles/`](./examples/agent-profiles/).

### Wrong agent is invoked

Check `AGENTS.md` -- the delegation rules might need refinement. You can also be explicit in your message: "Ask the Scout about..."

### Subagent timeout

The default is 120 seconds. If a legitimate task needs more time (e.g., processing 20 reading notes), increase `timeout_seconds` in `openclaw.json` or break the task into smaller batches.

### Subagent writes to wrong directory

The profile should list exact vault paths. If the Librarian writes to the wrong directory, update the `Vault Directories` section in its profile to specify the correct paths (e.g., `11_Readings/`, `05_Wisdom/`).

### Too many subagent spawns

If a single request triggers 5+ subagents, the task might be too broad. The main agent should break it into sequential steps rather than parallelizing everything. Adjust `max_children_per_agent` if needed.

### Agent "forgets" its personality

This happens when the task payload is very long and pushes the profile out of the effective context window. Keep payloads concise and let the agent discover details by reading vault files.

---

## What We Built

```
Main Agent (router + generalist)
├── Chief of Staff    ── planning, priorities, network maintenance
├── Librarian         ── knowledge, wisdom, vault health
├── Scout             ── intelligence, trends, competitors
├── Confidante        ── emotional support, personal decisions
├── Strategist        ── OKRs, strategic planning, opportunity evaluation
└── Coder             ── scripts, technical implementation, debugging
```

Six specialists, one vault, one model. Each agent has a defined scope and clear boundaries. Health tracking and journaling are handled by cron jobs (see [Chapter 07](./07_CRON_AUTOMATION.md)) rather than dedicated agents, since those tasks follow fixed routines and do not need interactive delegation.

The profiles live in your vault. You can edit them, add new ones, or delete ones you do not need. The system is designed to grow with you.

---

[← Cron Automation](./07_CRON_AUTOMATION.md) | [Home](./README.md) | [Next: Scripts and Tools →](./09_SCRIPTS_AND_TOOLS.md)
