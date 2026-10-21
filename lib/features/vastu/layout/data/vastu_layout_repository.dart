import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vastu_layout.dart';

/// Plan images live in the app's documents folder. Only the file name is
/// saved with a layout, because the folder's full path can change between
/// app updates on iOS.
class VastuImageStore {
  const VastuImageStore();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vastu_plans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Saves [bytes] for layout [id] and returns the new file name.
  Future<String> save(String id, Uint8List bytes, {String ext = 'jpg'}) async {
    final name = '${id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = File('${(await _dir()).path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<File?> file(String name) async {
    final file = File('${(await _dir()).path}/$name');
    return await file.exists() ? file : null;
  }

  Future<void> delete(String name) async {
    final file = await this.file(name);
    if (file != null) await file.delete();
  }
}

/// Saved house layouts, kept on this device.
class VastuLayoutRepository {
  static const _key = 'vastu_layouts';
  final VastuImageStore images;

  const VastuLayoutRepository({this.images = const VastuImageStore()});

  Future<List<VastuLayout>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          ?VastuLayout.fromJson(Map<String, dynamic>.from(item as Map)),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(List<VastuLayout> layouts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final l in layouts) l.toJson()]),
    );
  }

  Future<void> save(VastuLayout layout) async {
    final all = await loadAll();
    final previous = all.where((l) => l.id == layout.id).firstOrNull;
    if (previous?.imageFile case final old?
        when old != layout.imageFile) {
      await _deleteImage(old);
    }
    await _write([
      layout,
      for (final l in all)
        if (l.id != layout.id) l,
    ]);
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    for (final l in all) {
      if (l.id == id && l.imageFile != null) await _deleteImage(l.imageFile!);
    }
    await _write([
      for (final l in all)
        if (l.id != id) l,
    ]);
  }

  Future<void> _deleteImage(String name) async {
    try {
      await images.delete(name);
    } catch (_) {
      // A missing file is fine.
    }
  }
}

/// Which property each bought Vastu report is used for. Kept on this
/// device; purchases themselves come from the store, so a report bought
/// before a reinstall shows up again as an unused credit.
class VastuReportLedger {
  static const _key = 'vastu_report_assignments';

  const VastuReportLedger();

  Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<void> assign(String layoutId, String transactionId) async {
    final current = {...await load(), layoutId: transactionId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(current));
  }
}

/// A bought report not yet used for any property.
String? unusedReport(List<String> purchases, Map<String, String> assigned) {
  final used = assigned.values.toSet();
  for (final id in purchases) {
    if (!used.contains(id)) return id;
  }
  return null;
}

/// Whether [layoutId] has a report bought for it.
bool reportUnlocked(
  String layoutId,
  List<String> purchases,
  Map<String, String> assigned,
) {
  final txn = assigned[layoutId];
  return txn != null && purchases.contains(txn);
}
