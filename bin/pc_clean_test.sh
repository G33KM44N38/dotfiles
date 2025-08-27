#!/bin/bash

# Unit tests for clean_uninstalled_app_data function from pc_clean

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Test counters
tests_run=0
tests_passed=0

# Test helper functions
assert() {
    local message="$1"
    local expected="$2"
    local actual="$3"
    ((tests_run++))
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${RESET} $message"
        ((tests_passed++))
    else
        echo -e "${RED}✗ FAIL${RESET} $message"
        echo -e "  Expected: $expected"
        echo -e "  Actual: $actual"
    fi
}

# Modified version of the function for testing
clean_uninstalled_app_data_test() {
    local app_support_dir="$1"
    local app_locations=("$2" "$3")

    # Loop through each folder in Application Support
    find "$app_support_dir" -mindepth 1 -maxdepth 1 -type d | while read -r app_folder; do
        local app_name=$(basename "$app_folder")
        local app_found=false

        # Check if app exists in the common Applications folders
        for loc in "${app_locations[@]}"; do
            if [ -d "$loc/$app_name.app" ]; then
                app_found=true
                break
            fi
        done

        # If not found, delete the app data folder
        if [ "$app_found" = false ]; then
            rm -rf "$app_folder"
        fi
    done
}

# Test setup
setup_test_dirs() {
    # Create temporary directories
    test_app_support=$(mktemp -d)
    test_system_apps=$(mktemp -d)
    test_user_apps=$(mktemp -d)

    # Create mock app data folders
    mkdir -p "$test_app_support/InstalledApp"
    mkdir -p "$test_app_support/UninstalledApp"
    mkdir -p "$test_app_support/App With Spaces"
    mkdir -p "$test_app_support/AnotherUninstalled"

    # Create mock installed apps
    mkdir -p "$test_system_apps/InstalledApp.app"
    mkdir -p "$test_system_apps/App With Spaces.app"
    # Note: UninstalledApp and AnotherUninstalled are not installed
}

# Cleanup test directories
cleanup_test_dirs() {
    rm -rf "$test_app_support" "$test_system_apps" "$test_user_apps"
}

# Run tests
run_tests() {
    echo "Running unit tests for app detection logic..."
    echo

    setup_test_dirs

    # Run the function
    clean_uninstalled_app_data_test "$test_app_support" "$test_system_apps" "$test_user_apps"

    # Test 1: Installed app data should not be removed
    if [ -d "$test_app_support/InstalledApp" ]; then
        assert "Installed app data should not be removed" "kept" "kept"
    else
        assert "Installed app data should not be removed" "kept" "removed"
    fi

    # Test 2: Uninstalled app data should be removed
    if [ ! -d "$test_app_support/UninstalledApp" ]; then
        assert "Uninstalled app data should be removed" "removed" "removed"
    else
        assert "Uninstalled app data should be removed" "removed" "not_removed"
    fi

    # Test 3: App with spaces data should not be removed
    if [ -d "$test_app_support/App With Spaces" ]; then
        assert "App with spaces data should not be removed" "kept" "kept"
    else
        assert "App with spaces data should not be removed" "kept" "removed"
    fi

    # Test 4: Another uninstalled app data should be removed
    if [ ! -d "$test_app_support/AnotherUninstalled" ]; then
        assert "Another uninstalled app data should be removed" "removed" "removed"
    else
        assert "Another uninstalled app data should be removed" "removed" "not_removed"
    fi

    cleanup_test_dirs

    echo
    echo "Tests completed: $tests_passed/$tests_run passed"
}

# Run the tests
run_tests