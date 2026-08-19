#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


MAC_EPOCH_OFFSET = 978_307_200
DEFAULT_DB = Path("~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite").expanduser()
DEFAULT_MEDIA_ROOT = Path("~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message").expanduser()
DEFAULT_MODEL = Path("~/.cache/whisper.cpp/ggml-tiny.bin").expanduser()
DEFAULT_WORKDIR = Path("/tmp/read-whatsapp")
MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"


@dataclass(frozen=True)
class Message:
    pk: int
    chat: str
    from_me: bool
    msg_type: int
    timestamp: str
    text: str
    media_path: str
    duration: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read local WhatsApp chats and optionally transcribe voice notes.")
    parser.add_argument("--chat", help="Chat/contact search term, e.g. beautyhairmaiidi")
    parser.add_argument("--search", help="Message text search term")
    parser.add_argument("--since", help="Local date lower bound, e.g. 2026-06-06 or 2026-06-06 10:00:00")
    parser.add_argument("--limit", type=int, default=60)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--media-root", type=Path, default=DEFAULT_MEDIA_ROOT)
    parser.add_argument("--transcribe", action="store_true")
    parser.add_argument("--language", default="fr")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--download-model", action="store_true")
    parser.add_argument("--workdir", type=Path, default=DEFAULT_WORKDIR)
    parser.add_argument(
        "--sync",
        action="store_true",
        help="Open WhatsApp and wait for the local database to refresh before reading",
    )
    parser.add_argument(
        "--sync-timeout",
        type=int,
        default=30,
        help="Maximum seconds to wait for a database refresh (default: 30)",
    )
    return parser.parse_args()


def require_file(path: Path, label: str) -> None:
    if not path.exists():
        raise SystemExit(f"{label} not found: {path}")


def require_bin(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"Missing binary: {name}")


def database_fingerprint(path: Path) -> tuple[tuple[int, int], ...]:
    paths = (path, Path(f"{path}-wal"), Path(f"{path}-shm"))
    fingerprint: list[tuple[int, int]] = []
    for candidate in paths:
        try:
            stat = candidate.stat()
            fingerprint.append((stat.st_mtime_ns, stat.st_size))
        except FileNotFoundError:
            fingerprint.append((0, 0))
    return tuple(fingerprint)


