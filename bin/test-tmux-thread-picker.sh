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

	if printf '%s' "$haystack" | grep -Fq "$needle"; then
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

	if printf '%s' "$haystack" | grep -Fq "$needle"; then
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
		printf '@2\t%%2\t%s\t%s\t1002\n' "${TMUX_MOCK_WORKTREE_COMMAND:-codex}" "$TEST_WORKTREE"
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
				printf '@2\t%s\n' "$TEST_WORKTREE"
				;;
			'#{window_id}'$'\t''#{pane_id}'$'\t''#{pane_current_command}'$'\t''#{pane_current_path}'$'\t''#{pane_pid}')
				printf '@1\t%%1\tzsh\t%s\t1001\n' "$TEST_REPO"
				printf '@2\t%%2\t%s\t%s\t1002\n' "${TMUX_MOCK_WORKTREE_COMMAND:-codex}" "$TEST_WORKTREE"
				;;
			'#{session_name}:#{window_index}'$'\t''#{window_id}'$'\t''#{window_name}'$'\t''#{window_activity_flag}'$'\t''#{window_bell_flag}')
				printf 'test:1\t@1\tmain\t0\t0\n'
				printf 'test:2\t@2\tfeature\t%s\t0\n' "${TMUX_MOCK_WORKTREE_ACTIVITY:-1}"
				;;
			'#{session_name}'$'\t''#{window_index}'$'\t''#{window_id}'$'\t''#{window_name}'$'\t''#{window_activity_flag}'$'\t''#{window_bell_flag}'$'\t''#{pane_current_path}'$'\t''#{@secondary-worktree-path}')
				printf 'test\t1\t@1\tmain\t0\t0\t%s\t\n' "$TEST_REPO"
				printf 'test\t2\t@2\tfeature\t%s\t0\t%s\t\n' "${TMUX_MOCK_WORKTREE_ACTIVITY:-1}" "$TEST_WORKTREE"
				;;
			*)
				printf '1\n2\n'
				;;
		esac
		;;
	show-options)
		exit 0
		;;
	switch-client)
		printf 'switch-client %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	select-window)
		printf 'select-window %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	kill-window)
		printf 'kill-window %s\n' "$*" >>"$TMUX_MOCK_LOG"
		;;
	command-prompt)
		printf 'command-prompt %s\n' "$*" >>"$TMUX_MOCK_LOG"
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
	first-data|*)
		printf '%s\n' "$input" | awk -F '\t' '$1 != "GROUP" && NF { print; exit }'
		;;
esac
EOF
	chmod +x "$mock_bin/fzf"
}

write_mock_curl() {
	cat >"$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "$mock_bin/curl"
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
	export NO_COLOR="1"
	export TMUX_MOCK_LOG="$tmp_root/tmux.log"
	export FZF_MOCK_ARGS="$tmp_root/fzf-args.log"
	export FZF_MOCK_INPUT="$tmp_root/fzf-input.tsv"
	: >"$TMUX_MOCK_LOG"
	: >"$FZF_MOCK_ARGS"
	: >"$FZF_MOCK_INPUT"

	write_mock_tmux
	write_mock_fzf
	write_mock_curl
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

run_script --toggle-pin "$TEST_REPO"
run_script --set-title "$TEST_REPO" "Main Thread"
rows="$(run_script --rows)"
plain_rows="$(printf '%s' "$rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_rows" $'GROUP\t:: Pinned' "rows include Pinned group"
assert_contains "$plain_rows" $'GROUP\t:: demo' "rows include project group"

attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_attention_rows="$(printf '%s' "$attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_attention_rows" "$TEST_REPO" "attention mode keeps current thread"
assert_not_contains "$plain_attention_rows" "$TEST_WORKTREE" "attention mode hides inactive unpinned thread"

run_script --toggle-pin "$TEST_WORKTREE"
pinned_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_pinned_attention_rows="$(printf '%s' "$pinned_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_not_contains "$plain_pinned_attention_rows" "$TEST_WORKTREE" "attention mode hides pinned inactive thread"
activity_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=1 TMUX_MOCK_WORKTREE_COMMAND=zsh run_script --rows)"
plain_activity_attention_rows="$(printf '%s' "$activity_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_not_contains "$plain_activity_attention_rows" "$TEST_WORKTREE" "attention mode ignores tmux activity flag"
codex_attention_rows="$(TMUX_THREAD_ATTENTION_ONLY=1 TMUX_MOCK_WORKTREE_ACTIVITY=0 TMUX_MOCK_WORKTREE_COMMAND=codex run_script --rows)"
plain_codex_attention_rows="$(printf '%s' "$codex_attention_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_codex_attention_rows" "$TEST_WORKTREE" "attention mode keeps open codex cli"
run_script --toggle-pin "$TEST_WORKTREE"

run_script --toggle-archive "$TEST_WORKTREE"
rows="$(run_script --rows)"
plain_rows="$(printf '%s' "$rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_not_contains "$plain_rows" "$TEST_WORKTREE" "archived worktree hidden by default"
assert_not_contains "$plain_rows" $'GROUP\t:: Archived' "Archived group hidden by default"

archived_rows="$(TMUX_THREAD_SHOW_ARCHIVED=1 run_script --rows)"
plain_archived_rows="$(printf '%s' "$archived_rows" | perl -pe 's/\e\[[0-9;]*m//g')"
assert_contains "$plain_archived_rows" $'GROUP\t:: Archived' "archived mode includes Archived group"
assert_contains "$plain_archived_rows" "$TEST_WORKTREE" "archived mode includes archived worktree"

list_output="$(run_script --list)"
assert_contains "$list_output" ":: Pinned" "list mode includes readable group headers"
assert_contains "$list_output" "Main Thread" "list mode strips ansi and includes titles"

: >"$FZF_MOCK_ARGS"
: >"$FZF_MOCK_INPUT"
FZF_MOCK_MODE=first-data run_script >/dev/null
fzf_args="$(cat "$FZF_MOCK_ARGS")"
assert_contains "$fzf_args" "load:transform:[[ {1} = GROUP ]] && echo down" "fzf skips group on initial load"
assert_contains "$fzf_args" "result:transform:[[ {1} = GROUP ]] && echo down" "fzf skips group after filtering"
assert_contains "$fzf_args" "enter:transform:[[ {1} = GROUP ]] && echo down || echo accept" "enter does not accept group rows"
assert_contains "$fzf_args" "ctrl-x:execute-silent" "fzf has single-key hide binding"
assert_contains "$fzf_args" "alt-f:reload(TMUX_THREAD_ATTENTION_ONLY=0" "fzf can reload full inventory"
assert_not_contains "$fzf_args" "focus:transform" "ctrl-k can move upward across group rows"
assert_file_contains_line "$TMUX_MOCK_LOG" "switch-client -t test:1" "OPEN selection switches tmux client"

printf 'OPEN\tstale cache row\ttest:9\tmain\t%s\tdemo\n' "$TEST_REPO" >"$XDG_STATE_HOME/tmux-thread-picker/display-rows.tsv"
: >"$FZF_MOCK_INPUT"
TMUX_THREAD_USE_DISPLAY_CACHE=1 FZF_MOCK_MODE=none run_script >/dev/null
cached_picker_input="$(cat "$FZF_MOCK_INPUT")"
assert_contains "$cached_picker_input" $'GROUP\t:: Pinned' "pick mode rebuilds stale cache without group rows"

run_script --kill-window OPEN test:2 test:1
assert_file_contains_line "$TMUX_MOCK_LOG" "kill-window -t test:2" "kill-window kills selected open window"

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
