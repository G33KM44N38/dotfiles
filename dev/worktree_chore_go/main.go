package main

import (
	"bufio"
	"bytes"
	"context"
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
)

type config struct {
	dryRun       bool
	yes          bool
	autoPull     bool
	parallelJobs int
}

type commandRunner interface {
	Run(ctx context.Context, dir string, name string, args ...string) (string, error)
}

type execRunner struct{}

func (execRunner) Run(ctx context.Context, dir string, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_PAGER=cat")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	return out.String(), err
}

type app struct {
	cfg    config
	runner commandRunner
	in     io.Reader
	out    io.Writer
	errOut io.Writer
}

type worktree struct {
	path   string
	branch string
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
}

type plan struct {
	safe      []row
	staleDirs []row
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
	noPull := fs.Bool("no-pull", false, "")
	help := fs.Bool("help", false, "")
	shortHelp := fs.Bool("h", false, "")
	if err := fs.Parse(args); err != nil {
		return config{}, err
	}
	if *help || *shortHelp {
		printUsage(os.Stdout)
		return config{parallelJobs: 0}, nil
	}
	cfg.autoPull = !*noPull
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
	fmt.Fprint(w, `Usage: worktree-cleanup.sh [--dry-run|-n] [--yes|-y] [--no-pull] [--help|-h]

Cleans up git worktrees:
- SAFE REMOVE: HEAD already merged into origin/main|origin/release
- BEHIND: can auto pull --rebase
- UNPUSHED: local commits not on upstream
- ATTENTION: uncommitted/untracked, diverged, detached, unreadable, no upstream
- KEEP: unique work

Options:
  -n, --dry-run   Show actions without changing anything
  -y, --yes       Do not ask for confirmation
  --no-pull       Do not auto pull behind branches
  -h, --help      Show help

Environment:
  WORKTREE_CHORE_JOBS         Parallel scan/action jobs, default: CPU count capped at 8
  WORKTREE_CHORE_REMOVE_JOBS  Deprecated alias for WORKTREE_CHORE_JOBS
`)
}

func (a app) run(ctx context.Context) error {
	repoRoot, err := a.repoRoot(ctx)
	if err != nil {
		return err
	}
	mode := "LIVE"
	if a.cfg.dryRun {
		mode = "DRY-RUN"
	}
	fmt.Fprintf(a.out, "🧹 worktree cleanup  (mode: %s)\n", mode)
	if a.cfg.dryRun {
		_, _ = a.git(ctx, repoRoot, "fetch", "--all", "--prune", "--dry-run")
	} else {
		_, _ = a.git(ctx, repoRoot, "fetch", "--all", "--prune")
	}
	trees, err := a.listWorktrees(ctx, repoRoot)
	if err != nil {
		return err
	}
	fmt.Fprintf(a.out, "🔎 Scanning worktrees (parallel jobs: %d)...\n", a.cfg.parallelJobs)
	pl := a.classifyAll(ctx, repoRoot, trees)
	pl.staleDirs = findStaleDirs(trees)
	fmt.Fprintln(a.out)
	renderPlan(a.out, pl)
	if len(pl.safe) == 0 && len(pl.staleDirs) == 0 && len(pl.behind) == 0 {
		fmt.Fprintln(a.out, "✓ Nothing to do automatically.")
		return nil
	}
	if !a.cfg.yes && !a.cfg.dryRun {
		if !a.confirm(pl) {
			fmt.Fprintln(a.out, "Aborted.")
			return nil
		}
	}
	a.apply(ctx, repoRoot, pl)
	if a.cfg.dryRun {
		fmt.Fprintln(a.out, "[DRY RUN] git worktree prune")
	} else {
		_, _ = a.git(ctx, repoRoot, "worktree", "prune")
	}
	fmt.Fprintln(a.out, "✓ Done.")
	return nil
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
	sem := make(chan struct{}, a.cfg.parallelJobs)
	var wg sync.WaitGroup
	for i, wt := range trees {
		i, wt := i, wt
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
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
	if _, err := a.git(ctx, wt.path, "rev-parse", "--git-dir"); err != nil {
		return row{category: catAttention, path: wt.path, branch: wt.branch, reason: "unreadable"}
	}
	branchOut, _ := a.git(ctx, wt.path, "rev-parse", "--abbrev-ref", "HEAD")
	branch := strings.TrimSpace(branchOut)
	if branch == "" || branch == "HEAD" {
		return row{category: catAttention, path: wt.path, branch: "(detached)", reason: "detached"}
	}
	if branch == "main" || branch == "release" {
		return row{category: catKeep, path: wt.path, branch: branch, reason: "protected"}
	}
	status, _ := a.git(ctx, wt.path, "status", "--porcelain", "--untracked-files=normal")
	hasLocalChanges := strings.TrimSpace(status) != ""
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
		reason := "merged"
		if hasLocalChanges {
			reason = "merged_with_local_changes"
		}
		return row{category: catSafe, path: wt.path, branch: branch, reason: reason, a: mergedInto}
	}
	if hasLocalChanges {
		return row{category: catAttention, path: wt.path, branch: branch, reason: "local_changes"}
	}
	upstream, _ := a.git(ctx, wt.path, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
	compareRef := strings.TrimSpace(upstream)
	if compareRef == "" {
		if _, err := a.git(ctx, repoRoot, "show-ref", "--verify", "--quiet", "refs/remotes/origin/"+branch); err == nil {
			compareRef = "origin/" + branch
		}
	}
	ahead, behind := 0, 0
	if compareRef != "" {
		ahead = a.revCount(ctx, wt.path, compareRef+"..HEAD")
		behind = a.revCount(ctx, wt.path, "HEAD.."+compareRef)
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
		return row{category: catBehind, path: wt.path, branch: branch, reason: "behind", a: strconv.Itoa(behind), compareRef: compareRef}
	}
	return row{category: catSafe, path: wt.path, branch: branch, reason: "synced_clean", a: compareRef}
}

func (a app) revCount(ctx context.Context, dir, revspec string) int {
	out, err := a.git(ctx, dir, "rev-list", "--count", revspec)
	if err != nil {
		return 0
	}
	n, err := strconv.Atoi(strings.TrimSpace(out))
	if err != nil {
		return 0
	}
	return n
}

func findStaleDirs(trees []worktree) []row {
	registered := map[string]bool{}
	parents := map[string]int{}
	scanSet := map[string]bool{}
	for _, wt := range trees {
		if wt.path == "" {
			continue
		}
		clean := filepath.Clean(wt.path)
		registered[clean] = true
		parents[filepath.Dir(clean)]++
		for _, dir := range conventionalWorktreeDirs(clean) {
			scanSet[dir] = true
		}
	}

	var scanParents []string
	for parent, count := range parents {
		if count > 1 && !isSystemTempDir(parent) {
			scanSet[parent] = true
		}
	}
	for parent := range scanSet {
		scanParents = append(scanParents, parent)
	}
	sort.Strings(scanParents)

	var stale []row
	for _, parent := range scanParents {
		entries, err := os.ReadDir(parent)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			path := filepath.Clean(filepath.Join(parent, entry.Name()))
			if registered[path] || containsRegisteredWorktree(path, registered) {
				continue
			}
			stale = append(stale, row{path: path, branch: entry.Name(), reason: "not_registered"})
		}
	}
	return stale
}

