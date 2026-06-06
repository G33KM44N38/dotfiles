#!/usr/bin/env bash

set -euo pipefail

require_bin() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "tmux-git: missing binary: $1" >&2
		exit 1
	}
}

require_bin git
require_bin gh
require_bin fzf
require_bin tmux

fail() {
	local message="$1"
	echo "$message" >&2
	tmux display-message "$message" >/dev/null 2>&1 || true
	exit 1
}

tmux_session() {
	tmux display-message -p '#S' 2>/dev/null || true
}

tmux_path() {
	tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}' 2>/dev/null || pwd
}

repo_root() {
	git -C "$1" rev-parse --show-toplevel 2>/dev/null || true
}

git_common_dir() {
	local root="$1"
	local common_dir

	common_dir="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null || true)"
	[ -z "$common_dir" ] && return 1

	if [ "${common_dir#/}" = "$common_dir" ]; then
		(cd "$root" && cd "$common_dir" && pwd)
	else
		printf '%s\n' "$common_dir"
	fi
}

worktree_path_for_branch() {
	local root="$1"
	local branch="$2"

	git -C "$root" worktree list --porcelain | awk -v branch="$branch" '
		BEGIN { path=""; current="" }
		/^worktree / { path = substr($0, 10); current = ""; next }
		/^branch / {
			current = substr($0, 8)
			sub(/^refs\/heads\//, "", current)
			if (current == branch) {
				print path
				exit
			}
		}
	'
}

window_for_worktree() {
	local session="$1"
	local worktree="$2"
	local window_id pane_path tagged_worktree pane_root

	while IFS=$'\t' read -r window_id pane_path; do
		[ -z "$window_id" ] && continue

		tagged_worktree="$(tmux show-options -w -t "$window_id" -v @secondary-worktree-path 2>/dev/null || true)"
		if [ "$tagged_worktree" = "$worktree" ]; then
			tmux display-message -p -t "$window_id" '#{window_index}'
			return 0
		fi

		pane_root="$(repo_root "$pane_path")"
		if [ "$pane_root" = "$worktree" ]; then
			tmux display-message -p -t "$window_id" '#{window_index}'
			return 0
		fi
	done < <(tmux list-windows -t "$session" -F '#{window_id}'$'\t''#{pane_current_path}')

	return 1
}

next_window_index() {
	local session="$1"
	local min_index="${2:-6}"
	local candidate

	candidate="$min_index"
	while tmux list-windows -t "$session" -F '#{window_index}' 2>/dev/null | grep -qx "$candidate"; do
		candidate=$((candidate + 1))
	done

	printf '%s\n' "$candidate"
}

sanitize_name() {
	printf '%s\n' "$1" | tr '/[:space:]' '--' | tr -cd 'A-Za-z0-9._-'
}

worktree_base_dir() {
	local root="$1"
	local common_dir main_checkout

	common_dir="$(git_common_dir "$root")" || fail "tmux-git: unable to resolve git common dir"
	main_checkout="$(dirname "$common_dir")"
	printf '%s-worktrees\n' "$main_checkout"
}

ensure_branch_worktree() {
	local root="$1"
	local branch="$2"
	local existing base_dir name target_path suffix remote_branch

	existing="$(worktree_path_for_branch "$root" "$branch" || true)"
	if [ -n "$existing" ] && [ -d "$existing" ]; then
		printf '%s\n' "$existing"
		return 0
	fi

	base_dir="$(worktree_base_dir "$root")"
	mkdir -p "$base_dir"

	name="$(sanitize_name "$branch")"
	[ -z "$name" ] && name="worktree"
	target_path="$base_dir/$name"
	suffix=2
	while [ -e "$target_path" ]; do
		target_path="$base_dir/$name-$suffix"
		suffix=$((suffix + 1))
	done

	git -C "$root" fetch origin "$branch" >/dev/null 2>&1 || true

	if ! git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
		remote_branch="origin/$branch"
		if ! git -C "$root" show-ref --verify --quiet "refs/remotes/$remote_branch"; then
			fail "tmux-git: missing base branch $branch"
		fi
		git -C "$root" branch --track "$branch" "$remote_branch" >/dev/null 2>&1 || fail "tmux-git: failed to track $remote_branch"
	fi

	git -C "$root" worktree add "$target_path" "$branch" >/dev/null 2>&1 || fail "tmux-git: failed to create worktree for $branch"

	printf '%s\n' "$target_path"
}

open_worktree_window() {
	local session="$1"
	local worktree="$2"
	"$HOME/.dotfiles/bin/tmux-worktree-layout.sh" open "$session" "$worktree" "$(basename "$worktree")"
}

pick_pr() {
	local session current_path root selected base_branch worktree

	session="$(tmux_session)"
	[ -z "$session" ] && fail "tmux-git: unable to resolve tmux session"

	current_path="$(tmux_path)"
	root="$(repo_root "$current_path")"
	[ -z "$root" ] && fail "tmux-git: not in a git repository"

	selected="$(
		GH_PAGER=cat gh pr list \
			--limit 200 \
			--state open \
			--json number,title,headRefName,isDraft,author,baseRefName \
			--template '{{range .}}{{printf "%v\t" .number}}{{if .isDraft}}D{{else}} {{end}}{{printf "\t%s\t%s\t%s\t%s\n" .headRefName .baseRefName .author.login .title}}{{end}}' | \
		fzf \
			--prompt="pull request > " \
			--delimiter=$'\t' \
			--with-nth=1,2,3,4,5 \
			--header=$'pr\tdraft\thead\tbase\tauthor\ttitle' \
			--layout=reverse \
			--border \
			--height=100% \
			|| true
	)"

	[ -z "$selected" ] && exit 0

	base_branch="$(printf '%s' "$selected" | cut -f4)"
	[ -z "$base_branch" ] && fail "tmux-git: invalid PR base branch"

	worktree="$(ensure_branch_worktree "$root" "$base_branch")"
	open_worktree_window "$session" "$worktree"
}

