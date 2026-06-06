#!/usr/bin/env bash

set -euo pipefail

tmux_bin="$(command -v tmux 2>/dev/null || true)"
fzf_bin="$(command -v fzf 2>/dev/null || true)"
git_bin="$(command -v git 2>/dev/null || true)"

fail() {
	local message="$1"
	echo "$message" >&2
	if [ -n "$tmux_bin" ]; then
		"$tmux_bin" display-message "$message" >/dev/null 2>&1 || true
	fi
	if [ -t 1 ]; then
		echo
		echo "Press Enter to close..."
		read -r _
	fi
	exit 1
}

for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
	[ -n "$tmux_bin" ] && break
	[ -x "$candidate" ] && tmux_bin="$candidate"
done

for candidate in /opt/homebrew/bin/fzf /usr/local/bin/fzf; do
	[ -n "$fzf_bin" ] && break
	[ -x "$candidate" ] && fzf_bin="$candidate"
done

[ -n "$tmux_bin" ] && "$tmux_bin" list-sessions >/dev/null 2>&1 || fail "thread picker: tmux server not available"
[ -n "$git_bin" ] || fail "thread picker: git not found in PATH"

mode="${1:-pick}"
pin_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-thread-picker"
pin_file="$pin_state_dir/pins"
title_file="$pin_state_dir/titles"
archive_file="$pin_state_dir/archives"
seen_file="$pin_state_dir/seen-finished"
repo_cache_file="$pin_state_dir/repo-candidates.tsv"
worktree_cache_file="$pin_state_dir/worktrees.tsv"
codex_state_cache_file="$pin_state_dir/codex-states.tsv"
display_cache_file="$pin_state_dir/display-rows.tsv"
repo_cache_ttl="${TMUX_THREAD_CACHE_TTL:-300}"
codex_state_cache_ttl="${TMUX_THREAD_CODEX_CACHE_TTL:-15}"

toggle_pin() {
	local key="$1"
	local tmp_file

	[ -n "$key" ] || exit 0
	mkdir -p "$pin_state_dir"
	touch "$pin_file"

	tmp_file="${pin_file}.$$"
	if grep -Fxq "$key" "$pin_file" 2>/dev/null; then
		grep -Fxv "$key" "$pin_file" >"$tmp_file" || true
	else
		cat "$pin_file" >"$tmp_file"
		printf '%s\n' "$key" >>"$tmp_file"
	fi
	sort -u "$tmp_file" >"$pin_file"
	rm -f "$tmp_file"
}

if [ "$mode" = "--toggle-pin" ]; then
	toggle_pin "${2:-}"
	exit 0
fi

toggle_archive() {
	local key="$1"
	local tmp_file

	[ -n "$key" ] || exit 0
	mkdir -p "$pin_state_dir"
	touch "$archive_file"

	tmp_file="${archive_file}.$$"
	if grep -Fxq "$key" "$archive_file" 2>/dev/null; then
		grep -Fxv "$key" "$archive_file" >"$tmp_file" || true
	else
		cat "$archive_file" >"$tmp_file"
		printf '%s\n' "$key" >>"$tmp_file"
	fi
	sort -u "$tmp_file" >"$archive_file"
	rm -f "$tmp_file"
}

set_title() {
	local key="$1"
	local title="${2:-}"
	local tmp_file

	[ -n "$key" ] || exit 0
	mkdir -p "$pin_state_dir"
	touch "$title_file"

	tmp_file="${title_file}.$$"
	awk -F '\t' -v key="$key" '$1 != key' "$title_file" >"$tmp_file" 2>/dev/null || true
	if [ -n "$title" ]; then
		printf '%s\t%s\n' "$key" "$title" >>"$tmp_file"
	fi
	mv "$tmp_file" "$title_file"
}

prompt_title() {
	local key="$1"
	local command

	[ -n "$key" ] || exit 0
	printf -v command '%q --set-title %q %s' "$0" "$key" "'%%'"
	"$tmux_bin" command-prompt -p "thread title" "run-shell $command"
}

edit_title() {
	local key="$1"
	local title

	[ -n "$key" ] || exit 0
	printf 'Thread title (empty clears): ' > /dev/tty
	IFS= read -r title < /dev/tty || title=""
	set_title "$key" "$title"
}

if [ "$mode" = "--toggle-archive" ]; then
	toggle_archive "${2:-}"
	exit 0
fi

if [ "$mode" = "--set-title" ]; then
	set_title "${2:-}" "${3:-}"
	exit 0
fi

if [ "$mode" = "--prompt-title" ]; then
	prompt_title "${2:-}"
	exit 0
fi

if [ "$mode" = "--edit-title" ]; then
	edit_title "${2:-}"
	exit 0
fi

if [ "$mode" = "--watch-fzf" ]; then
	fzf_socket="${2:-}"
	[ -n "$fzf_socket" ] || exit 0
	while [ -S "$fzf_socket" ]; do
		"$0" --refresh-cache >/dev/null 2>&1 || true
		[ -S "$fzf_socket" ] || exit 0
		curl --silent --show-error --max-time 1 --unix-socket "$fzf_socket" http \
			--data-binary "reload(cat '$display_cache_file')" >/dev/null 2>&1 || exit 0
		sleep "${TMUX_THREAD_WATCH_INTERVAL:-2}"
	done
	exit 0
