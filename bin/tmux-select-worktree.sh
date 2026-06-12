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

cache_key=""
if command -v shasum >/dev/null 2>&1; then
	cache_key="$(printf '%s' "$repo_root" | shasum | awk '{print $1}')"
fi
[ -z "$cache_key" ] && cache_key="$(printf '%s' "$repo_root" | tr -cd 'A-Za-z0-9._-' | cut -c1-80)"
cache_file="/tmp/tmux-select-worktree-${UID:-$(id -u)}-${cache_key}.tsv"
cache_meta_file="${cache_file}.meta"
# Keep the cache for days, but refresh it in the background after it ages out.
cache_max_age_seconds="${TMUX_WORKTREE_CACHE_TTL:-604800}"
cache_refresh_after_seconds="${TMUX_WORKTREE_CACHE_REFRESH_AFTER:-86400}"
cache_block_on_stale="${TMUX_WORKTREE_BLOCK_ON_STALE:-0}"

cache_age_seconds() {
	local file="$1"
	[ -s "$file" ] || return 1
	perl -e 'print time - (stat($ARGV[0]))[9]' "$file" 2>/dev/null
}

path_mtime_seconds() {
	local path="$1"
	[ -e "$path" ] || return 1
	perl -e 'print((stat($ARGV[0]))[9])' "$path" 2>/dev/null
}

resolve_repo_git_path() {
	local root="$1"
	local rel="$2"
	local path

	path="$(git -C "$root" rev-parse --git-path "$rel" 2>/dev/null || true)"
	[ -n "$path" ] || return 1
	if [ "${path#/}" = "$path" ]; then
		path="$root/$path"
	fi
	printf '%s\n' "$path"
}

repo_cache_stamp() {
	local root="$1"
	local packed_refs refs_heads refs_remotes refs_origin worktrees

	packed_refs="$(resolve_repo_git_path "$root" packed-refs 2>/dev/null || true)"
	refs_heads="$(resolve_repo_git_path "$root" refs/heads 2>/dev/null || true)"
	refs_remotes="$(resolve_repo_git_path "$root" refs/remotes 2>/dev/null || true)"
	refs_origin="$(resolve_repo_git_path "$root" refs/remotes/origin 2>/dev/null || true)"
	worktrees="$(resolve_repo_git_path "$root" worktrees 2>/dev/null || true)"

	printf '%s|%s|%s|%s|%s\n' \
		"$(path_mtime_seconds "$packed_refs" 2>/dev/null || echo 0)" \
		"$(path_mtime_seconds "$refs_heads" 2>/dev/null || echo 0)" \
		"$(path_mtime_seconds "$refs_remotes" 2>/dev/null || echo 0)" \
		"$(path_mtime_seconds "$refs_origin" 2>/dev/null || echo 0)" \
		"$(path_mtime_seconds "$worktrees" 2>/dev/null || echo 0)"
}

build_worktree_cache() {
	local root="$1"
	local fetch_values

	fetch_values="$(git -C "$root" config --get-all remote.origin.fetch 2>/dev/null || true)"
	if ! printf '%s\n' "$fetch_values" | grep -q 'refs/remotes/origin'; then
		git -C "$root" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" >/dev/null 2>&1 || true
	fi
	git -C "$root" fetch --all >/dev/null 2>&1 || true

	git -C "$root" worktree list --porcelain | awk '
		BEGIN { path=""; branch="(detached)"; is_bare=0 }
		function emit_entry() {
			if (path != "" && is_bare == 0) {
				print "WT\t" path "\t" branch
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
	git -C "$root" for-each-ref --sort=refname --format='RB	%(refname:short)' refs/remotes
}

refresh_worktree_cache() {
	local tmp_file="${cache_file}.$$"
	local tmp_meta="${cache_meta_file}.$$"
	if build_worktree_cache "$repo_root" >"$tmp_file"; then
		repo_cache_stamp "$repo_root" >"$tmp_meta" || true
		mv "$tmp_file" "$cache_file"
		mv "$tmp_meta" "$cache_meta_file" 2>/dev/null || true
	else
		rm -f "$tmp_file"
		rm -f "$tmp_meta"
		return 1
	fi
}

refresh_worktree_cache_background() {
	local lock_dir="${cache_file}.lock"

	mkdir "$lock_dir" 2>/dev/null || return 0
	(
		trap 'rmdir "$lock_dir" >/dev/null 2>&1 || true' EXIT
		refresh_worktree_cache >/dev/null 2>&1
	) &
}

cache_age=""
if [ -s "$cache_file" ]; then
	cache_age="$(cache_age_seconds "$cache_file" || true)"
fi
cache_stamp=""
if [ -s "$cache_meta_file" ]; then
	cache_stamp="$(cat "$cache_meta_file" 2>/dev/null || true)"
fi
current_stamp="$(repo_cache_stamp "$repo_root" 2>/dev/null || true)"

if [ -z "$cache_age" ] || [ -z "$cache_stamp" ]; then
	refresh_worktree_cache || true
elif [ "$cache_stamp" != "$current_stamp" ]; then
	if [ "$cache_block_on_stale" = "1" ]; then
		refresh_worktree_cache || true
	else
		refresh_worktree_cache_background
	fi
elif [ "$cache_age" -gt "$cache_max_age_seconds" ] && [ "$cache_block_on_stale" = "1" ]; then
	refresh_worktree_cache || true
elif [ "$cache_age" -gt "$cache_refresh_after_seconds" ]; then
	refresh_worktree_cache_background
fi
if [ ! -s "$cache_file" ]; then
	fail "secondary picker: unable to build worktree cache for $repo_root"
fi

worktree_entries=()
remote_branch_entries=()
while IFS=$'\t' read -r entry_kind entry_value entry_extra; do
	[ -z "$entry_kind" ] && continue
	case "$entry_kind" in
		WT) worktree_entries+=("${entry_value}"$'\t'"${entry_extra}") ;;
		RB) remote_branch_entries+=("$entry_value") ;;
	esac
done <"$cache_file"

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

for remote_branch in "${remote_branch_entries[@]:-}"; do
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
done

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
	printf '%s\n' "$1" \
		| tr '/[:space:]' '--' \
		| tr -cd 'A-Za-z0-9._-' \
		| sed 's/^-*//; s/-*$//'
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

		rm -f "$cache_file"
		selected_path="$target_path"
	fi
fi

if [ -z "$selected_path" ] || [ ! -d "$selected_path" ]; then
	fail "secondary picker: invalid selected worktree path: $selected_path"
fi

exec "$HOME/.dotfiles/bin/tmux-worktree-layout.sh" open "$source_session" "$selected_path" "$selected_branch"
