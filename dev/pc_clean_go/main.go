package main

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type config struct {
	full              bool
	skipPython        bool
	analyzeOnly       bool
	dryRun            bool
	skipDocker        bool
	skipBrew          bool
	skipXcode         bool
	includeBrewCasks  bool
	chooseSimRuntime  bool
	skipAI            bool
	simRuntimeDays    int
	nodeModulesDays   int
	generatedDays     int
	aiHistoryDays     int
	reportSizeTimeout time.Duration
	home              string
}

var colors = struct {
	red, green, yellow, blue, magenta, cyan, reset string
}{
	red:     "\033[0;31m",
	green:   "\033[0;32m",
	yellow:  "\033[0;33m",
	blue:    "\033[0;34m",
	magenta: "\033[0;35m",
	cyan:    "\033[0;36m",
	reset:   "\033[0m",
}

func main() {
	cfg, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	clearScreen()
	printBanner()

	if cfg.analyzeOnly {
		fmt.Printf("%sRunning in analysis mode only%s\n\n", colors.blue, colors.reset)
		printStorageReport(cfg)
		printHeader("Analysis Complete")
		fmt.Printf("%sNo cleanup actions were executed.%s\n\n", colors.green, colors.reset)
		return
	}

	runExternalCleanupTools(cfg)

	if cfg.full {
		fmt.Printf("%sRunning in FULL cleanup mode%s\n\n", colors.magenta, colors.reset)
	} else {
		fmt.Printf("%sRunning in standard cleanup mode%s\n", colors.blue, colors.reset)
		fmt.Printf("%sUse --full for more aggressive cleaning%s\n\n", colors.blue, colors.reset)
	}
	if cfg.dryRun {
		fmt.Printf("%sDry-run mode enabled: destructive actions will be printed, not executed%s\n\n", colors.yellow, colors.reset)
	}
	if cfg.skipPython {
		fmt.Printf("%sSkipping Python cache cleanup%s\n\n", colors.yellow, colors.reset)
	}
	if cfg.chooseSimRuntime {
		fmt.Printf("%sInteractive simulator runtime selection enabled%s\n\n", colors.yellow, colors.reset)
	}

	printStorageReport(cfg)

	steps := []struct {
		name string
		fn   func(config)
	}{
		{"System Memory Cleanup", cleanSystemMemory},
		{"Homebrew Cleanup", cleanHomebrew},
		{"Development Environment Cleanup", cleanDevDirectories},
		{"Xcode Cleanup", cleanXcode},
		{"Docker Cleanup", cleanDocker},
		{"Rust Cleanup", cleanRust},
		{"Git Repository Cleanup", cleanGitRepos},
		{"System Cache Cleanup", cleanSystemCaches},
		{"AI Tool Runtime Cleanup", cleanAIRuntimeState},
	}
	for i, step := range steps {
		step.fn(cfg)
		showProgress(i+1, len(steps), "Overall Progress")
	}

	fmt.Println()
	printHeader("Cleanup Complete!")
	fmt.Printf("%sYour system has been cleaned and optimized.%s\n", colors.green, colors.reset)
	fmt.Printf("%sYou may want to restart your system for all changes to take effect.%s\n\n", colors.yellow, colors.reset)
}

func parseArgs(args []string) (config, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return config{}, err
	}
	cfg := config{
		simRuntimeDays:    30,
		nodeModulesDays:   120,
		generatedDays:     14,
		aiHistoryDays:     30,
		reportSizeTimeout: 3 * time.Second,
		home:              home,
	}

	fs := flag.NewFlagSet("pc_clean_go", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.BoolVar(&cfg.analyzeOnly, "analyze", false, "Print a storage report without deleting anything")
	fs.BoolVar(&cfg.chooseSimRuntime, "choose-sim-runtime", false, "Interactively choose installed simulator runtime(s) to delete")
	fs.BoolVar(&cfg.dryRun, "dry-run", false, "Show destructive actions without executing them")
	fs.BoolVar(&cfg.full, "full", false, "Run more aggressive cleanup steps")
	fs.BoolVar(&cfg.includeBrewCasks, "include-brew-casks", false, "Also upgrade Homebrew casks")
	fs.BoolVar(&cfg.skipPython, "skip-python", false, "Skip Python cache cleanup")
	fs.BoolVar(&cfg.skipBrew, "skip-brew", false, "Skip Homebrew maintenance")
	fs.BoolVar(&cfg.skipDocker, "skip-docker", false, "Skip Docker cleanup")
	fs.BoolVar(&cfg.skipXcode, "skip-xcode", false, "Skip Xcode / Simulator cleanup")
	fs.BoolVar(&cfg.skipAI, "skip-ai", false, "Skip Codex / Claude runtime cleanup")
	fs.IntVar(&cfg.simRuntimeDays, "sim-runtime-days", 30, "Retention threshold for simulator runtimes in full mode")
	fs.IntVar(&cfg.nodeModulesDays, "node-modules-days", 120, "Remove node_modules older than this many days")
	fs.IntVar(&cfg.generatedDays, "generated-days", 14, "Remove generated project artifacts older than this many days")
	fs.IntVar(&cfg.aiHistoryDays, "ai-history-days", 30, "Full mode retention for Codex/Claude history-like files")

	help := fs.Bool("help", false, "Show this help")
	shortHelp := fs.Bool("h", false, "Show this help")
	if err := fs.Parse(args); err != nil {
		return config{}, err
	}
	if *help || *shortHelp {
		printUsage()
		os.Exit(0)
	}
	if cfg.simRuntimeDays < 0 || cfg.nodeModulesDays < 0 || cfg.generatedDays < 0 || cfg.aiHistoryDays < 0 {
		return config{}, errors.New("retention day values must be non-negative")
	}
	return cfg, nil
}

