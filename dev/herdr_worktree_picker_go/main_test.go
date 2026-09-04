package main

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

func TestApplyFilterRanksExactBranchFirst(t *testing.T) {
	rows := []row{
		{Branch: "feature/cleanup", Detail: "/work/main-service", Updated: 300},
		{Branch: "remain", Updated: 250},
		{Branch: "feature/main", Updated: 200},
		{Branch: "mainline", Updated: 150},
		{Branch: "main", Updated: 100},
	}
	m := model{allRows: rows, query: "main"}

	m.applyFilter(true)

	want := []string{"main", "mainline", "feature/main", "remain", "feature/cleanup"}
	if len(m.rows) != len(want) {
		t.Fatalf("got %d rows, want %d", len(m.rows), len(want))
	}
	for i, branch := range want {
		if m.rows[i].Branch != branch {
			t.Errorf("row %d = %q, want %q", i, m.rows[i].Branch, branch)
		}
	}
}

func TestApplyFilterIsCaseInsensitive(t *testing.T) {
	rows := []row{{Branch: "feature/main"}, {Branch: "Main"}}
	m := model{allRows: rows, query: "MAIN"}

	m.applyFilter(true)

	if got := m.rows[0].Branch; got != "Main" {
		t.Fatalf("first row = %q, want exact branch Main", got)
	}
}

func TestApplyFilterWithoutQueryPreservesRecencyOrder(t *testing.T) {
	rows := []row{{Branch: "newest"}, {Branch: "older"}}
	m := model{allRows: rows}

	m.applyFilter(true)

	for i := range rows {
		if m.rows[i].Branch != rows[i].Branch {
			t.Fatalf("row %d = %q, want %q", i, m.rows[i].Branch, rows[i].Branch)
		}
	}
}

func TestRowPriorityKeepsThreadsBeforeGitTargets(t *testing.T) {
	rows := []row{
		{Kind: "RB", Branch: "remote"},
		{Kind: "TH", State: "idle", Branch: "idle"},
		{Kind: "WT", Branch: "worktree"},
		{Kind: "TH", State: "working", Branch: "working"},
		{Kind: "TH", State: "blocked", Branch: "blocked"},
	}

	for i := 1; i < len(rows); i++ {
		for j := i; j > 0 && rowPriority(rows[j]) < rowPriority(rows[j-1]); j-- {
			rows[j], rows[j-1] = rows[j-1], rows[j]
		}
	}

	want := []string{"blocked", "working", "idle", "worktree", "remote"}
	for i, title := range want {
		if rows[i].Branch != title {
			t.Fatalf("row %d = %q, want %q", i, rows[i].Branch, title)
		}
	}
}

func TestSnapshotRowsUseMachineScopedThreadIdentity(t *testing.T) {
	data := map[string]any{
		"result": map[string]any{
			"snapshot": map[string]any{
				"workspaces": []any{map[string]any{
					"workspace_id": "w1",
					"label":        "feature",
					"repository": map[string]any{
						"checkout_path":     "/work/feature",
						"portable_repo_key": "github.com/example/repo",
					},
				}},
				"agents": []any{map[string]any{
					"name":             "api-thread",
					"agent_status":     "working",
					"pane_id":          "w1:p2",
					"workspace_id":     "w1",
					"state_change_seq": float64(42),
					"agent_session": map[string]any{
						"value": "thread-1234567890",
					},
				}},
			},
		},
	}
	a := &app{}

	rows := a.snapshotRows(data, "Ubuntu", true)

	if len(rows) != 2 {
		t.Fatalf("got %d rows, want thread and worktree", len(rows))
	}
	thread := rows[1]
	if thread.Kind != "TH" || thread.Machine != "Ubuntu" || thread.Target != "w1:p2" {
		t.Fatalf("unexpected thread row: %#v", thread)
	}
	if thread.Session != "thread-1234567890" || thread.Repo != "github.com/example/repo" {
		t.Fatalf("thread identity was not retained: %#v", thread)
	}
}

