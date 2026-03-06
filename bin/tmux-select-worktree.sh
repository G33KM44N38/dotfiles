#!/usr/bin/env bash

set -euo pipefail

tmux_bin="$(command -v tmux 2>/dev/null || true)"
fzf_bin="$(command -v fzf 2>/dev/null || true)"

fail() {
	local message="$1"
	echo "$message" >&2
	if [ -n "${TMUX:-}" ]; then
		"$tmux_bin" display-message "$message" >/dev/null 2>&1 || true
	fi
	if [ -t 1 ]; then
		echo
		echo "Press Enter to close..."
		read -r _
	fi
	exit 1
}

if [ -z "$tmux_bin" ]; then
	for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
		if [ -x "$candidate" ]; then
			tmux_bin="$candidate"
			break
		fi
	done
fi

if [ -z "$fzf_bin" ]; then
	for candidate in /opt/homebrew/bin/fzf /usr/local/bin/fzf; do
		if [ -x "$candidate" ]; then
			fzf_bin="$candidate"
			break
		fi
	done
fi

if [ -z "$tmux_bin" ] || ! "$tmux_bin" list-sessions >/dev/null 2>&1; then
	fail "secondary picker: tmux server not available"
fi

if [ -z "$fzf_bin" ]; then
	fail "secondary picker: fzf not found in PATH"
fi

source_session="${1:-}"
source_path="${2:-}"

if [ -z "$source_session" ]; then
	source_session="$("$tmux_bin" display-message -p '#S' 2>/dev/null || true)"
fi
if [ -z "$source_session" ]; then
	source_session="$("$tmux_bin" list-sessions -F '#{session_name}' 2>/dev/null | head -n1 || true)"
fi
if [ -z "$source_session" ]; then
	fail "secondary picker: unable to resolve session"
fi

if [ -z "$source_path" ]; then
	source_path="$("$tmux_bin" display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}' 2>/dev/null || true)"
fi
if [ -z "$source_path" ]; then
	source_path="$PWD"
fi

normalize_existing_path() {
	local p="$1"
	while [ ! -e "$p" ] && [ "$p" != "/" ]; do
		p="$(dirname "$p")"
	done
	[ -e "$p" ] && printf '%s\n' "$p"
}

source_path="$(normalize_existing_path "$source_path" || true)"
if [ -z "$source_path" ]; then
	source_path="$PWD"
fi

resolve_repo_root() {
	local from_path="$1"
	local common_dir top

	common_dir="$(git -C "$from_path" rev-parse --git-common-dir 2>/dev/null || true)"
	if [ -n "$common_dir" ]; then
		if [ "${common_dir#/}" = "$common_dir" ]; then
			common_dir="$(cd "$from_path" && cd "$common_dir" 2>/dev/null && pwd || true)"
		fi
		if [ -n "$common_dir" ] && [ -d "$common_dir" ] && git -C "$common_dir" worktree list --porcelain >/dev/null 2>&1; then
			printf '%s\n' "$common_dir"
			return 0
		fi
	fi

	top="$(git -C "$from_path" rev-parse --show-toplevel 2>/dev/null || true)"
	if [ -n "$top" ] && [ -d "$top" ] && git -C "$top" worktree list --porcelain >/dev/null 2>&1; then
		printf '%s\n' "$top"
		return 0
	fi

	return 1
}

add_candidate_path() {
	local p="$1"
	[ -z "$p" ] && return 0
	p="$(normalize_existing_path "$p" || true)"
	[ -z "$p" ] && return 0
	for existing in "${candidate_paths[@]:-}"; do
		[ "$existing" = "$p" ] && return 0
	done
	candidate_paths+=("$p")
}

candidate_paths=()
add_candidate_path "$source_path"
add_candidate_path "$("$tmux_bin" display-message -p -t '{last}' '#{pane_current_path}' 2>/dev/null || true)"
session_secondary_worktree="$("$tmux_bin" show-option -qv -t "$source_session" @secondary-worktree 2>/dev/null || true)"
if [ -z "$session_secondary_worktree" ]; then
	# Backward compatibility with old global option.
	session_secondary_worktree="$("$tmux_bin" show-option -gv @secondary-worktree 2>/dev/null || true)"
