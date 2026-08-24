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
	"sort"
	"strconv"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

type filterMode int

const (
	filterAll filterMode = iota
	filterStack
	filterClassic
)

type stackInfo struct {
	Number   int `json:"number"`
	Position int `json:"position"`
	Base     struct {
		Ref string `json:"ref"`
	} `json:"base"`
}

type pullRequest struct {
	Number    int        `json:"number"`
	Title     string     `json:"title"`
	Draft     bool       `json:"draft"`
	UpdatedAt string     `json:"updated_at"`
	Stack     *stackInfo `json:"stack"`
	Head      struct {
		Ref string `json:"ref"`
	} `json:"head"`
	Base struct {
		Ref string `json:"ref"`
	} `json:"base"`
	User struct {
		Login string `json:"login"`
	} `json:"user"`
}

type row struct {
	Kind    filterMode
	ID      string
	State   string
	Base    string
	Detail  string
	Target  string
	Updated string
	Numbers []int
}

type app struct {
	ghBin  string
	gitBin string
	slug   string
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
}

var colors = palette{
	reset:   "\033[0m",
	bold:    "\033[1m",
	dim:     "\033[2m",
	green:   "\033[32m",
	yellow:  "\033[33m",
	cyan:    "\033[36m",
	magenta: "\033[35m",
	red:     "\033[31m",
}

type model struct {
	allRows   []row
	rows      []row
	mode      filterMode
	query     string
	searching bool
	cursor    int
	width     int
	height    int
	selected  *row
	quit      bool
}

func main() {
	if err := runMain(); err != nil {
		fmt.Fprintf(os.Stderr, "herdr-pr-browser: %s\n", err)
		os.Exit(1)
	}
}

func runMain() error {
	list := flag.Bool("list", false, "print pull request rows")
	selectQuery := flag.String("select", os.Getenv("HERDR_PR_FILTER"), "select without opening the UI")
	dryRun := flag.Bool("dry-run", os.Getenv("HERDR_PR_DRY_RUN") == "1", "print browser actions")
	flag.Parse()

	ghBin, err := exec.LookPath("gh")
	if err != nil {
		return errors.New("gh not found in PATH")
	}
	gitBin, err := exec.LookPath("git")
	if err != nil && os.Getenv("HERDR_PR_REPO") == "" {
		return errors.New("git not found in PATH")
	}
	a := &app{ghBin: ghBin, gitBin: gitBin}
	a.slug, err = a.repoSlug()
	if err != nil {
		return err
	}

	pulls, err := a.loadPullRequests()
	if err != nil {
		return err
	}
	rows := buildRows(pulls)
	if len(rows) == 0 {
		return errors.New("no open pull requests")
	}
	if !*list && *selectQuery == "" {
		branch, err := a.currentBranch()
		if err != nil {
			return err
		}
		if current, ok := currentRow(rows, pulls, branch); ok {
			return a.openRow(current, *dryRun)
		}
	}
	if *list {
		for _, item := range rows {
			fmt.Println(item.tsv())
		}
		return nil
	}
	if *selectQuery != "" {
		selected, ok := chooseNonInteractive(rows, *selectQuery)
		if !ok {
			return fmt.Errorf("no pull request matches selector: %s", *selectQuery)
		}
		return a.openRow(selected, *dryRun)
	}

	finalModel, err := tea.NewProgram(
		newModel(rows),
		tea.WithAltScreen(),
		tea.WithFPS(15),
	).Run()
	if err != nil {
		return err
	}
	result, ok := finalModel.(model)
	if !ok || result.selected == nil {
		return nil
	}
	return a.openRow(*result.selected, *dryRun)
}

func (a *app) output(args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, a.ghBin, args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return nil, errors.New("GitHub request timed out after 8s")
		}
		detail := strings.TrimSpace(stderr.String())
		if detail == "" {
			detail = err.Error()
		}
		return nil, errors.New(detail)
	}
	return stdout.Bytes(), nil
}

func (a *app) repoSlug() (string, error) {
	if value := os.Getenv("HERDR_PR_REPO"); value != "" {
		return value, nil
	}
	data, err := a.gitOutput("remote", "get-url", "origin")
	if err != nil {
		return "", err
	}
	slug := parseGitHubSlug(strings.TrimSpace(string(data)))
	if slug == "" {
		return "", fmt.Errorf("unable to resolve GitHub repository from origin")
	}
	return slug, nil
}

func (a *app) gitOutput(args ...string) ([]byte, error) {
	cmd := exec.Command(a.gitBin, args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, errors.New(strings.TrimSpace(stderr.String()))
	}
	return stdout.Bytes(), nil
}

