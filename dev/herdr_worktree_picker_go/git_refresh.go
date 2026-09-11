package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

const gitRefreshTimeout = 15 * time.Second

// Nil Rows means keep the current results. A failed fetch can still update refs.
type gitBranchesRefreshedMsg struct {
	Rows []row
	Err  error
}

func (a *app) refreshGitBranchesCmd(ctx context.Context) tea.Cmd {
	// Background commands must not read mutable UI state.
	worker := *a
	return func() tea.Msg { return worker.refreshGitBranches(ctx) }
}

func (a *app) refreshGitBranches(ctx context.Context) gitBranchesRefreshedMsg {
	fetchCtx, cancel := context.WithTimeout(ctx, gitRefreshTimeout)
	defer cancel()
	if err := a.ensureBareFetchConfig(fetchCtx); err != nil {
		return gitBranchesRefreshedMsg{Err: err}
	}
	rules, err := a.gitConfig(fetchCtx, "--get-all", "remote.origin.fetch")
	if err != nil {
		return gitBranchesRefreshedMsg{Err: err}
	}
	mirror, err := a.gitConfig(fetchCtx, "--type=bool", "--get", "remote.origin.mirror")
	if err != nil {
		return gitBranchesRefreshedMsg{Err: err}
	}
	if mirror == "true" || !remoteTrackingFetchOnly(rules) {
		return gitBranchesRefreshedMsg{}
	}

	sshCommand := os.Getenv("GIT_SSH_COMMAND")
	if sshCommand == "" {
		sshCommand, err = a.gitConfig(fetchCtx, "--get", "core.sshCommand")
		if err != nil {
			return gitBranchesRefreshedMsg{Err: err}
		}
	}
	if sshCommand == "" {
		if sshPath := os.Getenv("GIT_SSH"); sshPath != "" {
			sshCommand = "'" + strings.ReplaceAll(sshPath, "'", "'\\''") + "'"
		} else {
			sshCommand = "ssh"
		}
	}
	cmd := a.gitRefreshCommand(fetchCtx, "fetch", "--no-tags", "--no-prune", "--no-prune-tags",
		"--no-write-fetch-head", "--no-auto-maintenance", "--recurse-submodules=no", "origin")
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0", "GCM_INTERACTIVE=never",
		"GIT_ASKPASS=false", "SSH_ASKPASS=false", "SSH_ASKPASS_REQUIRE=never",
		"GIT_SSH_COMMAND="+sshCommand+" -o BatchMode=yes -o StrictHostKeyChecking=yes")
	_, fetchErr := runRefreshCommand(fetchCtx, cmd)
	cancel()
	if ctx.Err() != nil {
		return gitBranchesRefreshedMsg{Err: ctx.Err()}
	}

	// A separate deadline lets us load successful refs after a timed-out or
	// partially failed fetch, including case-only branch collisions on macOS.
	rowsCtx, cancelRows := context.WithTimeout(ctx, 3*time.Second)
	defer cancelRows()
	worker := *a
	worker.commandContext = rowsCtx
	rows, rowsErr := worker.buildWorktreeRows()
	rowsErr = errors.Join(rowsErr, rowsCtx.Err())
	if rowsErr != nil {
		return gitBranchesRefreshedMsg{Err: errors.Join(fetchErr, rowsErr)}
	}
	return gitBranchesRefreshedMsg{Rows: rows, Err: fetchErr}
}

func (a *app) ensureBareFetchConfig(ctx context.Context) error {
	rules, err := a.gitConfig(ctx, "--get-all", "remote.origin.fetch")
	if err != nil || rules != "" {
		return err
	}
	bare, err := runRefreshCommand(ctx, a.gitRefreshCommand(ctx, "rev-parse", "--is-bare-repository"))
	if err != nil || bare != "true" {
		return err
	}
	url, err := a.gitConfig(ctx, "--get-all", "remote.origin.url")
	if err != nil || url == "" {
		return err
	}
	mirror, err := a.gitConfig(ctx, "--type=bool", "--get", "remote.origin.mirror")
	if err != nil || mirror == "true" {
		return err
	}
	// Local config lives in the common bare repository, shared by its worktrees.
	_, err = runRefreshCommand(ctx, a.gitRefreshCommand(ctx, "config", "--local",
		"--replace-all", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*", "^$"))
	return err
}

// Never let opening the picker update local branches, tags, or mirror refs.
// Preserve configured branch restrictions and negative refspecs as written.
func remoteTrackingFetchOnly(rules string) bool {
	positive := false
	for _, rule := range strings.Fields(rules) {
		if strings.HasPrefix(rule, "^") {
			continue
		}
		_, target, ok := strings.Cut(strings.TrimPrefix(rule, "+"), ":")
		if !ok || !strings.HasPrefix(target, "refs/remotes/") {
			return false
		}
		positive = true
	}
	return positive
}

func (a *app) gitConfig(ctx context.Context, args ...string) (string, error) {
	out, err := runRefreshCommand(ctx, a.gitRefreshCommand(ctx, append([]string{"config"}, args...)...))
	var exitErr *exec.ExitError
	if ctx.Err() == nil && errors.As(err, &exitErr) && exitErr.ExitCode() == 1 {
		return "", nil // An absent key is different from an unreadable config.
	}
	return out, err
}

func (a *app) gitRefreshCommand(ctx context.Context, args ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, a.gitBin, append([]string{"-C", a.root}, args...)...)
	// Git can spawn SSH/credential helpers. Cancel the whole group on timeout
	// or picker exit so a child cannot keep running or hold our output pipes.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		err := syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
		if errors.Is(err, syscall.ESRCH) {
			return os.ErrProcessDone
		}
		return err
	}
	cmd.WaitDelay = time.Second
	return cmd
}

func runRefreshCommand(ctx context.Context, cmd *exec.Cmd) (string, error) {
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	err := cmd.Run()
	if ctx.Err() != nil {
		err = ctx.Err()
	}
	if err != nil {
		if detail := strings.TrimSpace(stderr.String()); detail != "" {
			err = fmt.Errorf("%s: %w", detail, err)
		}
		return "", err
	}
	return strings.TrimSpace(stdout.String()), nil
}

func (m *model) applyGitBranchRefresh(msg gitBranchesRefreshedMsg) {
	m.gitLoading, m.gitLoaded, m.gitErr = false, msg.Rows != nil, msg.Err
	if msg.Rows == nil {
		return
	}
	rows := append([]row(nil), msg.Rows...)
	for _, existing := range m.allRows {
		if existing.Remote {
			rows = append(rows, existing)
		}
	}
	m.replaceRowsPreservingSelection(rows)
}

func (m *model) replaceRowsPreservingSelection(rows []row) {
	var selected row
	if m.cursor >= 0 && m.cursor < len(m.rows) {
		selected = m.rows[m.cursor]
	}
	sortRows(rows)
	m.allRows = m.app.filterModeRows(rows)
	m.applyFilter(false)
	m.cursor = 0
	for i, candidate := range m.rows {
		if candidate.Kind == selected.Kind && candidate.Machine == selected.Machine &&
			candidate.Target == selected.Target && candidate.Remote == selected.Remote {
			m.cursor = i
			break
		}
	}
}
