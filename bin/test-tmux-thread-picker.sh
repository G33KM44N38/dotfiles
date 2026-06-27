#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/tmux-thread-picker.sh"

pass_count=0
fail_count=0
tmp_root=""

cleanup() {
	[ -n "$tmp_root" ] && rm -rf "$tmp_root"
}
trap cleanup EXIT

fail() {
	printf 'not ok - %s\n' "$1" >&2
	fail_count=$((fail_count + 1))
}

pass() {
	printf 'ok - %s\n' "$1"
	pass_count=$((pass_count + 1))
}

assert_contains() {
	local haystack="$1"
	local needle="$2"
	local name="$3"

	if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
		pass "$name"
	else
		fail "$name"
		printf '  expected to contain: %s\n' "$needle" >&2
	fi
}

assert_not_contains() {
	local haystack="$1"
	local needle="$2"
	local name="$3"

	if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
		fail "$name"
		printf '  expected not to contain: %s\n' "$needle" >&2
	else
		pass "$name"
	fi
}

assert_file_contains_line() {
	local file="$1"
	local line="$2"
	local name="$3"

	if [ -s "$file" ] && grep -Fxq "$line" "$file"; then
		pass "$name"
	else
		fail "$name"
		printf '  expected %s to contain line: %s\n' "$file" "$line" >&2
	fi
}

assert_file_missing_line() {
	local file="$1"
	local line="$2"
	local name="$3"

	if [ ! -e "$file" ] || ! grep -Fxq "$line" "$file"; then
		pass "$name"
	else
		fail "$name"
		printf '  expected %s not to contain line: %s\n' "$file" "$line" >&2
	fi
}

write_mock_tmux() {
	cat >"$mock_bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
shift || true
worktree_path="${TMUX_MOCK_WORKTREE_PATH:-$TEST_WORKTREE}"
secondary_worktree_path="${TMUX_MOCK_SECONDARY_WORKTREE_PATH:-}"

case "$cmd" in
	list-sessions)
		printf 'test\n'
		;;
	display-message)
		print_mode=0
		target=""
		format=""
		while [ "$#" -gt 0 ]; do
			case "$1" in
				-p) print_mode=1; shift ;;
				-t) target="${2:-}"; shift 2 ;;
				*) format="$1"; shift ;;
			esac
		done
		if [ "$print_mode" -eq 0 ]; then
			exit 0
		fi
		case "$format" in
			'#S') printf 'test\n' ;;
			'#{pane_current_path}') printf '%s\n' "$TEST_REPO" ;;
			'#{window_index}')
				case "$target" in
					@2|test:2) printf '2\n' ;;
					*) printf '1\n' ;;
				esac
				;;
			'#{session_name}:#{window_index}')
				case "$target" in
					@2) printf 'test:2\n' ;;
					*) printf 'test:1\n' ;;
				esac
				;;
			*) printf '\n' ;;
		esac
		;;
	list-panes)
		printf '@1\t%%1\tzsh\t%s\t1001\n' "$TEST_REPO"
		if [ "${TMUX_MOCK_TWO_CODEX_PANES:-0}" = "1" ]; then
			printf '@2\t%%2\tcodex\t%s\t1002\n' "$worktree_path"
			if [ "${TMUX_MOCK_TWO_CODEX_SAME_PATH:-0}" = "1" ]; then
				printf '@2\t%%3\tcodex\t%s\t1003\n' "$worktree_path"
			else
				printf '@2\t%%3\tcodex\t%s\t1003\n' "$TEST_REPO"
			fi
		else
			printf '@2\t%%2\t%s\t%s\t1002\n' "${TMUX_MOCK_WORKTREE_COMMAND:-codex}" "$worktree_path"
		fi
		;;
	list-windows)
		format=""
		target=""
		while [ "$#" -gt 0 ]; do
			case "$1" in
				-t) target="${2:-}"; shift 2 ;;
				-F) format="${2:-}"; shift 2 ;;
				-a) shift ;;
				*) shift ;;
			esac
		done
		case "$format" in
			'#{window_index}')
				printf '1\n2\n'
				;;
			'#{window_id}'$'\t''#{pane_current_path}')
				printf '@1\t%s\n' "$TEST_REPO"
				printf '@2\t%s\n' "$worktree_path"
				;;
			'#{window_id}'$'\t''#{pane_id}'$'\t''#{pane_current_command}'$'\t''#{pane_current_path}'$'\t''#{pane_pid}')
				printf '@1\t%%1\tzsh\t%s\t1001\n' "$TEST_REPO"
				if [ "${TMUX_MOCK_TWO_CODEX_PANES:-0}" = "1" ]; then
					printf '@2\t%%2\tcodex\t%s\t1002\n' "$worktree_path"
					if [ "${TMUX_MOCK_TWO_CODEX_SAME_PATH:-0}" = "1" ]; then
						printf '@2\t%%3\tcodex\t%s\t1003\n' "$worktree_path"
					else
						printf '@2\t%%3\tcodex\t%s\t1003\n' "$TEST_REPO"
					fi
				else
					printf '@2\t%%2\t%s\t%s\t1002\n' "${TMUX_MOCK_WORKTREE_COMMAND:-codex}" "$worktree_path"
				fi
				;;
			'#{session_name}:#{window_index}'$'\t''#{window_id}'$'\t''#{window_name}'$'\t''#{window_activity_flag}'$'\t''#{window_bell_flag}')
				printf 'test:1\t@1\tmain\t0\t0\n'
				printf 'test:2\t@2\tfeature\t%s\t0\n' "${TMUX_MOCK_WORKTREE_ACTIVITY:-1}"
				;;
			'#{session_name}'$'\t''#{window_index}'$'\t''#{window_id}'$'\t''#{window_name}'$'\t''#{window_activity_flag}'$'\t''#{window_bell_flag}'$'\t''#{pane_current_path}'$'\t''#{@secondary-worktree-path}')
				printf 'test\t1\t@1\tmain\t0\t0\t%s\t\n' "$TEST_REPO"
				printf 'test\t2\t@2\tfeature\t%s\t0\t%s\t%s\n' "${TMUX_MOCK_WORKTREE_ACTIVITY:-1}" "$worktree_path" "$secondary_worktree_path"
				;;
			*)
				printf '1\n2\n'
				;;
		esac
		;;
	show-options)
		exit 0
		;;
	set-option)
		printf 'set-option %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	switch-client)
		printf 'switch-client %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	select-window)
		printf 'select-window %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	select-pane)
		printf 'select-pane %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	kill-window)
		printf 'kill-window %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	command-prompt)
		printf 'command-prompt %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	new-window)
		printf 'new-window %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	capture-pane)
		target=""
		while [ "$#" -gt 0 ]; do
			case "$1" in
				-t) target="${2:-}"; shift 2 ;;
				*) shift ;;
			esac
		done
		case "$target" in
			%2)
				if [ "${TMUX_MOCK_TWO_CODEX_PANES:-0}" = "1" ] || [ "${TMUX_MOCK_CAPTURE_PANE2:-0}" = "1" ]; then
					printf 'User asks for LIN-42: Add refund flow\n'
				fi
				;;
			%3) printf 'Investigate session picker naming\n' ;;
			*) printf '\n' ;;
		esac
		;;
	*)
		printf 'tmux mock: unhandled %s %s\n' "$cmd" "$*" >>"$TMUX_MOCK_LOG"
		;;
esac
EOF
	chmod +x "$mock_bin/tmux"
}

