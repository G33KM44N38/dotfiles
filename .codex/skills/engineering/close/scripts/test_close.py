"""Integration checks using real Git repositories and real macOS Trash."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("close_skill", Path(__file__).with_name("close.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CloseTests(unittest.TestCase):
    def setUp(self):
        self.original = Path.cwd()
        self.base = Path(tempfile.mkdtemp(prefix="codex-close-test-")).resolve()
        self.repo = self.base / "repo"
        self.work = self.base / "feature"
        self.git(self.base, "init", "-b", "main", str(self.repo))
        self.git(self.repo, "config", "user.name", "Close test")
        self.git(self.repo, "config", "user.email", "close@example.invalid")
        (self.repo / "package.json").write_text('{"name":"close-fixture"}\n')
        (self.repo / ".gitignore").write_text("build/\nnode_modules/\n.env\n")
        self.git(self.repo, "add", ".")
        self.git(self.repo, "commit", "-m", "fixture")
        self.git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        self.git(self.repo, "worktree", "add", "-b", "feature", str(self.work))
        (self.work / "build").mkdir()
        (self.work / "build/output.bin").write_bytes(b"disposable" * 100)
        (self.work / ".env").write_text("FIXTURE_ONLY=true\n")

    def tearDown(self):
        os.chdir(self.original)
        subprocess.run(["/usr/bin/trash", "-s", str(self.base)], check=True)

    def git(self, cwd, *args):
        return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True).stdout

    def reject(self, text):
        with self.assertRaisesRegex(module.Blocked, text):
            module.close(self.work, apply=True)
        self.assertTrue((self.work / "build/output.bin").exists())

    def test_preview_and_success_preserve_branch_and_unknown_ignored_files(self):
        preview = module.close(self.work)
        self.assertEqual(preview["delete_disposable"], ["build"])
        self.assertTrue((self.work / "build/output.bin").exists())
        self.assertFalse((self.repo / ".git/worktrees/feature/close.lock").exists())
        result = module.close(self.work, apply=True)
        self.assertEqual(result["status"], "closed")
        self.assertFalse(self.work.exists())
        self.git(self.repo, "show-ref", "--verify", "refs/heads/feature")
        self.assertNotIn(str(self.work).encode(), self.git(self.repo, "worktree", "list", "--porcelain"))
        # Find the trashed checkout by its unique administrative pointer.
        pointer = str(self.repo / ".git/worktrees/feature")
        matches = [p for p in (Path.home() / ".Trash").iterdir()
                   if p.is_dir() and (p / ".git").is_file()
                   and pointer in (p / ".git").read_text()]
        self.assertEqual(len(matches), 1)
        self.assertEqual((matches[0] / ".env").read_text(), "FIXTURE_ONLY=true\n")
        self.assertFalse((matches[0] / "build").exists())

    def test_dirty_tracked_file(self):
        (self.work / "package.json").write_text("modified\n")
        self.reject("Uncommitted")

    def test_untracked_file(self):
        (self.work / "notes.txt").write_text("keep\n")
        self.reject("Uncommitted")

    def test_unpublished_commit(self):
        self.git(self.work, "commit", "--allow-empty", "-m", "unpublished")
        self.reject("HEAD is not contained")

    def test_locked_worktree(self):
        self.git(self.repo, "worktree", "lock", str(self.work))
        self.reject("locked")

    def test_primary_checkout(self):
        with self.assertRaisesRegex(module.Blocked, "primary checkouts"):
            module.close(self.repo, apply=True)

    def test_linked_main_is_protected(self):
        self.git(self.repo, "branch", "-m", "main", "original")
        self.git(self.work, "branch", "-m", "main")
        self.reject("Protected branch")

    def test_external_symlink_is_not_followed(self):
        external = self.base / "external"
        external.mkdir()
        (external / "keep.txt").write_text("keep")
        (self.repo / ".git/info/exclude").write_text("node_modules\n")
        (self.work / "node_modules").symlink_to(external, target_is_directory=True)
        preview = module.close(self.work)
        self.assertIn("node_modules", preview["preserve_in_trash"])
        module.close(self.work, apply=True)
        self.assertEqual((external / "keep.txt").read_text(), "keep")

    def test_tracked_build_content_is_not_deleted(self):
        self.git(self.work, "add", "-f", "build/output.bin")
        self.git(self.work, "commit", "-m", "tracked output")
        self.git(self.repo, "update-ref", "refs/remotes/origin/feature", "refs/heads/feature")
        preview = module.close(self.work)
        self.assertNotIn("build", preview["delete_disposable"])
        self.assertIn("build", preview["preserve_in_trash"])

    def test_nested_git_in_build_blocks_deletion(self):
        self.git(self.work / "build", "init")
        self.reject("Nested repository")

    def test_running_process_blocks_cleanup(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], cwd=self.work)
        try:
            self.reject("Processes still")
        finally:
            child.terminate()
            child.wait(timeout=5)

    def test_bare_repository_feature_worktree(self):
        bare = self.base / "bare.git"
        self.git(self.base, "clone", "--bare", str(self.repo), str(bare))
        self.git(bare, "update-ref", "refs/remotes/origin/main", "refs/heads/main")
        work = bare / "task"
        self.git(bare, "worktree", "add", "-b", "task", str(work), "main")
        result = module.close(work, apply=True)
        self.assertEqual(result["status"], "closed")
        self.assertTrue((bare / "HEAD").exists())
        self.git(bare, "show-ref", "--verify", "refs/heads/task")

    def test_detached_published_head(self):
        self.git(self.work, "switch", "--detach")
        result = module.close(self.work, apply=True)
        self.assertEqual(result["status"], "closed")


if __name__ == "__main__":
    unittest.main(verbosity=2)