func TestSnapshotRowsHideLocalUbuntuAttachProxy(t *testing.T) {
	data := map[string]any{
		"result": map[string]any{
			"snapshot": map[string]any{
				"agents": []any{map[string]any{
					"name":          "ubuntu-session",
					"display_agent": "Ubuntu · Herdr",
					"pane_id":       "w1:p9",
				}},
			},
		},
	}
	a := &app{}

	rows := a.snapshotRows(data, "Mac", false)

	if len(rows) != 0 {
		t.Fatalf("attach proxy leaked into thread rows: %#v", rows)
	}
	if a.remoteAttachPane != "w1:p9" {
		t.Fatalf("attach pane = %q, want w1:p9", a.remoteAttachPane)
	}
}

func TestSnapshotRowsShowsDirectUbuntuCodexAsRemoteHosted(t *testing.T) {
	data := map[string]any{
		"result": map[string]any{
			"snapshot": map[string]any{
				"workspaces": []any{map[string]any{
					"workspace_id": "w1",
					"label":        "Fix login",
					"repository": map[string]any{
						"checkout_path":     "/local/repo",
						"portable_repo_key": "github.com/example/repo",
					},
				}},
				"agents": []any{map[string]any{
					"name":          "ubuntu-codex",
					"display_agent": "Ubuntu · Codex",
					"agent_status":  "working",
					"pane_id":       "w1:p2",
					"workspace_id":  "w1",
				}},
			},
		},
	}
	a := &app{remoteMachine: "Ubuntu"}

	rows := a.snapshotRows(data, "Mac", false)

	if len(rows) != 1 {
		t.Fatalf("got %d rows, want direct remote thread", len(rows))
	}
	thread := rows[0]
	if thread.Machine != "Ubuntu" || !thread.RemoteHost || thread.Remote {
		t.Fatalf("unexpected direct remote row: %#v", thread)
	}
	if thread.Target != "w1:p2" || thread.Repo != "github.com/example/repo" {
		t.Fatalf("direct remote identity was not retained: %#v", thread)
	}
}

func TestGlobalThreadSearchOffersCreationAfterNoMatch(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteOnline: true, root: "/work/current"}
	m := model{
		app: a,
		allRows: []row{{
			Kind: "TH", Machine: "Mac", Branch: "login bug", Session: "session-1",
		}},
		query: "why does checkout fail",
	}

	m.applyFilter(true)

	if len(m.rows) != 1 || m.rows[0].Kind != "NEW" || m.rows[0].Prompt != "why does checkout fail" {
		t.Fatalf("global search did not offer creation: %#v", m.rows)
	}
}

func TestExactWorktreeSearchDoesNotOfferCreation(t *testing.T) {
	a := &app{localMachine: "Mac", root: "/work/current"}
	m := model{
		app: a,
		allRows: []row{{
			Kind: "WT", Machine: "Mac", Branch: "ci/baba-1313-targeted-validation-flow",
		}},
		query: "ci/baba-1313-targeted-validation-flow",
	}

	m.applyFilter(true)

	if len(m.rows) != 1 || m.rows[0].Kind != "WT" {
		t.Fatalf("worktree search offered a non-worktree action: %#v", m.rows)
	}
}

func TestMissingWorktreeSearchOffersCreation(t *testing.T) {
	a := &app{localMachine: "Mac", root: "/work/current"}
	m := model{
		app: a,
		allRows: []row{{
			Kind: "WT", Machine: "Mac", Branch: "ci/existing-flow",
		}},
		query: "ci/new-flow",
	}

	m.applyFilter(true)

	if len(m.rows) != 1 || m.rows[0].Kind != "NEW" || m.rows[0].Prompt != "ci/new-flow" {
		t.Fatalf("missing worktree search did not offer creation: %#v", m.rows)
	}
}

