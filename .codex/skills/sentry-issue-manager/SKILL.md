---
name: sentry-issue-manager
description: "Manage Sentry issues as an engineering triage loop: inspect Sentry projects, classify production errors, decide whether to ignore, resolve, route to humans, or create linked tracker tickets, and keep Sentry state aligned with fixes. Use when the user asks to triage, clean up, prioritize, route, or manage Sentry issues, error groups, releases, regressions, or alert noise."
---

# Sentry Issue Manager

Manage Sentry issues for humans and AI agents.

Treat this skill as an error-triage product manager. The goal is to turn noisy Sentry groups into
clear engineering decisions: what is real, what is urgent, what can be safely handled by an agent,
what needs a human, what should be ignored, and what needs a linked tracker ticket.

Default to `dry-run`. Only mutate Sentry or a tracker when the user explicitly asks for `apply`.

When running unattended, never wait for user input. Record missing setup, unresolved ambiguity, and
recommended next action in the final report.

## Core Contract

Use exactly one Sentry organization/project scope per run. Do not merge unrelated projects unless the
user explicitly asks for a portfolio-level report.

Supported Sentry access:
- Sentry web/API through an available connector or authenticated environment.
- `sentry-cli` when installed and authenticated.
- Direct Sentry REST API when `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and a project slug are available.
- Exported Sentry issue JSON only when the user provides it as the source for an offline dry-run.

Supported tracker linkage:
- Linear when available or named by the user.
- GitHub Issues when explicitly named and `gh` is authenticated.
- No tracker mutation when no tracker is named or discoverable; report candidate tickets instead.

Prefer Linear for created engineering tickets when both Linear and GitHub are available, unless the
repo or user clearly uses GitHub Issues as the source of truth.

## Classification Labels

Use this fixed classification vocabulary in reports and tracker tickets. Do not invent extra routing
labels unless the user asks.

### Severity

Use Sentry's native level, priority, users affected, event count, trend, and release data first.

- `severity:critical` - widespread breakage, payment/auth/data-loss path, current release spike, or many affected users.
- `severity:high` - user-visible breakage with repeated events or clear regression.
- `severity:medium` - real but limited error, low affected-user count, no urgent business path.
- `severity:low` - rare, noisy, non-user-visible, or known harmless issue.

### Type

- `type:bug` - product/runtime bug requiring a code fix.
- `type:config` - environment, release, source map, SDK, sampling, or alert configuration issue.
- `type:dependency` - third-party service/library issue or upgrade needed.
- `type:noise` - issue is expected, unactionable, duplicate, bot/client noise, or should be filtered.
- `type:unknown` - not enough information to classify confidently.

### Routing

- `agent:ready` - safe for an AI coding agent to fix from a tracker ticket.
- `needs:human` - requires product, incident, data, auth, billing, security, infrastructure, or ambiguous-behavior judgement.
- `sentry:monitor` - keep observing before action; do not create a fix ticket yet.
- `sentry:ignore-candidate` - likely safe to ignore or filter, but only apply when evidence is strong.

Use tracker-native status fields for lifecycle state. Use labels only as routing/classification.

## Agent-Ready Rules

Only mark `agent:ready` or create an agent-ready tracker ticket when all are true:
- the issue is reproducible or has a clear stack trace pointing to owned code
- likely fix is small and code-local
- no product, UX, security, privacy, billing, auth, data migration, deployment, or incident judgement is required
- the expected behavior is clear from code, tests, docs, or obvious crash semantics
- verification can be stated
- no active linked PR or tracker issue already covers it

Good examples:
- missing null guard with clear stack trace
- source map/upload/config drift with a documented fix
- failing parser on a clearly invalid input path
- simple dependency regression with a known patched version
- Sentry noise caused by a known bot pattern that can be filtered safely

Use `needs:human` when:
- the affected behavior is unclear
- the issue touches auth, payments, customer data, privacy, or operational policy
- the fix requires product or UX choice
- Sentry evidence is too thin to act on
- the event looks incident-like or might need comms/escalation
- a previous fix attempt regressed or failed

## Triage Assessment

When creating or updating a tracker ticket, include this block:

```md
## Sentry Triage Assessment

Sentry issue: <url>
Severity: critical | high | medium | low
Type: bug | config | dependency | noise | unknown
Routing: agent:ready | needs:human | sentry:monitor | sentry:ignore-candidate

Evidence:
- <event count, users affected, release, stack frame, trace, environment, first/last seen>

Reason:
<1-3 sentences explaining the classification.>

