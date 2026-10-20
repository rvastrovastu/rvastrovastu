#!/bin/bash

# ============================================================================
# RV ASTRO VASTU - BUILD HELPER SCRIPT
# ============================================================================
# Purpose: Build the app for different platforms (Android, iOS, Web, Desktop)
# Usage: bash build_helper.sh [platform] [mode]
# Example: bash build_helper.sh android release
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

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Run this script from project root."
    exit 1
fi

# Default values
PLATFORM=""
MODE="debug"
SHOULD_CLEAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        android|ios|web|macos|windows|linux)
            PLATFORM=$1
            shift
            ;;
        debug|profile|release)
            MODE=$1
            shift
            ;;
        --clean)
            SHOULD_CLEAN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [platform] [mode] [options]"
            echo ""
            echo "Platforms:"
            echo "  android    - Build Android APK or App Bundle"
            echo "  ios        - Build iOS app"
            echo "  web        - Build web app"
            echo "  macos      - Build macOS app"
            echo "  windows    - Build Windows app"
            echo "  linux      - Build Linux app"
            echo ""
            echo "Modes:"
            echo "  debug      - Debug build (default)"
            echo "  profile    - Profile build (optimized)"
            echo "  release    - Release build (fully optimized)"
            echo ""
            echo "Options:"
            echo "  --clean    - Clean before building"
            echo "  --help     - Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Show menu if no platform specified
if [ -z "$PLATFORM" ]; then
    print_header "Build Helper - Choose Platform"
    echo "Available platforms:"
    echo "  1) Android (APK)"
    echo "  2) Android (App Bundle)"
    echo "  3) iOS"
    echo "  4) Web"
    echo "  5) macOS"
    echo "  6) Windows"
    echo "  7) Linux"
    echo "  8) All Platforms"
    echo "  9) Exit"
    echo ""
    read -p "Enter platform (1-9): " platform_choice
    
    case $platform_choice in
        1) PLATFORM="android"; ANDROID_PACKAGE_TYPE="apk" ;;
        2) PLATFORM="android"; ANDROID_PACKAGE_TYPE="bundle" ;;
        3) PLATFORM="ios" ;;
        4) PLATFORM="web" ;;
        5) PLATFORM="macos" ;;
        6) PLATFORM="windows" ;;
        7) PLATFORM="linux" ;;
        8) PLATFORM="all" ;;
        9) exit 0 ;;
        *) print_error "Invalid option"; exit 1 ;;
    esac
    
    # Ask for build mode
    echo ""
    read -p "Build mode (debug/profile/release) [default: debug]: " mode_input
    if [ ! -z "$mode_input" ]; then
        MODE=$mode_input
    fi
fi

# Validate mode
if [[ ! "$MODE" =~ ^(debug|profile|release)$ ]]; then
    print_error "Invalid mode: $MODE. Use debug, profile, or release."
    exit 1
fi

# ============================================================================
# PRE-BUILD CHECKS
# ============================================================================
print_header "Pre-Build Checks"

print_info "Flutter version:"
flutter --version | head -1

print_info "Checking project structure..."
flutter doctor -v | head -20

# ============================================================================
# PREPARE BUILD
# ============================================================================
if [ "$SHOULD_CLEAN" = true ]; then
    print_header "Cleaning Project"
    flutter clean
    print_success "Project cleaned"
fi

print_header "Preparing Dependencies"
flutter pub get
print_success "Dependencies ready"

