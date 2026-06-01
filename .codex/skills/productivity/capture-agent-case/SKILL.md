---
name: capture-agent-case
description: Capture coding-agent behavior as structured review cases. Use when the user asks to save, archive, log, document, transcript, review later, standardize, or learn from an agent session, including the original prompt, visible conversation transcript, attempted work, final solution, failures, bugs, commands, tests, and follow-up lessons.
---

# Capture Agent Case

## Overview

Save the current or recent coding-agent session as a dated Markdown case file for later review. Preserve the user's original request, the visible conversation transcript, and the solution actually found, then add enough evidence to understand what the agent did well, what failed, and what should be improved.

Default archive location: `${AGENT_CASES_DIR:-$HOME/agent-cases}`.

## Workflow

1. Identify the case boundary:
   - Use the user's initial prompt verbatim when available.
   - Include the visible user/agent transcript when available. If the platform does not expose the full raw transcript, include the accessible conversation turns and state that limitation.
   - Use the final implemented answer or diagnosis as the solution.
   - Include only relevant commands, test results, files touched, and mistakes.
2. Classify the outcome:
   - `solved`: the requested result was completed and verified.
   - `partial`: meaningful progress was made, but something remains.
   - `blocked`: progress stopped on missing access, unclear requirements, broken external state, or repeated failure.
   - `failed`: the agent produced an incorrect solution or could not recover.
3. Write neutral review notes:
   - State concrete failure modes, not vague quality judgments.
   - Separate what happened from what should change next time.
   - Record verification evidence, including tests that were not run.
4. Run `agent-case` to create the archive file. If `agent-case` is not on `PATH`, run `/Users/boss/.dotfiles/bin/agent-case`.
5. Report the created file path to the user.

## Case Fields

Every case should include:

- `title`: short human-readable label.
- `status`: one of `solved`, `partial`, `blocked`, `failed`.
- `initial_prompt`: the user's starting request, as close to verbatim as possible.
- `transcript`: the visible conversation between the user and agent, including corrections or feedback that changed the work.
- `solution`: final fix, answer, or diagnosis.
- `failures`: specific agent mistakes, wrong assumptions, loops, missing checks, or points of confusion.
- `commands`: important commands or tools used.
- `verification`: tests, screenshots, lint checks, manual validation, or explicit "not run".
- `lessons`: changes to prompts, skills, tools, tests, or workflow that would prevent the issue.

Useful optional metadata:

- `repo`: repository path or project name.
- `files`: changed or important files.
- `tags`: compact labels such as `frontend`, `tests`, `git`, `requirements`, `tooling`.
- `agent`: model, tool, or agent name if the user wants to compare agents later.

## Script Usage

Prefer file inputs for multiline prompt and solution text:

```bash
agent-case \
  --title "Fix stale React state in editor" \
  --status solved \
  --repo "/path/to/repo" \
  --prompt-file /tmp/agent-case-prompt.md \
  --transcript-file /tmp/agent-case-transcript.md \
  --solution-file /tmp/agent-case-solution.md \
  --failures "Initially chased the wrong component boundary." \
  --commands "rg EditorState src" \
  --verification "npm test -- editor-state" \
  --lessons "Check reducer ownership before changing UI state."
```

For short cases, inline values are acceptable:

```bash
agent-case \
  --title "Explain failed migration" \
  --status partial \
  --prompt "Why does the migration fail?" \
  --transcript "User: Why does the migration fail?\nAgent: ..." \
  --solution "The migration expects column account_id before it is created." \
  --verification "Read migration order; tests not run."
```

The script prints the created Markdown path.

## Review Quality

Make the case useful to future review:

- Prefer timestamps, file paths, command names, and exact symptoms.
- Keep the archive factual; avoid defending the agent's choices.
- If the user gave feedback during the session, quote or paraphrase it in `failures` or `lessons`.
- If the case reveals a reusable process improvement, say whether it belongs in a prompt, a skill, a test, or a codebase change.
