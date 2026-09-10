#!/usr/bin/env python3
"""Audited, bounded cleanup: disposable artifacts only; checkout goes to Trash.

Never run repository code. Never force Git, delete branches, or prune other worktrees.
The dry run is read-only. Only an explicit --apply mutates anything.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


class Blocked(Exception):
    pass


def run(argv, cwd=None, allowed=(0,)):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=30)
    if result.returncode not in allowed:
        raise Blocked(result.stderr.decode(errors="replace").strip() or f"Command failed: {argv[0]}")
    return result


def git(cwd, *args):
    return run(["git", "--no-optional-locks", "-C", str(cwd), *args]).stdout


def records(common):
    rows = []
    for record in git(common, "worktree", "list", "--porcelain", "-z").split(b"\0\0"):
        row = {}
        for line in record.split(b"\0"):
            if line:
                key, _, value = line.partition(b" ")
                row[key.decode()] = os.fsdecode(value)
        if row:
            rows.append(row)
    return rows


def context(start):
    for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE"):
        if os.environ.get(name):
            raise Blocked(f"Unset {name} before closing a worktree.")
    root = Path(os.fsdecode(git(start, "rev-parse", "--show-toplevel")).strip()).resolve()
    common = Path(os.fsdecode(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir")).strip()).resolve()
    admin = Path(os.fsdecode(git(root, "rev-parse", "--absolute-git-dir")).strip()).resolve()
    if not (root / ".git").is_file() or admin.parent != common / "worktrees":
        raise Blocked("Only a linked worktree can be closed; primary checkouts are protected.")
    if common == root or common.is_relative_to(root):
        raise Blocked("The shared Git repository is inside the target.")
    rows = records(common)
    row = next((r for r in rows if Path(r["worktree"]).resolve() == root), None)
    if not row or "locked" in row or "prunable" in row:
        raise Blocked("Worktree is missing, locked, or has inconsistent registration.")
    if any(Path(r["worktree"]).resolve().is_relative_to(root) and Path(r["worktree"]).resolve() != root for r in rows):
        raise Blocked("Another registered worktree is nested inside this one.")
    branch = row.get("branch", "detached").removeprefix("refs/heads/")
    defaults = git(common, "for-each-ref", "--format=%(symref)", "refs/remotes").decode().splitlines()
    protected = {"main", "master", "develop", "development", "staging", "production", "prod"}
    protected.update(ref.split("/", 3)[-1] for ref in defaults if ref.startswith("refs/remotes/"))
    if branch in protected:
        raise Blocked(f"Protected branch: {branch}.")
    if git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--ignore-submodules=none"):
        raise Blocked("Uncommitted or untracked files exist. Save them before closing.")
    head = git(root, "rev-parse", "HEAD").decode().strip()
    if not git(common, "for-each-ref", f"--contains={head}", "--format=%(refname)", "refs/remotes").strip():
        raise Blocked("HEAD is not contained in any locally known remote branch. Publish/save the commits first; close does not fetch or push.")
    tracked = git(root, "ls-files", "--stage", "-z").split(b"\0")
    if any(entry.startswith(b"160000 ") for entry in tracked):
        raise Blocked("Submodules require separate handling; no cleanup performed.")
    return root, common, admin, branch, head


def active_processes(root):
    # Ignore this invocation and its ancestor shells/Codex, never unrelated agents.
    ps = run(["ps", "-axo", "pid=,ppid="]).stdout.decode()
    parents = dict(tuple(map(int, line.split())) for line in ps.splitlines() if line.strip())
    ancestors = set()
    pid = os.getpid()
    while pid and pid not in ancestors:
        ancestors.add(pid)
        pid = parents.get(pid, 0)
    result = run(["lsof", "-n", "-P", "-a", "-d", "cwd", "-Fpn"], allowed=(0, 1))
    if result.returncode and (result.stderr or not result.stdout):
        raise Blocked("Cannot inspect running processes with lsof.")
    active = []
    pid = None
    for line in os.fsdecode(result.stdout).splitlines():
        if line.startswith("p"):
            pid = int(line[1:])
        elif line.startswith("n") and pid not in ancestors:
            path = Path(line[1:])
            if path.is_absolute() and path.is_relative_to(root):
                active.append(pid)
    if active:
        raise Blocked("Processes still have a working directory in this worktree: " + ", ".join(map(str, sorted(set(active)))))


def artifacts(root):
    """Allowlist at recognized project roots; nothing outside this checkout."""
    found, skipped = [], []
    prune = {".git", "node_modules", "build", "dist", "target", "Pods", ".next", ".turbo", "coverage", ".expo", ".gradle"}
    for parent, dirs, files in os.walk(root, followlinks=False):
        p = Path(parent)
        if p != root and ".git" in files + dirs:
            raise Blocked(f"Nested Git repository: {p.relative_to(root)}.")
        names = set()
        if "package.json" in files:
            names.update({"node_modules", "build", "dist", ".next", ".turbo", "coverage"})
        if "Cargo.toml" in files:
            names.add("target")
        if "Podfile" in files:
            names.update({"Pods", "build"})
        if "build.gradle" in files or "build.gradle.kts" in files:
            names.update({"build", ".gradle"})
        for name in sorted(names):
            candidate = p / name
            if not os.path.lexists(candidate):
                continue
            rel = str(candidate.relative_to(root))
            if candidate.is_symlink() or not candidate.is_dir():
                skipped.append(rel)
                continue
            ignored = run(["git", "-C", str(root), "check-ignore", "-q", "--", rel], allowed=(0, 1))
            tracked = git(root, "ls-files", "-z", "--", f":(literal){rel}")
            if ignored.returncode or tracked:
                skipped.append(rel)
                continue
            # A separate mount or nested repo is never a disposable artifact.
            for child, child_dirs, child_files in os.walk(candidate, followlinks=False):
                if ".git" in child_dirs + child_files or Path(child).stat().st_dev != root.stat().st_dev:
                    raise Blocked(f"Nested repository or filesystem in {rel}.")
            found.append(candidate)
        dirs[:] = [d for d in dirs if d not in prune and not (p / d).is_symlink()]
    return found, skipped


def close(start, apply=False):
    if sys.platform != "darwin" or not Path("/usr/bin/trash").exists():
        raise Blocked("This close script currently supports macOS with /usr/bin/trash only.")
    if not shutil.rmtree.avoids_symlink_attacks:
        raise Blocked("Python lacks the safe directory-removal implementation.")
    root, common, admin, branch, head = context(start)
    active_processes(root)
    targets, skipped = artifacts(root)
    report = {"status": "preview", "worktree": str(root), "branch_preserved": None if branch == "detached" else branch,
              "delete_disposable": [str(p.relative_to(root)) for p in targets],
              "preserve_in_trash": skipped, "repository": str(common)}
    if not apply:
        return report
    # Serialize close invocations; the Git administrative directory survives until unregister.
    with (admin / "close.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Blocked("Another close invocation is running.")
        if context(root) != (root, common, admin, branch, head):
            raise Blocked("Worktree changed during validation.")
        active_processes(root)
        # Only validated, ignored, untracked artifact directories are permanently removed.
        for target in targets:
            if target.is_symlink() or target.resolve() != target or not target.is_relative_to(root):
                raise Blocked(f"Artifact path changed: {target}.")
            shutil.rmtree(target)
        context(root)  # Recheck user files and HEAD after potentially slow cleanup.
        os.chdir(common)
        run(["/usr/bin/trash", "-s", str(root)], cwd=common)
        if root.exists():
            raise Blocked("Trash did not remove the checkout; Git registration was preserved.")
        # With the checkout absent, Git removes only this worktree's registration.
        git(common, "worktree", "remove", "--", str(root))
        if any(Path(r["worktree"]).resolve() == root for r in records(common)):
            raise Blocked("Checkout is in Trash but Git still reports its registration.")
    report["status"] = "closed"
    report["checkout"] = "Moved to macOS Trash; branch and global caches preserved."
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--apply", action="store_true")
    group.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(close(Path.cwd(), args.apply), ensure_ascii=False, indent=2))
        return 0
    except (Blocked, OSError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"status": "blocked", "reason": str(error)}, ensure_ascii=False))
        return 2


if __name__ == "__main__":
    sys.exit(main())