write_mock_fzf() {
	cat >"$mock_bin/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$FZF_MOCK_ARGS"
input="$(cat)"
printf '%s\n' "$input" >>"$FZF_MOCK_INPUT"

case "${FZF_MOCK_MODE:-first-data}" in
	none)
		exit 1
		;;
	query)
		printf '%s\n' "${FZF_MOCK_QUERY:-new thread}"
		;;
	kind)
		printf '%s\n' "$input" | awk -F '\t' -v kind="${FZF_MOCK_KIND:-OPEN}" '$1 == kind { print; exit }'
		;;
	target)
		printf '%s\n' "$input" | awk -F '\t' -v target="${FZF_MOCK_TARGET:-}" '$3 ~ target { print; exit }'
		;;
	first-data|*)
		printf '%s\n' "$input" | awk -F '\t' '$1 != "GROUP" && NF { print; exit }'
		;;
esac
EOF
	chmod +x "$mock_bin/fzf"
}

write_mock_codex() {
	cat >"$mock_bin/codex" <<'EOF'
#!/usr/bin/env bash
printf 'codex %s\n' "$*" >>"${CODEX_MOCK_LOG:-/dev/null}"
EOF
	chmod +x "$mock_bin/codex"
}

write_mock_curl() {
	cat >"$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "$mock_bin/curl"
}

write_mock_ps() {
	cat >"$mock_bin/ps" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${TMUX_MOCK_BUSY_PROCESS:-0}" = "1" ]; then
	printf '2000 1002 node node server.js\n'
fi
EOF
	chmod +x "$mock_bin/ps"
}

setup_fixture() {
	tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-thread-picker-test.XXXXXX")"
	tmp_root="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$tmp_root")"
	mock_bin="$tmp_root/bin"
	test_home="$tmp_root/home"
	state_home="$tmp_root/state"
	repo="$test_home/coding/demo"
	worktree="$test_home/coding/demo-feature"
	mkdir -p "$mock_bin" "$test_home/coding" "$state_home"

	git init -b main "$repo" >/dev/null
	git -C "$repo" config user.email test@example.com
	git -C "$repo" config user.name "Test User"
	printf 'hello\n' >"$repo/README.md"
	git -C "$repo" add README.md
	git -C "$repo" commit -m initial >/dev/null
	git -C "$repo" worktree add -b feature "$worktree" >/dev/null 2>&1
	repo="$(cd "$repo" && pwd)"
	worktree="$(cd "$worktree" && pwd)"

	export TEST_REPO="$repo"
	export TEST_WORKTREE="$worktree"
	export HOME="$test_home"
	export XDG_STATE_HOME="$state_home"
	export TMUX_THREAD_SOURCE_SESSION="test"
	export TMUX_THREAD_SOURCE_PANE="%1"
	export TMUX_THREAD_SOURCE_PATH="$repo"
	export TMUX_THREAD_ROOTS="$test_home/coding"
	export TMUX_THREAD_CACHE_TTL="999999"
	export TMUX_THREAD_USE_DISPLAY_CACHE="0"
	export TMUX_THREAD_COLOR="0"
	export TMUX_THREAD_AI_TITLE="0"
	export NO_COLOR="1"
	export TMUX_MOCK_LOG="$tmp_root/tmux.log"
	export CODEX_MOCK_LOG="$tmp_root/codex.log"
	export FZF_MOCK_ARGS="$tmp_root/fzf-args.log"
	export FZF_MOCK_INPUT="$tmp_root/fzf-input.tsv"
	: >"$TMUX_MOCK_LOG"
	: >"$CODEX_MOCK_LOG"
	: >"$FZF_MOCK_ARGS"
	: >"$FZF_MOCK_INPUT"

	write_mock_tmux
	write_mock_fzf
	write_mock_codex
	write_mock_curl
	write_mock_ps
	export PATH="$mock_bin:$PATH"
}

run_script() {
	"$SCRIPT" "$@"
}

setup_fixture

bash -n "$SCRIPT" && pass "script has valid bash syntax" || fail "script has valid bash syntax"

run_script --toggle-pin "$TEST_REPO"
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/pins" "$TEST_REPO" "toggle-pin adds pin"
run_script --toggle-pin "$TEST_REPO"
assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/pins" "$TEST_REPO" "toggle-pin removes existing pin"

run_script --toggle-archive "$TEST_WORKTREE"
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/archives" "$TEST_WORKTREE" "toggle-archive adds archive"
run_script --toggle-archive "$TEST_WORKTREE"
assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/archives" "$TEST_WORKTREE" "toggle-archive removes existing archive"

run_script --set-title "$TEST_REPO" "Main Thread"
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/titles" "$TEST_REPO"$'\t'"Main Thread" "set-title stores title"
run_script --set-title "$TEST_REPO" ""
if [ ! -s "$XDG_STATE_HOME/tmux-thread-picker/titles" ]; then
	pass "set-title clears title on empty value"
else
	fail "set-title clears title on empty value"
fi
if command -v sqlite3 >/dev/null 2>&1; then
	mkdir -p "$HOME/.codex"
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text primary key, title text not null, first_user_message text not null default '');
insert into threads(id, title, first_user_message) values ('rename-session', 'Old Codex Title', 'first prompt');
insert into threads(id, title, first_user_message) values ('auto-session', '', '');
EOF
	printf 'codex:rename-session\tStale Local Title\n' >"$XDG_STATE_HOME/tmux-thread-picker/titles"
	run_script --set-title "codex:rename-session" "Renamed Codex's Chat"
	assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/titles" "codex:rename-session"$'\t'"Stale Local Title" "set-title removes stale local codex title"
	assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/titles" "codex:rename-session"$'\t'"Renamed Codex's Chat" "set-title avoids duplicate local codex title"
	codex_db_title="$(sqlite3 "$HOME/.codex/state_5.sqlite" "select title from threads where id = 'rename-session';")"
	assert_contains "$codex_db_title" "Renamed Codex's Chat" "set-title syncs codex internal title"
	run_script --set-title "codex:rename-session" ""
	codex_db_title_after_clear="$(sqlite3 "$HOME/.codex/state_5.sqlite" "select title from threads where id = 'rename-session';")"
	assert_contains "$codex_db_title_after_clear" "Renamed Codex's Chat" "clearing picker title leaves codex internal title intact"
	TMUX_MOCK_CAPTURE_PANE2=1 run_script --regen-title "codex:auto-session" "test:2"
	auto_codex_db_title="$(sqlite3 "$HOME/.codex/state_5.sqlite" "select title from threads where id = 'auto-session';")"
	assert_contains "$auto_codex_db_title" "LIN-42: Add refund flow" "regen-title syncs codex internal title"
	assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/auto-titles" "codex:auto-session"$'\t'"LIN-42: Add refund flow" "regen-title avoids duplicate local codex auto-title"
	rm -f "$HOME/.codex/state_5.sqlite"
else
	pass "set-title syncs codex internal title (sqlite3 unavailable)"
	pass "regen-title syncs codex internal title (sqlite3 unavailable)"
fi

rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
TMUX_MOCK_CAPTURE_PANE2=1 run_script --regen-title "$TEST_WORKTREE" "test:2"
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/auto-titles" "$TEST_WORKTREE"$'\t'"LIN-42: Add refund flow" "regen-title resolves codex pane from window target"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"

: >"$TMUX_MOCK_LOG"
run_script --prompt-title "$TEST_REPO"
prompt_log="$(cat "$TMUX_MOCK_LOG")"
assert_contains "$prompt_log" "command-prompt -p thread title run-shell" "prompt-title opens tmux command prompt"
assert_contains "$prompt_log" "run-shell -b" "prompt-title wraps set-title command for tmux run-shell"
assert_not_contains "$prompt_log" "run-shell '$SCRIPT' --set-title" "prompt-title does not pass extra run-shell arguments"
assert_contains "$prompt_log" "--set-title" "prompt-title command sets title"
assert_contains "$prompt_log" "$TEST_REPO" "prompt-title passes selected key"
: >"$TMUX_MOCK_LOG"
run_script --prompt-title "codex:thread with spaces"
space_prompt_log="$(cat "$TMUX_MOCK_LOG")"
assert_contains "$space_prompt_log" "codex:thread with spaces" "prompt-title preserves keys with spaces"
assert_contains "$space_prompt_log" "run-shell -b" "prompt-title with spaced key wraps run-shell command"

