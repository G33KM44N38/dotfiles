package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type reviewHerdrRunner struct{ workspaces string }

func (r reviewHerdrRunner) Run(_ context.Context, _ string, _ string, args ...string) (string, error) {
	if args[0] == "workspace" {
		return r.workspaces, nil
	}
	if args[0] == "pane" {
		return `{"result":{"panes":[]}}`, nil
	}
	return `{"result":{"agents":[]}}`, nil
}

func TestReviewPlainWorkspaceProtection(t *testing.T) {
	path := t.TempDir()
	payload, _ := json.Marshal(map[string]any{"result": map[string]any{"workspaces": []any{map[string]any{"repository": map[string]any{"checkout_path": path}, "workspace_id": "wTest"}}}})
	a := app{runner: reviewHerdrRunner{string(payload)}}
	paths, err := a.herdrProtectedPaths(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	a.protectedPaths = paths
	if !a.isProtected(path) {
		t.Fatal("OPEN ordinary workspace is not protected")
	}
}

func TestReviewMalformedHerdrEnvelope(t *testing.T) {
	a := app{runner: reviewHerdrRunner{`{"error":{"message":"unavailable"}}`}}
	_, err := a.herdrProtectedPaths(context.Background())
	if err == nil {
		t.Fatal("error envelope accepted as empty workspace list")
	}
}

func reviewRepo(t *testing.T) (string, string) {
	root := t.TempDir()
	repo := filepath.Join(root, "source")
	runGit(t, root, "init", "-b", "main", repo)
	runGit(t, repo, "config", "user.name", "Review")
	runGit(t, repo, "config", "user.email", "review@example.invalid")
	mustWrite(t, filepath.Join(repo, "README"), "base\n")
	mustWrite(t, filepath.Join(repo, ".gitignore"), "local-data/\n")
	runGit(t, repo, "add", ".")
	runGit(t, repo, "commit", "-m", "base")
	runGit(t, repo, "update-ref", "refs/remotes/origin/main", "HEAD")
	wt := filepath.Join(root, "feature")
	runGit(t, repo, "worktree", "add", "-b", "feature", wt)
	return repo, wt
}

func TestReviewIgnoredDataSurvives(t *testing.T) {
	repo, wt := reviewRepo(t)
	local := filepath.Join(wt, "local-data")
	if err := os.Mkdir(local, 0700); err != nil {
		t.Fatal(err)
	}
	mustWrite(t, filepath.Join(local, "only-copy.txt"), "user data\n")
	a := app{cfg: config{automation: true, parallelJobs: 1}, runner: execRunner{}, out: &bytes.Buffer{}, errOut: &bytes.Buffer{}}
	planned := a.classify(context.Background(), repo, worktree{path: wt})
	result, err := a.removeSafeWorktree(context.Background(), repo, planned)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(local, "only-copy.txt")); err != nil {
		t.Fatalf("ignored user data removed: category=%s result=%s", planned.category, result)
	}
}

func TestReviewForeignRepositoryNotStale(t *testing.T) {
	repo, wt := reviewRepo(t)
	foreign := filepath.Join(filepath.Dir(repo), "other-project")
	runGit(t, filepath.Dir(repo), "init", foreign)
	var output bytes.Buffer
	a := app{cfg: config{dryRun: true, noFetch: true, parallelJobs: 1}, runner: execRunner{}, out: &output, errOut: &output}
	if err := a.runRepository(context.Background(), repo); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(output.String(), foreign) {
		t.Fatal("unrelated directory appears in cleanup plan")
	}
	_ = wt
}

func TestReviewOutsideRootExcluded(t *testing.T) {
	repo, wt := reviewRepo(t)
	a := app{runner: execRunner{}}
	repos, err := a.discoverRepositories(context.Background(), wt)
	if err != nil {
		t.Fatal(err)
	}
	a.cfg.scanRoot = wt
	got := a.classify(context.Background(), repos[0].root, worktree{path: repo, branch: "main"})
	if got.category != catKeep || got.reason != "outside scan root" {
		t.Fatalf("outside root not protected: %#v", got)
	}
}

func TestReviewRemovalFailureReturnsError(t *testing.T) {
	repo, wt := reviewRepo(t)
	runGit(t, repo, "worktree", "lock", wt)
	var output bytes.Buffer
	a := app{cfg: config{automation: true, yes: true, noFetch: true, parallelJobs: 1}, runner: execRunner{}, out: &output, errOut: &output}
	err := a.runRepository(context.Background(), repo)
	if err == nil {
		t.Fatalf("exit success despite removal failure: %s", output.String())
	}
}

