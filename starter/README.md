# Starter

Content, not code. Everything here is a template you copy and edit: the vault
skeleton, the nine system files, the frontmatter conventions, one skill contract, and
two dashboard pages.

**There is no installer and no reference implementation.** That is deliberate. The
scripts in Parts 3 to 5 are shown complete in their chapters, where they sit next to
the reasoning that makes them correct — and a script shipped here would be one more
thing to keep working against APIs that change. Copy them from the chapters, adapt them,
and own them.

## Use it

```bash
cp -r starter/vault ~/secondbrain
cp starter/system/*.md ~/secondbrain/
cp starter/dashboards/*.md ~/secondbrain/00_Start/
cd ~/secondbrain
git init && git add -A && git commit -m "Vault from starter templates"
```

Then work through the placeholders. Every file uses `{{DOUBLE_BRACE}}` for something
only you can fill in, and the guide says where each value comes from.

```bash
grep -rn '{{' ~/secondbrain
```

## What is here

| Path | Chapter |
|---|---|
| `vault/` | [05](../PART_2_BUILD/05_stage-0-thirty-minutes.md) — the directory skeleton |
| `vault/99_Assets/Templates/` | [01](../PART_1_PRINCIPLES/01_the-vault-is-the-api.md) — the frontmatter contract |
| `vault/skills/quick-capture/` | [12](../PART_3_SKILLS/12_skill-inventory.md) — the first skill to build |
| `system/` | [08](../PART_2_BUILD/08_stage-3-system-files.md) — the nine governance files |
| `dashboards/` | [18](../PART_4_SENSORS/18_dashboard-archetypes.md) — habits and health |

## Order

Do not fill in all nine system files at once. Chapter 08 gives a trigger for each — a
rule written before the failure it prevents usually addresses one that was never going
to happen, and costs context on every run regardless.

Start with `IDENTITY.md` and `SECURITY.md`. Those two plus the conventions file are
enough for a working system.