rm -f "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
run_script --refresh-repo-cache
repo_cache_content="$(cat "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv")"
assert_contains "$repo_cache_content" "$TEST_REPO" "refresh-repo-cache populates repo cache"
if [ ! -e "$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" ] &&
	[ ! -e "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv" ]; then
	pass "refresh-repo-cache skips worktree and display caches"
else
	fail "refresh-repo-cache skips worktree and display caches"
fi

repo_snapshot="$tmp_root/repo-candidates-snapshot.tsv"
cp "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" "$repo_snapshot"
run_script --refresh-worktree-cache "$repo_snapshot"
worktree_cache_content="$(cat "$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv")"
assert_contains "$worktree_cache_content" "$TEST_WORKTREE"$'\t'"feature" "refresh-worktree-cache populates worktree cache"
if [ ! -e "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv" ]; then
	pass "refresh-worktree-cache skips display cache"
else
	fail "refresh-worktree-cache skips display cache"
fi

rm -f "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
run_script --refresh-cache
if [ -s "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv" ]; then
	pass "refresh-cache writes display cache in full mode"
else
	fail "refresh-cache writes display cache in full mode"
fi
rm -f "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
TMUX_THREAD_ATTENTION_ONLY=1 run_script --refresh-cache
if [ ! -e "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" ] &&
	[ ! -e "$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" ] &&
	[ ! -e "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv" ]; then
	pass "attention refresh-cache skips inventory caches"
else
	fail "attention refresh-cache skips inventory caches"
fi

run_script --toggle-pin "$TEST_REPO"
run_script --set-title "$TEST_REPO" "Main Thread"
rows="$(run_script --rows)"
plain_rows="$(printf '%s' "$rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_rows" $'GROUP\t:: Pinned' "rows include Pinned group"
assert_contains "$plain_rows" $'GROUP\t:: demo' "rows include project group"
assert_contains "$plain_rows" "GROUP"$'\t'":: demo"$'\t\t\t\t'"demo"$'\t'" :: demo" "project group carries hidden search text"
assert_contains "$plain_rows" "demo-feature" "project group search text includes matching child path token"
assert_contains "$plain_rows" $'\ttest:2\tfeature\t' "data row search text keeps target and branch searchable"
assert_contains "$plain_rows" "codex   demo-feature" "open codex cli is shown"
assert_not_contains "$plain_rows" "run     demo-feature" "open codex cli is not shown as running"
assert_not_contains "$plain_rows" "▶     codex   demo-feature" "open codex cli does not show active arrow"
: >"$TMUX_MOCK_LOG"
wrong_secondary_rows="$(TMUX_MOCK_SECONDARY_WORKTREE_PATH="$TEST_REPO" run_script --rows)"
plain_wrong_secondary_rows="$(printf '%s' "$wrong_secondary_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_wrong_secondary_rows" | awk -F '\t' -v worktree="$TEST_WORKTREE" '$1 == "OPEN" && $3 == "test:2" && $4 == "feature" && $5 == worktree { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "stale secondary path cannot override live pane cwd"
else
	fail "stale secondary path cannot override live pane cwd"
fi
assert_contains "$(cat "$TMUX_MOCK_LOG")" "set-option -wuq -t @2 @secondary-worktree-path" "stale secondary path is cleared"
: >"$TMUX_MOCK_LOG"
missing_secondary="$tmp_root/missing-secondary-worktree"
missing_secondary_rows="$(TMUX_MOCK_SECONDARY_WORKTREE_PATH="$missing_secondary" run_script --rows)"
plain_missing_secondary_rows="$(printf '%s' "$missing_secondary_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_missing_secondary_rows" | awk -F '\t' -v worktree="$TEST_WORKTREE" '$1 == "OPEN" && $3 == "test:2" && $5 == worktree { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "missing secondary path falls back to live pane cwd"
else
	fail "missing secondary path falls back to live pane cwd"
fi
assert_contains "$(cat "$TMUX_MOCK_LOG")" "set-option -wuq -t @2 @secondary-worktree-path" "missing secondary path is cleared"
: >"$TMUX_MOCK_LOG"
missing_pane_cwd="$tmp_root/missing-pane-cwd"
tagged_secondary_rows="$(TMUX_MOCK_WORKTREE_PATH="$missing_pane_cwd" TMUX_MOCK_SECONDARY_WORKTREE_PATH="$TEST_WORKTREE" run_script --rows)"
plain_tagged_secondary_rows="$(printf '%s' "$tagged_secondary_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_tagged_secondary_rows" | awk -F '\t' -v worktree="$TEST_WORKTREE" '$1 == "OPEN" && $3 == "test:2" && $4 == "feature" && $5 == worktree { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "secondary path remains authoritative when pane cwd is unavailable"
else
	fail "secondary path remains authoritative when pane cwd is unavailable"
fi
assert_not_contains "$(cat "$TMUX_MOCK_LOG")" "set-option -wuq -t @2 @secondary-worktree-path" "valid secondary path with unavailable pane cwd is kept"
run_script --set-title "test:2" "Legacy Target Title"
legacy_target_rows="$(run_script --rows)"
plain_legacy_target_rows="$(printf '%s' "$legacy_target_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_legacy_target_rows" "Legacy Target Title" "legacy tmux target title remains a display alias"
if printf '%s\n' "$plain_legacy_target_rows" | awk -F '\t' -v path="$TEST_WORKTREE" '$1 == "OPEN" && $3 == "test:2" && $5 == path { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "legacy tmux target title does not replace stable row key"
else
	fail "legacy tmux target title does not replace stable row key"
fi
run_script --set-title "test:2" ""
two_pane_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
plain_two_pane_rows="$(printf '%s' "$two_pane_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_two_pane_rows" "LIN-42: Add refund flow" "two codex panes use captured Linear ticket title"
assert_contains "$plain_two_pane_rows" "Main Thread" "two codex panes preserve manual title priority"
if [ "$(printf '%s\n' "$plain_two_pane_rows" | awk -F '\t' '$1 == "OPEN" && $3 ~ /^test:2,%[0-9]+$/ { count++ } END { print count + 0 }')" = "2" ]; then
	pass "two codex panes in one window produce separate rows"
else
	fail "two codex panes in one window produce separate rows"
fi
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
now="$(date +%s)"
started=$((now - 30))
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\tsingle-pane-session\t%%2\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf 'codex:single-pane-session\tSingle Pane Session\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
single_pane_session_rows="$(run_script --rows)"
plain_single_pane_session_rows="$(printf '%s' "$single_pane_session_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_single_pane_session_rows" "Single Pane Session" "single codex pane uses session-specific title"
assert_contains "$plain_single_pane_session_rows" $'test:2\tfeature\tcodex:single-pane-session' "single codex pane row uses codex session key"
printf '%s\n' "$single_pane_session_rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\treplaced-pane-session\t%%2\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf 'codex:replaced-pane-session\tReplaced Pane Session\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
rekeyed_cache_input="$(cat "$FZF_MOCK_INPUT")"
plain_rekeyed_cache_input="$(printf '%s' "$rekeyed_cache_input" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_rekeyed_cache_input" "Replaced Pane Session" "stale display cache rebuilds after codex identity title changes"
assert_contains "$plain_rekeyed_cache_input" $'test:2\tfeature\tcodex:replaced-pane-session' "stale display cache rebuilds after codex identity key changes"
assert_not_contains "$plain_rekeyed_cache_input" "Single Pane Session" "stale display cache does not preserve old codex title"
assert_not_contains "$plain_rekeyed_cache_input" "codex:single-pane-session" "stale display cache does not preserve old codex identity key"
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\tsingle-pane-session\t%%2\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf 'codex:single-pane-session\tSingle Pane Session\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
printf '%s\n' "$TEST_WORKTREE" >"$XDG_STATE_HOME/tmux-thread-picker/pins"
legacy_path_pin_rows="$(run_script --rows)"
plain_legacy_path_pin_rows="$(printf '%s' "$legacy_path_pin_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_legacy_path_pin_rows" | awk -F '\t' '$1 == "OPEN" && $5 == "codex:single-pane-session" && $2 ~ / P / { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "codex row recognizes legacy path pin"
else
	fail "codex row recognizes legacy path pin"
