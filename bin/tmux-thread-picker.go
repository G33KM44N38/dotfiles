package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode"
)

type colors struct {
	reset      string
	bold       string
	dim        string
	green      string
	yellow     string
	cyan       string
	magenta    string
	red        string
	dotCurrent string
	proc       string
}

type app struct {
	mode       string
	args       []string
	self       string
	tmuxBin    string
	fzfBin     string
	gitBin     string
	home       string
	stateDir   string
	sourceSess string
	sourcePane string
	sourcePath string
	tmpDir     string
	c          colors

	pinFile                string
	titleFile              string
	archiveFile            string
	seenFile               string
	repoCacheFile          string
	worktreeCacheFile      string
	codexStateCacheFile    string
	displayCacheFile       string
	processWindowCacheFile string
	codexHookStateIndex    string

	repoCacheTTL          int
	codexStateCacheTTL    int
	displayRefreshTTL     int
	processWindowCacheTTL int

	repoCandidatesFile    string
	openPathsFile         string
	rowsFile              string
	sortedRowsFile        string
	displayRowsFile       string
	fzfRowsFile           string
	paneRowsFile          string
	codexStateRowsFile    string
	processWindowRowsFile string
	scanRoots             []string
}

type row struct {
	sortKey string
	kind    string
	display string
	target  string
	branch  string
	pinKey  string
	project string
	search  string
}

type worktreeRow struct {
	path     string
	branch   string
	project  string
	relative string
}

func main() {
	a := newApp(os.Args[1:])
	if err := a.run(); err != nil {
		a.fail(err.Error())
	}
}

func newApp(args []string) *app {
	home, _ := os.UserHomeDir()
	mode := "pick"
	if len(args) > 0 {
		mode = args[0]
	}
	stateHome := getenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	stateDir := filepath.Join(stateHome, "tmux-thread-picker")
	self := os.Getenv("TMUX_THREAD_PICKER_ENTRYPOINT")
	if self == "" {
		self = os.Args[0]
	}
	return &app{
		mode:                   mode,
		args:                   args,
		self:                   self,
		tmuxBin:                lookPath("tmux", "/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"),
		fzfBin:                 lookPath("fzf", "/opt/homebrew/bin/fzf", "/usr/local/bin/fzf"),
		gitBin:                 lookPath("git"),
		home:                   home,
		stateDir:               stateDir,
		sourceSess:             os.Getenv("TMUX_THREAD_SOURCE_SESSION"),
		sourcePane:             firstNonEmpty(os.Getenv("TMUX_THREAD_SOURCE_PANE"), os.Getenv("TMUX_PANE")),
		sourcePath:             os.Getenv("TMUX_THREAD_SOURCE_PATH"),
		pinFile:                filepath.Join(stateDir, "pins"),
		titleFile:              filepath.Join(stateDir, "titles"),
		archiveFile:            filepath.Join(stateDir, "archives"),
		seenFile:               filepath.Join(stateDir, "seen-finished"),
		repoCacheFile:          filepath.Join(stateDir, "repo-candidates.tsv"),
		worktreeCacheFile:      filepath.Join(stateDir, "worktrees.tsv"),
		codexStateCacheFile:    filepath.Join(stateDir, "codex-states.tsv"),
		displayCacheFile:       filepath.Join(stateDir, "display-rows.tsv"),
		processWindowCacheFile: filepath.Join(stateDir, "process-windows.tsv"),
		codexHookStateIndex:    filepath.Join(stateDir, "codex-hook-states.tsv"),
		repoCacheTTL:           getenvInt("TMUX_THREAD_CACHE_TTL", 300),
		codexStateCacheTTL:     getenvInt("TMUX_THREAD_CODEX_CACHE_TTL", 0),
		displayRefreshTTL:      getenvInt("TMUX_THREAD_DISPLAY_REFRESH_TTL", 3),
		processWindowCacheTTL:  getenvInt("TMUX_THREAD_PROCESS_CACHE_TTL", 3),
	}
}

func (a *app) run() error {
	if a.mode == "--filter-rows" {
		query := ""
		if len(a.args) > 1 {
			query = a.args[1]
		}
		return filterRows(os.Stdin, os.Stdout, query)
	}

	switch a.mode {
	case "--toggle-pin":
		return toggleLine(a.pinFile, arg(a.args, 1))
	case "--toggle-archive":
		return toggleLine(a.archiveFile, arg(a.args, 1))
	case "--set-title":
		return a.setTitle(arg(a.args, 1), arg(a.args, 2))
	case "--prompt-title":
		return a.promptTitle(arg(a.args, 1))
	case "--edit-title":
		return a.editTitle(arg(a.args, 1))
	}

	if a.tmuxBin == "" || !a.tmuxAvailable() {
		return errors.New("thread picker: tmux server not available")
	}
	if a.gitBin == "" {
		return errors.New("thread picker: git not found in PATH")
	}

	switch a.mode {
	case "--kill-window":
		return a.killThreadWindow(arg(a.args, 1), arg(a.args, 2), arg(a.args, 3))
	case "--watch-fzf":
		return a.watchFZF(arg(a.args, 1))
	}

	if err := a.resolveSource(); err != nil {
		return err
	}
	a.initColors()

	if a.mode == "--new-thread" {
		return a.createNewThread(arg(a.args, 1))
	}

	tmp, err := os.MkdirTemp(os.Getenv("TMPDIR"), "tmux-thread-picker.*")
	if err != nil {
		return err
	}
	a.tmpDir = tmp
	defer os.RemoveAll(tmp)
	a.repoCandidatesFile = filepath.Join(tmp, "repos.tsv")
	a.openPathsFile = filepath.Join(tmp, "open-paths.txt")
	a.rowsFile = filepath.Join(tmp, "rows.tsv")
	a.sortedRowsFile = filepath.Join(tmp, "sorted-rows.tsv")
	a.displayRowsFile = filepath.Join(tmp, "display-rows.tsv")
	a.fzfRowsFile = filepath.Join(tmp, "fzf-rows.tsv")
	a.paneRowsFile = filepath.Join(tmp, "panes.tsv")
	a.codexStateRowsFile = filepath.Join(tmp, "codex-states.tsv")
	a.processWindowRowsFile = filepath.Join(tmp, "process-windows.txt")

	if a.mode == "--refresh-cache" {
		return a.refreshCacheLocked()
	}

	if a.shouldUseDisplayCache() {
		_ = copyFile(a.displayCacheFile, a.displayRowsFile)
		_ = a.refreshLiveStateOverlay()
		a.refreshDisplayCacheBackground()
	} else {
		if err := a.buildRows(); err != nil {
			return err
		}
		_ = a.writeDisplayCache()
	}

	if fileEmpty(a.displayRowsFile) {
		return errors.New("thread picker: no tmux windows or git worktrees found")
	}

	switch a.mode {
	case "--list":
		return a.printList()
	case "--rows":
		_ = a.writeDisplayCache()
		data, _ := os.ReadFile(a.displayRowsFile)
		_, err := os.Stdout.Write(data)
		return err
	}

	if a.fzfBin == "" {
		return errors.New("thread picker: fzf not found in PATH")
	}
	return a.pick()
}

func (a *app) tmuxAvailable() bool {
	return exec.Command(a.tmuxBin, "list-sessions").Run() == nil
}

