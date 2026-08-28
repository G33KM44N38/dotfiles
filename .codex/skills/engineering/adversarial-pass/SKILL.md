---
name: adversarial-pass
description: Run one independent, read-only attack against one explicit claim about a plan, change, or fix. Use when the user asks for an adversarial pass, hunter pass, red-team pass, or asks Codex to prove a specific claim wrong. Do not use for broad code review or open-ended audits.
---

# Adversarial pass

Try to disprove one claim. This is a one-shot investigation, not a review loop.

Assume the user is new to adversarial passes. Explain each section in plain language every time the skill runs. Define specialist terms such as **fence**, **hunter**, **finding**, **reachability**, and **reproduction** when they first appear. Do not give unexplained labels.

## Required fence

Before the pass starts, establish:

- **Claim:** One falsifiable statement.
- **Scope:** The exact files, diff, plan, or artifact that the hunter can inspect.
- **Budget:** A clear limit on time, tool calls, or investigation size.
- **Reachability:** The real user, operator, integration, or system action that is in scope.

### Intake gate

On invocation, check whether the user supplied all four fields. Do not inspect the work or start the hunter while a field is missing.

Ask for exactly one missing field per turn. Use this order:

1. Claim
2. Scope
3. Budget
4. Reachability

Explain only the field that you ask for. Give one short example. Then stop and wait for the user's answer.

Use these explanations:

- **Claim:** The one statement that the hunter must try to prove wrong. Example: "A promotion code can affect an order only once."
- **Scope:** The exact work that the hunter can inspect. Example: "src/checkout/promotion.ts and its tests."
- **Budget:** The hard limit for the pass. Example: "15 minutes or 12 tool calls."
- **Reachability:** The real action that can cause the behavior. Example: "A customer selects Buy twice on a slow connection."

Keep all values that the user already supplied. After each answer, ask only for the next missing field. Start the pass only after the fence is complete. Do not infer a missing field unless the user explicitly asks you to infer it.

## Run the hunter

1. Start exactly one fresh subagent. Give it only the fence, the scoped artifacts, and the minimum domain context needed to test the claim. Do not give it the author's conclusions or suspected findings.
2. Keep the pass read-only. The hunter can inspect source, history, and documentation, and can run safe existing checks. It must not edit repository files, commit, push, update tickets, or make external changes.
3. Tell the hunter to try to prove the claim false. A successful result can be either a concrete counterexample or no accepted finding.
4. Accept a finding only when all of these are present:
   - a real in-scope action reaches the behavior;
   - precise evidence identifies the relevant artifact and location;
   - a concrete reproduction or fully specified reproduction path demonstrates the failure;
   - the finding contradicts the stated claim.
5. Drop invented inputs, manual data corruption with no supported path, unreachable states, style opinions, unrelated defects, and claims that exceed the fence.
6. Stop after the first pass or when the budget is exhausted. Do not ask the hunter to search again. Do not let it edit or fix what it finds.

If no independent subagent facility is available, say that the fresh-eyes requirement cannot be met and stop. Do not silently let the author act as the hunter.

## Report

The primary agent checks that each returned item meets the fence, but does not start a second hunt. The user judges severity and decides what to fix.

Report the fence, followed only by accepted findings. For each finding, give:

1. **Real action:** What a real user, operator, integration, or system does to reach the problem.
2. **Evidence:** The exact source, plan, or document location that supports the finding, with file and line when applicable.
3. **Reproduction:** The steps that another person can follow to see the same problem.
4. **Why the claim fails:** A plain explanation of how the result proves the original claim wrong.

If nothing survives the gate, say: `No finding survived the reachability and evidence gates.` Then stop. Do not add speculative concerns, severity labels, fixes, or a claim that the whole system is safe.

## After this pass

This invocation ends with the report. If the user later asks for a fix, add a deterministic regression test for the bug class, implement the chosen fix, and run the relevant regression checks. Do not rerun the same hunter to prove the fix.
