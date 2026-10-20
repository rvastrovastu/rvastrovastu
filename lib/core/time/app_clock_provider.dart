import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final appClockProvider = NotifierProvider<AppClockNotifier, DateTime>(
  AppClockNotifier.new,
);

class AppClockNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = DateTime.now();

    _scheduleNextRefresh(now);

    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    return now;
  }

  void refresh() {
    state = DateTime.now();
    _scheduleNextRefresh(state);
  }

  void _scheduleNextRefresh(DateTime now) {
    _timer?.cancel();

    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );

    final duration = nextMinute.difference(now);

    _timer = Timer(
      duration.isNegative || duration == Duration.zero
          ? const Duration(seconds: 1)
          : duration,
      refresh,
    );
  }
}
