#!/bin/bash

# Test script for dotfiles installation
# This script tests the installation on selected platforms in Docker containers

set -e

echo "🧪 Testing dotfiles installation on Arch Linux, Ubuntu, macOS, and Omarchy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run test in container
run_test() {
    local distro=$1
    local image=$2
    local package_manager=$3

    echo -e "\n${BLUE}Testing on $distro (${image})${NC}"

    # Create a temporary container and run the installation
    if docker run --rm \
        --name "dotfiles-test-${distro}" \
        -e DEBIAN_FRONTEND=noninteractive \
        "$image" \
        bash -c "
            echo '📦 Installing base dependencies...'
            case '$package_manager' in
                apt)
                    apt update && apt install -y curl git ansible python3 python3-pip
                    ;;
                dnf)
                    dnf install -y curl git ansible python3 python3-pip
                    ;;
                pacman)
                    pacman -Syu --noconfirm curl git ansible python python-pip
                    ;;
            esac

            echo '🔗 Downloading and running dotfiles installer...'
            if curl -fsSL https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/install-online.sh | bash -s -- --deps; then
                echo -e '${GREEN}✅ Dependencies installation successful${NC}'
            else
                echo -e '${RED}❌ Dependencies installation failed${NC}'
                exit 1
            fi
        "; then
        echo -e "${GREEN}✅ $distro test passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $distro test failed${NC}"
        return 1
    fi
}

# Test different distributions
echo "🚀 Starting compatibility tests..."

failed_tests=0
passed_tests=()
failed_tests_list=()
skipped_tests=()

# Arch Linux test
# Check if we're on ARM64 - Arch Linux Docker image doesn't support ARM64
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
    echo -e "${YELLOW}⚠️  Arch Linux Docker image not available for ARM64 architecture, skipping${NC}"
    echo "Arch Linux: SKIP (ARM64 not supported)"
    skipped_tests+=("Arch Linux (ARM64 not supported)")
else
    if docker image inspect archlinux:latest >/dev/null 2>&1; then
        echo "Arch Linux image found locally"
    else
        echo "Pulling Arch Linux image..."
        if docker pull archlinux:latest; then
            echo "Arch Linux image pulled successfully"
        else
            echo -e "${YELLOW}⚠️  Failed to pull Arch Linux image, skipping${NC}"
            echo "Arch Linux: SKIP"
            skipped_tests+=("Arch Linux (failed to pull image)")
        fi
    fi

    if docker image inspect archlinux:latest >/dev/null 2>&1; then
        if run_test "Arch Linux" "archlinux:latest" "pacman"; then
            echo "Arch Linux: PASS"
            passed_tests+=("Arch Linux")
        else
            echo "Arch Linux: FAIL"
            ((failed_tests++))
            failed_tests_list+=("Arch Linux")
        fi
    else
        echo "Arch Linux: SKIP"
        skipped_tests+=("Arch Linux (image not available)")
    fi
fi

# Ubuntu test
if run_test "Ubuntu" "ubuntu:22.04" "apt"; then
    echo "Ubuntu: PASS"
    passed_tests+=("Ubuntu")
else
    echo "Ubuntu: FAIL"
    ((failed_tests++))
    failed_tests_list+=("Ubuntu")
fi

# macOS test
echo -e "\n${YELLOW}⚠️  macOS testing in Docker not supported (macOS doesn't run natively in containers)${NC}"
echo "macOS: SKIP (Docker limitation)"
skipped_tests+=("macOS (Docker limitation)")

# Omarchy test (Arch-based Linux distro by DHH)
echo -e "\n${BLUE}Testing on Omarchy${NC}"
if docker image inspect omarchy:latest >/dev/null 2>&1; then
    if run_test "Omarchy" "omarchy:latest" "pacman"; then
        echo "Omarchy: PASS"
        passed_tests+=("Omarchy")
    else
        echo "Omarchy: FAIL"
        ((failed_tests++))
        failed_tests_list+=("Omarchy")
    fi
else
    echo -e "${YELLOW}⚠️  Omarchy Docker image not available, skipping${NC}"
    echo "Omarchy: SKIP (Docker image not available)"
    skipped_tests+=("Omarchy (Docker image not available)")
fi

# Summary
echo -e "\n${BLUE}Test Summary:${NC}"

# Display recap of all tests
echo -e "\n${BLUE}📋 Test Results Recap:${NC}"

if [ ${#passed_tests[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Passed:${NC}"
    for test in "${passed_tests[@]}"; do
        echo -e "   • $test"
    done
fi

if [ ${#failed_tests_list[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed:${NC}"
    for test in "${failed_tests_list[@]}"; do
        echo -e "   • $test"
    done
fi

if [ ${#skipped_tests[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Skipped:${NC}"
    for test in "${skipped_tests[@]}"; do
        echo -e "   • $test"
    done
fi

if [ $failed_tests -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Compatibility looks good.${NC}"
    echo -e "${GREEN}Your dotfiles should work on the tested platforms.${NC}"
else
    echo -e "\n${RED}❌ $failed_tests test(s) failed. Please check the output above.${NC}"
    exit 1
fi

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Test the full installation (not just dependencies) in real environments"
echo "2. Verify that all your tools and configurations work as expected"
echo "3. For macOS testing, run the installer natively on a macOS system"