func printUsage() {
	fmt.Println(`Usage: pc_clean [options]

Cleanup and analyze development-heavy storage on macOS.

Options:
  --analyze                     Print a storage report without deleting anything
  --choose-sim-runtime          Interactively choose installed simulator runtime(s) to delete
  --dry-run                     Show destructive actions without executing them
  --full                        Run more aggressive cleanup steps
  --include-brew-casks          Also upgrade Homebrew casks (disabled by default)
  --skip-python                 Skip Python cache cleanup
  --skip-brew                   Skip Homebrew maintenance
  --skip-docker                 Skip Docker cleanup
  --skip-xcode                  Skip Xcode / Simulator cleanup
  --sim-runtime-days <days>     Retention threshold for simulator runtimes in full mode
  --node-modules-days <days>    Remove node_modules older than this many days
  --generated-days <days>       Remove generated project artifacts older than this many days
  --ai-history-days <days>      Full mode retention for Codex/Claude history-like files
  --skip-ai                     Skip Codex / Claude runtime cleanup
  -h, --help                    Show this help

Examples:
  pc_clean --analyze
  pc_clean --dry-run --full
  pc_clean --full --generated-days 7 --node-modules-days 60`)
}

func clearScreen() {
	fmt.Print("\033[3J\033[H\033[2J")
}

func printBanner() {
	fmt.Println(colors.cyan)
	fmt.Println("  _____   _____    _____  _      _____          _   _ ")
	fmt.Println(" |  __ \\ / ____|  / ____|| |    |  ___|  /\\    | \\ | |")
	fmt.Println(" | |__) | |      | |     | |    | |__   /  \\   |  \\| |")
	fmt.Println(" |  ___/| |      | |     | |    |  __| / /\\ \\  | . ` |")
	fmt.Println(" | |    | |____  | |____ | |___ | |___/ ____ \\ | |\\  |")
	fmt.Println(" |_|     \\_____|  \\_____||_____||_____/_/    \\_\\|_| \\_|")
	fmt.Println(colors.reset)
	fmt.Printf("%sOptimized System Cleanup Tool%s\n", colors.green, colors.reset)
	fmt.Printf("%s=====================================%s\n\n", colors.yellow, colors.reset)
}

func printHeader(title string) {
	fmt.Printf("\n%s========================================%s\n", colors.blue, colors.reset)
	fmt.Printf("%s%s%s\n", colors.cyan, title, colors.reset)
	fmt.Printf("%s========================================%s\n\n", colors.blue, colors.reset)
}

func info(format string, args ...any) {
	fmt.Printf("%s->%s %s\n", colors.yellow, colors.reset, fmt.Sprintf(format, args...))
}

func warn(format string, args ...any) {
	fmt.Printf("%s!%s %s\n", colors.yellow, colors.reset, fmt.Sprintf(format, args...))
}

func success(format string, args ...any) {
	fmt.Printf("%sOK%s %s\n", colors.green, colors.reset, fmt.Sprintf(format, args...))
}

func showProgress(current, total int, title string) {
	percent := current * 100 / total
	width := 40
	filled := current * width / total
	fmt.Printf("%s[%-40s]%s %3d%% %s\r", colors.magenta, strings.Repeat("=", filled), colors.reset, percent, title)
}

