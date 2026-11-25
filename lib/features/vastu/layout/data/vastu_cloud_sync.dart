import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_initialization.dart';
import '../../../../core/telemetry/telemetry.dart';
import '../domain/vastu_layout.dart';

/// Keeps saved house plans with an email account, so they follow the user
/// to a new phone. Guests, and phones without the backend, keep plans on
/// the device only: every method then does nothing.
///
/// Plans are rows in `vastu_layouts`; pictures live in the private
/// `vastu-plans` bucket under `<user id>/<file name>`. Failures never reach
/// the user: the plan is always saved on the phone first.
class VastuCloudSync {
  const VastuCloudSync();

  static const bucket = 'vastu-plans';
  static const table = 'vastu_layouts';

  SupabaseClient? get _client =>
      AppInitialization.supabaseAvailable ? AppInitialization.supabase : null;

  /// The signed-in email account's id, or null.
  String? get _userId {
    final user = _client?.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return user.id;
  }

  /// Uploads [layout] and its picture. [previousImage] is the picture it
  /// replaced, removed from the cloud too.
  Future<void> push(
    VastuLayout layout, {
    Uint8List? image,
    String? previousImage,
    String? reportTxn,
  }) async {
    final client = _client;
    final uid = _userId;
    if (client == null || uid == null) return;
    try {
      String? path;
      final name = layout.imageFile;
      if (name != null && image != null) {
        path = '$uid/$name';
        await _uploadImage(client, path, image);
      }
      if (previousImage != null && previousImage != name) {
        await _removeImages(client, ['$uid/$previousImage']);
      }
      await client.from(table).upsert({
        'user_id': uid,
        'id': layout.id,
        'layout': layout.toJson(),
        'image_path': path,
        'report_txn': reportTxn,
        'updated_at': layout.updatedAt.toUtc().toIso8601String(),
        'deleted': false,
      });
    } catch (error, stack) {
      debugPrint('Vastu plan upload skipped: $error');
      Telemetry.recordError(error, stack, reason: 'vastu_push');
    }
  }

  /// Marks [id] deleted in the cloud and removes its picture, so other
  /// phones drop their copy.
  Future<void> remove(String id, {String? imageFile}) async {
    final client = _client;
    final uid = _userId;
    if (client == null || uid == null) return;
    try {
      if (imageFile != null) await _removeImages(client, ['$uid/$imageFile']);
      await client.from(table).upsert({
        'user_id': uid,
        'id': id,
        'layout': <String, dynamic>{},
        'image_path': null,
        'report_txn': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'deleted': true,
      });
    } catch (error, stack) {
      debugPrint('Vastu plan delete skipped: $error');
      Telemetry.recordError(error, stack, reason: 'vastu_remove');
    }
  }

