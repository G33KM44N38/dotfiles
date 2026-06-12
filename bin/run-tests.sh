#!/usr/bin/env bash

# Test runner for dotfiles shell scripts.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Running dotfiles test suite${NC}"
echo "==========================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

overall_success=true

run_test() {
    local name="$1"
    local path="$2"

    if [ ! -x "$path" ]; then
        echo -e "${YELLOW}skip${NC} $name ($path not found)"
        return 0
    fi

    echo -e "\n${YELLOW}Running $name...${NC}"
    if "$path"; then
        echo -e "${GREEN}pass${NC} $name"
    else
        echo -e "${RED}fail${NC} $name"
        overall_success=false
    fi
}

run_test "tmux-thread-picker" "$SCRIPT_DIR/test-tmux-thread-picker.sh"
run_test "tmux-navigate" "$SCRIPT_DIR/test-tmux-navigate.sh"

# Summary
echo -e "\n${BLUE}Test summary${NC}"
echo "============"

if $overall_success; then
    echo -e "${GREEN}All tests passed${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
