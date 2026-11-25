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

  /// The Web Billing public key (starts with `rcb_`), for the website.
  /// Purchases there go through Stripe and unlock the same entitlements as
  /// the stores, because the app user id is the same Supabase account.
  static const webKey = String.fromEnvironment('REVENUECAT_WEB_KEY');

  static String? get keyForPlatform {
    if (kIsWeb) return webKey.isEmpty ? null : webKey;
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
    final offerings = await Purchases.getOfferings().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('[STORE] getOfferings timed out after 15s');
        throw TimeoutException('getOfferings');
      },
    );
    final offering = offerings.current;
    if (offering == null) return const [];
    // Use the offering's own slots first, then fall back to matching the
    // product ids, so plans still show when the dashboard package types
    // are custom rather than monthly/annual.
    Package? monthly = offering.monthly;
    Package? annual = offering.annual;
    for (final package in offering.availablePackages) {
      final id = package.storeProduct.identifier;
      if (monthly == null && id.startsWith(StoreIds.monthly)) monthly = package;
      if (annual == null && id.startsWith(StoreIds.yearly)) annual = package;
    }
    final packages = [
      if (monthly != null) (PlanPeriod.monthly, monthly),
      if (annual != null) (PlanPeriod.yearly, annual),
    ];

    // Apple shows trials to everyone; only advertise one the user can
    // still take. Google Play already offers eligible trials only.
    var ineligible = <String>{};
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        final eligibility =
            await Purchases.checkTrialOrIntroductoryPriceEligibility([
              for (final (_, p) in packages) p.storeProduct.identifier,
            ]).timeout(const Duration(seconds: 8));
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
    final found = await _oneTimeProducts([
      for (final a in AddOn.values) StoreIds.productFor(a),
    ]);
    return [
      for (final addOn in AddOn.values)
        if (found[StoreIds.productFor(addOn)] case (final price, final handle))
          AddOnOffer(addOn: addOn, priceLabel: price, handle: handle),
    ];
  }

  /// One-time products by id: their price label and what to buy them with.
  ///
  /// The stores look products up directly. Web Billing can't (the SDK sells
  /// only packages on the web), so there every one-time product must sit in
  /// a package of some offering in the dashboard: the `web_addons` offering
  /// in the setup guide. Products are matched by identifier in any offering.
  Future<Map<String, (String, Object)>> _oneTimeProducts(
    List<String> ids,
  ) async {
    if (!kIsWeb) {
      final products = await Purchases.getProducts(
        ids,
        productCategory: ProductCategory.nonSubscription,
      );
      return {
        for (final product in products)
          if (ids.contains(product.identifier))
            product.identifier: (product.priceString, product),
      };
    }
    final offerings = await Purchases.getOfferings();
    return {
      for (final offering in offerings.all.values)
        for (final package in offering.availablePackages)
          if (ids.contains(package.storeProduct.identifier))
            package.storeProduct.identifier: (
              package.storeProduct.priceString,
              package,
            ),
    };
  }

  /// Buys a one-time product found by [_oneTimeProducts].
  Future<(PurchaseOutcome, MembershipState?)> _buyOneTime(Object handle) =>
      _buy(
        () => Purchases.purchase(
          handle is Package
              ? PurchaseParams.package(handle)
              : PurchaseParams.storeProduct(handle as StoreProduct),
        ),
      );

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyPlan(PlanOffer plan) async {
    final (outcome, state) = await _buy(() => Purchases.purchase(
          PurchaseParams.package(plan.handle as Package),
        ));
    if (outcome != PurchaseOutcome.purchased || (state?.premium ?? false)) {
      return (outcome, state);
    }
    // The store can take a moment to report the new entitlement; check again
    // before telling the user Premium is not active.
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      final info = await Purchases.getCustomerInfo();
      final fresh = membershipFrom(info);
      debugPrint('[PURCHASE] re-check premium=${fresh.premium} subs=${info.activeSubscriptions}');
      return (outcome, fresh);
    } catch (error) {
      debugPrint('[PURCHASE] re-check failed: $error');
      return (outcome, state);
    }
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAddOn(AddOnOffer offer) =>
      _buyOneTime(offer.handle);

  Future<(PurchaseOutcome, MembershipState?)> _buy(
    Future<PurchaseResult> Function() purchase,
  ) async {
    try {
      final result = await purchase();
      final active = result.customerInfo.entitlements.active.keys.toList();
      debugPrint('[PURCHASE] completed; active entitlements: $active');
      return (PurchaseOutcome.purchased, membershipFrom(result.customerInfo));
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[PURCHASE] failed code=$code message=${e.message}');
      return switch (code) {
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
    } catch (error) {
      debugPrint('[PURCHASE] unexpected error: $error');
      return (PurchaseOutcome.failed, null);
    }
  }

  @override
  Future<VastuReportOffer?> vastuReportOffer() async {
    final found = await _oneTimeProducts([StoreIds.vastuReport]);
    return switch (found[StoreIds.vastuReport]) {
      (final price, final handle) => VastuReportOffer(
        priceLabel: price,
        handle: handle,
      ),
      null => null,
    };
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyVastuReport(
    VastuReportOffer offer,
  ) => _buyOneTime(offer.handle);

  @override
  Future<AiPackOffer?> aiPackOffer() async {
    final found = await _oneTimeProducts([StoreIds.aiQuestionPack]);
    return switch (found[StoreIds.aiQuestionPack]) {
      (final price, final handle) => AiPackOffer(
        priceLabel: price,
        handle: handle,
      ),
      null => null,
    };
  }

  @override
  Future<(PurchaseOutcome, MembershipState?)> buyAiPack(AiPackOffer offer) =>
      _buyOneTime(offer.handle);

  /// On the web there is no store account to restore from: purchases belong
  /// to the signed-in account, so this just reads them again.
  @override
  Future<MembershipState> restore() async => kIsWeb
      ? membershipFrom(await Purchases.getCustomerInfo())
      : membershipFrom(await Purchases.restorePurchases());
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

/// Entitlements that belong to the single-report add-ons, not to Premium.
const _addOnEntitlements = {
  StoreIds.kundliPdfEntitlement,
  StoreIds.compatibilityPdfEntitlement,
  StoreIds.varshphalPdfEntitlement,
};

/// Maps RevenueCat's customer info to the app's membership.
///
/// Premium counts when the `premium` entitlement is active, or when any other
/// non-add-on entitlement is active, or when an active Premium subscription
/// product exists. The last check keeps Premium working even if the
/// entitlement is named differently or not linked to the products yet.
@visibleForTesting
MembershipState membershipFrom(CustomerInfo info) {
  final active = info.entitlements.active;
  final premiumInfo = active[StoreIds.premiumEntitlement] ??
      (() {
        for (final entry in active.entries) {
          if (!_addOnEntitlements.contains(entry.key)) return entry.value;
        }
        return null;
      })();
  final subscriptionId = info.activeSubscriptions
      .where(
        (id) =>
            id.startsWith(StoreIds.monthly) || id.startsWith(StoreIds.yearly),
      )
      .toList();
  final planProductId = premiumInfo?.productIdentifier ??
      (subscriptionId.isEmpty ? null : subscriptionId.first);
  final expiry = premiumInfo?.expirationDate;
  return MembershipState(
    premium: premiumInfo != null || subscriptionId.isNotEmpty,
    addOns: {
      for (final addOn in AddOn.values)
        if (active.containsKey(StoreIds.entitlementFor(addOn))) addOn,
    },
    premiumUntil: expiry == null ? null : DateTime.tryParse(expiry),
    willRenew: premiumInfo?.willRenew ?? subscriptionId.isNotEmpty,
    plan: switch (planProductId) {
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
