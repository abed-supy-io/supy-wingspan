# supy-wingspan — CTO Demo & Walkthrough

A 10-minute, copy-paste walkthrough of what the plugin does and proof that it works.
Everything below is runnable — no slides, just the real behavior.

## The one-sentence pitch

One Claude Code plugin, installed once, that makes **every** `supy-*` repo follow Supy
engineering standards automatically. It **detects the repo's stack**, then surfaces **only
the skills and review agents relevant to that stack** — so a backend dev and a Flutter dev
never see each other's tooling, and nobody has to remember to copy agent files between repos.

## Why it exists (the problem it kills)

Today the standards live as loose agent files copied into each repo by hand. We forget to
add them, they drift out of sync, and the AI loses context and works worse. This plugin
**centralizes all of it in one place**. Install it once; it figures out where it is and
applies the right rules — lazily, on demand, driven by *your feature*, not by config you
maintain per repo.

## What's inside (current counts)

| Component | Count | What it is |
| --- | --- | --- |
| Review agents | 11 | Stack-aware reviewers (NestJS, Angular, Flutter, Firebase Functions, TS CLI, AI-agents, k8s) + two stack-agnostic ones (commit/PR conventions, secret scanner) |
| Skills | 29 | Scaffolding, Git, spec-authoring, CI-fixing, Flutter delivery, baseline generator, superpowers wrappers |
| Slash commands | 6 | Thin orchestration over skills |
| Stack templates | 7 | Drop-in enforcement config per stack |

Ships **no runtime code** — only Markdown, JSON, and shell. Every rule traces back to
`config/standards/`, the single source of truth.

---

## Live demo — run these, watch the output

> Run from the repo root. Each block prints what Claude Code sees.

### 1. It knows what kind of repo it's in (SessionStart hook)

```bash
bash hooks/detect-stack.sh
```

The hook fingerprints the repo (`nx.json` + framework dep → angular-nx / nestjs-nx;
`pubspec.yaml` → flutter; `firebase.json` + `functions/` → firebase-functions;
`commander` + `bin` → ts-cli; MCP/agent SDK anywhere → ai-agents; ConfigMap/Secret YAML →
k8s-config) and prints a stack-specific nudge. **This is the "install once, it detects your
repo" claim — proven in one line.**

### 2. Universal skills fire on every repo (UserPromptSubmit hook)

```bash
printf '{"prompt":"can you commit my changes","cwd":"%s"}' "$PWD" | bash hooks/skill-router.sh
```

→ nudges you to the **supy-commit** skill (Conventional Commits, grounded in the standard).
Commit / PR / review / rebase / hotfix / CI-fix work **everywhere**, regardless of stack.

### 3. Stack-scoped skills stay hidden outside their stack (the key claim)

```bash
printf '{"prompt":"check release readiness for the app store","cwd":"%s"}' "$PWD" | bash hooks/skill-router.sh
```

→ **prints nothing.** The Flutter release-readiness skill is suppressed because this isn't a
Flutter repo. This is exactly *"backend and Flutter devs never see each other's skills."*
It's **lazy**: the feature you're working on pulls in its skills — not the other way around.

### 4. It stays quiet when it has nothing to add

```bash
printf '{"prompt":"what time is it","cwd":"%s"}' "$PWD" | bash hooks/skill-router.sh
```

→ **prints nothing.** No context pollution on ordinary turns. Hooks also degrade silently on
any error — a hook can never fail a session.

---

## How it works — worked examples (real output)

These are actual runs of the plugin's hooks against sample repos of each stack. **None of
those repos contain any plugin config** — the plugin figures out everything from the repo's
own files.

### Example 1 — one plugin, four repos, four correct answers

The SessionStart hook fingerprints each repo and prints a stack-specific message:

```text
cd backend/   → detected nestjs-nx repo. Run supy-baseline to generate a CLAUDE.md.
cd frontend/  → detected angular-nx repo. Run supy-baseline to generate a CLAUDE.md.
cd mobile/    → detected flutter repo. Run supy-baseline to generate a CLAUDE.md.
cd functions/ → detected firebase-functions repo — remediation-first: secrets via Secret
                Manager (never literals) + runtime-enforced auth markers. Run supy-review.
```

*This is the "install once, it detects your repo" claim.*

### Example 2 — the SAME prompt behaves differently per repo (the "lazy" claim)

Prompt: **"implement the figma design for the login screen"**

```text
in the FLUTTER repo  → nudges: use supy-figma-implement-design (tokens, Widgetbook, goldens)
in the BACKEND repo  → (silent) — a backend dev is never shown a Figma skill
```

Prompt: **"is the app ready to release to the store"**

```text
in the FLUTTER repo   → nudges: use supy-app-release-readiness (audits each platform)
in the FRONTEND repo  → (silent) — offered only where it applies
```

*The feature you're working on pulls in its skills — not the other way around.*

### Example 3 — universal intents fire on every repo

Prompt: **"review my changes then commit them"** — in the backend repo:

```text
- Committing? Use supy-commit — Conventional Commits, grounded in the standard.
- Reviewing changes? Run supy-review — detects the stack, dispatches matching reviewers.
```

Commit / PR / review / rebase / hotfix / CI-fix work **everywhere**, regardless of stack.

### Example 4 — what `supy-review` actually dispatches, by stack

When you run the review, it picks the reviewer set for the detected stack:

```text
nestjs-nx          → 6 backend reviewers  + commit/PR + secrets
angular-nx         → angular reviewer      + commit/PR + secrets
flutter            → flutter reviewer      + commit/PR + secrets
firebase-functions → firebase reviewer     + commit/PR + secrets
ts-cli             → ts-cli reviewer       + commit/PR + secrets
ai-agents          → ai-agents reviewer    + commit/PR + secrets
k8s-config         → secrets reviewer
```

The commit/PR and secrets reviewers are **stack-agnostic** — they run on every stack, so no
repo ever ships a committed credential or a non-conventional commit.

You can reproduce Examples 1–3 yourself with the four commands in the next section.

---

## Install it in a real repo (for the huddle)

```text
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
/reload-plugins
```

Then open any `supy-*` repo and start a session — the SessionStart nudge tells you the
detected stack, and typing a request (e.g. "review my changes before I push") surfaces the
matching skill.

## The cross-repo consistency angle

Because the standards live in **one** plugin, a feature that spans repos (say backend +
Flutter) gets the **same** rules applied on both sides. No more "we forgot to add the secret
scanner to that repo." Fix a rule once in `config/standards/`, every repo picks it up.

## Where to look next

- `README.md` — full component catalog and per-stack skill matrix
- `config/standards/` — the mined standards every agent cites (source of truth)
- `docs/USAGE.md` — day-to-day usage
- `CLAUDE.md` — how we develop the plugin itself

---

*Bottom line for the CTO: it's built, it's wired, and the two headline behaviors —
auto-detect the stack and surface only that stack's skills — are demonstrated live above in
four commands.*
