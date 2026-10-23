import 'dart:async';

import 'package:rv_astro_vastu/features/membership/data/purchases_service.dart';
import 'package:rv_astro_vastu/features/membership/domain/membership.dart';

/// In-memory store for widget tests.
class FakePurchasesService implements PurchasesService {
  MembershipState state;
  final List<PlanOffer> planOffers;
  final List<AddOnOffer> addOnOffers;
  final _changes = StreamController<MembershipState>.broadcast();
  final List<Object> bought = [];
  String? userId;

  FakePurchasesService({
    this.state = MembershipState.free,
    this.planOffers = const [],
    this.addOnOffers = const [],
  });

  static List<PlanOffer> usPlans({int? trialDays = 7}) => [
    const PlanOffer(
      period: PlanPeriod.monthly,
      priceLabel: r'$1.19',
      price: 1.19,
      currencyCode: 'USD',
      handle: 'monthly',
    ),
    PlanOffer(
      period: PlanPeriod.yearly,
      priceLabel: r'$11.99',
      price: 11.99,
      currencyCode: 'USD',
      handle: 'yearly',
      trialDays: trialDays,
    ),
  ];

  static const usAddOns = [
    AddOnOffer(addOn: AddOn.kundliPdf, priceLabel: r'$2.99', handle: 'k'),
    AddOnOffer(
      addOn: AddOn.compatibilityPdf,
      priceLabel: r'$1.99',
      handle: 'c',
    ),
  ];

  @override
  bool get isAvailable => true;

  @override
  Future<void> start({required String? userId}) async => this.userId = userId;

  @override
  Future<void> identify(String userId) async => this.userId = userId;

  @override
  Future<MembershipState> membership() async => state;

  @override
  Stream<MembershipState> get changes => _changes.stream;

  @override
  Future<List<PlanOffer>> plans() async => planOffers;

  @override
  Future<List<AddOnOffer>> addOns() async => addOnOffers;

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyPlan(PlanOffer plan) async {
    bought.add(plan.handle);
    state = MembershipState(
      premium: true,
      plan: plan.period,
      willRenew: true,
      premiumUntil: DateTime.utc(2027, 10, 20),
    );
    return (PurchaseOutcome.purchased, state);
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAddOn(
    AddOnOffer offer,
  ) async {
    bought.add(offer.handle);
    state = MembershipState(addOns: {...state.addOns, offer.addOn});
    return (PurchaseOutcome.purchased, state);
  }

  VastuReportOffer? vastuOffer = const VastuReportOffer(
    priceLabel: r'$10.99',
    handle: 'vastu',
  );

  @override
  Future<VastuReportOffer?> vastuReportOffer() async => vastuOffer;

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyVastuReport(
    VastuReportOffer offer,
  ) async {
    bought.add(offer.handle);
    state = MembershipState(
      premium: state.premium,
      addOns: state.addOns,
      vastuReports: [...state.vastuReports, 'txn${state.vastuReports.length}'],
    );
    return (PurchaseOutcome.purchased, state);
  }

  AiPackOffer? aiOffer = const AiPackOffer(
    priceLabel: r'$1.99',
    handle: 'ai10',
  );

  @override
  Future<AiPackOffer?> aiPackOffer() async => aiOffer;

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAiPack(
    AiPackOffer offer,
  ) async {
    bought.add(offer.handle);
    return (PurchaseOutcome.purchased, state);
  }

  @override
  Future<MembershipState> restore() async => state;
}
