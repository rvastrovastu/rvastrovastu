#!/bin/bash

# ============================================================================
# SIMPLE FIX FOR DASHA WIDGET SYNTAX ERRORS
# ============================================================================
# Copy this and run from your project root:
# bash SIMPLE_FIX.sh
# ============================================================================

cd /Users/riteshvyas/Projects/rv_astro_vastu

echo "🔧 Fixing dasha_summary_card.dart..."

# Fix the extra parentheses in dasha_summary_card.dart
# Line 187: context.l10n.planetName(period.planet.name)).substring
#       →  context.l10n.planetName(period.planet.name).substring
sed -i '' "s/planetName(period\.planet\.name))\.substring/planetName(period.planet.name).substring/g" \
  lib/features/dasha/presentation/widgets/dasha_summary_card.dart

# Line 199: context.l10n.planetName(period.planet.name)),
#       →  context.l10n.planetName(period.planet.name),
sed -i '' 's/planetName(period\.planet\.name))\,$/planetName(period.planet.name),/g' \
  lib/features/dasha/presentation/widgets/dasha_summary_card.dart

# Line 255: Same fix as above
sed -i '' 's/planetName(period\.planet\.name))\,$/planetName(period.planet.name),/g' \
  lib/features/dasha/presentation/widgets/dasha_summary_card.dart

echo "✓ dasha_summary_card.dart fixed"

echo "🔧 Fixing antardasha_timeline.dart..."

# Fix line 165: Remove extra } in string interpolation
sed -i '' 's/planetName(period\.planet\.name))}/planetName(period.planet.name)}/g' \
  lib/features/dasha/presentation/widgets/antardasha_timeline.dart

# Fix line 321: Remove extra ) in planetName call
sed -i '' 's/planetName(period\.planet\.name))\,$/planetName(period.planet.name),/g' \
  lib/features/dasha/presentation/widgets/antardasha_timeline.dart

echo "✓ antardasha_timeline.dart fixed"

# Clean and rebuild
echo ""
echo "🧹 Cleaning build..."
flutter clean
rm -rf .dart_tool build pubspec.lock

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "✅ All fixed! Run: flutter run"
