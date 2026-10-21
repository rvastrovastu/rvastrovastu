import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../data/vastu_layout_repository.dart';
import '../domain/vastu_layout.dart';

final vastuLayoutRepositoryProvider = Provider<VastuLayoutRepository>(
  (ref) => const VastuLayoutRepository(),
);

final vastuImageStoreProvider = Provider<VastuImageStore>(
  (ref) => ref.watch(vastuLayoutRepositoryProvider).images,
);

final vastuReportLedgerProvider = Provider<VastuReportLedger>(
  (ref) => const VastuReportLedger(),
);

/// Every saved property, newest first.
final vastuLayoutsProvider =
    AsyncNotifierProvider<VastuLayoutsNotifier, List<VastuLayout>>(
      VastuLayoutsNotifier.new,
    );

class VastuLayoutsNotifier extends AsyncNotifier<List<VastuLayout>> {
  VastuLayoutRepository get _repo => ref.read(vastuLayoutRepositoryProvider);

  @override
  Future<List<VastuLayout>> build() =>
      ref.watch(vastuLayoutRepositoryProvider).loadAll();

  Future<void> save(VastuLayout layout) async {
    await _repo.save(layout);
    state = AsyncData(await _repo.loadAll());
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.loadAll());
  }
}

/// One saved property, or null when it no longer exists.
final vastuLayoutProvider = Provider.family<AsyncValue<VastuLayout?>, String>(
  (ref, id) => ref
      .watch(vastuLayoutsProvider)
      .whenData((all) => all.where((l) => l.id == id).firstOrNull),
);

/// Which property each bought report belongs to (layout id → transaction).
final vastuReportAssignmentsProvider =
    AsyncNotifierProvider<VastuReportAssignments, Map<String, String>>(
      VastuReportAssignments.new,
    );

class VastuReportAssignments extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() =>
      ref.watch(vastuReportLedgerProvider).load();

  Future<void> assign(String layoutId, String transactionId) async {
    final ledger = ref.read(vastuReportLedgerProvider);
    await ledger.assign(layoutId, transactionId);
    state = AsyncData(await ledger.load());
  }
}

/// Where a property stands with its detailed report.
enum VastuReportAccess {
  /// Bought for this property (or unlocked by the debug preview).
  unlocked,

  /// A report was bought earlier and not yet used for any property.
  unusedCredit,

  /// Needs a purchase.
  locked,
}

final vastuReportAccessProvider = Provider.family<VastuReportAccess, String>((
  ref,
  layoutId,
) {
  if (premiumPreviewEnabled) return VastuReportAccess.unlocked;
  final purchases =
      ref.watch(membershipProvider).value?.vastuReports ?? const <String>[];
  final assigned =
      ref.watch(vastuReportAssignmentsProvider).value ??
      const <String, String>{};
  if (reportUnlocked(layoutId, purchases, assigned)) {
    return VastuReportAccess.unlocked;
  }
  return unusedReport(purchases, assigned) == null
      ? VastuReportAccess.locked
      : VastuReportAccess.unusedCredit;
});

/// The store's price for one report, or null when the store can't sell it.
final vastuReportOfferProvider = FutureProvider<VastuReportOffer?>((
  ref,
) async {
  try {
    // Wait for the store to be set up for this user.
    await ref.read(membershipProvider.future);
    return await ref.read(purchasesServiceProvider).vastuReportOffer();
  } catch (_) {
    return null;
  }
});

/// Puts a bought-but-unused report on [layoutId]. Returns false when there
/// is no unused report.
Future<bool> useReportCredit(WidgetRef ref, String layoutId) async {
  final purchases =
      ref.read(membershipProvider).value?.vastuReports ?? const <String>[];
  final assigned = await ref.read(vastuReportAssignmentsProvider.future);
  final txn = unusedReport(purchases, assigned);
  if (txn == null) return false;
  await ref.read(vastuReportAssignmentsProvider.notifier).assign(layoutId, txn);
  return true;
}