fi

source_session="$("$tmux_bin" display-message -p '#S' 2>/dev/null || true)"
if [ -z "$source_session" ]; then
	source_session="$("$tmux_bin" list-sessions -F '#{session_name}' 2>/dev/null | head -n1 || true)"
fi
[ -n "$source_session" ] || fail "thread picker: unable to resolve tmux session"

source_path="$("$tmux_bin" display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}' 2>/dev/null || true)"
[ -n "$source_path" ] || source_path="$PWD"

if [ -n "${NO_COLOR:-}" ] && [ "${TMUX_THREAD_COLOR:-1}" != "1" ]; then
	c_reset=""
	c_bold=""
	c_dim=""
	c_green=""
	c_yellow=""
	c_cyan=""
	c_blue=""
	c_magenta=""
	c_red=""
	c_dot_look=""
	c_dot_current=""
	c_dot_open=""
	c_dot_pick=""
	c_dot_work=""
	c_proc=""
else
	c_reset=$'\033[0m'
	c_bold=$'\033[1m'
	c_dim=$'\033[2m'
	c_green=$'\033[32m'
	c_yellow=$'\033[33m'
	c_cyan=$'\033[36m'
	c_blue=$'\033[34m'
	c_magenta=$'\033[35m'
	c_red=$'\033[31m'
	c_dot_look=$'\033[1;38;5;196m'
	c_dot_current=$'\033[1;38;5;46m'
	c_dot_open=$'\033[1;38;5;33m'
	c_dot_pick=$'\033[1;38;5;201m'
	c_dot_work=$'\033[38;5;244m'
	c_proc=$'\033[1;38;5;220m'
fi

color_state() {
	local kind="$1"
	local state="$2"

	case "$kind" in
		PICK) printf '%s%s%s%s\n' "$c_bold" "$c_cyan" "$state" "$c_reset" ;;
		OPEN)
			if [[ "$state" == open\** ]]; then
				printf '%s%s%s%s\n' "$c_bold" "$c_green" "$state" "$c_reset"
			else
				printf '%s%s%s%s\n' "$c_green" "$state" "$c_reset"
			fi
			;;
		WT) printf '%s%s%s\n' "$c_yellow" "$state" "$c_reset" ;;
		*) printf '%s\n' "$state" ;;
	esac
}

clip_text() {
	local value="$1"
	local width="$2"
	local keep

	if [ "${#value}" -le "$width" ]; then
		printf '%s\n' "$value"
		return 0
	fi

	keep=$((width - 1))
	if [ "$keep" -le 0 ]; then
		printf '~\n'
	else
		printf '%s~\n' "${value:0:$keep}"
	fi
}

pad_text() {
	local value="$1"
	local width="$2"
	local clipped

	clipped="$(clip_text "$value" "$width")"
	printf "%-${width}s" "$clipped"
}

color_text() {
	local color="$1"
	local value="$2"

	printf '%s%s%s' "$color" "$value" "$c_reset"
}

thread_title() {
	local key="$1"
	local fallback="$2"
	local title

	if [ -n "$key" ] && [ -s "$title_file" ]; then
		title="$(awk -F '\t' -v key="$key" '$1 == key { print $2; exit }' "$title_file" 2>/dev/null || true)"
		if [ -n "$title" ]; then
			printf '%s\n' "$title"
			return 0
		fi
	fi

	printf '%s\n' "$fallback"
}

is_archived() {
	local key="$1"
	[ -n "$key" ] && [ -s "$archive_file" ] && grep -Fxq "$key" "$archive_file" 2>/dev/null
}

mark_seen_finished() {
	local key="$1"

	[ -n "$key" ] || return 0
	mkdir -p "$pin_state_dir"
	touch "$seen_file"
	if ! grep -Fxq "$key" "$seen_file" 2>/dev/null; then
		printf '%s\n' "$key" >>"$seen_file"
	fi
}

clear_seen_finished() {
	local key="$1"
	local tmp_file

	[ -n "$key" ] || return 0
	[ -s "$seen_file" ] || return 0
	tmp_file="${seen_file}.$$"
	grep -Fxv "$key" "$seen_file" >"$tmp_file" || true
	mv "$tmp_file" "$seen_file"
}

has_seen_finished() {
	local key="$1"
	[ -n "$key" ] && [ -s "$seen_file" ] && grep -Fxq "$key" "$seen_file" 2>/dev/null
}

