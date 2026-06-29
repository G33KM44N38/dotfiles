package main

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseArgsUsesNewAndDeprecatedJobEnv(t *testing.T) {
	cfg, err := parseArgs([]string{"--dry-run", "--yes", "--no-pull"}, func(key string) string {
		switch key {
		case "WORKTREE_CHORE_JOBS":
			return "3"
		case "WORKTREE_CHORE_REMOVE_JOBS":
			return "7"
		default:
			return ""
		}
	})
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.dryRun || !cfg.yes || cfg.autoPull || cfg.parallelJobs != 3 {
		t.Fatalf("unexpected config: %+v", cfg)
	}

	cfg, err = parseArgs(nil, func(key string) string {
		if key == "WORKTREE_CHORE_REMOVE_JOBS" {
			return "7"
		}
		return ""
	})
	if err != nil {
		t.Fatal(err)
	}
	if cfg.parallelJobs != 7 {
		t.Fatalf("deprecated env fallback = %d, want 7", cfg.parallelJobs)
	}
}

func TestParseArgsRejectsBadJobs(t *testing.T) {
	_, err := parseArgs(nil, func(key string) string {
		if key == "WORKTREE_CHORE_JOBS" {
			return "0"
		}
		return ""
	})
	if err == nil || !strings.Contains(err.Error(), "positive integer") {
		t.Fatalf("expected positive integer error, got %v", err)
	}
}

func TestRepoRootAcceptsWorktree(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git unavailable")
	}

	tmp := t.TempDir()
	repo := filepath.Join(tmp, "repo")
	runGit(t, tmp, "init", repo)
	t.Chdir(repo)

	a := app{runner: execRunner{}}
	got, err := a.repoRoot(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !samePath(t, got, repo) {
		t.Fatalf("repoRoot = %q, want %q", got, repo)
	}
}

func TestRepoRootAcceptsBareRepository(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git unavailable")
	}

	tmp := t.TempDir()
	bare := filepath.Join(tmp, "repo.git")
	runGit(t, tmp, "init", "--bare", bare)
	t.Chdir(bare)

	a := app{runner: execRunner{}}
	got, err := a.repoRoot(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !samePath(t, got, bare) {
		t.Fatalf("repoRoot = %q, want %q", got, bare)
	}
}

func samePath(t *testing.T, a, b string) bool {
	t.Helper()
	aInfo, err := os.Stat(a)
	if err != nil {
		t.Fatal(err)
	}
	bInfo, err := os.Stat(b)
	if err != nil {
		t.Fatal(err)
	}
	return os.SameFile(aInfo, bInfo)
}

func TestParseWorktrees(t *testing.T) {
	got := parseWorktrees(`worktree /repo
HEAD abc
branch refs/heads/main

worktree /repo-feature
HEAD def
branch refs/heads/feature/demo

worktree /repo-detached
HEAD abc
detached

worktree /repo-bare
bare
`)
	want := []worktree{
		{path: "/repo", branch: "main"},
		{path: "/repo-feature", branch: "feature/demo"},
		{path: "/repo-detached", branch: "(detached)"},
	}
	if len(got) != len(want) {
		t.Fatalf("len = %d, want %d: %#v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("worktree[%d] = %#v, want %#v", i, got[i], want[i])
		}
	}
}

func TestRenderPlanMatchesShellSections(t *testing.T) {
	pl := plan{}
	pl.add(row{category: catSafe, path: "/tmp/safe", branch: "feat-safe", reason: "merged", a: "main"})
	pl.staleDirs = append(pl.staleDirs, row{path: "/tmp/stale", branch: "stale", reason: "not_registered"})
	pl.add(row{category: catBehind, path: "/tmp/behind", branch: "feat-behind", reason: "behind", a: "2", compareRef: "origin/feat-behind"})
	pl.add(row{category: catUnpushed, path: "/tmp/ahead", branch: "feat-ahead", reason: "unpushed", a: "1", compareRef: "origin/feat-ahead"})
	pl.add(row{category: catAttention, path: "/tmp/dirty", branch: "feat-dirty", reason: "local_changes"})
	pl.add(row{category: catKeep, path: "/tmp/main", branch: "main", reason: "protected"})

	var out bytes.Buffer
	renderPlan(&out, pl)
	text := out.String()
	for _, part := range []string{
		"✅ SAFE TO REMOVE",
		"feat-safe  (merged into origin/main)",
		"🧽 STALE DIRECTORIES",
		"stale  (not registered as a git worktree)",
		"🔄 BEHIND (can pull --rebase)",
		"feat-behind  (2 behind origin/feat-behind)",
		"📤 UNPUSHED COMMITS",
		"feat-ahead  (1 commit(s) not pushed to origin/feat-ahead)",
		"⚠️  ATTENTION (manual review)",
		"feat-dirty  (local changes: tracked/staged/untracked)",
		"ℹ️  KEEP",
		"main  (protected)",
	} {
		if !strings.Contains(text, part) {
			t.Fatalf("rendered plan missing %q:\n%s", part, text)
		}
	}
}

func TestFindStaleDirsScansWorktreeSiblingParents(t *testing.T) {
	tmp := t.TempDir()
	root := filepath.Join(tmp, "codex-")
	nested := filepath.Join(root, "r-")
	for _, dir := range []string{
		filepath.Join(root, "main"),
		filepath.Join(root, "feature"),
		filepath.Join(root, "orphan"),
		nested,
		filepath.Join(nested, "release"),
		filepath.Join(nested, "old-release"),
	} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	got := findStaleDirs([]worktree{
		{path: filepath.Join(root, "main")},
		{path: filepath.Join(root, "feature")},
		{path: filepath.Join(nested, "release")},
		{path: filepath.Join(nested, "other")},
	})
	var names []string
	for _, row := range got {
		names = append(names, row.branch)
	}
	if strings.Join(names, ",") != "orphan,old-release" {
		t.Fatalf("stale dirs = %v, want [orphan old-release]", names)
	}
}