fi
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/pins" "codex:single-pane-session" "legacy path pin migrates to codex key"
assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/pins" "$TEST_WORKTREE" "legacy path pin alias is removed after migration"
printf '%s\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/pins"
printf '%s\n' "$TEST_WORKTREE" >"$XDG_STATE_HOME/tmux-thread-picker/archives"
legacy_path_archive_rows="$(run_script --rows)"
plain_legacy_path_archive_rows="$(printf '%s' "$legacy_path_archive_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_legacy_path_archive_rows" | awk -F '\t' '$1 == "OPEN" && $5 == "codex:single-pane-session" && $2 ~ / A / { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "codex row recognizes legacy path archive"
else
	fail "codex row recognizes legacy path archive"
fi
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/archives" "codex:single-pane-session" "legacy path archive migrates to codex key"
assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/archives" "$TEST_WORKTREE" "legacy path archive alias is removed after migration"
printf '%s\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/pins"
: >"$XDG_STATE_HOME/tmux-thread-picker/archives"
: >"$XDG_STATE_HOME/tmux-thread-picker/pins"
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\twrite-canonical-session\t%%2\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
run_script --toggle-pin "$TEST_WORKTREE"
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/pins" "codex:write-canonical-session" "toggle-pin writes canonical codex key"
assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/pins" "$TEST_WORKTREE" "toggle-pin avoids legacy path key for codex row"
: >"$XDG_STATE_HOME/tmux-thread-picker/archives"
run_script --toggle-archive "$TEST_WORKTREE"
assert_file_contains_line "$XDG_STATE_HOME/tmux-thread-picker/archives" "codex:write-canonical-session" "toggle-archive writes canonical codex key"
assert_file_missing_line "$XDG_STATE_HOME/tmux-thread-picker/archives" "$TEST_WORKTREE" "toggle-archive avoids legacy path key for codex row"
printf '%s\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/pins"
: >"$XDG_STATE_HOME/tmux-thread-picker/archives"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
now="$(date +%s)"
started=$((now - 65))
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\tsession-pane-2\t%%2\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
mixed_pane_status_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
plain_mixed_pane_status_rows="$(printf '%s' "$mixed_pane_status_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_mixed_pane_status_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%2" && $2 ~ /run/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "pane-specific hook marks matching pane as running"
else
	fail "pane-specific hook marks matching pane as running"
fi
if printf '%s\n' "$plain_mixed_pane_status_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $2 ~ /codex/ && $2 !~ /run/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "pane-specific hook does not mark sibling pane as running"
else
	fail "pane-specific hook does not mark sibling pane as running"
fi
same_path_mixed_pane_status_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 TMUX_MOCK_TWO_CODEX_SAME_PATH=1 run_script --rows)"
plain_same_path_mixed_pane_status_rows="$(printf '%s' "$same_path_mixed_pane_status_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_same_path_mixed_pane_status_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%2" && $2 ~ /run/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "same-path pane hook marks matching pane as running"
else
	fail "same-path pane hook marks matching pane as running"
fi
if printf '%s\n' "$plain_same_path_mixed_pane_status_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $2 ~ /codex/ && $2 !~ /run/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "same-path pane hook does not mark sibling pane as running"
else
	fail "same-path pane hook does not mark sibling pane as running"
fi
if awk -F '\t' '$1 == "@2" && $2 == "running" && $5 == "%2" { running = 1 } $1 == "@2" && $2 == "unknown" && $5 == "%3" { sibling = 1 } END { exit(running && sibling ? 0 : 1) }' "$XDG_STATE_HOME/tmux-thread-picker/codex-states.tsv"; then
	pass "codex state cache keeps same-path pane statuses separate"
else
	fail "codex state cache keeps same-path pane statuses separate"
fi
printf '%s\n' "$rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
same_path_window_overlay_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 TMUX_MOCK_TWO_CODEX_SAME_PATH=1 run_script --live-rows "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv")"
plain_same_path_window_overlay_rows="$(printf '%s' "$same_path_window_overlay_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_same_path_window_overlay_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2" && $2 !~ /run/ && $2 !~ /wait/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "same-path pane hook does not collapse onto cached window row"
else
	fail "same-path pane hook does not collapse onto cached window row"
fi
printf '%s\n' "$two_pane_rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 TMUX_MOCK_TWO_CODEX_PANES=1 FZF_MOCK_MODE=none run_script >/dev/null
cached_mixed_pane_status_rows="$(cat "$FZF_MOCK_INPUT")"
plain_cached_mixed_pane_status_rows="$(printf '%s' "$cached_mixed_pane_status_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_cached_mixed_pane_status_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%2" && $2 ~ /run/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "cached overlay marks matching pane as running"
else
	fail "cached overlay marks matching pane as running"
fi
if printf '%s\n' "$plain_cached_mixed_pane_status_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $2 ~ /codex/ && $2 !~ /run/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "cached overlay does not mark sibling pane as running"
else
	fail "cached overlay does not mark sibling pane as running"
fi
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
old=$((now - 90000))
printf '%s\tdone\tStop\t%s\t%s\tstale-pane-session\t%%3\n' "$TEST_REPO" "$old" "$old" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf 'codex:stale-pane-session\tStale Pane Title\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
stale_pane_title_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
plain_stale_pane_title_rows="$(printf '%s' "$stale_pane_title_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_stale_pane_title_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $5 == "codex:stale-pane-session" && $2 ~ /Stale Pane Title/ && $2 ~ /codex/ && $2 !~ /wait/ { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "stale pane hook keeps title identity without stale status"
else
	fail "stale pane hook keeps title identity without stale status"
fi
if command -v sqlite3 >/dev/null 2>&1; then
	mkdir -p "$HOME/.codex"
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text, cwd text, updated_at_ms integer, title text, first_user_message text);
insert into threads values ('explicit-pane-session', '$TEST_WORKTREE', 200, '', '');
insert into threads values ('fallback-pane-session', '$TEST_WORKTREE', 100, '', '');
insert into threads values ('target-alias-session', '$TEST_WORKTREE', 300, 'Fresh Codex SQLite Title', '');
EOF
	: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	printf '%s\tdone\tStop\t%s\t%s\texplicit-pane-session\t%%2\n' "$TEST_WORKTREE" "$old" "$old" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	printf 'codex:explicit-pane-session\tExplicit Pane Title\ncodex:fallback-pane-session\tFallback Pane Title\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
	fallback_title_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_fallback_title_rows="$(printf '%s' "$fallback_title_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_fallback_title_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%2" && $5 == "codex:explicit-pane-session" && $2 ~ /Explicit Pane Title/ { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "pane explicit title key remains on matching pane"
	else
		fail "pane explicit title key remains on matching pane"
	fi
	if printf '%s\n' "$plain_fallback_title_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $5 != "codex:fallback-pane-session" && $2 !~ /Fallback Pane Title/ { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "ambiguous sibling pane does not claim fallback title key"
	else
		fail "ambiguous sibling pane does not claim fallback title key"
	fi
	run_script --set-title "test:2" "Stale Target Alias"
	printf '%s\trunning\tUserPromptSubmit\t%s\t%s\ttarget-alias-session\t%%2\n' "$TEST_WORKTREE" "$(date +%s)" "$(date +%s)" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	target_alias_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_target_alias_rows="$(printf '%s' "$target_alias_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_target_alias_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%2" && $5 == "codex:target-alias-session" && $2 ~ /Fresh Codex SQLite Title/ && $2 !~ /Stale Target Alias/ { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "codex sqlite title beats stale tmux target alias"
	else
		fail "codex sqlite title beats stale tmux target alias"
	fi
	run_script --set-title "test:2" ""
	rm -f "$HOME/.codex/state_5.sqlite"
