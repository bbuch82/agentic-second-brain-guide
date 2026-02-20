# MEMORY

## Purpose

This file is the agent's persistent memory. It stores facts, observations, and context that should survive across conversation sessions. The nightly maintenance routine compacts this file by removing entries older than 30 days.

## How to Use This File

- Add entries when you learn something about Alex that is not in USER.md
- Add entries when Alex states a preference or makes a decision
- Add entries for follow-up items that span multiple days
- Remove entries once they are no longer relevant or have been acted upon

## Format

Each entry has a date, category, and content:

```
### YYYY-MM-DD | category | brief title
Content here.
```

---

## Active Entries

### 2026-03-01 | preference | Meeting prep format
Alex prefers meeting prep as 3 bullet points: (1) goal of the meeting, (2) key points to raise, (3) desired outcome. No longer documents needed.

### 2026-03-05 | follow-up | Marcus API migration
Marcus's auth API migration is scheduled for completion by March 14. Alex wants a status update on March 12 if no progress update has been shared.

### 2026-03-08 | observation | Weekend routines
Alex tends to be more reflective on Sunday evenings. Good time for weekly review prompts. Saturday mornings are family time -- avoid non-urgent messages before noon.

### 2026-03-10 | project | Atlas prototype scope
Alex and Sarah agreed: Atlas prototype should focus on 3 use cases (city recommendations, itinerary optimization, local dining). Broader scope deferred to Q3. Board presentation planned for end of March.

### 2026-03-12 | preference | Journal tone
Alex asked the evening journal to be "less corporate." Prefers a personal, honest tone. Reference specific moments from the day rather than generic summaries. This feedback should be reflected in the Confidante profile.

### 2026-03-14 | follow-up | Priya onboarding mockups
Priya's onboarding flow mockups have been reviewed. Alex approved direction A (progressive disclosure). Priya is refining based on feedback. Expected final version by March 21.

### 2026-03-15 | health | Running goal adjustment
Alex adjusted the running goal from 4x/week to 3x/week until the half-marathon training plan starts in April. Current focus is consistency over distance.
