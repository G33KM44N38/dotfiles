package main

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
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

func TestParseArgsRejectsConflictingFetchFlags(t *testing.T) {
	_, err := parseArgs([]string{"--fetch", "--no-fetch"}, func(string) string { return "" })
	if err == nil || !strings.Contains(err.Error(), "cannot be used together") {
		t.Fatalf("expected conflicting fetch flags error, got %v", err)
	}
}

func TestParseArgsAutomationIsNonInteractiveAndDoesNotPull(t *testing.T) {
	cfg, err := parseArgs([]string{"--automation", "--root", "/tmp/work"}, func(string) string { return "" })
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.automation || !cfg.yes || cfg.autoPull || cfg.scanRoot != "/tmp/work" {
		t.Fatalf("unexpected automation config: %+v", cfg)
	}
}

func TestRunRepositoryFailsClosedWhenFetchFails(t *testing.T) {
	runner := &failingFetchRunner{}
	a := app{
		cfg:    config{forceFetch: true, parallelJobs: 1},
		runner: runner,
		out:    &bytes.Buffer{},
		errOut: &bytes.Buffer{},
	}
	err := a.runRepository(context.Background(), "/repo")
	if err == nil || !strings.Contains(err.Error(), "refusing cleanup") {
		t.Fatalf("expected fail-closed fetch error, got %v", err)
	}
	if runner.listCalled {
		t.Fatal("worktrees were scanned after fetch failed")
	}
}

type failingFetchRunner struct {
	listCalled bool
}

func (r *failingFetchRunner) Run(_ context.Context, _ string, name string, args ...string) (string, error) {
	if name == "git" && len(args) > 0 && args[0] == "fetch" {
		return "", errors.New("network unavailable")
	}
	if name == "git" && len(args) > 1 && args[0] == "worktree" && args[1] == "list" {
		r.listCalled = true
	}
	return "", nil
}

func TestConfiguredJobsDefaultsToCPUCountUpToEight(t *testing.T) {
	got, err := configuredJobs(func(string) string { return "" })
	if err != nil {
		t.Fatal(err)
	}
	want := runtime.NumCPU()
	if want > 8 {
		want = 8
	}
	if got != want {
		t.Fatalf("default jobs = %d, want %d", got, want)
	}
}

func TestRepoRootAcceptsWorktree(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git unavailable")
	}

	tmp := t.TempDir()
	repo := filepath.Join(tmp, "repo")
	runGit(t, tmp, "init", repo)
	chdir(t, repo)

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
	chdir(t, bare)

	a := app{runner: execRunner{}}
	got, err := a.repoRoot(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !samePath(t, got, bare) {
		t.Fatalf("repoRoot = %q, want %q", got, bare)
	}
}

func TestDiscoverRepositoriesDeduplicatesLinkedWorktrees(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git unavailable")
	}

	root := t.TempDir()
	repo := filepath.Join(root, "source")
	runGit(t, root, "init", repo)
	runGit(t, repo, "config", "user.email", "test@example.com")
	runGit(t, repo, "config", "user.name", "Test User")
	mustWrite(t, filepath.Join(repo, "README.md"), "base\n")
	runGit(t, repo, "add", "README.md")
	runGit(t, repo, "commit", "-m", "base")
	runGit(t, repo, "branch", "linked")
	runGit(t, repo, "worktree", "add", filepath.Join(root, "linked"), "linked")
	runGit(t, root, "init", "--bare", filepath.Join(root, "other.git"))

	a := app{runner: execRunner{}}
	repositories, err := a.discoverRepositories(context.Background(), root)
	if err != nil {
		t.Fatal(err)
	}
	if len(repositories) != 2 {
		t.Fatalf("repositories = %#v, want two shared Git directories", repositories)
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

func chdir(t *testing.T, path string) {
	t.Helper()
	previous, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(path); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(previous); err != nil {
			t.Errorf("restore working directory: %v", err)
		}
	})
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
	pl.add(row{category: catBehind, path: "/tmp/behind", branch: "feat-behind", reason: "behind", a: "2", compareRef: "origin/feat-behind"})
	pl.add(row{category: catUnpushed, path: "/tmp/ahead", branch: "feat-ahead", reason: "unpushed", a: "1", compareRef: "origin/feat-ahead"})
	pl.add(row{category: catAttention, path: "/tmp/dirty", branch: "feat-dirty", reason: "local_changes"})
	pl.add(row{category: catKeep, path: "/tmp/main", branch: "main", reason: "protected"})

	var out bytes.Buffer
	renderPlan(&out, pl, palette{})
	text := out.String()
	for _, part := range []string{
		"✅ SAFE TO REMOVE",
		"feat-safe  (merged into origin/main)",
		"🔄 BEHIND (can pull --ff-only)",
		"feat-behind  (2 behind origin/feat-behind)",
		"📤 UNPUSHED COMMITS",
		"feat-ahead  (1 commit(s) not pushed to origin/feat-ahead)",
		"⚠️  ATTENTION (manual review)",
		"feat-dirty  (local changes: tracked/staged/untracked/ignored)",
		"ℹ️  KEEP",
		"main  (protected)",
	} {
		if !strings.Contains(text, part) {
			t.Fatalf("rendered plan missing %q:\n%s", part, text)
		}
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
		filepath.Join(tmp, "dirty"):    catAttention,
		filepath.Join(tmp, "behind"):   catBehind,
		repo:                           catKeep,
	}
	for path, want := range cases {
		got := a.classify(ctx, repo, worktree{path: path})
		if got.category != want {
			t.Fatalf("%s category = %s, want %s: %#v", path, got.category, want, got)
		}
	}

	a.cfg.automation = true
	dirty := a.classify(ctx, repo, worktree{path: filepath.Join(tmp, "dirty")})
	if dirty.category != catAttention || dirty.reason != "local_changes" {
		t.Fatalf("automation dirty category = %#v, want attention/local_changes", dirty)
	}

	protected := a
	protected.protectedPaths = map[string]bool{filepath.Join(tmp, "safe"): true}
	active := protected.classify(ctx, repo, worktree{path: filepath.Join(tmp, "safe")})
	if active.category != catKeep || active.reason != "active_workspace" {
		t.Fatalf("active worktree category = %#v, want keep/active_workspace", active)
	}

	planned := a.classify(ctx, repo, worktree{path: filepath.Join(tmp, "safe")})
	if planned.category != catSafe {
		t.Fatalf("planned worktree = %#v, want safe", planned)
	}
	mustWrite(t, filepath.Join(tmp, "safe", "appeared-after-scan.txt"), "do not delete\n")
	result, err := a.removeSafeWorktree(ctx, repo, planned)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(result, "Skipped") {
		t.Fatalf("race result = %q, want skipped", result)
	}
	if !isDir(filepath.Join(tmp, "safe")) {
		t.Fatal("worktree was removed after becoming dirty")
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
