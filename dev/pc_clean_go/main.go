package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const version = "2.0.0"

var defaultExternalCommands = [][]string{{"mole"}, {"mac-cleanup"}}

type config struct {
	apply, dryRun, yes, list, analyze    bool
	skipExternal                         bool
	selected                             []string
	nodeDays, generatedDays, sessionDays int
	reportTimeout                        time.Duration
	home                                 string
}

type operation struct {
	description, path, allowedRoot string
	command                        []string
}

type cleanupAction struct {
	id, label, risk, detail string
	plan                    func(config) ([]operation, error)
}

type sizeResult struct {
	label, path string
	bytes       int64
	err         error
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "pc_clean: %v\n", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("find home directory: %w", err)
	}
	cfg, err := parseArgs(args, home)
	if err != nil {
		return err
	}
	actions := availableActions()
	if cfg.list {
		printActions(actions)
		return nil
	}
	if !cfg.apply && !cfg.dryRun {
		if cfg.analyze || cfg.skipExternal {
			fmt.Printf("pc_clean %s — storage analysis (no files will be changed)\n\n", version)
			printStorageReport(cfg)
			fmt.Println("\nCleanup actions are opt-in. Run pc_clean --list to review them.")
			fmt.Println("Preview one with: pc_clean --dry-run --only <action>")
			return nil
		}

		fmt.Printf("pc_clean %s — default cleanup\n\n", version)
		externalErr := runExternalCleaners()
		fmt.Println("\nStorage after external cleaners:")
		printStorageReport(cfg)
		fmt.Println("\nCleanup actions are opt-in. Run pc_clean --list to review them.")
		fmt.Println("Preview one with: pc_clean --dry-run --only <action>")
		return externalErr
	}
	if len(cfg.selected) == 0 {
		return errors.New("--only is required with --apply or --dry-run; use --list to see actions")
	}
	selected, err := selectActions(actions, cfg.selected)
	if err != nil {
		return err
	}
	operations, err := buildPlan(selected, cfg)
	if err != nil {
		return err
	}
	printPlan(selected, operations)
	if len(operations) == 0 {
		fmt.Println("\nNothing matched the selected cleanup actions.")
		return nil
	}
	if cfg.dryRun {
		fmt.Println("\nDry run only; nothing changed.")
		return nil
	}
	if !cfg.yes {
		ok, err := confirm(os.Stdin, os.Stdout)
		if err != nil {
			return err
		}
		if !ok {
			fmt.Println("Cancelled; nothing changed.")
			return nil
		}
	}
	before, _ := availableBytes("/")
	result := executePlan(operations)
	after, _ := availableBytes("/")
	if result.failed > 0 {
		return fmt.Errorf("cleanup incomplete: %d succeeded, %d failed", result.succeeded, result.failed)
	}
	fmt.Printf("\nCompleted %d operation(s).", result.succeeded)
	if after > before {
		fmt.Printf(" Disk availability increased by %s.", humanBytes(int64(after-before)))
	}
	fmt.Println()
	if result.trashed > 0 {
		fmt.Println("Some items were moved to Trash; space is reclaimed only after you review and empty Trash yourself.")
	}
	return nil
}

func parseArgs(args []string, home string) (config, error) {
	var cfg config
	var only string
	set := flag.NewFlagSet("pc_clean", flag.ContinueOnError)
	set.SetOutput(os.Stderr)
	set.BoolVar(&cfg.apply, "apply", false, "execute the selected cleanup actions")
	set.BoolVar(&cfg.dryRun, "dry-run", false, "show the exact cleanup plan without changing files")
	set.BoolVar(&cfg.yes, "yes", false, "skip the interactive confirmation")
	set.BoolVar(&cfg.list, "list", false, "list available cleanup actions")
	set.BoolVar(&cfg.analyze, "analyze", false, "report storage without running the default external cleaners")
	set.BoolVar(&cfg.skipExternal, "skip-external", false, "skip Mole and mac-cleanup in the default run")
	set.StringVar(&only, "only", "", "comma-separated cleanup action IDs")
	set.IntVar(&cfg.nodeDays, "node-modules-days", 90, "minimum node_modules age in days")
	set.IntVar(&cfg.generatedDays, "generated-days", 30, "minimum generated-artifact age in days")
	set.IntVar(&cfg.sessionDays, "session-days", 90, "minimum Codex session-file age in days")
	set.DurationVar(&cfg.reportTimeout, "report-timeout", 30*time.Second, "timeout for each storage measurement")
	set.Usage = func() {
		fmt.Fprintln(set.Output(), "Usage: pc_clean [--analyze|--list] [--dry-run|--apply --only ACTIONS] [options]")
		set.PrintDefaults()
	}
	if err := set.Parse(args); err != nil {
		return cfg, err
	}
	if set.NArg() != 0 {
		return cfg, fmt.Errorf("unexpected arguments: %s", strings.Join(set.Args(), " "))
	}
	if cfg.apply && cfg.dryRun {
		return cfg, errors.New("--apply and --dry-run cannot be used together")
	}
	if cfg.nodeDays < 1 || cfg.generatedDays < 1 || cfg.sessionDays < 1 {
		return cfg, errors.New("retention periods must be at least one day")
	}
	if cfg.reportTimeout <= 0 {
		return cfg, errors.New("--report-timeout must be positive")
	}
	for _, id := range strings.Split(only, ",") {
		if id = strings.TrimSpace(id); id != "" {
			cfg.selected = append(cfg.selected, id)
		}
	}
	cfg.home = home
	return cfg, nil
}

