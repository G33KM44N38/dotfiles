package main

import "testing"

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