else
	pass "ambiguous sibling pane does not claim fallback title key (sqlite3 unavailable)"
fi
if command -v sqlite3 >/dev/null 2>&1; then
	mkdir -p "$HOME/.codex"
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text, cwd text, updated_at_ms integer, title text, first_user_message text);
insert into threads values ('history-pane-three', '$TEST_REPO', 300, 'Investigate session picker naming', '');
EOF
	: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
	history_matched_pane_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_history_matched_pane_rows="$(printf '%s' "$history_matched_pane_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_history_matched_pane_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $5 == "codex:history-pane-three" { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "idle codex pane recovers session key from matching history"
	else
		fail "idle codex pane recovers session key from matching history"
	fi
	printf '%s\trunning\tUserPromptSubmit\t%s\t%s\thook-pane-three\t%%3\n' "$TEST_REPO" "$(date +%s)" "$(date +%s)" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	hook_precedence_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_hook_precedence_rows="$(printf '%s' "$hook_precedence_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_hook_precedence_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $5 == "codex:hook-pane-three" { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "hook pane session key wins over matching history"
	else
		fail "hook pane session key wins over matching history"
	fi
	printf '%s\trunning\tUserPromptSubmit\t%s\t%s\thook-path-three\n' "$TEST_REPO" "$(date +%s)" "$(date +%s)" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	hook_path_precedence_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_hook_path_precedence_rows="$(printf '%s' "$hook_path_precedence_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_hook_path_precedence_rows" | awk -F '\t' '$1 == "OPEN" && $3 == "test:2,%3" && $5 == "codex:hook-path-three" { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "hook path session key wins over matching history"
	else
		fail "hook path session key wins over matching history"
	fi
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text, cwd text, updated_at_ms integer, title text, first_user_message text);
insert into threads values ('low-confidence-history', '$TEST_REPO', 300, 'Investigate picker naming session', '');
EOF
	: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	low_confidence_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_low_confidence_rows="$(printf '%s' "$low_confidence_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_low_confidence_rows" | awk -F '\t' -v repo="$TEST_REPO" '$1 == "OPEN" && $3 == "test:2,%3" && $5 == repo { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "low-confidence history match does not claim live row identity"
	else
		fail "low-confidence history match does not claim live row identity"
	fi
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text, cwd text, updated_at_ms integer, title text, first_user_message text);
insert into threads values ('ambiguous-history-one', '$TEST_REPO', 300, 'Investigate session picker naming', '');
insert into threads values ('ambiguous-history-two', '$TEST_REPO', 200, 'Investigate session picker naming', '');
EOF
	ambiguous_history_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
	plain_ambiguous_history_rows="$(printf '%s' "$ambiguous_history_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_ambiguous_history_rows" | awk -F '\t' -v repo="$TEST_REPO" '$1 == "OPEN" && $3 == "test:2,%3" && $5 == repo { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "ambiguous history match does not claim live row identity"
	else
		fail "ambiguous history match does not claim live row identity"
	fi
	rm -f "$HOME/.codex/state_5.sqlite"
else
	pass "idle codex pane recovers session key from matching history (sqlite3 unavailable)"
	pass "hook pane session key wins over matching history (sqlite3 unavailable)"
	pass "hook path session key wins over matching history (sqlite3 unavailable)"
	pass "low-confidence history match does not claim live row identity (sqlite3 unavailable)"
	pass "ambiguous history match does not claim live row identity (sqlite3 unavailable)"
fi
if command -v sqlite3 >/dev/null 2>&1; then
	mkdir -p "$HOME/.codex"
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text, cwd text, updated_at_ms integer, title text, first_user_message text);
insert into threads values ('history-one', '$TEST_WORKTREE', 300, 'History One', 'first one');
insert into threads values ('history-two', '$TEST_WORKTREE', 200, 'History Two', 'first two');
insert into threads values ('history-whatsapp', '$TEST_REPO', 100, 'Could you look at my conversation with beautyhairmaiidi on Whatsapp and identify the problem that she has?', '');
EOF
	: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
	history_rows="$(run_script --rows)"
	plain_history_rows="$(printf '%s' "$history_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	assert_not_contains "$plain_history_rows" $'GROUP\t:: Codex History' "codex history rows do not use dedicated group"
	assert_contains "$plain_history_rows" $'GROUP\t:: demo' "codex history rows use project group"
	assert_contains "$plain_history_rows" $'HIST\t' "codex history rows are listed"
	assert_contains "$plain_history_rows" "History One" "codex history includes first same-cwd chat"
	assert_contains "$plain_history_rows" "History Two" "codex history includes second same-cwd chat"
	assert_not_contains "$plain_history_rows" "Could you look at my conversation" "codex history hides raw prompt prefixes"
	assert_contains "$plain_history_rows" "1970-01" "codex history rows show last updated date"
	if printf '%s\n' "$plain_history_rows" | awk -F '\t' '$1 == "GROUP" { group = $2 } $1 == "HIST" && $5 == "codex:history-one" && group == ":: demo" { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "codex history rows appear under relevant project group"
	else
		fail "codex history rows appear under relevant project group"
	fi
	limited_group_rows="$(TMUX_THREAD_GROUP_SEARCH_LIMIT=80 run_script --rows)"
	if printf '%s\n' "$limited_group_rows" | awk -F '\t' '$1 == "GROUP" && $2 ~ /:: demo/ { if (length($7) <= 120) found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "project group search text with codex history is capped"
	else
		fail "project group search text with codex history is capped"
	fi
	if [ "$(printf '%s\n' "$plain_history_rows" | awk -F '\t' '$1 == "HIST" { print $5 }' | head -n 2 | paste -sd ' ' -)" = "codex:history-one codex:history-two" ]; then
		pass "codex history rows sort newest first"
	else
		fail "codex history rows sort newest first"
	fi
	if [ "$(printf '%s\n' "$plain_history_rows" | awk -F '\t' -v cwd="$TEST_WORKTREE" '$1 == "HIST" && $3 == cwd { count++ } END { print count + 0 }')" = "2" ]; then
		pass "codex history keeps same-cwd chats separate"
	else
		fail "codex history keeps same-cwd chats separate"
	fi
	printf '%s\trunning\tUserPromptSubmit\t%s\t%s\thistory-one\t%%2\n' "$TEST_WORKTREE" "$(date +%s)" "$(date +%s)" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	live_history_rows="$(run_script --rows)"
	plain_live_history_rows="$(printf '%s' "$live_history_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if printf '%s\n' "$plain_live_history_rows" | awk -F '\t' '$1 == "OPEN" && $5 == "codex:history-one" { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "open codex session claims matching history identity"
	else
		fail "open codex session claims matching history identity"
	fi
	if ! printf '%s\n' "$plain_live_history_rows" | awk -F '\t' '$1 == "HIST" && $5 == "codex:history-one" { found = 1 } END { exit(found ? 0 : 1) }'; then
		pass "open codex session suppresses duplicate history row"
	else
		fail "open codex session suppresses duplicate history row"
	fi
	: >"$TMUX_MOCK_LOG"
	: >"$FZF_MOCK_INPUT"
	TMUX_THREAD_USE_DISPLAY_CACHE=0 FZF_MOCK_MODE=kind FZF_MOCK_KIND=HIST run_script >/dev/null
	assert_contains "$(cat "$TMUX_MOCK_LOG")" "new-window -t test: -c $TEST_WORKTREE" "codex history selection opens a tmux window in the chat cwd"
	assert_contains "$(cat "$TMUX_MOCK_LOG")" "-n History-Two" "codex history selection reuses displayed history title for tmux window"
	assert_contains "$(cat "$TMUX_MOCK_LOG")" "resume 'history-" "codex history selection resumes selected session"
	rm -f "$HOME/.codex/state_5.sqlite"
	sqlite3 "$HOME/.codex/state_5.sqlite" <<EOF