func path(cfg config, parts ...string) string {
	all := append([]string{cfg.home}, parts...)
	return filepath.Join(all...)
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func commandString(name string, args ...string) string {
	quoted := append([]string{name}, args...)
	return strings.Join(quoted, " ")
}

func runSilent(cfg config, description, name string, args ...string) error {
	if cfg.dryRun {
		info("[dry-run] %s", description)
		fmt.Printf("    %s\n", commandString(name, args...))
		return nil
	}
	start := time.Now()
	cmd := exec.Command(name, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	err := cmd.Run()
	if err != nil {
		warn("%s failed: %v", description, err)
		return err
	}
	success("%s (%s)", description, time.Since(start).Round(time.Millisecond))
	return nil
}

func runOutput(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}

func runCapture(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func printStorageReport(cfg config) {
	printHeader("Storage Report")

	info("Disk usage overview")
	runOutput("df", "-h", "/", "/System/Volumes/Data")
	fmt.Println()

	printPathSizeGroup(cfg, "Top storage buckets",
		path(cfg, "Library", "Application Support"),
		path(cfg, "Library", "Containers"),
		path(cfg, "Library", "Group Containers"),
		path(cfg, "Library", "Developer"),
		path(cfg, "coding", "work"),
		path(cfg, "coding", "perso"),
		path(cfg, "Downloads"),
		path(cfg, "Documents"),
		path(cfg, "Pictures"),
		path(cfg, "Movies"),
		path(cfg, ".dotfiles", ".codex"),
		"/opt/homebrew",
		"/Applications",
	)

	info("High-value cleanup targets")
	printSortedSizes(cfg,
		path(cfg, "Library", "Developer", "Xcode", "DerivedData"),
		path(cfg, "Library", "Developer", "CoreSimulator", "Devices"),
		"/Library/Developer/CoreSimulator/Volumes",
		path(cfg, "Library", "Containers", "com.docker.docker"),
		path(cfg, "Library", "Caches"),
		"/opt/homebrew/Cellar",
		"/Applications/Xcode.app",
		"/Applications/Docker.app",
	)

	printPathSizeGroup(cfg, "Developer toolchains and package caches",
		"/opt/homebrew",
		path(cfg, ".cache"),
		path(cfg, ".nvm"),
		path(cfg, ".cargo"),
		path(cfg, ".rustup"),
		path(cfg, ".gradle"),
		path(cfg, ".docker"),
	)

	printPathSizeGroup(cfg, "Persistent app data for manual review",
		path(cfg, "Library", "Application Support", "Google"),
		path(cfg, "Library", "Application Support", "Arc"),
		path(cfg, "Library", "Group Containers", "group.net.whatsapp.WhatsApp.shared"),
		path(cfg, "Library", "Application Support", "Linear"),
		path(cfg, "Library", "Application Support", "BeeperTexts"),
		path(cfg, "Library", "Application Support", "Slack"),
		path(cfg, "Library", "Application Support", "discord"),
		path(cfg, "Library", "Application Support", "Wispr Flow"),
		path(cfg, "Library", "Application Support", "Notion"),
		path(cfg, "Library", "Containers", "com.apple.AMPArtworkAgent"),
	)

	printPathSizeGroup(cfg, "Personal media and downloads",
		path(cfg, "Downloads"),
		path(cfg, "Desktop"),
		path(cfg, "Documents"),
		path(cfg, "Movies"),
		path(cfg, "Music"),
		path(cfg, "Pictures"),
	)

	printPathSizeGroup(cfg, "AI agent runtime state",
		path(cfg, ".codex", "logs_2.sqlite"),
		path(cfg, ".codex", "archived_sessions"),
		path(cfg, ".codex", "sessions"),
		path(cfg, ".codex", "attachments"),
		path(cfg, ".codex", "generated_images"),
		path(cfg, ".codex", "cache"),
		path(cfg, ".codex", "tmp"),
		path(cfg, ".claude", "cache"),
		path(cfg, ".claude", "todos"),
	)

	printWorktreeReport(cfg)

	if commandExists("xcrun") {
		info("Installed simulator runtimes")
		runOutput("xcrun", "simctl", "list", "runtimes")
		fmt.Println()
	}
	if commandExists("docker") {
		info("Docker disk usage")
		runOutput("docker", "system", "df")
		fmt.Println()
	}
}

func printPathSizeGroup(cfg config, title string, paths ...string) {
	info("%s", title)
	printSortedSizes(cfg, paths...)
}

type sizeLine struct {
	raw   string
	bytes int64
	path  string
}

func printSortedSizes(cfg config, paths ...string) {
	lines := make([]sizeLine, 0, len(paths))
	results := make(chan sizeLine, len(paths))
	var wg sync.WaitGroup

	for _, p := range paths {
		p := p
		wg.Add(1)
		go func() {
			defer wg.Done()
			line, ok := reportPathSize(cfg, p)
			if ok {
				results <- line
			}
		}()
	}
	wg.Wait()
	close(results)

	for line := range results {
		lines = append(lines, line)
	}
	sort.Slice(lines, func(i, j int) bool {
		if lines[i].bytes == lines[j].bytes {
			return lines[i].path < lines[j].path
		}
		return lines[i].bytes < lines[j].bytes
	})
	for _, line := range lines {
		fmt.Println(line.raw)
	}
	fmt.Println()
}

func reportPathSize(cfg config, p string) (sizeLine, bool) {
	if _, err := os.Stat(p); err != nil {
		return sizeLine{}, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), cfg.reportSizeTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "du", "-sh", p)
	out, err := cmd.Output()
	if ctx.Err() == context.DeadlineExceeded {
		return sizeLine{raw: fmt.Sprintf("timeout\t%s", p), bytes: 1 << 62, path: p}, true
	}
	if err != nil {
		return sizeLine{}, false
	}
	raw := strings.TrimSpace(string(out))
	fields := strings.Fields(raw)
	var bytes int64
	if len(fields) > 0 {
		bytes = parseHumanSize(fields[0])
	}
	return sizeLine{raw: raw, bytes: bytes, path: p}, true
}

func parseHumanSize(s string) int64 {
	s = strings.TrimSpace(s)
	if s == "" || s == "timeout" {
		return 1 << 62
	}
	unit := s[len(s)-1]
	mult := float64(1)
	switch unit {
	case 'K':
		mult = 1024
		s = s[:len(s)-1]
	case 'M':
		mult = 1024 * 1024
		s = s[:len(s)-1]
	case 'G':
		mult = 1024 * 1024 * 1024
		s = s[:len(s)-1]
	case 'T':
		mult = 1024 * 1024 * 1024 * 1024
		s = s[:len(s)-1]
	case 'B':
		s = s[:len(s)-1]
	}
	v, _ := strconv.ParseFloat(s, 64)
	return int64(v * mult)
}

func printWorktreeReport(cfg config) {
	workRoot := path(cfg, "coding", "work")
	if !commandExists("git") {
		return
	}
	if _, err := os.Stat(workRoot); err != nil {
		return
	}
	info("Git worktree repositories")
	for _, repo := range findBareGitRepos(workRoot, 4) {
		out, err := runCapture("git", "--git-dir="+repo, "worktree", "list")
		if err != nil {
			continue
		}
		count := 0
		for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
			if strings.TrimSpace(line) != "" {
				count++
			}
		}
		fmt.Printf("%d worktrees\t%s\n", count, repo)
	}
	fmt.Println()
}

func runExternalCleanupTools(cfg config) {
	for _, tool := range []string{"mole", "mac-cleanup"} {
		if commandExists(tool) {
			info("Running %s", tool)
			_ = runSilent(cfg, tool, tool)
		} else {
			warn("Skipping %s: command not found", tool)
		}
	}
}

func cleanSystemMemory(cfg config) {
	printHeader("System Memory Cleanup")
	if commandExists("sudo") && commandExists("purge") {
		_ = runSilent(cfg, "Purging system memory", "sudo", "purge")
	} else {
		warn("Skipping memory purge: sudo or purge is not available")
	}
}

func cleanHomebrew(cfg config) {
	printHeader("Homebrew Cleanup")
	if cfg.skipBrew {
		info("Homebrew cleanup skipped (--skip-brew flag used)")
		return
	}
	if !commandExists("brew") {
		warn("Skipping Homebrew cleanup: brew is not installed")
		return
	}
	info("Updating and cleaning Homebrew packages...")
	_ = runSilent(cfg, "Updating Homebrew", "brew", "update")
	_ = runSilent(cfg, "Upgrading formulae", "brew", "upgrade", "--formula")
	if cfg.includeBrewCasks {
		_ = runSilent(cfg, "Upgrading casks", "brew", "upgrade", "--cask")
	} else {
		info("Skipping Homebrew cask upgrades by default")
		info("Use --include-brew-casks to opt in")
	}
	_ = runSilent(cfg, "Cleaning old versions", "brew", "cleanup", "--prune=all")
	_ = runSilent(cfg, "Removing unneeded dependencies", "brew", "autoremove")
	if cfg.full {
		out, err := runCapture("brew", "--cache")
		if err == nil {
			cleanDirectoryContents(cfg, strings.TrimSpace(out))
		}
	}
	success("Homebrew maintenance complete")
}

func cleanDevDirectories(cfg config) {
	printHeader("Development Environment Cleanup")
	coding := path(cfg, "coding")
	if exists(coding) {
		cleanOldNodeModules(cfg, coding)
		cleanGeneratedProjectArtifacts(cfg, coding)
	}
	if cfg.skipPython {
		info("Python cache cleanup skipped (--skip-python flag used)")
	} else {
		cleanPythonCache(cfg)
	}
	for _, p := range []string{
		path(cfg, "Library", "Caches", "pip"),
		path(cfg, ".npm"),
		path(cfg, ".gradle", "caches"),
		path(cfg, "Library", "Caches", "CocoaPods"),
		path(cfg, "Library", "Developer", "Xcode", "DerivedData"),
		path(cfg, "Library", "Developer", "Xcode", "Archives"),
		path(cfg, "Library", "Developer", "Xcode", "iOS DeviceSupport"),
	} {
		cleanDirectoryContents(cfg, p)
	}
	success("Cache directories cleaned")
}

func cleanOldNodeModules(cfg config, root string) {
	info("Removing node_modules older than %d days under %s...", cfg.nodeModulesDays, root)
	cutoff := time.Now().AddDate(0, 0, -cfg.nodeModulesDays)
	count := 0
	walkPruned(root, func(p string, d fs.DirEntry) (bool, error) {
		if !d.IsDir() {
			return false, nil
		}
		base := d.Name()
		if base == ".git" || base == ".next" || base == ".turbo" {
			return true, nil
		}
		if base == "node_modules" {
			info, err := d.Info()
			if err == nil && info.ModTime().Before(cutoff) {
				count++
				removePath(cfg, p)
			}
			return true, nil
		}
		return false, nil
	})
	success("Old node_modules scan complete (%d candidates)", count)
}

func cleanGeneratedProjectArtifacts(cfg config, root string) {
	info("Removing generated project artifacts older than %d days under %s...", cfg.generatedDays, root)
	cutoff := time.Now().AddDate(0, 0, -cfg.generatedDays)
	count := 0
	walkPruned(root, func(p string, d fs.DirEntry) (bool, error) {
		if !d.IsDir() {
			return false, nil
		}
		base := d.Name()
		if base == ".git" || base == "node_modules" || base == "Pods" || base == ".venv" || base == "venv" {
			return true, nil
		}
		if isGeneratedArtifact(p, base) {
			info, err := d.Info()
			if err == nil && info.ModTime().Before(cutoff) {
				count++
				removePath(cfg, p)
			}
			return true, nil
		}
		return false, nil
	})
	success("Generated artifact scan complete (%d candidates)", count)
}

func isGeneratedArtifact(p, base string) bool {
	switch base {
	case ".next", ".turbo", ".parcel-cache", ".expo", "coverage", "test-results", "playwright-report", ".nyc_output":
		return true
	case "build":
		parent := filepath.Base(filepath.Dir(p))
		return parent == "ios" || parent == "android"
	default:
		return false
	}
}

func cleanPythonCache(cfg config) {
	info("Cleaning Python cache...")
	roots := []string{path(cfg, "coding"), path(cfg, "Projects"), path(cfg, "code"), path(cfg, "python"), path(cfg, "development"), path(cfg, "dev")}
	count := 0
	for _, root := range roots {
		if !exists(root) {
			continue
		}
		walkPruned(root, func(p string, d fs.DirEntry) (bool, error) {
			if !d.IsDir() {
				return false, nil
			}
			base := d.Name()
			if base == ".git" || base == "node_modules" || base == ".next" || base == ".turbo" || base == ".venv" || base == "venv" {
				return true, nil
			}
			if base == "__pycache__" {
				count++
				removePath(cfg, p)
				return true, nil
			}
			return false, nil
		})
	}
	success("Python cache cleanup complete (%d candidates)", count)
}

func cleanXcode(cfg config) {
	printHeader("Xcode Cleanup")
	if cfg.skipXcode {
		info("Xcode cleanup skipped (--skip-xcode flag used)")
		return
	}
	if !exists("/Applications/Xcode.app") && !exists(path(cfg, "Library", "Developer")) {
		info("Xcode not installed, skipping related cleanup")
		return
	}
	_ = runSilent(cfg, "Closing Xcode", "osascript", "-e", `quit app "Xcode"`)
	time.Sleep(time.Second)
	for _, p := range []string{
		path(cfg, "Library", "Developer", "Xcode", "DerivedData"),
		path(cfg, "Library", "Developer", "Xcode", "Archives"),
		path(cfg, "Library", "Caches", "com.apple.dt.Xcode"),
	} {
		cleanDirectoryContents(cfg, p)
	}
	if commandExists("xcrun") {
		if cfg.chooseSimRuntime {
			chooseSimRuntimeToDelete(cfg)
		}
		_ = runSilent(cfg, "Deleting unavailable simulator devices", "xcrun", "simctl", "delete", "unavailable")
		if cfg.full {
			_ = runSilent(cfg, fmt.Sprintf("Deleting simulator runtimes unused for %d days", cfg.simRuntimeDays), "xcrun", "simctl", "runtime", "delete", "--notUsedSinceDays", strconv.Itoa(cfg.simRuntimeDays))
		} else if cfg.dryRun {
			_ = runSilent(cfg, fmt.Sprintf("Previewing simulator runtimes unused for %d days", cfg.simRuntimeDays), "xcrun", "simctl", "runtime", "delete", "--notUsedSinceDays", strconv.Itoa(cfg.simRuntimeDays), "--dry-run")
		} else {
			info("Standard mode keeps installed simulator runtimes")
			info("Use --full to delete runtimes unused for %d days", cfg.simRuntimeDays)
		}
	} else {
		warn("Skipping simulator cleanup: xcrun is not available")
	}
	success("Xcode cleanup complete")
}

func chooseSimRuntimeToDelete(cfg config) {
	entries := listRuntimeEntries()
	if len(entries) == 0 {
		info("No installed simulator runtimes found")
		return
	}

	fmt.Println("Installed runtimes:")
	for i, entry := range entries {
		fmt.Printf("  %d) %s [%s, last used: %s, size: %s]\n", i+1, entry.name, emptyDefault(entry.state, "unknown"), emptyDefault(entry.lastUsed, "unknown"), emptyDefault(entry.size, "unknown"))
	}
	fmt.Println("  a) Delete all listed runtimes")
	fmt.Println("  q) Cancel")
	fmt.Print("\nChoose runtime(s) to delete: ")

	scanner := bufio.NewScanner(os.Stdin)
	if !scanner.Scan() {
		info("Runtime deletion cancelled")
		return
	}
	selection := strings.TrimSpace(scanner.Text())
	if selection == "" || strings.EqualFold(selection, "q") {
		info("Runtime deletion cancelled")
		return
	}
	if strings.EqualFold(selection, "a") {
		for _, entry := range entries {
			_ = runSilent(cfg, "Deleting "+entry.name, "xcrun", "simctl", "runtime", "delete", entry.id)
		}
		return
	}

	seen := map[int]struct{}{}
	for _, token := range strings.Fields(strings.ReplaceAll(selection, ",", " ")) {
		idx, err := strconv.Atoi(token)
		if err != nil || idx < 1 || idx > len(entries) {
			warn("Invalid selection: %s", token)
			return
		}
		if _, ok := seen[idx]; ok {
			continue
		}
		seen[idx] = struct{}{}
		entry := entries[idx-1]
		_ = runSilent(cfg, "Deleting "+entry.name, "xcrun", "simctl", "runtime", "delete", entry.id)
	}
}

type runtimeEntry struct {
	id       string
	name     string
	state    string
	lastUsed string
	size     string
}

func listRuntimeEntries() []runtimeEntry {
	out, err := runCapture("xcrun", "simctl", "runtime", "list", "-v")
	if err != nil {
		return nil
	}
	var entries []runtimeEntry
	var current *runtimeEntry
	for _, raw := range strings.Split(out, "\n") {
		line := strings.TrimSpace(raw)
		if strings.HasPrefix(line, "iOS ") && strings.Contains(line, " - ") {
			if current != nil {
				entries = append(entries, *current)
			}
			parts := strings.Split(line, " - ")
			current = &runtimeEntry{
				name: strings.Join(parts[:len(parts)-1], " - "),
				id:   parts[len(parts)-1],
			}
			continue
		}
		if current == nil {
			continue
		}
		switch {
		case strings.HasPrefix(line, "State:"):
			current.state = strings.TrimSpace(strings.TrimPrefix(line, "State:"))
		case strings.HasPrefix(line, "Last Used At:"):
			current.lastUsed = strings.TrimSpace(strings.TrimPrefix(line, "Last Used At:"))
		case strings.HasPrefix(line, "Size:"):
			current.size = strings.TrimSpace(strings.TrimPrefix(line, "Size:"))
		}
	}
	if current != nil {
		entries = append(entries, *current)
	}
	return entries
}

func emptyDefault(s, fallback string) string {
	if strings.TrimSpace(s) == "" {
		return fallback
	}
	return s
}

func cleanDocker(cfg config) {
	printHeader("Docker Cleanup")
	if cfg.skipDocker {
		info("Docker cleanup skipped (--skip-docker flag used)")
		return
	}
	if !commandExists("docker") {
		info("Docker not installed, skipping cleanup")
		return
	}
	if err := exec.Command("docker", "info").Run(); err != nil {
		warn("Skipping Docker cleanup: Docker is installed but the daemon is not running")
		return
	}
	info("Docker usage before cleanup")
	runOutput("docker", "system", "df")
	_ = runSilent(cfg, "Pruning unused Docker volumes", "docker", "volume", "prune", "-f")
	_ = runSilent(cfg, "Pruning Docker system", "docker", "system", "prune", "-af", "--volumes")
	info("Docker usage after cleanup")
	runOutput("docker", "system", "df")
	success("Docker cleanup complete")
}

func cleanRust(cfg config) {
	printHeader("Rust Cleanup")
	if !commandExists("cargo") {
		info("Rust not installed, skipping cleanup")
		return
	}
	root := path(cfg, "coding")
	if !exists(root) {
		root = path(cfg, "Projects")
	}
	if !exists(root) {
		info("No Rust project root found, skipping build artifact cleanup")
		return
	}
	info("Cleaning Rust project artifacts under %s...", root)
	dirs := map[string]struct{}{}
	walkPruned(root, func(p string, d fs.DirEntry) (bool, error) {
		if d.IsDir() {
			base := d.Name()
			if base == ".git" || base == "node_modules" || base == ".next" || base == ".turbo" || base == "target" || base == "Pods" {
				return true, nil
			}
			return false, nil
		}
		if d.Name() == "Cargo.toml" {
			dirs[filepath.Dir(p)] = struct{}{}
		}
		return false, nil
	})
	for dir := range dirs {
		if cfg.dryRun {
			fmt.Printf("    %s\n", filepath.Join(dir, "Cargo.toml"))
		} else {
			cmd := exec.Command("cargo", "clean")
			cmd.Dir = dir
			cmd.Stdout = io.Discard
			cmd.Stderr = io.Discard
			_ = cmd.Run()
		}
	}
	success("Rust cleanup complete (%d projects)", len(dirs))
}

func cleanGitRepos(cfg config) {
	printHeader("Git Repository Cleanup")
	if !commandExists("git") {
		info("Git not installed, skipping cleanup")
		return
	}
	root := path(cfg, "coding")
	if !exists(root) {
		root = path(cfg, "Projects")
	}
	if !exists(root) {
		info("No Projects directory found, skipping Git cleanup")
		return
	}

	repos := findNormalGitRepos(root)
	info("Found %d normal Git repositories to clean", len(repos))
	for _, gitDir := range repos {
		repoDir := strings.TrimSuffix(gitDir, string(filepath.Separator)+".git")
		cleanMergedBranches(cfg, repoDir)
		if !cfg.dryRun {
			_ = runSilent(cfg, "git gc --auto "+repoDir, "git", "-C", repoDir, "gc", "--auto")
		}
	}

	info("Pruning stale worktree metadata in bare repositories")
	for _, repo := range findBareGitRepos(root, 4) {
		if cfg.dryRun {
			info("[dry-run] git --git-dir=%s worktree prune", repo)
			runOutput("git", "--git-dir="+repo, "worktree", "prune", "--dry-run")
		} else {
			_ = runSilent(cfg, "Pruning worktree metadata "+repo, "git", "--git-dir="+repo, "worktree", "prune")
			_ = runSilent(cfg, "git gc --auto "+repo, "git", "--git-dir="+repo, "gc", "--auto")
		}
	}
	success("Git repositories cleaned")
}

func cleanMergedBranches(cfg config, repoDir string) {
	out, err := runCapture("git", "-C", repoDir, "branch", "--merged")
	if err != nil {
		return
	}
	for _, line := range strings.Split(out, "\n") {
		branch := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "*"))
		if branch == "" || branch == "main" || branch == "master" {
			continue
		}
		if cfg.dryRun {
			fmt.Printf("    git -C %s branch -d %s\n", repoDir, branch)
		} else {
			_ = runSilent(cfg, "Deleting merged branch "+branch, "git", "-C", repoDir, "branch", "-d", branch)
		}
	}
}

