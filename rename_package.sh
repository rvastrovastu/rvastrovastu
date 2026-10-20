#!/bin/bash
# Run from: ~/AndroidStudioProjects/PlanBhAI
set -e

OLD_PATH="app/src/main/java/com/example/planbhai"
NEW_PATH="app/src/main/java/com/planbhai/app"

if [ ! -d "$OLD_PATH" ]; then
  echo "ABORT: $OLD_PATH not found. Are you in the right directory?"
  exit 1
fi

echo "Creating new package directory structure..."
mkdir -p "$NEW_PATH"

echo "Moving files..."
# Move everything from old location to new (preserves subdirectories like ui/theme)
mv "$OLD_PATH"/* "$NEW_PATH"/

echo "Removing old, now-empty directory tree..."
rmdir "app/src/main/java/com/example/planbhai" 2>/dev/null || true
rmdir "app/src/main/java/com/example" 2>/dev/null || true

echo "Updating package declarations in all .kt files..."
find "$NEW_PATH" -name "*.kt" -exec sed -i '' 's/com\.example\.planbhai/com.planbhai.app/g' {} \;

echo "Updating androidTest and test source sets too..."
if [ -d "app/src/androidTest/java/com/example/planbhai" ]; then
  mkdir -p "app/src/androidTest/java/com/planbhai/app"
  mv app/src/androidTest/java/com/example/planbhai/* app/src/androidTest/java/com/planbhai/app/
  rmdir app/src/androidTest/java/com/example/planbhai 2>/dev/null || true
  rmdir app/src/androidTest/java/com/example 2>/dev/null || true
  find app/src/androidTest/java/com/planbhai/app -name "*.kt" -exec sed -i '' 's/com\.example\.planbhai/com.planbhai.app/g' {} \;
fi

if [ -d "app/src/test/java/com/example/planbhai" ]; then
  mkdir -p "app/src/test/java/com/planbhai/app"
  mv app/src/test/java/com/example/planbhai/* app/src/test/java/com/planbhai/app/
  rmdir app/src/test/java/com/example/planbhai 2>/dev/null || true
  rmdir app/src/test/java/com/example 2>/dev/null || true
  find app/src/test/java/com/planbhai/app -name "*.kt" -exec sed -i '' 's/com\.example\.planbhai/com.planbhai.app/g' {} \;
fi

echo "Updating build.gradle.kts..."
sed -i '' 's/com\.example\.planbhai/com.planbhai.app/g' app/build.gradle.kts

echo ""
echo "OK: package renamed to com.planbhai.app"
echo "Verify with: find . -name '*.kt' -o -name 'build.gradle*' | grep -v node_modules"
