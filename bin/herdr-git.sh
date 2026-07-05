#!/usr/bin/env bash

set -euo pipefail

program="herdr-git"

usage() {
	cat <<'EOF'
Usage: herdr-git.sh <command>

Commands:
  current-pr   Open or focus the Herdr worktree workspace for the current PR
  pick-pr      Pick an open GitHub PR with fzf, then open or focus its worktree
  list-prs     List open GitHub PRs without selecting one
  menu         Show a small Git menu suitable for a Herdr keybinding
  help         Show this help
EOF
}

require_bin() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$program: missing binary: $1" >&2
		exit 1
	}
}

fail() {
	echo "$program: $1" >&2
	exit 1
}

current_path() {
	local path

	if git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
		pwd
		return 0
	fi

	path=""
	if command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
		path="$(herdr pane current 2>/dev/null | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty' 2>/dev/null || true)"
	fi

	if [ -n "$path" ] && [ -d "$path" ]; then
		printf '%s\n' "$path"
	else
		pwd
	fi
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

sanitize_name() {
	printf '%s\n' "$1" \
		| tr '/[:space:]' '--' \
		| tr . _ \
		| tr -cd 'A-Za-z0-9._-' \
		| sed 's/^-*//; s/-*$//'
}

worktree_base_dir() {
	local root="$1"
	local common_dir common_base

	common_dir="$(git_common_dir "$root")" || fail "unable to resolve git common dir"
	common_base="$(basename "$common_dir")"
	if [ "$common_base" != ".git" ] && [[ "$common_base" == *.git ]]; then
		printf '%s/worktrees/branches\n' "$common_dir"
	else
		printf '%s/worktrees/branches\n' "$(dirname "$common_dir")"
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

repo_default_remote() {
	local root="$1"
	local remote

	remote="$(git -C "$root" remote 2>/dev/null | grep -x origin || true)"
	if [ -z "$remote" ]; then
		remote="$(git -C "$root" remote 2>/dev/null | head -n1 || true)"
	fi
	printf '%s\n' "$remote"
}

ensure_local_pr_branch() {
	local root="$1"
	local pr_number="$2"
	local head_branch="$3"
	local remote local_branch

	if git -C "$root" show-ref --verify --quiet "refs/heads/$head_branch"; then
		printf '%s\n' "$head_branch"
		return 0
	fi

	remote="$(repo_default_remote "$root")"
	[ -n "$remote" ] || fail "no git remote found for PR #$pr_number"

	git -C "$root" fetch "$remote" "$head_branch" >/dev/null 2>&1 || true
	if git -C "$root" show-ref --verify --quiet "refs/remotes/$remote/$head_branch"; then
		git -C "$root" branch --track "$head_branch" "$remote/$head_branch" >/dev/null 2>&1 || true
		if git -C "$root" show-ref --verify --quiet "refs/heads/$head_branch"; then
			printf '%s\n' "$head_branch"
			return 0
		fi
	fi

	local_branch="pr/$pr_number-$(sanitize_name "$head_branch")"
	if git -C "$root" show-ref --verify --quiet "refs/heads/$local_branch"; then
		printf '%s\n' "$local_branch"
		return 0
	fi

	git -C "$root" fetch "$remote" "pull/$pr_number/head:$local_branch" >/dev/null 2>&1 ||
		fail "failed to fetch PR #$pr_number into $local_branch"
	printf '%s\n' "$local_branch"
}

ensure_branch_worktree() {
	local root="$1"
	local branch="$2"
	local existing base_dir name target_path suffix

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

	git -C "$root" worktree add "$target_path" "$branch" >/dev/null 2>&1 ||
		fail "failed to create worktree for $branch"

	printf '%s\n' "$target_path"
}

pr_label() {
	local pr_number="$1"
	local branch="$2"
	local name

	name="$(sanitize_name "$branch")"
	[ -n "$name" ] || name="pr"
	printf 'pr-%s-%s\n' "$pr_number" "$name"
}

herdr_open_worktree() {
	local root="$1"
	local pr_number="$2"
	local branch="$3"
	local label worktree

	require_bin herdr

	label="$(pr_label "$pr_number" "$branch")"
	if herdr worktree open --cwd "$root" --branch "$branch" --label "$label" --focus --json >/dev/null 2>&1; then
		printf '%s\n' "$label"
		return 0
	fi

	worktree="$(ensure_branch_worktree "$root" "$branch")"
	if herdr worktree open --cwd "$root" --path "$worktree" --label "$label" --focus --json >/dev/null 2>&1; then
		printf '%s\n' "$label"
		return 0
	fi

	herdr workspace create --cwd "$worktree" --label "$label" --focus >/dev/null 2>&1 ||
		fail "failed to create or focus Herdr workspace for $worktree"
	printf '%s\n' "$label"
}

pr_rows() {
	GH_PAGER=cat gh pr list \
		--limit 200 \
		--state open \
		--json number,title,headRefName,baseRefName,isDraft,author,url \
		--template '{{range .}}{{printf "%v\t" .number}}{{if .isDraft}}D{{else}} {{end}}{{printf "\t%s\t%s\t%s\t%s\t%s\n" .headRefName .baseRefName .author.login .title .url}}{{end}}'
}

list_prs() {
	require_bin git
	require_bin gh

	local root
	root="$(repo_root "$(current_path)")"
	[ -n "$root" ] || fail "not in a git repository"

	(cd "$root" && pr_rows)
}

open_pr_number() {
	local root="$1"
	local pr_number="$2"
	local data head_branch local_branch label

	data="$(
		cd "$root" && GH_PAGER=cat gh pr view "$pr_number" \
			--json number,headRefName \
			--jq '[.number, .headRefName] | @tsv'
	)"
	IFS=$'\t' read -r pr_number head_branch <<< "$data"
	[ -n "$pr_number" ] && [ -n "$head_branch" ] || fail "invalid PR metadata"

	local_branch="$(ensure_local_pr_branch "$root" "$pr_number" "$head_branch")"
	label="$(herdr_open_worktree "$root" "$pr_number" "$local_branch")"
	printf 'Opened %s for PR #%s (%s)\n' "$label" "$pr_number" "$local_branch"
}

choose_pr() {
	local prompt="$1"

	require_bin fzf
	pr_rows | fzf \
		--prompt="$prompt > " \
		--delimiter=$'\t' \
		--with-nth=1,2,3,4,5,6 \
		--header=$'pr\tdraft\thead\tbase\tauthor\ttitle' \
		--layout=reverse \
		--border \
		--height=100% \
		|| true
}

pick_pr() {
	require_bin git
	require_bin gh
	require_bin fzf

	local root selected pr_number
	root="$(repo_root "$(current_path)")"
	[ -n "$root" ] || fail "not in a git repository"

	selected="$(cd "$root" && choose_pr "pull request")"
	[ -z "$selected" ] && exit 0

	pr_number="$(printf '%s' "$selected" | cut -f1)"
	[ -n "$pr_number" ] || fail "invalid PR selection"
	open_pr_number "$root" "$pr_number"
}

current_branch_pr_number() {
	local root="$1"
	local branch upstream upstream_branch selected count pr_number candidate match_flag match_branch match_label ticket_key

	branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
	[ -n "$branch" ] || fail "unable to resolve current branch"

	upstream="$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
	upstream_branch="${upstream#*/}"
	[ "$upstream_branch" = "$upstream" ] && upstream_branch=""

	count=0
	match_flag="--head"
	match_branch="$branch"
	match_label="head"

	for candidate in "$branch" "$upstream_branch"; do
		[ -z "$candidate" ] && continue
		count="$(
			GH_PAGER=cat gh pr list \
				--limit 200 \
				--state open \
				--head "$candidate" \
				--json number \
				--jq 'length'
		)"
		if [ "$count" -gt 0 ]; then
			match_branch="$candidate"
			break
		fi
	done

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
		match_branch="$branch"
		match_label="base"
	fi

	if [ "$count" -eq 0 ]; then
		ticket_key="$(printf '%s\n' "$branch" | sed -nE 's/.*(([A-Z]+|[a-z]+)-[0-9]+).*/\1/p' | head -n1 | tr '[:lower:]' '[:upper:]')"
		if [ -n "$ticket_key" ]; then
			count="$(
				GH_PAGER=cat gh pr list \
					--limit 200 \
					--state open \
					--search "$ticket_key" \
					--json number \
					--jq 'length'
			)"
			match_flag="--search"
			match_branch="$ticket_key"
			match_label="search"
		fi
	fi

	if [ "$count" -eq 0 ]; then
		fail "no open PR found for branch $branch"
	fi

	if [ "$count" -eq 1 ]; then
		GH_PAGER=cat gh pr list \
			--limit 200 \
			--state open \
			"$match_flag" "$match_branch" \
			--json number \
			--jq '.[0].number'
		return 0
	fi

	require_bin fzf
	selected="$(
		GH_PAGER=cat gh pr list \
			--limit 200 \
			--state open \
			"$match_flag" "$match_branch" \
			--json number,title,isDraft,author,headRefName,baseRefName,url \
			--template '{{range .}}{{printf "%v\t" .number}}{{if .isDraft}}D{{else}} {{end}}{{printf "\t%s\t%s\t%s\t%s\t%s\n" .headRefName .baseRefName .author.login .title .url}}{{end}}' | \
		fzf \
			--prompt="pull request ($match_label:$match_branch) > " \
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
	[ -n "$pr_number" ] || fail "invalid PR selection"
	printf '%s\n' "$pr_number"
}