create table threads(id text, cwd text, updated_at_ms integer, title text, first_user_message text);
with recursive seq(n) as (
	select 1
	union all
	select n + 1 from seq where n < 255
)
insert into threads
select printf('bulk-%03d', n), '$TEST_REPO', n, printf('Bulk History %03d', n), ''
from seq;
EOF
	bounded_history_rows="$(run_script --rows)"
	plain_bounded_history_rows="$(printf '%s' "$bounded_history_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if [ "$(printf '%s\n' "$plain_bounded_history_rows" | awk -F '\t' '$1 == "HIST" { count++ } END { print count + 0 }')" = "250" ]; then
		pass "codex history defaults to bounded row volume"
	else
		fail "codex history defaults to bounded row volume"
	fi
	unlimited_history_rows="$(TMUX_THREAD_CODEX_HISTORY_LIMIT=0 run_script --rows)"
	plain_unlimited_history_rows="$(printf '%s' "$unlimited_history_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	if [ "$(printf '%s\n' "$plain_unlimited_history_rows" | awk -F '\t' '$1 == "HIST" { count++ } END { print count + 0 }')" = "255" ]; then
		pass "codex history limit can be disabled with env override"
	else
		fail "codex history limit can be disabled with env override"
	fi
	rm -f "$HOME/.codex/state_5.sqlite"
	: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
else
	pass "codex history rows are listed (sqlite3 unavailable)"
	pass "codex history keeps same-cwd chats separate (sqlite3 unavailable)"
	pass "codex history selection resumes selected session (sqlite3 unavailable)"
fi
rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\tsession-pane-2\t%%2\n' "$TEST_WORKTREE" "$(date +%s)" "$(date +%s)" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\tsession-pane-3\t%%3\n' "$TEST_REPO" "$(date +%s)" "$(date +%s)" >>"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf 'codex:session-pane-2\tPane Two Title\ncodex:session-pane-3\tPane Three Title\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
pane_key_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
plain_pane_key_rows="$(printf '%s' "$pane_key_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_pane_key_rows" "Pane Two Title" "codex title follows pane id for first pane"
assert_contains "$plain_pane_key_rows" "Pane Three Title" "codex title follows pane id for second pane"
assert_contains "$plain_pane_key_rows" $'test:2,%2\tfeature\tcodex:session-pane-2' "first pane row uses pane-specific codex key"
assert_contains "$plain_pane_key_rows" $'test:2,%3\tmain\tcodex:session-pane-3' "second pane row uses pane-specific codex key"
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\tsession-test\n' "$TEST_WORKTREE" "$(date +%s)" "$(date +%s)" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf 'codex:session-test\tCached Session Title\n' >"$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
session_title_rows="$(TMUX_MOCK_TWO_CODEX_PANES=1 run_script --rows)"
plain_session_title_rows="$(printf '%s' "$session_title_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_session_title_rows" "Cached Session Title" "generated titles reuse codex session id cache"
assert_not_contains "$plain_session_title_rows" "LIN-42: Add refund flow" "codex session id cache prevents repeated title generation"
if ! grep -Fq "$TEST_WORKTREE"$'\t' "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"; then
	pass "generated titles are not duplicated under path when codex session id exists"
else
	fail "generated titles are not duplicated under path when codex session id exists"
fi
printf '%s\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/pins"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/auto-titles"
now="$(date +%s)"
started=$((now - 125))
printf '%s\trunning\tUserPromptSubmit\t%s\t%s\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
running_rows="$(run_script --rows)"
stale_running_cache_rows="$running_rows"
plain_running_rows="$(printf '%s' "$running_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_running_rows" "▶     run     demo-feature" "running codex hook shows active arrow"
assert_contains "$plain_running_rows" "2m0" "running codex hook shows work duration with seconds"
assert_not_contains "$plain_running_rows" "codex   demo-feature" "running codex hook is not shown as idle codex"
printf '%s\n' "$running_rows" >"$XDG_STATE_HOME/tmux-thread-picker/running-rows.tsv"
assert_contains "$(run_script --has-running-row "$XDG_STATE_HOME/tmux-thread-picker/running-rows.tsv")" "1" "running row detector finds active work"
printf '%s\tdone\tStop\t%s\t%s\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
done_rows="$(run_script --rows)"
plain_done_rows="$(printf '%s' "$done_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_done_rows" "●     wait    demo-feature" "done codex hook shows wait status"
assert_contains "$plain_done_rows" "2m05s" "done codex hook shows final work duration"
	assert_not_contains "$plain_done_rows" "▶     wait    demo-feature" "done codex hook does not show active arrow"
	: >"$TMUX_MOCK_LOG"
	FZF_MOCK_MODE=target FZF_MOCK_TARGET='^test:2$' run_script >/dev/null
	if awk -F '\t' -v key="$TEST_WORKTREE@$now" '$1 == key && $2 ~ /^[0-9]+$/ { found = 1 } END { exit(found ? 0 : 1) }' "$XDG_STATE_HOME/tmux-thread-picker/seen-finished"; then
		pass "seen finished marker stores path event timestamp"
	else
		fail "seen finished marker stores path event timestamp"
	fi
	seen_done_rows="$(run_script --rows)"
	plain_seen_done_rows="$(printf '%s' "$seen_done_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	assert_not_contains "$plain_seen_done_rows" "●     wait    demo-feature" "seen finished thread hides wait status"
	printf '%s\tdone\tStop\t%s\t%s\ttransition-session\t%%2\n' "$TEST_WORKTREE" "$now" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	transition_rows="$(run_script --rows)"
	plain_transition_rows="$(printf '%s' "$transition_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	assert_contains "$plain_transition_rows" $'test:2\tfeature\tcodex:transition-session' "path seen marker can transition to codex session key"
	assert_not_contains "$plain_transition_rows" "●     wait    demo-feature" "path seen marker hides same finish after session id appears"
	rm -f "$XDG_STATE_HOME/tmux-thread-picker/seen-finished"
	FZF_MOCK_MODE=target FZF_MOCK_TARGET='^test:2$' run_script >/dev/null
	if awk -F '\t' -v key="codex:transition-session@$now" '$1 == key && $2 ~ /^[0-9]+$/ { found = 1 } END { exit(found ? 0 : 1) }' "$XDG_STATE_HOME/tmux-thread-picker/seen-finished"; then
		pass "seen finished marker stores session event timestamp"
	else
		fail "seen finished marker stores session event timestamp"
	fi
	session_seen_rows="$(run_script --rows)"
	plain_session_seen_rows="$(printf '%s' "$session_seen_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	assert_not_contains "$plain_session_seen_rows" "●     wait    demo-feature" "session seen marker hides same finished event"
	session_new_done=$((now + 20))
	printf '%s\tdone\tStop\t%s\t%s\ttransition-session\t%%2\n' "$TEST_WORKTREE" "$session_new_done" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	session_new_rows="$(run_script --rows)"
	plain_session_new_rows="$(printf '%s' "$session_new_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
	assert_contains "$plain_session_new_rows" "●     wait    demo-feature" "newer session finish ignores stale seen marker"
	new_done=$((now + 10))
	printf '%s\tdone\tStop\t%s\t%s\n' "$TEST_WORKTREE" "$new_done" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
	new_done_rows="$(run_script --rows)"
