import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:swisseph/swisseph.dart';
import 'package:rv_astro_vastu/core/telemetry/telemetry.dart';

/// Where the web build serves the package's WebAssembly module
/// (swisseph.js + swisseph.wasm), relative to the app's base href. Null is
/// the package default, `swisseph` next to index.html, which is where
/// tools/build_web.sh puts both files; the others are fallbacks.
@visibleForTesting
const webEphemerisPaths = <String?>[null, 'swisseph', 'assets/swisseph'];

/// Opens the bundled Swiss Ephemeris library for this platform. Callers
/// close it when done.
///
/// On the web this is the package's WebAssembly build, which uses the
/// Moshier ephemeris, the same as the phone builds (no .se1 files are
/// bundled), so charts match across platforms.
Future<SwissEph> loadSwissEph() async {
  if (kIsWeb) return _loadWeb();
  if (Platform.isIOS) {
    final appDirectory = File(Platform.resolvedExecutable).parent;
    final framework =
        '${appDirectory.path}/Frameworks/swisseph.framework/swisseph';
    if (File(framework).existsSync()) return SwissEph(framework);
    throw StateError('Swiss Ephemeris framework not found at: $framework');
  }
  if (Platform.isMacOS) {
    final contents = File(Platform.resolvedExecutable).parent.parent;
    final framework = '${contents.path}/Frameworks/swisseph.framework/swisseph';
    if (File(framework).existsSync()) return SwissEph(framework);
  }
  // Android: Flutter bundles the library inside the app as
  // libswisseph.so, which opens by name.
  if (Platform.isAndroid) {
    try {
      return SwissEph('libswisseph.so');
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'ephemeris_android_load');
    }
  }
  return SwissEph.load();
}

/// The path that worked last time, so later loads skip the misses.
String? _webPath;
bool _webPathKnown = false;

Future<SwissEph> _loadWeb() async {
  if (_webPathKnown) return _open(_webPath);
  Object? lastError;
  StackTrace? lastStack;
  for (final path in webEphemerisPaths) {
    try {
      final swe = await _open(path);
      _webPath = path;
      _webPathKnown = true;
      return swe;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
      debugPrint('[EPHEMERIS] web load failed for ${path ?? 'default'}: $error');
    }
  }
  Telemetry.recordError(lastError!, lastStack, reason: 'ephemeris_web_load');
  throw StateError('Swiss Ephemeris WebAssembly module not found: $lastError');
}

/// [SwissEph.load] with the package's default location when [path] is null.
Future<SwissEph> _open(String? path) =>
    path == null ? SwissEph.load() : SwissEph.load(path);
