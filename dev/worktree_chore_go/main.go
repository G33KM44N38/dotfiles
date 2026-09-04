package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const fetchTTL = 5 * time.Minute

type config struct {
	dryRun       bool
	yes          bool
	automation   bool
	autoPull     bool
	forceFetch   bool
	noFetch      bool
	scanRoot     string
	parallelJobs int
}

type commandRunner interface {
	Run(ctx context.Context, dir string, name string, args ...string) (string, error)
}

type execRunner struct{}

func (execRunner) Run(ctx context.Context, dir string, name string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_PAGER=cat", "GIT_TERMINAL_PROMPT=0", "GIT_OPTIONAL_LOCKS=0")
	var out bytes.Buffer
	cmd.Stdout = &out
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		return out.String(), fmt.Errorf("%s %s: %w: %s", name, strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return out.String(), nil
}

type app struct {
	cfg                config
	runner             commandRunner
	in                 io.Reader
	out                io.Writer
	errOut             io.Writer
	protectedPaths     map[string]bool
	loadProtectedPaths func(context.Context) (map[string]bool, error)
	gitSemaphore       chan struct{}
}

type palette struct {
	enabled bool
}

const (
	ansiReset   = "\x1b[0m"
	ansiBold    = "\x1b[1m"
	ansiDim     = "\x1b[2m"
	ansiRed     = "\x1b[31m"
	ansiGreen   = "\x1b[32m"
	ansiYellow  = "\x1b[33m"
	ansiBlue    = "\x1b[34m"
	ansiMagenta = "\x1b[35m"
	ansiCyan    = "\x1b[36m"
)

func (p palette) paint(code, value string) string {
	if !p.enabled {
		return value
	}
	return code + value + ansiReset
}

func colorsEnabled(w io.Writer) bool {
	if os.Getenv("NO_COLOR") != "" || os.Getenv("TERM") == "dumb" {
		return false
	}
	f, ok := w.(*os.File)
	if !ok {
		return false
	}
	info, err := f.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

type worktree struct {
	path   string
	branch string
}

type repository struct {
	root string
	key  string
}

type category string

const (
	catSafe      category = "safe"
	catBehind    category = "behind"
	catUnpushed  category = "unpushed"
	catAttention category = "attention"
	catKeep      category = "keep"
)

type row struct {
	category   category
	path       string
	branch     string
	reason     string
	a          string
	b          string
	compareRef string
	head       string
}

type plan struct {
	safe      []row
	behind    []row
	unpushed  []row
	attention []row
	keep      []row
}

func main() {
	cfg, err := parseArgs(os.Args[1:], os.Getenv)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if cfg.parallelJobs == 0 {
		os.Exit(0)
	}
	a := app{
		cfg:    cfg,
		runner: execRunner{},
		in:     os.Stdin,
		out:    os.Stdout,
		errOut: os.Stderr,
	}
	a.loadProtectedPaths = a.herdrProtectedPaths
	if err := a.run(context.Background()); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func parseArgs(args []string, getenv func(string) string) (config, error) {
	cfg := config{autoPull: true}
	fs := flag.NewFlagSet("worktree-chore", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.BoolVar(&cfg.dryRun, "dry-run", false, "")
	fs.BoolVar(&cfg.dryRun, "n", false, "")
	fs.BoolVar(&cfg.yes, "yes", false, "")
	fs.BoolVar(&cfg.yes, "y", false, "")
	fs.BoolVar(&cfg.automation, "automation", false, "")
	noPull := fs.Bool("no-pull", false, "")
	fs.BoolVar(&cfg.forceFetch, "fetch", false, "")
	fs.BoolVar(&cfg.noFetch, "no-fetch", false, "")
	fs.StringVar(&cfg.scanRoot, "root", "", "")
	help := fs.Bool("help", false, "")
	shortHelp := fs.Bool("h", false, "")
	if err := fs.Parse(args); err != nil {
		return config{}, err
	}
	if *help || *shortHelp {
		printUsage(os.Stdout)
		return config{parallelJobs: 0}, nil
	}
	if cfg.forceFetch && cfg.noFetch {
		return config{}, errors.New("Error: --fetch and --no-fetch cannot be used together")
	}
	cfg.autoPull = !*noPull
	if cfg.automation {
		cfg.yes = true
		cfg.autoPull = false
	}
	jobs, err := configuredJobs(getenv)
	if err != nil {
		return config{}, err
	}
	cfg.parallelJobs = jobs
	return cfg, nil
}

func configuredJobs(getenv func(string) string) (int, error) {
	raw := getenv("WORKTREE_CHORE_JOBS")
	if raw == "" {
		raw = getenv("WORKTREE_CHORE_REMOVE_JOBS")
	}
	if raw == "" {
		n := runtime.NumCPU()
		if n > 8 {
			n = 8
		}
		if n < 1 {
			n = 1
		}
		return n, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 {
		return 0, errors.New("Error: WORKTREE_CHORE_JOBS must be a positive integer")
	}
	return n, nil
}

func printUsage(w io.Writer) {
	fmt.Fprint(w, `Usage: worktree-chore [--root PATH] [--dry-run|-n] [--yes|-y] [--fetch|--no-fetch] [--no-pull] [--help|-h]

Cleans up git worktrees:
- SAFE REMOVE: HEAD already merged into origin/main|origin/release
- MANUAL ONLY: clean branches synchronized with a remote upstream
- BEHIND: can auto pull --ff-only
- UNPUSHED: local commits not on upstream
- ATTENTION: tracked/untracked/ignored local files, diverged, detached, unreadable, no upstream
- KEEP: unique work

Options:
  --root PATH     Discover repositories below PATH; only change worktrees inside PATH
  -n, --dry-run   Show actions without changing anything
  -y, --yes       Do not ask for confirmation
  --automation    Remove only clean merged worktrees; skip pulls
  --no-pull       Do not auto pull behind branches
  --fetch         Force refreshing remote refs
  --no-fetch      Never refresh remote refs
  -h, --help      Show help

Environment:
  WORKTREE_CHORE_JOBS         Concurrent Git jobs across all repositories, default: CPU count capped at 8
  WORKTREE_CHORE_REMOVE_JOBS  Deprecated alias for WORKTREE_CHORE_JOBS

Unregistered directories are never removed. Ignored files also prevent cleanup.
Discovery skips Git internals, node_modules, .venv, and .cache directories.
Protection covers workspaces, panes, and agents in the queried Herdr session.
`)
}

func (a *app) run(ctx context.Context) error {
	if a.gitSemaphore == nil {
		a.gitSemaphore = make(chan struct{}, a.cfg.parallelJobs)
	}
	if err := a.refreshProtectedPaths(ctx); err != nil {
		return err
	}
	if a.cfg.scanRoot == "" {
		root, err := a.repoRoot(ctx)
		if err != nil {
			return err
		}
		return a.runRepository(ctx, root)
	}
	repositories, err := a.discoverRepositories(ctx, a.cfg.scanRoot)
	if err != nil {
		return err
	}
	if len(repositories) == 0 {
		return fmt.Errorf("no Git repositories found below %s", a.cfg.scanRoot)
	}
	type prepared struct {
		repo   repository
		plan   plan
		output string
		err    error
	}
	results := parallelMap(min(a.cfg.parallelJobs, len(repositories)), repositories, func(repo repository) prepared {
		var output bytes.Buffer
		child := *a
		child.out = &output
		child.errOut = &output
		pl, err := child.prepareRepository(ctx, repo.root)
		return prepared{repo, pl, output.String(), err}
	})
	var combined plan
	var failures []error
	for _, result := range results {
		fmt.Fprintf(a.out, "\n📁 Repository: %s\n%s", result.repo.root, result.output)
		if result.err != nil {
			failures = append(failures, result.err)
			fmt.Fprintln(a.errOut, result.err)
			continue
		}
		combined.safe = append(combined.safe, result.plan.safe...)
		combined.behind = append(combined.behind, result.plan.behind...)
	}
	if a.hasActions(combined) && !a.cfg.yes && !a.cfg.dryRun && !a.confirm(combined) {
		fmt.Fprintln(a.out, "Aborted.")
		return errors.Join(failures...)
	}
	for _, result := range results {
		if result.err == nil && a.hasActions(result.plan) {
			if err := a.apply(ctx, result.repo.root, result.plan); err != nil {
				failures = append(failures, err)
			}
		}
	}
	return errors.Join(failures...)
}

func (a app) hasActions(pl plan) bool {
	return len(pl.safe) > 0 || (a.cfg.autoPull && len(pl.behind) > 0)
}

func (a *app) prepareRepository(ctx context.Context, root string) (plan, error) {
	mode := "LIVE"
	if a.cfg.dryRun {
		mode = "DRY-RUN"
	}
	fmt.Fprintf(a.out, "🧹 worktree cleanup (mode: %s)\n", mode)
	if err := a.refreshRemotes(ctx, root); err != nil {
		return plan{}, fmt.Errorf("%s: remote refresh failed; refusing cleanup: %w", root, err)
	}
	trees, err := a.listWorktrees(ctx, root)
	if err != nil {
		return plan{}, err
	}
	pl := a.classifyAll(ctx, root, trees)
	renderPlan(a.out, pl, palette{enabled: colorsEnabled(a.out)})
	if !a.hasActions(pl) {
		fmt.Fprintln(a.out, "✓ Nothing to do automatically.")
	}
	return pl, nil
}

func (a *app) runRepository(ctx context.Context, root string) error {
	pl, err := a.prepareRepository(ctx, root)
	if err != nil || !a.hasActions(pl) {
		return err
	}
	if !a.cfg.yes && !a.cfg.dryRun && !a.confirm(pl) {
		fmt.Fprintln(a.out, "Aborted.")
		return nil
	}
	return a.apply(ctx, root, pl)
}

func (a app) refreshRemotes(ctx context.Context, repoRoot string) error {
	if a.cfg.noFetch {
		fmt.Fprintln(a.out, "🌐 Using cached remote refs (--no-fetch)")
		return nil
	}
	age, fresh := a.fetchAge(ctx, repoRoot)
	if !a.cfg.forceFetch && fresh && age < fetchTTL {
		fmt.Fprintf(a.out, "🌐 Using remote refs updated %s ago\n", age.Round(time.Second))
		return nil
	}
	fmt.Fprintln(a.out, "🌐 Refreshing remote refs...")
	args := []string{"fetch", "--all", "--prune"}
	if a.cfg.dryRun {
		args = append(args, "--dry-run")
	}
	if _, err := a.git(ctx, repoRoot, args...); err != nil {
		return err
	}
	return nil
}

func (a app) fetchAge(ctx context.Context, repoRoot string) (time.Duration, bool) {
	commonDir, err := a.git(ctx, repoRoot, "rev-parse", "--path-format=absolute", "--git-common-dir")
	if err != nil {
		return 0, false
	}
	info, err := os.Stat(filepath.Join(strings.TrimSpace(commonDir), "FETCH_HEAD"))
	if err != nil {
		return 0, false
	}
	age := time.Since(info.ModTime())
	if age < 0 {
		age = 0
	}
	return age, true
}

func (a *app) refreshProtectedPaths(ctx context.Context) error {
	if a.loadProtectedPaths == nil {
		return nil
	}
	paths, err := a.loadProtectedPaths(ctx)
	if err != nil {
		return fmt.Errorf("cannot read active Herdr workspaces; refusing cleanup: %w", err)
	}
	a.protectedPaths = paths
	return nil
}

func (a app) herdrProtectedPaths(ctx context.Context) (map[string]bool, error) {
	herdr, err := findHerdr()
	if err != nil {
		return nil, err
	}
	paths := map[string]bool{}
	for _, group := range []string{"workspace", "pane", "agent"} {
		raw, err := a.runner.Run(ctx, "", herdr, group, "list")
		if err != nil {
			return nil, err
		}
		var envelope struct {
			Result map[string]json.RawMessage `json:"result"`
			Error  json.RawMessage            `json:"error"`
		}
		if err := json.Unmarshal([]byte(raw), &envelope); err != nil {
			return nil, fmt.Errorf("parse Herdr %s: %w", group, err)
		}
		data, exists := envelope.Result[group+"s"]
		if !exists || string(data) == "null" || (len(envelope.Error) > 0 && string(envelope.Error) != "null") {
			return nil, fmt.Errorf("invalid Herdr %s list response", group)
		}
		var records []struct {
			CWD           string `json:"cwd"`
			ForegroundCWD string `json:"foreground_cwd"`
			Worktree      struct {
				CheckoutPath string `json:"checkout_path"`
			} `json:"worktree"`
			Repository struct {
				CheckoutPath string `json:"checkout_path"`
			} `json:"repository"`
		}
		if err := json.Unmarshal(data, &records); err != nil {
			return nil, fmt.Errorf("parse Herdr %s records: %w", group, err)
		}
		for _, record := range records {
			for _, path := range []string{record.CWD, record.ForegroundCWD, record.Worktree.CheckoutPath, record.Repository.CheckoutPath} {
				addProtectedPath(paths, path)
			}
		}
	}
	return paths, nil
}

func findHerdr() (string, error) {
	for _, candidate := range []string{"/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"} {
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate, nil
		}
	}
	return exec.LookPath("herdr")
}

func addProtectedPath(paths map[string]bool, path string) {
	if path != "" {
		paths[canonicalPath(path)] = true
	}
}

func (a app) isProtected(path string) bool {
	clean := canonicalPath(path)
	for protected := range a.protectedPaths {
		rel, err := filepath.Rel(clean, canonicalPath(protected))
		if err == nil && (rel == "." || (!filepath.IsAbs(rel) && rel != ".." && !strings.HasPrefix(rel, ".."+string(os.PathSeparator)))) {
			return true
		}
	}
	return false
}

func canonicalPath(path string) string {
	if absolute, err := filepath.Abs(path); err == nil {
		path = absolute
	}
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		path = resolved
	}
	return filepath.Clean(path)
}

func withinRoot(root, path string) bool {
	rel, err := filepath.Rel(canonicalPath(root), canonicalPath(path))
	return err == nil && rel != ".." && !filepath.IsAbs(rel) && !strings.HasPrefix(rel, ".."+string(os.PathSeparator))
}

func (a app) discoverRepositories(ctx context.Context, root string) ([]repository, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	info, err := os.Stat(root)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("Error: scan root is not a directory: %s", root)
	}

	byKey := map[string]repository{}
	err = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if !entry.IsDir() {
			return nil
		}
		if path != root {
			switch entry.Name() {
			case ".git", "node_modules", ".venv", ".cache":
				return filepath.SkipDir
			}
		}
		if !isRepositoryCandidate(path) {
			return nil
		}
		commonDir, err := a.git(ctx, path, "rev-parse", "--path-format=absolute", "--git-common-dir")
		if err != nil {
			return nil
		}
		key := filepath.Clean(strings.TrimSpace(commonDir))
		if resolved, err := filepath.EvalSymlinks(key); err == nil {
			key = resolved
		}
		if _, exists := byKey[key]; !exists {
			byKey[key] = repository{root: key, key: key}
		}
		if isFile(filepath.Join(path, "HEAD")) && isDir(filepath.Join(path, "objects")) {
			return filepath.SkipDir
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	repositories := make([]repository, 0, len(byKey))
	for _, repo := range byKey {
		repositories = append(repositories, repo)
	}
	sort.Slice(repositories, func(i, j int) bool { return repositories[i].root < repositories[j].root })
	return repositories, nil
}

func isRepositoryCandidate(path string) bool {
	if _, err := os.Lstat(filepath.Join(path, ".git")); err == nil {
		return true
	}
	return isFile(filepath.Join(path, "HEAD")) && isDir(filepath.Join(path, "objects")) && isDir(filepath.Join(path, "refs"))
}

func isFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func (a app) repoRoot(ctx context.Context) (string, error) {
	insideWorktree, err := a.git(ctx, "", "rev-parse", "--is-inside-work-tree")
	if err != nil {
		return "", errors.New("Error: run inside a git repository/worktree or bare git repository")
	}
	if strings.TrimSpace(insideWorktree) == "true" {
		root, err := a.git(ctx, "", "rev-parse", "--path-format=absolute", "--show-toplevel")
		if err != nil {
			return "", err
		}
		return strings.TrimSpace(root), nil
	}

	bareRepo, err := a.git(ctx, "", "rev-parse", "--is-bare-repository")
	if err == nil && strings.TrimSpace(bareRepo) == "true" {
		gitDir, err := a.git(ctx, "", "rev-parse", "--path-format=absolute", "--git-dir")
		if err != nil {
			return "", err
		}
		return strings.TrimSpace(gitDir), nil
	}

	return "", errors.New("Error: run inside a git repository/worktree or bare git repository")
}

func (a app) git(ctx context.Context, dir string, args ...string) (string, error) {
	if a.gitSemaphore != nil {
		select {
		case a.gitSemaphore <- struct{}{}:
		case <-ctx.Done():
			return "", ctx.Err()
		}
		defer func() { <-a.gitSemaphore }()
	}
	return a.runner.Run(ctx, dir, "git", args...)
}

func (a app) listWorktrees(ctx context.Context, repoRoot string) ([]worktree, error) {
	out, err := a.git(ctx, repoRoot, "worktree", "list", "--porcelain")
	if err != nil {
		return nil, err
	}
	return parseWorktrees(out), nil
}

func parseWorktrees(input string) []worktree {
	var trees []worktree
	var path string
	scanner := bufio.NewScanner(strings.NewReader(input))
	for scanner.Scan() {
		line := scanner.Text()
		switch {
		case strings.HasPrefix(line, "worktree "):
			path = strings.TrimPrefix(line, "worktree ")
		case line == "bare":
			path = ""
		case strings.HasPrefix(line, "branch "):
			if path == "" {
				continue
			}
			branch := strings.TrimPrefix(line, "branch ")
			branch = strings.TrimPrefix(branch, "refs/heads/")
			branch = strings.TrimPrefix(branch, "refs/remotes/")
			trees = append(trees, worktree{path: path, branch: branch})
		case line == "detached" || strings.HasPrefix(line, "detached "):
			if path != "" {
				trees = append(trees, worktree{path: path, branch: "(detached)"})
			}
		}
	}
	return trees
}

func (a app) classifyAll(ctx context.Context, repoRoot string, trees []worktree) plan {
	rows := make([]row, len(trees))
	var wg sync.WaitGroup
	for i, wt := range trees {
		i, wt := i, wt
		wg.Add(1)
		go func() {
			defer wg.Done()
			rows[i] = a.classify(ctx, repoRoot, wt)
		}()
	}
	wg.Wait()
	var pl plan
	for _, r := range rows {
		if r.category == "" {
			continue
		}
		pl.add(r)
	}
	return pl
}

func (p *plan) add(r row) {
	switch r.category {
	case catSafe:
		p.safe = append(p.safe, r)
	case catBehind:
		p.behind = append(p.behind, r)
	case catUnpushed:
		p.unpushed = append(p.unpushed, r)
	case catAttention:
		p.attention = append(p.attention, r)
	case catKeep:
		p.keep = append(p.keep, r)
	}
}

func (a app) classify(ctx context.Context, repoRoot string, wt worktree) row {
	if wt.path == "" || !isDir(wt.path) {
		return row{}
	}
	if a.cfg.scanRoot != "" && !withinRoot(a.cfg.scanRoot, wt.path) {
		return row{category: catKeep, path: wt.path, branch: wt.branch, reason: "outside scan root"}
	}
	if _, err := a.git(ctx, wt.path, "rev-parse", "--git-dir"); err != nil {
		return row{category: catAttention, path: wt.path, branch: wt.branch, reason: "unreadable"}
	}
	branchOut, err := a.git(ctx, wt.path, "rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		return row{category: catAttention, path: wt.path, branch: wt.branch, reason: "unreadable"}
	}
	branch := strings.TrimSpace(branchOut)
	if branch == "" || branch == "HEAD" {
		return row{category: catAttention, path: wt.path, branch: "(detached)", reason: "detached"}
	}
	defaultRef, _ := a.git(ctx, repoRoot, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
	if branch == "main" || branch == "release" || branch == "master" || strings.TrimSpace(defaultRef) == "refs/remotes/origin/"+branch {
		return row{category: catKeep, path: wt.path, branch: branch, reason: "protected"}
	}
	if a.isProtected(wt.path) {
		return row{category: catKeep, path: wt.path, branch: branch, reason: "active_workspace"}
	}
	headOut, err := a.git(ctx, wt.path, "rev-parse", "HEAD")
	if err != nil {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "unreadable"}
	}
	head := strings.TrimSpace(headOut)
	status, err := a.git(ctx, wt.path, "status", "--porcelain", "--untracked-files=all", "--ignored=matching")
	if err != nil {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "unreadable"}
	}
	hasLocalChanges := strings.TrimSpace(status) != ""
	if hasLocalChanges {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "local_changes", head: head}
	}
	mergedInto := ""
	for _, target := range []string{"main", "release"} {
		if _, err := a.git(ctx, repoRoot, "show-ref", "--verify", "--quiet", "refs/remotes/origin/"+target); err == nil {
			if _, err := a.git(ctx, wt.path, "merge-base", "--is-ancestor", "HEAD", "origin/"+target); err == nil {
				mergedInto = target
				break
			}
		}
	}
	if mergedInto != "" {
		return row{category: catSafe, path: wt.path, branch: branch, reason: "merged", a: mergedInto, head: head}
	}
	upstream, _ := a.git(ctx, wt.path, "rev-parse", "--symbolic-full-name", "@{upstream}")
	compareRef := strings.TrimSpace(upstream)
	if compareRef != "" && !strings.HasPrefix(compareRef, "refs/remotes/") {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "upstream is not a remote branch"}
	}
	if compareRef == "" {
		if _, err := a.git(ctx, repoRoot, "show-ref", "--verify", "--quiet", "refs/remotes/origin/"+branch); err == nil {
			compareRef = "origin/" + branch
		}
	}
	ahead, behind := 0, 0
	if compareRef != "" {
		ahead, err = a.revCount(ctx, wt.path, compareRef+"..HEAD")
		if err != nil {
			return row{category: catAttention, path: wt.path, branch: branch, reason: "unreadable", head: head}
		}
		behind, err = a.revCount(ctx, wt.path, "HEAD.."+compareRef)
		if err != nil {
			return row{category: catAttention, path: wt.path, branch: branch, reason: "unreadable", head: head}
		}
	}
	if compareRef == "" {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "no_upstream"}
	}
	if ahead > 0 && behind > 0 {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "diverged", a: strconv.Itoa(ahead), b: strconv.Itoa(behind), compareRef: compareRef}
	}
	if ahead > 0 {
		return row{category: catUnpushed, path: wt.path, branch: branch, reason: "unpushed", a: strconv.Itoa(ahead), compareRef: compareRef}
	}
	if behind > 0 {
		return row{category: catBehind, path: wt.path, branch: branch, reason: "behind", a: strconv.Itoa(behind), compareRef: compareRef, head: head}
	}
	if a.cfg.automation {
		return row{category: catKeep, path: wt.path, branch: branch, reason: "synced but not merged"}
	}
	return row{category: catSafe, path: wt.path, branch: branch, reason: "synced_clean", a: compareRef, head: head}
}