plain_new_done_rows="$(printf '%s' "$new_done_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_new_done_rows" "●     wait    demo-feature" "newer finish ignores stale seen marker"
printf '%s\n' "$TEST_WORKTREE" >"$XDG_STATE_HOME/tmux-thread-picker/seen-finished"
legacy_old_done=$((now - 1))
printf '%s\tdone\tStop\t%s\t%s\n' "$TEST_WORKTREE" "$legacy_old_done" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
legacy_old_done_rows="$(run_script --rows)"
plain_legacy_old_done_rows="$(printf '%s' "$legacy_old_done_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_not_contains "$plain_legacy_old_done_rows" "●     wait    demo-feature" "legacy seen marker hides older timestamped finish"
printf '%s\tdone\tStop\t%s\t%s\n' "$TEST_WORKTREE" "$new_done" "$started" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
legacy_seen_done_rows="$(run_script --rows)"
plain_legacy_seen_done_rows="$(printf '%s' "$legacy_seen_done_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_legacy_seen_done_rows" "●     wait    demo-feature" "legacy seen marker does not hide newer timestamped finish"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/seen-finished"
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
if printf '%s\n' "$plain_rows" | awk -F '\t' 'NF != 7 { exit 1 }'; then
	pass "hidden search text is tab-safe single field"
else
	fail "hidden search text is tab-safe single field"
fi
filtered_rows="$(printf '%s\n' "$rows" | run_script --filter-rows feature)"
assert_contains "$filtered_rows" $'GROUP\t:: demo' "script filter keeps group for matching child"
assert_contains "$filtered_rows" $'\ttest:2\tfeature\t' "script filter keeps matching child row"
release_rows=$(
	cat <<EOF
GROUP	:: babacoiffure_monorepo				babacoiffure_monorepo	 :: babacoiffure_monorepo OPEN release- codex-/release- release babacoiffure_monorepo_git:7 release /tmp/release babacoiffure_monorepo
OPEN	      open    admin-refund                    codex-/admin-refund                                      admin-refund                                            	babacoiffure_monorepo_git:8	admin-refund	/tmp/admin-refund	babacoiffure_monorepo	 OPEN open admin-refund codex-/admin-refund admin-refund babacoiffure_monorepo_git:8 admin-refund /tmp/admin-refund babacoiffure_monorepo
OPEN	      open    release-                        codex-/release-                                           release                                                 	babacoiffure_monorepo_git:7	release	/tmp/release	babacoiffure_monorepo	 OPEN open release- codex-/release- release babacoiffure_monorepo_git:7 release /tmp/release babacoiffure_monorepo
GROUP	:: mainonly				mainonly	 :: mainonly OPEN main
OPEN	      open    main                            .                                                         main                                                    	test:1	main	/tmp/main	mainonly	 OPEN open main . main test:1 main /tmp/main mainonly
GROUP	:: dorali				dorali	 :: dorali OPEN run dorali . codex/setup-sentry-observability dorali:6 codex/setup-sentry-observability /Users/boss/coding/work/dorali dorali
OPEN	      open    dorali                          .                                                         codex/setup-sentry-observability                        	dorali:6	codex/setup-sentry-observability	/Users/boss/coding/work/dorali	dorali	 OPEN open dorali . codex/setup-sentry-observability dorali:6 codex/setup-sentry-observability /Users/boss/coding/work/dorali dorali
EOF
)
filtered_release_rows="$(printf '%s\n' "$release_rows" | run_script --filter-rows rele)"
assert_contains "$filtered_release_rows" $'GROUP\t:: babacoiffure_monorepo' "script filter keeps group for rele child match"
assert_contains "$filtered_release_rows" "release-" "script filter keeps rele child row"
assert_contains "$filtered_release_rows" "open    release-" "script filter keeps visible thread status"
assert_not_contains "$filtered_release_rows" "admin-refund" "script filter hides nonmatching sibling rows"
assert_not_contains "$filtered_release_rows" $'GROUP\t:: mainonly' "script filter hides unrelated group for rele query"
assert_not_contains "$filtered_release_rows" $'GROUP\t:: dorali' "script filter does not fuzzy-match release across unrelated paths"
filtered_compact_rows="$(printf '%s\n' "$release_rows" | run_script --filter-rows babacoiffuremonorepo)"
assert_contains "$filtered_compact_rows" $'GROUP\t:: babacoiffure_monorepo' "script filter matches punctuation-insensitive project names"
assert_contains "$filtered_compact_rows" "admin-refund" "script filter shows whole group when group label matches"
if command -v fzf >/dev/null 2>&1; then
	filtered_rows="$(printf '%s\n' "$rows" | fzf --delimiter=$'\t' --with-nth=2 --filter=Main || true)"
	assert_contains "$filtered_rows" "Main Thread" "real fzf filter matches visible row text"
else
	pass "real fzf filter matches visible row text (fzf unavailable)"
fi

printf '%s\n' "$rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
cached_picker_input="$(cat "$FZF_MOCK_INPUT")"
assert_contains "$cached_picker_input" "Main Thread" "fresh display cache feeds picker input"
if [ ! -e "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" ] &&
	[ ! -e "$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" ]; then
	pass "fresh display cache skips inventory caches"
else
	fail "fresh display cache skips inventory caches"
fi

printf '%s\n' "$rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 TMUX_MOCK_WORKTREE_PATH="$TEST_REPO" FZF_MOCK_MODE=none run_script >/dev/null
changed_path_cache_input="$(cat "$FZF_MOCK_INPUT")"
plain_changed_path_cache_input="$(printf '%s' "$changed_path_cache_input" | perl -pe 's/\e\[[0-9;]*m//g')"
if printf '%s\n' "$plain_changed_path_cache_input" | awk -F '\t' -v repo="$TEST_REPO" '$1 == "OPEN" && $3 == "test:2" && $4 == "main" && $5 == repo { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "stale display cache rebuilds after live target path changes"
else
	fail "stale display cache rebuilds after live target path changes"
fi
if ! printf '%s\n' "$plain_changed_path_cache_input" | awk -F '\t' -v worktree="$TEST_WORKTREE" '$1 == "OPEN" && $3 == "test:2" && $4 == "feature" && $5 == worktree { found = 1 } END { exit(found ? 0 : 1) }'; then
	pass "stale display cache does not preserve old target identity"
else
	fail "stale display cache does not preserve old target identity"
fi

printf '%s\n' "$rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
run_script --set-title "$TEST_REPO" "Renamed Thread"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
renamed_cache_input="$(cat "$FZF_MOCK_INPUT")"
plain_renamed_cache_input="$(printf '%s' "$renamed_cache_input" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_renamed_cache_input" "Renamed Thread" "stale display cache rebuilds after manual title changes"
assert_not_contains "$plain_renamed_cache_input" $'OPEN\t      open*   Main Thread' "stale display cache does not preserve old title"
run_script --set-title "$TEST_REPO" "Main Thread"
rows="$(run_script --rows)"

printf 'GROUP\t:: Old Cache\t\t\t\told\t :: Old Cache\nOPEN\told cache row\ttest:9\tmain\t%s\tdemo\t OPEN old cache row\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=0 FZF_MOCK_MODE=none run_script >/dev/null
cache_bypass_input="$(cat "$FZF_MOCK_INPUT")"
assert_not_contains "$cache_bypass_input" "Old Cache" "cache disabled bypasses valid display cache"
assert_contains "$cache_bypass_input" "Main Thread" "cache disabled rebuilds picker rows"

rm -f "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" \
	"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
inactive_worktree="$(dirname "$TEST_REPO")/demo-inactive"
git -C "$TEST_REPO" worktree add -b inactive "$inactive_worktree" >/dev/null 2>&1
attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_attention_rows="$(printf '%s' "$attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_attention_rows" "$TEST_REPO" "attention mode keeps current thread"
assert_contains "$plain_attention_rows" "$TEST_WORKTREE" "attention mode keeps open inactive thread"
assert_not_contains "$plain_attention_rows" "$inactive_worktree" "attention mode hides inactive unpinned worktree"
if [ ! -e "$XDG_STATE_HOME/tmux-thread-picker/repo-candidates.tsv" ] &&
	[ ! -e "$XDG_STATE_HOME/tmux-thread-picker/worktrees.tsv" ] &&
	[ ! -e "$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv" ]; then
	pass "attention mode skips full inventory caches"
