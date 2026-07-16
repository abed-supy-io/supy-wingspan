# Security policy

## Scope

supy-wingspan ships no runtime service and no network code. Its security surface is:

- **Shell in hooks and skill snippets** — anything under `hooks/` or a fenced `bash` block a skill
  instructs Claude to run.
- **The secret-hygiene guarantee** — `supy-secrets-reviewer` and `config/standards/secrets-and-config.md`
  exist to keep credentials out of Supy repos. A gap that lets a committed secret slip through review
  is a security issue in this plugin.

## Reporting a vulnerability

Do **not** open a public issue for a security problem. Report it privately to the Supy engineering
team (contact the maintainer at <abed@supy.io>) with:

- the component (skill / hook / agent) and version from `.claude-plugin/plugin.json`
- a description and, if possible, a minimal reproduction

Never include real secrets in a report — redact them.

## Handling secrets

If you discover a real credential committed anywhere (this repo or a Supy repo), treat it as
compromised: rotate it first, then remove it from history. Do not simply delete the file in a new
commit — the value stays in git history.
