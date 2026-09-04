package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode"

	tea "github.com/charmbracelet/bubbletea"
)

type row struct {
	Kind       string
	Machine    string
	State      string
	Branch     string
	Target     string
	Workspace  string
	Session    string
	Prompt     string
	Detail     string
	Repo       string
	Updated    int64
	Remote     bool
	RemoteHost bool
	GitSpace   string
	Source     string
	Base       string
}

type threadDraft struct {
	row           row
	cursor        int
	gitSpace      string
	source        string
	defaultBranch string
	project       string
	editingTitle  bool
	promptCursor  int
	killBuffer    string
	showKeymap    bool
}

type app struct {
	gitBin           string
	herdrBin         string
	sshBin           string
	remoteTarget     string
	remoteHerdrBin   string
	remoteSession    string
	localMachine     string
	remoteMachine    string
	remoteOnline     bool
	remoteCached     bool
	remoteLoading    bool
	remoteErr        error
	remoteAttachPane string
	threadsOnly      bool
	newThreadOnly    bool
	sqliteBin        string
	historyDB        string
	historyLoading   bool
	historyLoaded    bool
	historyErr       error
	historyCount     int
	root             string
	rows             []row
}

type palette struct {
	reset   string
	bold    string
	dim     string
	green   string
	yellow  string
	cyan    string
	magenta string
	red     string
	blue    string
}

var c = palette{
	reset:   "\033[0m",
	bold:    "\033[1m",
	dim:     "\033[2m",
	green:   "\033[32m",
	yellow:  "\033[33m",
	cyan:    "\033[36m",
	magenta: "\033[35m",
	red:     "\033[31m",
	blue:    "\033[34m",
}

type model struct {
	app      *app
	allRows  []row
	rows     []row
	cursor   int
	query    string
	width    int
	height   int
	selected *row
	quit     bool
	err      error
	draft    *threadDraft
}

type remoteSnapshotMsg struct {
	data map[string]any
	err  error
}

type historyMsg struct {
	rows []row
	err  error
}

func main() {
	if err := runMain(); err != nil {
		fmt.Fprintf(os.Stderr, "herdr-worktree-picker: %s\n", err)
		os.Exit(1)
	}
}

func runMain() error {
	list := flag.Bool("list", false, "print rows and exit")
	threadsOnly := flag.Bool("threads", false, "show only existing threads")
	newThreadOnly := flag.Bool("new-thread", false, "search and create threads for the current repository")
	selectQuery := flag.String("select", "", "select without opening the UI")
	dryRun := flag.Bool("dry-run", false, "print selected command")
	flag.Parse()
	if *threadsOnly && *newThreadOnly {
		return errors.New("--threads and --new-thread cannot be used together")
	}
	explicitPath := ""
	if flag.NArg() > 0 {
		explicitPath = flag.Arg(0)
	}

	herdrBin := os.Getenv("HERDR_BIN_PATH")
	if herdrBin == "" {
		herdrBin = lookPath("herdr")
	}
	localMachine := "Mac"
	if strings.EqualFold(runtimeOS(), "linux") {
		localMachine = "Ubuntu"
	}
	a := &app{
		gitBin:         lookPath("git"),
		herdrBin:       herdrBin,
		sshBin:         lookPath("ssh"),
		remoteTarget:   firstNonEmpty(os.Getenv("HERDR_UBUNTU_TARGET"), "kylian@kylian-ps42-8rb"),
		remoteHerdrBin: firstNonEmpty(os.Getenv("HERDR_REMOTE_HERDR_BIN"), "/usr/local/bin/herdr"),
		remoteSession:  firstNonEmpty(os.Getenv("HERDR_REMOTE_SESSION"), "default"),
		localMachine:   localMachine,
		remoteMachine:  "Ubuntu",
		threadsOnly:    *threadsOnly,
		newThreadOnly:  *newThreadOnly,
		sqliteBin:      lookPath("sqlite3"),
	}
	if a.herdrBin == "" {
		return errors.New("herdr not found in PATH")
	}
	var rows []row
	var err error
	if a.threadsOnly || a.newThreadOnly {
		if a.gitBin == "" {
			if a.newThreadOnly {
				return errors.New("git not found in PATH")
			}
		} else if source, sourceErr := a.sourcePath(explicitPath); sourceErr == nil {
			a.root, _ = a.repoRoot(source)
		} else if a.newThreadOnly || explicitPath != "" {
			return sourceErr
		}
		if a.newThreadOnly && a.root == "" {
			return errors.New("unable to resolve the current Git repository")
		}
		a.historyDB, err = a.findHistoryDB()
		if err != nil {
			a.historyErr = err
		}
		rows = a.buildThreadRows()
		if a.root != "" {
			rows = append(a.newThreadRows(""), rows...)
		}
	} else {
		if a.gitBin == "" {
			return errors.New("git not found in PATH")
		}
		source, sourceErr := a.sourcePath(explicitPath)
		if sourceErr != nil {
			return sourceErr
		}
		a.root, err = a.repoRoot(source)
		if err == nil {
			rows, err = a.buildWorktreeRows()
		}
	}
	if err != nil {
		return err
	}
	rows = a.filterModeRows(rows)
	if (a.threadsOnly || a.newThreadOnly) && (*list || *selectQuery != "") {
		history, historyErr := a.loadHistoryRows()
		if historyErr != nil {
			return historyErr
		}
		merge := model{app: a, allRows: rows}
		merge.applyHistoryRows(history)
		rows = merge.allRows
	}
	a.rows = rows

	if *list {
		for _, r := range rows {
			fmt.Println(r.tsv())
		}
		return nil
	}
	if *selectQuery != "" {
		selected, ok := chooseNonInteractive(rows, *selectQuery)
		if !ok {
			return fmt.Errorf("no thread/worktree/branch matches selector: %s", *selectQuery)
		}
		return a.openRow(selected, *dryRun)
	}

	m := newModel(a, rows)
	finalModel, err := tea.NewProgram(m, tea.WithAltScreen(), tea.WithFPS(15)).Run()
	if err != nil {
		return err
	}
	result, ok := finalModel.(model)
	if !ok || result.selected == nil {
		return nil
	}
	return a.openRow(*result.selected, *dryRun)
}

func filterThreadRows(rows []row) []row {
	filtered := make([]row, 0, len(rows))
	for _, candidate := range rows {
		if candidate.Kind == "NEW" || candidate.Kind == "TH" || candidate.Kind == "HIST" {
			filtered = append(filtered, candidate)
		}
	}
	return filtered
}

func filterWorktreeRows(rows []row) []row {
	filtered := make([]row, 0, len(rows))
	for _, candidate := range rows {
		if candidate.Kind == "WT" || candidate.Kind == "BR" || candidate.Kind == "RB" {
			filtered = append(filtered, candidate)
		}
	}
	return filtered
}

func (a *app) filterModeRows(rows []row) []row {
	if a.threadsOnly || a.newThreadOnly {
		rows = filterThreadRows(rows)
		if a.newThreadOnly {
			rows = a.filterCurrentRepoRows(rows)
		}
		return rows
	}
	return filterWorktreeRows(rows)
}

func (a *app) filterCurrentRepoRows(rows []row) []row {
	current := a.repoKeyForPath(a.root)
	project := strings.ToLower(a.projectName())
	filtered := make([]row, 0, len(rows))
	for _, candidate := range rows {
		if candidate.Kind == "NEW" {
			filtered = append(filtered, candidate)
			continue
		}
		rowKey := normalizeRepoKey(candidate.Repo)
		matches := current != "" && rowKey == current
		if !matches && rowKey != "" {
			matches = strings.EqualFold(filepath.Base(rowKey), project)
		}
		if !matches && candidate.Target != "" && filepath.IsAbs(candidate.Target) {
			matches = pathWithin(candidate.Target, a.root)
		}
		if matches {
			filtered = append(filtered, candidate)
		}
	}
	return filtered
}