func TestProjectThreadModeKeepsOnlyCurrentRepo(t *testing.T) {
	a := &app{newThreadOnly: true, root: "/work/current", localMachine: "Mac"}
	rows := []row{
		{Kind: "NEW", Branch: "New thread"},
		{Kind: "TH", Branch: "current", Repo: "github.com/example/current"},
		{Kind: "HIST", Branch: "other", Repo: "github.com/example/other"},
	}

	filtered := a.filterModeRows(rows)

	if len(filtered) != 2 || filtered[0].Kind != "NEW" || filtered[1].Branch != "current" {
		t.Fatalf("unexpected project rows: %#v", filtered)
	}
}

func TestProjectFilterDoesNotRunGitForEachHistoryPath(t *testing.T) {
	directory := t.TempDir()
	logPath := filepath.Join(directory, "calls")
	gitPath := filepath.Join(directory, "git")
	script := "#!/bin/sh\nprintf x >>\"$HERDR_GIT_CALL_LOG\"\nexit 1\n"
	if err := os.WriteFile(gitPath, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HERDR_GIT_CALL_LOG", logPath)
	a := &app{newThreadOnly: true, root: filepath.Join(directory, "repo"), gitBin: gitPath}
	rows := make([]row, 100)
	for index := range rows {
		rows[index] = row{Kind: "HIST", Repo: "other", Target: filepath.Join(directory, "other", string(rune(index+65)))}
	}

	a.filterModeRows(rows)
	raw, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw) > 3 {
		t.Fatalf("project filter ran Git %d times, want at most 3", len(raw))
	}
}

func TestNormalizeRepoKeyMatchesHerdrPortableKey(t *testing.T) {
	for _, remote := range []string{
		"git@github.com:example/repo.git",
		"https://github.com/example/repo.git",
	} {
		if got := normalizeRepoKey(remote); got != "github.com/example/repo" {
			t.Fatalf("normalizeRepoKey(%q) = %q", remote, got)
		}
	}
}

func TestMatchingThreadTitleJoinsInsteadOfCreating(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteOnline: true}
	m := model{
		app: a,
		allRows: []row{{
			Kind: "TH", Machine: "Ubuntu", Branch: "login bug", Session: "session-1",
		}},
		query: "LOGIN",
	}

	m.applyFilter(true)

	if len(m.rows) != 1 || m.rows[0].Kind != "TH" {
		t.Fatalf("matching thread title did not select existing thread: %#v", m.rows)
	}
}

func TestThreadModeHidesGitTargets(t *testing.T) {
	rows := []row{
		{Kind: "NEW", Branch: "New thread"},
		{Kind: "TH", Branch: "existing thread"},
		{Kind: "HIST", Branch: "saved thread"},
		{Kind: "WT", Branch: "worktree"},
		{Kind: "BR", Branch: "branch"},
		{Kind: "RB", Branch: "remote branch"},
	}

	filtered := filterThreadRows(rows)

	if len(filtered) != 3 || filtered[0].Kind != "NEW" || filtered[1].Kind != "TH" || filtered[2].Kind != "HIST" {
		t.Fatalf("unexpected thread-only rows: %#v", filtered)
	}
}

func TestWorktreeModeContainsOnlyGitTargets(t *testing.T) {
	rows := []row{
		{Kind: "NEW", Branch: "New thread"},
		{Kind: "TH", Branch: "existing thread"},
		{Kind: "WT", Branch: "worktree"},
		{Kind: "BR", Branch: "branch"},
		{Kind: "RB", Branch: "remote branch"},
	}

	filtered := filterWorktreeRows(rows)

	if len(filtered) != 3 {
		t.Fatalf("unexpected worktree picker rows: %#v", filtered)
	}
	for _, candidate := range filtered {
		if candidate.Kind == "TH" || candidate.Kind == "NEW" {
			t.Fatalf("thread action leaked into worktree mode: %#v", candidate)
		}
	}
}