emit_row() {
	local kind="$1"
	local state="$2"
	local branch="$3"
	local target="$4"
	local window="$5"
	local path="$6"
	local selection_target="$7"
	local project="$8"
	local pin_key="$9"
	local row_signal="${10:-}"
	local process_signal="${11:-}"
	local detail_override="${12:-}"
	local pinned archived archive_label pin_label state_label title detail branch_col display sort_key relative_path fallback_title dot proc_marker

	if is_archived "$pin_key" && [ "${TMUX_THREAD_SHOW_ARCHIVED:-0}" != "1" ]; then
		return 0
	fi

	archived=" "
	is_archived "$pin_key" && archived="A"
	pinned=" "
	if [ -n "$pin_key" ] && [ -s "$pin_file" ] && grep -Fxq "$pin_key" "$pin_file" 2>/dev/null; then
		pinned="P"
	fi

	pin_label=" "
	[ "$pinned" = "P" ] && pin_label="P"
	archive_label=" "
	[ "$archived" = "A" ] && archive_label="A"
	state_label="$state"
	[ "$state" = "open " ] && state_label="open"

	case "$row_signal" in
		codex_done)
			dot="$(color_text "$c_dot_current" "●")"
			state_label="wait"
			;;
		codex_running)
			dot="$(color_text "$c_proc" "▶")"
			state_label="run"
			;;
		*) dot=" " ;;
	esac
	if [ "$process_signal" = "process" ]; then
		proc_marker="$(color_text "$c_proc" "!")"
	else
		proc_marker=" "
	fi

	if [ -n "$detail_override" ]; then
		relative_path="$detail_override"
	else
		relative_path="$(project_relative_path "$path")"
	fi

	case "$kind" in
		PICK)
			fallback_title="worktree picker"
			detail="$relative_path"
			;;
		OPEN|WT)
			fallback_title="$(basename "$path")"
			detail="$relative_path"
			;;
		*)
			fallback_title="$window"
			detail="$relative_path"
			;;
	esac

	title="$(thread_title "$pin_key" "$fallback_title")"
	title="$(pad_text "$title" 30)"
	detail="$(pad_text "$detail" 56)"
	branch_col="$(pad_text "$branch" 56)"

	display="$(
		printf '%s%s %s %s  %s  %s  %s' \
			"$dot" \
			"$proc_marker" \
			"$(color_text "$c_red" "$pin_label$archive_label")" \
			"$(color_state "$kind" "$(pad_text "$state_label" 6)")" \
			"$title" \
			"$(color_text "$c_dim" "$detail")" \
			"$(color_text "$c_magenta" "$branch_col")"
	)"

	sort_key="1"
	[ "$pinned" = "P" ] && sort_key="0"
	[ "$archived" = "A" ] && sort_key="9"

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$sort_key|$(printf '%s' "$project" | tr '[:upper:]' '[:lower:]')|$kind|$path" \
		"$kind" \
		"$display" \
		"$selection_target" \
		"$branch" \
		"$pin_key" \
		"$project"
}

emit_group_header() {
	local label="$1"
	local display

	display="$(printf '%s%s%s' "$c_bold$c_cyan" ":: $label" "$c_reset")"
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "GROUP" "$display" "" "" "" "$label"
}

render_grouped_rows() {
	local sorted_file="$1"
	local row sort_key kind display target branch pin_key project current_project has_pinned=0 has_archived=0 printed_projects_file

	printed_projects_file="$tmp_dir/printed-projects.txt"
	: >"$printed_projects_file"

	while IFS=$'\t' read -r sort_key kind display target branch pin_key project; do
		[ -n "$kind" ] || continue
		case "$sort_key" in
			0\|*) has_pinned=1 ;;
			9\|*) has_archived=1 ;;
		esac
	done <"$sorted_file"

	if [ "$has_pinned" -eq 1 ]; then
		emit_group_header "Pinned"
		while IFS=$'\t' read -r sort_key kind display target branch pin_key project; do
			case "$sort_key" in
				0\|*) printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$display" "$target" "$branch" "$pin_key" "$project" ;;
			esac
		done <"$sorted_file"
	fi

	while IFS=$'\t' read -r sort_key kind display target branch pin_key project; do
		[ -n "$kind" ] || continue
		case "$sort_key" in
			0\|*|9\|*) continue ;;
		esac
		if ! grep -Fxq "$project" "$printed_projects_file" 2>/dev/null; then
			printf '%s\n' "$project" >>"$printed_projects_file"
			emit_group_header "$project"
		fi
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$display" "$target" "$branch" "$pin_key" "$project"
	done <"$sorted_file"

	if [ "$has_archived" -eq 1 ]; then
		emit_group_header "Archived"
		while IFS=$'\t' read -r sort_key kind display target branch pin_key project; do
			case "$sort_key" in
				9\|*) printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$display" "$target" "$branch" "$pin_key" "$project" ;;
			esac
		done <"$sorted_file"
	fi
}

build_rows() {
	: >"$repo_candidates_file"
	: >"$open_paths_file"
	: >"$rows_file"
	"$tmux_bin" list-panes -a -F '#{window_id}'$'\t''#{pane_id}'$'\t''#{pane_current_command}' 2>/dev/null >"$pane_rows_file" || : >"$pane_rows_file"
	build_codex_state_cache

	scan_roots=()
	source_path="$(normalize_existing_path "$source_path" || true)"
	add_current_repo_candidate "$source_path"
	add_current_repo_candidate "$HOME/.dotfiles"

	if [ -n "${TMUX_THREAD_ROOTS:-}" ]; then
		IFS=':' read -r -a configured_roots <<<"$TMUX_THREAD_ROOTS"
		for configured_root in "${configured_roots[@]:-}"; do
			add_scan_root "$configured_root"
		done
	else
		add_scan_root "$HOME/coding"
		add_scan_root "$HOME/Projects"
		add_scan_root "$HOME/dev"
		add_scan_root "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
	fi

	collect_cached_repo_candidates
	ensure_worktree_cache

	emit_open_rows >>"$rows_file"
	emit_worktree_rows >>"$rows_file"
	sort -t "$(printf '\t')" -k1,1 "$rows_file" >"$sorted_rows_file"
	render_grouped_rows "$sorted_rows_file" >"$display_rows_file"
}