func (a *app) resolveSource() error {
	if a.sourceSess == "" {
		a.sourceSess = strings.TrimSpace(a.output(a.tmuxBin, "display-message", "-p", "#S"))
	}
	if a.sourceSess == "" {
		lines := strings.Split(strings.TrimSpace(a.output(a.tmuxBin, "list-sessions", "-F", "#{session_name}")), "\n")
		if len(lines) > 0 {
			a.sourceSess = lines[0]
		}
	}
	if a.sourceSess == "" {
		return errors.New("thread picker: unable to resolve tmux session")
	}
	if a.sourcePath == "" {
		a.sourcePath = strings.TrimSpace(a.output(a.tmuxBin, "display-message", "-p", "-t", a.sourcePane, "#{pane_current_path}"))
	}
	if a.sourcePath == "" {
		wd, _ := os.Getwd()
		a.sourcePath = wd
	}
	return nil
}

func (a *app) initColors() {
	if os.Getenv("NO_COLOR") != "" && os.Getenv("TMUX_THREAD_COLOR") != "1" {
		a.c = colors{}
		return
	}
	a.c = colors{
		reset:      "\033[0m",
		bold:       "\033[1m",
		dim:        "\033[2m",
		green:      "\033[32m",
		yellow:     "\033[33m",
		cyan:       "\033[36m",
		magenta:    "\033[35m",
		red:        "\033[31m",
		dotCurrent: "\033[1;38;5;46m",
		proc:       "\033[1;38;5;220m",
	}
}

func (a *app) fail(message string) {
	fmt.Fprintln(os.Stderr, message)
	if a.tmuxBin != "" {
		_ = exec.Command(a.tmuxBin, "display-message", message).Run()
	}
	if isTerminal(os.Stdout.Fd()) {
		fmt.Fprintln(os.Stdout)
		fmt.Fprint(os.Stdout, "Press Enter to close...")
		_, _ = bufio.NewReader(os.Stdin).ReadString('\n')
	}
	os.Exit(1)
}

func filterRows(in io.Reader, out io.Writer, query string) error {
	scanner := bufio.NewScanner(in)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	var group string
	var groupLabelSearch string
	var rows []string
	var rowSearch []string

	flush := func() {
		if group == "" {
			return
		}
		if strings.TrimSpace(query) == "" {
			fmt.Fprintln(out, group)
			for _, r := range rows {
				fmt.Fprintln(out, r)
			}
		} else {
			groupMatches := queryMatch(groupLabelSearch, query)
			any := groupMatches
			matches := make([]bool, len(rows))
			for i, s := range rowSearch {
				if queryMatch(s, query) {
					matches[i] = true
					any = true
				}
			}
			if any {
				fmt.Fprintln(out, group)
			}
			for i, r := range rows {
				if groupMatches || matches[i] {
					fmt.Fprintln(out, r)
				}
			}
		}
		group = ""
		groupLabelSearch = ""
		rows = nil
		rowSearch = nil
	}

	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Split(line, "\t")
		if len(fields) > 0 && fields[0] == "GROUP" {
			flush()
			group = line
			label := field(fields, 1)
			search := field(fields, 5)
			groupLabelSearch = label + " " + search
			continue
		}
		if group == "" {
			if strings.TrimSpace(query) == "" || queryMatch(line, query) {
				fmt.Fprintln(out, line)
			}
			continue
		}
		rows = append(rows, line)
		rowsSearchText := line + " " + field(fields, 6)
		rowSearch = append(rowSearch, rowsSearchText)
	}
	flush()
	return scanner.Err()
}

func queryMatch(value, needle string) bool {
	value = normalize(stripANSI(value))
	needle = normalize(stripANSI(needle))
	needle = strings.Join(strings.Fields(needle), " ")
	if needle == "" {
		return true
	}
	compactValue := compact(value)
	for _, term := range strings.Fields(needle) {
		compactTerm := compact(term)
		if !strings.Contains(value, term) && (compactTerm == "" || !strings.Contains(compactValue, compactTerm)) {
			return false
		}
	}
	return true
}

func normalize(s string) string { return strings.ToLower(s) }

