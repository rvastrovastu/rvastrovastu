import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/purchases_service.dart';
import '../../data/revenuecat_purchases_service.dart';
import '../../domain/membership.dart';

/// Debug builds only: `--dart-define=PREMIUM_PREVIEW=true` unlocks every
/// premium feature without a store, for testing screens.
const _premiumPreview = bool.fromEnvironment('PREMIUM_PREVIEW');

/// True only in a debug build run with PREMIUM_PREVIEW=true.
const premiumPreviewEnabled = kDebugMode && _premiumPreview;

final purchasesServiceProvider = Provider<PurchasesService>((ref) {
  if (premiumPreviewEnabled) {
    return const UnavailablePurchasesService(
      MembershipState(
        premium: true,
        addOns: {AddOn.kundliPdf, AddOn.compatibilityPdf},
      ),
    );
  }
  final key = RevenueCatConfig.keyForPlatform;
  return key == null
      ? const UnavailablePurchasesService()
      : RevenueCatPurchasesService(key);
});

final membershipProvider =
    AsyncNotifierProvider<MembershipNotifier, MembershipState>(
      MembershipNotifier.new,
    );

class MembershipNotifier extends AsyncNotifier<MembershipState> {
  @override
  Future<MembershipState> build() async {
    final service = ref.watch(purchasesServiceProvider);
    final userId = ref.watch(authUserIdProvider);

    try {
      await service.start(userId: userId);
      final sub = service.changes.listen((s) => state = AsyncData(s));
      ref.onDispose(sub.cancel);
      return await service.membership();
    } catch (error) {
      // Never block the app on the store; treat as free until it answers.
      debugPrint('[MEMBERSHIP] unavailable: $error');
      return MembershipState.free;
    }
  }

  PurchasesService get _service => ref.read(purchasesServiceProvider);

  Future<PurchaseOutcome> buyPlan(PlanOffer plan) async {
    final (outcome, updated) = await _service.buyPlan(plan);
    if (updated != null) state = AsyncData(updated);
    return outcome;
  }

  Future<PurchaseOutcome> buyAddOn(AddOnOffer offer) async {
    final (outcome, updated) = await _service.buyAddOn(offer);
    if (updated != null) state = AsyncData(updated);
    return outcome;
  }

  Future<PurchaseOutcome> buyVastuReport(VastuReportOffer offer) async {
    final (outcome, updated) = await _service.buyVastuReport(offer);
    if (updated != null) state = AsyncData(updated);
    return outcome;
  }

  /// Restores purchases from the store account. Returns true when anything
  /// paid is now active.
  Future<bool> restore() async {
    final restored = await _service.restore();
    state = AsyncData(restored);
    return restored.premium ||
        restored.addOns.isNotEmpty ||
        restored.vastuReports.isNotEmpty;
  }
}

/// Whether the current user may use [feature]. False while loading.
final canUseProvider = Provider.family<bool, PremiumFeature>(
  (ref, feature) =>
      ref.watch(membershipProvider).value?.canUse(feature) ?? false,
);

/// Plans and add-ons with store prices, for the paywall.
final storeOffersProvider =
    FutureProvider.autoDispose<(List<PlanOffer>, List<AddOnOffer>)>((
      ref,
    ) async {
      final service = ref.watch(purchasesServiceProvider);
      // Make sure the SDK is configured before asking for offerings.
      await ref.read(membershipProvider.future);
      return (await service.plans(), await service.addOns());
    });

/// Whether another birth profile may be saved, given [savedCount].
bool canAddProfile(MembershipState? membership, int savedCount) {
  final limit = (membership ?? MembershipState.free).profileLimit;
  return limit == null || savedCount < limit;
}