write_display_cache() {
	[ -s "$display_rows_file" ] || return 0
	mkdir -p "$pin_state_dir"
	cp "$display_rows_file" "$display_cache_file" 2>/dev/null || true
}

refresh_display_cache_background() {
	(
		"$0" --refresh-cache
	) >/dev/null 2>&1 &
}

normalize_existing_path() {
	local p="$1"
	while [ ! -e "$p" ] && [ "$p" != "/" ]; do
		p="$(dirname "$p")"
	done
	[ -e "$p" ] && (cd "$p" 2>/dev/null && pwd)
}

repo_root() {
	"$git_bin" -C "$1" rev-parse --show-toplevel 2>/dev/null || true
}

git_common_dir() {
	local root="$1"
	local common_dir

	common_dir="$("$git_bin" -C "$root" rev-parse --git-common-dir 2>/dev/null || true)"
	[ -n "$common_dir" ] || return 1
	if [ "${common_dir#/}" = "$common_dir" ]; then
		(cd "$root" && cd "$common_dir" 2>/dev/null && pwd)
	else
		printf '%s\n' "$common_dir"
	fi
}

branch_name() {
	local path="$1"
	local branch

	branch="$("$git_bin" -C "$path" branch --show-current 2>/dev/null || true)"
	if [ -z "$branch" ]; then
		branch="$("$git_bin" -C "$path" rev-parse --short HEAD 2>/dev/null || true)"
	fi
	[ -n "$branch" ] && printf '%s\n' "$branch" || printf '%s\n' "-"
}

project_name() {
	local path="$1"
	local common_dir common_base main_checkout

	common_dir="$(git_common_dir "$path" 2>/dev/null || true)"
	if [ -n "$common_dir" ]; then
		common_base="$(basename "$common_dir")"
		if [ "$common_base" != ".git" ] && [ "${common_base%.git}" != "$common_base" ]; then
			printf '%s\n' "${common_base%.git}"
			return 0
		fi
		main_checkout="$(dirname "$common_dir")"
		basename "$main_checkout" | sed 's/\.git$//'
		return 0
	fi

	basename "$path"
}

project_relative_path() {
	local path="$1"
	local common_dir common_base base rel

	common_dir="$(git_common_dir "$path" 2>/dev/null || true)"
	if [ -n "$common_dir" ]; then
		common_base="$(basename "$common_dir")"
		if [ "$common_base" != ".git" ] && [ "${common_base%.git}" != "$common_base" ]; then
			base="$common_dir"
		else
			base="$path"
		fi

		if [ "$path" = "$base" ]; then
			printf '.\n'
			return 0
		fi
		case "$path" in
			"$base"/*)
				rel="${path#"$base"/}"
				[ -n "$rel" ] && printf '%s\n' "$rel" || printf '.\n'
				return 0
				;;
		esac
	fi

	case "$path" in
		"$HOME"/*) printf '~/%s\n' "${path#"$HOME"/}" ;;
		*) printf '%s\n' "$path" ;;
	esac
}

sanitize_name() {
	printf '%s\n' "$1" \
		| tr '/[:space:]' '--' \
		| tr -cd 'A-Za-z0-9._-' \
		| sed 's/^-*//; s/-*$//'
}

sanitize_branch_path() {
	local raw="$1"
	local part safe result=""

	IFS='/' read -r -a parts <<<"$raw"
	for part in "${parts[@]:-}"; do
		safe="$(printf '%s\n' "$part" | tr '[:space:]' '-' | tr -cd 'A-Za-z0-9._-')"
		if [ -z "$safe" ] || [ "$safe" = "." ] || [ "$safe" = ".." ]; then
			safe="thread"
		fi
		if [ -z "$result" ]; then
			result="$safe"
		else
			result="$result/$safe"
		fi
	done

	[ -n "$result" ] || result="thread"
	printf '%s\n' "$result"
}

next_thread_window_index() {
	local session="$1"
	local candidate="${2:-6}"
	local used_indexes

	used_indexes="$("$tmux_bin" list-windows -t "$session" -F '#{window_index}' 2>/dev/null || true)"
	while printf '%s\n' "$used_indexes" | grep -qx "$candidate"; do
		candidate=$((candidate + 1))
	done
	printf '%s\n' "$candidate"
}