func runExternalCleaners() error {
	var failures []error
	for _, command := range defaultExternalCommands {
		path, err := exec.LookPath(command[0])
		if err != nil {
			fmt.Printf("Skipping %s because it is not installed.\n", command[0])
			continue
		}
		fmt.Printf("Running %s...\n", command[0])
		cmd := exec.Command(path, command[1:]...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			failures = append(failures, fmt.Errorf("%s failed: %w", command[0], err))
		}
	}
	return errors.Join(failures...)
}

func availableActions() []cleanupAction {
	return []cleanupAction{
		{id: "pnpm-store", label: "Prune the pnpm content-addressed store", risk: "low", detail: "Uses pnpm's own prune command; installed projects are untouched.", plan: commandPlan("Prune unreferenced pnpm packages", "pnpm", "store", "prune")},
		{id: "homebrew-cache", label: "Remove stale Homebrew downloads", risk: "low", detail: "Runs brew cleanup with a 30-day retention period; does not update or upgrade packages.", plan: commandPlan("Clean Homebrew downloads older than 30 days", "brew", "cleanup", "--prune=30")},
		{id: "docker-build-cache", label: "Prune old Docker build cache", risk: "low", detail: "Deletes build cache older than seven days; never prunes Docker volumes.", plan: commandPlan("Prune Docker build cache older than seven days", "docker", "builder", "prune", "-f", "--filter", "until=168h")},
		{id: "docker-unused-images", label: "Prune old unused Docker images", risk: "review", detail: "Deletes unused images older than 30 days; they may need to be downloaded again. Volumes are untouched.", plan: commandPlan("Prune unused Docker images older than 30 days", "docker", "image", "prune", "-af", "--filter", "until=720h")},
		{id: "app-caches", label: "Move selected application caches to Trash", risk: "low", detail: "Targets rebuildable browser, package-manager, and updater caches; excludes CloudKit and application data.", plan: fixedCachePlan},
		{id: "dev-caches", label: "Move selected developer caches to Trash", risk: "low", detail: "Targets rebuildable model, runtime, compiler, and test caches under ~/.cache.", plan: devCachePlan},
		{id: "xcode-derived-data", label: "Move Xcode derived data to Trash", risk: "low", detail: "Targets DerivedData and Xcode cache only; release Archives are never selected.", plan: xcodeCachePlan},
		{id: "simulator-unavailable", label: "Delete unavailable Simulator devices", risk: "low", detail: "Uses Apple's simctl cleanup for devices whose runtimes are unavailable.", plan: commandPlan("Delete unavailable Simulator devices", "xcrun", "simctl", "delete", "unavailable")},
		{id: "maestro-cache", label: "Move Maestro caches to Trash", risk: "low", detail: "Selects only directories named .maestro/cache below ~/coding; Maestro rebuilds them when needed.", plan: maestroCachePlan},
		{id: "old-node-modules", label: "Move old node_modules directories to Trash", risk: "review", detail: "Scans ~/coding and selects node_modules directories not modified within the retention period.", plan: oldNodeModulesPlan},
		{id: "generated-artifacts", label: "Move old generated project artifacts to Trash", risk: "review", detail: "Selects named build, coverage, Playwright, Expo, and Maestro artifact output below ~/coding.", plan: generatedArtifactsPlan},
		{id: "codex-old-sessions", label: "Move old Codex session files to Trash", risk: "history", detail: "Old conversations may disappear from history and can no longer be resumed; inspect the dry run first.", plan: oldCodexSessionsPlan},
	}
}

