#!/bin/bash

# ============================================================================
# RV ASTRO VASTU - PROJECT SETUP & UPDATE SCRIPT
# ============================================================================
# This script will set up, clean, update, and optimize your Flutter project
# Usage: bash setup_and_update_project.sh
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print with color
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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# 1. PROJECT SETUP & VERIFICATION
# ============================================================================
print_header "STEP 1: Verifying Project Setup"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the project root directory."
    exit 1
fi

print_success "Project structure verified"

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed. Please install Flutter first."
    exit 1
fi

print_success "Flutter SDK found"
flutter --version

# Check Dart installation
if ! command -v dart &> /dev/null; then
    print_error "Dart is not installed."
    exit 1
fi

print_success "Dart SDK found"

# ============================================================================
# 2. CLEAN UP UNNECESSARY FILES
# ============================================================================
print_header "STEP 2: Cleaning Up Project"

print_info "Removing build artifacts..."
flutter clean

print_info "Removing old lock file backups..."
rm -f pubspec.lock.bak 2>/dev/null || true

print_success "Project cleaned"

# ============================================================================
# 3. GET DEPENDENCIES
# ============================================================================
print_header "STEP 3: Getting Dependencies"

print_info "Fetching Flutter and Pub dependencies..."
flutter pub get

print_success "Dependencies installed"

# ============================================================================
# 4. CODE GENERATION
# ============================================================================
print_header "STEP 4: Generating Code"

print_info "Running build_runner for code generation..."
print_info "This includes Freezed models, JSON serialization, and localization..."

flutter pub run build_runner build --delete-conflicting-outputs

print_success "Code generation completed"

# ============================================================================
# 5. GENERATE LOCALIZATIONS
# ============================================================================
print_header "STEP 5: Regenerating Localizations"

print_info "Generating localization files from .arb files..."
flutter gen-l10n

print_success "Localizations generated"

# ============================================================================
# 6. CODE ANALYSIS & LINTING
# ============================================================================
print_header "STEP 6: Analyzing Code Quality"

print_info "Running Flutter analyzer..."
flutter analyze

print_success "Code analysis completed"

# ============================================================================
# 7. CODE FORMATTING
# ============================================================================
print_header "STEP 7: Formatting Code"

print_info "Formatting all Dart files in lib/ and test/..."
dart format lib/ test/ --set-exit-if-changed

print_success "Code formatting completed"

# ============================================================================
# 8. AUTO-FIX DART ISSUES
# ============================================================================
print_header "STEP 8: Applying Automatic Fixes"

print_info "Applying dart fix for common issues..."
dart fix --apply

print_success "Automatic fixes applied"

# ============================================================================
# 9. VERIFY PUBSPEC & DEPENDENCIES
# ============================================================================
print_header "STEP 9: Verifying Dependencies"

print_info "Checking for outdated packages..."
flutter pub outdated --no-dependency-trees

print_success "Dependency check completed"

# ============================================================================
# 10. SETUP ENVIRONMENT VARIABLES (if needed)
# ============================================================================
print_header "STEP 10: Checking Environment Configuration"

if [ ! -f ".env" ]; then
    print_warning ".env file not found"
    print_info "Creating .env file from template..."
    
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success ".env file created from template"
        print_warning "Please update .env with your Supabase credentials:"
        cat .env
    else
        print_warning "No .env.example file found. Please create .env manually."
    fi
else
    print_success ".env file exists"
fi

# ============================================================================
# 11. DOCTOR CHECK
# ============================================================================
print_header "STEP 11: Running Flutter Doctor"

print_info "Checking Flutter environment health..."
flutter doctor

# ============================================================================
# 12. OPTIONAL: RUN TESTS
# ============================================================================
print_header "STEP 12: Running Tests (Optional)"

if [ -d "test" ] && [ "$(ls -A test)" ]; then
    read -p "Do you want to run tests? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Running unit and widget tests..."
        flutter test
        print_success "Tests completed"
    fi
else
    print_warning "No tests found in test/ directory"
fi

# ============================================================================
# 13. PROJECT SUMMARY
# ============================================================================
print_header "Setup Summary"

print_success "All setup steps completed!"

echo -e "${BLUE}Project Information:${NC}"
echo "  Project Name: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
echo "  Version: $(grep '^version:' pubspec.yaml | cut -d' ' -f2)"
echo "  Flutter: $(flutter --version | head -1)"
echo "  Dart: $(dart --version 2>&1 | head -1)"

echo -e "\n${BLUE}Next Steps:${NC}"
echo "  1. Review and update .env file with your Supabase credentials"
echo "  2. Run 'flutter run' to test on a device/emulator"
echo "  3. Run 'flutter run -d chrome' to test on web"
echo "  4. Check lib/features/ for feature-specific implementation"
echo "  5. Review generated documentation in project root"

# ============================================================================
# 14. OPTIONAL: BUILD SETUP
# ============================================================================
print_header "Optional: Build Configuration"

echo -e "${BLUE}Available build commands:${NC}"
echo ""
echo "  Android (APK):"
echo "    flutter build apk --release"
echo ""
echo "  Android (App Bundle):"
echo "    flutter build appbundle --release"
echo ""
echo "  iOS:"
echo "    flutter build ios --release"
echo ""
echo "  Web:"
echo "    flutter build web --release"
echo ""
echo "  macOS:"
echo "    flutter build macos --release"
echo ""
echo "  Windows:"
echo "    flutter build windows --release"
echo ""
echo "  Linux:"
echo "    flutter build linux --release"
echo ""

# ============================================================================
# 15. FINAL RECOMMENDATIONS
# ============================================================================
print_header "Recommendations Based on Project Analysis"

echo -e "${BLUE}Based on the project structure analysis:${NC}\n"

print_info "1. Code Quality Improvements"
echo "   - Add comprehensive unit tests for services/"
echo "   - Add widget tests for presentation/ layers"
echo "   - Add integration tests for critical flows"
echo "   Command: flutter test --coverage"
echo ""

print_info "2. Security Review"
echo "   - Verify Supabase rules are properly configured"
echo "   - Review JWT token storage in secure storage"
echo "   - Audit API endpoints for security"
echo ""

print_info "3. Performance Optimization"
echo "   - Profile app: flutter run --profile"
echo "   - Check memory usage with DevTools"
echo "   - Optimize large lists with ListView.builder"
echo ""

print_info "4. Localization Completeness"
echo "   - Check untranslated_messages.json for missing translations"
echo "   - Add translations for all 11 languages"
echo "   - Run: grep -r 'untranslated' ."
echo ""

print_info "5. Documentation"
echo "   - Keep README.md updated with setup instructions"
echo "   - Document API endpoints and responses"
echo "   - Add architecture decision records (ADRs)"
echo ""

# ============================================================================
# 16. GIT STATUS
# ============================================================================
print_header "Git Status Check"

if [ -d ".git" ]; then
    echo -e "${BLUE}Current branch:${NC}"
    git branch --show-current
    
    echo -e "\n${BLUE}Recent commits:${NC}"
    git log --oneline -5
    
    echo -e "\n${BLUE}Uncommitted changes:${NC}"
    if [ -z "$(git status --porcelain)" ]; then
        print_success "Working directory is clean"
    else
        print_warning "Uncommitted changes detected:"
        git status --short
    fi
else
    print_warning "Not a git repository"
fi

print_success "Setup script completed successfully!"

# ============================================================================
# EXIT
# ============================================================================
exit 0
