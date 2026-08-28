package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestParseArgsDefaultsToExternalCleanup(t *testing.T) {
	cfg, err := parseArgs(nil, "/Users/test")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.apply || cfg.dryRun || cfg.analyze || cfg.skipExternal || len(cfg.selected) != 0 {
		t.Fatalf("unexpected default configuration: %+v", cfg)
	}
}

func TestDefaultExternalCleanersRemainConfigured(t *testing.T) {
	want := []string{"mole", "mac-cleanup"}
	if len(defaultExternalCommands) != len(want) {
		t.Fatalf("got %d external cleaners, want %d", len(defaultExternalCommands), len(want))
	}
	for index, command := range defaultExternalCommands {
		if len(command) != 1 || command[0] != want[index] {
			t.Fatalf("external cleaner %d is %v, want [%s]", index, command, want[index])
		}
	}
}

func TestAnalyzeAndSkipExternalAreReadOnlyModes(t *testing.T) {
	for _, args := range [][]string{{"--analyze"}, {"--skip-external"}} {
		cfg, err := parseArgs(args, "/Users/test")
		if err != nil {
			t.Fatal(err)
		}
		if !cfg.analyze && !cfg.skipExternal {
			t.Fatalf("%v did not enable a read-only default mode", args)
		}
	}
}

func TestParseArgsRejectsConflictingModes(t *testing.T) {
	if _, err := parseArgs([]string{"--apply", "--dry-run"}, "/Users/test"); err == nil {
		t.Fatal("expected conflicting modes to fail")
	}
}

func TestSelectActionsRejectsUnknownAndDeduplicates(t *testing.T) {
	actions := availableActions()
	selected, err := selectActions(actions, []string{"app-caches", "app-caches"})
	if err != nil {
		t.Fatal(err)
	}
	if len(selected) != 1 {
		t.Fatalf("got %d actions, want 1", len(selected))
	}
	if _, err := selectActions(actions, []string{"delete-everything"}); err == nil {
		t.Fatal("expected unknown action to fail")
	}
}

func TestValidateTrashTarget(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "allowed")
	target := filepath.Join(root, "cache")
	mustMkdir(t, target)
	if err := validateTrashTarget(target, root); err != nil {
		t.Fatalf("valid child rejected: %v", err)
	}
	if err := validateTrashTarget(root, root); err == nil {
		t.Fatal("allowed root itself must be rejected")
	}
	sibling := filepath.Join(base, "allowed-sibling")
	mustMkdir(t, sibling)
	if err := validateTrashTarget(sibling, root); err == nil {
		t.Fatal("sibling-prefix escape must be rejected")
	}
}

func TestValidateTrashTargetRejectsSymlinkEscape(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "allowed")
	outside := filepath.Join(base, "outside")
	mustMkdir(t, root)
	mustMkdir(t, outside)
	link := filepath.Join(root, "escape")
	if err := os.Symlink(outside, link); err != nil {
		t.Fatal(err)
	}
	if err := validateTrashTarget(link, root); err == nil {
		t.Fatal("symlink escape must be rejected")
	}
}

func TestDiscoverNamedDirectoriesUsesModificationCutoffAndSkipsGit(t *testing.T) {
	root := t.TempDir()
	old := filepath.Join(root, "old-project", "node_modules")
	recent := filepath.Join(root, "recent-project", "node_modules")
	insideGit := filepath.Join(root, ".git", "node_modules")
	for _, path := range []string{old, recent, insideGit} {
		mustMkdir(t, path)
	}
	oldTime := time.Now().Add(-100 * 24 * time.Hour)
	if err := os.Chtimes(old, oldTime, oldTime); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(insideGit, oldTime, oldTime); err != nil {
		t.Fatal(err)
	}
	operations, err := discoverNamedDirectories(root, map[string]bool{"node_modules": true}, time.Now().Add(-90*24*time.Hour), map[string]bool{".git": true})
	if err != nil {
		t.Fatal(err)
	}
	if len(operations) != 1 || operations[0].path != old {
		t.Fatalf("selected %#v, want only %s", operations, old)
	}
}

func TestMaestroDiscoveryOnlySelectsChildrenOfMaestro(t *testing.T) {
	root := t.TempDir()
	wanted := filepath.Join(root, "app", ".maestro", "cache")
	unrelated := filepath.Join(root, "important", "cache")
	for _, path := range []string{wanted, unrelated} {
		mustMkdir(t, path)
		oldTime := time.Now().Add(-100 * 24 * time.Hour)
		if err := os.Chtimes(path, oldTime, oldTime); err != nil {
			t.Fatal(err)
		}
	}
	cutoff := time.Now().Add(-30 * 24 * time.Hour)
	operations, err := discoverChildrenOfNamedDirectory(root, ".maestro", map[string]bool{"cache": true}, &cutoff, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(operations) != 1 || operations[0].path != wanted {
		t.Fatalf("selected %#v, want only %s", operations, wanted)
	}
}

func TestDockerPlansNeverPruneVolumes(t *testing.T) {
	for _, action := range availableActions() {
		if !strings.HasPrefix(action.id, "docker-") {
			continue
		}
		operations, err := action.plan(config{})
		if err != nil {
			// A machine without Docker cannot expose a dangerous plan either.
			continue
		}
		for _, operation := range operations {
			if strings.Contains(strings.Join(operation.command, " "), "--volumes") {
				t.Fatalf("%s unexpectedly prunes volumes: %v", action.id, operation.command)
			}
		}
	}
}

func TestNoActionContainsLegacyDestructiveBehavior(t *testing.T) {
	for _, action := range availableActions() {
		if strings.Contains(action.id, "branch") || strings.Contains(action.id, "trash-empty") {
			t.Fatalf("unsafe legacy action remains: %s", action.id)
		}
	}
}

func mustMkdir(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatal(err)
	}
}