func commandPlan(description string, command ...string) func(config) ([]operation, error) {
	return func(config) ([]operation, error) {
		if len(command) == 0 {
			return nil, errors.New("empty cleanup command")
		}
		if _, err := exec.LookPath(command[0]); err != nil {
			return nil, fmt.Errorf("%s is not installed", command[0])
		}
		return []operation{{description: description, command: command}}, nil
	}
}

func fixedCachePlan(cfg config) ([]operation, error) {
	root := filepath.Join(cfg.home, "Library", "Caches")
	return existingPaths(root, []string{"CocoaPods", "ms-playwright", "pnpm", "@lineardesktop-updater", "com.electron.wispr-flow.ShipIt", "Arc"}), nil
}

func devCachePlan(cfg config) ([]operation, error) {
	root := filepath.Join(cfg.home, ".cache")
	return existingPaths(root, []string{"huggingface", "uv", "codex-runtimes", "whisper.cpp", "zig", "mongodb-binaries"}), nil
}

func xcodeCachePlan(cfg config) ([]operation, error) {
	var operations []operation
	for _, item := range []struct{ root, name string }{{filepath.Join(cfg.home, "Library", "Developer", "Xcode"), "DerivedData"}, {filepath.Join(cfg.home, "Library", "Caches"), "com.apple.dt.Xcode"}} {
		operations = append(operations, existingPaths(item.root, []string{item.name})...)
	}
	return operations, nil
}

func existingPaths(root string, names []string) []operation {
	var operations []operation
	for _, name := range names {
		path := filepath.Join(root, name)
		if info, err := os.Lstat(path); err == nil && info.Mode()&os.ModeSymlink == 0 {
			operations = append(operations, operation{description: "Move " + path + " to Trash", path: path, allowedRoot: root})
		}
	}
	return operations
}

func oldNodeModulesPlan(cfg config) ([]operation, error) {
	return discoverNamedDirectories(filepath.Join(cfg.home, "coding"), map[string]bool{"node_modules": true}, time.Now().Add(-time.Duration(cfg.nodeDays)*24*time.Hour), map[string]bool{".git": true})
}

func maestroCachePlan(cfg config) ([]operation, error) {
	root := filepath.Join(cfg.home, "coding")
	skip := map[string]bool{".git": true, "node_modules": true, "Pods": true, ".venv": true, "venv": true}
	return discoverChildrenOfNamedDirectory(root, ".maestro", map[string]bool{"cache": true}, nil, skip)
}

func generatedArtifactsPlan(cfg config) ([]operation, error) {
	root := filepath.Join(cfg.home, "coding")
	cutoff := time.Now().Add(-time.Duration(cfg.generatedDays) * 24 * time.Hour)
	names := map[string]bool{".next": true, ".turbo": true, ".parcel-cache": true, ".expo": true, "coverage": true, "test-results": true, "playwright-report": true, ".nyc_output": true}
	skip := map[string]bool{".git": true, "node_modules": true, "Pods": true, ".venv": true, "venv": true}
	operations, err := discoverNamedDirectories(root, names, cutoff, skip)
	if err != nil {
		return nil, err
	}
	maestro, err := discoverChildrenOfNamedDirectory(root, ".maestro", map[string]bool{"artifacts": true}, &cutoff, skip)
	return append(operations, maestro...), err
}

func oldCodexSessionsPlan(cfg config) ([]operation, error) {
	root := filepath.Join(cfg.home, ".codex", "sessions")
	resolvedRoot, err := filepath.EvalSymlinks(root)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("resolve Codex sessions: %w", err)
	}
	root = resolvedRoot
	cutoff := time.Now().Add(-time.Duration(cfg.sessionDays) * 24 * time.Hour)
	var operations []operation
	err = filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if errors.Is(walkErr, os.ErrNotExist) {
				return nil
			}
			return walkErr
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return nil
		}
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".jsonl" {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.ModTime().Before(cutoff) {
			operations = append(operations, operation{description: "Move old Codex session to Trash", path: path, allowedRoot: root})
		}
		return nil
	})
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	return operations, err
}