func cleanSystemCaches(cfg config) {
	printHeader("System Cache Cleanup")
	matches, _ := filepath.Glob(path(cfg, "Library", "Preferences", "com.apple.LaunchServices.QuarantineEventsV*"))
	if len(matches) > 0 && commandExists("sqlite3") {
		_ = runSilent(cfg, "Clearing download history", "sqlite3", matches[0], "delete from LSQuarantineEvent")
	}
	trash := path(cfg, ".Trash")
	if entries, err := os.ReadDir(trash); err == nil && len(entries) > 0 {
		cleanDirectoryContents(cfg, trash)
	}
	for _, p := range []string{
		path(cfg, "Library", "Application Support", "CrashReporter"),
		path(cfg, "Library", "Application State"),
		path(cfg, "Library", "Caches"),
	} {
		cleanDirectoryContents(cfg, p)
	}
	success("System caches cleaned")
}

func cleanAIRuntimeState(cfg config) {
	printHeader("AI Tool Runtime Cleanup")
	if cfg.skipAI {
		info("AI runtime cleanup skipped (--skip-ai flag used)")
		return
	}
	for _, p := range []string{
		path(cfg, ".codex", "tmp"),
		path(cfg, ".codex", ".tmp"),
		path(cfg, ".codex", "node_repl"),
		path(cfg, ".claude", "cache"),
		path(cfg, ".claude", "debug"),
		path(cfg, ".claude", "paste-cache"),
		path(cfg, ".claude", "tsc-cache"),
	} {
		cleanDirectoryContents(cfg, p)
	}
	if cfg.full {
		info("Pruning old AI history-like files older than %d days", cfg.aiHistoryDays)
		cutoff := time.Now().AddDate(0, 0, -cfg.aiHistoryDays)
		for _, root := range []string{path(cfg, ".codex", "archived_sessions"), path(cfg, ".codex", "generated_images"), path(cfg, ".codex", "attachments")} {
			removeOldFiles(cfg, root, cutoff)
		}
	} else {
		info("Standard mode keeps Codex/Claude session history")
		info("Use --full to prune old archived sessions/images/attachments")
	}
	if exists(path(cfg, ".codex", "logs_2.sqlite")) {
		warn("Not deleting Codex SQLite logs automatically:")
		if line, ok := reportPathSize(cfg, path(cfg, ".codex", "logs_2.sqlite")); ok {
			fmt.Printf("    %s\n", line.raw)
		}
	}
	success("AI runtime cleanup complete")
}

