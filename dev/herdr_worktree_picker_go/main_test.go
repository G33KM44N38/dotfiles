package main

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
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

func TestQuestionCreatesPromptRowsWhenNoThreadMatches(t *testing.T) {
	a := &app{localMachine: "Mac", remoteMachine: "Ubuntu", remoteOnline: true}
	m := model{
		app: a,
		allRows: []row{{
			Kind: "TH", Machine: "Mac", Branch: "login bug", Session: "session-1",
		}},
		query: "why does checkout fail",
	}

	m.applyFilter(true)

	if len(m.rows) != 2 {
		t.Fatalf("got %d rows, want one create row per online machine", len(m.rows))
	}
	for _, created := range m.rows {
		if created.Kind != "NEW" || created.Prompt != "why does checkout fail" {
			t.Fatalf("unexpected create row: %#v", created)
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
	var sawLocal, sawFresh, sawStale, sawRemoteNew bool
	for _, candidate := range m.allRows {
		sawLocal = sawLocal || (!candidate.Remote && candidate.Branch == "local")
		sawFresh = sawFresh || (candidate.Remote && candidate.Branch == "fresh")
		sawStale = sawStale || candidate.Branch == "stale"
		sawRemoteNew = sawRemoteNew || (candidate.Remote && candidate.Kind == "NEW")
	}
	if !sawLocal || !sawFresh || sawStale || !sawRemoteNew {
		t.Fatalf("unexpected merged rows: %#v", m.allRows)
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
