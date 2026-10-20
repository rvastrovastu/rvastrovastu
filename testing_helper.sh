#!/bin/bash

# ============================================================================
# RV ASTRO VASTU - TESTING HELPER SCRIPT
# ============================================================================
# Purpose: Run tests, generate coverage reports, and manage test configuration
# Usage: bash testing_helper.sh [option]
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if tests directory exists
if [ ! -d "test" ]; then
    print_warning "No test/ directory found"
    read -p "Do you want to create one? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p test
        print_success "test/ directory created"
    fi
fi

# Show menu if no argument provided
if [ $# -eq 0 ]; then
    print_header "Testing Helper"
    echo "Choose an option:"
    echo ""
    echo "  1) Run All Tests"
    echo "  2) Run Tests with Coverage"
    echo "  3) Run Specific Test File"
    echo "  4) Run Tests in Verbose Mode"
    echo "  5) Watch Tests (auto-run on changes)"
    echo "  6) Generate Coverage Report (HTML)"
    echo "  7) Run Tests with Timeout"
    echo "  8) Generate Test Summary"
    echo "  9) View Coverage Report"
    echo "  10) Setup Pre-commit Hook"
    echo "  11) Exit"
    echo ""
    read -p "Enter your choice (1-11): " choice
else
    choice=$1
fi

case $choice in
    1)
        print_header "Running All Tests"
        flutter test
        print_success "All tests completed"
        ;;
        
    2)
        print_header "Running Tests with Coverage"
        
        print_info "Running tests and generating coverage data..."
        flutter test --coverage
        
        print_success "Coverage data generated"
        print_info "Coverage file: coverage/lcov.info"
        
        # Check if lcov is installed
        if command -v genhtml &> /dev/null; then
            print_info "Generating HTML coverage report..."
            genhtml coverage/lcov.info -o coverage/html
            print_success "HTML report generated: coverage/html/index.html"
        else
            print_warning "lcov not installed. Cannot generate HTML report."
            print_info "Install with: brew install lcov (macOS) or apt install lcov (Linux)"
        fi
        ;;
        
    3)
        print_header "Running Specific Test File"
        echo ""
        echo "Available test files:"
        find test -name "*_test.dart" -type f | head -10
        echo ""
        read -p "Enter test file path (from test directory): " test_file
        
        if [ ! -f "test/$test_file" ] && [ ! -f "$test_file" ]; then
            print_error "Test file not found: $test_file"
            exit 1
        fi
        
        flutter test "$test_file"
        ;;
        
    4)
        print_header "Running Tests in Verbose Mode"
        flutter test --verbose
        print_success "Verbose test run completed"
        ;;
        
    5)
        print_header "Watch Mode - Auto-run Tests"
        print_info "Starting watch mode for tests..."
        print_info "Tests will re-run when files change"
        print_info "Press Ctrl+C to stop"
        print_info ""
        
        flutter test --watch
        ;;
        
    6)
        print_header "Generate Coverage Report"
        
        # Check if coverage directory exists
        if [ ! -d "coverage" ]; then
            print_info "No coverage data found. Running tests with coverage..."
            flutter test --coverage
        fi
        
        # Generate HTML report
        if command -v genhtml &> /dev/null; then
            print_info "Generating HTML coverage report..."
            genhtml coverage/lcov.info -o coverage/html --quiet
            print_success "HTML report generated"
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                open coverage/html/index.html
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                xdg-open coverage/html/index.html &
            else
                start coverage/html/index.html
            fi
        else
            print_error "lcov not found. Cannot generate HTML report."
            print_info "Install: brew install lcov (macOS) or sudo apt install lcov (Linux)"
        fi
        ;;
        
    7)
        print_header "Running Tests with Timeout"
        
        read -p "Enter timeout in seconds (default: 30): " timeout
        timeout=${timeout:-30}
        
        print_info "Running tests with ${timeout}s timeout per test..."
        flutter test --timeout="${timeout}s"
        ;;
        
    8)
        print_header "Generate Test Summary"
        
        print_info "Analyzing test files..."
        echo ""
        
        # Count test files
        test_file_count=$(find test -name "*_test.dart" -type f | wc -l)
        print_info "Total test files: $test_file_count"
        echo ""
        
        print_info "Test files found:"
        find test -name "*_test.dart" -type f | sort
        echo ""
        
        # Count test cases (approximate)
        print_info "Approximate test count:"
        test_count=$(grep -r "test(" test/ 2>/dev/null | wc -l)
        testwidget_count=$(grep -r "testWidgets(" test/ 2>/dev/null | wc -l)
        
        echo "  Unit Tests: $test_count"
        echo "  Widget Tests: $testwidget_count"
        echo "  Total: $((test_count + testwidget_count))"
        echo ""
        
        # File structure summary
        print_info "Test coverage by module:"
        for dir in test/*/; do
            if [ "$(ls -A "$dir")" ]; then
                count=$(find "$dir" -name "*_test.dart" -type f | wc -l)
                module=$(basename "$dir")
                echo "  $module: $count test files"
            fi
        done
        ;;
        
    9)
        print_header "View Coverage Report"
        
        if [ ! -d "coverage/html" ]; then
            print_error "Coverage report not found. Generate one first."
            print_info "Run: bash testing_helper.sh 6"
            exit 1
        fi
        
        print_info "Opening coverage report..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open coverage/html/index.html
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open coverage/html/index.html &
        else
            start coverage/html/index.html
        fi
        ;;
        
    10)
        print_header "Setup Pre-commit Hook"
        
        # Create pre-commit hook
        hook_content='#!/bin/bash
set -e

echo "Running pre-commit checks..."
echo ""

# Run analyzer
echo "Running code analysis..."
flutter analyze
if [ $? -ne 0 ]; then
  echo "✗ Analysis failed. Commit aborted."
  exit 1
fi
echo "✓ Code analysis passed"

# Format code
echo "Formatting code..."
dart format lib/ test/ --set-exit-if-changed
if [ $? -ne 0 ]; then
  echo "Code has been formatted. Please stage and try again."
  exit 1
fi

# Run tests
echo "Running tests..."
flutter test
if [ $? -ne 0 ]; then
  echo "✗ Tests failed. Commit aborted."
  exit 1
fi

echo "✓ All pre-commit checks passed!"
exit 0
'
        
        # Create hooks directory if it doesn't exist
        mkdir -p .git/hooks
        
        # Write pre-commit hook
        echo "$hook_content" > .git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit
        
        print_success "Pre-commit hook installed"
        print_info "Hook will run:"
        print_info "  - Code analysis (flutter analyze)"
        print_info "  - Code formatting (dart format)"
        print_info "  - Tests (flutter test)"
        print_info ""
        print_warning "Note: This may slow down commits. You can bypass with: git commit --no-verify"
        ;;
        
    11)
        print_info "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid option. Please choose 1-11."
        exit 1
        ;;
esac

print_success "Testing helper completed!"
exit 0
