#!/usr/bin/env python3
import argparse
import subprocess
import textwrap


PRO_ACCOUNTS = [
    ("Babacoiffure", "admin@babacoiffure.com"),
    ("kylian pro", "mayangakylian@gmail.com"),
    ("renayam pro", "renayam.pro@gmail.com"),
    ("babacoiffure google 27", "babacoiffure27@gmail.com"),
]

PERSO_ACCOUNTS = [
    ("kylian perso", "kylianmayanga@gmail.com"),
    ("sunshinedeep", "sunshinedeep81@gmail.com"),
    ("kylian us", "kylianmayangaus@gmail.com"),
    ("junk mail", "azertabj2008@gmail.com"),
]

SKIP_MAILBOXES = {"Trash", "Corbeille", "Junk", "Spam"}


def osa(script: str) -> str:
    result = subprocess.run(
        ["osascript"],
        input=script,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def as_list_literal(items):
    return "{" + ", ".join(f'"{item}"' for item in items) + "}"


def rows_for_scope(scope):
    if scope == "pro":
        return PRO_ACCOUNTS
    if scope == "perso":
        return PERSO_ACCOUNTS
    return PRO_ACCOUNTS + PERSO_ACCOUNTS


def audit(_args):
    script = r'''
tell application "Mail"
  set out to ""
  repeat with a in every account
    set out to out & "ACCOUNT: " & (name of a) & " | " & ((email addresses of a) as string) & linefeed
    try
      set out to out & "  MAILBOXES: " & ((name of every mailbox of a) as string) & linefeed
    end try
  end repeat
  set out to out & "RULES:" & linefeed
  repeat with r in every rule
    set out to out & "  " & (name of r) & linefeed
  end repeat
  return out
end tell
'''
    print(osa(script))


def ensure_sender_rule(args):
    rows = rows_for_scope(args.scope)
    subject_clause = ""
    subject_condition = ""
    if args.subject:
        subject_clause = f'\n      make new rule condition at end of rule conditions of r with properties {{rule type:subject header, qualifier:does contain value, expression:"{args.subject}"}}'
        subject_condition = f" - {args.subject}"
    stop = "true" if args.stop else "false"
    flag_props = ", mark flagged:true, mark flag index:0" if args.flag else ""
    script_rows = ", ".join('{"%s", "%s"}' % row for row in rows)
    script = f'''
on ensureRule(ruleName, accountName, recipientAddress, senderText, destBox)
  tell application "Mail"
    if not (exists rule ruleName) then
      set dest to mailbox destBox of account accountName
      set r to make new rule with properties {{name:ruleName, enabled:true, all conditions must be met:true, should move message:true, move message:dest{flag_props}, stop evaluating rules:{stop}}}
      make new rule condition at end of rule conditions of r with properties {{rule type:to or cc header, qualifier:does contain value, expression:recipientAddress}}
      make new rule condition at end of rule conditions of r with properties {{rule type:from header, qualifier:does contain value, expression:senderText}}{subject_clause}
    end if
  end tell
end ensureRule

set rows to {{{script_rows}}}
repeat with rowData in rows
  set accountName to item 1 of rowData
  set recipientAddress to item 2 of rowData
  ensureRule("AUTO {args.name} - " & accountName & "{subject_condition}", accountName as string, recipientAddress as string, "{args.sender}", "{args.destination}")
end repeat
'''
    print(osa(script))
    if args.apply:
        apply_sender(args)


def apply_sender(args):
    rows = rows_for_scope(args.scope)
    account_names = [row[0] for row in rows]
    subjects = [args.subject] if args.subject else []
    script = f'''
on isSkipped(boxName)
  set skipNames to {as_list_literal(sorted(SKIP_MAILBOXES))}
  repeat with t in skipNames
    if boxName is (t as string) then return true
  end repeat
  return false
end isSkipped

on moveMatches(accountName, senderNeedle, subjectNeedles, destBox)
  set movedCount to 0
  tell application "Mail"
    set acc to account accountName
    if not (exists mailbox destBox of acc) then return 0
    set dest to mailbox destBox of acc
    repeat with mb in mailboxes of acc
      try
        set mbName to name of mb as string
        if my isSkipped(mbName) is false then
          repeat with m in messages of mb
            try
              set subj to subject of m as string
              set snd to sender of m as string
              set subjectOK to true
              if (count of subjectNeedles) > 0 then
                set subjectOK to false
                repeat with needle in subjectNeedles
                  if subj contains (needle as string) then set subjectOK to true
                end repeat
              end if
              if snd contains senderNeedle and subjectOK then
                set mailbox of m to dest
                set movedCount to movedCount + 1
              end if
            end try
          end repeat
        end if
      end try
    end repeat
  end tell
  return movedCount
end moveMatches

set totalMoved to 0
repeat with a in {as_list_literal(account_names)}
  set totalMoved to totalMoved + moveMatches(a as string, "{args.sender}", {as_list_literal(subjects)}, "{args.destination}")
end repeat
return totalMoved
'''
    print(osa(script))


def apply_known(args):
    if args.pattern == "qonto-transfers":
        subjects = ["You received a transfer", "Your transfer has been executed successfully"]
        total = 0
        for subject in subjects:
            ns = argparse.Namespace(
                scope="pro",
                sender="support@qonto.com",
                subject=subject,
                destination="02_PRO_FACTURES",
            )
            out = osa_apply_count(ns)
            total += int(out or "0")
        print(total)
        return
    if args.pattern == "bounce-undelivered":
        ns = argparse.Namespace(
            scope="pro",
            sender=None,
            subject="Undelivered Mail Returned to Sender",
            destination="00_PRO_A_TRAITER",
            flag=True,
        )
        print(apply_subject_count(ns))
        return
    raise SystemExit(f"Unknown pattern: {args.pattern}")


def osa_apply_count(args):
    rows = rows_for_scope(args.scope)
    account_names = [row[0] for row in rows]
    script = f'''
on isSkipped(boxName)
  set skipNames to {as_list_literal(sorted(SKIP_MAILBOXES))}
  repeat with t in skipNames
    if boxName is (t as string) then return true
  end repeat
  return false
end isSkipped

on moveMatches(accountName)
  set movedCount to 0
  tell application "Mail"
    set acc to account accountName
    if not (exists mailbox "{args.destination}" of acc) then return 0
    set dest to mailbox "{args.destination}" of acc
    repeat with mb in mailboxes of acc
      try
        if my isSkipped(name of mb as string) is false then
          repeat with m in messages of mb
            try
              if (sender of m as string) contains "{args.sender}" and (subject of m as string) contains "{args.subject}" then
                set mailbox of m to dest
                set movedCount to movedCount + 1
              end if
            end try
          end repeat
        end if
      end try
    end repeat
  end tell
  return movedCount
end moveMatches
set totalMoved to 0
repeat with a in {as_list_literal(account_names)}
  set totalMoved to totalMoved + moveMatches(a as string)
end repeat
return totalMoved
'''
    return osa(script)


def apply_subject_count(args):
    account_names = [row[0] for row in rows_for_scope(args.scope)]
    flag_lines = "set flagged status of m to true\n                set flag index of m to 0" if getattr(args, "flag", False) else ""
    script = f'''
on isSkipped(boxName)
  set skipNames to {as_list_literal(sorted(SKIP_MAILBOXES))}
  repeat with t in skipNames
    if boxName is (t as string) then return true
  end repeat
  return false
end isSkipped

on moveMatches(accountName)
  set movedCount to 0
  tell application "Mail"
    set acc to account accountName
    if not (exists mailbox "{args.destination}" of acc) then return 0
    set dest to mailbox "{args.destination}" of acc
    repeat with mb in mailboxes of acc
      try
        if my isSkipped(name of mb as string) is false then
          repeat with m in messages of mb
            try
              if (subject of m as string) contains "{args.subject}" then
                {flag_lines}
                set mailbox of m to dest
                set movedCount to movedCount + 1
              end if
            end try
          end repeat
        end if
      end try
    end repeat
  end tell
  return movedCount
end moveMatches
set totalMoved to 0
repeat with a in {as_list_literal(account_names)}
  set totalMoved to totalMoved + moveMatches(a as string)
end repeat
return totalMoved
'''
    return osa(script)


def ensure_default_rules(_args):
    patterns = [
        argparse.Namespace(name="PRO bounce undelivered", scope="pro", sender="MAILER-DAEMON", subject="Undelivered Mail Returned to Sender", destination="00_PRO_A_TRAITER", apply=False, stop=False, flag=True),
        argparse.Namespace(name="PRO factures Qonto transfer", scope="pro", sender="support@qonto.com", subject="You received a transfer", destination="02_PRO_FACTURES", apply=False, stop=False, flag=False),
        argparse.Namespace(name="PRO factures Qonto transfer", scope="pro", sender="support@qonto.com", subject="Your transfer has been executed successfully", destination="02_PRO_FACTURES", apply=False, stop=False, flag=False),
        argparse.Namespace(name="PRO factures Stripe exact", scope="pro", sender="invoice+statements+acct_1CTbIsBmBV2o9vP5@stripe.com", subject=None, destination="02_PRO_FACTURES", apply=False, stop=False, flag=False),
    ]
    for pattern in patterns:
        ensure_sender_rule(pattern)


def main():
    parser = argparse.ArgumentParser(
        description="Manage Apple Mail rules and learned classification patterns.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """\
            Safety: this script creates rules and moves messages. It never deletes mail.
            Retroactive apply skips Trash/Corbeille/Junk/Spam.
            """
        ),
    )
    sub = parser.add_subparsers(required=True)

    p = sub.add_parser("audit")
    p.set_defaults(func=audit)

    p = sub.add_parser("ensure-default-rules")
    p.set_defaults(func=ensure_default_rules)

    p = sub.add_parser("apply-known")
    p.add_argument("--pattern", required=True, choices=["qonto-transfers", "bounce-undelivered"])
    p.set_defaults(func=apply_known)

    p = sub.add_parser("add-sender-rule")
    p.add_argument("--name", required=True)
    p.add_argument("--sender", required=True)
    p.add_argument("--subject")
    p.add_argument("--destination", required=True)
    p.add_argument("--scope", choices=["pro", "perso", "all"], default="pro")
    p.add_argument("--apply", action="store_true")
    p.add_argument("--flag", action="store_true")
    p.add_argument("--stop", action="store_true")
    p.set_defaults(func=ensure_sender_rule)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