fi
add_candidate_path "$session_secondary_worktree"

repo_root=""
for candidate in "${candidate_paths[@]}"; do
	repo_root="$(resolve_repo_root "$candidate" || true)"
	[ -n "$repo_root" ] && break
done

if [ -z "$repo_root" ]; then
	fail "secondary picker: not in a git repository (checked: ${candidate_paths[*]})"
fi

fetch_values="$(git -C "$repo_root" config --get-all remote.origin.fetch 2>/dev/null || true)"
if ! printf '%s\n' "$fetch_values" | grep -q 'refs/remotes/origin'; then
	git -C "$repo_root" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" >/dev/null 2>&1 || true
fi
git -C "$repo_root" fetch --all >/dev/null 2>&1 || true

worktree_entries=()
while IFS= read -r line; do
	worktree_entries+=("$line")
done < <(
	git -C "$repo_root" worktree list --porcelain | awk '
		BEGIN { path=""; branch="(detached)"; is_bare=0 }
		function emit_entry() {
			if (path != "" && is_bare == 0) {
				print path "\t" branch
			}
		}
		/^worktree / {
			emit_entry()
			path = substr($0, 10)
			branch = "(detached)"
			is_bare = 0
			next
		}
		/^bare$/ {
			is_bare = 1
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
)

find_worktree_by_branch() {
	local needle="$1"
	local row path branch
	for row in "${worktree_entries[@]:-}"; do
		path="${row%%$'\t'*}"
		branch="${row#*$'\t'}"
		if [ "$branch" = "$needle" ] && [ -d "$path" ]; then
			printf '%s\n' "$path"
			return 0
		fi
	done
	return 1
}

display_rows=()
current_root="$(git -C "$source_path" rev-parse --show-toplevel 2>/dev/null || true)"
for item in "${worktree_entries[@]:-}"; do
	path="${item%%$'\t'*}"
	branch="${item#*$'\t'}"
	marker=" "
	if [ -n "$current_root" ] && [ "$path" = "$current_root" ]; then
		marker="*"
	fi
	display_rows+=("WT"$'\t'"${marker}"$'\t'"${branch}"$'\t'"${path}")
done

while IFS= read -r remote_branch; do
	[ -z "$remote_branch" ] && continue
	case "$remote_branch" in
		*/*) ;;
		*) continue ;;
	esac
	case "$remote_branch" in
		*/HEAD) continue ;;
	esac

	local_branch="${remote_branch#*/}"
	if find_worktree_by_branch "$local_branch" >/dev/null 2>&1; then
		continue
	fi
	display_rows+=("RB"$'\t'"+"$'\t'"${remote_branch}"$'\t'"<create-worktree>")
done < <(git -C "$repo_root" for-each-ref --sort=refname --format='%(refname:short)' refs/remotes)

if [ "${#display_rows[@]}" -eq 0 ]; then
	fail "secondary picker: no worktrees or remote branches available in $repo_root"
fi

selected="$(
	printf '%s\n' "${display_rows[@]}" | \
		"$fzf_bin" \
			--prompt="secondary worktree > " \
			--delimiter=$'\t' \
			--with-nth=2,3,4 \
			--header=$'mark\tbranch/path\ttarget' \
			--layout=reverse \
			--border \
			--height=100% \
		|| true
)"

if [ -z "$selected" ]; then
	exit 0
fi

selected_kind="$(printf '%s' "$selected" | cut -f1)"
selected_ref="$(printf '%s' "$selected" | cut -f3)"
selected_path="$(printf '%s' "$selected" | cut -f4)"
selected_branch="$selected_ref"

sanitize_name() {
	printf '%s\n' "$1" | tr '/[:space:]' '--' | tr -cd 'A-Za-z0-9._-'
}

