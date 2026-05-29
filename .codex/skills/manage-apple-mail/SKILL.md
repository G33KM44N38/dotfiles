---
name: manage-apple-mail
description: Manage and improve the user's Apple Mail organization safely. Use when the user asks to organize Apple Mail, add or run Mail rules, classify senders, separate pro/perso mail, create dashboards or smart mailboxes, tune invoice/admin/newsletter routing, audit connected mail accounts, or make the mailbox workflow increasingly automatic without deleting mail.
---

# Manage Apple Mail

## Operating Principles

Treat Apple Mail as live personal data. Default to non-destructive changes:

- Do not delete mail, empty trash, unsubscribe, reply, forward, or click message links without explicit confirmation at action time.
- Prefer moving messages to folders, flagging, and creating rules.
- Ignore `Trash`, `Corbeille`, `Junk`, and `Spam` when applying a new rule retroactively unless the user explicitly asks to recover those messages.
- When a sender/pattern is discovered, update both future rules and existing messages when safe.
- Keep `All Inboxes` as the lightweight "new unclassified mail" view.

## Known Setup

Use `references/apple-mail-profile.md` for the current account map, folder conventions, and known learned patterns. Update it when the user teaches a new durable pattern.

Current workflow goal:

- `DASHBOARD_PRO`: main work view.
- `DASHBOARD_PERSO`: personal view.
- `All Inboxes`: triage for new/unclassified mail.
- Folders like `02_PRO_FACTURES`, `01_PRO_ADMIN_COMPTES`, and `04_PRO_NEWSLETTERS` are storage and search targets, not places the user should manually poll.

## Tooling

Use `scripts/apple_mail_manager.py` for repeatable terminal automation. Prefer it over rewriting AppleScript.

Examples:

```bash
python3 /Users/boss/.dotfiles/.codex/skills/manage-apple-mail/scripts/apple_mail_manager.py audit
python3 /Users/boss/.dotfiles/.codex/skills/manage-apple-mail/scripts/apple_mail_manager.py ensure-default-rules
python3 /Users/boss/.dotfiles/.codex/skills/manage-apple-mail/scripts/apple_mail_manager.py apply-known --pattern qonto-transfers
python3 /Users/boss/.dotfiles/.codex/skills/manage-apple-mail/scripts/apple_mail_manager.py add-sender-rule --name "Stripe invoice exact" --sender "invoice+statements@example.com" --destination 02_PRO_FACTURES --scope pro --apply
```

The script uses AppleScript through `osascript`, so Mail may need to be open and the shell/Codex may need macOS automation and Full Disk Access permissions.

## Workflow

1. Audit first when context may be stale.
   Run `audit` to list accounts, email addresses, top-level mailboxes, and rule names.

2. Classify the request.
   - New sender or subject pattern: create a focused rule and optionally apply it to existing non-trash messages.
   - "Run the rule": apply the relevant learned pattern to existing messages.
   - "Why was this not sorted?": inspect sender, subject, recipient account, current mailbox, and rule overlap before changing rules.
   - Dashboard request: use Apple Mail UI for Smart Mailboxes when possible; direct plist edits are fragile because Mail may rewrite them from cache.

3. Create narrow rules.
   Always include recipient/account scoping for pro/perso separation when possible. Use `to or cc header contains <account email>` plus sender/subject criteria.

4. Apply retroactively with care.
   Move matching messages from account mailboxes to the destination folder, but skip trash/junk/spam by default.

5. Report compactly.
   Tell the user the rule created, destination, how many existing messages moved, and whether anything was deliberately skipped.

## Default Destinations

Use these conventions unless the user says otherwise:

- Pro invoices, receipts, accounting transfers: `02_PRO_FACTURES`
- Pro account/security/platform notices: `01_PRO_ADMIN_COMPTES`
- Pro action-required bounces or delivery failures: `00_PRO_A_TRAITER` and flag
- Pro marketing/newsletters: `04_PRO_NEWSLETTERS`
- Personal invoices/receipts: `02_PERSO_FACTURES`
- Personal travel: `03_PERSO_VOYAGE`
- Personal newsletters: `04_PERSO_NEWSLETTERS`

## Known Lessons

- Qonto transfer notices from `support@qonto.com` with subjects `You received a transfer` or `Your transfer has been executed successfully` belong in `02_PRO_FACTURES`.
- Stripe invoice senders like `invoice+statements+...@stripe.com` belong in `02_PRO_FACTURES`.
- `Undelivered Mail Returned to Sender` on pro accounts belongs in `00_PRO_A_TRAITER` and should be flagged.
- Existing broad Qonto admin rules may send Qonto mail to `01_PRO_ADMIN_COMPTES`; add more specific accounting rules when the user identifies transfer/payment mail.
