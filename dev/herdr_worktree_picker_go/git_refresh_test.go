package main

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

func refreshFixture(t *testing.T) (*app, string) {
	t.Helper()
	base := t.TempDir()
	t.Setenv("GIT_CONFIG_GLOBAL", filepath.Join(base, "no-global-config"))
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	seed, bare := filepath.Join(base, "seed"), filepath.Join(base, "repo.git")
	fixtureGit(t, "init", "-q", "-b", "main", seed)
	fixtureGit(t, "-C", seed, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
		"commit", "--allow-empty", "-qm", "seed")
	fixtureGit(t, "clone", "-q", "--bare", seed, bare)
	herdr := filepath.Join(base, "herdr")
	payload, err := json.Marshal(map[string]any{"result": map[string]any{
		"source":    map[string]any{"repo_name": "repo.git"},
		"worktrees": []any{map[string]any{"path": bare, "is_bare": true}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	writeRefreshScript(t, herdr, "printf '%s\\n' "+refreshShellQuote(string(payload))+"\n")
	return &app{gitBin: lookPath("git"), herdrBin: herdr, root: bare,
		localMachine: "Mac", remoteMachine: "Mac"}, seed
}

func fixtureGit(t *testing.T, args ...string) string {
	t.Helper()
	out, err := exec.Command(lookPath("git"), args...).CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

func refreshShellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func writeRefreshScript(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("#!/bin/sh\n"+body), 0o755); err != nil {
		t.Fatal(err)
	}
}

func hasRefreshBranch(rows []row, kind, branch string) bool {
	for _, r := range rows {
		if r.Kind == kind && r.Branch == branch {
			return true
		}
	}
	return false
}

func TestGitRefreshFindsNewRemoteBranchAndRepairsBareClone(t *testing.T) {
	a, seed := refreshFixture(t)
	initial, err := a.buildWorktreeRows()
	if err != nil {
		t.Fatal(err)
	}
	branch := "fix/baba-1360-website-home-appointment-navigation"
	fixtureGit(t, "-C", seed, "branch", branch)
	if hasRefreshBranch(initial, "RB", branch) {
		t.Fatal("new branch unexpectedly present before refresh")
	}
	before := fixtureGit(t, "-C", a.root, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads")

	msg := a.refreshGitBranches(context.Background())
	if msg.Err != nil || !hasRefreshBranch(msg.Rows, "RB", branch) {
		t.Fatalf("new remote branch missing after refresh: %#v", msg)
	}
	rules := fixtureGit(t, "-C", a.root, "config", "--local", "--get-all", "remote.origin.fetch")
	if rules != "+refs/heads/*:refs/remotes/origin/*" {
		t.Fatalf("unexpected repair: %q", rules)
	}
	if err := a.ensureBareFetchConfig(context.Background()); err != nil {
		t.Fatal(err)
	}
	if after := fixtureGit(t, "-C", a.root, "config", "--get-all", "remote.origin.fetch"); after != rules {
		t.Fatalf("repair duplicated fetch rules: %q", after)
	}
	if after := fixtureGit(t, "-C", a.root, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads"); after != before {
		t.Fatal("local branches changed")
	}
}

func TestGitRefreshPreservesConfiguredBranchRestrictions(t *testing.T) {
	a, seed := refreshFixture(t)
	fixtureGit(t, "-C", seed, "branch", "allowed")
	fixtureGit(t, "-C", seed, "branch", "excluded")
	want := "+refs/heads/allowed:refs/remotes/origin/allowed"
	fixtureGit(t, "-C", a.root, "config", "remote.origin.fetch", want)
	msg := a.refreshGitBranches(context.Background())
	if msg.Err != nil || !hasRefreshBranch(msg.Rows, "RB", "allowed") || hasRefreshBranch(msg.Rows, "RB", "excluded") {
		t.Fatalf("custom fetch restriction lost: %#v", msg)
	}
	if got := fixtureGit(t, "-C", a.root, "config", "--get-all", "remote.origin.fetch"); got != want {
		t.Fatalf("custom rules changed: %q", got)
	}
}

func TestBareFetchRepairPreservesInheritedRulesAndOtherRepoTypes(t *testing.T) {
	t.Run("inherited", func(t *testing.T) {
		a, _ := refreshFixture(t)
		global := filepath.Join(t.TempDir(), "global-config")
		if err := os.WriteFile(global, []byte("[remote \"origin\"]\nfetch = +refs/heads/main:refs/remotes/origin/main\n"), 0o600); err != nil {
			t.Fatal(err)
		}
		t.Setenv("GIT_CONFIG_GLOBAL", global)
		if err := a.ensureBareFetchConfig(context.Background()); err != nil {
			t.Fatal(err)
		}
		cmd := exec.Command(a.gitBin, "-C", a.root, "config", "--local", "--get-all", "remote.origin.fetch")
		if err := cmd.Run(); err == nil {
			t.Fatal("inherited restriction overridden locally")
		}
	})
	t.Run("ordinary-clone", func(t *testing.T) {
		a, seed := refreshFixture(t)
		a.root = seed
		fixtureGit(t, "-C", seed, "config", "remote.origin.url", "/missing.git")
		if err := a.ensureBareFetchConfig(context.Background()); err != nil {
			t.Fatal(err)
		}
		if got, err := a.gitConfig(context.Background(), "--get-all", "remote.origin.fetch"); err != nil || got != "" {
			t.Fatalf("ordinary clone repaired unexpectedly: %q %v", got, err)
		}
	})
	t.Run("no-origin", func(t *testing.T) {
		a, _ := refreshFixture(t)
		fixtureGit(t, "-C", a.root, "config", "--remove-section", "remote.origin")
		msg := a.refreshGitBranches(context.Background())
		if msg.Err != nil || msg.Rows != nil {
			t.Fatalf("origin invented: %#v", msg)
		}
	})
}

func TestGitRefreshSkipsMirrorsAndLocalBranchDestinations(t *testing.T) {
	for _, mirror := range []bool{true, false} {
		t.Run(map[bool]string{true: "mirror", false: "local-branch"}[mirror], func(t *testing.T) {
			a, seed := refreshFixture(t)
			fixtureGit(t, "-C", seed, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
				"commit", "--allow-empty", "-qm", "remote advanced")
			if mirror {
				fixtureGit(t, "-C", a.root, "config", "remote.origin.mirror", "true")
			} else {
				fixtureGit(t, "-C", a.root, "config", "remote.origin.fetch", "+refs/heads/*:refs/heads/*")
			}
			before, err := os.ReadFile(filepath.Join(a.root, "config"))
			if err != nil {
				t.Fatal(err)
			}
			branch := fixtureGit(t, "-C", a.root, "rev-parse", "main")
			msg := a.refreshGitBranches(context.Background())
			if msg.Err != nil || msg.Rows != nil {
				t.Fatalf("unsafe refresh was not skipped: %#v", msg)
			}
			after, err := os.ReadFile(filepath.Join(a.root, "config"))
			if err != nil {
				t.Fatal(err)
			}
			if string(before) != string(after) || branch != fixtureGit(t, "-C", a.root, "rev-parse", "main") {
				t.Fatal("mirror or local branch destination changed")
			}
		})
	}
}

func TestGitRefreshPartialFailureStillLoadsFetchedRefs(t *testing.T) {
	a, _ := refreshFixture(t)
	git := a.gitBin
	wrapper := filepath.Join(t.TempDir(), "git")
	writeRefreshScript(t, wrapper, "if [ \"$3\" = fetch ]; then\n"+
		refreshShellQuote(git)+" -C \"$2\" update-ref refs/remotes/origin/fetched main\n"+
		"echo 'case-only branch collision' >&2\nexit 1\nfi\nexec "+refreshShellQuote(git)+" \"$@\"\n")
	a.gitBin = wrapper
	msg := a.refreshGitBranches(context.Background())
	if msg.Err == nil || !strings.Contains(msg.Err.Error(), "case-only branch collision") || !hasRefreshBranch(msg.Rows, "RB", "fetched") {
		t.Fatalf("partial fetch was discarded: %#v", msg)
	}
}

func TestGitRefreshOfflineKeepsCachedBranches(t *testing.T) {
	a, _ := refreshFixture(t)
	fixtureGit(t, "-C", a.root, "update-ref", "refs/remotes/origin/cached", "main")
	fixtureGit(t, "-C", a.root, "remote", "set-url", "origin", filepath.Join(t.TempDir(), "offline.git"))
	msg := a.refreshGitBranches(context.Background())
	if msg.Err == nil || !hasRefreshBranch(msg.Rows, "RB", "cached") {
		t.Fatalf("offline refresh lost cached branches or hid failure: %#v", msg)
	}
}

func TestGitRefreshPreservesSelectionQueryAndUbuntuRows(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu"}
	selected := row{Kind: "RB", Machine: "Mac", Branch: "feature/b", Target: "origin/feature/b"}
	ubuntu := row{Kind: "WT", Machine: "Ubuntu", Branch: "feature/ubuntu", Target: "/work/feature", Remote: true}
	m := model{app: a, allRows: []row{selected, ubuntu}, query: "feature", gitLoading: true}
	m.applyFilter(true)
	m.applyGitBranchRefresh(gitBranchesRefreshedMsg{Rows: []row{
		{Kind: "RB", Machine: "Mac", Branch: "feature/a", Target: "origin/feature/a"}, selected,
	}, Err: errors.New("partial fetch")})
	if m.gitLoading || m.gitErr == nil || m.query != "feature" || m.rows[m.cursor].Target != selected.Target || !hasRefreshBranch(m.allRows, "WT", ubuntu.Branch) {
		t.Fatalf("refresh changed search/selection or lost Ubuntu: %#v", m)
	}
	if view := stripANSI(m.View()); !strings.Contains(view, "partial fetch") {
		t.Fatalf("refresh error hidden: %s", view)
	}
	m.applyGitBranchRefresh(gitBranchesRefreshedMsg{Err: errors.New("list failed")})
	if len(m.allRows) != 3 || m.rows[m.cursor].Target != selected.Target {
		t.Fatal("failed rebuild discarded current results")
	}
}

func TestGitRefreshDoesNotBlockSearchAndCancelsChildren(t *testing.T) {
	a, _ := refreshFixture(t)
	base := t.TempDir()
	started, orphan := filepath.Join(base, "started"), filepath.Join(base, "orphan")
	git := a.gitBin
	wrapper := filepath.Join(base, "git")
	writeRefreshScript(t, wrapper, "if [ \"$3\" = fetch ]; then\n"+
		"[ \"$GIT_TERMINAL_PROMPT\" = 0 ] && [ \"$GCM_INTERACTIVE\" = never ] || exit 2\n"+
		"case \"$GIT_SSH_COMMAND\" in *'BatchMode=yes'*) ;; *) exit 3 ;; esac\n"+
		"(sleep 0.4; touch "+refreshShellQuote(orphan)+") &\n"+
		"touch "+refreshShellQuote(started)+"\nwait\nexit 0\nfi\nexec "+refreshShellQuote(git)+" \"$@\"\n")
	a.gitBin = wrapper
	rows, err := a.buildWorktreeRows()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	m := newModel(a, rows)
	m.gitContext = ctx
	cmd := m.Init()
	result := make(chan tea.Msg, 1)
	go func() { result <- cmd() }()
	deadline := time.Now().Add(2 * time.Second)
	for {
		if _, err := os.Stat(started); err == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("background fetch did not start")
		}
		time.Sleep(5 * time.Millisecond)
	}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("main")})
	m = updated.(model)
	if m.query != "main" || !strings.Contains(stripANSI(m.View()), "Git refreshing") {
		t.Fatal("search unavailable during fetch")
	}
	cancel()
	select {
	case response := <-result:
		msg := response.(gitBranchesRefreshedMsg)
		if !errors.Is(msg.Err, context.Canceled) {
			t.Fatalf("cancellation hidden: %#v", msg)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("fetch did not cancel")
	}
	time.Sleep(450 * time.Millisecond)
	if _, err := os.Stat(orphan); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("fetch child survived picker cancellation")
	}
}

func TestThreadPickersDoNotFetchGit(t *testing.T) {
	for _, a := range []*app{
		{root: "/repo", localMachine: "Mac", remoteMachine: "Mac", threadsOnly: true},
		{root: "/repo", localMachine: "Mac", remoteMachine: "Mac", newThreadOnly: true},
	} {
		if m := newModel(a, nil); m.gitLoading {
			t.Fatal("thread picker started Git refresh")
		}
	}
}
