---
name: client-prod-pr
description: Prepare a GitHub pull request that helps a non-technical client run a project in production-like/dev handoff mode, especially for Docker onboarding. Use when the user asks to make a prod PR, client handoff PR, babysit a client, automate PR preparation, or write French client instructions.
metadata:
  short-description: Prepare client handoff PRs
---

# Client Prod PR

Prepare a practical PR and French handoff for a non-technical client.

## When To Use

Use this skill when the user wants to:

- create or prepare a production/client PR;
- automate branch, commit, push, and GitHub PR creation;
- explain exactly what changed and what the client must do;
- package a local run workflow, usually Docker, into a client-safe handoff.

## Workflow

1. Inspect the repo instructions first: `AGENTS.md`, package manager, no-go areas, release restrictions.
2. Check `git status --short --branch` and protect unrelated/user changes.
3. Prefer adding or using a local helper script, usually `scripts/client-prod-pr.sh`, instead of relying on manual multi-step instructions.
4. The script should:
   - create a branch if currently on the base branch;
   - stage relevant files only;
   - explicitly exclude secrets and proof artifacts: `.env`, `.env.*`, `.env.asc`, `.env.gpg`, videos, screenshots, `test-results/**`;
   - run configurable checks;
   - commit;
   - push;
   - create a GitHub PR with `gh pr create` when authenticated;
   - write a French PR body and French client instructions to `/tmp`.
5. Create the PR ready for review. Never use draft mode unless the user explicitly requests it in the current task.
6. Do not merge, publish releases, run OTA updates, rotate secrets, or run production migrations.

## Recommended Command Shape

If the repo already has `pnpm client:prod-pr`, recommend:

```bash
PR_TITLE="Dockeriser le projet pour une prise en main client simple" \
COMMIT_MESSAGE="chore: add client handoff workflow" \
BRANCH_NAME="chore/client-prod-handoff" \
pnpm client:prod-pr
```

For a fast call where the user accepts risk:

```bash
RUN_CHECKS=0 PR_TITLE="Dockeriser le projet pour une prise en main client simple" pnpm client:prod-pr
```

## French Client Instructions Template

Give the client concise instructions in French:

~~~markdown
# Instructions pour lancer le projet

1. Installer Docker Desktop.
2. Ouvrir un terminal dans le dossier du projet.
3. Lancer:

```bash
pnpm docker:up
```

4. Ouvrir les URLs indiquees par l'equipe.
5. En cas de probleme, envoyer:

```bash
pnpm docker:ps
pnpm docker:logs
```

Important: ne jamais partager publiquement les fichiers `.env`, `.env.asc` ou `.env.gpg`.
~~~

## Verification

Before final response, run the cheapest relevant proof:

- shell syntax check for any script: `bash -n scripts/client-prod-pr.sh`;
- command help if available: `pnpm client:prod-pr --help`;
- `git status --short` to list changed files.

Report what passed and any checks skipped.
