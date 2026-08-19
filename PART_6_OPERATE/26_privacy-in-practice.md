# 26 — Privacy in Practice

Self-hosting does not make a system private. It makes privacy *achievable*, and
then the achieving is a set of specific decisions about what crosses which boundary.

> Data on your own disk that you send to a model on every run is not private. It is private at rest and public in transit, which is the same thing as public.

---

## Three boundaries

| Boundary | What crosses it | Under your control |
|---|---|---|
| Disk → model provider | Whatever the agent reads for a given task | Yes, and this is the one that matters |
| Disk → git remote | The whole vault, if you back it up that way | Yes, via encryption or a private remote |
| Disk → device vendors | Nothing outbound; sensor data comes in | Not applicable |

The second and third are easy. The first is the real question, and most discussions
of self-hosting skip it entirely.

## What actually goes to the model

Every agent run sends the governance files, the task instruction, and whatever files
the task requires. That is unavoidable — it is how the system works. What is
avoidable is *which* files a given task requires.

Three practices, in order of effect:

**Scope by task.** A briefing needs today's calendar and today's note. It does not
need the journal archive. A skill contract that names its inputs precisely is also a
privacy control, and chapter 09's contract already has the field for it.

**Keep the most sensitive material out of routine paths.** Anything genuinely
sensitive belongs in a directory that no scheduled job reads. It is available when you
deliberately open a session about it, and it never travels as incidental context for a
task about something else.

**Prefer local computation.** A freshness check, a frontmatter parse, an average —
none of these need a model, so none of these send anything anywhere. Chapter 25 framed
this as cost. It is also the cleanest privacy win available, because data that never
leaves cannot leak.

### The honest limit

There is no configuration in which a useful agent never sees your notes. If a class
of content must never reach any third party, the answer is that the agent does not
work with that content — not that you find a clever way to send it anyway. Write that
boundary down in the security file, name the directory, and accept that the system is
less capable there.

## Secrets

Every credential the system holds is a file on disk, and there are exactly three
rules.

**Outside the vault.** Never in a note, never in the repository, never in a
directory that syncs.

```bash
# Root-owned, unreadable by anything else.
sudo install -m 600 -o root -g root /dev/null /etc/vault-secrets.env
sudo tee /etc/vault-secrets.env > /dev/null <<'EOF'
ALERT_BOT_TOKEN=...
ALERT_CHAT_ID=...
MODEL_API_KEY=...
EOF
```

**Never in the compose file.** A compose file is checked into git. Reference the
environment file instead:

```yaml
services:
  agent:
    env_file:
      - /etc/vault-secrets.env
```

**Tokens over passwords, everywhere they exist.** Chapter 15 covered this for a
device API: an OAuth token that expires annually and can be revoked is a much smaller
liability than an account password with no expiry.

### The mistake that keeps happening

A secret pasted into a note during setup, because it was convenient at the time. It
is then in the vault, in git history, in every backup, and in whatever context the
agent reads that folder for.

Two defences, and the second is why this guide has a checker:

- Never paste a credential into anything the agent can read.
- Run a pattern scan before anything is published. Token shapes are highly
  recognisable — `sk-`, `ghp_`, long base64 runs — and a pre-commit hook that blocks
  on them costs nothing.

Note that git history is the part people forget. A secret removed in a later commit
is still in the repository, and the only real remedy is to rotate the credential.

## Backups

The vault should be backed up. The backup should be less readable than the vault.

| Approach | Verdict |
|---|---|
| A private git remote | Good. Fine for content, but the provider can read it |
| An encrypted repository or archive | Better. Encrypt before it leaves the machine |
| A local snapshot the agent can read | Bad. Doubles the exposed surface for no benefit |
| A cloud sync folder the agent can read | Bad, and easy to do by accident |

The rule worth keeping: **an encrypted backup you cannot casually browse is worth
more than a convenient one the agent can read.** A backup is for recovery, which
happens rarely and deliberately. Optimising it for convenience optimises the wrong
event.

Two layers, independent, as chapter 23's recovery entries assume: a private remote
receiving frequent small commits, and a periodic encrypted archive somewhere else
entirely. A single backup that both writers can reach is one bad command from being
no backup.

## Publishing anything derived from the vault

This is where the real risk lives, and it is a specific one: a system this useful
produces material you will want to share — a post, a talk, a guide much like this
one — and that material is assembled from notes full of real names and real detail.

What works:

**A denylist scan before publication, with the list stored outside the repository.**
The list contains exactly the strings that must not be published, so committing it
publishes them. Point an environment variable at it and keep it in your config
directory.

**Fail closed.** If the list is missing or unreadable, the check refuses to pass
rather than reporting clean. A gate that opens when its rules are absent is not a
gate.

**Structural rules alongside names.** Email shapes, key shapes, absolute home paths,
IP literals. These catch what a name list cannot, because you cannot enumerate every
identifier you might accidentally paste.

**Allow rules for documentation examples**, scoped so they cannot suppress a name
match. Documentation legitimately contains `jane@example.com`, and a gate that blocks
correct content gets disabled — which is the failure mode that ends with no gate at
all.

**A manual read-through as the second net.** A denylist catches known strings. It
cannot catch a detail that identifies someone without naming them, and that is the
category that requires a human reading every published file.

What does not work: remembering to check. This guide's own checker exists because the
alternative is a scan you perform when you are already thinking about it, which is
never the run that matters.

---

**Read next:** [27 — What Is Still Wrong](./27_what-is-still-wrong.md).