func TestReviewNestedRepoDiscovered(t *testing.T) {
	repo, _ := reviewRepo(t)
	nested := filepath.Join(repo, "nested")
	runGit(t, repo, "init", nested)
	a := app{runner: execRunner{}}
	repos, err := a.discoverRepositories(context.Background(), repo)
	if err != nil {
		t.Fatal(err)
	}
	if len(repos) != 2 {
		t.Fatal(fmt.Sprintf("found %d repositories, nested repository skipped", len(repos)))
	}
}

type reviewPromptReader struct {
	started chan struct{}
	once    sync.Once
	input   io.Reader
}

func (r *reviewPromptReader) Read(p []byte) (int, error) {
	r.once.Do(func() { close(r.started) })
	return r.input.Read(p)
}

func TestReviewPromptVisibleBeforeInput(t *testing.T) {
	repo, _ := reviewRepo(t)
	input, writer := io.Pipe()
	defer writer.Close()
	reader := &reviewPromptReader{started: make(chan struct{}), input: input}
	var output bytes.Buffer
	a := app{cfg: config{scanRoot: filepath.Dir(repo), noFetch: true, parallelJobs: 1}, runner: execRunner{}, in: reader, out: &output, errOut: &output}
	done := make(chan error, 1)
	go func() { done <- a.run(context.Background()) }()
	select {
	case <-reader.started:
		hidden := output.Len() == 0
		writer.Close()
		<-done
		if hidden {
			t.Fatal("waiting for confirmation while all prompts remain in private output buffers")
		}
	case <-time.After(5 * time.Second):
		writer.Close()
		<-done
		t.Fatal("no confirmation request observed")
	}
}

func TestReviewSymlinkWorkspaceProtected(t *testing.T) {
	repo, wt := reviewRepo(t)
	alias := filepath.Join(filepath.Dir(repo), "shortcut")
	if err := os.Symlink(wt, alias); err != nil {
		t.Fatal(err)
	}
	a := app{protectedPaths: map[string]bool{alias: true}}
	if !a.isProtected(wt) {
		t.Fatal("workspace opened through symlink is not protected")
	}
}

func TestCleanMergedRemoval(t *testing.T) {
	repo, wt := reviewRepo(t)
	a := app{cfg: config{automation: true, parallelJobs: 1}, runner: execRunner{}}
	planned := a.classify(context.Background(), repo, worktree{path: wt})
	if planned.category != catSafe {
		t.Fatalf("expected removable fixture: %#v", planned)
	}
	if _, err := a.removeSafeWorktree(context.Background(), repo, planned); err != nil {
		t.Fatal(err)
	}
	if isDir(wt) {
		t.Fatal("clean merged worktree was not removed")
	}
}

func TestProtectionFailureStopsCleanup(t *testing.T) {
	a := app{cfg: config{automation: true, parallelJobs: 1}, loadProtectedPaths: func(context.Context) (map[string]bool, error) {
		return nil, errors.New("Herdr unavailable")
	}}
	if err := a.run(context.Background()); err == nil {
		t.Fatal("cleanup continued without protection data")
	}
}

func TestNewIgnoredFileAfterScanIsKept(t *testing.T) {
	repo, wt := reviewRepo(t)
	a := app{cfg: config{automation: true, parallelJobs: 1}, runner: execRunner{}}
	planned := a.classify(context.Background(), repo, worktree{path: wt})
	if err := os.Mkdir(filepath.Join(wt, "local-data"), 0700); err != nil {
		t.Fatal(err)
	}
	mustWrite(t, filepath.Join(wt, "local-data", "new.txt"), "keep\n")
	if _, err := a.removeSafeWorktree(context.Background(), repo, planned); err != nil {
		t.Fatal(err)
	}
	if !isFile(filepath.Join(wt, "local-data", "new.txt")) {
		t.Fatal("new ignored file was removed")
	}
}

func TestSyncedUnmergedWorktreeIsKeptByAutomation(t *testing.T) {
	repo, wt := reviewRepo(t)
	mustWrite(t, filepath.Join(wt, "feature.txt"), "unique\n")
	runGit(t, wt, "add", "feature.txt")
	runGit(t, wt, "commit", "-m", "unique feature")
	runGit(t, wt, "update-ref", "refs/remotes/origin/feature", "HEAD")
	a := app{cfg: config{automation: true}, runner: execRunner{}}
	got := a.classify(context.Background(), repo, worktree{path: wt})
	if got.category != catKeep || got.reason != "synced but not merged" {
		t.Fatalf("unexpected decision: %#v", got)
	}
	a.cfg.automation = false
	if got := a.classify(context.Background(), repo, worktree{path: wt}); got.category != catSafe {
		t.Fatalf("manual synced policy changed: %#v", got)
	}
}
