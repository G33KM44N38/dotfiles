package main

import (
	"fmt"
	"regexp"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

func newModel(rows []row) model {
	m := model{allRows: rows, mode: filterAll, width: 100, height: 24}
	m.applyFilter(true)
	return m
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		key := msg.String()
		if m.searching {
			return m.updateSearch(key, msg.Runes)
		}
		switch key {
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
		case "/":
			m.searching = true
		case "s":
			m.setMode(filterStack)
		case "a":
			m.setMode(filterAll)
		case "c":
			m.setMode(filterClassic)
		}
	}
	return m, nil
}

func (m model) updateSearch(key string, runes []rune) (tea.Model, tea.Cmd) {
	switch key {
	case "ctrl+c":
		m.quit = true
		return m, tea.Quit
	case "esc":
		m.query = ""
		m.searching = false
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
			query := []rune(m.query)
			m.query = string(query[:len(query)-1])
		}
	case "ctrl+u":
		m.query = ""
	default:
		m.query += string(runes)
	}
	m.applyFilter(true)
	return m, nil
}

func (m *model) setMode(mode filterMode) {
	m.mode = mode
	m.applyFilter(true)
}

func (m *model) applyFilter(reset bool) {
	query := strings.ToLower(strings.TrimSpace(m.query))
	m.rows = nil
	for _, item := range m.allRows {
		if m.mode != filterAll && item.Kind != m.mode {
			continue
		}
		if query != "" && !strings.Contains(strings.ToLower(item.searchText()), query) {
			continue
		}
		m.rows = append(m.rows, item)
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

func (m model) View() string {
	if m.quit {
		return ""
	}
	width := max(m.width, 80)
	height := max(m.height, 12)
	inner := width - 4
	available := max(height-9, 1)
	start := 0
	if m.cursor >= available {
		start = m.cursor - available + 1
	}
	end := min(start+available, len(m.rows))

	var output strings.Builder
	output.WriteString("╭" + strings.Repeat("─", inner+2) + "╮\n")
	output.WriteString(boxLine(color(colors.bold+colors.cyan, "pull requests"), inner) + "\n")
	output.WriteString(boxLine(m.tabs(), inner) + "\n")
	output.WriteString(boxLine(m.searchPrompt(), inner) + "\n")
	output.WriteString("├" + strings.Repeat("─", inner+2) + "┤\n")
	columns := fmt.Sprintf("  %-9s %-9s %-7s %-18s %s", "type", "id", "state", "base", "PRs / title")
	output.WriteString(boxLine(color(colors.dim, columns), inner) + "\n")
	for index := start; index < end; index++ {
		prefix := "  "
		if index == m.cursor {
			prefix = color(colors.cyan+colors.bold, "> ")
		}
		output.WriteString(boxLine(prefix+m.rows[index].display(inner-2), inner) + "\n")
	}
	for index := end - start; index < available; index++ {
		output.WriteString(boxLine("", inner) + "\n")
	}
	output.WriteString("├" + strings.Repeat("─", inner+2) + "┤\n")
	footer := color(colors.green, "Enter") + " open  " +
		color(colors.yellow, "↑↓") + " navigate  " +
		color(colors.yellow, "/") + " search  " +
		color(colors.yellow, "Esc") + " clear/quit"
	output.WriteString(boxLine(footer, inner) + "\n")
	output.WriteString("╰" + strings.Repeat("─", inner+2) + "╯")
	return output.String()
}

func (m model) tabs() string {
	return strings.Join([]string{
		m.tab("a", "all", filterAll),
		m.tab("s", "stack", filterStack),
		m.tab("c", "classic", filterClassic),
	}, "   ")
}

func (m model) tab(key, label string, mode filterMode) string {
	value := fmt.Sprintf("[%s] %s", key, label)
	if m.mode == mode {
		return color(colors.cyan+colors.bold, value)
	}
	return color(colors.dim, value)
}

func (m model) searchPrompt() string {
	if m.searching {
		return color(colors.bold+colors.cyan, "/ ") + m.query
	}
	if m.query != "" {
		return color(colors.dim, "search: ") + m.query
	}
	return color(colors.dim, "press / to search")
}

func (item row) display(width int) string {
	detailWidth := max(width-50, 12)
	return fmt.Sprintf(
		"%-9s %-9s %-7s %-18s %s",
		color(item.kindColor(), padPlain(item.kindLabel(), 9)),
		color(colors.bold, padPlain(item.ID, 9)),
		color(item.stateColor(), padPlain(item.State, 7)),
		color(colors.dim, padPlain(item.Base, 18)),
		truncatePlain(item.Detail, detailWidth),
	)
}

func (item row) kindLabel() string {
	if item.Kind == filterStack {
		return "stack"
	}
	return "classic"
}

func (item row) kindColor() string {
	if item.Kind == filterStack {
		return colors.magenta + colors.bold
	}
	return colors.cyan
}

func (item row) stateColor() string {
	if item.State == "draft" {
		return colors.yellow
	}
	return colors.green
}

func (item row) searchText() string {
	return strings.Join([]string{item.kindLabel(), item.ID, item.State, item.Base, item.Detail, item.Target}, " ")
}

func (item row) tsv() string {
	return strings.Join([]string{item.kindLabel(), item.ID, item.State, item.Base, item.Detail, item.Target}, "\t")
}

func chooseNonInteractive(rows []row, selector string) (row, bool) {
	selector = strings.ToLower(selector)
	for _, item := range rows {
		if strings.Contains(strings.ToLower(item.searchText()), selector) {
			return item, true
		}
	}
	return row{}, false
}

func boxLine(value string, width int) string {
	value = ansiTruncate(value, width)
	padding := max(width-ansiVisibleLen(value), 0)
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
	value = truncatePlain(value, width)
	return value + strings.Repeat(" ", max(width-len([]rune(value)), 0))
}

func color(code, value string) string {
	return code + value + colors.reset
}

var ansiPattern = regexp.MustCompile(`\x1b\[[0-9;]*m`)

func ansiVisibleLen(value string) int {
	return len([]rune(ansiPattern.ReplaceAllString(value, "")))
}

func ansiTruncate(value string, width int) string {
	if ansiVisibleLen(value) <= width {
		return value
	}
	plain := ansiPattern.ReplaceAllString(value, "")
	return truncatePlain(plain, width)
}
