package main

import (
	"bytes"
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

	tea "github.com/charmbracelet/bubbletea"
)

type row struct {
	Kind      string
	State     string
	Branch    string
	Target    string
	Workspace string
	Detail    string
	Repo      string
	Updated   int64
}

type app struct {
	gitBin   string
	herdrBin string
	root     string
	rows     []row
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
}

func main() {
	if err := runMain(); err != nil {
		fmt.Fprintf(os.Stderr, "herdr-worktree-picker: %s\n", err)
		os.Exit(1)
	}
}

func runMain() error {
	list := flag.Bool("list", false, "print rows and exit")
	selectQuery := flag.String("select", "", "select without opening the UI")
	dryRun := flag.Bool("dry-run", false, "print selected command")
	flag.Parse()
	explicitPath := ""
	if flag.NArg() > 0 {
		explicitPath = flag.Arg(0)
	}

	a := &app{gitBin: lookPath("git"), herdrBin: lookPath("herdr")}
	if a.gitBin == "" {
		return errors.New("git not found in PATH")
	}
	if a.herdrBin == "" {
		return errors.New("herdr not found in PATH")
	}
	source, err := a.sourcePath(explicitPath)
	if err != nil {
		return err
	}
	root, err := a.repoRoot(source)
	if err != nil {
		return err
	}
	a.root = root
	rows, err := a.buildRows()
	if err != nil {
		return err
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
			return fmt.Errorf("no worktree/branch matches selector: %s", *selectQuery)
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

func lookPath(name string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	return ""
}

func (a *app) output(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = bytes.NewBuffer(nil)
	if cmd.Run() != nil {
		return ""
	}
	return strings.TrimSpace(out.String())
}

func (a *app) herdrJSON(args ...string) (map[string]any, error) {
	out := a.output(a.herdrBin, args...)
	if out == "" {
		return nil, fmt.Errorf("herdr %s returned no JSON", strings.Join(args, " "))
	}
	var data map[string]any
	if err := json.Unmarshal([]byte(out), &data); err != nil {
		return nil, err
	}
	return data, nil
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
	if data, err := a.herdrJSON("pane", "current"); err == nil {
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
		if path != "" && a.output(a.gitBin, "-C", path, "rev-parse", "--git-common-dir") != "" {
			return path, nil
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
	return "", fmt.Errorf("not in a git repository: %s", path)
}

func (a *app) buildRows() ([]row, error) {
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
		out = append(out, row{Kind: "WT", State: state, Branch: branch, Target: path, Workspace: jsonString(wt, "open_workspace_id"), Detail: path, Repo: repoName, Updated: updated})
	}
	localBranches := a.branchRefs("refs/heads")
	localSet := map[string]bool{}
	for _, branch := range localBranches {
		localSet[branch] = true
		if existingBranches[branch] {
			continue
		}
		out = append(out, row{Kind: "BR", State: "branch", Branch: branch, Target: branch, Detail: "local branch", Repo: repoName, Updated: refTimes[branch]})
	}
	for _, remote := range a.branchRefs("refs/remotes") {
		branch := remoteLocalName(remote)
		if branch == "" || existingBranches[branch] || localSet[branch] {
			continue
		}
		out = append(out, row{Kind: "RB", State: "remote", Branch: branch, Target: remote, Detail: remote, Repo: repoName, Updated: refTimes[remote]})
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Updated == out[j].Updated {
			return out[i].Branch < out[j].Branch
		}
		return out[i].Updated > out[j].Updated
	})
	return out, nil
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
	var args []string
	switch r.Kind {
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

func newModel(a *app, rows []row) model {
	m := model{app: a, allRows: rows, width: 100, height: 24}
	m.applyFilter(true)
	return m
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc":
			m.quit = true
			return m, tea.Quit
		case "enter":
			if len(m.rows) > 0 {
				selected := m.rows[m.cursor]
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

func (m model) View() string {
	if m.quit {
		return ""
	}
	width := m.width
	if width < 90 {
		width = 90
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
	b.WriteString(boxLine(color(c.bold+c.cyan, "herdr worktree > ")+m.query, inner) + "\n")
	b.WriteString(boxLine("      "+color(c.dim, fmt.Sprintf("%-8s  %-38s  %-7s  %s", "state", "branch", "kind", "detail")), inner) + "\n")
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
	b.WriteString(boxLine(color(c.dim, "type to search")+" | "+color(c.green, "Enter")+" open/create | "+color(c.yellow, "Esc")+" quit | "+color(c.yellow, "Ctrl-u")+" clear", inner) + "\n")
	b.WriteString("╰" + strings.Repeat("─", inner+2) + "╯")
	return b.String()
}

func (m *model) applyFilter(reset bool) {
	query := strings.ToLower(strings.TrimSpace(m.query))
	m.rows = nil
	for _, r := range m.allRows {
		if query == "" {
			m.rows = append(m.rows, r)
			continue
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
	if reset || m.cursor >= len(m.rows) {
		m.cursor = 0
	}
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
		"%-8s  %-38s  %-7s  %s",
		color(r.stateColor(), padPlain(r.State, 8)),
		color(r.branchColor(), padPlain(truncatePlain(r.Branch, 38), 38)),
		color(r.kindColor(), padPlain(r.Kind, 7)),
		color(c.dim, truncatePlain(r.Detail, 80)),
	)
}

func (r row) searchText() string {
	return strings.Join([]string{r.Kind, r.State, r.Branch, r.Target, r.Workspace, r.Detail, r.Repo}, " ")
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

	fields := []string{r.Target, r.Workspace, r.Detail, r.Repo, r.Kind, r.State}
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
	return strings.Join([]string{r.Kind, r.State, r.Branch, r.Target, r.Workspace, r.Detail, r.Repo}, "\t")
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

func jsonBool(data map[string]any, key string) bool {
	value, _ := data[key].(bool)
	return value
}