else
	fail "attention mode skips full inventory caches"
fi

run_script --toggle-pin "$inactive_worktree"
pinned_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_pinned_attention_rows="$(printf '%s' "$pinned_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_pinned_attention_rows" "$inactive_worktree" "attention mode keeps pinned inactive worktree"
run_script --toggle-pin "$inactive_worktree"
activity_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=1 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_activity_attention_rows="$(printf '%s' "$activity_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_activity_attention_rows" "$TEST_WORKTREE" "attention mode keeps open thread with tmux activity flag"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/process-windows.tsv"
busy_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_BUSY_PROCESS=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_busy_attention_rows="$(printf '%s' "$busy_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_busy_attention_rows" "$TEST_WORKTREE" "attention mode keeps busy process thread"
assert_contains "$plain_busy_attention_rows" "!" "attention mode marks busy process thread"
rm -f "$XDG_STATE_HOME/tmux-thread-picker/process-windows.tsv"
codex_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=codex run_script --rows)"
plain_codex_attention_rows="$(printf '%s' "$codex_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_codex_attention_rows" "$TEST_WORKTREE" "attention mode keeps open codex cli"

now="$(date +%s)"
printf '%s\tdone\tStop\t%s\n' "$TEST_WORKTREE" "$now" >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"
printf '%s\n' "$stale_running_cache_rows" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
cached_picker_input="$(cat "$FZF_MOCK_INPUT")"
plain_cached_picker_input="$(printf '%s' "$cached_picker_input" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_cached_picker_input" $'OPEN\t●     wait' "cached picker overlay updates visible codex status"
assert_contains "$plain_cached_picker_input" "demo-feature" "cached picker overlay keeps thread title"
assert_not_contains "$plain_cached_picker_input" "run     demo-feature" "cached picker overlay removes stale visible run status"
assert_not_contains "$plain_cached_picker_input" "OPEN ▶ run demo-feature" "cached picker overlay rebuilds stale hidden run search text"
if printf '%s\n' "$plain_cached_picker_input" | awk -F '\t' 'NF != 7 { exit 1 }'; then
	pass "cached picker overlay keeps hidden search text tab-safe"
else
	fail "cached picker overlay keeps hidden search text tab-safe"
fi
: >"$XDG_STATE_HOME/tmux-thread-picker/codex-hook-states.tsv"

run_script --toggle-archive "$TEST_WORKTREE"
rows="$(run_script --rows)"
plain_rows="$(printf '%s' "$rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_rows" "$TEST_WORKTREE" "archived open thread visible by default"
assert_contains "$plain_rows" " A " "archived open thread keeps archive marker"
assert_not_contains "$plain_rows" $'GROUP\t:: Archived' "Archived group hidden by default"

archived_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=codex run_script --rows)"
plain_archived_attention_rows="$(printf '%s' "$archived_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_archived_attention_rows" "$TEST_WORKTREE" "attention mode keeps archived open codex thread"

archived_rows="$(TMUX_THREAD_SHOW_ARCHIVED=1 run_script --rows)"
plain_archived_rows="$(printf '%s' "$archived_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_archived_rows" $'GROUP\t:: Archived' "archived mode includes Archived group"
assert_contains "$plain_archived_rows" "$TEST_WORKTREE" "archived mode includes archived worktree"
attention_archived_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_THREAD_SHOW_ARCHIVED=1 run_script --rows)"
plain_attention_archived_rows="$(printf '%s' "$attention_archived_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_attention_archived_rows" $'GROUP\t:: Archived' "archived mode disables attention filter"
assert_contains "$plain_attention_archived_rows" "$TEST_WORKTREE" "archived attention mode includes archived worktree"

list_output="$(run_script --list)"
assert_contains "$list_output" ":: Pinned" "list mode includes readable group headers"
assert_contains "$list_output" "Main Thread" "list mode strips ansi and includes titles"

: >"$FZF_MOCK_ARGS"
: >"$FZF_MOCK_INPUT"
FZF_MOCK_MODE=first-data run_script >/dev/null
fzf_args="$(cat "$FZF_MOCK_ARGS")"
fzf_input="$(cat "$FZF_MOCK_INPUT")"
assert_contains "$fzf_args" "--with-nth=2" "fzf displays only visible row text"
assert_contains "$fzf_args" "work" "fzf header includes work duration column"
assert_contains "$fzf_args" "--disabled" "fzf delegates filtering to script"
assert_contains "$fzf_args" "change:reload($SCRIPT --filter-rows {q}" "fzf reloads filtered grouped rows on query change"
assert_not_contains "$fzf_args" "--nth=2,7" "fzf does not hide normal search fields behind nth"
assert_not_contains "$fzf_input" $'\033[8m' "fzf input does not rely on concealed search text"
assert_contains "$fzf_args" "load:transform:[[ {1} = GROUP ]] && echo down" "fzf skips group on initial load"
assert_contains "$fzf_args" "result:transform:[[ {1} = GROUP ]] && echo down" "fzf skips group after filtering"
assert_contains "$fzf_args" "enter:transform:[[ {1} = GROUP ]] && echo down || echo accept" "enter does not accept group rows"
assert_contains "$fzf_args" "ctrl-x:execute-silent" "fzf has single-key hide binding"
assert_contains "$fzf_args" "ctrl-t:execute($SCRIPT --edit-title {5})+reload" "fzf edits title with interactive prompt and reloads"
assert_contains "$fzf_args" "Ctrl-y auto-title" "fzf footer advertises auto-title binding"
assert_contains "$fzf_args" "ctrl-y:execute-silent($SCRIPT --regen-title {5} {3})" "fzf can rerun title logic for selected row"
assert_contains "$fzf_args" "alt-f:reload(TMUX_THREAD_ATTENTION_ONLY=0" "fzf can reload full inventory"
assert_not_contains "$fzf_args" "focus:transform" "ctrl-k can move upward across group rows"
assert_file_contains_line "$TMUX_MOCK_LOG" "switch-client -t test:1" "OPEN selection switches tmux client"

: >"$TMUX_MOCK_LOG"
: >"$FZF_MOCK_INPUT"
TMUX_MOCK_TWO_CODEX_PANES=1 FZF_MOCK_MODE=target FZF_MOCK_TARGET='^test:2,%2$' run_script >/dev/null
assert_file_contains_line "$TMUX_MOCK_LOG" "switch-client -t test:2" "pane-specific OPEN selection switches tmux window"
assert_file_contains_line "$TMUX_MOCK_LOG" "select-pane -t %2" "pane-specific OPEN selection focuses selected codex pane"

printf 'OPEN\tstale cache row\ttest:9\tmain\t%s\tdemo\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
cached_picker_input="$(cat "$FZF_MOCK_INPUT")"
assert_contains "$cached_picker_input" $'GROUP\t:: Pinned' "pick mode rebuilds stale cache without group rows"

printf 'GROUP\t:: Old Cache\t\t\t\told\nOPEN\told cache row\ttest:9\tmain\t%s\tdemo\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
cached_picker_input="$(cat "$FZF_MOCK_INPUT")"
assert_not_contains "$cached_picker_input" "Old Cache" "pick mode rebuilds grouped cache without hidden search text"
assert_contains "$cached_picker_input" $'GROUP\t:: Pinned' "rebuilt grouped cache includes fresh group rows"

run_script --kill-window OPEN test:2 test:1
assert_file_contains_line "$TMUX_MOCK_LOG" "kill-window -t test:2" "kill-window kills selected open window"
: >"$TMUX_MOCK_LOG"
run_script --kill-window OPEN test:2 test:2
assert_file_contains_line "$TMUX_MOCK_LOG" "switch-client -t test:1" "kill-window switches away from current window"
assert_file_contains_line "$TMUX_MOCK_LOG" "kill-window -t test:2" "kill-window kills current window after fallback"

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