func conventionalWorktreeDirs(path string) []string {
	sep := string(os.PathSeparator)
	marker := sep + "worktrees" + sep
	idx := strings.Index(path, marker)
	if idx < 0 {
		return nil
	}
	root := path[:idx+len(marker)-1]
	return []string{
		filepath.Join(root, "branches"),
		filepath.Join(root, "threads"),
	}
}

func isSystemTempDir(path string) bool {
	clean := filepath.Clean(path)
	for _, temp := range []string{os.TempDir(), "/tmp", "/private/tmp", "/var/tmp", "/private/var/tmp"} {
		if clean == filepath.Clean(temp) {
			return true
		}
	}
	return false
}

func containsRegisteredWorktree(path string, registered map[string]bool) bool {
	prefix := path + string(os.PathSeparator)
	for wtPath := range registered {
		if strings.HasPrefix(wtPath, prefix) {
			return true
		}
	}
	return false
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func renderPlan(w io.Writer, pl plan) {
	if len(pl.safe) > 0 {
		fmt.Fprintln(w, "✅ SAFE TO REMOVE")
		for _, r := range pl.safe {
			switch r.reason {
			case "merged":
				fmt.Fprintf(w, "  • %s  (merged into origin/%s)\n", r.branch, r.a)
			case "merged_with_local_changes":
				fmt.Fprintf(w, "  • %s  (merged into origin/%s; local changes will be discarded)\n", r.branch, r.a)
			case "synced_clean":
				fmt.Fprintf(w, "  • %s  (clean and synced with %s)\n", r.branch, valueOr(r.a, "upstream"))
			default:
				fmt.Fprintf(w, "  • %s\n", r.branch)
			}
			fmt.Fprintf(w, "    %s\n", r.path)
		}
		fmt.Fprintln(w)
	}
	if len(pl.staleDirs) > 0 {
		fmt.Fprintln(w, "🧽 STALE DIRECTORIES")
		for _, r := range pl.staleDirs {
			fmt.Fprintf(w, "  • %s  (not registered as a git worktree)\n", r.branch)
			fmt.Fprintf(w, "    %s\n", r.path)
		}
		fmt.Fprintln(w)
	}
	if len(pl.behind) > 0 {
		fmt.Fprintln(w, "🔄 BEHIND (can pull --rebase)")
		for _, r := range pl.behind {
			fmt.Fprintf(w, "  • %s  (%s behind %s)\n", r.branch, r.a, valueOr(r.compareRef, "upstream"))
			fmt.Fprintf(w, "    %s\n", r.path)
		}
		fmt.Fprintln(w)
	}
	if len(pl.unpushed) > 0 {
		fmt.Fprintln(w, "📤 UNPUSHED COMMITS")
		for _, r := range pl.unpushed {
			fmt.Fprintf(w, "  • %s  (%s commit(s) not pushed to %s)\n", r.branch, r.a, valueOr(r.compareRef, "upstream"))
			fmt.Fprintf(w, "    %s\n", r.path)
		}
		fmt.Fprintln(w)
	}
	if len(pl.attention) > 0 {
		fmt.Fprintln(w, "⚠️  ATTENTION (manual review)")
		for _, r := range pl.attention {
			switch r.reason {
			case "local_changes":
				fmt.Fprintf(w, "  • %s  (local changes: tracked/staged/untracked)\n", r.branch)
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
			fmt.Fprintf(w, "    %s\n", r.path)
		}
		fmt.Fprintln(w)
	}
	if len(pl.keep) > 0 {
		fmt.Fprintln(w, "ℹ️  KEEP")
		for _, r := range pl.keep {
			if r.reason == "protected" {
				fmt.Fprintf(w, "  • %s  (protected)\n", r.branch)
			} else {
				fmt.Fprintf(w, "  • %s  (%s)\n", r.branch, r.reason)
			}
			fmt.Fprintf(w, "    %s\n", r.path)
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
	if len(pl.staleDirs) > 0 {
		fmt.Fprintf(a.out, "  • remove %d stale directories\n", len(pl.staleDirs))
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

func (a app) apply(ctx context.Context, repoRoot string, pl plan) {
	if len(pl.safe) > 0 {
		fmt.Fprintln(a.out, "🗑️  Removing safe worktrees...")
		if a.cfg.dryRun {
			for _, r := range pl.safe {
				fmt.Fprintf(a.out, "  [DRY RUN] git worktree remove --force %q\n", r.path)
				fmt.Fprintf(a.out, "  [DRY RUN] git branch -d %q\n", r.branch)
			}
		} else {
			fmt.Fprintf(a.out, "  parallel jobs: %d\n", a.cfg.parallelJobs)
			lines := parallelMap(a.cfg.parallelJobs, pl.safe, func(r row) string {
				if _, err := a.git(ctx, repoRoot, "worktree", "remove", "--force", r.path); err == nil {
					_, _ = a.git(ctx, repoRoot, "branch", "-d", r.branch)
					return fmt.Sprintf("  ✓ removed %s", r.branch)
				}
				return fmt.Sprintf("  ⚠️  failed to remove %s", r.branch)
			})
			for _, line := range lines {
				fmt.Fprintln(a.out, line)
			}
		}
		fmt.Fprintln(a.out)
	}
	if len(pl.staleDirs) > 0 {
		fmt.Fprintln(a.out, "🧽 Removing stale directories...")
		if a.cfg.dryRun {
			for _, r := range pl.staleDirs {
				fmt.Fprintf(a.out, "  [DRY RUN] rm -rf %q\n", r.path)
			}
		} else {
			lines := parallelMap(a.cfg.parallelJobs, pl.staleDirs, func(r row) string {
				if err := os.RemoveAll(r.path); err == nil {
					return fmt.Sprintf("  ✓ removed %s", r.branch)
				}
				return fmt.Sprintf("  ⚠️  failed to remove %s", r.branch)
			})
			for _, line := range lines {
				fmt.Fprintln(a.out, line)
			}
		}
		fmt.Fprintln(a.out)
	}
	if len(pl.behind) > 0 && a.cfg.autoPull {
		fmt.Fprintln(a.out, "⬇️  Pulling behind worktrees...")
		if a.cfg.dryRun {
			for _, r := range pl.behind {
				fmt.Fprintf(a.out, "  [DRY RUN] (cd %q && git pull --rebase)\n", r.path)
			}
		} else {
			fmt.Fprintf(a.out, "  parallel jobs: %d\n", a.cfg.parallelJobs)
			lines := parallelMap(a.cfg.parallelJobs, pl.behind, func(r row) string {
				if _, err := a.git(ctx, r.path, "pull", "--rebase"); err == nil {
					return fmt.Sprintf("  ✓ pulled %s", r.branch)
				}
				return fmt.Sprintf("  ⚠️  failed pull %s", r.branch)
			})
			for _, line := range lines {
				fmt.Fprintln(a.out, line)
			}
		}
		fmt.Fprintln(a.out)
	}
}

func parallelMap[T any](jobs int, items []T, fn func(T) string) []string {
	out := make([]string, len(items))
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