sanitize_branch_path() {
	local raw="$1"
	local part safe result=""

	# Preserve slash hierarchy from branch names (e.g. feature/foo/bar),
	# but sanitize each segment to safe filesystem characters.
	IFS='/' read -r -a parts <<<"$raw"
	for part in "${parts[@]:-}"; do
		safe="$(printf '%s\n' "$part" | tr '[:space:]' '-' | tr -cd 'A-Za-z0-9._-')"
		if [ -z "$safe" ] || [ "$safe" = "." ] || [ "$safe" = ".." ]; then
			safe="wt"
		fi
		if [ -z "$result" ]; then
			result="$safe"
		else
			result="$result/$safe"
		fi
	done

	[ -z "$result" ] && result="wt"
	printf '%s\n' "$result"
}

pick_worktree_base_dir() {
	local root="$1"
	local preferred="$2"
	local normalized top preferred_parent
	normalized="$(normalize_existing_path "$preferred" || true)"
	if [ -n "$normalized" ] && [ -d "$normalized" ]; then
		top="$(git -C "$normalized" rev-parse --show-toplevel 2>/dev/null || true)"
		if [ -n "$top" ] && [ -d "$top" ] && [ "${top#$root/}" != "$top" ] && [ "$top" != "$root" ]; then
			preferred_parent="$(dirname "$top")"
			if [ -n "$preferred_parent" ] && [ -d "$preferred_parent" ] && [ "${preferred_parent#$root/}" != "$preferred_parent" ]; then
				printf '%s\n' "$preferred_parent"
				return 0
			fi
		fi

		if [ "${normalized#$root/}" != "$normalized" ] && [ "$normalized" != "$root" ]; then
			preferred_parent="$(dirname "$normalized")"
			if [ -n "$preferred_parent" ] && [ -d "$preferred_parent" ] && [ "${preferred_parent#$root/}" != "$preferred_parent" ]; then
				printf '%s\n' "$preferred_parent"
				return 0
			fi
		fi
	fi
	if [ -d "$root/codex" ]; then
		printf '%s\n' "$root/codex"
		return 0
	fi
	printf '%s\n' "$root"
}

