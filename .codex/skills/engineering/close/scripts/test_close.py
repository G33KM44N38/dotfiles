"""Integration checks using real Git repositories and real macOS Trash."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from test_close_neovim import editor

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

    def remote_without_fetch_mapping(self):
        remote = self.base / "remote.git"
        self.git(self.base, "init", "--bare", "-b", "main", str(remote))
        self.git(self.repo, "remote", "add", "origin", str(remote))
        self.git(self.repo, "config", "--unset-all", "remote.origin.fetch")
        self.git(self.repo, "push", "origin", "main:refs/heads/main")
        return remote

    def publish_feature(self):
        self.git(self.work, "commit", "--allow-empty", "-m", "published")
        self.git(self.work, "push", "origin", "HEAD:refs/heads/ci/published")
        self.git(self.work, "config", "branch.feature.remote", "origin")
        self.git(self.work, "config", "branch.feature.merge", "refs/heads/ci/published")

    def divergent_tracking_ref(self, name):
        old = self.git(self.repo, "commit-tree", "main^{tree}", "-p", "main", "-m", "old tip").decode().strip()
        new = self.git(self.repo, "commit-tree", "main^{tree}", "-p", "main", "-m", "rewritten tip").decode().strip()
        self.git(self.repo, "update-ref", f"refs/remotes/origin/{name}", old)
        self.git(self.repo, "push", "origin", f"{new}:refs/heads/{name}")
        return old

    def test_unrelated_divergent_branch_does_not_block_close_or_get_updated(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        old = self.divergent_tracking_ref("fix/unrelated")
        self.assertEqual(module.close(self.work, apply=True)["status"], "closed")
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/remotes/origin/fix/unrelated").decode().strip(), old)

    def test_targeted_fetch_reports_reference_rejection_without_claiming_auth_failure(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        old = self.git(self.repo, "commit-tree", "main^{tree}", "-p", "main", "-m", "divergent cache").decode().strip()
        self.git(self.repo, "update-ref", "refs/remotes/origin/ci/published", old)
        with self.assertRaisesRegex(module.Blocked, "rejected.*refs/remotes/origin/ci/published") as failure:
            module.close(self.work, apply=True)
        self.assertNotIn("authentication", str(failure.exception).lower())
        self.assertTrue((self.work / "build/output.bin").exists())

    def test_targeted_fetch_accepts_an_upstream_that_has_advanced(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        newer = self.git(self.repo, "commit-tree", "feature^{tree}", "-p", "feature", "-m", "newer published work").decode().strip()
        self.git(self.repo, "push", "origin", f"{newer}:refs/heads/ci/published")
        module.context(self.work, refresh_remotes=True)
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/remotes/origin/ci/published").decode().strip(), newer)

    def test_symbolic_tracking_destination_does_not_change_local_branch(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        old_main = self.git(self.repo, "rev-parse", "main")
        self.git(self.repo, "symbolic-ref", "refs/remotes/origin/ci/published", "refs/heads/main")
        with self.assertRaisesRegex(module.Blocked, "symbolic"):
            module.context(self.work, refresh_remotes=True)
        self.assertEqual(self.git(self.repo, "rev-parse", "main"), old_main)

    def test_close_fetches_published_branch_without_mapping(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        config = (self.repo / ".git/config").read_bytes()
        self.assertEqual(module.close(self.work, apply=True)["status"], "closed")
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/remotes/origin/ci/published"),
                         self.git(self.repo, "rev-parse", "refs/heads/feature"))
        self.assertEqual((self.repo / ".git/config").read_bytes(), config)
        self.assertFalse((self.repo / ".git/FETCH_HEAD").exists())

    def test_fetch_finds_merge_after_remote_feature_branch_deleted(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        other = self.base / "other"
        self.git(self.base, "clone", str(self.base / "remote.git"), str(other))
        self.git(other, "config", "user.name", "Close test")
        self.git(other, "config", "user.email", "close@example.invalid")
        self.git(other, "merge", "--no-ff", "-m", "merge", "origin/ci/published")
        self.git(other, "push", "origin", "main:refs/heads/main", ":refs/heads/ci/published")
        merge = self.git(other, "rev-parse", "HEAD")
        self.assertNotEqual(self.git(self.repo, "rev-parse", "refs/remotes/origin/main"), merge)
        self.assertEqual(module.close(self.work, apply=True)["status"], "closed")
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/remotes/origin/main"), merge)

    def test_preview_does_not_fetch_missing_publication_proof(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        refs = self.git(self.repo, "show-ref")
        config = (self.repo / ".git/config").read_bytes()
        with self.assertRaisesRegex(module.Blocked, "--apply.*fetch"):
            module.close(self.work)
        self.assertEqual(self.git(self.repo, "show-ref"), refs)
        self.assertEqual((self.repo / ".git/config").read_bytes(), config)
        self.assertTrue((self.work / "build/output.bin").exists())
        self.assertFalse((self.repo / ".git/FETCH_HEAD").exists())

    def test_unpublished_commit_still_blocks_after_fetch(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        self.git(self.work, "commit", "--allow-empty", "-m", "not pushed")
        self.reject("HEAD is not contained")
        self.git(self.repo, "show-ref", "--verify", "refs/remotes/origin/ci/published")

    def test_unavailable_remote_blocks_without_exposing_its_url(self):
        self.remote_without_fetch_mapping()
        self.git(self.work, "commit", "--allow-empty", "-m", "unverified")
        self.git(self.repo, "remote", "set-url", "origin", str(self.base / "PRIVATE_URL_SENTINEL"))
        with self.assertRaisesRegex(module.Blocked, "ls-remote.*failed") as failure:
            module.close(self.work, apply=True)
        self.assertNotIn("PRIVATE_URL_SENTINEL", str(failure.exception))
        self.assertTrue((self.work / "build/output.bin").exists())

    def test_local_publication_proof_needs_no_available_remote(self):
        self.remote_without_fetch_mapping()
        self.git(self.repo, "remote", "set-url", "origin", str(self.base / "missing"))
        self.assertEqual(module.close(self.work, apply=True)["status"], "closed")

    def test_fetch_does_not_apply_configured_branch_or_tag_mappings_or_prune(self):
        remote = self.remote_without_fetch_mapping()
        self.publish_feature()
        self.git(remote, "tag", "remote-only", "main")
        old_main = self.git(self.repo, "rev-parse", "refs/heads/main")
        self.git(self.repo, "config", "remote.origin.fetch", "refs/heads/ci/published:refs/heads/main")
        self.git(self.repo, "config", "--add", "remote.origin.fetch", "refs/heads/ci/published:refs/tags/unwanted")
        self.git(self.repo, "config", "fetch.prune", "true")
        self.git(self.repo, "config", "fetch.pruneTags", "true")
        self.git(self.repo, "update-ref", "refs/remotes/origin/removed", "main")
        module.context(self.work, refresh_remotes=True)
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/heads/main"), old_main)
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/remotes/origin/removed"), old_main)
        self.assertEqual(self.git(self.repo, "tag", "--list"), b"")

    def test_bare_repository_fetches_without_mapping(self):
        remote = self.remote_without_fetch_mapping()
        self.publish_feature()
        bare = self.base / "bare.git"
        self.git(self.base, "clone", "--bare", str(remote), str(bare))
        work = bare / "task"
        self.git(bare, "worktree", "add", "-b", "task", str(work), "ci/published")
        config = (bare / "config").read_bytes()
        self.assertEqual(module.close(work, apply=True)["status"], "closed")
        self.assertEqual(self.git(bare, "rev-parse", "refs/remotes/origin/ci/published"),
                         self.git(bare, "rev-parse", "refs/heads/task"))
        self.assertEqual((bare / "config").read_bytes(), config)

    def test_fetch_does_not_run_repository_hooks(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        hook = self.repo / ".git/hooks/reference-transaction"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        # This hook would reject every fetched ref update if executed.
        module.context(self.work, refresh_remotes=True)
        self.git(self.repo, "show-ref", "--verify", "refs/remotes/origin/ci/published")

    def test_fetch_timeout_blocks_cleanup(self):
        self.remote_without_fetch_mapping()
        self.publish_feature()
        real_run = subprocess.run

        def timeout_fetch(argv, **kwargs):
            if "fetch" in argv:
                raise subprocess.TimeoutExpired(argv, 30, stderr=b"PRIVATE_URL_SENTINEL")
            return real_run(argv, **kwargs)

        with mock.patch.object(module.subprocess, "run", side_effect=timeout_fetch):
            with self.assertRaisesRegex(module.Blocked, "fetch.*timed out") as failure:
                module.close(self.work, apply=True)
        self.assertNotIn("PRIVATE_URL_SENTINEL", str(failure.exception))
        self.assertTrue((self.work / "build/output.bin").exists())

    def test_another_remote_can_prove_publication_after_origin_fails(self):
        remote = self.remote_without_fetch_mapping()
        self.publish_feature()
        self.git(self.repo, "remote", "add", "backup", str(remote))
        self.git(self.repo, "remote", "set-url", "origin", str(self.base / "missing"))
        module.context(self.work, refresh_remotes=True)
        self.assertEqual(self.git(self.repo, "rev-parse", "refs/remotes/backup/ci/published"),
                         self.git(self.work, "rev-parse", "HEAD"))

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

    def test_close_quits_clean_neovim_but_preview_does_not(self):
        with editor(self.work) as (process, address, pid):
            with self.assertRaisesRegex(module.Blocked, "Processes still"):
                module.close(self.work)
            self.assertIsNone(process.poll())
            result = module.close(self.work, apply=True)
            self.assertEqual(result["status"], "closed")
            self.assertEqual(result["closed_neovim_servers"], [pid])
            self.assertEqual(process.wait(timeout=5), 0)

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
