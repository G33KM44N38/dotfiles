#!/usr/bin/env bash

set -euo pipefail

path="${1:-}"
[ -z "$path" ] && path="$PWD"

command -v git >/dev/null 2>&1 || exit 0

run_gh() {
	command -v gh >/dev/null 2>&1 || return 127
	if command -v timeout >/dev/null 2>&1; then
		timeout 5 gh "$@"
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout 5 gh "$@"
	else
		gh "$@"
	fi
}

root="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && exit 0

branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
[ -z "$branch" ] && exit 0

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-pr-status"
mkdir -p "$cache_dir" 2>/dev/null || exit 0

if command -v shasum >/dev/null 2>&1; then
	key="$(printf '%s\t%s' "$root" "$branch" | shasum | awk '{print $1}')"
else
	key="$(printf '%s\t%s' "$root" "$branch" | cksum | awk '{print $1}')"
fi
cache_file="$cache_dir/$key"
ttl="${TMUX_PR_STATUS_TTL:-60}"
now="$(date +%s)"

local_value=""
dirty=0
if ! git -C "$root" diff --quiet --ignore-submodules -- 2>/dev/null ||
	! git -C "$root" diff --cached --quiet --ignore-submodules -- 2>/dev/null ||
	[ -n "$(git -C "$root" ls-files --others --exclude-standard 2>/dev/null)" ]; then
	dirty=1
	local_value="#[fg=colour214]*"
fi

upstream="$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
upstream_branch=""
ahead=0
behind=0
if [ -n "$upstream" ]; then
	upstream_branch="${upstream#*/}"
	ahead_behind="$(git -C "$root" rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || true)"
	if [ -n "$ahead_behind" ]; then
		read -r behind ahead <<< "$ahead_behind"
		if [ "${ahead:-0}" -gt 0 ]; then
			local_value="$local_value#[fg=colour82]+$ahead"
		fi
		if [ "${behind:-0}" -gt 0 ]; then
			local_value="$local_value#[fg=colour203]-$behind"
		fi
	fi
fi

query_pr() {
	local head="$1"

	[ -z "$head" ] && return 0
	cd "$root" && GH_PAGER=cat run_gh pr view "$head" \
		--json number,isDraft,state,mergeStateStatus,reviewDecision,statusCheckRollup \
		--jq '
			[
				.number,
				.isDraft,
				.state,
				(.mergeStateStatus // ""),
				(.reviewDecision // ""),
				([.statusCheckRollup[]? | (.conclusion // .status // "")] | join(","))
			] | @tsv
		' 2>/dev/null || true
}

cached_value=""
if [ -r "$cache_file" ]; then
	IFS=$'\t' read -r cached_at cached_value < "$cache_file" || true
	if [ -n "${cached_at:-}" ] && [ $((now - cached_at)) -lt "$ttl" ]; then
		pr_data="${cached_value:-}"
	else
		pr_data=""
	fi
else
	pr_data=""
fi

if [ -z "$pr_data" ]; then
	pr_data="$(query_pr "$branch")"
	if [ -z "$pr_data" ] && [ -n "$upstream_branch" ] && [ "$upstream_branch" != "$branch" ]; then
		pr_data="$(query_pr "$upstream_branch")"
	fi
	printf '%s\t%s\n' "$now" "$pr_data" > "$cache_file" 2>/dev/null || true
fi

pr_value=""
if [ -n "$pr_data" ]; then
	IFS=$'\t' read -r number is_draft state merge_state review_decision checks <<< "$pr_data"
	checks_upper="$(printf '%s' "$checks" | tr '[:lower:]' '[:upper:]')"

	if [ "$is_draft" = "true" ]; then
		label="draft"
		color="colour244"
	elif [ "$state" != "OPEN" ]; then
		label="$(printf '%s' "$state" | tr '[:upper:]' '[:lower:]')"
		color="colour244"
	elif [ "$merge_state" = "DIRTY" ]; then
		label="conflict"
		color="colour203"
	elif [[ "$checks_upper" =~ FAILURE|TIMED_OUT|ACTION_REQUIRED|CANCELLED ]]; then
		label="checks fail"
		color="colour203"
	elif [[ "$checks_upper" =~ PENDING|QUEUED|IN_PROGRESS|REQUESTED|WAITING ]]; then
		label="checks run"
		color="colour214"
	elif [ "$review_decision" = "CHANGES_REQUESTED" ]; then
		label="changes"
		color="colour203"
	elif [ "$review_decision" = "APPROVED" ]; then
		label="approved"
		color="colour82"
	else
		if [ "$dirty" -eq 1 ]; then
			label="commit"
			color="colour214"
		elif [ "${ahead:-0}" -gt 0 ]; then
			label="push"
			color="colour82"
		elif [ "${behind:-0}" -gt 0 ]; then
			label="pull"
			color="colour203"
		else
			label="view"
			color="colour39"
		fi
	fi

	pr_value="#[fg=$color]#$number:$label"
fi

if [ -n "${pr_value:-}${local_value:-}" ]; then
	printf ' %s%s' "${pr_value:-}" "${local_value:-}"
fi