func TestFindStaleDirsSkipsSystemTempParents(t *testing.T) {
	temp := filepath.Clean(os.TempDir())
	got := findStaleDirs([]worktree{
		{path: filepath.Join(temp, "registered-one")},
		{path: filepath.Join(temp, "registered-two")},
	})
	if len(got) != 0 {
		t.Fatalf("system temp stale dirs = %#v, want none", got)
	}
}

func TestFindStaleDirsScansConventionalWorktreeFolders(t *testing.T) {
	tmp := t.TempDir()
	branches := filepath.Join(tmp, "repo.git", "worktrees", "branches")
	threads := filepath.Join(tmp, "repo.git", "worktrees", "threads")
	for _, dir := range []string{
		filepath.Join(tmp, "repo.git", "worktrees", "main"),
		filepath.Join(branches, "registered-branch"),
		filepath.Join(branches, "stale-branch"),
		filepath.Join(threads, "stale-thread"),
	} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	got := findStaleDirs([]worktree{
		{path: filepath.Join(tmp, "repo.git", "worktrees", "main")},
		{path: filepath.Join(branches, "registered-branch")},
	})
	var names []string
	for _, row := range got {
		names = append(names, row.branch)
	}
	if strings.Join(names, ",") != "stale-branch,stale-thread" {
		t.Fatalf("stale dirs = %v, want [stale-branch stale-thread]", names)
	}
}

func TestClassifyWorktreesInGitRepo(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git unavailable")
	}

	ctx := context.Background()
	tmp := t.TempDir()
	remote := filepath.Join(tmp, "remote.git")
	runGit(t, tmp, "init", "--bare", remote)

	repo := filepath.Join(tmp, "repo")
	runGit(t, tmp, "clone", remote, repo)
	runGit(t, repo, "config", "user.email", "test@example.com")
	runGit(t, repo, "config", "user.name", "Test User")
	mustWrite(t, filepath.Join(repo, "README.md"), "base\n")
	runGit(t, repo, "add", "README.md")
	runGit(t, repo, "commit", "-m", "base")
	runGit(t, repo, "branch", "-M", "main")
	runGit(t, repo, "push", "-u", "origin", "main")

	runGit(t, repo, "checkout", "-b", "safe-merged")
	mustWrite(t, filepath.Join(repo, "safe.txt"), "safe\n")
	runGit(t, repo, "add", "safe.txt")
	runGit(t, repo, "commit", "-m", "safe")
	runGit(t, repo, "checkout", "main")
	runGit(t, repo, "merge", "--no-ff", "safe-merged", "-m", "merge safe")
	runGit(t, repo, "push", "origin", "main")
	runGit(t, repo, "worktree", "add", filepath.Join(tmp, "safe"), "safe-merged")

	runGit(t, repo, "checkout", "-b", "unpushed")
	runGit(t, repo, "push", "-u", "origin", "unpushed")
	mustWrite(t, filepath.Join(repo, "unpushed.txt"), "unpushed\n")
	runGit(t, repo, "add", "unpushed.txt")
	runGit(t, repo, "commit", "-m", "unpushed")
	runGit(t, repo, "checkout", "main")
	runGit(t, repo, "worktree", "add", filepath.Join(tmp, "unpushed"), "unpushed")

	runGit(t, repo, "checkout", "-b", "dirty")
	runGit(t, repo, "push", "-u", "origin", "dirty")
	runGit(t, repo, "checkout", "main")
	runGit(t, repo, "worktree", "add", filepath.Join(tmp, "dirty"), "dirty")
	mustWrite(t, filepath.Join(tmp, "dirty", "dirty.txt"), "dirty\n")

	runGit(t, repo, "checkout", "-b", "behind")
	mustWrite(t, filepath.Join(repo, "behind-base.txt"), "behind base\n")
	runGit(t, repo, "add", "behind-base.txt")
	runGit(t, repo, "commit", "-m", "behind base")
	runGit(t, repo, "push", "-u", "origin", "behind")
	runGit(t, repo, "checkout", "main")
	runGit(t, repo, "worktree", "add", filepath.Join(tmp, "behind"), "behind")
	other := filepath.Join(tmp, "other")
	runGit(t, tmp, "clone", remote, other)
	runGit(t, other, "config", "user.email", "test@example.com")
	runGit(t, other, "config", "user.name", "Test User")
	runGit(t, other, "checkout", "behind")
	mustWrite(t, filepath.Join(other, "behind.txt"), "behind\n")
	runGit(t, other, "add", "behind.txt")
	runGit(t, other, "commit", "-m", "behind")
	runGit(t, other, "push", "origin", "behind")
	runGit(t, repo, "fetch", "--all", "--prune")

	a := app{cfg: config{parallelJobs: 2}, runner: execRunner{}}
	cases := map[string]category{
		filepath.Join(tmp, "safe"):     catSafe,
		filepath.Join(tmp, "unpushed"): catUnpushed,
		filepath.Join(tmp, "dirty"):    catSafe,
		filepath.Join(tmp, "behind"):   catBehind,
		repo:                           catKeep,
	}
	for path, want := range cases {
		got := a.classify(ctx, repo, worktree{path: path})
		if got.category != want {
			t.Fatalf("%s category = %s, want %s: %#v", path, got.category, want, got)
		}
	}
}

func runGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_PAGER=cat")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s failed in %s: %v\n%s", strings.Join(args, " "), dir, err, out)
	}
}

func mustWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
