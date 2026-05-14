---
name: commit-stage
description: >
  Stage changes, generate a conventional commit message, and create the commit.
agent: build
created: 2026-04-24
---

Prépare un commit propre à partir de l’état courant du dépôt.

## Workflow
1. Inspect the repository state with `git status --short`
2. Stage only the intended files
3. Generate a conventional commit message from the staged diff
4. Commit the staged files with `git commit`
5. Report the commit hash and a short summary of what changed

## Règles
- Never stage unrelated files
- Never use `git add .` unless the user explicitly asked for all changes
- Prefer conventional commit types: `feat`, `fix`, `refactor`, `docs`, `test`,
  `chore`, `build`, `ci`, `style`, `perf`, `revert`
- Keep the subject short and imperative
- Add a body only when the reason is not obvious from the diff
- Do not amend existing commits unless the user explicitly asks

## Si rien n'est staged
- Le dire clairement
- Demander quels fichiers il faut stage

## Si `$ARGUMENTS` sont fournis
- Les traiter comme intention de commit ou contexte additionnel
- Les utiliser pour choisir le type, le scope, et le sujet

## Sortie
- Le message de commit
- Le hash du commit après succès
- Un bref résumé des changements staged
