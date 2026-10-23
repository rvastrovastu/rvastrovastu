import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/membership.dart';
import 'purchases_service.dart';

/// RevenueCat public SDK keys, passed with --dart-define. They are safe to
/// ship in the app (they can't grant purchases).
class RevenueCatConfig {
  const RevenueCatConfig._();

  static const appleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const googleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

  static String? get keyForPlatform {
    if (kIsWeb) return null;
    final key = Platform.isIOS || Platform.isMacOS
        ? appleKey
        : Platform.isAndroid
        ? googleKey
        : '';
    return key.isEmpty ? null : key;
  }
}

class RevenueCatPurchasesService implements PurchasesService {
  final String apiKey;
  final _changes = StreamController<MembershipState>.broadcast();
  bool _started = false;

  RevenueCatPurchasesService(this.apiKey);

  @override
  bool get isAvailable => true;

  @override
  Future<void> start({required String? userId}) async {
    if (_started) {
      if (userId != null) await identify(userId);
      return;
    }
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(apiKey)..appUserID = userId;
    await Purchases.configure(config);
    Purchases.addCustomerInfoUpdateListener(
      (info) => _changes.add(membershipFrom(info)),
    );
    _started = true;
  }

  @override
  Future<void> identify(String userId) async {
    if (!_started) return start(userId: userId);
    final current = await Purchases.appUserID;
    if (current == userId) return;
    final result = await Purchases.logIn(userId);
    _changes.add(membershipFrom(result.customerInfo));
  }

  @override
  Future<MembershipState> membership() async =>
      membershipFrom(await Purchases.getCustomerInfo());

  @override
  Stream<MembershipState> get changes => _changes.stream;

  @override
  Future<List<PlanOffer>> plans() async {
    final offering = (await Purchases.getOfferings()).current;
    if (offering == null) return const [];
    final packages = [
      if (offering.monthly case final p?) (PlanPeriod.monthly, p),
      if (offering.annual case final p?) (PlanPeriod.yearly, p),
    ];

    // Apple shows trials to everyone; only advertise one the user can
    // still take. Google Play already offers eligible trials only.
    var ineligible = <String>{};
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final eligibility =
            await Purchases.checkTrialOrIntroductoryPriceEligibility([
              for (final (_, p) in packages) p.storeProduct.identifier,
            ]);
        ineligible = {
          for (final entry in eligibility.entries)
            if (entry.value.status ==
                IntroEligibilityStatus.introEligibilityStatusIneligible)
              entry.key,
        };
      } catch (_) {
        // Unknown eligibility: fall back to what the store reports.
      }
    }

    return [
      for (final (period, package) in packages)
        PlanOffer(
          period: period,
          priceLabel: package.storeProduct.priceString,
          price: package.storeProduct.price,
          currencyCode: package.storeProduct.currencyCode,
          trialDays: ineligible.contains(package.storeProduct.identifier)
              ? null
              : freeTrialDays(package.storeProduct),
          handle: package,
        ),
    ];
  }

  @override
  Future<List<AddOnOffer>> addOns() async {
    final products = await Purchases.getProducts(
      [for (final a in AddOn.values) StoreIds.productFor(a)],
      productCategory: ProductCategory.nonSubscription,
    );
    return [
      for (final addOn in AddOn.values)
        for (final product in products)
          if (product.identifier == StoreIds.productFor(addOn))
            AddOnOffer(
              addOn: addOn,
              priceLabel: product.priceString,
              handle: product,
            ),
    ];
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyPlan(PlanOffer plan) =>
      _buy(() => Purchases.purchase(
            PurchaseParams.package(plan.handle as Package),
          ));

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAddOn(AddOnOffer offer) =>
      _buy(() => Purchases.purchase(
            PurchaseParams.storeProduct(offer.handle as StoreProduct),
          ));

  Future<(PurchaseOutcome, MembershipState?)> _buy(
    Future<PurchaseResult> Function() purchase,
  ) async {
    try {
      final result = await purchase();
      return (PurchaseOutcome.purchased, membershipFrom(result.customerInfo));
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => (
          PurchaseOutcome.cancelled,
          null,
        ),
        PurchasesErrorCode.paymentPendingError => (
          PurchaseOutcome.pending,
          null,
        ),
        _ => (PurchaseOutcome.failed, null),
      };
    }
  }

  @override
  Future<VastuReportOffer?> vastuReportOffer() async {
    final products = await Purchases.getProducts([
      StoreIds.vastuReport,
    ], productCategory: ProductCategory.nonSubscription);
    for (final product in products) {
      if (product.identifier == StoreIds.vastuReport) {
        return VastuReportOffer(
          priceLabel: product.priceString,
          handle: product,
        );
      }
    }
    return null;
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyVastuReport(
    VastuReportOffer offer,
  ) => _buy(
    () => Purchases.purchase(
      PurchaseParams.storeProduct(offer.handle as StoreProduct),
    ),
  );

  @override
  Future<AiPackOffer?> aiPackOffer() async {
    final products = await Purchases.getProducts([
      StoreIds.aiQuestionPack,
    ], productCategory: ProductCategory.nonSubscription);
    for (final product in products) {
      if (product.identifier == StoreIds.aiQuestionPack) {
        return AiPackOffer(priceLabel: product.priceString, handle: product);
      }
    }
    return null;
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAiPack(AiPackOffer offer) =>
      _buy(
        () => Purchases.purchase(
          PurchaseParams.storeProduct(offer.handle as StoreProduct),
        ),
      );

  @override
  Future<MembershipState> restore() async =>
      membershipFrom(await Purchases.restorePurchases());
}

/// Days of free trial on [product]: the App Store introductory offer, or
/// the free phase of the default Google Play offer.
@visibleForTesting
int? freeTrialDays(StoreProduct product) {
  int? days(PeriodUnit unit, int count) => switch (unit) {
    PeriodUnit.day => count,
    PeriodUnit.week => count * 7,
    PeriodUnit.month => count * 30,
    PeriodUnit.year => count * 365,
    PeriodUnit.unknown => null,
  };

  final intro = product.introductoryPrice;
  if (intro != null && intro.price == 0) {
    return days(intro.periodUnit, intro.periodNumberOfUnits * intro.cycles);
  }
  final period = product.defaultOption?.freePhase?.billingPeriod;
  if (period != null) return days(period.unit, period.value);
  return null;
}

/// Maps RevenueCat's customer info to the app's membership.
@visibleForTesting
MembershipState membershipFrom(CustomerInfo info) {
  final active = info.entitlements.active;
  final premium = active[StoreIds.premiumEntitlement];
  final expiry = premium?.expirationDate;
  return MembershipState(
    premium: premium != null,
    addOns: {
      for (final addOn in AddOn.values)
        if (active.containsKey(StoreIds.entitlementFor(addOn))) addOn,
    },
    premiumUntil: expiry == null ? null : DateTime.tryParse(expiry),
    willRenew: premium?.willRenew ?? false,
    plan: switch (premium?.productIdentifier) {
      final id? when id.startsWith(StoreIds.yearly) => PlanPeriod.yearly,
      final id? when id.startsWith(StoreIds.monthly) => PlanPeriod.monthly,
      _ => null,
    },
    managementUrl: info.managementURL,
    vastuReports: [
      for (final t in info.nonSubscriptionTransactions)
        if (t.productIdentifier == StoreIds.vastuReport) t.transactionIdentifier,
    ],
  );
}