func compact(s string) string {
	var b strings.Builder
	for _, r := range normalize(stripANSI(s)) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func stripANSI(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] == 0x1b && i+1 < len(s) && s[i+1] == '[' {
			i += 2
			for i < len(s) && s[i] != 'm' {
				i++
			}
			continue
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

func toggleLine(path, key string) error {
	if key == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	lines := readLines(path)
	found := false
	var next []string
	for _, line := range lines {
		if line == key {
			found = true
			continue
		}
		if line != "" {
			next = append(next, line)
		}
	}
	if !found {
		next = append(next, key)
	}
	sort.Strings(next)
	return writeLines(path, unique(next))
}

func (a *app) setTitle(key, title string) error {
	if key == "" {
		return nil
	}
	if err := os.MkdirAll(a.stateDir, 0o755); err != nil {
		return err
	}
	var out []string
	for _, line := range readLines(a.titleFile) {
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) > 0 && parts[0] == key {
			continue
		}
		if line != "" {
			out = append(out, line)
		}
	}
	if title != "" {
		out = append(out, key+"\t"+title)
	}
	return writeLines(a.titleFile, out)
}

func (a *app) promptTitle(key string) error {
	if key == "" {
		return nil
	}
	command := shellQuote(a.self) + " --set-title " + shellQuote(key) + " '%'"
	return exec.Command(a.tmuxBin, "command-prompt", "-p", "thread title", "run-shell "+command).Run()
}

func (a *app) editTitle(key string) error {
	if key == "" {
		return nil
	}
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer tty.Close()
	fmt.Fprint(tty, "Thread title (empty clears): ")
	title, _ := bufio.NewReader(tty).ReadString('\n')
	title = strings.TrimRight(title, "\r\n")
	return a.setTitle(key, title)
}

func (a *app) killThreadWindow(kind, target, sourceTarget string) error {
	if kind != "OPEN" || target == "" || !strings.Contains(target, ":") {
		return nil
	}
	parts := strings.SplitN(target, ":", 2)
	session, window := parts[0], parts[1]
	if target == sourceTarget {
		for _, candidate := range strings.Fields(a.output(a.tmuxBin, "list-windows", "-t", session, "-F", "#{window_index}")) {
			if candidate != window {
				if exec.Command(a.tmuxBin, "switch-client", "-t", session+":"+candidate).Run() != nil {
					_ = exec.Command(a.tmuxBin, "select-window", "-t", session+":"+candidate).Run()
				}
				break
			}
		}
	}
	cleanup := filepath.Join(a.home, ".dotfiles", "bin", "tmux-cleanup.sh")
	if isExecutable(cleanup) {
		_ = exec.Command(cleanup, "window", session, window).Run()
	}
	_ = exec.Command(a.tmuxBin, "kill-window", "-t", target).Run()
	return nil
}

func (a *app) watchFZF(socket string) error {
	if socket == "" {
		return nil
	}
	script := fmt.Sprintf(`last=""
sleep "${TMUX_THREAD_WATCH_INITIAL_DELAY:-0}"
while [ -S %s ]; do
  %s --refresh-cache >/dev/null 2>&1 || true
  [ -S %s ] || exit 0
  if [ -s %s ]; then
    checksum="$(cksum %s 2>/dev/null || true)"
    if [ -n "$checksum" ] && [ "$checksum" != "$last" ]; then
      last="$checksum"
      curl --silent --show-error --max-time 1 --unix-socket %s http --data-binary %s >/dev/null 2>&1 || exit 0
    fi
  fi
  sleep "${TMUX_THREAD_WATCH_INTERVAL:-5}"
done`, shellQuote(socket), shellQuote(a.self), shellQuote(socket), shellQuote(a.displayCacheFile), shellQuote(a.displayCacheFile), shellQuote(socket), shellQuote("reload("+a.self+" --filter-rows {q} < "+shellQuote(a.displayCacheFile)+")"))
	cmd := exec.Command("sh", "-c", script)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	_ = cmd.Start()
	return nil
}

func (a *app) buildRows() error {
	_ = os.WriteFile(a.repoCandidatesFile, nil, 0o644)
	_ = os.WriteFile(a.openPathsFile, nil, 0o644)
	_ = os.WriteFile(a.rowsFile, nil, 0o644)
	panes := a.output(a.tmuxBin, "list-panes", "-a", "-F", "#{window_id}\t#{pane_id}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_pid}")
	_ = os.WriteFile(a.paneRowsFile, []byte(panes), 0o644)
	_ = a.buildCodexStateCache()
	_ = a.ensureProcessWindowIndex()

	a.scanRoots = nil
	if p := normalizeExistingPath(a.sourcePath); p != "" {
		a.sourcePath = p
	}
	_ = a.addCurrentRepoCandidate(a.sourcePath)
	_ = a.addCurrentRepoCandidate(filepath.Join(a.home, ".dotfiles"))
	if roots := os.Getenv("TMUX_THREAD_ROOTS"); roots != "" {
		for _, root := range strings.Split(roots, ":") {
			a.addScanRoot(root)
		}
	} else {
		a.addScanRoot(filepath.Join(a.home, "coding"))
		a.addScanRoot(filepath.Join(a.home, "Projects"))
		a.addScanRoot(filepath.Join(a.home, "dev"))
		a.addScanRoot(filepath.Join(a.home, "Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"))
	}
	_ = a.collectCachedRepoCandidates()
	_ = a.ensureWorktreeCache()

	var rows []row
	rows = append(rows, a.emitOpenRows()...)
	rows = append(rows, a.emitWorktreeRows()...)
	sort.Slice(rows, func(i, j int) bool { return rows[i].sortKey < rows[j].sortKey })
	display := a.renderGroupedRows(rows)
	display = a.addGroupSearchColumn(display)
	return writeRows(a.displayRowsFile, display, false)
}

func (a *app) emitOpenRows() []row {
	sourceWindowIndex := strings.TrimSpace(a.output(a.tmuxBin, "display-message", "-p", "-t", a.sourcePane, "#{window_index}"))
	lines := strings.Split(strings.TrimRight(a.output(a.tmuxBin, "list-windows", "-a", "-F", "#{session_name}\t#{window_index}\t#{window_id}\t#{window_name}\t#{window_activity_flag}\t#{window_bell_flag}\t#{pane_current_path}\t#{@secondary-worktree-path}"), "\n"), "\n")
	var out []row
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		sessionName, windowIndex, windowID, windowName := field(parts, 0), field(parts, 1), field(parts, 2), field(parts, 3)
		activityFlag, bellFlag, panePath, taggedPath := field(parts, 4), field(parts, 5), field(parts, 6), field(parts, 7)
		if windowID == "" {
			continue
		}
		path := firstNonEmpty(taggedPath, panePath)
		path = normalizeExistingPath(path)
		if path == "" {
			continue
		}
		branch, project, relative := a.worktreeMetadata(path)
		if branch == "" {
			if root := a.repoRoot(path); root != "" {
				path = root
			}
			branch = a.branchName(path)
			project = a.projectName(path)
			relative = a.projectRelativePath(path)
		}
		currentMarker := " "
		if sessionName == a.sourceSess && windowIndex == sourceWindowIndex {
			currentMarker = "*"
		}
		state := "open" + currentMarker
		target := sessionName + ":" + windowIndex
		rowSignal := "open"
		if currentMarker == "*" {
			rowSignal = "current"
		}
		if activityFlag == "1" || bellFlag == "1" {
			rowSignal = "look"
		}
		switch a.windowCodexState(windowID) {
		case "done":
			if a.hasSeenFinished(path) {
				rowSignal = "open"
				if currentMarker == "*" {
					rowSignal = "current"
				}
			} else {
				rowSignal = "codex_done"
			}
		case "running":
			_ = a.clearSeenFinished(path)
			rowSignal = "codex_running"
		}
		if a.windowHasCodexCLI(windowID) {
			if rowSignal != "codex_running" && rowSignal != "codex_done" && rowSignal != "current" {
				rowSignal = "codex_open"
			}
		}
		processSignal := ""
		if a.windowHasRunningProcess(windowID) {
			processSignal = "process"
		}
		if r, ok := a.emitRow("OPEN", state, branch, target, windowName, path, target, project, path, rowSignal, processSignal, relative); ok {
			out = append(out, r)
		}
		appendLine(a.openPathsFile, path)
	}
	return out
}

func (a *app) emitWorktreeRows() []row {
	open := map[string]bool{}
	for _, line := range readLines(a.openPathsFile) {
		open[line] = true
	}
	var out []row
	for _, wt := range a.readWorktreeCache() {
		if !isDir(wt.path) || open[wt.path] {
			continue
		}
		project := wt.project
		if project == "" {
			project = a.projectName(wt.path)
		}
		relative := wt.relative
		if relative == "" {
			relative = a.projectRelativePath(wt.path)
		}
		if r, ok := a.emitRow("WT", "work", wt.branch, "<open>", filepath.Base(wt.path), wt.path, wt.path, project, wt.path, "work", "", relative); ok {
			out = append(out, r)
		}
	}
	return out
}

func (a *app) emitRow(kind, state, branch, target, window, path, selectionTarget, project, pinKey, rowSignal, processSignal, detailOverride string) (row, bool) {
	if a.isArchived(pinKey) && os.Getenv("TMUX_THREAD_SHOW_ARCHIVED") != "1" {
		return row{}, false
	}
	archived := " "
	if a.isArchived(pinKey) {
		archived = "A"
	}
	pinned := " "
	if pinKey != "" && containsLine(a.pinFile, pinKey) {
		pinned = "P"
	}
	if a.attentionModeEnabled() {
		if rowSignal != "codex_done" && rowSignal != "codex_running" && rowSignal != "codex_open" && rowSignal != "current" && processSignal != "process" {
			return row{}, false
		}
	}
	stateLabel := state
	if state == "open " {
		stateLabel = "open"
	}
	dot := " "
	switch rowSignal {
	case "codex_open":
		stateLabel = "codex"
	case "codex_done":
		dot = a.colorText(a.c.dotCurrent, "●")
		stateLabel = "wait"
	case "codex_running":
		dot = a.colorText(a.c.proc, "▶")
		stateLabel = "run"
	}
	procMarker := " "
	if processSignal == "process" {
		procMarker = a.colorText(a.c.proc, "!")
	}
	relative := detailOverride
	if relative == "" {
		relative = a.projectRelativePath(path)
	}
	fallbackTitle := window
	if kind == "PICK" {
		fallbackTitle = "worktree picker"
	} else if kind == "OPEN" || kind == "WT" {
		fallbackTitle = filepath.Base(path)
	}
	title := padText(a.threadTitle(pinKey, fallbackTitle), 30)
	detail := padText(relative, 56)
	branchCol := padText(branch, 56)
	display := fmt.Sprintf("%s%s %s %s  %s  %s  %s",
		dot,
		procMarker,
		a.colorText(a.c.red, pinned+archived),
		a.colorState(kind, padText(stateLabel, 6)),
		title,
		a.colorText(a.c.dim, detail),
		a.colorText(a.c.magenta, branchCol),
	)
	sortKey := "1"
	if pinned == "P" {
		sortKey = "0"
	}
	if archived == "A" {
		sortKey = "9"
	}
	rowPriority := "5"
	if rowSignal == "codex_done" || rowSignal == "codex_running" || rowSignal == "codex_open" || rowSignal == "look" {
		rowPriority = "0"
	}
	if strings.Contains(state, "*") && rowPriority > "1" {
		rowPriority = "1"
	}
	if processSignal == "process" && rowPriority > "2" {
		rowPriority = "2"
	}
	return row{
		sortKey: sortKey + "|" + strings.ToLower(project) + "|" + rowPriority + "|" + kind + "|" + path,
		kind:    kind,
		display: display,
		target:  selectionTarget,
		branch:  branch,
		pinKey:  pinKey,
		project: project,
	}, true
}

