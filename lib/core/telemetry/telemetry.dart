import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reports and product events, sent to Firebase.
///
/// Every call is safe without Firebase: before `flutterfire configure` has
/// added the project files, or in tests, [init] finds no project and all
/// other calls do nothing. Events never carry birth details, names, places,
/// questions or contact details, only what happened and coarse values.
class Telemetry {
  Telemetry._();

  static bool _ready = false;

  /// Starts Firebase. Crash collection is on only in release builds, so
  /// development crashes don't mix with real ones.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode,
      );
      _ready = true;
    } catch (error) {
      debugPrint('Telemetry off: $error');
    }
  }

  /// Sends Flutter framework errors and uncaught async errors to
  /// Crashlytics. Call once, after [init].
  static void captureUncaughtErrors() {
    if (!_ready) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Records a handled error, for failures the app recovers from but that
  /// should not stay invisible (a calculation that fell back, a sync that
  /// failed). [reason] says where it happened.
  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    if (!_ready) return;
    FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false)
        .catchError((Object _) {});
  }

  /// Logs a product event, such as `booking_paid`. Values must be short,
  /// non-personal strings or numbers.
  static void event(String name, [Map<String, Object>? parameters]) {
    if (!_ready) return;
    FirebaseAnalytics.instance
        .logEvent(name: name, parameters: parameters)
        .catchError((Object _) {});
  }
}