func (a app) revCount(ctx context.Context, dir, revspec string) (int, error) {
	out, err := a.git(ctx, dir, "rev-list", "--count", revspec)
	if err != nil {
		return 0, err
	}
	n, err := strconv.Atoi(strings.TrimSpace(out))
	if err != nil {
		return 0, err
	}
	return n, nil
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func renderPlan(w io.Writer, pl plan, p palette) {
	if len(pl.safe) > 0 {
		fmt.Fprintln(w, p.paint(ansiBold+ansiGreen, "✅ SAFE TO REMOVE"))
		for _, r := range pl.safe {
			switch r.reason {
			case "merged":
				fmt.Fprintf(w, "  • %s  (merged into origin/%s)\n", r.branch, r.a)
			case "synced_clean":
				fmt.Fprintf(w, "  • %s  (clean and synced with %s)\n", r.branch, valueOr(r.a, "upstream"))
			default:
				fmt.Fprintf(w, "  • %s\n", r.branch)
			}
			fmt.Fprintf(w, "    %s\n", p.paint(ansiDim, r.path))
		}
		fmt.Fprintln(w)
	}
	if len(pl.behind) > 0 {
		fmt.Fprintln(w, p.paint(ansiBold+ansiBlue, "🔄 BEHIND (can pull --ff-only)"))
		for _, r := range pl.behind {
			fmt.Fprintf(w, "  • %s  (%s behind %s)\n", r.branch, r.a, valueOr(r.compareRef, "upstream"))
			fmt.Fprintf(w, "    %s\n", p.paint(ansiDim, r.path))
		}
		fmt.Fprintln(w)
	}
	if len(pl.unpushed) > 0 {
		fmt.Fprintln(w, p.paint(ansiBold+ansiYellow, "📤 UNPUSHED COMMITS"))
		for _, r := range pl.unpushed {
			fmt.Fprintf(w, "  • %s  (%s commit(s) not pushed to %s)\n", r.branch, r.a, valueOr(r.compareRef, "upstream"))
			fmt.Fprintf(w, "    %s\n", p.paint(ansiDim, r.path))
		}
		fmt.Fprintln(w)
	}
	if len(pl.attention) > 0 {
		fmt.Fprintln(w, p.paint(ansiBold+ansiRed, "⚠️  ATTENTION (manual review)"))
		for _, r := range pl.attention {
			switch r.reason {
			case "local_changes":
				fmt.Fprintf(w, "  • %s  (local changes: tracked/staged/untracked/ignored)\n", r.branch)
			case "diverged":
				fmt.Fprintf(w, "  • %s  (diverged from %s: %s ahead, %s behind)\n", r.branch, valueOr(r.compareRef, "upstream"), r.a, r.b)
			case "detached":
				fmt.Fprintln(w, "  • (detached)")
			case "unreadable":
				fmt.Fprintf(w, "  • %s  (cannot read path)\n", r.branch)
			case "no_upstream":
				fmt.Fprintf(w, "  • %s  (no upstream configured / remote-tracking ref missing)\n", r.branch)
			default:
				fmt.Fprintf(w, "  • %s  (%s)\n", r.branch, r.reason)
			}
			fmt.Fprintf(w, "    %s\n", p.paint(ansiDim, r.path))
		}
		fmt.Fprintln(w)
	}
	if len(pl.keep) > 0 {
		fmt.Fprintln(w, p.paint(ansiBold+ansiCyan, "ℹ️  KEEP"))
		for _, r := range pl.keep {
			if r.reason == "protected" {
				fmt.Fprintf(w, "  • %s  (protected)\n", r.branch)
			} else if r.reason == "active_workspace" {
				fmt.Fprintf(w, "  • %s  (open in Herdr / active agent)\n", r.branch)
			} else {
				fmt.Fprintf(w, "  • %s  (%s)\n", r.branch, r.reason)
			}
			fmt.Fprintf(w, "    %s\n", p.paint(ansiDim, r.path))
		}
		fmt.Fprintln(w)
	}
}

func valueOr(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func (a app) confirm(pl plan) bool {
	fmt.Fprintln(a.out, "Ready to:")
	if len(pl.safe) > 0 {
		fmt.Fprintf(a.out, "  • remove %d worktree(s)\n", len(pl.safe))
	}
	if len(pl.behind) > 0 && a.cfg.autoPull {
		fmt.Fprintf(a.out, "  • pull %d worktree(s)\n", len(pl.behind))
	}
	fmt.Fprintln(a.out)
	fmt.Fprint(a.out, "Proceed? [y/N] ")
	scanner := bufio.NewScanner(a.in)
	if !scanner.Scan() {
		return false
	}
	ans := strings.ToLower(strings.TrimSpace(scanner.Text()))
	return ans == "y" || ans == "yes"
}

func (a *app) apply(ctx context.Context, root string, pl plan) error {
	var failures []error
	for _, r := range pl.safe {
		if a.cfg.dryRun {
			fmt.Fprintf(a.out, "[DRY RUN] revalidate, then git worktree remove %q\n", r.path)
			continue
		}
		message, err := a.removeSafeWorktree(ctx, root, r)
		fmt.Fprintln(a.out, message)
		if err != nil {
			failures = append(failures, err)
		}
	}
	if a.cfg.autoPull {
		for _, r := range pl.behind {
			if a.cfg.dryRun {
				fmt.Fprintf(a.out, "[DRY RUN] git -C %q pull --ff-only\n", r.path)
				continue
			}
			if err := a.refreshProtectedPaths(ctx); err != nil {
				failures = append(failures, err)
				continue
			}
			current := a.classify(ctx, root, worktree{path: r.path, branch: r.branch})
			if current.category != catBehind || current.branch != r.branch || current.head != r.head {
				fmt.Fprintf(a.out, "Skipped %s: worktree changed or became active.\n", r.branch)
				continue
			}
			if _, err := a.git(ctx, r.path, "pull", "--ff-only"); err != nil {
				failures = append(failures, err)
			}
		}
	}
	// Do not prune unrelated registration records outside the selected scope.
	return errors.Join(failures...)
}

func (a *app) removeSafeWorktree(ctx context.Context, root string, planned row) (string, error) {
	if err := a.refreshProtectedPaths(ctx); err != nil {
		return "Cleanup stopped: protection check failed.", err
	}
	current := a.classify(ctx, root, worktree{path: planned.path, branch: planned.branch})
	if current.category != catSafe || current.branch != planned.branch || current.head == "" || current.head != planned.head {
		return fmt.Sprintf("Skipped %s: worktree changed or became active.", planned.branch), nil
	}
	if _, err := a.git(ctx, root, "worktree", "remove", planned.path); err != nil {
		return fmt.Sprintf("Failed to remove %s safely.", planned.branch), err
	}
	if _, err := a.git(ctx, root, "branch", "-d", planned.branch); err != nil {
		return fmt.Sprintf("Removed worktree %s, but kept its branch.", planned.branch), err
	}
	return fmt.Sprintf("Removed %s.", planned.branch), nil
}

func parallelMap[T, R any](jobs int, items []T, fn func(T) R) []R {
	out := make([]R, len(items))
	sem := make(chan struct{}, jobs)
	var wg sync.WaitGroup
	for i, item := range items {
		i, item := i, item
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			out[i] = fn(item)
		}()
	}
	wg.Wait()
	return out
}
