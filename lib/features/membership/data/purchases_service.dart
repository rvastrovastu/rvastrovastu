import '../domain/membership.dart';

/// Store purchases behind an interface, so screens and tests don't depend
/// on the RevenueCat SDK.
abstract class PurchasesService {
  /// False when this build has no store keys; the paywall then explains
  /// that purchases aren't available.
  bool get isAvailable;

  /// Links purchases to [userId] (the Supabase user id).
  Future<void> start({required String? userId});

  Future<void> identify(String userId);

  Future<MembershipState> membership();

  /// Pushes a new state whenever the store reports a change (renewal,
  /// expiry, purchase on another device).
  Stream<MembershipState> get changes;

  Future<List<PlanOffer>> plans();

  Future<List<AddOnOffer>> addOns();

  Future<(PurchaseOutcome, MembershipState?)> buyPlan(PlanOffer plan);

  Future<(PurchaseOutcome, MembershipState?)> buyAddOn(AddOnOffer offer);

  /// The per-property Vastu report, or null when the store has no price.
  Future<VastuReportOffer?> vastuReportOffer();

  Future<(PurchaseOutcome, MembershipState?)> buyVastuReport(
    VastuReportOffer offer,
  );

  /// A pack of AI questions, or null when the store has no price.
  Future<AiPackOffer?> aiPackOffer();

  Future<(PurchaseOutcome, MembershipState?)> buyAiPack(AiPackOffer offer);

  Future<MembershipState> restore();
}

/// Used when no store keys are configured (local builds, tests).
class UnavailablePurchasesService implements PurchasesService {
  final MembershipState state;

  const UnavailablePurchasesService([this.state = MembershipState.free]);

  @override
  bool get isAvailable => false;

  @override
  Future<void> start({required String? userId}) async {}

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<MembershipState> membership() async => state;

  @override
  Stream<MembershipState> get changes => const Stream.empty();

  @override
  Future<List<PlanOffer>> plans() async => const [];

  @override
  Future<List<AddOnOffer>> addOns() async => const [];

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyPlan(PlanOffer plan) async =>
      (PurchaseOutcome.failed, null);

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAddOn(
    AddOnOffer offer,
  ) async => (PurchaseOutcome.failed, null);

  @override
  Future<VastuReportOffer?> vastuReportOffer() async => null;

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyVastuReport(
    VastuReportOffer offer,
  ) async => (PurchaseOutcome.failed, null);

  @override
  Future<AiPackOffer?> aiPackOffer() async => null;

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAiPack(
    AiPackOffer offer,
  ) async => (PurchaseOutcome.failed, null);

  @override
  Future<MembershipState> restore() async => state;
}