current_pr() {
	require_bin git
	require_bin gh

	local root pr_number
	root="$(repo_root "$(current_path)")"
	[ -n "$root" ] || fail "not in a git repository"

	pr_number="$(cd "$root" && current_branch_pr_number "$root")"
	open_pr_number "$root" "$pr_number"
}

menu() {
	require_bin fzf

	local selected action
	selected="$(
		printf '%s\n' \
			$'current-pr\tOpen/focus current PR worktree' \
			$'pick-pr\tPick GitHub PR worktree' \
			$'list-prs\tList open GitHub PRs' | \
		fzf \
			--prompt="git > " \
			--delimiter=$'\t' \
			--with-nth=1,2 \
			--layout=reverse \
			--border \
			--height=100% \
			|| true
	)"
	[ -z "$selected" ] && exit 0

	action="$(printf '%s' "$selected" | cut -f1)"
	case "$action" in
		current-pr) current_pr ;;
		pick-pr) pick_pr ;;
		list-prs) list_prs ;;
	esac
}

case "${1:-help}" in
	current-pr) current_pr ;;
	pick-pr | pr) pick_pr ;;
	list-prs | list) list_prs ;;
	menu) menu ;;
	help | --help | -h) usage ;;
	*)
		usage >&2
		exit 2
		;;
esac