func (a *app) renderGroupedRows(rows []row) []row {
	hasPinned, hasArchived := false, false
	for _, r := range rows {
		if strings.HasPrefix(r.sortKey, "0|") {
			hasPinned = true
		}
		if strings.HasPrefix(r.sortKey, "9|") {
			hasArchived = true
		}
	}
	var out []row
	if hasPinned {
		out = append(out, a.groupHeader("Pinned"))
		for _, r := range rows {
			if strings.HasPrefix(r.sortKey, "0|") {
				out = append(out, r)
			}
		}
	}
	printed := map[string]bool{}
	for _, r := range rows {
		if strings.HasPrefix(r.sortKey, "0|") || strings.HasPrefix(r.sortKey, "9|") {
			continue
		}
		if !printed[r.project] {
			printed[r.project] = true
			out = append(out, a.groupHeader(r.project))
		}
		out = append(out, r)
	}
	if hasArchived {
		out = append(out, a.groupHeader("Archived"))
		for _, r := range rows {
			if strings.HasPrefix(r.sortKey, "9|") {
				out = append(out, r)
			}
		}
	}
	return out
}

func (a *app) groupHeader(label string) row {
	return row{kind: "GROUP", display: a.c.bold + a.c.cyan + ":: " + label + a.c.reset, project: label}
}

func (a *app) addGroupSearchColumn(rows []row) []row {
	currentGroup := -1
	for i := range rows {
		base := strings.Join([]string{rows[i].kind, rows[i].display, rows[i].target, rows[i].branch, rows[i].pinKey, rows[i].project}, "\t")
		if rows[i].kind == "GROUP" {
			currentGroup = i
			rows[i].search = " " + searchText(rows[i].display)
		} else {
			rows[i].search = " " + searchText(base)
			if currentGroup >= 0 {
				rows[currentGroup].search += " " + searchText(base)
			}
		}
	}
	return rows
}

func (a *app) colorState(kind, state string) string {
	switch kind {
	case "PICK":
		return a.c.bold + a.c.cyan + state + a.c.reset
	case "OPEN":
		return a.c.green + state + a.c.reset
	case "WT":
		return a.c.yellow + state + a.c.reset
	default:
		return state
	}
}

func (a *app) colorText(color, value string) string {
	return color + value + a.c.reset
}

func (a *app) threadTitle(key, fallback string) string {
	if key != "" {
		for _, line := range readLines(a.titleFile) {
			parts := strings.SplitN(line, "\t", 2)
			if len(parts) == 2 && parts[0] == key && parts[1] != "" {
				return parts[1]
			}
		}
	}
	return fallback
}

func (a *app) isArchived(key string) bool {
	return key != "" && containsLine(a.archiveFile, key)
}

func (a *app) attentionModeEnabled() bool {
	return os.Getenv("TMUX_THREAD_ATTENTION_ONLY") == "1" && os.Getenv("TMUX_THREAD_SHOW_ARCHIVED") != "1"
}

func (a *app) buildCodexStateCache() error {
	_ = os.MkdirAll(a.stateDir, 0o755)
	if age, ok := cacheAgeSeconds(a.codexStateCacheFile); ok && age < a.codexStateCacheTTL {
		return copyFile(a.codexStateCacheFile, a.codexStateRowsFile)
	}
	hook := a.readHookStates()
	stateByWindow := map[string]string{}
	for _, line := range readLines(a.paneRowsFile) {
		parts := strings.Split(line, "\t")
		if len(parts) < 4 || !strings.Contains(parts[2], "codex") {
			continue
		}
		state := hook[parts[3]]
		if state == "" {
			state = "unknown"
		}
		window := parts[0]
		if state == "running" || (state == "done" && stateByWindow[window] != "running") || stateByWindow[window] == "" {
			stateByWindow[window] = state
		}
	}
	var lines []string
	for window, state := range stateByWindow {
		lines = append(lines, window+"\t"+state)
	}
	sort.Strings(lines)
	_ = writeLines(a.codexStateCacheFile, lines)
	return copyFile(a.codexStateCacheFile, a.codexStateRowsFile)
}

func (a *app) readHookStates() map[string]string {
	result := map[string]string{}
	now := time.Now().Unix()
	staleAfter := int64(getenvInt("TMUX_THREAD_CODEX_HOOK_STALE_AFTER", 86400))
	for _, line := range readLines(a.codexHookStateIndex) {
		parts := strings.Split(line, "\t")
		if len(parts) < 4 {
			continue
		}
		updated, _ := strconv.ParseInt(parts[3], 10, 64)
		if parts[0] == "" || updated == 0 || now-updated > staleAfter {
			continue
		}
		state := "unknown"
		if parts[1] == "running" {
			state = "running"
		} else if parts[1] == "attention" || parts[1] == "done" {
			state = "done"
		}
		if state == "running" || (state == "done" && result[parts[0]] != "running") || result[parts[0]] == "" {
			result[parts[0]] = state
		}
	}
	return result
}

func (a *app) ensureProcessWindowIndex() error {
	if !fileEmpty(a.processWindowRowsFile) {
		return nil
	}
	if age, ok := fileAgeSeconds(a.processWindowCacheFile); ok && age < a.processWindowCacheTTL {
		return copyFile(a.processWindowCacheFile, a.processWindowRowsFile)
	}
	return a.buildProcessWindowIndex()
}

func (a *app) buildProcessWindowIndex() error {
	_ = os.MkdirAll(a.stateDir, 0o755)
	psOutput := a.output("ps", "-axo", "pid=,ppid=,comm=,command=")
	type proc struct {
		ppid int
		comm string
		line string
	}
	processes := map[int]proc{}
	for _, line := range strings.Split(psOutput, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		pid, err1 := strconv.Atoi(fields[0])
		ppid, err2 := strconv.Atoi(fields[1])
		if err1 != nil || err2 != nil {
			continue
		}
		comm := fields[2]
		commandLine := ""
		if idx := strings.Index(line, comm); idx >= 0 {
			commandLine = strings.TrimSpace(line[idx+len(comm):])
		}
		processes[pid] = proc{ppid: ppid, comm: comm, line: commandLine}
	}
	paneWindow := map[int]string{}
	for _, line := range readLines(a.paneRowsFile) {
		parts := strings.Split(line, "\t")
		if len(parts) < 5 || parts[4] == "" {
			continue
		}
		pid, err := strconv.Atoi(parts[4])
		if err == nil {
			paneWindow[pid] = parts[0]
		}
	}
	paneAncestor := func(pid int) string {
		seen := map[int]bool{}
		for pid != 0 {
			if window := paneWindow[pid]; window != "" {
				return window
			}
			if seen[pid] {
				return ""
			}
			seen[pid] = true
			p := processes[pid]
			if isIgnoredContainer(p.comm) {
				return ""
			}
			pid = p.ppid
		}
		return ""
	}
	busy := map[string]bool{}
	for pid, p := range processes {
		window := paneAncestor(p.ppid)
		if window != "" && !isIgnoredProcess(p.comm, p.line) {
			busy[window] = true
		}
		_ = pid
	}
	var lines []string
	for window := range busy {
		lines = append(lines, window)
	}
	sort.Strings(lines)
	_ = writeLines(a.processWindowCacheFile, lines)
	return copyFile(a.processWindowCacheFile, a.processWindowRowsFile)
}