func TestThreadBranchUsesPromptAndTimestamp(t *testing.T) {
	when := time.Date(2026, 9, 2, 14, 5, 6, 0, time.UTC)

	got := threadBranch("Fix checkout failure", when)

	if got != "thread/fix-checkout-failure-20260902-140506" {
		t.Fatalf("branch = %q", got)
	}
}

func TestThreadTitleComesFromFirstPrompt(t *testing.T) {
	prompt := "Fix the checkout flow when the remote default branch changes unexpectedly"

	got := generatedThreadTitle(prompt)

	if got != "Fix the checkout flow when the remote…" {
		t.Fatalf("title = %q", got)
	}
}

func TestNewThreadLaunchArgsKeepDraftChoices(t *testing.T) {
	when := time.Date(2026, 9, 4, 12, 30, 0, 0, time.UTC)
	r := row{
		Target: "ubuntu", Prompt: "Fix login", GitSpace: "worktree", Source: "origin", Base: "develop",
	}

	got := newThreadLaunchArgs(r, "/work/repo", "main", when)
	want := []string{
		"ubuntu", "--project-path", "/work/repo",
		"--git-space", "worktree", "--source", "origin",
		"--default-branch", "develop", "--thread-title", "Fix login", "--new-worktree",
		"thread/fix-login-20260904-123000", "--prompt", "Fix login",
	}
	if strings.Join(got, "\x00") != strings.Join(want, "\x00") {
		t.Fatalf("args = %#v, want %#v", got, want)
	}
}