Suggested plan:
1. <small first step>
2. <small second step>
3. <verification step>
```

If human input is needed, include:

```md
Human needed:
<specific decision required before work can proceed.>
```

## Workflow

Run the full loop by default.

### Step 1 - Load Context

Read local project guidance first when working from a repo:
- `AGENTS.md`
- `CLAUDE.md`
- README and development docs
- Sentry setup docs, release/source-map docs, observability docs
- issue templates and tracker conventions

Use this context to decide ownership, severity, and verification. Do not make up incident policy.

### Step 2 - Resolve Sentry Scope

Use the organization/project/environment/release the user names.

Otherwise, infer only from explicit local configuration such as:
- `sentry.properties`
- `.sentryclirc`
- Sentry SDK config
- release upload scripts
- environment variables
- CI deploy/release workflows

If scope cannot be resolved, stop and ask for the Sentry org/project or report the missing variables
for unattended runs.

Useful commands and API shapes:

```bash
sentry-cli info
sentry-cli issues list --org <org> --project <project>
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/<org>/<project>/issues/?query=is:unresolved"
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/issues/<issue_id>/events/latest/"
```

### Step 3 - Fetch Issues

Fetch unresolved issues first. Include:
- title, permalink, issue id, short id
- status and substatus
- level/priority
- first seen, last seen, event count, users affected
- project, environment, release, culprit, platform
- latest event stack trace and in-app frames
- tags that affect routing, such as browser, OS, URL, transaction, customer tier, or server name
- linked issues, commits, releases, and pull requests when available

For large projects, prioritize:
1. regressions in the latest production release
2. high user count
3. high event count or fast upward trend
4. payment/auth/data paths
5. new issues first seen recently

### Step 4 - Deduplicate Existing Work

Before creating anything, check:
- Sentry linked issues
- Linear or GitHub tickets mentioning the Sentry issue URL/id/title
- open PRs linked from Sentry, tracker, commit messages, or branch names
- recently resolved Sentry issues with the same culprit or stack trace

Never create duplicate tracker tickets. If a matching ticket exists, report the Sentry issue as
already tracked and suggest any missing ticket updates.

### Step 5 - Classify And Route

For each issue:
1. Determine severity from Sentry evidence and local business context.
2. Determine type.
3. Decide routing: `agent:ready`, `needs:human`, `sentry:monitor`, or `sentry:ignore-candidate`.
4. Identify a likely owner or code area when evidence supports it.
5. Decide whether to create/update a tracker ticket.
6. Decide whether Sentry status should change in `apply` mode.

Do not resolve or ignore an issue just because it is old. Use event recency, release, and fix
evidence.

### Step 6 - Apply Conservative Mutations

In `dry-run`, report proposed changes only.

In `apply`, only perform changes explicitly allowed by the user:
- create or update linked tracker tickets with the triage assessment
- add tracker labels/classification
- link tracker tickets back to Sentry when supported
- assign an owner when ownership is obvious from local policy
- archive/ignore Sentry noise only when the user allowed ignores and evidence is strong
- resolve Sentry issues only when there is clear fix evidence, such as a merged PR, release fix, or
  issue no longer occurring after the fix release

Never apply destructive or high-risk changes from this skill:
- do not delete Sentry projects, alerts, releases, or events
- do not change sampling, PII scrubbing, alert rules, or SDK config unless the user explicitly asked
  for that configuration task
- do not mark incident-like issues ignored without human approval
- do not close tracker tickets unless linked Sentry and PR evidence clearly supports closure

### Step 7 - Sync With Fix Evidence

When a linked PR is open:
- keep the Sentry issue unresolved unless the tracker policy says otherwise
- remove `agent:ready` from the tracker ticket if active work already exists
- move tracker status to review/in progress when available

When a linked PR is merged:
- verify the fix release if possible
- resolve the Sentry issue only if events stopped after the fix release or the PR clearly addresses
  the issue and the user allowed Sentry resolution
- move tracker status to done only when tracker policy and evidence support it

When an issue regresses:
- reopen or report reopening as needed
- add `needs:human` if the previous fix failed and the next step is unclear

### Step 8 - Alert And Noise Hygiene

Report, but do not silently mutate:
- noisy issues suitable for inbound filters or ignore rules
- missing source maps or poor stack traces
- releases missing commits
- environments mixed into one project in a confusing way
- alerts that appear too noisy or too broad
- repeated ignored issues that still affect users

Create tracker tickets only for concrete, bounded, evidence-backed hygiene work.

### Step 9 - Verify Apply Runs

After an `apply` run, verify:
- every created/updated tracker ticket links to the Sentry issue
- every linked Sentry issue has the intended tracker link when supported
- `agent:ready` only appears on clear, bounded work
- `needs:human` is present when judgement is required
- no duplicate tracker issue was created
- resolved/ignored Sentry issues have clear evidence in the report
- unresolved high/critical issues are called out with next action

### Step 10 - Report

End with a compact summary:
- Sentry org/project/environment used
- mode used: `dry-run` or `apply`
- number of issues inspected
- top critical/high issues
- issues already tracked
- tickets proposed or created
- issues marked `agent:ready`
- issues needing humans
- monitor/ignore candidates
- Sentry issues resolved/ignored, if any
- alert/noise hygiene findings
- verification result
- blockers and recommended next action

## Safety Rules

- Default to `dry-run`.
- Do not mutate Sentry or trackers unless the user explicitly asks for `apply`.
- Do not create duplicate tracker tickets.
- Do not mark Sentry issues resolved without clear fix evidence.
- Do not ignore incident-like, auth, payment, privacy, security, or data issues without human approval.
- Do not add `agent:ready` when expected behavior is ambiguous.
- Do not use Sentry event count alone as severity; include affected users, recency, release, and impact.
- Prefer report-only for configuration changes unless the user asked for configuration edits.
- When unsure, route to `needs:human` with a specific question.

## Example Invocations

```text
$sentry-issue-manager dry-run for Sentry org acme project web production
$sentry-issue-manager apply for Sentry project api: create Linear tickets only, do not resolve or ignore Sentry issues
$sentry-issue-manager dry-run from exported sentry-issues.json
```
