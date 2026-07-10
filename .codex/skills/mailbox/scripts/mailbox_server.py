#!/usr/bin/env python3
"""Local-only email triage UI and task queue server (stdlib only)."""

from __future__ import annotations

import json
import os
import hashlib
import subprocess
import threading
import uuid
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


SKILL_ROOT = Path(__file__).resolve().parent.parent
DATA = Path(
    os.environ.get(
        "MAILBOX_DATA_DIR",
        Path("/tmp") / f"codex-mailbox-{os.getuid()}",
    )
).expanduser()
STATIC = SKILL_ROOT / "assets" / "mailroom"
EMAILS = DATA / "emails.json"
TASKS = DATA / "tasks.json"
LEGACY_TASKS = Path(
    os.environ.get(
        "MAILBOX_LEGACY_TASKS",
        Path.home() / "coding" / "perso" / "mail-triage" / "data" / "tasks.json",
    )
).expanduser()
LOCK = threading.RLock()

MAIL_SCRIPT = r'''
set output to ""
tell application "Mail"
  repeat with a in every account
    try
      set inboxBox to mailbox "INBOX" of a
      set unreadMessages to (messages of inboxBox whose read status is false)
      repeat with m in unreadMessages
        try
          set output to output & (name of a) & tab & (date received of m as string) & tab & sender of m & tab & subject of m & linefeed
        end try
      end repeat
    end try
  end repeat
end tell
return output
'''


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path) -> list[dict]:
    with LOCK:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return []
        return value if isinstance(value, list) else []


def write_json(path: Path, value: list[dict]) -> None:
    with LOCK:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(value, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        os.replace(temporary, path)


def refresh_unread_emails() -> None:
    """Snapshot unread inbox metadata from Apple Mail; retain old data on failure."""
    try:
        result = subprocess.run(
            ["osascript", "-e", MAIL_SCRIPT], capture_output=True, text=True,
            timeout=30, check=True,
        )
        emails = []
        for line in result.stdout.splitlines():
            parts = line.split("\t", 3)
            if len(parts) != 4:
                continue
            account, date, sender, subject = parts
            identity = hashlib.sha1(line.encode("utf-8")).hexdigest()[:14]
            lowered = subject.lower()
            important = any(word in lowered for word in (
                "action required", "alerte de sécurité", "security alert",
                "unrecognized", "unsuccessful", "impayé", "api key",
                "transfer pause", "mfa",
            ))
            emails.append({"id": identity, "account": account, "sender": sender,
                           "subject": subject, "date": date, "unread": True,
                           "priority": "IMPORTANT" if important else "UNREAD"})
        if emails:
            write_json(EMAILS, emails)
    except (OSError, subprocess.SubprocessError):
        pass


class Handler(SimpleHTTPRequestHandler):
    server_version = "MailTriage/1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        print(f"[{self.log_date_time_string()}] {fmt % args}")

    def send_json(self, value, status: HTTPStatus = HTTPStatus.OK) -> None:
        payload = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def read_body(self) -> dict | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 64 * 1024:
                return None
            value = json.loads(self.rfile.read(length) or b"{}")
            return value if isinstance(value, dict) else None
        except (ValueError, json.JSONDecodeError):
            return None

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/emails":
            self.send_json(read_json(EMAILS))
            return
        if path == "/api/tasks":
            self.send_json(read_json(TASKS))
            return
        if path.startswith("/api/"):
            self.send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)
            return
        if path == "/":
            self.path = "/index.html"
        super().do_GET()

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/tasks":
            self.send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)
            return
        body = self.read_body()
        if body is None:
            self.send_json({"error": "Invalid JSON body"}, HTTPStatus.BAD_REQUEST)
            return
        email_id = str(body.get("email_id", "")).strip()
        instruction = str(body.get("instruction", "")).strip()
        if not email_id or not instruction:
            self.send_json(
                {"error": "email_id and instruction are required"},
                HTTPStatus.BAD_REQUEST,
            )
            return
        if not any(str(email.get("id")) == email_id for email in read_json(EMAILS)):
            self.send_json({"error": "Unknown email_id"}, HTTPStatus.BAD_REQUEST)
            return
        created = now()
        email = next(
            email for email in read_json(EMAILS)
            if str(email.get("id")) == email_id
        )
        task = {
            "id": str(uuid.uuid4()),
            "email_id": email_id,
            "subject": email.get("subject", "Email task"),
            "account": email.get("account", ""),
            "instruction": instruction,
            "status": "queued",
            "result": "",
            "created_at": created,
            "updated_at": created,
        }
        with LOCK:
            tasks = read_json(TASKS)
            tasks.append(task)
            write_json(TASKS, tasks)
        self.send_json(task, HTTPStatus.CREATED)

    def do_PATCH(self) -> None:
        parts = urlparse(self.path).path.strip("/").split("/")
        if len(parts) != 3 or parts[:2] != ["api", "tasks"]:
            self.send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)
            return
        body = self.read_body()
        if body is None:
            self.send_json({"error": "Invalid JSON body"}, HTTPStatus.BAD_REQUEST)
            return
        allowed_statuses = {"queued", "working", "done", "failed"}
        status = body.get("status")
        if status is not None and status not in allowed_statuses:
            self.send_json({"error": "Invalid status"}, HTTPStatus.BAD_REQUEST)
            return
        with LOCK:
            tasks = read_json(TASKS)
            task = next((item for item in tasks if item.get("id") == parts[2]), None)
            if task is None:
                self.send_json({"error": "Task not found"}, HTTPStatus.NOT_FOUND)
                return
            if status is not None:
                task["status"] = status
            if "result" in body:
                task["result"] = str(body["result"])
            task["updated_at"] = now()
            write_json(TASKS, tasks)
        self.send_json(task)


def main() -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    DATA.chmod(0o700)
    if not TASKS.exists() and LEGACY_TASKS.exists():
        write_json(TASKS, read_json(LEGACY_TASKS))
    if not EMAILS.exists():
        write_json(EMAILS, [])
    if not TASKS.exists():
        write_json(TASKS, [])
    refresh_unread_emails()
    host, port = "127.0.0.1", int(os.environ.get("PORT", "8765"))
    print(f"Mail triage running at http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == "__main__":
    main()