func TestDefaultBranchFollowsOriginHead(t *testing.T) {
	repository := t.TempDir()
	git := lookPath("git")
	for _, args := range [][]string{
		{"init", "-q", "-b", "develop", repository},
		{"-C", repository, "remote", "add", "origin", "https://example.test/repo.git"},
		{"-C", repository, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop"},
	} {
		if output, err := exec.Command(git, args...).CombinedOutput(); err != nil {
			t.Fatalf("git %v failed: %v: %s", args, err, output)
		}
	}

	a := app{gitBin: git, root: repository}
	if got := a.defaultBranch(); got != "develop" {
		t.Fatalf("default branch = %q, want develop", got)
	}
}

func TestRepoRootRecoversStaleLinkedCheckout(t *testing.T) {
	root := filepath.Join(t.TempDir(), "repo.git")
	checkout := filepath.Join(root, "main")
	if err := os.MkdirAll(checkout, 0o755); err != nil {
		t.Fatal(err)
	}
	git := lookPath("git")
	if output, err := exec.Command(git, "init", "-q", "--bare", root).CombinedOutput(); err != nil {
		t.Fatalf("bare init failed: %v: %s", err, output)
	}
	staleGitDir := filepath.Join(root, "worktrees", "main")
	if err := os.WriteFile(filepath.Join(checkout, ".git"), []byte("gitdir: "+staleGitDir+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	a := app{gitBin: git}
	got, err := a.repoRoot(checkout)
	if err != nil || got != root {
		t.Fatalf("repoRoot() = %q, %v, want %q", got, err, root)
	}
}

func TestPickerLabelsMatchItsMode(t *testing.T) {
	worktree := model{app: &app{localMachine: "Mac"}, width: 100, height: 12}
	if view := stripANSI(worktree.View()); !strings.Contains(view, "herdr worktree >") || strings.Contains(view, "herdr thread >") {
		t.Fatalf("unexpected worktree view: %q", view)
	}

	thread := model{app: &app{localMachine: "Mac", threadsOnly: true}, width: 100, height: 12}
	if view := stripANSI(thread.View()); !strings.Contains(view, "herdr thread >") || strings.Contains(view, "herdr worktree >") {
		t.Fatalf("unexpected thread view: %q", view)
	}
}

func TestRemoteFailureKeepsLocalRowsAndStopsLoading(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteLoading: true}
	m := model{
		app:     a,
		allRows: []row{{Kind: "WT", Machine: "Mac", Branch: "main"}},
	}

	updated, _ := m.Update(remoteSnapshotMsg{err: errors.New("offline")})
	got := updated.(model)

	if got.app.remoteLoading {
		t.Fatal("remote loading remained active after failure")
	}
	if got.app.remoteErr == nil {
		t.Fatal("remote failure state was not retained")
	}
	if len(got.allRows) != 1 || got.allRows[0].Branch != "main" {
		t.Fatalf("remote failure changed local rows: %#v", got.allRows)
	}
}

func TestHistoryLoadingAndFailureStatesAreVisible(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Mac", threadsOnly: true, historyLoading: true}
	m := model{app: a, width: 120, height: 12}
	if view := stripANSI(m.View()); !strings.Contains(view, "history loading") {
		t.Fatalf("loading state is missing: %q", view)
	}

	a.historyLoading = false
	a.historyErr = errors.New("database is locked")
	if view := stripANSI(m.View()); !strings.Contains(view, "history failed: database is locked") {
		t.Fatalf("failure state is missing: %q", view)
	}

	a.historyErr = nil
	a.historyLoaded = true
	if view := stripANSI(m.View()); !strings.Contains(view, "no saved threads") {
		t.Fatalf("empty state is missing: %q", view)
	}
}

func TestHistoryLoadFailureReturnsAUsefulError(t *testing.T) {
	directory := t.TempDir()
	failingSQLite := filepath.Join(directory, "sqlite3")
	if err := os.WriteFile(failingSQLite, []byte("#!/bin/sh\nprintf 'database is locked\\n' >&2\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	database := filepath.Join(directory, "state_5.sqlite")
	if err := os.WriteFile(database, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	a := &app{sqliteBin: failingSQLite, historyDB: database, localMachine: "Mac"}

	_, err := a.loadHistoryRows()

	if err == nil || !strings.Contains(err.Error(), "database is locked") {
		t.Fatalf("unexpected history error: %v", err)
	}
}

func TestHistoryRowsAreTiedToTheirSavedPaths(t *testing.T) {
	directory := t.TempDir()
	savedPath := filepath.Join(directory, "saved-path")
	if err := os.Mkdir(savedPath, 0o755); err != nil {
		t.Fatal(err)
	}
	fakeSQLite := filepath.Join(directory, "sqlite3")
	payload := `[{"id":"session-1","cwd":"` + savedPath + `","title":"Fix checkout","updated":1788379200}]`
	if err := os.WriteFile(fakeSQLite, []byte("#!/bin/sh\nprintf '%s' '"+payload+"'\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	database := filepath.Join(directory, "state_5.sqlite")
	if err := os.WriteFile(database, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	a := &app{sqliteBin: fakeSQLite, historyDB: database, localMachine: "Mac"}

	rows, err := a.loadHistoryRows()

	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 || rows[0].Kind != "HIST" || rows[0].Target != savedPath {
		t.Fatalf("unexpected history row: %#v", rows)
	}
	if rows[0].Session != "session-1" || rows[0].Branch != "Fix checkout" {
		t.Fatalf("saved thread identity was lost: %#v", rows[0])
	}
	if rows[0].State != "history" {
		t.Fatalf("available path was marked %q", rows[0].State)
	}
}

func TestHistoryMergeDoesNotDuplicateALiveThread(t *testing.T) {
	a := &app{threadsOnly: true}
	m := model{app: a, allRows: []row{{Kind: "TH", Session: "session-1", Branch: "live"}}}

	m.applyHistoryRows([]row{
		{Kind: "HIST", Session: "session-1", Branch: "saved duplicate"},
		{Kind: "HIST", Session: "session-2", Branch: "saved"},
	})

	if len(m.allRows) != 2 {
		t.Fatalf("unexpected merged rows: %#v", m.allRows)
	}
	for _, candidate := range m.allRows {
		if candidate.Branch == "saved duplicate" {
			t.Fatalf("live thread was duplicated: %#v", m.allRows)
		}
	}
}

func TestSavedThreadFailsWhenItsPathIsGone(t *testing.T) {
	a := &app{}
	err := a.openHistoryThread(row{
		Kind: "HIST", Session: "session-1", Target: filepath.Join(t.TempDir(), "gone"),
	}, true)

	if err == nil || !strings.Contains(err.Error(), "saved path is not available") {
		t.Fatalf("unexpected missing-path error: %v", err)
	}
}

func TestRemoteSuccessReplacesCachedRowsWithoutChangingLocalRows(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteCached: true, threadsOnly: true}
	m := model{
		app: a,
		allRows: []row{
			{Kind: "TH", Machine: "Mac", Branch: "local", Target: "w1:p1"},
			{Kind: "TH", Machine: "Ubuntu", Branch: "stale", Remote: true},
		},
	}
	data := map[string]any{
		"result": map[string]any{
			"snapshot": map[string]any{
				"agents": []any{map[string]any{
					"name":         "fresh",
					"agent_status": "idle",
					"pane_id":      "w2:p1",
				}},
			},
		},
	}

	m.applyRemoteSnapshot(data)

	if !m.app.remoteOnline || m.app.remoteCached {
		t.Fatalf("unexpected remote state: online=%v cached=%v", m.app.remoteOnline, m.app.remoteCached)
	}
	var sawLocal, sawFresh, sawStale bool
	for _, candidate := range m.allRows {
		sawLocal = sawLocal || (!candidate.Remote && candidate.Branch == "local")
		sawFresh = sawFresh || (candidate.Remote && candidate.Branch == "fresh")
		sawStale = sawStale || candidate.Branch == "stale"
	}
	if !sawLocal || !sawFresh || sawStale {
		t.Fatalf("unexpected merged rows: %#v", m.allRows)
	}
}

func TestNewThreadSelectionOpensDraftBeforeCreate(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteOnline: true}
	m := model{
		app:    a,
		rows:   []row{{Kind: "NEW", Machine: "Mac", Target: "mac", Prompt: "fix login"}},
		width:  120,
		height: 24,
	}

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	got := updated.(model)

	if cmd != nil || got.quit || got.selected != nil || got.draft == nil {
		t.Fatalf("new thread skipped configuration: %#v", got)
	}
	if got.draft.gitSpace != "worktree" || got.draft.source != "origin" {
		t.Fatalf("unexpected draft defaults: %#v", got.draft)
	}
	if !got.draft.editingTitle {
		t.Fatal("prompt composer did not open")
	}
}

func TestBlankThreadRequiresNameBeforeCreation(t *testing.T) {
	a := &app{localMachine: "Mac", root: "/work/repo"}
	m := model{app: a, rows: []row{{Kind: "NEW", Machine: "Mac"}}}

	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	if !m.draft.editingTitle || m.selected != nil {
		t.Fatal("empty title was accepted")
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("Fix checkout")})
	m = updated.(model)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	if m.selected == nil || m.selected.Prompt != "Fix checkout" {
		t.Fatalf("named thread was not created: %#v", m.selected)
	}
}

func TestPromptInputSupportsReadlineEditing(t *testing.T) {
	m := model{draft: &threadDraft{
		row:          row{Prompt: "fix checkout failure"},
		editingTitle: true,
		promptCursor: len([]rune("fix checkout failure")),
	}}

	updated, _ := m.updateThreadTitle("ctrl+w")
	m = updated.(model)
	if m.draft.row.Prompt != "fix checkout " || m.draft.promptCursor != len([]rune("fix checkout ")) {
		t.Fatalf("Ctrl-w result = %q at %d", m.draft.row.Prompt, m.draft.promptCursor)
	}
	updated, _ = m.updateThreadTitle("ctrl+y")
	m = updated.(model)
	if m.draft.row.Prompt != "fix checkout failure" {
		t.Fatalf("Ctrl-y result = %q", m.draft.row.Prompt)
	}
	updated, _ = m.updateThreadTitle("ctrl+a")
	m = updated.(model)
	updated, _ = m.updateThreadTitle("urgent ")
	m = updated.(model)
	if m.draft.row.Prompt != "urgent fix checkout failure" {
		t.Fatalf("cursor insertion result = %q", m.draft.row.Prompt)
	}
}

func TestPromptKeymapListsTerminalEditingKeys(t *testing.T) {
	m := model{
		draft:  &threadDraft{showKeymap: true},
		width:  100,
		height: 32,
	}

	view := stripANSI(m.View())
	for _, key := range []string{"Ctrl-a", "Ctrl-e", "Ctrl-w", "Alt-d", "Ctrl-k", "Ctrl-y", "Ctrl-t"} {
		if !strings.Contains(view, key) {
			t.Fatalf("keymap does not show %s", key)
		}
	}
}

func TestThreadDraftCarriesMachineSpaceSourceAndDefaultBranch(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteOnline: true}
	m := model{
		app: a,
		draft: &threadDraft{
			row:           row{Kind: "NEW", Machine: "Mac", Target: "mac", Prompt: "Test task"},
			gitSpace:      "worktree",
			source:        "origin",
			defaultBranch: "develop",
		},
	}

	m.toggleThreadDraftField(0)
	m.toggleThreadDraftField(1)
	m.toggleThreadDraftField(2)
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	got := updated.(model)

	if got.selected == nil {
		t.Fatal("draft did not create a selection")
	}
	selected := *got.selected
	if selected.Target != "ubuntu" || !selected.Remote || selected.GitSpace != "default" || selected.Source != "local" || selected.Base != "develop" {
		t.Fatalf("draft selection was not retained: %#v", selected)
	}
}

func TestThreadDraftViewUsesFullScreenLayout(t *testing.T) {
	m := model{
		app: &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteOnline: true},
		draft: &threadDraft{
			row:           row{Machine: "Mac"},
			gitSpace:      "worktree",
			source:        "origin",
			defaultBranch: "main",
			project:       "example",
		},
		width:  120,
		height: 24,
	}

	view := stripANSI(m.View())
	if !strings.Contains(view, "PROMPT") || !strings.Contains(view, "TITLE") || !strings.Contains(view, "git space") || !strings.Contains(view, "origin") {
		t.Fatalf("draft view is incomplete: %q", view)
	}
	if lines := strings.Count(view, "\n") + 1; lines != 24 {
		t.Fatalf("view uses %d lines, want 24", lines)
	}

	m.width = 80
	for index, line := range strings.Split(stripANSI(m.View()), "\n") {
		if width := len([]rune(line)); width != 80 {
			t.Fatalf("line %d uses %d columns, want 80: %q", index, width, line)
		}
	}
}

func TestRemoteRefreshKeepsWorktreesAndHidesThreads(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu"}
	m := model{
		app:     a,
		allRows: []row{{Kind: "BR", Machine: "Mac", Branch: "main"}},
	}
	data := map[string]any{
		"result": map[string]any{
			"snapshot": map[string]any{
				"workspaces": []any{map[string]any{
					"workspace_id": "w2",
					"label":        "remote-worktree",
					"repository": map[string]any{
						"checkout_path": "/work/remote-worktree",
					},
				}},
				"agents": []any{map[string]any{
					"name":         "remote-thread",
					"agent_status": "idle",
					"pane_id":      "w2:p1",
					"workspace_id": "w2",
				}},
			},
		},
	}

	m.applyRemoteSnapshot(data)

	for _, candidate := range m.allRows {
		if candidate.Kind == "TH" || candidate.Kind == "NEW" {
			t.Fatalf("thread action leaked after remote refresh: %#v", candidate)
		}
	}
	if len(m.allRows) != 2 {
		t.Fatalf("unexpected refreshed rows: %#v", m.allRows)
	}
}
