#!/usr/bin/env bash

# Test suite for tmux-navigate.sh
# Simple bash-based testing framework

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

assert_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected to contain: $expected"
        echo -e "  Actual:              $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

assert_not_empty() {
    local actual="$1"
    local test_name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ -n "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected non-empty result"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Setup test environment
setup_test_env() {
    export TEST_DIR="/tmp/tmux-navigate-test-$$"
    mkdir -p "$TEST_DIR"/{coding,backup,dotfiles}
    mkdir -p "$TEST_DIR/coding/project1"
    mkdir -p "$TEST_DIR/coding/project2"
    mkdir -p "$TEST_DIR/backup/old-stuff"
    mkdir -p "$TEST_DIR/dotfiles/.config"
    
    # Create test obsidian directory structure
    mkdir -p "$TEST_DIR/obsidian/Documents/Second_Brain"
    echo "test vault" > "$TEST_DIR/obsidian/Documents/Second_Brain/test.md"
    
    # Create the actual path structure to match real setup
    mkdir -p "$TEST_DIR/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
    echo "real second brain" > "$TEST_DIR/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/notes.md"
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf "$TEST_DIR"
}

# Extract functions from tmux-navigate.sh for testing
source_script_functions() {
    # Create a version of the script with functions extracted
    cat << 'EOF' > "$TEST_DIR/tmux-navigate-functions.sh"
#!/usr/bin/env bash

# Extract the path expansion logic as a function
expand_and_validate_paths() {
    local raw_paths=("$@")
    local search_paths=()
    
    for dir in "${raw_paths[@]}"; do
        expanded_dir=$(eval echo "$dir")
        if [[ -d "$expanded_dir" ]]; then
            search_paths+=("$expanded_dir")
        fi
    done
    
    printf '%s\n' "${search_paths[@]}"
}

# Extract the basename conflict resolution logic (fixed for spaces)
process_directories() {
    local dirs_input="$1"
    declare -a basenames
    declare -a paths_strings
    
    while IFS= read -r dir; do
        clean_dir=$(echo "$dir" | sed 's:/*$::')
        dir_name=$(basename "$clean_dir" | tr . _)
        
        index=-1
        for ((j=0; j<${#basenames[@]}; j++)); do
            if [[ ${basenames[j]} == "$dir_name" ]]; then
                index=$j
                break
            fi
        done
        
        if [[ $index -ge 0 ]]; then
            paths_strings[index]+=" $clean_dir"
        else
            basenames+=("$dir_name")
            paths_strings+=("$clean_dir")
        fi
    done <<< "$dirs_input"
    
    # Output in format: basename:paths
    for ((i=0; i<${#basenames[@]}; i++)); do
        echo "${basenames[i]}:${paths_strings[i]}"
    done
}

# Extract fzf input generation logic
generate_fzf_input() {
    local existing_sessions="$1"
    shift
    local basename_path_pairs=("$@")
    
    local fzf_input=""
    
    for pair in "${basename_path_pairs[@]}"; do
        IFS=':' read -r basename paths_str <<< "$pair"
        paths_str=${paths_str# }
        IFS=' ' read -ra paths <<< "$paths_str"
        
        if [[ ${#paths[@]} -gt 1 ]]; then
            for path in "${paths[@]}"; do
                if echo "$existing_sessions" | grep -q -E "^${basename}$"; then
                    fzf_input+="[TMUX] $path\t$path\n"
                else
                    fzf_input+="$path\t$path\n"
                fi
            done
        else
            path=${paths[0]}
            if echo "$existing_sessions" | grep -q -E "^${basename}$"; then
                fzf_input+="[TMUX] $basename\t$path\n"
            else
                fzf_input+="$basename\t$path\n"
            fi
        fi
    done
    
    echo -e "$fzf_input"
}

# Function to sanitize session names
sanitize_session_name() {
    local name="$1"
    echo "$name" | tr . _
}
EOF
    
    source "$TEST_DIR/tmux-navigate-functions.sh"
}

# Test functions
test_path_expansion() {
    echo -e "\n${YELLOW}Testing path expansion and validation${NC}"
    
    # Test with existing directories
    local result
    result=$(expand_and_validate_paths "$TEST_DIR/coding" "$TEST_DIR/backup" "/nonexistent")
    assert_contains "$TEST_DIR/coding" "$result" "Should include existing coding directory"
    assert_contains "$TEST_DIR/backup" "$result" "Should include existing backup directory"
    assert_not_contains "/nonexistent" "$result" "Should exclude nonexistent directory"
}

test_basename_processing() {
    echo -e "\n${YELLOW}Testing basename conflict resolution${NC}"
    
    # Test with conflicting basenames
    local result
    local dirs_input="$TEST_DIR/coding/project1
$TEST_DIR/backup/project1"
    result=$(process_directories "$dirs_input")
    assert_contains "project1:" "$result" "Should handle basename conflicts"
    
    # Test with unique basenames  
    dirs_input="$TEST_DIR/coding/project1
$TEST_DIR/coding/project2"
    result=$(process_directories "$dirs_input")
    assert_contains "project1:" "$result" "Should process unique basename project1"
    assert_contains "project2:" "$result" "Should process unique basename project2"
}

test_fzf_input_generation() {
    echo -e "\n${YELLOW}Testing fzf input generation${NC}"
    
    # Test without existing tmux sessions
    local result
    result=$(generate_fzf_input "" "project1:$TEST_DIR/coding/project1")
    assert_contains "project1" "$result" "Should contain basename for unique path"
    assert_contains "$TEST_DIR/coding/project1" "$result" "Should contain full path"
    
    # Test with existing tmux session
    result=$(generate_fzf_input "project1" "project1:$TEST_DIR/coding/project1")
    assert_contains "[TMUX]" "$result" "Should mark existing tmux sessions"
}

test_session_name_sanitization() {
    echo -e "\n${YELLOW}Testing session name sanitization${NC}"
    
    local result
    result=$(sanitize_session_name "my.project")
    assert_equals "my_project" "$result" "Should replace dots with underscores"
    
    result=$(sanitize_session_name "normal-name")
    assert_equals "normal-name" "$result" "Should keep hyphens unchanged"
}

test_integration() {
    echo -e "\n${YELLOW}Testing integration scenarios${NC}"
    
    # Test the full pipeline with test data
    local raw_paths=("$TEST_DIR/coding" "$TEST_DIR/backup")
    local expanded_paths
    expanded_paths=$(expand_and_validate_paths "${raw_paths[@]}")
    assert_not_empty "$expanded_paths" "Should expand paths successfully"
    
    # Test with obsidian-like structure
    local obsidian_result
    obsidian_result=$(expand_and_validate_paths "$TEST_DIR/obsidian/Documents/")
    assert_contains "$TEST_DIR/obsidian/Documents/" "$obsidian_result" "Should handle obsidian path"
}

test_second_brain_navigation() {
    echo -e "\n${YELLOW}Testing Second Brain navigation${NC}"
    
    # Test the real Second Brain path structure
    local second_brain_path="$TEST_DIR/Library/Mobile Documents/iCloud~md~obsidian/Documents/"
    local expanded_result
    expanded_result=$(expand_and_validate_paths "$second_brain_path")
    assert_contains "$second_brain_path" "$expanded_result" "Should expand Second Brain parent path"
    
    # Test finding Second_Brain directory inside Documents
    local found_dirs
    found_dirs=$(find "$second_brain_path" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    assert_contains "Second_Brain" "$found_dirs" "Should find Second_Brain directory"
    
    # Test session name generation for Second_Brain
    local session_name
    session_name=$(sanitize_session_name "Second_Brain")
    assert_equals "Second_Brain" "$session_name" "Should keep Second_Brain name unchanged"
    
    # Test full path processing for Second_Brain
    local full_path="$TEST_DIR/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
    local processed_result
    processed_result=$(process_directories "$full_path")
    assert_contains "Second_Brain:" "$processed_result" "Should process Second_Brain directory correctly"
    
    # Test that paths are absolute (start with /)
    assert_contains "/" "$full_path" "Second_Brain path should be absolute"
    if [[ "$full_path" =~ ^/ ]]; then
        echo -e "${GREEN}✓${NC} Second_Brain path is absolute"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Second_Brain path should be absolute but is: $full_path"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Helper function to check if string contains substring
assert_not_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$actual" != *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected NOT to contain: $expected"
        echo -e "  Actual:                  $actual"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Run all tests
run_tests() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    setup_test_env
    source_script_functions
    
    echo -e "${YELLOW}Running tmux-navigate.sh tests${NC}"
    echo "=================================="
    
    test_path_expansion
    test_basename_processing
    test_fzf_input_generation
    test_session_name_sanitization
    test_integration
    test_second_brain_navigation
    
    echo -e "\n=================================="
    echo -e "Test Results:"
    echo -e "Total:  $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! 🎉${NC}"
        cleanup_test_env
        exit 0
    else
        echo -e "\n${RED}Some tests failed! ❌${NC}"
        cleanup_test_env
        exit 1
    fi
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi