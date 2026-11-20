import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vastu_layout.dart';
import 'vastu_cloud_sync.dart';
import 'package:rv_astro_vastu/core/telemetry/telemetry.dart';

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

  /// Saves [bytes] under an existing file name (a picture brought down
  /// from the account keeps the name it had on the other phone).
  Future<void> put(String name, Uint8List bytes) async {
    final file = File('${(await _dir()).path}/$name');
    await file.writeAsBytes(bytes, flush: true);
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

/// Saved house layouts, kept on this device and, for email accounts, in
/// the cloud (see [VastuCloudSync]).
class VastuLayoutRepository {
  static const _key = 'vastu_layouts';
  final VastuImageStore images;
  final VastuCloudSync cloud;
  final VastuReportLedger ledger;

  const VastuLayoutRepository({
    this.images = const VastuImageStore(),
    this.cloud = const VastuCloudSync(),
    this.ledger = const VastuReportLedger(),
  });

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
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'vastu_plans_load');
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
    // In the background: saving on the phone never waits for the network.
    unawaited(_push(layout, previousImage: previous?.imageFile));
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    String? image;
    for (final l in all) {
      if (l.id == id && l.imageFile != null) {
        image = l.imageFile;
        await _deleteImage(l.imageFile!);
      }
    }
    await _write([
      for (final l in all)
        if (l.id != id) l,
    ]);
    unawaited(cloud.remove(id, imageFile: image));
  }

  /// Brings the account's plans onto this phone and sends up the ones the
  /// account lacks; when both have a plan, the copy changed last wins.
  /// Returns the plans now on the phone, or null when nothing changed (a
  /// guest, offline, or already in step).
  Future<List<VastuLayout>?> syncWithAccount() async {
    final remote = await cloud.fetch();
    if (remote == null) return null;
    final local = await loadAll();
    final assigned = await ledger.load();
    final plan = mergeVastuPlans(local, remote, assigned);

    for (final entry in plan.downloads.entries) {
      final layout = plan.keep.firstWhere((l) => l.id == entry.key);
      final name = layout.imageFile!;
      if (await images.file(name) != null) continue;
      final bytes = await cloud.download(entry.value);
      if (bytes != null) await images.put(name, bytes);
    }
    // Pictures of copies that were replaced or deleted elsewhere.
    final keptImages = {for (final l in plan.keep) l.imageFile};
    for (final l in [...local, ...plan.dropped]) {
      final name = l.imageFile;
      if (name != null && !keptImages.contains(name)) await _deleteImage(name);
    }
    for (final entry in plan.reports.entries) {
      await ledger.assign(entry.key, entry.value, syncCloud: false);
    }
    for (final layout in plan.uploads) {
      await _push(layout);
    }

    final changed =
        plan.downloads.isNotEmpty ||
        plan.dropped.isNotEmpty ||
        plan.reports.isNotEmpty ||
        plan.keep.length != local.length ||
        [
          for (var i = 0; i < local.length; i++)
            plan.keep[i].updatedAt != local[i].updatedAt ||
                plan.keep[i].id != local[i].id,
        ].any((c) => c);
    if (!changed) return null;
    await _write(plan.keep);
    return loadAll();
  }

  Future<void> _push(VastuLayout layout, {String? previousImage}) async {
    final name = layout.imageFile;
    final file = name == null ? null : await images.file(name);
    final assigned = await ledger.load();
    await cloud.push(
      layout,
      image: file,
      previousImage: previousImage,
      reportTxn: assigned[layout.id],
    );
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
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'vastu_ledger_load');
      return const {};
    }
  }

  Future<void> assign(
    String layoutId,
    String transactionId, {
    bool syncCloud = true,
  }) async {
    final current = {...await load(), layoutId: transactionId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(current));
    if (syncCloud) {
      unawaited(const VastuCloudSync().setReport(layoutId, transactionId));
    }
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
