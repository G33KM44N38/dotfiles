#!/usr/bin/env python3
import argparse
import os
import sqlite3
import subprocess
import sys
import time
import urllib.parse


DB_PATH = os.path.expanduser(
    "~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"
)


def find_jules_phone(chat_name: str) -> str:
    if not os.path.exists(DB_PATH):
        raise SystemExit("WhatsApp ChatStorage.sqlite not found")

    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        """
        select ZCONTACTJID, ZPARTNERNAME, ZLASTMESSAGEDATE
        from ZWACHATSESSION
        where ZPARTNERNAME = ?
          and ZCONTACTJID like '%@s.whatsapp.net'
        order by ZLASTMESSAGEDATE desc
        """,
        (chat_name,),
    ).fetchall()

    if not rows:
        raise SystemExit(f"No exact WhatsApp chat found for {chat_name!r}")

    if len(rows) > 1:
        first = rows[0]["ZCONTACTJID"]
        if any(row["ZCONTACTJID"] != first for row in rows[1:]):
            raise SystemExit(f"Multiple WhatsApp chats found for {chat_name!r}")

    jid = rows[0]["ZCONTACTJID"]
    phone = jid.split("@", 1)[0]
    if not phone.isdigit():
        raise SystemExit("Resolved WhatsApp JID is not phone based")

    return phone


def open_whatsapp(phone: str, message: str) -> None:
    url = "whatsapp://send?" + urllib.parse.urlencode(
        {
            "phone": phone,
            "text": message,
        }
    )
    subprocess.run(["open", url], check=True)


def send_return(delay: float) -> None:
    time.sleep(delay)
    script = """
    tell application "WhatsApp" to activate
    delay 0.5
    tell application "System Events"
        key code 36
    end tell
    """
    subprocess.run(["osascript", "-e", script], check=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Open Jules's WhatsApp chat with a message, optionally send it."
    )
    parser.add_argument("--message", help="Message to send. Reads stdin if omitted.")
    parser.add_argument("--chat-name", default="Jules")
    parser.add_argument("--draft-only", action="store_true")
    parser.add_argument("--send", action="store_true")
    parser.add_argument("--resolve-only", action="store_true")
    parser.add_argument("--send-delay", type=float, default=2.0)
    args = parser.parse_args()

    selected_modes = sum(
        bool(mode) for mode in [args.draft_only, args.send, args.resolve_only]
    )
    if selected_modes > 1:
        raise SystemExit("Use only one mode: --draft-only, --send, or --resolve-only")

    message = args.message if args.message is not None else sys.stdin.read()
    message = message.strip()
    if not message:
        raise SystemExit("Message is required")

    phone = find_jules_phone(args.chat_name)
    if args.resolve_only:
        print("resolved")
        return 0

    open_whatsapp(phone, message)

    if args.send:
        send_return(args.send_delay)
        print("sent")
    else:
        print("draft-opened")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
