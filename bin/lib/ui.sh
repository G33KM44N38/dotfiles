#!/bin/bash

# UI and logging functions for dotfiles script

# Color codes
RESTORE='\033[0m'
NC='\033[0m'
BLACK='\033[00;30m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'
LBLACK='\033[01;30m'
LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'
OVERWRITE='\e[1A\e[K'

# Emoji codes
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9C\x96${NC}"
ARROW="${CYAN}\xE2\x96\xB6${NC}"

# Global task state
TASK=""

# _task colorizes the given argument with spacing
function _task {
    [[ -n $TASK ]] && printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\\n"
    TASK="$1"
    printf "${LBLACK} [ ]  ${TASK} \\n${LRED}"
}

# _cmd performs commands with error checking
function _cmd {
    [[ ! -f $DOTFILES_LOG ]] && touch $DOTFILES_LOG
    echo "" >> $DOTFILES_LOG
    if eval "$1" >> /dev/null 2>> $DOTFILES_LOG; then
        return 0 # success
    fi
    printf "${OVERWRITE}${LRED} [X]  ${TASK}${LRED}\\n"
    sed 's/^/      /' "$DOTFILES_LOG"
    printf "\\n"
    exit 1
}

function _clear_task {
    TASK=""
}

function _task_done {
    printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}
"
    _clear_task
}

# Enhanced command execution with better error reporting
function _cmd_safe {
    local cmd="$1"
    local desc="$2"
    
    [[ ! -f $DOTFILES_LOG ]] && touch $DOTFILES_LOG
    echo "=== $(date) === $desc ===" >> $DOTFILES_LOG
    
    if eval "$cmd" >> $DOTFILES_LOG 2>&1; then
        return 0
    else
        local exit_code=$?
        printf "${OVERWRITE}${LRED} [X]  ${TASK} (exit code: $exit_code)${LRED}\\n"
        echo -e "${YELLOW}Command failed: ${cmd}${NC}"
        echo -e "${YELLOW}Check log: ${DOTFILES_LOG}${NC}"
        return $exit_code
    fi
}

# Show success message with context
function _success {
    local message="$1"
    echo -e "${CHECK_MARK} ${GREEN}${message}${NC}"
}

# Show warning message
function _warning {
    local message="$1"
    echo -e "${ARROW} ${YELLOW}${message}${NC}"
}

# Show error message
function _error {
    local message="$1"
    echo -e "${X_MARK} ${RED}${message}${NC}"
}

# Prompt user for yes/no confirmation
function _confirm {
    local prompt="$1"
    local default="$2"  # 'y' or 'n'
    
    local prompt_suffix
    if [[ "$default" == "y" ]]; then
        prompt_suffix="(Y/n)"
    else
        prompt_suffix="(y/N)"
    fi
    
    read -p "${CYAN}${prompt} ${prompt_suffix} ${NC}" -n 1 -r
    echo # Newline after read
    
    if [[ -z $REPLY ]]; then
        [[ "$default" == "y" ]]
    elif [[ $REPLY =~ ^[Yy]$ ]]; then
        true
    else
        false
    fi
}