window_for_path() {
	local path="$1"
	local window_id pane_path tagged_path pane_root

	while IFS=$'\t' read -r window_id pane_path; do
		[ -n "$window_id" ] || continue

		tagged_path="$("$tmux_bin" show-options -w -t "$window_id" -v @secondary-worktree-path 2>/dev/null || true)"
		if [ "$tagged_path" = "$path" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{session_name}:#{window_index}'
			return 0
		fi

		pane_root="$(repo_root "$pane_path")"
		if [ -n "$pane_root" ] && [ "$pane_root" = "$path" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{session_name}:#{window_index}'
			return 0
		fi
	done < <("$tmux_bin" list-windows -a -F '#{window_id}'$'\t''#{pane_current_path}' 2>/dev/null)

	return 1
}

window_codex_state() {
	local window_id="$1"
	local state

	state="$(awk -F '\t' -v window_id="$window_id" '$1 == window_id { print $2; exit }' "$codex_state_rows_file" 2>/dev/null || true)"
	[ -n "$state" ] && printf '%s\n' "$state"
	return 0
}

build_codex_state_cache() {
	local cache_age tmp_cache window_id pane_id pane_command pane_text state saw_window

	mkdir -p "$pin_state_dir"
	cache_age="$(cache_age_seconds "$codex_state_cache_file" 2>/dev/null || true)"
	if [ -n "$cache_age" ] && [ "$cache_age" -lt "$codex_state_cache_ttl" ]; then
		cp "$codex_state_cache_file" "$codex_state_rows_file" 2>/dev/null || : >"$codex_state_rows_file"
		return 0
	fi

	tmp_cache="${codex_state_cache_file}.$$"
	: >"$tmp_cache"
	awk -F '\t' '$3 ~ /codex/ { print $1 "\t" $2 "\t" $3 }' "$pane_rows_file" | while IFS=$'\t' read -r window_id pane_id pane_command; do
		[ -n "$pane_id" ] || continue
		if awk -F '\t' -v window_id="$window_id" '$1 == window_id { found=1 } END { exit found ? 0 : 1 }' "$tmp_cache" 2>/dev/null; then
			continue
		fi
		pane_text="$("$tmux_bin" capture-pane -p -t "$pane_id" -S -80 2>/dev/null || true)"
		state="unknown"
		if printf '%s\n' "$pane_text" | grep -q 'Working ('; then
			state="running"
		elif printf '%s\n' "$pane_text" | grep -q '^[[:space:]]*› '; then
			state="done"
		fi
		printf '%s\t%s\n' "$window_id" "$state" >>"$tmp_cache"
	done
	mv "$tmp_cache" "$codex_state_cache_file"
	cp "$codex_state_cache_file" "$codex_state_rows_file" 2>/dev/null || : >"$codex_state_rows_file"
}

is_ignored_running_command() {
	case "${1:-}" in
		""|zsh|bash|sh|dash|fish|ksh|nu|pwsh|tmux|nvim|vim|vi|codex|codex-*|*codex*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

window_has_running_process() {
	local window_id="$1"
	local pane_command

	while IFS= read -r pane_command; do
		if ! is_ignored_running_command "$pane_command"; then
			return 0
		fi
	done < <(awk -F '\t' -v window_id="$window_id" '$1 == window_id { print $3 }' "$pane_rows_file" 2>/dev/null)

	return 1
}

open_thread_window() {
	local path="$1"
	local branch="$2"

	mark_seen_finished "$path"
	exec "$HOME/.dotfiles/bin/tmux-worktree-layout.sh" open "$source_session" "$path" "$branch"
}

new_worktree_base_dir() {
	local path="$1"
	local common_dir common_base parent

	common_dir="$(git_common_dir "$path" 2>/dev/null || true)"
	[ -n "$common_dir" ] || return 1
	common_base="$(basename "$common_dir")"

	if [ "$common_base" != ".git" ] && [ "${common_base%.git}" != "$common_base" ]; then
		case "$path" in
			"$common_dir"/*)
				parent="$(dirname "$path")"
				if [ -d "$parent" ] && [ "$parent" != "$common_dir" ]; then
					printf '%s\n' "$parent"
					return 0
				fi
				;;
		esac
		if [ -d "$common_dir/codex-" ]; then
			printf '%s\n' "$common_dir/codex-"
			return 0
		fi
		if [ -d "$common_dir/codex" ]; then
			printf '%s\n' "$common_dir/codex"
			return 0
		fi
		printf '%s\n' "$common_dir"
		return 0
	fi

	parent="$(dirname "$path")"
	printf '%s\n' "$parent"
}

create_new_thread() {
	local key="$1"
	local preferred_path source_repo_path title branch branch_dir base_dir target_path suffix add_err project_rows selected_project project_name_value

	preferred_path=""
	case "$key" in
		PICK:*) source_repo_path="${key#PICK:}" ;;
		*) source_repo_path="$key" ;;
	esac
	[ -d "${source_repo_path:-}" ] && preferred_path="$source_repo_path"

	project_rows="$(
		{
			if [ -n "$preferred_path" ]; then
				printf '%s\t%s\n' "$(project_name "$preferred_path")" "$preferred_path"
			fi
			if [ -s "$repo_cache_file" ]; then
				cut -f2 "$repo_cache_file"
			else
				find "$HOME/coding" "$HOME/Projects" "$HOME/dev" "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain" \
					\( -type d \( -name node_modules -o -name .cache -o -name .next -o -name dist -o -name build -o -name target -o -name vendor \) -prune \) -o \
					\( -type d -name .git -print -prune \) -o \
					\( -type f -name .git -print \) -o \
					\( -type d -name '*.git' -print -prune \) 2>/dev/null | while IFS= read -r candidate; do
						add_repo_candidate "$candidate" | cut -f2
					done
			fi | while IFS= read -r repo_path; do
				[ -d "$repo_path" ] || continue
				printf '%s\t%s\n' "$(project_name "$repo_path")" "$repo_path"
			done
		} | awk -F '\t' '!seen[$2]++' | sort -f
	)"

	[ -n "$project_rows" ] || fail "thread picker: no projects found for new thread"

	selected_project="$(
		printf '%s\n' "$project_rows" | "$fzf_bin" \
			--prompt="project > " \
			--delimiter=$'\t' \
			--with-nth=1,2 \
			--height=100% \
			--border
	)" || exit 0

	source_repo_path="$(printf '%s' "$selected_project" | cut -f2)"
	project_name_value="$(printf '%s' "$selected_project" | cut -f1)"
	[ -d "$source_repo_path" ] || fail "thread picker: invalid project path for new thread: $source_repo_path"

	title="$(
		"$fzf_bin" \
			--prompt="thread title for $project_name_value > " \
			--print-query \
			--height=100% \
			--border \
			--no-info \
			--phony \
			--bind "enter:accept-or-print-query" \
			< /dev/null | head -n1
	)" || title=""
	[ -n "$title" ] || exit 0

	branch="$(sanitize_branch_path "$title")"
	branch_dir="$(sanitize_branch_path "$branch")"
	base_dir="$(new_worktree_base_dir "$source_repo_path")" || fail "thread picker: unable to resolve worktree base"
	target_path="$base_dir/$branch_dir"
	suffix=2
	while [ -e "$target_path" ]; do
		target_path="$base_dir/$branch_dir-$suffix"
		suffix=$((suffix + 1))
	done

	if "$git_bin" -C "$source_repo_path" show-ref --verify --quiet "refs/heads/$branch"; then
		add_err="$("$git_bin" -C "$source_repo_path" worktree add "$target_path" "$branch" 2>&1 || true)"
	else
		add_err="$("$git_bin" -C "$source_repo_path" worktree add -b "$branch" "$target_path" 2>&1 || true)"
	fi
	[ -d "$target_path" ] || fail "thread picker: failed to create worktree: $add_err"

	rm -f "$worktree_cache_file"
	set_title "$target_path" "$title"
	open_thread_window "$target_path" "$branch"
}

add_scan_root() {
	local path="$1"
	[ -n "$path" ] || return 0
	path="${path/#\~/$HOME}"
	[ -d "$path" ] || return 0
	path="$(cd "$path" 2>/dev/null && pwd || true)"
	[ -n "$path" ] || return 0
	for existing in "${scan_roots[@]:-}"; do
		[ "$existing" = "$path" ] && return 0
	done
	scan_roots+=("$path")
}

add_repo_candidate() {
	local candidate="$1"
	local repo_path common_dir

	if [ "$(basename "$candidate")" = ".git" ]; then
		repo_path="$(dirname "$candidate")"
	else
		repo_path="$candidate"
	fi

	"$git_bin" -C "$repo_path" worktree list --porcelain >/dev/null 2>&1 || return 0
	common_dir="$(git_common_dir "$repo_path" 2>/dev/null || true)"
	[ -n "$common_dir" ] || common_dir="$repo_path"
	printf '%s\t%s\n' "$common_dir" "$repo_path"
}

collect_repo_candidates() {
	local root="$1"
	[ -d "$root" ] || return 0

	find "$root" \
		\( -type d \( -name node_modules -o -name .cache -o -name .next -o -name dist -o -name build -o -name target -o -name vendor \) -prune \) -o \
		\( -type d -name .git -print -prune \) -o \
		\( -type f -name .git -print \) -o \
		\( -type d -name '*.git' -print -prune \) \
		2>/dev/null | while IFS= read -r candidate; do
			add_repo_candidate "$candidate"
		done
}

cache_age_seconds() {
	local file="$1"
	[ -s "$file" ] || return 1
	perl -e 'print time - (stat($ARGV[0]))[9]' "$file" 2>/dev/null
}

collect_cached_repo_candidates() {
	local cache_age

	mkdir -p "$pin_state_dir"
	cache_age="$(cache_age_seconds "$repo_cache_file" 2>/dev/null || true)"
	if [ -s "$repo_cache_file" ]; then
		cat "$repo_cache_file" >>"$repo_candidates_file"
		if [ -n "$cache_age" ] && [ "$cache_age" -ge "$repo_cache_ttl" ]; then
			refresh_repo_cache_background
		fi
		return 0
	fi

	refresh_repo_cache
	cat "$repo_cache_file" >>"$repo_candidates_file"
}

refresh_repo_cache_background() {
	(
		refresh_repo_cache
	) >/dev/null 2>&1 &
}

refresh_repo_cache() {
	local tmp_cache scan_root

	tmp_cache="${repo_cache_file}.${BASHPID:-$$}"
	: >"$tmp_cache"
	for scan_root in "${scan_roots[@]:-}"; do
		collect_repo_candidates "$scan_root" >>"$tmp_cache"
	done
	sort -u "$tmp_cache" >"$repo_cache_file"
	rm -f "$tmp_cache"
}

add_current_repo_candidate() {
	local path="$1"
	local root

	[ -n "$path" ] || return 0
	root="$(repo_root "$path")"
	[ -n "$root" ] || return 0
	add_repo_candidate "$root" >>"$repo_candidates_file"
}

emit_open_rows() {
	local row session_name window_index window_id window_name activity_flag bell_flag pane_path tagged_path path root branch state target current_marker project row_signal codex_state process_signal metadata relative_path source_window_index

	source_window_index="$("$tmux_bin" display-message -p '#{window_index}' 2>/dev/null || true)"

	while IFS=$'\t' read -r session_name window_index window_id window_name activity_flag bell_flag pane_path tagged_path; do
		[ -n "$window_id" ] || continue
		path="$tagged_path"
		[ -n "$path" ] || path="$pane_path"
		path="$(normalize_existing_path "$path" || true)"
		[ -n "$path" ] || continue

		metadata="$(awk -F '\t' -v path="$path" '$1 == path { print $2 "\t" $3 "\t" $4; exit }' "$worktree_cache_file" 2>/dev/null || true)"
		if [ -n "$metadata" ]; then
			IFS=$'\t' read -r branch project relative_path <<<"$metadata"
			if [ "$branch" = "-" ]; then
				branch="$(branch_name "$path")"
			fi
		else
			root="$(repo_root "$path")"
			[ -n "$root" ] && path="$root"
			branch="$(branch_name "$path")"
			project="$(project_name "$path")"
			relative_path="$(project_relative_path "$path")"
		fi
		current_marker=" "
		if [ "$session_name" = "$source_session" ] && [ "$window_index" = "$source_window_index" ]; then
			current_marker="*"
		fi
		state="open$current_marker"
		target="${session_name}:${window_index}"
		row_signal="open"
		[ "$current_marker" = "*" ] && row_signal="current"
		if [ "$activity_flag" = "1" ] || [ "$bell_flag" = "1" ]; then
			row_signal="look"
		fi
		codex_state="$(window_codex_state "$window_id")"
		case "$codex_state" in
			done)
				if has_seen_finished "$path"; then
					row_signal="open"
					[ "$current_marker" = "*" ] && row_signal="current"
				else
					row_signal="codex_done"
				fi
				;;
			running)
				clear_seen_finished "$path"
				row_signal="codex_running"
				;;
		esac
		process_signal=""
		if window_has_running_process "$window_id"; then
			process_signal="process"
		fi
		emit_row "OPEN" "$state" "$branch" "$target" "$window_name" "$path" "$target" "$project" "$path" "$row_signal" "$process_signal" "$relative_path"
		printf '%s\n' "$path" >>"$open_paths_file"
	done < <("$tmux_bin" list-windows -a -F '#{session_name}'$'\t''#{window_index}'$'\t''#{window_id}'$'\t''#{window_name}'$'\t''#{window_activity_flag}'$'\t''#{window_bell_flag}'$'\t''#{pane_current_path}'$'\t''#{@secondary-worktree-path}' 2>/dev/null)
}

emit_picker_row() {
	local root branch project

	root="$(repo_root "$source_path")"
	[ -n "$root" ] || return 0
	branch="$(branch_name "$root")"
	project="$(project_name "$root")"
	emit_row "PICK" "pick" "$branch" "worktrees" "tmux-select-worktree" "$root" "$root" "$project" "PICK:$root" "pick"
}

emit_worktree_rows() {
	local path branch project relative_path

	ensure_worktree_cache

	while IFS=$'\t' read -r path branch project relative_path; do
		[ -d "$path" ] || continue
		if grep -Fxq "$path" "$open_paths_file" 2>/dev/null; then
			continue
		fi
		if [ -z "$project" ]; then
			project="$(project_name "$path")"
		fi
		if [ -z "$relative_path" ]; then
			relative_path="$(project_relative_path "$path")"
		fi
		emit_row "WT" "work" "$branch" "<open>" "$(basename "$path")" "$path" "$path" "$project" "$path" "work" "" "$relative_path"
	done <"$worktree_cache_file"
}

ensure_worktree_cache() {
	local cache_age

	mkdir -p "$pin_state_dir"
	cache_age="$(cache_age_seconds "$worktree_cache_file" 2>/dev/null || true)"
	if [ -s "$worktree_cache_file" ]; then
		if [ -n "$cache_age" ] && [ "$cache_age" -ge "$repo_cache_ttl" ]; then
			refresh_worktree_cache_background
		fi
		return 0
	fi

	refresh_worktree_cache
}

refresh_worktree_cache_background() {
	local repo_snapshot

	repo_snapshot="${pin_state_dir}/repo-candidates-for-worktrees.${BASHPID:-$$}.tsv"
	sort -u "$repo_candidates_file" >"$repo_snapshot" 2>/dev/null || : >"$repo_snapshot"
	(
		refresh_worktree_cache "$repo_snapshot"
		rm -f "$repo_snapshot"
	) >/dev/null 2>&1 &
}

refresh_worktree_cache() {
	local repo_source="${1:-$repo_candidates_file}"
	local repo_path path branch project relative_path tmp_cache

	tmp_cache="${worktree_cache_file}.${BASHPID:-$$}"
	sort -u "$repo_source" | cut -f2 | while IFS= read -r repo_path; do
		"$git_bin" -C "$repo_path" worktree list --porcelain 2>/dev/null | awk '
			BEGIN { path=""; branch="-" }
			function emit_entry() {
				if (path != "") {
					print path "\t" branch
				}
			}
			/^worktree / {
				emit_entry()
				path = substr($0, 10)
				branch = "-"
				next
			}
			/^branch / {
				branch = substr($0, 8)
				sub(/^refs\/heads\//, "", branch)
				next
			}
			/^detached/ {
				branch = "(detached)"
				next
			}
			END {
				emit_entry()
			}
		'
	done | sort -u | while IFS=$'\t' read -r path branch; do
		[ -d "$path" ] || continue
		project="$(project_name "$path")"
		relative_path="$(project_relative_path "$path")"
		printf '%s\t%s\t%s\t%s\n' "$path" "$branch" "$project" "$relative_path"
	done >"$tmp_cache"
	mv "$tmp_cache" "$worktree_cache_file"
}

if [ "$mode" = "--new-thread" ]; then
	create_new_thread "${2:-}"
	exit 0
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tmux-thread-picker.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
repo_candidates_file="$tmp_dir/repos.tsv"
open_paths_file="$tmp_dir/open-paths.txt"
rows_file="$tmp_dir/rows.tsv"
sorted_rows_file="$tmp_dir/sorted-rows.tsv"
display_rows_file="$tmp_dir/display-rows.tsv"
pane_rows_file="$tmp_dir/panes.tsv"
codex_state_rows_file="$tmp_dir/codex-states.tsv"

if [ "$mode" = "--refresh-cache" ]; then
	refresh_lock_dir="$pin_state_dir/display-refresh.lock"
	if ! mkdir "$refresh_lock_dir" 2>/dev/null; then
		exit 0
	fi
	trap 'rmdir "$refresh_lock_dir" 2>/dev/null || true; rm -rf "$tmp_dir"' EXIT
	build_rows
	write_display_cache
	exit 0
fi

if [ "$mode" = "pick" ] && [ -s "$display_cache_file" ]; then
	cp "$display_cache_file" "$display_rows_file" 2>/dev/null || : >"$display_rows_file"
	refresh_display_cache_background
else
	build_rows
	write_display_cache
fi

if [ ! -s "$display_rows_file" ]; then
	fail "thread picker: no tmux windows or git worktrees found"
fi

if [ "$mode" = "--list" ]; then
	cut -f2 "$display_rows_file" | perl -pe 's/\e\[[0-9;]*m//g' 2>/dev/null || cut -f2 "$display_rows_file"
	exit 0
fi

if [ "$mode" = "--rows" ]; then
	write_display_cache
	cat "$display_rows_file"
	exit 0
fi

[ -n "$fzf_bin" ] || fail "thread picker: fzf not found in PATH"

header="$(
	printf '      %s  %s  %s  %s' \
		"$(pad_text "state" 6)" \
		"$(pad_text "title" 30)" \
		"$(pad_text "path" 56)" \
		"$(pad_text "branch" 56)"
)"

selected="$(
		"$fzf_bin" \
		--prompt="thread > " \
		--delimiter=$'\t' \
		--with-nth=2 \
		--header="$header" \
		--header-border=line \
		--footer="Ctrl-n new | Ctrl-r refresh | Ctrl-o worktree picker | Ctrl-p pin | Ctrl-t title | Ctrl-a archive | Alt-a archived | Enter open" \
		--footer-border=line \
		--layout=reverse \
		--border \
		--ansi \
		--track \
		--listen="${tmp_dir}/fzf.sock" \
		--bind "start:execute-silent($0 --watch-fzf ${tmp_dir}/fzf.sock)" \
		--bind "ctrl-p:execute-silent($0 --toggle-pin {5})+reload($0 --rows)" \
		--bind "ctrl-a:execute-silent($0 --toggle-archive {5})+reload($0 --rows)" \
		--bind "alt-a:reload(TMUX_THREAD_SHOW_ARCHIVED=1 $0 --rows)" \
		--bind "ctrl-t:execute($0 --edit-title {5})+reload($0 --rows)" \
		--bind "ctrl-n:execute($0 --new-thread {5})+abort" \
		--bind "ctrl-r:reload($0 --rows)" \
		--bind "ctrl-o:execute($HOME/.dotfiles/bin/tmux-select-worktree.sh)" \
		--bind "):clear-query+search(::)" \
		--bind "(:clear-query+search(::)" \
		--height=100% \
		<"$display_rows_file" || true
)"

[ -n "$selected" ] || exit 0

selected_kind="$(printf '%s' "$selected" | cut -f1)"
selected_target="$(printf '%s' "$selected" | cut -f3)"
selected_branch="$(printf '%s' "$selected" | cut -f4)"
selected_key="$(printf '%s' "$selected" | cut -f5)"

case "$selected_kind" in
	GROUP)
		exit 0
		;;
	PICK)
		exec "$HOME/.dotfiles/bin/tmux-select-worktree.sh" "$source_session" "$selected_target"
		;;
	OPEN)
		mark_seen_finished "$selected_key"
		"$tmux_bin" switch-client -t "$selected_target"
		;;
	WT)
		open_thread_window "$selected_target" "$selected_branch"
		;;
	*)
		fail "thread picker: invalid selection"
		;;
esac
