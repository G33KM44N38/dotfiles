package main

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func testRows() []row {
	return []row{
		{Kind: filterStack, ID: "S#90", Target: "stack:90"},
		{Kind: filterClassic, ID: "PR #22", Target: "pr:22"},
	}
}

func press(m model, key rune) model {
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{key}})
	return updated.(model)
}

func TestFilterShortcuts(t *testing.T) {
	m := newModel(testRows())
	m = press(m, 's')
	if m.mode != filterStack || len(m.rows) != 1 || m.rows[0].Kind != filterStack {
		t.Fatalf("s filter mismatch: mode=%v rows=%v", m.mode, m.rows)
	}
	m = press(m, 'c')
	if m.mode != filterClassic || len(m.rows) != 1 || m.rows[0].Kind != filterClassic {
		t.Fatalf("c filter mismatch: mode=%v rows=%v", m.mode, m.rows)
	}
	m = press(m, 'a')
	if m.mode != filterAll || len(m.rows) != 2 {
		t.Fatalf("a filter mismatch: mode=%v rows=%v", m.mode, m.rows)
	}
}

func TestSearchKeepsShortcutLettersSearchable(t *testing.T) {
	m := newModel(testRows())
	m = press(m, '/')
	m = press(m, 's')
	if m.mode != filterAll || m.query != "s" || !m.searching {
		t.Fatalf("search mismatch: mode=%v query=%q searching=%v", m.mode, m.query, m.searching)
	}
}

func TestBuildRowsUsesNativeStackMembership(t *testing.T) {
	stack := &stackInfo{Number: 90, Position: 2}
	stack.Base.Ref = "main"
	bottom := &stackInfo{Number: 90, Position: 1}
	bottom.Base.Ref = "main"
	pulls := []pullRequest{
		{Number: 12, Title: "top", Stack: stack, UpdatedAt: "2"},
		{Number: 22, Title: "classic", UpdatedAt: "3"},
		{Number: 11, Title: "bottom", Stack: bottom, UpdatedAt: "1"},
	}
	rows := buildRows(pulls)
	if len(rows) != 2 {
		t.Fatalf("got %d rows, want 2", len(rows))
	}
	if rows[0].Kind != filterClassic || rows[0].Target != "pr:22" {
		t.Fatalf("classic row mismatch: %+v", rows[0])
	}
	if rows[1].Kind != filterStack || rows[1].Detail != "#11 -> #12" {
		t.Fatalf("stack row mismatch: %+v", rows[1])
	}
}

func TestParseGitHubSlugWithoutNetwork(t *testing.T) {
	tests := map[string]string{
		"git@github.com:owner/repo.git":       "owner/repo",
		"https://github.com/owner/repo.git":   "owner/repo",
		"ssh://git@github.com/owner/repo.git": "owner/repo",
	}
	for remote, want := range tests {
		if got := parseGitHubSlug(remote); got != want {
			t.Errorf("parseGitHubSlug(%q) = %q, want %q", remote, got, want)
		}
	}
}

func TestCurrentRowReusesFetchedPulls(t *testing.T) {
	stack := &stackInfo{Number: 90, Position: 1}
	stack.Base.Ref = "main"
	pull := pullRequest{Number: 11, Stack: stack}
	pull.Head.Ref = "stack-bottom"
	rows := buildRows([]pullRequest{pull})
	selected, ok := currentRow(rows, []pullRequest{pull}, "stack-bottom")
	if !ok || selected.Target != "stack:90" {
		t.Fatalf("current stack row mismatch: ok=%v row=%+v", ok, selected)
	}
}
