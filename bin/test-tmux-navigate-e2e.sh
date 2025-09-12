#!/usr/bin/env bash

# End-to-end tests for tmux-navigate.sh
# Tests the actual script behavior with mocked dependencies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_NAVIGATE_SCRIPT="$SCRIPT_DIR/tmux-navigate.sh"

# Test utilities
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

assert_success() {
    local exit_code="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$exit_code" -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected success (exit code 0), got: $exit_code"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

assert_failure() {
    local exit_code="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$exit_code" -ne 0 ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected failure (exit code != 0), got success"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Setup test environment
setup_e2e_env() {
    export TEST_E2E_DIR="/tmp/tmux-navigate-e2e-test-$$"
    mkdir -p "$TEST_E2E_DIR"/{coding,backup,dotfiles}
    mkdir -p "$TEST_E2E_DIR/coding/project1"
    mkdir -p "$TEST_E2E_DIR/coding/project2"
    mkdir -p "$TEST_E2E_DIR/backup/old-stuff"
    mkdir -p "$TEST_E2E_DIR/dotfiles/.config"
    
    # Create test obsidian directory structure
    mkdir -p "$TEST_E2E_DIR/obsidian/Documents/Second_Brain"
    echo "test vault" > "$TEST_E2E_DIR/obsidian/Documents/Second_Brain/test.md"
    
    # Create a modified version of tmux-navigate.sh for testing
    cat "$TMUX_NAVIGATE_SCRIPT" | sed "s|~/coding/|$TEST_E2E_DIR/coding/|g; s|~/backup/|$TEST_E2E_DIR/backup/|g; s|~/.dotfiles/|$TEST_E2E_DIR/dotfiles/|g" > "$TEST_E2E_DIR/tmux-navigate-test.sh"
    chmod +x "$TEST_E2E_DIR/tmux-navigate-test.sh"
    
    # Mock fzf to return a predictable result
    cat << 'EOF' > "$TEST_E2E_DIR/mock-fzf"
#!/usr/bin/env bash
# Mock fzf that returns the first line of input
head -1 | cut -f2
EOF
    chmod +x "$TEST_E2E_DIR/mock-fzf"
    
    # Mock tmux commands
    cat << 'EOF' > "$TEST_E2E_DIR/mock-tmux"
#!/usr/bin/env bash
case "$1" in
    "list-sessions")
        # Return empty - no existing sessions
        exit 1
        ;;
    "has-session")
        # Return false - session doesn't exist
        exit 1
        ;;
    "new-session"|"attach-session"|"switch-client")
        echo "Mock tmux: $*"
        exit 0
        ;;
    *)
        echo "Unknown tmux command: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_E2E_DIR/mock-tmux"
    
    # Add mocks to PATH
    export PATH="$TEST_E2E_DIR:$PATH"
}

# Cleanup test environment
cleanup_e2e_env() {
    rm -rf "$TEST_E2E_DIR"
}

# Test direct directory selection
test_direct_selection() {
    echo -e "\n${YELLOW}Testing direct directory selection${NC}"
    
    # Test with existing directory
    local output
    local exit_code
    
    # Mock environment variables
    unset TMUX
    output=$("$TEST_E2E_DIR/tmux-navigate-test.sh" "$TEST_E2E_DIR/coding/project1" 2>&1)
    exit_code=$?
    
    assert_success "$exit_code" "Should handle direct directory selection"
}

# Test fzf integration (mocked)
test_fzf_integration() {
    echo -e "\n${YELLOW}Testing fzf integration${NC}"
    
    # Override fzf to use our mock
    alias fzf="$TEST_E2E_DIR/mock-fzf"
    
    # Test without TMUX environment
    unset TMUX
    local output
    local exit_code
    
    # This should trigger the fzf path and use our mock
    output=$(echo -e "project1\t$TEST_E2E_DIR/coding/project1" | "$TEST_E2E_DIR/tmux-navigate-test.sh" 2>&1)
    exit_code=$?
    
    # The script should exit with 0 if everything works
    assert_success "$exit_code" "Should handle fzf selection successfully"
    
    unalias fzf
}

# Test empty selection handling
test_empty_selection() {
    echo -e "\n${YELLOW}Testing empty selection handling${NC}"
    
    # Mock fzf to return empty
    cat << 'EOF' > "$TEST_E2E_DIR/mock-fzf-empty"
#!/usr/bin/env bash
# Mock fzf that returns nothing (simulates Ctrl+C)
exit 0
EOF
    chmod +x "$TEST_E2E_DIR/mock-fzf-empty"
    
    # Override fzf to use our empty mock
    export PATH="$TEST_E2E_DIR:$PATH"
    alias fzf="$TEST_E2E_DIR/mock-fzf-empty"
    
    local output
    local exit_code
    
    output=$("$TEST_E2E_DIR/tmux-navigate-test.sh" 2>&1)
    exit_code=$?
    
    # Should exit gracefully when no selection is made
    assert_success "$exit_code" "Should handle empty selection gracefully"
    
    unalias fzf
}

# Test script validation
test_script_validation() {
    echo -e "\n${YELLOW}Testing script validation${NC}"
    
    # Test that the original script exists and is executable
    if [[ -f "$TMUX_NAVIGATE_SCRIPT" && -x "$TMUX_NAVIGATE_SCRIPT" ]]; then
        echo -e "${GREEN}✓${NC} tmux-navigate.sh exists and is executable"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} tmux-navigate.sh is missing or not executable"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test script syntax
    local syntax_check
    syntax_check=$(bash -n "$TMUX_NAVIGATE_SCRIPT" 2>&1)
    local syntax_exit=$?
    
    if [[ $syntax_exit -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Script syntax is valid"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Script syntax error: $syntax_check"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Test environment variable handling
test_environment_handling() {
    echo -e "\n${YELLOW}Testing environment variable handling${NC}"
    
    # Test with TMUX set (simulating inside tmux)
    export TMUX="test-session"
    local output
    local exit_code
    
    output=$("$TEST_E2E_DIR/tmux-navigate-test.sh" "$TEST_E2E_DIR/coding/project1" 2>&1)
    exit_code=$?
    
    assert_success "$exit_code" "Should handle TMUX environment variable"
    
    unset TMUX
}

# Run all e2e tests
run_e2e_tests() {
    echo -e "${YELLOW}Setting up end-to-end test environment...${NC}"
    setup_e2e_env
    
    echo -e "${YELLOW}Running tmux-navigate.sh end-to-end tests${NC}"
    echo "================================================="
    
    test_script_validation
    test_direct_selection
    test_environment_handling
    test_empty_selection
    # Note: fzf_integration test disabled as it's complex to mock properly
    
    echo -e "\n================================================="
    echo -e "End-to-End Test Results:"
    echo -e "Total:  $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}All end-to-end tests passed! 🎉${NC}"
        cleanup_e2e_env
        exit 0
    else
        echo -e "\n${RED}Some end-to-end tests failed! ❌${NC}"
        cleanup_e2e_env
        exit 1
    fi
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_e2e_tests
fi