func isIgnoredProcess(command, line string) bool {
	base := filepath.Base(command)
	if base == "" || base == "tmux" || base == "nvim" || base == "vim" || base == "vi" {
		return true
	}
	switch base {
	case "ps", "awk", "sed", "grep", "perl":
		return true
	}
	if strings.HasPrefix(base, "codex") || strings.Contains(line, "codex") || strings.Contains(line, "supermaven") {
		return true
	}
	if isShellName(base) {
		return !containsAny(line, []string{"pnpm", "npm", "yarn", "bun", "node", "python", "ruby", "go ", "cargo", "make", "docker", "eas", "expo", "vite", "next", "jest", "vitest", "pytest", "gradle", "mvn", "java", "deno", "tsx", "ts-node"})
	}
	return false
}

func isIgnoredContainer(command string) bool {
	base := filepath.Base(command)
	return base == "nvim" || base == "vim" || base == "vi" || strings.Contains(base, "codex")
}

func isShellName(base string) bool {
	switch base {
	case "zsh", "bash", "sh", "dash", "fish", "ksh", "nu", "pwsh":
		return true
	default:
		return false
	}
}

func (a *app) windowCodexState(windowID string) string {
	for _, line := range readLines(a.codexStateRowsFile) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 2 && parts[0] == windowID {
			return parts[1]
		}
	}
	return ""
}

func (a *app) windowHasCodexCLI(windowID string) bool {
	for _, line := range readLines(a.paneRowsFile) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 3 && parts[0] == windowID {
			base := filepath.Base(parts[2])
			if base == "codex" || strings.HasPrefix(base, "codex-") {
				return true
			}
		}
	}
	return false
}

func (a *app) windowHasRunningProcess(windowID string) bool {
	return containsLine(a.processWindowRowsFile, windowID)
}

func (a *app) markSeenFinished(key string) error {
	if key == "" {
		return nil
	}
	_ = os.MkdirAll(a.stateDir, 0o755)
	if !containsLine(a.seenFile, key) {
		return appendLine(a.seenFile, key)
	}
	return nil
}

func (a *app) clearSeenFinished(key string) error {
	if key == "" || fileEmpty(a.seenFile) {
		return nil
	}
	var out []string
	for _, line := range readLines(a.seenFile) {
		if line != key && line != "" {
			out = append(out, line)
		}
	}
	return writeLines(a.seenFile, out)
}

func (a *app) hasSeenFinished(key string) bool {
	return key != "" && containsLine(a.seenFile, key)
}

func (a *app) addScanRoot(path string) {
	if path == "" {
		return
	}
	if strings.HasPrefix(path, "~/") {
		path = filepath.Join(a.home, strings.TrimPrefix(path, "~/"))
	}
	real, err := filepath.Abs(path)
	if err != nil || !isDir(real) {
		return
	}
	for _, existing := range a.scanRoots {
		if existing == real {
			return
		}
	}
	a.scanRoots = append(a.scanRoots, real)
}

func (a *app) collectCachedRepoCandidates() error {
	_ = os.MkdirAll(a.stateDir, 0o755)
	if !fileEmpty(a.repoCacheFile) {
		data, _ := os.ReadFile(a.repoCacheFile)
		appendBytes(a.repoCandidatesFile, data)
		if age, ok := cacheAgeSeconds(a.repoCacheFile); ok && age >= a.repoCacheTTL {
			a.refreshRepoCacheBackground()
		}
		return nil
	}
	if err := a.refreshRepoCache(); err != nil {
		return err
	}
	data, _ := os.ReadFile(a.repoCacheFile)
	appendBytes(a.repoCandidatesFile, data)
	return nil
}

func (a *app) refreshRepoCacheBackground() {
	cmd := exec.Command(a.self, "--refresh-cache")
	cmd.Env = append(os.Environ(), "TMUX_THREAD_PICKER_ENTRYPOINT="+a.self)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	_ = cmd.Start()
}

func (a *app) refreshRepoCache() error {
	var lines []string
	for _, root := range a.scanRoots {
		lines = append(lines, a.collectRepoCandidates(root)...)
	}
	sort.Strings(lines)
	return writeLines(a.repoCacheFile, unique(lines))
}

func (a *app) collectRepoCandidates(root string) []string {
	var out []string
	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		name := d.Name()
		if d.IsDir() && (name == "node_modules" || name == ".cache" || name == ".next" || name == "dist" || name == "build" || name == "target" || name == "vendor") {
			return filepath.SkipDir
		}
		if (d.IsDir() && name == ".git") || (!d.IsDir() && name == ".git") || (d.IsDir() && strings.HasSuffix(name, ".git")) {
			if line := a.addRepoCandidate(path); line != "" {
				out = append(out, line)
			}
			if d.IsDir() {
				return filepath.SkipDir
			}
		}
		return nil
	})
	return out
}

func (a *app) addRepoCandidate(candidate string) string {
	repoPath := candidate
	if filepath.Base(candidate) == ".git" {
		repoPath = filepath.Dir(candidate)
	}
	if exec.Command(a.gitBin, "-C", repoPath, "worktree", "list", "--porcelain").Run() != nil {
		return ""
	}
	common := a.gitCommonDir(repoPath)
	if common == "" {
		common = repoPath
	}
	return common + "\t" + repoPath
}

func (a *app) addCurrentRepoCandidate(path string) error {
	root := a.repoRoot(path)
	if root == "" {
		return nil
	}
	line := a.addRepoCandidate(root)
	if line != "" {
		return appendLine(a.repoCandidatesFile, line)
	}
	return nil
}

func (a *app) ensureWorktreeCache() error {
	_ = os.MkdirAll(a.stateDir, 0o755)
	if !fileEmpty(a.worktreeCacheFile) {
		if age, ok := cacheAgeSeconds(a.worktreeCacheFile); ok && age >= a.repoCacheTTL {
			a.refreshWorktreeCacheBackground()
		}
		return nil
	}
	return a.refreshWorktreeCache(a.repoCandidatesFile)
}

func (a *app) refreshWorktreeCacheBackground() {
	_ = a.refreshWorktreeCache(a.repoCandidatesFile)
}