func cleanDirectoryContents(cfg config, p string) {
	entries, err := os.ReadDir(p)
	if err != nil || len(entries) == 0 {
		return
	}
	info("Cleaning: %s", p)
	if cfg.dryRun {
		info("[dry-run] Would remove contents of %s", p)
		return
	}
	for _, entry := range entries {
		_ = os.RemoveAll(filepath.Join(p, entry.Name()))
	}
	success("Cleaned %s", p)
}

func removePath(cfg config, p string) {
	if cfg.dryRun {
		fmt.Printf("    %s\n", p)
		return
	}
	_ = os.RemoveAll(p)
}

func removeOldFiles(cfg config, root string, cutoff time.Time) {
	if !exists(root) {
		return
	}
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil || !info.ModTime().Before(cutoff) {
			return nil
		}
		if cfg.dryRun {
			fmt.Printf("    %s\n", p)
		} else {
			_ = os.Remove(p)
		}
		return nil
	})
}

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func walkPruned(root string, visit func(string, fs.DirEntry) (bool, error)) {
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		prune, err := visit(p, d)
		if err != nil {
			return nil
		}
		if prune && d.IsDir() {
			return filepath.SkipDir
		}
		return nil
	})
}

func findNormalGitRepos(root string) []string {
	var repos []string
	walkPruned(root, func(p string, d fs.DirEntry) (bool, error) {
		if !d.IsDir() {
			return false, nil
		}
		if d.Name() == ".git" {
			repos = append(repos, p)
			return true, nil
		}
		if shouldPruneRepoSearchDir(d.Name()) {
			return true, nil
		}
		return false, nil
	})
	sort.Strings(repos)
	return repos
}