func discoverNamedDirectories(root string, names map[string]bool, cutoff time.Time, skip map[string]bool) ([]operation, error) {
	var operations []operation
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if errors.Is(walkErr, os.ErrNotExist) {
				return nil
			}
			return walkErr
		}
		if path == root {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return nil
		}
		if !entry.IsDir() {
			return nil
		}
		if skip[entry.Name()] {
			return filepath.SkipDir
		}
		if !names[entry.Name()] {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.ModTime().Before(cutoff) {
			operations = append(operations, operation{description: "Move old generated directory to Trash", path: path, allowedRoot: root})
		}
		return filepath.SkipDir
	})
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	return operations, err
}

func discoverChildrenOfNamedDirectory(root, parentName string, childNames map[string]bool, cutoff *time.Time, skip map[string]bool) ([]operation, error) {
	var operations []operation
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if errors.Is(walkErr, os.ErrNotExist) {
				return nil
			}
			return walkErr
		}
		if path == root || !entry.IsDir() {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 || skip[entry.Name()] {
			return filepath.SkipDir
		}
		if filepath.Base(filepath.Dir(path)) != parentName || !childNames[entry.Name()] {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if cutoff == nil || info.ModTime().Before(*cutoff) {
			description := "Move generated cache to Trash"
			if cutoff != nil {
				description = "Move old generated directory to Trash"
			}
			operations = append(operations, operation{description: description, path: path, allowedRoot: root})
		}
		return filepath.SkipDir
	})
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	return operations, err
}

func printActions(actions []cleanupAction) {
	fmt.Println("Available cleanup actions (none run unless explicitly selected):")
	for _, action := range actions {
		fmt.Printf("  %-24s [%s] %s\n      %s\n", action.id, action.risk, action.label, action.detail)
	}
}

func selectActions(actions []cleanupAction, ids []string) ([]cleanupAction, error) {
	byID := make(map[string]cleanupAction, len(actions))
	for _, action := range actions {
		byID[action.id] = action
	}
	seen := map[string]bool{}
	var selected []cleanupAction
	for _, id := range ids {
		if seen[id] {
			continue
		}
		action, ok := byID[id]
		if !ok {
			return nil, fmt.Errorf("unknown cleanup action %q; use --list", id)
		}
		seen[id] = true
		selected = append(selected, action)
	}
	return selected, nil
}

func buildPlan(actions []cleanupAction, cfg config) ([]operation, error) {
	var operations []operation
	for _, action := range actions {
		planned, err := action.plan(cfg)
		if err != nil {
			return nil, fmt.Errorf("plan %s: %w", action.id, err)
		}
		for _, op := range planned {
			if op.path != "" {
				if err := validateTrashTarget(op.path, op.allowedRoot); err != nil {
					return nil, fmt.Errorf("unsafe %s target: %w", action.id, err)
				}
			}
			operations = append(operations, op)
		}
	}
	return operations, nil
}

func validateTrashTarget(target, allowedRoot string) error {
	if target == "" || allowedRoot == "" {
		return errors.New("target and allowed root are required")
	}
	resolvedTarget, err := filepath.EvalSymlinks(target)
	if err != nil {
		return fmt.Errorf("resolve target: %w", err)
	}
	resolvedRoot, err := filepath.EvalSymlinks(allowedRoot)
	if err != nil {
		return fmt.Errorf("resolve allowed root: %w", err)
	}
	resolvedTarget, resolvedRoot = filepath.Clean(resolvedTarget), filepath.Clean(resolvedRoot)
	if resolvedTarget == string(filepath.Separator) || resolvedTarget == resolvedRoot {
		return errors.New("refusing a filesystem or allowed-root target")
	}
	rel, err := filepath.Rel(resolvedRoot, resolvedTarget)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel) {
		return fmt.Errorf("%s is outside %s", resolvedTarget, resolvedRoot)
	}
	return nil
}

func printPlan(actions []cleanupAction, operations []operation) {
	fmt.Println("Selected actions:")
	for _, action := range actions {
		fmt.Printf("  %s [%s] — %s\n", action.id, action.risk, action.detail)
	}
	fmt.Printf("\nPlanned operations: %d\n", len(operations))
	for _, op := range operations {
		if op.path != "" {
			fmt.Printf("  trash %q — %s\n", op.path, op.description)
		} else {
			fmt.Printf("  %s — %s\n", shellDisplay(op.command), op.description)
		}
	}
}

func shellDisplay(args []string) string {
	quoted := make([]string, len(args))
	for i, arg := range args {
		quoted[i] = strconv.Quote(arg)
	}
	return strings.Join(quoted, " ")
}