find_window_for_worktree() {
	local worktree="$1"
	local window_id pane_path option_worktree pane_root

	while IFS=$'\t' read -r window_id pane_path; do
		[ -z "$window_id" ] && continue

		option_worktree="$("$tmux_bin" show-options -w -t "$window_id" -v @secondary-worktree-path 2>/dev/null || true)"
		if [ "$option_worktree" = "$worktree" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{window_index}'
			return 0
		fi

		pane_root="$(git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null || true)"
		if [ -n "$pane_root" ] && [ "$pane_root" = "$worktree" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{window_index}'
			return 0
		fi
	done < <("$tmux_bin" list-windows -t "$source_session" -F '#{window_id}'$'\t''#{pane_current_path}')

	return 1
}

next_worktree_window_index() {
	local session="$1"
	local min_index="${2:-6}"
	local used_indexes candidate

	used_indexes="$("$tmux_bin" list-windows -t "$session" -F '#{window_index}' 2>/dev/null || true)"
	candidate="$min_index"
	while printf '%s\n' "$used_indexes" | grep -qx "$candidate"; do
		candidate=$((candidate + 1))
	done

	printf '%s\n' "$candidate"
}

window_label="$(sanitize_name "$selected_branch")"
[ -z "$window_label" ] && window_label="secondary"
window_name="$window_label"

if [ "$selected_kind" = "RB" ]; then
	remote_branch="$selected_ref"
	local_branch="${remote_branch#*/}"
	selected_branch="$local_branch"
	selected_path="$(find_worktree_by_branch "$local_branch" || true)"

	if [ -z "$selected_path" ]; then
		base_dir="$(pick_worktree_base_dir "$repo_root" "$source_path")"
		branch_dir="$(sanitize_branch_path "$local_branch")"
		[ -z "$branch_dir" ] && branch_dir="wt"
		target_path="$base_dir/$branch_dir"
		suffix=2
		while [ -e "$target_path" ]; do
			target_path="$base_dir/$branch_dir-$suffix"
			suffix=$((suffix + 1))
		done

		if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/$local_branch"; then
			track_err="$(git -C "$repo_root" branch --track "$local_branch" "$remote_branch" 2>&1 || true)"
			if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/$local_branch"; then
				fail "secondary picker: failed to create tracking branch $local_branch from $remote_branch: $track_err"
			fi
		fi

		add_err="$(git -C "$repo_root" worktree add "$target_path" "$local_branch" 2>&1 || true)"
		if [ ! -d "$target_path" ]; then
			fail "secondary picker: failed to create worktree $target_path for $local_branch: $add_err"
		fi

		selected_path="$target_path"
	fi
fi

if [ -z "$selected_path" ] || [ ! -d "$selected_path" ]; then
	fail "secondary picker: invalid selected worktree path: $selected_path"
fi

secondary_agent="$("$tmux_bin" show-option -gv @secondary-agent 2>/dev/null || true)"
[ -z "$secondary_agent" ] && secondary_agent="codex"
secondary_agent_first="${secondary_agent%% *}"
if [ "${secondary_agent_first##*/}" = "codex" ] && [[ " $secondary_agent " != *" --dangerously-bypass-approvals-and-sandbox "* ]]; then
	secondary_agent="$secondary_agent --dangerously-bypass-approvals-and-sandbox"
fi

"$tmux_bin" set-option -q -t "$source_session" @secondary-worktree "$selected_path"
"$tmux_bin" set-option -q -t "$source_session" @secondary-session "$source_session"

existing_window="$(find_window_for_worktree "$selected_path" || true)"
if [ -n "$existing_window" ]; then
	"$tmux_bin" select-window -t "${source_session}:${existing_window}"
	if [ "$("$tmux_bin" display-message -p -t "${source_session}:${existing_window}" '#{window_zoomed_flag}')" = "1" ]; then
		"$tmux_bin" resize-pane -Z -t "${source_session}:${existing_window}"
	fi
	exit 0
fi

target_window_index="$(next_worktree_window_index "$source_session" 6)"
created_window="$("$tmux_bin" new-window -d -P -F '#{window_index}' -t "${source_session}:${target_window_index}" -n "$window_name" -c "$selected_path" 2>/dev/null || true)"
if [ -z "$created_window" ]; then
	fail "secondary picker: failed to create window at index >=6 in session $source_session"
fi

"$tmux_bin" set-option -wq -t "${source_session}:${created_window}" @secondary-worktree-path "$selected_path"

top_left_pane="$("$tmux_bin" display-message -p -t "${source_session}:${created_window}" '#{pane_id}' 2>/dev/null || true)"
if [ -z "$top_left_pane" ]; then
	fail "secondary picker: failed to resolve base pane for ${source_session}:${created_window}"
fi

bottom_pane="$("$tmux_bin" split-window -v -d -P -F '#{pane_id}' -t "$top_left_pane" -c "$selected_path" 2>/dev/null || true)"
if [ -z "$bottom_pane" ]; then
	fail "secondary picker: failed to create bottom terminal pane for ${source_session}:${created_window}"
fi

top_right_pane="$("$tmux_bin" split-window -h -d -P -F '#{pane_id}' -t "$top_left_pane" -c "$selected_path" 2>/dev/null || true)"
if [ -z "$top_right_pane" ]; then
	fail "secondary picker: failed to create codex pane for ${source_session}:${created_window}"
fi

printf -v nvim_cmd 'cd %q && nvim .' "$selected_path"
"$tmux_bin" send-keys -t "$top_left_pane" -R "$nvim_cmd" C-m

printf -v launch_cmd 'cd %q && %q %q' "$selected_path" "$HOME/.dotfiles/bin/tmux-supervise" "$secondary_agent"
"$tmux_bin" send-keys -t "$top_right_pane" -R "$launch_cmd" C-m
"$tmux_bin" select-window -t "${source_session}:${created_window}"
"$tmux_bin" select-pane -t "$bottom_pane"
if [ "$("$tmux_bin" display-message -p -t "${source_session}:${created_window}" '#{window_zoomed_flag}')" = "1" ]; then
	"$tmux_bin" resize-pane -Z -t "${source_session}:${created_window}"
fi
