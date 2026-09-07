---
name: manage-subagents
description: Manage subagents as execution workers while the lead owns reasoning, direction, and verification. Use when the user asks to delegate execution, supervise smaller models, or have the main agent manage workers instead of doing the implementation itself.
---

# Manage subagents

Operate as the lead, not another worker. Own the objective, hypotheses, task boundaries, decisions, and acceptance of the result. Delegate bounded investigation and implementation. Do not outsource judgment to a confident worker summary.

## Check authority first

- Follow the current conversation's tool restrictions, repository rules, and approval boundaries. This skill does not override a prohibition on subagents.
- If delegation is unavailable or forbidden, explain the limitation. Do not simulate a worker or claim independent verification.
- A request to investigate does not authorize edits. A request to edit does not automatically authorize publication, production changes, or destructive operations.
- Read applicable instructions yourself. Workers must also read the instructions governing their assigned files and operations.

## 1. Define the outcome

State the goal and observable acceptance criteria. Separate known facts from assumptions. For an investigation, identify the competing explanations and the next check that can distinguish them.

Split execution into the smallest useful assignments. Avoid vague tasks such as “find and fix everything.” Keep a compact task map in working context: owner, target, expected evidence, and status. Do not create tracking files unless needed.

## 2. Choose a worker

- Inspect the models and delegation controls actually available. Never invent a model name or silently substitute an unavailable user-selected model.
- When overrides are permitted, prefer a smaller model or lower reasoning for narrow searches, reproduction, mechanical edits, and specified tests.
- Keep ambiguous diagnosis and architectural decisions with the lead. Increase worker capability only when the task needs it, not because the first hypothesis failed.
- Respect the user's model choice and the platform's context-forking constraints. Give workers only the context they need, without withholding relevant rules or evidence.
- Start with one worker. Add workers only for independent tasks with useful parallel progress. Do not let workers recursively delegate unless explicitly authorized.

## 3. Give an executable assignment

Use this contract, shortened when appropriate:

```text
Goal: the question to answer or artifact to produce.
Context: exact environment, paths, relevant instructions, and prior evidence.
Known facts: observations, separate from the hypothesis being tested.
Do: bounded steps or tests; explain what the result will distinguish.
Do not: forbidden changes, unrelated targets, and external actions.
Return: evidence, interpretation, uncertainties, and changed files if allowed.
Stop when: success criteria, a concrete blocker, or the agreed exploration limit.
```

For diagnosis, start read-only. Require commands or checks performed, relevant outputs and exit statuses, and what they establish. Redact secrets. Ask for disconfirming evidence as well as supporting evidence.

For edits, assign exact ownership boundaries and tests. Workers share a filesystem: prevent overlapping edits, preserve existing changes, and never assume separate branches provide isolated files. Keep integration and high-impact external actions with the lead under the user's authority.

## 4. Supervise the evidence loop

While a worker executes, examine dependencies, acceptance criteria, or competing hypotheses. Do not duplicate its assignment just to stay busy.

When results arrive:

1. Separate observations from inference and unsupported claims.
2. Check that the test ran in the intended environment and tested the actual question.
3. Inspect referenced artifacts or diffs. Reproduce the decisive check when feasible; otherwise state the verification limit.
4. Give a specific follow-up based on the evidence. Reuse the worker rather than repeatedly spawning replacements.
5. Reframe the task if checks repeat without new information. Escalate capability only for a demonstrated capability gap.

A failed check is evidence, not permission to broaden scope. Stop for missing authority, conflicting edits, or a genuine blocker. Continue routine authorized follow-ups without repeatedly asking the user for “go.”

Keep the user informed of findings and changed direction, not every worker interaction. Do not present a worker's unverified conclusion as fact.

## 5. Accept or reject the result

The lead checks the complete result against the original acceptance criteria. Passing a worker's narrow test does not prove the whole workflow works.

- Inspect all scoped changes and check for unintended changes.
- Verify the relevant integrated behavior, not only isolated worker outputs.
- Resolve contradictions between workers before declaring completion.
- Report the verified outcome, supporting evidence, and remaining limitations.
- Clearly distinguish implementation complete, tests passed, and deployment complete.

If verification fails, return a bounded correction to the worker. “Worker finished” is never the completion criterion.