func (a *app) refreshWorktreeCache(repoSource string) error {
	repos := map[string]bool{}
	for _, line := range readLines(repoSource) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 2 {
			repos[parts[1]] = true
		}
	}
	var entries []worktreeRow
	for repo := range repos {
		entries = append(entries, a.gitWorktrees(repo)...)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].path < entries[j].path })
	var lines []string
	seen := map[string]bool{}
	for _, wt := range entries {
		if wt.path == "" || seen[wt.path] || !isDir(wt.path) {
			continue
		}
		seen[wt.path] = true
		wt.project = a.projectName(wt.path)
		wt.relative = a.projectRelativePath(wt.path)
		lines = append(lines, strings.Join([]string{wt.path, wt.branch, wt.project, wt.relative}, "\t"))
	}
	return writeLines(a.worktreeCacheFile, lines)
}

func (a *app) readWorktreeCache() []worktreeRow {
	var out []worktreeRow
	for _, line := range readLines(a.worktreeCacheFile) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 2 {
			out = append(out, worktreeRow{path: parts[0], branch: parts[1], project: field(parts, 2), relative: field(parts, 3)})
		}
	}
	return out
}

func (a *app) gitWorktrees(repo string) []worktreeRow {
	text := a.output(a.gitBin, "-C", repo, "worktree", "list", "--porcelain")
	var out []worktreeRow
	path, branch := "", "-"
	emit := func() {
		if path != "" {
			out = append(out, worktreeRow{path: path, branch: branch})
		}
	}
	for _, line := range strings.Split(text, "\n") {
		if strings.HasPrefix(line, "worktree ") {
			emit()
			path = strings.TrimPrefix(line, "worktree ")
			branch = "-"
		} else if strings.HasPrefix(line, "branch ") {
			branch = strings.TrimPrefix(line, "branch ")
			branch = strings.TrimPrefix(branch, "refs/heads/")
		} else if strings.HasPrefix(line, "detached") {
			branch = "(detached)"
		}
	}
	emit()
	return out
}

func (a *app) worktreeMetadata(path string) (string, string, string) {
	for _, line := range readLines(a.worktreeCacheFile) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 4 && parts[0] == path {
			return parts[1], parts[2], parts[3]
		}
	}
	return "", "", ""
}

func (a *app) repoRoot(path string) string {
	return strings.TrimSpace(a.output(a.gitBin, "-C", path, "rev-parse", "--show-toplevel"))
}

func (a *app) gitCommonDir(root string) string {
	common := strings.TrimSpace(a.output(a.gitBin, "-C", root, "rev-parse", "--git-common-dir"))
	if common == "" {
		return ""
	}
	if !filepath.IsAbs(common) {
		return cleanAbs(filepath.Join(root, common))
	}
	return common
}

func (a *app) branchName(path string) string {
	branch := strings.TrimSpace(a.output(a.gitBin, "-C", path, "branch", "--show-current"))
	if branch == "" {
		branch = strings.TrimSpace(a.output(a.gitBin, "-C", path, "rev-parse", "--short", "HEAD"))
	}
	if branch == "" {
		return "-"
	}
	return branch
}

func (a *app) projectName(path string) string {
	common := a.gitCommonDir(path)
	if common != "" {
		base := filepath.Base(common)
		if base != ".git" && strings.HasSuffix(base, ".git") {
			return strings.TrimSuffix(base, ".git")
		}
		return strings.TrimSuffix(filepath.Base(filepath.Dir(common)), ".git")
	}
	return filepath.Base(path)
}

func (a *app) projectRelativePath(path string) string {
	common := a.gitCommonDir(path)
	if common != "" {
		base := filepath.Base(common)
		root := path
		if base != ".git" && strings.HasSuffix(base, ".git") {
			root = common
		}
		if path == root {
			return "."
		}
		if strings.HasPrefix(path, root+string(os.PathSeparator)) {
			rel := strings.TrimPrefix(path, root+string(os.PathSeparator))
			if rel != "" {
				return rel
			}
			return "."
		}
	}
	if strings.HasPrefix(path, a.home+string(os.PathSeparator)) {
		return "~/" + strings.TrimPrefix(path, a.home+string(os.PathSeparator))
	}
	return path
}

func (a *app) createNewThread(key string) error {
	preferred := strings.TrimPrefix(key, "PICK:")
	if preferred == key && !isDir(preferred) {
		preferred = ""
	}
	var projectRows []string
	if preferred != "" {
		projectRows = append(projectRows, a.projectName(preferred)+"\t"+preferred)
	}
	for _, line := range readLines(a.repoCacheFile) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 2 && isDir(parts[1]) {
			projectRows = append(projectRows, a.projectName(parts[1])+"\t"+parts[1])
		}
	}
	projectRows = unique(projectRows)
	sort.Strings(projectRows)
	if len(projectRows) == 0 {
		return errors.New("thread picker: no projects found for new thread")
	}
	selectedProject, err := runInput(a.fzfBin, projectRows, "--prompt=project > ", "--delimiter=\t", "--with-nth=1,2", "--height=100%", "--border")
	if err != nil || selectedProject == "" {
		return nil
	}
	parts := strings.Split(selectedProject, "\t")
	sourceRepo := field(parts, 1)
	projectName := field(parts, 0)
	if !isDir(sourceRepo) {
		return fmt.Errorf("thread picker: invalid project path for new thread: %s", sourceRepo)
	}
	title, _ := runInput(a.fzfBin, nil, "--prompt=thread title for "+projectName+" > ", "--print-query", "--height=100%", "--border", "--no-info", "--phony", "--bind", "enter:accept-or-print-query")
	title = strings.Split(title, "\n")[0]
	if title == "" {
		return nil
	}
	branch := sanitizeBranchPath(title)
	baseDir, err := a.newWorktreeBaseDir(sourceRepo)
	if err != nil {
		return errors.New("thread picker: unable to resolve worktree base")
	}
	target := filepath.Join(baseDir, branch)
	for suffix := 2; pathExists(target); suffix++ {
		target = filepath.Join(baseDir, branch+"-"+strconv.Itoa(suffix))
	}
	var addErr []byte
	if exec.Command(a.gitBin, "-C", sourceRepo, "show-ref", "--verify", "--quiet", "refs/heads/"+branch).Run() == nil {
		addErr, _ = exec.Command(a.gitBin, "-C", sourceRepo, "worktree", "add", target, branch).CombinedOutput()
	} else {
		addErr, _ = exec.Command(a.gitBin, "-C", sourceRepo, "worktree", "add", "-b", branch, target).CombinedOutput()
	}
	if !isDir(target) {
		return fmt.Errorf("thread picker: failed to create worktree: %s", strings.TrimSpace(string(addErr)))
	}
	_ = os.Remove(a.worktreeCacheFile)
	_ = a.setTitle(target, title)
	return a.openThreadWindow(target, branch)
}

func (a *app) newWorktreeBaseDir(path string) (string, error) {
	common := a.gitCommonDir(path)
	if common == "" {
		return "", errors.New("no common dir")
	}
	base := filepath.Base(common)
	if base != ".git" && strings.HasSuffix(base, ".git") {
		if strings.HasPrefix(path, common+string(os.PathSeparator)) {
			parent := filepath.Dir(path)
			if isDir(parent) && parent != common {
				return parent, nil
			}
		}
		if isDir(filepath.Join(common, "codex-")) {
			return filepath.Join(common, "codex-"), nil
		}
		if isDir(filepath.Join(common, "codex")) {
			return filepath.Join(common, "codex"), nil
		}
		return common, nil
	}
	return filepath.Dir(path), nil
}

func (a *app) openThreadWindow(path, branch string) error {
	_ = a.markSeenFinished(path)
	script := filepath.Join(a.home, ".dotfiles", "bin", "tmux-worktree-layout.sh")
	return syscall.Exec(script, []string{script, "open", a.sourceSess, path, branch}, os.Environ())
}

