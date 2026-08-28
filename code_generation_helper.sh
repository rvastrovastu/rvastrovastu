#!/bin/bash

# ============================================================================
# RV ASTRO VASTU - CODE GENERATION HELPER SCRIPT
# ============================================================================
# Purpose: Automate code generation for Freezed, JSON serialization, and localizations
# Usage: bash code_generation_helper.sh [option]
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}\n"
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

# Show menu if no argument provided
if [ $# -eq 0 ]; then
    print_header "Code Generation Helper"
    echo "Choose an option:"
    echo ""
    echo "  1) Full Code Generation (all generators)"
    echo "  2) Freezed Models Only"
    echo "  3) JSON Serialization Only"
    echo "  4) Localizations Only"
    echo "  5) Watch Mode (auto-regenerate on changes)"
    echo "  6) Clean Generated Files"
    echo "  7) Verify Generation Status"
    echo "  8) Exit"
    echo ""
    read -p "Enter your choice (1-8): " choice
else
    choice=$1
fi

case $choice in
    1)
        print_header "Full Code Generation"
        print_info "Generating all code (Freezed, JSON, Localizations)..."
        
        flutter pub get
        flutter pub run build_runner build --delete-conflicting-outputs
        flutter gen-l10n
        
        print_success "Code generation completed!"
        print_info "Generated files:"
        print_info "  - *.freezed.dart (Freezed models)"
        print_info "  - *.g.dart (JSON serialization)"
        print_info "  - app_localizations_*.dart (Localizations)"
        ;;
        
    2)
        print_header "Freezed Models Generation"
        print_info "Generating Freezed models only..."
        
        flutter pub run build_runner build --build-filter="**.freezed.dart" --delete-conflicting-outputs
        
        print_success "Freezed models generated!"
        find lib -name "*.freezed.dart" -type f | head -5
        ;;
        
    3)
        print_header "JSON Serialization Generation"
        print_info "Generating JSON serialization files only..."
        
        flutter pub run build_runner build --build-filter="**.g.dart" --delete-conflicting-outputs
        
        print_success "JSON serialization files generated!"
        find lib -name "*.g.dart" -type f | head -5
        ;;
        
    4)
        print_header "Localizations Generation"
        print_info "Generating localization files..."
        
        flutter pub get
        flutter gen-l10n
        
        print_success "Localizations generated!"
        print_info "Generated files in lib/app_localizations.dart"
        ls -lh lib/app_localizations*.dart 2>/dev/null || echo "No localization files found"
        ;;
        
    5)
        print_header "Watch Mode - Auto Regenerate"
        print_info "Starting build_runner in watch mode..."
        print_info "Press Ctrl+C to stop watching"
        print_info ""
        
        flutter pub run build_runner watch --delete-conflicting-outputs
        ;;
        
    6)
        print_header "Clean Generated Files"
        print_info "Cleaning all generated code files..."
        
        # Clean generated files
        find lib -name "*.freezed.dart" -delete
        find lib -name "*.g.dart" -delete
        find lib -name "app_localizations*.dart" -delete
        rm -rf lib/app_localizations
        
        # Clean build_runner cache
        flutter pub run build_runner clean
        
        print_success "Generated files cleaned!"
        ;;
        
    7)
        print_header "Generation Status Check"
        print_info "Checking for missing generated files...\n"
        
        # Count generated files
        freezed_count=$(find lib -name "*.freezed.dart" -type f 2>/dev/null | wc -l)
        json_count=$(find lib -name "*.g.dart" -type f 2>/dev/null | wc -l)
        l10n_count=$(find lib -name "app_localizations*.dart" -type f 2>/dev/null | wc -l)
        
        echo "Generated Files Summary:"
        echo "  Freezed models (.freezed.dart): $freezed_count files"
        echo "  JSON serialization (.g.dart): $json_count files"
        echo "  Localizations (app_localizations*.dart): $l10n_count files"
        echo ""
        
        # Check for model files without generated files
        echo "Models without Freezed files:"
        for file in lib/**/*.dart; do
            if grep -q "@freezed" "$file" 2>/dev/null; then
                base="${file%.dart}"
                if [ ! -f "${base}.freezed.dart" ]; then
                    print_error "  Missing: ${base}.freezed.dart"
                fi
            fi
        done
        
        # Check for models without JSON serialization
        echo ""
        echo "Models without JSON serialization (.g.dart):"
        for file in lib/**/*.dart; do
            if grep -q "@JsonSerializable" "$file" 2>/dev/null; then
                base="${file%.dart}"
                if [ ! -f "${base}.g.dart" ]; then
                    print_error "  Missing: ${base}.g.dart"
                fi
            fi
        done
        
        print_info "Generation status check completed!"
        ;;
        
    8)
        print_info "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid option. Please choose 1-8."
        exit 1
        ;;
esac

print_success "Code generation helper completed!"
exit 0
