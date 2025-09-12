#!/usr/bin/env bash

# Test runner for tmux-navigate.sh
# Runs unit tests and provides a summary

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Running tmux-navigate.sh Test Suite${NC}"
echo "======================================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run unit tests
echo -e "\n${YELLOW}📋 Running Unit Tests...${NC}"
if "$SCRIPT_DIR/test-tmux-navigate.sh"; then
    echo -e "${GREEN}✅ Unit tests completed successfully${NC}"
    unit_success=true
else
    echo -e "${RED}❌ Unit tests failed${NC}"
    unit_success=false
fi

# Summary
echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="

if $unit_success; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "The tmux-navigate.sh script has been tested for:"
    echo "• Path expansion and validation"
    echo "• Directory basename conflict resolution" 
    echo "• FZF input generation"
    echo "• Session name sanitization"
    echo "• Integration scenarios"
    echo ""
    echo "🚀 Your script is ready to use!"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Please check the test output above for details."
    exit 1
fi