  /// Records which bought report [layoutId] uses.
  Future<void> setReport(String layoutId, String transactionId) async {
    final client = _client;
    final uid = _userId;
    if (client == null || uid == null) return;
    try {
      await client
          .from(table)
          .update({'report_txn': transactionId})
          .eq('user_id', uid)
          .eq('id', layoutId);
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'vastu_report');
    }
  }

  /// The account's plans as the cloud has them, or null for a guest, when
  /// offline or on any error.
  Future<List<CloudVastuPlan>?> fetch() async {
    final client = _client;
    final uid = _userId;
    if (client == null || uid == null) return null;
    try {
      final rows = await client.from(table).select().eq('user_id', uid);
      return [
        for (final row in rows) ?CloudVastuPlan.fromRow(row),
      ];
    } catch (error, stack) {
      debugPrint('Vastu plan sync skipped: $error');
      Telemetry.recordError(error, stack, reason: 'vastu_fetch');
      return null;
    }
  }

  /// Downloads a picture by its cloud path, or null when it can't.
  Future<Uint8List?> download(String path) async {
    final client = _client;
    if (client == null) return null;
    try {
      return await client.storage.from(bucket).download(path);
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'vastu_download');
      return null;
    }
  }

  /// Removes every picture of the signed-in account. Called before the
  /// account is deleted, because storage files don't go with the rows.
  Future<void> removeAllImages() async {
    final client = _client;
    final uid = _userId;
    if (client == null || uid == null) return;
    try {
      final files = await client.storage.from(bucket).list(path: uid);
      if (files.isEmpty) return;
      await _removeImages(client, [for (final f in files) '$uid/${f.name}']);
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'vastu_remove_all');
    }
  }

  Future<void> _uploadImage(
    SupabaseClient client,
    String path,
    Uint8List image,
  ) async {
    try {
      // File names are unique per picture, so one that is already there is
      // the same picture: nothing to do.
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            image,
            fileOptions: FileOptions(contentType: _contentType(path)),
          );
    } on StorageException catch (error) {
      if (error.statusCode == '409' ||
          error.message.toLowerCase().contains('exists')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _removeImages(SupabaseClient client, List<String> paths) async {
    try {
      await client.storage.from(bucket).remove(paths);
    } catch (_) {
      // A picture that is already gone is fine.
    }
  }

  static String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

/// One plan as stored in the cloud.
class CloudVastuPlan {
  final String id;
  final VastuLayout? layout;
  final String? imagePath;
  final String? reportTxn;
  final DateTime updatedAt;
  final bool deleted;

  const CloudVastuPlan({
    required this.id,
    required this.updatedAt,
    this.layout,
    this.imagePath,
    this.reportTxn,
    this.deleted = false,
  });

  static CloudVastuPlan? fromRow(Map<String, dynamic> row) {
    final id = row['id'] as String?;
    final updated = DateTime.tryParse(row['updated_at'] as String? ?? '');
    if (id == null || updated == null) return null;
    final deleted = row['deleted'] == true;
    final json = row['layout'];
    final layout = !deleted && json is Map
        ? VastuLayout.fromJson(Map<String, dynamic>.from(json))
              // The cloud's time is exact (UTC); the layout's own may be
              // in another phone's time zone.
              ?.copyWith(updatedAt: updated.toLocal())
        : null;
    if (!deleted && layout == null) return null;
    return CloudVastuPlan(
      id: id,
      updatedAt: updated,
      layout: layout,
      imagePath: row['image_path'] as String?,
      reportTxn: row['report_txn'] as String?,
      deleted: deleted,
    );
  }
}

/// What to do with each plan when this phone and the account meet.
class VastuMergePlan {
  /// Plans to keep on this phone, newest first.
  final List<VastuLayout> keep;

  /// Plans to download a picture for: layout id → cloud path.
  final Map<String, String> downloads;

  /// Local plans the cloud lacks or has an older copy of.
  final List<VastuLayout> uploads;

  /// Local plans deleted on another phone.
  final List<VastuLayout> dropped;

  /// Report assignments the cloud knows and this phone doesn't.
  final Map<String, String> reports;

  const VastuMergePlan({
    required this.keep,
    required this.downloads,
    required this.uploads,
    required this.dropped,
    required this.reports,
  });
}

/// Decides, plan by plan, which copy wins: the one changed most recently.
/// A plan deleted on another phone after its last change here is removed.
VastuMergePlan mergeVastuPlans(
  List<VastuLayout> local,
  List<CloudVastuPlan> cloud,
  Map<String, String> assigned,
) {
  final byId = {for (final l in local) l.id: l};
  final keep = <String, VastuLayout>{...byId};
  final downloads = <String, String>{};
  final uploads = <VastuLayout>[];
  final dropped = <VastuLayout>[];
  final reports = <String, String>{};
  final seen = <String>{};

  for (final remote in cloud) {
    seen.add(remote.id);
    final mine = byId[remote.id];
    if (remote.deleted) {
      if (mine == null) continue;
      if (mine.updatedAt.isAfter(remote.updatedAt)) {
        uploads.add(mine);
      } else {
        keep.remove(remote.id);
        dropped.add(mine);
      }
      continue;
    }
    final theirs = remote.layout!;
    if (mine == null || remote.updatedAt.isAfter(mine.updatedAt)) {
      keep[remote.id] = theirs;
      if (remote.imagePath != null && theirs.imageFile != null) {
        downloads[remote.id] = remote.imagePath!;
      }
    } else if (mine.updatedAt.isAfter(remote.updatedAt)) {
      uploads.add(mine);
    }
    final txn = remote.reportTxn;
    if (txn != null && assigned[remote.id] == null) reports[remote.id] = txn;
  }

  for (final l in local) {
    if (!seen.contains(l.id)) uploads.add(l);
  }

  return VastuMergePlan(
    keep: keep.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    downloads: downloads,
    uploads: uploads,
    dropped: dropped,
    reports: reports,
  );
}