# ============================================================================
# ANDROID BUILD
# ============================================================================
build_android() {
    print_header "Building Android"
    
    if [ "$ANDROID_PACKAGE_TYPE" = "bundle" ]; then
        print_info "Building App Bundle (for Play Store)..."
        flutter build appbundle --$MODE
        print_success "App Bundle built successfully!"
        print_info "Output: build/app/outputs/bundle/${MODE}_release/app-${MODE}_release.aab"
    else
        print_info "Building APK..."
        flutter build apk --$MODE --split-per-abi
        print_success "APK built successfully!"
        print_info "Output: build/app/outputs/apk/${MODE}/"
        ls -lh build/app/outputs/apk/${MODE}/*.apk
    fi
}

# ============================================================================
# iOS BUILD
# ============================================================================
build_ios() {
    print_header "Building iOS"
    
    # Check if on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "iOS build requires macOS. You are on $OSTYPE"
        return 1
    fi
    
    print_info "Updating iOS pods..."
    cd ios
    pod install || pod repo update && pod install
    cd ..
    
    print_info "Building iOS app..."
    flutter build ios --$MODE --no-codesign
    
    print_success "iOS app built successfully!"
    print_info "Output: build/ios/iphoneos/"
    print_warning "Note: Still needs code signing for distribution"
}

# ============================================================================
# WEB BUILD
# ============================================================================
build_web() {
    print_header "Building Web"
    
    print_info "Building web app..."
    flutter build web --$MODE --web-renderer=auto
    
    print_success "Web app built successfully!"
    print_info "Output: build/web/"
    print_info "To serve locally: python -m http.server 8080 --directory build/web"
}

# ============================================================================
# macOS BUILD
# ============================================================================
build_macos() {
    print_header "Building macOS"
    
    # Check if on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "macOS build requires macOS. You are on $OSTYPE"
        return 1
    fi
    
    print_info "Building macOS app..."
    flutter build macos --$MODE
    
    print_success "macOS app built successfully!"
    print_info "Output: build/macos/Build/Products/${MODE}/RvAstroVastu.app"
}

# ============================================================================
# WINDOWS BUILD
# ============================================================================
build_windows() {
    print_header "Building Windows"
    
    # Check if on Windows or has Visual Studio
    print_info "Building Windows app..."
    flutter build windows --$MODE
    
    print_success "Windows app built successfully!"
    print_info "Output: build/windows/runner/${MODE}/"
}

# ============================================================================
# LINUX BUILD
# ============================================================================
build_linux() {
    print_header "Building Linux"
    
    print_info "Building Linux app..."
    flutter build linux --$MODE
    
    print_success "Linux app built successfully!"
    print_info "Output: build/linux/x64/release/bundle/"
}

# ============================================================================
# EXECUTE BUILDS
# ============================================================================
print_header "Starting Build Process"
print_info "Platform: $PLATFORM"
print_info "Mode: $MODE"

case $PLATFORM in
    android)
        build_android || print_error "Android build failed"
        ;;
    ios)
        build_ios || print_error "iOS build failed"
        ;;
    web)
        build_web || print_error "Web build failed"
        ;;
    macos)
        build_macos || print_error "macOS build failed"
        ;;
    windows)
        build_windows || print_error "Windows build failed"
        ;;
    linux)
        build_linux || print_error "Linux build failed"
        ;;
    all)
        print_header "Building All Platforms"
        
        # Android
        print_info "Building Android..."
        build_android || print_warning "Android build skipped"
        
        # Web
        print_info "Building Web..."
        build_web || print_warning "Web build skipped"
        
        # macOS (only on macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Building iOS..."
            build_ios || print_warning "iOS build skipped"
            
            print_info "Building macOS..."
            build_macos || print_warning "macOS build skipped"
        fi
        
        # Windows (only on Windows)
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            print_info "Building Windows..."
            build_windows || print_warning "Windows build skipped"
        fi
        
        # Linux
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_info "Building Linux..."
            build_linux || print_warning "Linux build skipped"
        fi
        ;;
    *)
        print_error "Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

# ============================================================================
# POST-BUILD INFO
# ============================================================================
print_header "Build Complete"

echo -e "${GREEN}Build Summary:${NC}"
echo "  Platform: $PLATFORM"
echo "  Mode: $MODE"
echo "  Timestamp: $(date)"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
case $PLATFORM in
    android)
        echo "  1. Test APK on device: adb install -r build/app/outputs/apk/release/app-release.apk"
        echo "  2. Upload bundle to Google Play Console"
        echo "  3. Run: flutter install"
        ;;
    ios)
        echo "  1. Sign the build with your developer certificate"
        echo "  2. Build IPA file using Xcode"
        echo "  3. Upload to App Store Connect"
        ;;
    web)
        echo "  1. Test locally: cd build/web && python -m http.server 8080"
        echo "  2. Deploy to hosting: Firebase, Netlify, or similar"
        echo "  3. Share URL: http://localhost:8080"
        ;;
    *)
        echo "  1. Test the application on your device"
        echo "  2. Verify all functionality works correctly"
        echo "  3. Deploy to respective app store"
        ;;
esac

echo ""
print_success "Build script completed!"

exit 0