func (a *app) refreshCacheLocked() error {
	lock := filepath.Join(a.stateDir, "display-refresh.lock")
	if err := os.Mkdir(lock, 0o755); err != nil {
		if age, ok := fileAgeSeconds(lock); ok && age > 60 {
			_ = os.Remove(lock)
			if err := os.Mkdir(lock, 0o755); err != nil {
				return nil
			}
		} else {
			return nil
		}
	}
	defer os.Remove(lock)
	if err := a.buildRows(); err != nil {
		return err
	}
	return a.writeDisplayCache()
}

func (a *app) shouldUseDisplayCache() bool {
	return a.mode == "pick" &&
		!a.attentionModeEnabled() &&
		getenv("TMUX_THREAD_USE_DISPLAY_CACHE", "1") == "1" &&
		os.Getenv("TMUX_THREAD_SHOW_ARCHIVED") != "1" &&
		!fileEmpty(a.displayCacheFile) &&
		displayCacheHasGroups(a.displayCacheFile)
}

func displayCacheHasGroups(path string) bool {
	found := false
	for _, line := range readLines(path) {
		parts := strings.Split(line, "\t")
		if len(parts) > 0 && parts[0] == "GROUP" {
			found = true
			if len(parts) < 7 || parts[6] == "" {
				return false
			}
		}
	}
	return found
}

func (a *app) writeDisplayCache() error {
	if fileEmpty(a.displayRowsFile) || a.attentionModeEnabled() || os.Getenv("TMUX_THREAD_SHOW_ARCHIVED") == "1" {
		return nil
	}
	_ = os.MkdirAll(a.stateDir, 0o755)
	return copyFile(a.displayRowsFile, a.displayCacheFile)
}

func (a *app) refreshLiveStateOverlay() error {
	if fileEmpty(a.displayRowsFile) {
		return nil
	}
	panes := a.output(a.tmuxBin, "list-panes", "-a", "-F", "#{window_id}\t#{pane_id}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_pid}")
	_ = os.WriteFile(a.paneRowsFile, []byte(panes), 0o644)
	_ = a.buildCodexStateCache()
	_ = a.ensureProcessWindowIndex()

	sourceWindowIndex := strings.TrimSpace(a.output(a.tmuxBin, "display-message", "-p", "-t", a.sourcePane, "#{window_index}"))
	live := map[string]string{}
	windowIDByTarget := map[string]string{}
	for _, line := range strings.Split(strings.TrimRight(a.output(a.tmuxBin, "list-windows", "-a", "-F", "#{session_name}:#{window_index}\t#{window_id}\t#{window_name}\t#{window_activity_flag}\t#{window_bell_flag}"), "\n"), "\n") {
		parts := strings.Split(line, "\t")
		if len(parts) >= 2 {
			windowIDByTarget[parts[0]] = parts[1]
			live[parts[0]] = line
		}
	}
	var out []row
	for _, r := range readRows(a.displayRowsFile) {
		if r.kind != "OPEN" || r.target == "" || live[r.target] == "" {
			out = append(out, r)
			continue
		}
		plain := stripANSI(r.display)
		pin := substr(plain, 3, 5)
		tail := substr(plain, 14, len(plain))
		targetParts := strings.SplitN(r.target, ":", 2)
		currentMarker := " "
		if len(targetParts) == 2 && targetParts[0] == a.sourceSess && targetParts[1] == sourceWindowIndex {
			currentMarker = "*"
		}
		stateLabel := "open" + currentMarker
		dot := " "
		windowID := windowIDByTarget[r.target]
		switch a.windowCodexState(windowID) {
		case "running":
			dot = a.colorText(a.c.proc, "▶")
			stateLabel = "run"
		case "done":
			if !a.hasSeenFinished(r.pinKey) {
				dot = a.colorText(a.c.dotCurrent, "●")
				stateLabel = "wait"
			}
		}
		proc := " "
		if a.windowHasRunningProcess(windowID) {
			proc = a.colorText(a.c.proc, "!")
		}
		r.display = dot + proc + " " + a.colorText(a.c.red, pin) + " " + a.colorText(a.c.green, padText(stateLabel, 6)) + "  " + tail
		out = append(out, r)
	}
	out = a.addGroupSearchColumn(out)
	return writeRows(a.displayRowsFile, out, false)
}

func (a *app) refreshDisplayCacheBackground() {
	if age, ok := fileAgeSeconds(a.displayCacheFile); ok && age < a.displayRefreshTTL {
		return
	}
	cmd := exec.Command(a.self, "--refresh-cache")
	cmd.Env = append(os.Environ(), "TMUX_THREAD_PICKER_ENTRYPOINT="+a.self)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	_ = cmd.Start()
}

func (a *app) printList() error {
	for _, r := range readRows(a.displayRowsFile) {
		fmt.Println(stripANSI(r.display))
	}
	return nil
}