func pathWithin(path, root string) bool {
	if path == "" || root == "" {
		return false
	}
	path = filepath.Clean(path)
	root = filepath.Clean(root)
	relative, err := filepath.Rel(root, path)
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func (a *app) repoKeyForPath(path string) string {
	if path == "" || a.gitBin == "" {
		return ""
	}
	remote := a.output(a.gitBin, "-C", path, "remote", "get-url", "origin")
	if remote != "" {
		return normalizeRepoKey(remote)
	}
	common := a.output(a.gitBin, "-C", path, "rev-parse", "--git-common-dir")
	if common == "" {
		return ""
	}
	if !filepath.IsAbs(common) {
		common = filepath.Join(path, common)
	}
	resolved, err := filepath.EvalSymlinks(common)
	if err == nil {
		common = resolved
	}
	return strings.ToLower(strings.TrimSuffix(filepath.Clean(common), string(filepath.Separator)+".git"))
}

func normalizeRepoKey(value string) string {
	value = strings.TrimSpace(value)
	if split := strings.Index(value, "://"); split >= 0 {
		value = value[split+3:]
	} else if at := strings.Index(value, "@"); at >= 0 {
		value = value[at+1:]
		value = strings.Replace(value, ":", "/", 1)
	}
	value = strings.TrimSuffix(strings.TrimRight(value, "/"), ".git")
	return strings.ToLower(value)
}

func runtimeOS() string {
	return aOutput(lookPath("uname"), "-s")
}

func aOutput(name string, args ...string) string {
	if name == "" {
		return ""
	}
	cmd := exec.Command(name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = bytes.NewBuffer(nil)
	if cmd.Run() != nil {
		return ""
	}
	return strings.TrimSpace(out.String())
}

func lookPath(name string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	return ""
}

func (a *app) output(name string, args ...string) string {
	return a.outputWithTimeout(0, name, args...)
}

func (a *app) outputWithTimeout(timeout time.Duration, name string, args ...string) string {
	if name == "" {
		return ""
	}
	ctx := context.Background()
	var cancel context.CancelFunc
	if timeout > 0 {
		ctx, cancel = context.WithTimeout(ctx, timeout)
		defer cancel()
	}
	cmd := exec.CommandContext(ctx, name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = bytes.NewBuffer(nil)
	if cmd.Run() != nil {
		return ""
	}
	return strings.TrimSpace(out.String())
}

func decodeJSON(raw string) (map[string]any, error) {
	if raw == "" {
		return nil, errors.New("command returned no JSON")
	}
	var data map[string]any
	if err := json.Unmarshal([]byte(raw), &data); err != nil {
		return nil, err
	}
	return data, nil
}

func (a *app) herdrJSON(args ...string) (map[string]any, error) {
	out := a.output(a.herdrBin, args...)
	if out == "" {
		return nil, fmt.Errorf("herdr %s returned no JSON", strings.Join(args, " "))
	}
	return decodeJSON(out)
}

func (a *app) fetchRemoteSnapshot() (map[string]any, error) {
	if a.sshBin == "" {
		return nil, errors.New("ssh not found in PATH")
	}
	out := a.outputWithTimeout(
		2500*time.Millisecond,
		a.sshBin,
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=2",
		"-o", "ConnectionAttempts=1",
		"-o", "ControlMaster=auto",
		"-o", "ControlPersist=10m",
		"-o", "ControlPath=/tmp/herdr-alt-o-%C",
		a.remoteTarget,
		"env", "HERDR_SESSION="+a.remoteSession,
		a.remoteHerdrBin, "api", "snapshot",
	)
	data, err := decodeJSON(out)
	if err == nil {
		a.saveRemoteSnapshot(data)
	}
	return data, err
}

func (a *app) remoteSnapshotCachePath() string {
	cacheRoot := os.Getenv("XDG_CACHE_HOME")
	if cacheRoot == "" {
		if home, err := os.UserHomeDir(); err == nil {
			cacheRoot = filepath.Join(home, ".cache")
		}
	}
	if cacheRoot == "" {
		return ""
	}
	return filepath.Join(cacheRoot, "herdr-worktree-picker", "ubuntu-snapshot.json")
}

func (a *app) saveRemoteSnapshot(data map[string]any) {
	path := a.remoteSnapshotCachePath()
	if path == "" {
		return
	}
	encoded, err := json.Marshal(data)
	if err != nil || os.MkdirAll(filepath.Dir(path), 0o755) != nil {
		return
	}
	_ = os.WriteFile(path, encoded, 0o600)
}

func (a *app) loadRemoteSnapshot() (map[string]any, error) {
	path := a.remoteSnapshotCachePath()
	if path == "" {
		return nil, errors.New("cache path unavailable")
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return decodeJSON(string(raw))
}

func (a *app) findHistoryDB() (string, error) {
	if a.sqliteBin == "" {
		return "", errors.New("sqlite3 is not installed")
	}
	if configured := os.Getenv("HERDR_CODEX_STATE_DB"); configured != "" {
		if _, err := os.Stat(configured); err != nil {
			return "", fmt.Errorf("Codex history database: %w", err)
		}
		return configured, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	candidates, err := filepath.Glob(filepath.Join(home, ".codex", "state_*.sqlite"))
	if err != nil || len(candidates) == 0 {
		return "", errors.New("Codex history database was not found")
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		iInfo, iErr := os.Stat(candidates[i])
		jInfo, jErr := os.Stat(candidates[j])
		if iErr != nil || jErr != nil {
			return candidates[i] > candidates[j]
		}
		return iInfo.ModTime().After(jInfo.ModTime())
	})
	return candidates[0], nil
}

type historyRecord struct {
	ID      string `json:"id"`
	CWD     string `json:"cwd"`
	Title   string `json:"title"`
	Updated int64  `json:"updated"`
}

func (a *app) loadHistoryRows() ([]row, error) {
	if a.historyDB == "" {
		return nil, firstError(a.historyErr, errors.New("Codex history database is unavailable"))
	}
	query := `SELECT id, cwd,
COALESCE(NULLIF(name, ''), NULLIF(title, ''), NULLIF(substr(first_user_message, 1, 240), ''), 'Codex thread') AS title,
recency_at AS updated
FROM threads
WHERE archived = 0 AND preview <> '' AND source IN ('cli', 'vscode')
ORDER BY recency_at DESC, id DESC;`
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, a.sqliteBin, "-readonly", "-json", a.historyDB, query)
	var stdout, stderr bytes.Buffer
	command.Stdout = &stdout
	command.Stderr = &stderr
	if err := command.Run(); err != nil {
		detail := strings.TrimSpace(stderr.String())
		if ctx.Err() != nil {
			return nil, errors.New("Codex history load timed out")
		}
		if detail == "" {
			detail = err.Error()
		}
		return nil, fmt.Errorf("Codex history load failed: %s", detail)
	}
	var records []historyRecord
	if err := json.Unmarshal(stdout.Bytes(), &records); err != nil {
		return nil, fmt.Errorf("Codex history returned invalid data: %w", err)
	}
	rows := make([]row, 0, len(records))
	pathStates := make(map[string]string)
	for _, record := range records {
		if record.ID == "" {
			continue
		}
		title := oneLine(record.Title)
		if title == "" {
			title = "Codex thread"
		}
		detail := record.CWD
		state, known := pathStates[record.CWD]
		if !known {
			state = "history"
			if info, statErr := os.Stat(record.CWD); statErr != nil || !info.IsDir() {
				state = "missing"
			}
			pathStates[record.CWD] = state
		}
		if record.Updated > 0 {
			detail = strings.TrimSpace(fmt.Sprintf("%s · %s", record.CWD, time.Unix(record.Updated, 0).Format("2006-01-02")))
		}
		if state == "missing" {
			detail = "path unavailable · " + detail
		}
		rows = append(rows, row{
			Kind: "HIST", Machine: a.localMachine, State: state, Branch: title,
			Target: record.CWD, Session: record.ID, Detail: detail,
			Repo: filepath.Base(record.CWD), Updated: record.Updated,
		})
	}
	return rows, nil
}

func oneLine(value string) string {
	return strings.Join(strings.Fields(value), " ")
}

func firstError(values ...error) error {
	for _, value := range values {
		if value != nil {
			return value
		}
	}
	return nil
}

func normalizeExistingPath(path string) string {
	if path == "" {
		return ""
	}
	if strings.HasPrefix(path, "~") {
		if home, err := os.UserHomeDir(); err == nil {
			path = filepath.Join(home, strings.TrimPrefix(path, "~"))
		}
	}
	if !filepath.IsAbs(path) {
		if cwd, err := os.Getwd(); err == nil {
			path = filepath.Join(cwd, path)
		}
	}
	for {
		if info, err := os.Stat(path); err == nil && info.IsDir() {
			if abs, err := filepath.EvalSymlinks(path); err == nil {
				return abs
			}
			if abs, err := filepath.Abs(path); err == nil {
				return abs
			}
			return path
		}
		parent := filepath.Dir(path)
		if parent == path {
			return ""
		}
		path = parent
	}
}

func (a *app) sourcePath(explicit string) (string, error) {
	if explicit != "" {
		path := normalizeExistingPath(explicit)
		if path == "" {
			return "", fmt.Errorf("invalid source path: %s", explicit)
		}
		return path, nil
	}
	var candidates []string
	// Prefer the pane that invoked the picker. The globally focused workspace can
	// briefly point at another repository while commands are running elsewhere.
	if data, err := a.herdrJSON("pane", "current", "--current"); err == nil {
		pane := jsonMap(jsonMap(data, "result"), "pane")
		candidates = append(candidates, jsonString(pane, "foreground_cwd"), jsonString(pane, "cwd"))
	}
	if data, err := a.herdrJSON("workspace", "list"); err == nil {
		for _, item := range jsonArray(jsonMap(data, "result"), "workspaces") {
			workspace := item.(map[string]any)
			if !jsonBool(workspace, "focused") {
				continue
			}
			worktree := jsonMap(workspace, "worktree")
			candidates = append(candidates, jsonString(worktree, "repo_root"), jsonString(worktree, "checkout_path"))
			break
		}
	}
	candidates = append(candidates, os.Getenv("PWD"))
	if cwd, err := os.Getwd(); err == nil {
		candidates = append(candidates, cwd)
	}
	for _, candidate := range candidates {
		path := normalizeExistingPath(candidate)
		if path != "" {
			if _, repoErr := a.repoRoot(path); repoErr == nil {
				return path, nil
			}
		}
	}
	return "", errors.New("unable to resolve source git path")
}

func (a *app) repoRoot(path string) (string, error) {
	common := a.output(a.gitBin, "-C", path, "rev-parse", "--git-common-dir")
	if common != "" {
		if !filepath.IsAbs(common) {
			common = filepath.Join(path, common)
		}
		if a.output(a.gitBin, "-C", common, "rev-parse", "--is-bare-repository") == "true" {
			return common, nil
		}
	}
	top := a.output(a.gitBin, "-C", path, "rev-parse", "--show-toplevel")
	if top != "" {
		return top, nil
	}
	if linkedRoot := a.linkedRepoRoot(path); linkedRoot != "" {
		return linkedRoot, nil
	}
	return "", fmt.Errorf("not in a git repository: %s", path)
}

func (a *app) linkedRepoRoot(path string) string {
	raw, err := os.ReadFile(filepath.Join(path, ".git"))
	if err != nil {
		return ""
	}
	gitDir := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(string(raw)), "gitdir:"))
	marker := string(filepath.Separator) + "worktrees" + string(filepath.Separator)
	index := strings.LastIndex(gitDir, marker)
	if index < 0 {
		return ""
	}
	root := gitDir[:index]
	if a.output(a.gitBin, "-C", root, "rev-parse", "--is-bare-repository") == "true" {
		return root
	}
	return ""
}

func (a *app) buildThreadRows() []row {
	localSnapshot, _ := a.herdrJSON("api", "snapshot")
	threadRows := a.snapshotRows(localSnapshot, a.localMachine, false)
	if a.localMachine != a.remoteMachine {
		remoteSnapshot, err := a.loadRemoteSnapshot()
		if err == nil {
			a.remoteCached = true
			threadRows = append(threadRows, a.snapshotRows(remoteSnapshot, a.remoteMachine, true)...)
		}
	}
	sortRows(threadRows)
	return threadRows
}

func (a *app) buildWorktreeRows() ([]row, error) {
	data, err := a.herdrJSON("worktree", "list", "--cwd", a.root, "--json")
	if err != nil {
		return nil, err
	}
	result := jsonMap(data, "result")
	source := jsonMap(result, "source")
	repoName := strings.TrimSuffix(firstNonEmpty(jsonString(source, "repo_name"), filepath.Base(a.root)), ".git")
	refTimes := a.refTimes()
	existingBranches := map[string]bool{}
	var out []row
	for _, item := range jsonArray(result, "worktrees") {
		wt := item.(map[string]any)
		path := jsonString(wt, "path")
		if path == "" {
			continue
		}
		branch := firstNonEmpty(jsonString(wt, "branch"), filepath.Base(path))
		if jsonBool(wt, "is_bare") && jsonString(wt, "branch") == "" {
			branch = "(bare)"
		}
		if jsonString(wt, "branch") != "" {
			existingBranches[jsonString(wt, "branch")] = true
		}
		state := "worktree"
		if jsonString(wt, "open_workspace_id") != "" {
			state = "open"
		}
		updated := refTimes[jsonString(wt, "branch")]
		if updated == 0 && !jsonBool(wt, "is_bare") {
			updated = a.commitTime(path, "HEAD")
		}
		out = append(out, row{Kind: "WT", Machine: a.localMachine, State: state, Branch: branch, Target: path, Workspace: jsonString(wt, "open_workspace_id"), Detail: path, Repo: repoName, Updated: updated})
	}
	localBranches := a.branchRefs("refs/heads")
	localSet := map[string]bool{}
	for _, branch := range localBranches {
		localSet[branch] = true
		if existingBranches[branch] {
			continue
		}
		out = append(out, row{Kind: "BR", Machine: a.localMachine, State: "branch", Branch: branch, Target: branch, Detail: "local branch", Repo: repoName, Updated: refTimes[branch]})
	}
	for _, remote := range a.branchRefs("refs/remotes") {
		branch := remoteLocalName(remote)
		if branch == "" || existingBranches[branch] || localSet[branch] {
			continue
		}
		out = append(out, row{Kind: "RB", Machine: a.localMachine, State: "remote", Branch: branch, Target: remote, Detail: remote, Repo: repoName, Updated: refTimes[remote]})
	}
	sortRows(out)
	return out, nil
}

func sortRows(rows []row) {
	sort.SliceStable(rows, func(i, j int) bool {
		iPriority := rowPriority(rows[i])
		jPriority := rowPriority(rows[j])
		if iPriority != jPriority {
			return iPriority < jPriority
		}
		if rows[i].Updated == rows[j].Updated {
			return rows[i].Branch < rows[j].Branch
		}
		return rows[i].Updated > rows[j].Updated
	})
}

func (a *app) newThreadRows(prompt string) []row {
	detail := "start a blank thread"
	if prompt != "" {
		detail = prompt
	}
	return []row{{
		Kind: "NEW", Machine: a.localMachine, State: "new", Branch: "New thread",
		Target: "mac", Prompt: prompt, Detail: detail,
	}}
}

func (a *app) defaultBranch() string {
	if a.root == "" {
		return "main"
	}
	branch := a.output(a.gitBin, "-C", a.root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
	if strings.HasPrefix(branch, "origin/") {
		return strings.TrimPrefix(branch, "origin/")
	}
	branch = a.output(a.gitBin, "-C", a.root, "branch", "--show-current")
	return firstNonEmpty(branch, "main")
}

func (a *app) projectName() string {
	if a.root == "" {
		return "project"
	}
	remote := a.output(a.gitBin, "-C", a.root, "remote", "get-url", "origin")
	if remote != "" {
		return strings.TrimSuffix(filepath.Base(remote), ".git")
	}
	return strings.TrimSuffix(filepath.Base(a.root), ".git")
}

type workspaceSnapshot struct {
	label string
	repo  string
	path  string
}

func (a *app) snapshotRows(data map[string]any, machine string, remote bool) []row {
	result := jsonMap(data, "result")
	snapshot := jsonMap(result, "snapshot")
	workspaces := make(map[string]workspaceSnapshot)
	var rows []row

	for _, item := range jsonArray(snapshot, "workspaces") {
		workspace, ok := item.(map[string]any)
		if !ok {
			continue
		}
		workspaceID := jsonString(workspace, "workspace_id")
		repository := jsonMap(workspace, "repository")
		worktree := jsonMap(workspace, "worktree")
		path := firstNonEmpty(jsonString(repository, "checkout_path"), jsonString(worktree, "checkout_path"))
		repo := firstNonEmpty(jsonString(repository, "portable_repo_key"), jsonString(repository, "repo_name"), jsonString(worktree, "repo_name"))
		label := firstNonEmpty(jsonString(workspace, "label"), filepath.Base(path))
		workspaces[workspaceID] = workspaceSnapshot{label: label, repo: repo, path: path}

		if remote && path != "" {
			rows = append(rows, row{
				Kind: "WT", Machine: machine, State: "worktree", Branch: label,
				Target: path, Workspace: workspaceID, Detail: path, Repo: repo,
				Remote: true,
			})
		}
	}

	for _, item := range jsonArray(snapshot, "agents") {
		agent, ok := item.(map[string]any)
		if !ok {
			continue
		}
		name := jsonString(agent, "name")
		displayAgent := jsonString(agent, "display_agent")
		if !remote && strings.HasPrefix(name, "ubuntu-session") && strings.Contains(displayAgent, "Ubuntu") {
			a.remoteAttachPane = jsonString(agent, "pane_id")
			continue
		}
		directRemote := !remote && strings.HasPrefix(name, "ubuntu-codex") && strings.Contains(displayAgent, "Ubuntu")
		rowMachine := machine
		if directRemote {
			rowMachine = firstNonEmpty(a.remoteMachine, "Ubuntu")
		}
		workspaceID := jsonString(agent, "workspace_id")
		workspace := workspaces[workspaceID]
		cwd := firstNonEmpty(jsonString(agent, "foreground_cwd"), jsonString(agent, "cwd"), workspace.path)
		title := firstNonEmpty(name, jsonString(agent, "title"), jsonString(agent, "terminal_title_stripped"), workspace.label, filepath.Base(cwd))
		session := jsonString(jsonMap(agent, "agent_session"), "value")
		detail := cwd
		if session != "" {
			detail = firstNonEmpty(workspace.repo, cwd) + " · " + shortSession(session)
		}
		rows = append(rows, row{
			Kind: "TH", Machine: rowMachine, State: jsonString(agent, "agent_status"),
			Branch: title, Target: jsonString(agent, "pane_id"), Workspace: workspaceID,
			Session: session, Detail: detail, Repo: workspace.repo,
			Updated: jsonInt64(agent, "state_change_seq"), Remote: remote, RemoteHost: directRemote,
		})
	}
	return rows
}

func shortSession(session string) string {
	if len(session) <= 12 {
		return session
	}
	return session[:12]
}

func rowPriority(r row) int {
	if r.Kind == "NEW" {
		return 0
	}
	if r.Kind == "TH" {
		switch r.State {
		case "blocked":
			return 1
		case "working":
			return 2
		default:
			return 3
		}
	}
	switch r.Kind {
	case "HIST":
		return 4
	case "WT":
		return 5
	case "BR":
		return 6
	case "RB":
		return 7
	default:
		return 8
	}
}

// refTimes batches timestamp lookup for every local and remote branch into one
// Git process. The old per-row `git show` made picker latency grow with the
// number of branches.
func (a *app) refTimes() map[string]int64 {
	out := a.output(a.gitBin, "-C", a.root, "for-each-ref", "--format=%(refname:short)%09%(committerdate:unix)", "refs/heads", "refs/remotes")
	times := make(map[string]int64)
	for _, line := range strings.Split(out, "\n") {
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) != 2 {
			continue
		}
		times[parts[0]], _ = strconv.ParseInt(parts[1], 10, 64)
	}
	return times
}

func (a *app) commitTime(path, ref string) int64 {
	raw := a.output(a.gitBin, "-C", path, "show", "-s", "--format=%ct", ref)
	updated, _ := strconv.ParseInt(strings.TrimSpace(raw), 10, 64)
	return updated
}

func (a *app) branchRefs(namespace string) []string {
	out := a.output(a.gitBin, "-C", a.root, "for-each-ref", "--format=%(refname:short)", namespace)
	var rows []string
	for _, line := range strings.Split(out, "\n") {
		branch := strings.TrimSpace(line)
		if branch == "" {
			continue
		}
		if namespace == "refs/remotes" && (!strings.Contains(branch, "/") || strings.HasSuffix(branch, "/HEAD")) {
			continue
		}
		rows = append(rows, branch)
	}
	sort.Strings(rows)
	return unique(rows)
}

func (a *app) openRow(r row, dryRun bool) error {
	if r.Kind == "NEW" {
		return a.openNewThread(r, dryRun)
	}
	if r.Kind == "HIST" {
		return a.openHistoryThread(r, dryRun)
	}
	if r.Remote {
		return a.openRemoteRow(r, dryRun)
	}
	var args []string
	switch r.Kind {
	case "TH":
		args = []string{"agent", "focus", r.Target}
	case "WT":
		if r.Workspace != "" {
			args = []string{"workspace", "focus", r.Workspace}
		} else {
			args = []string{"worktree", "open", "--cwd", a.root, "--path", r.Target, "--label", r.Branch, "--focus", "--json"}
		}
	case "BR":
		branch := sanitizeBranch(r.Branch)
		args = []string{"worktree", "create", "--cwd", a.root, "--branch", branch, "--label", branch, "--focus"}
	case "RB":
		branch := sanitizeBranch(r.Branch)
		args = []string{"worktree", "create", "--cwd", a.root, "--branch", branch, "--base", r.Target, "--label", branch, "--focus"}
	default:
		return fmt.Errorf("unknown row kind: %s", r.Kind)
	}
	if dryRun {
		fmt.Println("herdr " + strings.Join(args, " "))
		return nil
	}
	cmd := exec.Command(a.herdrBin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (a *app) openHistoryThread(r row, dryRun bool) error {
	if r.Session == "" {
		return errors.New("saved thread has no session id")
	}
	info, err := os.Stat(r.Target)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("saved path is not available: %s", r.Target)
	}
	savedPath, err := filepath.EvalSymlinks(r.Target)
	if err != nil {
		return fmt.Errorf("saved path is not available: %s", r.Target)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	launcher := filepath.Join(home, ".dotfiles/bin/herdr-start-codex")
	args := []string{"mac", "--project-path", savedPath, "--resume", r.Session}
	if dryRun {
		fmt.Printf("%s %s\n", launcher, strings.Join(args, " "))
		return nil
	}
	command := exec.Command(launcher, args...)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	return command.Run()
}

func (a *app) openNewThread(r row, dryRun bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	launcher := filepath.Join(home, ".dotfiles/bin/herdr-start-codex")
	args := newThreadLaunchArgs(r, a.root, a.defaultBranch(), time.Now())
	if dryRun {
		fmt.Printf("%s %s\n", launcher, strings.Join(args, " "))
		return nil
	}
	command := exec.Command(launcher, args...)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	return command.Run()
}

func newThreadLaunchArgs(r row, projectPath, fallbackBase string, now time.Time) []string {
	gitSpace := firstNonEmpty(r.GitSpace, "worktree")
	source := firstNonEmpty(r.Source, "origin")
	base := firstNonEmpty(r.Base, fallbackBase)
	args := []string{
		r.Target,
		"--project-path", projectPath,
		"--git-space", gitSpace,
		"--source", source,
		"--default-branch", base,
	}
	if gitSpace == "worktree" {
		args = append(args,
			"--thread-title", generatedThreadTitle(r.Prompt),
			"--new-worktree", threadBranch(r.Prompt, now),
		)
	}
	if r.Prompt != "" {
		args = append(args, "--prompt", r.Prompt)
	}
	return args
}

func threadBranch(prompt string, now time.Time) string {
	label := strings.ToLower(generatedThreadTitle(prompt))
	label = strings.Trim(sanitizeBranch(label), "-./")
	if label == "" {
		label = "new"
	}
	if len(label) > 48 {
		label = strings.TrimRight(label[:48], "-.")
	}
	return fmt.Sprintf("thread/%s-%s", label, now.Format("20060102-150405"))
}

func generatedThreadTitle(prompt string) string {
	words := strings.Fields(oneLine(prompt))
	if len(words) == 0 {
		return "New thread"
	}
	truncated := false
	if len(words) > 7 {
		words = words[:7]
		truncated = true
	}
	title := strings.Join(words, " ")
	runes := []rune(title)
	if len(runes) > 52 {
		title = strings.TrimSpace(string(runes[:52]))
		if space := strings.LastIndex(title, " "); space >= 24 {
			title = title[:space]
		}
		truncated = true
	}
	title = strings.Trim(title, " \t\n.,:;-_")
	if title == "" {
		return "New thread"
	}
	if truncated {
		title += "…"
	}
	return title
}

func (a *app) openRemoteRow(r row, dryRun bool) error {
	var remoteArgs []string
	switch r.Kind {
	case "TH":
		remoteArgs = []string{"agent", "focus", r.Target}
	case "WT":
		remoteArgs = []string{"workspace", "focus", r.Workspace}
	default:
		return fmt.Errorf("unsupported remote row kind: %s", r.Kind)
	}
	sshArgs := []string{
		"-o", "BatchMode=yes",
		"-o", "ControlMaster=auto",
		"-o", "ControlPersist=10m",
		"-o", "ControlPath=/tmp/herdr-alt-o-%C",
		a.remoteTarget,
		"env", "HERDR_SESSION=" + a.remoteSession,
		a.remoteHerdrBin,
	}
	sshArgs = append(sshArgs, remoteArgs...)
	if dryRun {
		fmt.Printf("ssh %s\n", strings.Join(sshArgs, " "))
		return nil
	}
	command := exec.Command(a.sshBin, sshArgs...)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	if err := command.Run(); err != nil {
		return err
	}
	if a.remoteAttachPane != "" {
		return exec.Command(a.herdrBin, "agent", "focus", a.remoteAttachPane).Run()
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	attach := exec.Command(filepath.Join(home, ".dotfiles/bin/herdr-start-codex"), "ubuntu-attach")
	attach.Stdout = os.Stdout
	attach.Stderr = os.Stderr
	return attach.Run()
}

func newModel(a *app, rows []row) model {
	if a.localMachine != a.remoteMachine {
		a.remoteLoading = true
	}
	if (a.threadsOnly || a.newThreadOnly) && a.historyErr == nil {
		a.historyLoading = true
	}
	m := model{app: a, allRows: rows, width: 100, height: 24}
	m.applyFilter(true)
	return m
}

func (m model) Init() tea.Cmd {
	var commands []tea.Cmd
	if m.app.localMachine != m.app.remoteMachine {
		commands = append(commands, func() tea.Msg {
			data, err := m.app.fetchRemoteSnapshot()
			return remoteSnapshotMsg{data: data, err: err}
		})
	}
	if (m.app.threadsOnly || m.app.newThreadOnly) && m.app.historyErr == nil {
		commands = append(commands, func() tea.Msg {
			rows, err := m.app.loadHistoryRows()
			return historyMsg{rows: rows, err: err}
		})
	}
	return tea.Batch(commands...)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case remoteSnapshotMsg:
		m.app.remoteLoading = false
		if msg.err == nil {
			m.applyRemoteSnapshot(msg.data)
		} else {
			m.app.remoteErr = msg.err
		}
	case historyMsg:
		m.app.historyLoading = false
		m.app.historyLoaded = msg.err == nil
		m.app.historyErr = msg.err
		if msg.err == nil {
			m.applyHistoryRows(msg.rows)
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		if m.draft != nil {
			return m.updateThreadDraft(msg.String())
		}
		switch msg.String() {
		case "ctrl+c", "esc":
			m.quit = true
			return m, tea.Quit
		case "enter":
			if len(m.rows) > 0 {
				selected := m.rows[m.cursor]
				if selected.Kind == "NEW" {
					m.beginThreadDraft(selected)
					return m, nil
				}
				m.selected = &selected
			}
			m.quit = true
			return m, tea.Quit
		case "up", "ctrl+k":
			m.move(-1)
		case "down", "ctrl+j":
			m.move(1)
		case "backspace", "ctrl+h":
			if m.query != "" {
				runes := []rune(m.query)
				m.query = string(runes[:len(runes)-1])
				m.applyFilter(true)
			}
		case "ctrl+u":
			m.query = ""
			m.applyFilter(true)
		default:
			if len(msg.Runes) > 0 {
				m.query += string(msg.Runes)
				m.applyFilter(true)
			}
		}
	}
	return m, nil
}

func (m *model) beginThreadDraft(selected row) {
	m.draft = &threadDraft{
		row:           selected,
		gitSpace:      "worktree",
		source:        "origin",
		defaultBranch: m.app.defaultBranch(),
		project:       m.app.projectName(),
		editingTitle:  true,
		promptCursor:  len([]rune(selected.Prompt)),
	}
}

func (m model) updateThreadDraft(key string) (tea.Model, tea.Cmd) {
	if m.draft == nil {
		return m, nil
	}
	if m.draft.editingTitle {
		return m.updateThreadTitle(key)
	}
	if m.draft.showKeymap {
		return m.updateThreadKeymap(key)
	}
	switch key {
	case "ctrl+c", "q":
		m.quit = true
		return m, tea.Quit
	case "esc":
		m.draft = nil
		return m, nil
	case "enter":
		if strings.TrimSpace(m.draft.row.Prompt) == "" {
			m.draft.editingTitle = true
			return m, nil
		}
		return m.finishThreadDraft()
	case "up", "k", "shift+tab":
		m.draft.cursor = (m.draft.cursor + 2) % 3
	case "down", "j", "tab":
		m.draft.cursor = (m.draft.cursor + 1) % 3
	case "left", "right", "h", "l", " ", "space":
		m.toggleThreadDraftField(m.draft.cursor)
	case "m":
		m.draft.cursor = 0
		m.toggleThreadDraftField(0)
	case "w":
		m.draft.cursor = 1
		m.toggleThreadDraftField(1)
	case "o":
		m.draft.cursor = 2
		m.toggleThreadDraftField(2)
	case "t":
		m.draft.editingTitle = true
		m.draft.promptCursor = len([]rune(m.draft.row.Prompt))
	case "alt+?":
		m.draft.showKeymap = true
	}
	return m, nil
}

func (m model) updateThreadTitle(key string) (tea.Model, tea.Cmd) {
	if m.draft == nil {
		return m, nil
	}
	switch key {
	case "ctrl+c":
		m.quit = true
		return m, tea.Quit
	case "esc":
		m.draft = nil
	case "enter":
		m.draft.row.Prompt = strings.TrimSpace(m.draft.row.Prompt)
		if m.draft.row.Prompt != "" {
			return m.finishThreadDraft()
		}
	case "tab":
		m.draft.editingTitle = false
		m.draft.cursor = 0
	case "shift+tab":
		m.draft.editingTitle = false
		m.draft.cursor = 2
	case "alt+m":
		m.toggleThreadDraftField(0)
	case "alt+w":
		m.toggleThreadDraftField(1)
	case "alt+o":
		m.toggleThreadDraftField(2)
	case "alt+?":
		m.draft.showKeymap = true
		m.draft.editingTitle = false
	case "left", "ctrl+b":
		m.draft.promptCursor = max(0, m.draft.promptCursor-1)
	case "right", "ctrl+f":
		m.draft.promptCursor = min(len([]rune(m.draft.row.Prompt)), m.draft.promptCursor+1)
	case "home", "ctrl+a":
		m.draft.promptCursor = 0
	case "end", "ctrl+e":
		m.draft.promptCursor = len([]rune(m.draft.row.Prompt))
	case "alt+b", "alt+left", "ctrl+left":
		m.draft.promptCursor = previousWordBoundary([]rune(m.draft.row.Prompt), m.draft.promptCursor)
	case "alt+f", "alt+right", "ctrl+right":
		m.draft.promptCursor = nextWordBoundary([]rune(m.draft.row.Prompt), m.draft.promptCursor)
	case "ctrl+w", "alt+backspace":
		m.deletePromptRange(previousWordBoundary([]rune(m.draft.row.Prompt), m.draft.promptCursor), m.draft.promptCursor)
	case "alt+d":
		m.deletePromptRange(m.draft.promptCursor, nextWordBoundary([]rune(m.draft.row.Prompt), m.draft.promptCursor))
	case "ctrl+u":
		m.deletePromptRange(0, m.draft.promptCursor)
	case "ctrl+k":
		m.deletePromptRange(m.draft.promptCursor, len([]rune(m.draft.row.Prompt)))
	case "delete", "ctrl+d":
		m.deletePromptRange(m.draft.promptCursor, min(len([]rune(m.draft.row.Prompt)), m.draft.promptCursor+1))
	case "ctrl+y":
		m.insertPrompt(m.draft.killBuffer)
	case "ctrl+t":
		m.transposePromptCharacters()
	case "ctrl+l":
		return m, nil
	case "backspace", "ctrl+h":
		m.deletePromptRange(max(0, m.draft.promptCursor-1), m.draft.promptCursor)
	default:
		printable := make([]rune, 0, len([]rune(key)))
		for _, character := range []rune(key) {
			if character >= ' ' && character != 0x7f {
				printable = append(printable, character)
			}
		}
		if len(printable) > 0 {
			m.insertPrompt(string(printable))
		}
	}
	return m, nil
}

func (m model) updateThreadKeymap(key string) (tea.Model, tea.Cmd) {
	if m.draft == nil {
		return m, nil
	}
	switch key {
	case "ctrl+c":
		m.quit = true
		return m, tea.Quit
	case "esc", "alt+?", "enter":
		m.draft.showKeymap = false
		m.draft.editingTitle = true
	}
	return m, nil
}

func (m *model) insertPrompt(value string) {
	if m.draft == nil || value == "" {
		return
	}
	runes := []rune(m.draft.row.Prompt)
	cursor := min(max(0, m.draft.promptCursor), len(runes))
	inserted := []rune(value)
	runes = append(runes[:cursor], append(inserted, runes[cursor:]...)...)
	m.draft.row.Prompt = string(runes)
	m.draft.promptCursor = cursor + len(inserted)
}

func (m *model) deletePromptRange(start, end int) {
	if m.draft == nil {
		return
	}
	runes := []rune(m.draft.row.Prompt)
	start = min(max(0, start), len(runes))
	end = min(max(start, end), len(runes))
	if start == end {
		return
	}
	m.draft.killBuffer = string(runes[start:end])
	m.draft.row.Prompt = string(append(runes[:start], runes[end:]...))
	m.draft.promptCursor = start
}

func (m *model) transposePromptCharacters() {
	if m.draft == nil {
		return
	}
	runes := []rune(m.draft.row.Prompt)
	if len(runes) < 2 || m.draft.promptCursor == 0 {
		return
	}
	right := min(m.draft.promptCursor, len(runes)-1)
	left := right - 1
	runes[left], runes[right] = runes[right], runes[left]
	m.draft.row.Prompt = string(runes)
	m.draft.promptCursor = min(len(runes), right+1)
}

func previousWordBoundary(runes []rune, cursor int) int {
	cursor = min(max(0, cursor), len(runes))
	for cursor > 0 && unicode.IsSpace(runes[cursor-1]) {
		cursor--
	}
	for cursor > 0 && !unicode.IsSpace(runes[cursor-1]) {
		cursor--
	}
	return cursor
}

func nextWordBoundary(runes []rune, cursor int) int {
	cursor = min(max(0, cursor), len(runes))
	for cursor < len(runes) && unicode.IsSpace(runes[cursor]) {
		cursor++
	}
	for cursor < len(runes) && !unicode.IsSpace(runes[cursor]) {
		cursor++
	}
	return cursor
}

func (m model) finishThreadDraft() (tea.Model, tea.Cmd) {
	if m.draft == nil || strings.TrimSpace(m.draft.row.Prompt) == "" {
		return m, nil
	}
	selected := m.draft.row
	selected.Prompt = strings.TrimSpace(selected.Prompt)
	selected.Branch = generatedThreadTitle(selected.Prompt)
	selected.GitSpace = m.draft.gitSpace
	selected.Source = m.draft.source
	selected.Base = m.draft.defaultBranch
	m.selected = &selected
	m.quit = true
	return m, tea.Quit
}

func (m *model) toggleThreadDraftField(field int) {
	if m.draft == nil {
		return
	}
	switch field {
	case 0:
		if m.app.localMachine == m.app.remoteMachine || !m.app.remoteOnline {
			return
		}
		if m.draft.row.Remote {
			m.draft.row.Machine = m.app.localMachine
			m.draft.row.Target = "mac"
			m.draft.row.Remote = false
		} else {
			m.draft.row.Machine = m.app.remoteMachine
			m.draft.row.Target = "ubuntu"
			m.draft.row.Remote = true
		}
	case 1:
		if m.draft.gitSpace == "worktree" {
			m.draft.gitSpace = "default"
		} else {
			m.draft.gitSpace = "worktree"
		}
	case 2:
		if m.draft.source == "origin" {
			m.draft.source = "local"
		} else {
			m.draft.source = "origin"
		}
	}
}

func (m *model) applyRemoteSnapshot(data map[string]any) {
	m.app.remoteOnline = true
	m.app.remoteCached = false
	rows := make([]row, 0, len(m.allRows))
	for _, existing := range m.allRows {
		if !existing.Remote {
			rows = append(rows, existing)
		}
	}
	for _, created := range m.app.newThreadRows("") {
		if created.Remote {
			rows = append(rows, created)
		}
	}
	rows = append(rows, m.app.snapshotRows(data, m.app.remoteMachine, true)...)
	sortRows(rows)
	m.allRows = m.app.filterModeRows(rows)
	m.applyFilter(false)
}

func (m *model) applyHistoryRows(history []row) {
	activeSessions := make(map[string]bool)
	rows := make([]row, 0, len(m.allRows)+len(history))
	for _, existing := range m.allRows {
		if existing.Kind == "HIST" {
			continue
		}
		if existing.Kind == "TH" && existing.Session != "" {
			activeSessions[existing.Session] = true
		}
		rows = append(rows, existing)
	}
	for _, saved := range history {
		if !activeSessions[saved.Session] {
			rows = append(rows, saved)
		}
	}
	m.app.historyCount = len(history)
	sortRows(rows)
	m.allRows = m.app.filterModeRows(rows)
	m.applyFilter(false)
}

func (m model) View() string {
	if m.quit {
		return ""
	}
	if m.draft != nil {
		return m.threadDraftView()
	}
	width := m.width
	if width < 60 {
		width = 60
	}
	height := m.height
	if height < 10 {
		height = 10
	}
	inner := width - 4
	available := height - 7
	if available < 1 {
		available = 1
	}
	start := 0
	if m.cursor >= available {
		start = m.cursor - available + 1
	}
	end := start + available
	if end > len(m.rows) {
		end = len(m.rows)
	}
	var b strings.Builder
	top := "╭" + strings.Repeat("─", inner+2) + "╮"
	sep := "├" + strings.Repeat("─", inner+2) + "┤"
	b.WriteString(top + "\n")
	remoteState := "offline"
	if m.app.remoteOnline {
		remoteState = "online"
	} else if m.app.remoteErr != nil {
		remoteState = "failed"
	} else if m.app.remoteCached {
		remoteState = "offline · cached"
	}
	if m.app.remoteLoading {
		remoteState = "checking"
		if m.app.remoteCached {
			remoteState = "cached · checking"
		}
	}
	machineSummary := m.app.localMachine
	if m.app.localMachine != m.app.remoteMachine {
		machineSummary += " · " + m.app.remoteMachine + " " + remoteState
	}
	if m.app.threadsOnly || m.app.newThreadOnly {
		historyState := fmt.Sprintf("%d saved", m.app.historyCount)
		if m.app.historyLoading {
			historyState = "history loading"
		} else if m.app.historyErr != nil {
			historyState = "history failed: " + oneLine(m.app.historyErr.Error())
		} else if m.app.historyLoaded && m.app.historyCount == 0 {
			historyState = "no saved threads"
		}
		machineSummary += " · " + historyState
	}
	prompt := "herdr worktree > "
	targetHeader := "thread / worktree / branch"
	enterAction := "start/open/create"
	if m.app.threadsOnly || m.app.newThreadOnly {
		prompt = "herdr thread > "
		targetHeader = "thread"
		enterAction = "focus/start"
	}
	if m.app.newThreadOnly {
		machineSummary += " · " + m.app.projectName() + " only"
	}
	b.WriteString(boxLine(color(c.bold+c.cyan, prompt)+m.query+color(c.dim, "  "+machineSummary), inner) + "\n")
	b.WriteString(boxLine("      "+color(c.dim, fmt.Sprintf("%-8s  %-9s  %-32s  %-6s  %s", "machine", "state", targetHeader, "kind", "detail")), inner) + "\n")
	b.WriteString(sep + "\n")
	for i := start; i < end; i++ {
		prefix := "  "
		if i == m.cursor {
			prefix = color(c.cyan+c.bold, "> ")
		}
		b.WriteString(boxLine(prefix+m.rows[i].display(), inner) + "\n")
	}
	for i := end - start; i < available; i++ {
		b.WriteString(boxLine("", inner) + "\n")
	}
	b.WriteString(sep + "\n")
	b.WriteString(boxLine(color(c.dim, "type to search")+" | "+color(c.green, "Enter")+" "+enterAction+" | "+color(c.yellow, "Esc")+" quit | "+color(c.yellow, "Ctrl-u")+" clear", inner) + "\n")
	b.WriteString("╰" + strings.Repeat("─", inner+2) + "╯")
	return b.String()
}

func (m model) threadDraftView() string {
	draft := m.draft
	if draft == nil {
		return ""
	}
	if draft.showKeymap {
		return m.threadKeymapView()
	}
	width := m.width
	if width < 60 {
		width = 60
	}
	height := m.height
	if height < 17 {
		height = 17
	}
	bodyHeight := height - 8
	heading := color(c.bold+c.cyan, "new thread") + color(c.dim, "  · "+draft.project)
	project := color(c.dim, "Your first prompt creates the title, Git space, and agent.")

	machineDetail := "local"
	if draft.row.Remote {
		machineDetail = "remote"
	} else if m.app.localMachine != m.app.remoteMachine && !m.app.remoteOnline {
		machineDetail = "local · Ubuntu offline"
	}
	spaceValue := color(c.cyan, "new worktree")
	if draft.gitSpace == "default" {
		spaceValue = color(c.green, "default branch")
	}
	sourceValue := color(c.magenta, "origin")
	sourceDetail := "remote-first"
	if draft.source == "local" {
		sourceValue = color(c.green, "local state")
		sourceDetail = "unchanged"
	}
	prompt := strings.TrimSpace(draft.row.Prompt)
	promptValue := prompt
	if promptValue == "" {
		promptValue = "Describe what you want the agent to do"
	} else if draft.editingTitle {
		promptValue = promptWithCursor(draft.row.Prompt, draft.promptCursor)
	}
	if prompt == "" && draft.editingTitle {
		promptValue += "  █"
	}
	promptLines := wrapPlain(promptValue, width-8, 3)
	if prompt == "" {
		for index := range promptLines {
			promptLines[index] = color(c.dim, promptLines[index])
		}
	}

	controlPrefix := func(index int) string {
		if !draft.editingTitle && draft.cursor == index {
			return color(c.cyan+c.bold, "> ")
		}
		return "  "
	}
	body := []string{color(c.bold, "PROMPT")}
	for _, line := range promptLines {
		body = append(body, "  "+line)
	}
	body = append(body,
		color(c.dim, "TITLE  ")+color(c.green, generatedThreadTitle(prompt)),
		"",
		controlPrefix(0)+color(c.dim, "machine    ")+color(draft.row.machineColor()+c.bold, draft.row.Machine)+color(c.dim, "  · "+machineDetail+"  [⌥m]"),
		controlPrefix(1)+color(c.dim, "git space  ")+spaceValue+color(c.dim, "  · "+draft.defaultBranch+"  [⌥w]"),
		controlPrefix(2)+color(c.dim, "source     ")+sourceValue+color(c.dim, "  · "+sourceDetail+"  [⌥o]"),
		"",
		color(c.green, "● ")+"Ready",
	)

	var b strings.Builder
	b.WriteString("╭" + strings.Repeat("─", width-2) + "╮\n")
	b.WriteString(boxLine(heading, width-4) + "\n")
	b.WriteString(boxLine(project, width-4) + "\n")
	b.WriteString("├" + strings.Repeat("─", width-2) + "┤\n")
	for index := 0; index < bodyHeight; index++ {
		line := ""
		if index < len(body) {
			line = body[index]
		}
		b.WriteString(boxLine(line, width-4) + "\n")
	}
	b.WriteString("├" + strings.Repeat("─", width-2) + "┤\n")
	if draft.editingTitle {
		b.WriteString(boxLine(color(c.green, "Enter")+" send and create  "+color(c.yellow, "Tab")+" controls  "+color(c.yellow, "Esc")+" back  "+color(c.blue, "⌥?")+" keys", width-4) + "\n")
		b.WriteString(boxLine(color(c.blue, "⌥m")+" machine  "+color(c.cyan, "⌥w")+" git space  "+color(c.magenta, "⌥o")+" source  "+color(c.yellow, "Ctrl-w")+" delete word", width-4) + "\n")
	} else {
		b.WriteString(boxLine(color(c.dim, "↑/k ↓/j")+" move  "+color(c.cyan, "←/h →/l Space")+" change  "+color(c.yellow, "Tab")+" next", width-4) + "\n")
		b.WriteString(boxLine(color(c.blue, "m")+" machine  "+color(c.cyan, "w")+" git space  "+color(c.magenta, "o")+" source  "+color(c.blue, "t")+" prompt  "+color(c.green, "Enter")+" create  "+color(c.yellow, "Esc")+" back", width-4) + "\n")
	}
	b.WriteString("╰" + strings.Repeat("─", width-2) + "╯")
	return b.String()
}

func promptWithCursor(value string, cursor int) string {
	runes := []rune(value)
	cursor = min(max(0, cursor), len(runes))
	return string(runes[:cursor]) + "█" + string(runes[cursor:])
}

func (m model) threadKeymapView() string {
	width := max(60, m.width)
	height := max(20, m.height)
	bodyHeight := height - 6
	rows := []string{
		color(c.bold+c.cyan, "READLINE INPUT KEYS"),
		"",
		color(c.bold, "Move"),
		"  Ctrl-a / Home       start of line",
		"  Ctrl-e / End        end of line",
		"  Ctrl-b / ←          one character left",
		"  Ctrl-f / →          one character right",
		"  Alt-b / Ctrl-←      one word left",
		"  Alt-f / Ctrl-→      one word right",
		"",
		color(c.bold, "Edit"),
		"  Backspace / Ctrl-h  delete previous character",
		"  Delete / Ctrl-d     delete next character",
		"  Ctrl-w / Alt-BS     delete previous word",
		"  Alt-d               delete next word",
		"  Ctrl-u              delete before cursor",
		"  Ctrl-k              delete after cursor",
		"  Ctrl-y              paste last deleted text",
		"  Ctrl-t              swap characters",
		"  Ctrl-l              redraw",
		"",
		color(c.bold, "Create"),
		"  Enter               send prompt and create",
		"  Tab                 open controls",
		"  Alt-m / Alt-w / Alt-o  machine / Git space / source",
		"  Esc                 return to thread search",
		"  Ctrl-c              close",
	}

	var b strings.Builder
	b.WriteString("╭" + strings.Repeat("─", width-2) + "╮\n")
	b.WriteString(boxLine(color(c.bold+c.cyan, "input keymap")+color(c.dim, "  · terminal style"), width-4) + "\n")
	b.WriteString("├" + strings.Repeat("─", width-2) + "┤\n")
	for index := 0; index < bodyHeight; index++ {
		line := ""
		if index < len(rows) {
			line = rows[index]
		}
		b.WriteString(boxLine(line, width-4) + "\n")
	}
	b.WriteString("├" + strings.Repeat("─", width-2) + "┤\n")
	b.WriteString(boxLine(color(c.yellow, "Esc / Enter / ⌥?")+" back to prompt", width-4) + "\n")
	b.WriteString("╰" + strings.Repeat("─", width-2) + "╯")
	return b.String()
}

func wrapPlain(value string, width, limit int) []string {
	if width < 1 || limit < 1 {
		return nil
	}
	words := strings.Fields(oneLine(value))
	if len(words) == 0 {
		return []string{""}
	}
	lines := make([]string, 0, limit)
	for _, word := range words {
		if len(lines) == 0 || len([]rune(lines[len(lines)-1]+" "+word)) > width {
			if len(lines) == limit {
				last := strings.TrimRight(lines[limit-1], "…")
				lines[limit-1] = truncatePlain(last+"…", width)
				return lines
			}
			lines = append(lines, truncatePlain(word, width))
			continue
		}
		lines[len(lines)-1] += " " + word
	}
	return lines
}

func (draft threadDraft) plan() []string {
	steps := []string{"Run in the local Herdr workspace"}
	if draft.row.Remote {
		steps = []string{"Run Codex on Ubuntu over SSH"}
	}
	if draft.source == "origin" {
		steps = append(steps, "Fetch origin on the selected machine")
	}
	if draft.gitSpace == "default" {
		if draft.source == "origin" {
			steps = append(steps, "Fast-forward "+draft.defaultBranch+" from origin/"+draft.defaultBranch)
		} else {
			steps = append(steps, "Use the "+draft.defaultBranch+" checkout unchanged")
		}
	} else {
		base := draft.defaultBranch
		if draft.source == "origin" {
			base = "origin/" + base
		}
		steps = append(steps, "Create a new thread branch from "+base, "Let Herdr choose the worktree path")
	}
	if draft.row.Remote {
		return append(steps, "Create the thread entry under the local repository", "Open remote Codex in a local Herdr pane")
	}
	return append(steps, "Create or reuse the hidden Herdr workspace", "Start Codex and bind its session to the thread")
}

func splitBoxLine(left, right string, leftWidth, rightWidth int) string {
	left = ansiTruncate(left, leftWidth)
	right = ansiTruncate(right, rightWidth)
	return "│ " + left + strings.Repeat(" ", leftWidth-ansiVisibleLen(left)) +
		" │ " + right + strings.Repeat(" ", rightWidth-ansiVisibleLen(right)) + " │"
}

func (m *model) applyFilter(reset bool) {
	query := strings.ToLower(strings.TrimSpace(m.query))
	m.rows = nil
	threadTitleMatch := false
	gitTargetMatch := false
	for _, r := range m.allRows {
		if query == "" {
			m.rows = append(m.rows, r)
			continue
		}
		if r.Kind == "NEW" {
			continue
		}
		if (r.Kind == "TH" || r.Kind == "HIST") && r.threadTitleMatch(query) {
			threadTitleMatch = true
		}
		if (r.Kind == "WT" || r.Kind == "BR" || r.Kind == "RB") && r.gitTargetMatch(query) {
			gitTargetMatch = true
		}
		if _, matched := r.matchRank(query); matched {
			m.rows = append(m.rows, r)
		}
	}
	if query != "" {
		sort.SliceStable(m.rows, func(i, j int) bool {
			iRank, _ := m.rows[i].matchRank(query)
			jRank, _ := m.rows[j].matchRank(query)
			return iRank < jRank
		})
	}
	if query != "" && !threadTitleMatch && !gitTargetMatch && m.app != nil && m.app.root != "" {
		m.rows = append(m.app.newThreadRows(strings.TrimSpace(m.query)), m.rows...)
	}
	if reset || m.cursor >= len(m.rows) {
		m.cursor = 0
	}
}

func (r row) gitTargetMatch(query string) bool {
	return strings.EqualFold(strings.TrimSpace(r.Branch), query) ||
		strings.EqualFold(strings.TrimSpace(r.Target), query)
}

func (r row) threadTitleMatch(query string) bool {
	return strings.Contains(strings.ToLower(strings.TrimSpace(r.Branch)), query) ||
		(r.Session != "" && strings.EqualFold(r.Session, query))
}

func (m *model) move(delta int) {
	if len(m.rows) == 0 {
		m.cursor = 0
		return
	}
	m.cursor += delta
	if m.cursor < 0 {
		m.cursor = 0
	}
	if m.cursor >= len(m.rows) {
		m.cursor = len(m.rows) - 1
	}
}

func (r row) display() string {
	return fmt.Sprintf(
		"%-8s  %-9s  %-32s  %-6s  %s",
		color(r.machineColor(), padPlain(r.Machine, 8)),
		color(r.stateColor(), padPlain(r.State, 9)),
		color(r.branchColor(), padPlain(truncatePlain(r.Branch, 32), 32)),
		color(r.kindColor(), padPlain(r.Kind, 6)),
		color(c.dim, truncatePlain(r.Detail, 80)),
	)
}

func (r row) searchText() string {
	return strings.Join([]string{r.Kind, r.Machine, r.State, r.Branch, r.Target, r.Workspace, r.Session, r.Prompt, r.Detail, r.Repo}, " ")
}

// matchRank keeps the default recency ordering as a stable tie-breaker while
// making the text the user typed the primary ordering signal.
func (r row) matchRank(query string) (int, bool) {
	branch := strings.ToLower(r.Branch)
	if branch == query {
		return 0, true
	}
	if strings.HasPrefix(branch, query) {
		return 1, true
	}
	for _, part := range strings.FieldsFunc(branch, func(value rune) bool {
		return value == '/' || value == '-' || value == '_' || value == '.'
	}) {
		if part == query {
			return 2, true
		}
	}
	if strings.Contains(branch, query) {
		return 3, true
	}

	fields := []string{r.Target, r.Workspace, r.Session, r.Detail, r.Repo, r.Machine, r.Kind, r.State}
	for _, field := range fields {
		if strings.ToLower(field) == query {
			return 4, true
		}
	}
	for _, field := range fields {
		if strings.HasPrefix(strings.ToLower(field), query) {
			return 5, true
		}
	}
	if strings.Contains(strings.ToLower(r.searchText()), query) {
		return 6, true
	}
	return 0, false
}

func (r row) tsv() string {
	return strings.Join([]string{r.Kind, r.Machine, r.State, r.Branch, r.Target, r.Workspace, r.Session, r.Prompt, r.Detail, r.Repo}, "\t")
}

func chooseNonInteractive(rows []row, selector string) (row, bool) {
	for _, r := range rows {
		if selector == r.Branch || selector == r.Target || strings.Contains(r.searchText(), selector) {
			return r, true
		}
	}
	return row{}, false
}

func boxLine(value string, width int) string {
	value = ansiTruncate(value, width)
	padding := width - ansiVisibleLen(value)
	if padding < 0 {
		padding = 0
	}
	return "│ " + value + strings.Repeat(" ", padding) + " │"
}

func truncatePlain(value string, width int) string {
	runes := []rune(value)
	if len(runes) <= width {
		return value
	}
	if width <= 1 {
		return "~"
	}
	return string(runes[:width-1]) + "~"
}

func padPlain(value string, width int) string {
	runes := []rune(value)
	if len(runes) > width {
		value = truncatePlain(value, width)
		runes = []rune(value)
	}
	return value + strings.Repeat(" ", width-len(runes))
}

func color(colorCode, value string) string {
	return colorCode + value + c.reset
}

func (r row) kindColor() string {
	switch r.Kind {
	case "NEW":
		return c.blue + c.bold
	case "TH":
		return c.green
	case "HIST":
		return c.magenta
	case "WT":
		return c.cyan
	case "BR":
		return c.yellow
	case "RB":
		return c.magenta
	default:
		return c.dim
	}
}

func (r row) stateColor() string {
	switch r.State {
	case "new":
		return c.blue + c.bold
	case "blocked":
		return c.red + c.bold
	case "working":
		return c.yellow + c.bold
	case "idle":
		return c.green
	case "history":
		return c.magenta
	case "missing":
		return c.red + c.bold
	case "open":
		return c.green + c.bold
	case "worktree":
		return c.cyan
	case "branch":
		return c.yellow
	case "remote":
		return c.magenta
	default:
		return c.dim
	}
}

func (r row) branchColor() string {
	switch r.Kind {
	case "NEW":
		return c.blue + c.bold
	case "TH":
		return c.green
	case "HIST":
		return c.magenta
	case "WT":
		if r.State == "open" {
			return c.green
		}
		return c.cyan
	case "BR":
		return c.yellow
	case "RB":
		return c.magenta
	default:
		return c.reset
	}
}

func (r row) machineColor() string {
	if r.Remote || r.RemoteHost {
		return c.magenta
	}
	return c.blue
}

var ansiPattern = regexp.MustCompile(`\x1b\[[0-9;]*m`)

func stripANSI(value string) string {
	return ansiPattern.ReplaceAllString(value, "")
}

func ansiVisibleLen(value string) int {
	return len([]rune(stripANSI(value)))
}

func ansiTruncate(value string, width int) string {
	if ansiVisibleLen(value) <= width {
		return value
	}
	var b strings.Builder
	visible := 0
	for i := 0; i < len(value); {
		if value[i] == '\x1b' {
			end := i + 1
			for end < len(value) && value[end] != 'm' {
				end++
			}
			if end < len(value) {
				b.WriteString(value[i : end+1])
				i = end + 1
				continue
			}
		}
		r := []rune(value[i:])[0]
		size := len(string(r))
		if visible >= width-1 {
			break
		}
		b.WriteRune(r)
		visible++
		i += size
	}
	b.WriteString("~")
	b.WriteString(c.reset)
	return b.String()
}

func sanitizeBranch(raw string) string {
	var parts []string
	re := regexp.MustCompile(`[^A-Za-z0-9._-]+`)
	for _, part := range strings.Split(raw, "/") {
		safe := strings.Trim(re.ReplaceAllString(strings.TrimSpace(part), "-"), "-")
		if safe == "" || safe == "." || safe == ".." {
			safe = "branch"
		}
		parts = append(parts, safe)
	}
	return strings.Join(parts, "/")
}

func remoteLocalName(remote string) string {
	if index := strings.Index(remote, "/"); index >= 0 && index+1 < len(remote) {
		return remote[index+1:]
	}
	return remote
}

func unique(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := values[:0]
	var previous string
	for i, value := range values {
		if i == 0 || value != previous {
			out = append(out, value)
			previous = value
		}
	}
	return out
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func jsonMap(data map[string]any, key string) map[string]any {
	value, _ := data[key].(map[string]any)
	if value == nil {
		return map[string]any{}
	}
	return value
}

func jsonArray(data map[string]any, key string) []any {
	value, _ := data[key].([]any)
	return value
}

func jsonString(data map[string]any, key string) string {
	value, _ := data[key].(string)
	return value
}

func jsonInt64(data map[string]any, key string) int64 {
	value, _ := data[key].(float64)
	return int64(value)
}

func jsonBool(data map[string]any, key string) bool {
	value, _ := data[key].(bool)
	return value
}
