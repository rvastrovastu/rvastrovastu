import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChartStyle { north, south }

/// The user's preferred chart layout, remembered across launches.
final chartStyleProvider = NotifierProvider<ChartStyleNotifier, ChartStyle>(
  ChartStyleNotifier.new,
);

class ChartStyleNotifier extends Notifier<ChartStyle> {
  static const String _key = 'chart_style';

  @override
  ChartStyle build() {
    _load();
    return ChartStyle.north;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == ChartStyle.south.name) state = ChartStyle.south;
    } catch (error) {
      debugPrint('[CHART STYLE] load failed: $error');
    }
  }

  Future<void> set(ChartStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, style.name);
    } catch (error) {
      debugPrint('[CHART STYLE] save failed: $error');
    }
  }
}