func confirm(input *os.File, output *os.File) (bool, error) {
	info, err := input.Stat()
	if err != nil {
		return false, err
	}
	if info.Mode()&os.ModeCharDevice == 0 {
		return false, errors.New("confirmation requires a terminal; inspect with --dry-run, then use --apply --yes")
	}
	fmt.Fprint(output, "\nApply this exact plan? [y/N] ")
	line, err := bufio.NewReader(input).ReadString('\n')
	if err != nil && len(line) == 0 {
		return false, err
	}
	answer := strings.ToLower(strings.TrimSpace(line))
	return answer == "y" || answer == "yes", nil
}

type executionResult struct{ succeeded, failed, trashed int }

func executePlan(operations []operation) executionResult {
	var result executionResult
	for _, op := range operations {
		command := op.command
		if op.path != "" {
			if err := validateTrashTarget(op.path, op.allowedRoot); err != nil {
				fmt.Fprintf(os.Stderr, "FAIL %s: %v\n", op.description, err)
				result.failed++
				continue
			}
			command = []string{"/usr/bin/trash", "--stopOnError", op.path}
		}
		output, err := exec.Command(command[0], command[1:]...).CombinedOutput()
		if err != nil {
			fmt.Fprintf(os.Stderr, "FAIL %s: %v\n%s", op.description, err, output)
			result.failed++
			continue
		}
		fmt.Printf("OK   %s\n", op.description)
		result.succeeded++
		if op.path != "" {
			result.trashed++
		}
	}
	return result
}

func printStorageReport(cfg config) {
	targets := []struct{ label, path string }{
		{"User Library", filepath.Join(cfg.home, "Library")}, {"Codex data", filepath.Join(cfg.home, ".codex")}, {"User caches", filepath.Join(cfg.home, ".cache")}, {"Coding projects", filepath.Join(cfg.home, "coding")}, {"Pictures", filepath.Join(cfg.home, "Pictures")}, {"Rust toolchains", filepath.Join(cfg.home, ".rustup")}, {"Local user data", filepath.Join(cfg.home, ".local")}, {"Applications", "/Applications"}, {"System data volume", "/System/Volumes/Data/System"}, {"Homebrew and local software", "/opt"}, {"Private system data", "/private"}, {"Shared Library", "/Library"},
	}
	results := make(chan sizeResult, len(targets))
	limit := make(chan struct{}, 3)
	for _, target := range targets {
		go func(label, path string) {
			limit <- struct{}{}
			defer func() { <-limit }()
			bytes, err := measurePath(path, cfg.reportTimeout)
			results <- sizeResult{label: label, path: path, bytes: bytes, err: err}
		}(target.label, target.path)
	}
	var measured []sizeResult
	for range targets {
		measured = append(measured, <-results)
	}
	sort.Slice(measured, func(i, j int) bool { return measured[i].bytes > measured[j].bytes })
	for _, result := range measured {
		if result.err != nil {
			fmt.Printf("  %-28s unavailable (%v)\n", result.label, result.err)
		} else {
			fmt.Printf("  %-28s %9s  %s\n", result.label, humanBytes(result.bytes), result.path)
		}
	}
}

func measurePath(path string, timeout time.Duration) (int64, error) {
	if _, err := os.Stat(path); err != nil {
		return 0, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	if dua, err := exec.LookPath("dua"); err == nil {
		output, err := exec.CommandContext(ctx, dua, "aggregate", "-f", "bytes", path).Output()
		if err == nil {
			lines := strings.Split(strings.TrimSpace(string(output)), "\n")
			if len(lines) > 0 {
				fields := strings.Fields(lines[len(lines)-1])
				if len(fields) >= 2 && fields[len(fields)-1] == "total" {
					return strconv.ParseInt(fields[0], 10, 64)
				}
			}
		}
		if ctx.Err() != nil {
			return 0, fmt.Errorf("dua timed out after %s", timeout)
		}
	}
	output, err := exec.CommandContext(ctx, "du", "-sk", path).Output()
	if err != nil {
		if ctx.Err() != nil {
			return 0, fmt.Errorf("measurement timed out after %s", timeout)
		}
		return 0, err
	}
	fields := strings.Fields(string(output))
	if len(fields) == 0 {
		return 0, errors.New("du returned no size")
	}
	kib, err := strconv.ParseInt(fields[0], 10, 64)
	return kib * 1024, err
}

func availableBytes(path string) (uint64, error) {
	var stat syscall.Statfs_t
	if err := syscall.Statfs(path, &stat); err != nil {
		return 0, err
	}
	return stat.Bavail * uint64(stat.Bsize), nil
}

func humanBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