open_current_branch_pr() {
	local current_path root branch selected count pr_number match_flag match_label

	current_path="$(tmux_path)"
	root="$(repo_root "$current_path")"
	[ -z "$root" ] && fail "tmux-git: not in a git repository"

	branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
	[ -z "$branch" ] && fail "tmux-git: unable to resolve current branch"

	count="$(
		GH_PAGER=cat gh pr list \
			--limit 200 \
			--state open \
			--head "$branch" \
			--json number \
			--jq 'length'
	)"
	match_flag="--head"
	match_label="head"

	if [ "$count" -eq 0 ]; then
		count="$(
			GH_PAGER=cat gh pr list \
				--limit 200 \
				--state open \
				--base "$branch" \
				--json number \
				--jq 'length'
		)"
		match_flag="--base"
		match_label="base"
	fi

	if [ "$count" -eq 0 ]; then
		fail "tmux-git: no open PR found for branch $branch"
	fi

	if [ "$count" -eq 1 ]; then
		pr_number="$(
			GH_PAGER=cat gh pr list \
				--limit 200 \
				--state open \
				"$match_flag" "$branch" \
				--json number \
				--jq '.[0].number'
		)"
	else
		selected="$(
			GH_PAGER=cat gh pr list \
				--limit 200 \
				--state open \
				"$match_flag" "$branch" \
				--json number,title,isDraft,author,baseRefName,url \
				--template '{{range .}}{{printf "%v\t" .number}}{{if .isDraft}}D{{else}} {{end}}{{printf "\t%s\t%s\t%s\t%s\t%s\n" .headRefName .baseRefName .author.login .title .url}}{{end}}' | \
			fzf \
				--prompt="open pr ($match_label:$branch) > " \
				--delimiter=$'\t' \
				--with-nth=1,2,3,4,5,6 \
				--header=$'pr\tdraft\thead\tbase\tauthor\ttitle' \
				--layout=reverse \
				--border \
				--height=100% \
				|| true
		)"

		[ -z "$selected" ] && exit 0
		pr_number="$(printf '%s' "$selected" | cut -f1)"
	fi

	[ -z "$pr_number" ] && fail "tmux-git: invalid PR selection"
	gh pr view "$pr_number" --web
}

case "${1:-}" in
	pr)
		pick_pr
		;;
	current-pr)
		open_current_branch_pr
		;;
	*)
		echo "Usage: tmux-git.sh pr|current-pr" >&2
		exit 1
		;;
esac
