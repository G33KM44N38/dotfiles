#!/bin/bash

# Test script for Linux dotfiles installation
# This script tests the installation in Docker containers

set -e

echo "🧪 Testing dotfiles installation on Linux distributions"

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
            if curl -fsSL https://raw.githubusercontent.com/G33KM44N38/dotfiles/main/bin/dotfiles | bash -s -- --deps; then
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
echo "🚀 Starting Linux compatibility tests..."

failed_tests=0

# Ubuntu test
if run_test "Ubuntu" "ubuntu:22.04" "apt"; then
    echo "Ubuntu: PASS"
else
    echo "Ubuntu: FAIL"
    ((failed_tests++))
fi

# Fedora test
if run_test "Fedora" "fedora:38" "dnf"; then
    echo "Fedora: PASS"
else
    echo "Fedora: FAIL"
    ((failed_tests++))
fi

# Arch Linux test (if available)
if docker image inspect archlinux:latest >/dev/null 2>&1; then
    if run_test "Arch Linux" "archlinux:latest" "pacman"; then
        echo "Arch Linux: PASS"
    else
        echo "Arch Linux: FAIL"
        ((failed_tests++))
    fi
else
    echo -e "${YELLOW}⚠️  Arch Linux image not available, skipping${NC}"
fi

# Summary
echo -e "\n${BLUE}Test Summary:${NC}"
if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Linux compatibility looks good.${NC}"
    echo -e "${GREEN}Your dotfiles should now work on Linux systems.${NC}"
else
    echo -e "${RED}❌ $failed_tests test(s) failed. Please check the output above.${NC}"
    exit 1
fi

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Test the full installation (not just dependencies) in a real Linux environment"
echo "2. Verify that all your tools and configurations work as expected"
echo "3. Consider adding more Linux distributions to your test matrix"