func findBareGitRepos(root string, maxDepth int) []string {
	var repos []string
	root = filepath.Clean(root)
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || !d.IsDir() {
			return nil
		}
		if p == root {
			return nil
		}
		depth := pathDepth(root, p)
		if depth > maxDepth {
			return filepath.SkipDir
		}
		if strings.HasSuffix(d.Name(), ".git") && d.Name() != ".git" {
			repos = append(repos, p)
			return filepath.SkipDir
		}
		if d.Name() == ".git" || shouldPruneRepoSearchDir(d.Name()) {
			return filepath.SkipDir
		}
		return nil
	})
	sort.Strings(repos)
	return repos
}

func shouldPruneRepoSearchDir(name string) bool {
	switch name {
	case "node_modules", ".next", ".turbo", "Pods", ".venv", "venv", "target":
		return true
	default:
		return strings.HasSuffix(name, ".git")
	}
}

func pathDepth(root, p string) int {
	rel, err := filepath.Rel(root, p)
	if err != nil || rel == "." {
		return 0
	}
	return len(strings.Split(rel, string(filepath.Separator)))
}

func runLoggedForBench(name string, args ...string) (time.Duration, error) {
	start := time.Now()
	cmd := exec.Command(name, args...)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	err := cmd.Run()
	return time.Since(start), err
}