func (a *app) pick() error {
	in, _ := os.Open(a.displayRowsFile)
	out, _ := os.Create(a.fzfRowsFile)
	_ = filterRows(in, out, "")
	_ = in.Close()
	_ = out.Close()

	archiveAction := "archive"
	archiveReload := a.self + " --rows"
	if os.Getenv("TMUX_THREAD_SHOW_ARCHIVED") == "1" {
		archiveAction = "unarchive"
		archiveReload = "TMUX_THREAD_SHOW_ARCHIVED=1 " + a.self + " --rows"
	}
	sourceWindowIndex := strings.TrimSpace(a.output(a.tmuxBin, "display-message", "-p", "-t", a.sourcePane, "#{window_index}"))
	sourceTarget := a.sourceSess + ":" + sourceWindowIndex
	fzfRowsFileQ := shellQuote(a.fzfRowsFile)
	filterCurrentQuery := a.self + " --filter-rows {q}"
	filteredRowsCommand := filterCurrentQuery + " < " + fzfRowsFileQ
	reloadRowsCommand := a.self + " --rows | tee " + fzfRowsFileQ + " | " + filterCurrentQuery
	header := fmt.Sprintf("      %s  %s  %s  %s", padText("state", 6), padText("title", 30), padText("path", 56), padText("branch", 56))

	args := []string{
		"--prompt=thread > ",
		"--delimiter=\t",
		"--with-nth=2",
		"--header=" + header,
		"--header-border=line",
		"--footer=Ctrl-n new | Ctrl-r refresh | Ctrl-o worktrees | Ctrl-p pin | Ctrl-t title | Ctrl-x " + archiveAction + " | Alt-f all | Alt-v archived | Enter open",
		"--footer-border=line",
		"--layout=reverse",
		"--border",
		"--ansi",
		"--disabled",
		"--listen=" + filepath.Join(a.tmpDir, "fzf.sock"),
		"--bind", "start:execute-silent(" + a.self + " --watch-fzf " + filepath.Join(a.tmpDir, "fzf.sock") + ")",
		"--bind", "load:transform:[[ {1} = GROUP ]] && echo down",
		"--bind", "result:transform:[[ {1} = GROUP ]] && echo down",
		"--bind", "change:reload(" + filteredRowsCommand + ")+first",
		"--bind", "enter:transform:[[ {1} = GROUP ]] && echo down || echo accept",
		"--bind", "ctrl-p:execute-silent(" + a.self + " --toggle-pin {5})+reload(" + reloadRowsCommand + ")",
		"--bind", "ctrl-q:execute-silent(" + a.self + " --kill-window {1} {3} " + shellQuote(sourceTarget) + ")+reload(" + reloadRowsCommand + ")",
		"--bind", "alt-a:execute-silent(" + a.self + " --toggle-archive {5})+reload(" + archiveReload + " | tee " + fzfRowsFileQ + " | " + filterCurrentQuery + ")",
		"--bind", "ctrl-x:execute-silent(" + a.self + " --toggle-archive {5})+reload(" + archiveReload + " | tee " + fzfRowsFileQ + " | " + filterCurrentQuery + ")",
		"--bind", "alt-f:reload(TMUX_THREAD_ATTENTION_ONLY=0 " + a.self + " --rows | tee " + fzfRowsFileQ + " | " + filterCurrentQuery + ")",
		"--bind", "alt-v:reload(TMUX_THREAD_SHOW_ARCHIVED=1 " + a.self + " --rows | tee " + fzfRowsFileQ + " | " + filterCurrentQuery + ")",
		"--bind", "ctrl-t:execute(" + a.self + " --edit-title {5})+reload(" + reloadRowsCommand + ")",
		"--bind", "ctrl-n:execute(" + a.self + " --new-thread {5})+abort",
		"--bind", "ctrl-r:reload(" + reloadRowsCommand + ")",
		"--bind", "ctrl-o:execute(" + filepath.Join(a.home, ".dotfiles", "bin", "tmux-select-worktree.sh") + ")",
		"--bind", "):clear-query+search(::)",
		"--bind", "(:clear-query+search(::)",
		"--height=100%",
	}
	selected, _ := runInput(a.fzfBin, readLines(a.fzfRowsFile), args...)
	if selected == "" {
		return nil
	}
	parts := strings.Split(selected, "\t")
	switch field(parts, 0) {
	case "GROUP":
		return nil
	case "PICK":
		script := filepath.Join(a.home, ".dotfiles", "bin", "tmux-select-worktree.sh")
		return syscall.Exec(script, []string{script, a.sourceSess, field(parts, 2)}, os.Environ())
	case "OPEN":
		_ = a.markSeenFinished(field(parts, 4))
		return exec.Command(a.tmuxBin, "switch-client", "-t", field(parts, 2)).Run()
	case "WT":
		return a.openThreadWindow(field(parts, 2), field(parts, 3))
	default:
		return errors.New("thread picker: invalid selection")
	}
}

func (a *app) output(name string, args ...string) string {
	if name == "" {
		return ""
	}
	cmd := exec.Command(name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = io.Discard
	if cmd.Run() != nil {
		return ""
	}
	return out.String()
}

func runInput(name string, lines []string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Stdin = strings.NewReader(strings.Join(lines, "\n"))
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	return strings.TrimRight(out.String(), "\n"), err
}

func writeRows(path string, rows []row, includeSort bool) error {
	var lines []string
	for _, r := range rows {
		fields := []string{r.kind, r.display, r.target, r.branch, r.pinKey, r.project}
		if includeSort {
			fields = append([]string{r.sortKey}, fields...)
		}
		fields = append(fields, r.search)
		lines = append(lines, strings.Join(fields, "\t"))
	}
	return writeLines(path, lines)
}

func readRows(path string) []row {
	var out []row
	for _, line := range readLines(path) {
		parts := strings.Split(line, "\t")
		if len(parts) >= 6 {
			out = append(out, row{kind: parts[0], display: field(parts, 1), target: field(parts, 2), branch: field(parts, 3), pinKey: field(parts, 4), project: field(parts, 5), search: field(parts, 6)})
		}
	}
	return out
}

func searchText(value string) string {
	value = stripANSI(value)
	value = strings.ReplaceAll(value, "\t", " ")
	return strings.Join(strings.Fields(value), " ")
}

func sanitizeBranchPath(raw string) string {
	var parts []string
	for _, part := range strings.Split(raw, "/") {
		var b strings.Builder
		for _, r := range part {
			if unicode.IsSpace(r) {
				b.WriteByte('-')
			} else if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '.' || r == '_' || r == '-' {
				b.WriteRune(r)
			}
		}
		safe := b.String()
		if safe == "" || safe == "." || safe == ".." {
			safe = "thread"
		}
		parts = append(parts, safe)
	}
	if len(parts) == 0 {
		return "thread"
	}
	return strings.Join(parts, "/")
}

func padText(value string, width int) string {
	r := []rune(value)
	if len(r) > width {
		if width <= 1 {
			value = "~"
		} else {
			value = string(r[:width-1]) + "~"
		}
	}
	return fmt.Sprintf("%-*s", width, value)
}

func normalizeExistingPath(p string) string {
	for p != "" && p != "/" {
		if _, err := os.Stat(p); err == nil {
			return cleanAbs(p)
		}
		p = filepath.Dir(p)
	}
	if p == "/" {
		return "/"
	}
	return ""
}

func cleanAbs(path string) string {
	abs, err := filepath.Abs(path)
	if err != nil {
		return path
	}
	return abs
}

func readLines(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	text := strings.TrimRight(string(data), "\n")
	if text == "" {
		return nil
	}
	return strings.Split(text, "\n")
}

func writeLines(path string, lines []string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data := ""
	if len(lines) > 0 {
		data = strings.Join(lines, "\n") + "\n"
	}
	return os.WriteFile(path, []byte(data), 0o644)
}

func appendLine(path, line string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = fmt.Fprintln(f, line)
	return err
}

func appendBytes(path string, data []byte) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.Write(data)
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o644)
}

func fileEmpty(path string) bool {
	info, err := os.Stat(path)
	return err != nil || info.Size() == 0
}

func cacheAgeSeconds(path string) (int, bool) {
	if fileEmpty(path) {
		return 0, false
	}
	return fileAgeSeconds(path)
}

func fileAgeSeconds(path string) (int, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, false
	}
	return int(time.Since(info.ModTime()).Seconds()), true
}

func containsLine(path, needle string) bool {
	for _, line := range readLines(path) {
		if line == needle {
			return true
		}
	}
	return false
}

func unique(lines []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, line := range lines {
		if line == "" || seen[line] {
			continue
		}
		seen[line] = true
		out = append(out, line)
	}
	return out
}

func field(fields []string, index int) string {
	if index < len(fields) {
		return fields[index]
	}
	return ""
}

func arg(args []string, index int) string {
	if index < len(args) {
		return args[index]
	}
	return ""
}

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
	}
	return fallback
}

func lookPath(name string, fallbacks ...string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	for _, path := range fallbacks {
		if isExecutable(path) {
			return path
		}
	}
	return ""
}

func isExecutable(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir() && info.Mode()&0o111 != 0
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func containsAny(value string, needles []string) bool {
	for _, needle := range needles {
		if strings.Contains(value, needle) {
			return true
		}
	}
	return false
}

func shellQuote(s string) string {
	if s == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}

func isTerminal(fd uintptr) bool {
	var stat syscall.Stat_t
	if err := syscall.Fstat(int(fd), &stat); err != nil {
		return false
	}
	return stat.Mode&syscall.S_IFMT == syscall.S_IFCHR
}

func substr(s string, start, end int) string {
	r := []rune(s)
	if start < 0 {
		start = 0
	}
	if end > len(r) {
		end = len(r)
	}
	if start > end {
		return ""
	}
	return string(r[start:end])
}