func (a *app) currentBranch() (string, error) {
	if branch, exists := os.LookupEnv("HERDR_PR_BRANCH"); exists {
		return branch, nil
	}
	data, err := a.gitOutput("branch", "--show-current")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

func (a *app) loadPullRequests() ([]pullRequest, error) {
	var data []byte
	var err error
	if fixture, exists := os.LookupEnv("HERDR_PR_PULLS_JSON"); exists {
		data = []byte(fixture)
	} else {
		data, err = a.output(
			"api", "--cache", "5s", "--paginate", "--slurp",
			fmt.Sprintf("repos/%s/pulls?state=open&per_page=100", a.slug),
		)
		if err != nil {
			return nil, err
		}
	}
	var pages [][]pullRequest
	if err := json.Unmarshal(data, &pages); err != nil {
		return nil, fmt.Errorf("decode pull requests: %w", err)
	}
	return flattenPages(pages), nil
}

func flattenPages(pages [][]pullRequest) []pullRequest {
	var pulls []pullRequest
	for _, page := range pages {
		pulls = append(pulls, page...)
	}
	return pulls
}

func parseGitHubSlug(remote string) string {
	remote = strings.TrimSuffix(remote, ".git")
	for _, prefix := range []string{
		"git@github.com:",
		"ssh://git@github.com/",
		"https://github.com/",
		"http://github.com/",
	} {
		if strings.HasPrefix(remote, prefix) {
			return strings.TrimPrefix(remote, prefix)
		}
	}
	return ""
}

func currentRow(rows []row, pulls []pullRequest, branch string) (row, bool) {
	if branch == "" {
		return row{}, false
	}
	target := ""
	for _, pull := range pulls {
		if pull.Head.Ref != branch {
			continue
		}
		if pull.Stack != nil {
			target = fmt.Sprintf("stack:%d", pull.Stack.Number)
		} else {
			target = fmt.Sprintf("pr:%d", pull.Number)
		}
		break
	}
	for _, item := range rows {
		if item.Target == target {
			return item, true
		}
	}
	return row{}, false
}

func buildRows(pulls []pullRequest) []row {
	stacks := make(map[int][]pullRequest)
	var rows []row
	for _, pull := range pulls {
		if pull.Stack != nil {
			stacks[pull.Stack.Number] = append(stacks[pull.Stack.Number], pull)
			continue
		}
		state := "open"
		if pull.Draft {
			state = "draft"
		}
		rows = append(rows, row{
			Kind:    filterClassic,
			ID:      fmt.Sprintf("PR #%d", pull.Number),
			State:   state,
			Base:    pull.Base.Ref,
			Detail:  fmt.Sprintf("@%s  %s", pull.User.Login, cleanLine(pull.Title)),
			Target:  fmt.Sprintf("pr:%d", pull.Number),
			Updated: pull.UpdatedAt,
			Numbers: []int{pull.Number},
		})
	}
	for number, pulls := range stacks {
		sort.SliceStable(pulls, func(i, j int) bool {
			return pulls[i].Stack.Position < pulls[j].Stack.Position
		})
		prNumbers := make([]string, 0, len(pulls))
		numbers := make([]int, 0, len(pulls))
		updated := ""
		for _, pull := range pulls {
			prNumbers = append(prNumbers, fmt.Sprintf("#%d", pull.Number))
			numbers = append(numbers, pull.Number)
			if pull.UpdatedAt > updated {
				updated = pull.UpdatedAt
			}
		}
		rows = append(rows, row{
			Kind:    filterStack,
			ID:      fmt.Sprintf("S#%d", number),
			State:   fmt.Sprintf("%d PRs", len(pulls)),
			Base:    pulls[0].Stack.Base.Ref,
			Detail:  strings.Join(prNumbers, " -> "),
			Target:  fmt.Sprintf("stack:%d", number),
			Updated: updated,
			Numbers: numbers,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool { return rows[i].Updated > rows[j].Updated })
	return rows
}

func cleanLine(value string) string {
	return strings.Join(strings.Fields(value), " ")
}

func (a *app) openRow(item row, dryRun bool) error {
	if len(item.Numbers) == 0 {
		return fmt.Errorf("selection has no open PR: %s", item.Target)
	}
	for _, number := range item.Numbers {
		if err := a.openPR(number, dryRun); err != nil {
			return err
		}
	}
	return nil
}

func (a *app) openPR(number int, dryRun bool) error {
	if dryRun {
		fmt.Printf("open pr %d\n", number)
		return nil
	}
	cmd := exec.Command(a.ghBin, "pr", "view", strconv.Itoa(number), "--web")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