def sync_whatsapp(db_path: Path, timeout: int) -> None:
    if sys.platform != "darwin":
        raise SystemExit("--sync is only supported on macOS")
    require_bin("open")
    require_file(db_path, "WhatsApp DB")

    before = database_fingerprint(db_path)
    subprocess.run(
        ["open", "-a", "WhatsApp"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    deadline = time.monotonic() + max(timeout, 1)
    changed = False
    last = before
    stable_since: float | None = None

    while time.monotonic() < deadline:
        time.sleep(1)
        current = database_fingerprint(db_path)
        if current != before:
            changed = True
        if changed and current == last:
            stable_since = stable_since or time.monotonic()
            if time.monotonic() - stable_since >= 2:
                break
        else:
            stable_since = None
        last = current

    status = "changed_and_settled" if changed else "unchanged_after_wait"
    print(
        f"WHATSAPP_SYNC status={status} waited_up_to={max(timeout, 1)}s "
        f"db_mtime={time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(db_path.stat().st_mtime))}",
        file=sys.stderr,
    )


def download_model(model_path: Path) -> None:
    if model_path.exists():
        return
    require_bin("curl")
    model_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["curl", "-L", "--fail", "-o", str(model_path), MODEL_URL],
        check=True,
    )


def normalize_since(value: str | None) -> str | None:
    if value is None:
        return None
    if len(value) == 10:
        return f"{value} 00:00:00"
    return value


def query_messages(args: argparse.Namespace) -> list[Message]:
    require_file(args.db.expanduser(), "WhatsApp DB")
    clauses: list[str] = []
    params: list[object] = []

    if args.chat:
        clauses.append(
            "lower(coalesce(c.ZPARTNERNAME,'') || ' ' || coalesce(c.ZCONTACTJID,'') || ' ' || coalesce(c.ZLASTMESSAGETEXT,'')) LIKE ?"
        )
        params.append(f"%{args.chat.lower()}%")

    if args.search:
        clauses.append("lower(coalesce(m.ZTEXT,'')) LIKE ?")
        params.append(f"%{args.search.lower()}%")

    since = normalize_since(args.since)
    if since:
        clauses.append("m.ZMESSAGEDATE >= strftime('%s', ?, 'localtime') - ?")
        params.extend([since, MAC_EPOCH_OFFSET])

    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    params.append(args.limit)

    sql = f"""
        SELECT
            m.Z_PK,
            coalesce(c.ZPARTNERNAME, c.ZCONTACTJID, '') AS chat,
            m.ZISFROMME,
            m.ZMESSAGETYPE,
            datetime(m.ZMESSAGEDATE + {MAC_EPOCH_OFFSET}, 'unixepoch', 'localtime') AS msg_date,
            coalesce(m.ZTEXT, '') AS text,
            coalesce(mi.ZMEDIALOCALPATH, '') AS media_path,
            coalesce(mi.ZMOVIEDURATION, 0) AS duration
        FROM ZWAMESSAGE m
        LEFT JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
        LEFT JOIN ZWAMEDIAITEM mi ON mi.Z_PK = m.ZMEDIAITEM
        {where}
        ORDER BY m.ZMESSAGEDATE DESC
        LIMIT ?
    """

    with sqlite3.connect(args.db.expanduser()) as conn:
        rows = conn.execute(sql, params).fetchall()

    return [
        Message(
            pk=int(row[0]),
            chat=str(row[1]),
            from_me=bool(row[2]),
            msg_type=int(row[3]),
            timestamp=str(row[4]),
            text=str(row[5]),
            media_path=str(row[6]),
            duration=int(row[7]),
        )
        for row in rows
    ]


def resolve_media(media_root: Path, media_path: str) -> Path | None:
    if not media_path:
        return None
    path = Path(media_path)
    if path.is_absolute():
        return path
    return media_root.expanduser() / path


def transcribe_audio(source: Path, args: argparse.Namespace) -> str:
    require_bin("ffmpeg")
    require_bin("whisper-cli")
    if args.download_model:
        download_model(args.model.expanduser())
    require_file(args.model.expanduser(), "Whisper model")

    args.workdir.mkdir(parents=True, exist_ok=True)
    stem = source.stem
    wav_path = args.workdir / f"{stem}.wav"
    out_base = args.workdir / stem
    txt_path = args.workdir / f"{stem}.txt"

    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(source), "-ar", "16000", "-ac", "1", str(wav_path)],
        check=True,
    )
    subprocess.run(
        ["whisper-cli", "-m", str(args.model.expanduser()), "-f", str(wav_path), "-l", args.language, "-otxt", "-of", str(out_base)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return txt_path.read_text(encoding="utf-8").strip()


def print_message(message: Message, args: argparse.Namespace) -> None:
    direction = "me" if message.from_me else "them"
    print(f"[{message.timestamp}] {message.chat} {direction} type={message.msg_type} id={message.pk}")
    if message.text:
        print(message.text)

    media = resolve_media(args.media_root, message.media_path)
    if media:
        exists = "exists" if media.exists() else "missing"
        print(f"media: {media} ({exists}, duration={message.duration}s)")
        if args.transcribe and media.exists() and media.suffix.lower() in {".opus", ".ogg", ".m4a", ".mp3", ".wav", ".aac"}:
            transcript = transcribe_audio(media, args)
            print("transcript:")
            print(transcript if transcript else "[empty transcript]")
    print()


def main() -> int:
    args = parse_args()
    if args.sync:
        sync_whatsapp(args.db.expanduser(), args.sync_timeout)
    messages = query_messages(args)
    if not messages:
        print("No WhatsApp messages found.")
        return 0

    for message in messages:
        print_message(message, args)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(f"Command failed: {' '.join(str(part) for part in exc.cmd)}", file=sys.stderr)
        raise SystemExit(exc.returncode)
