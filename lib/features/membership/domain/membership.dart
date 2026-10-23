/// What a free account can and can't do, and what the paid tiers unlock.
library;

/// Features reserved for members. Anything not listed here is free.
enum PremiumFeature {
  navamsa,
  yogas,
  doshaDetails,
  transits,
  dashaTimeline,
  remedies,
  muhuratPlanner,
  compatibilityDetails,
  nameNumerology,
  unlimitedProfiles,
  kundliPdf,
  compatibilityPdf,
  vastuRemedies,
  pujaVidhi,
  vargaCharts,
  aiAstrologer,
  transitAlerts,
  strength,
  varshphal,
  kp,
}

/// One-time purchases that unlock a single feature for good.
enum AddOn {
  kundliPdf(PremiumFeature.kundliPdf),
  compatibilityPdf(PremiumFeature.compatibilityPdf),
  varshphalPdf(PremiumFeature.varshphal);

  final PremiumFeature feature;

  const AddOn(this.feature);
}

enum PlanPeriod { monthly, yearly }

/// Saved birth profiles a free account may keep.
const int freeProfileLimit = 2;

/// Store and RevenueCat identifiers. Create products and entitlements with
/// exactly these ids (see the setup guide).
class StoreIds {
  const StoreIds._();

  static const premiumEntitlement = 'premium';
  static const kundliPdfEntitlement = 'kundli_pdf';
  static const compatibilityPdfEntitlement = 'compatibility_pdf';
  static const varshphalPdfEntitlement = 'varshphal_pdf';

  static const monthly = 'rv_premium_monthly';
  static const yearly = 'rv_premium_yearly';
  static const kundliPdf = 'rv_kundli_pdf';
  static const compatibilityPdf = 'rv_compatibility_pdf';
  static const varshphalPdf = 'rv_varshphal_pdf';

  /// Consumable: [aiPackSize] more AI astrologer questions.
  static const aiQuestionPack = 'rv_ai_questions_10';

  /// Consumable: one detailed Vastu report for one property.
  static const vastuReport = 'rv_vastu_report';

  static String entitlementFor(AddOn addOn) => switch (addOn) {
    AddOn.kundliPdf => kundliPdfEntitlement,
    AddOn.compatibilityPdf => compatibilityPdfEntitlement,
    AddOn.varshphalPdf => varshphalPdfEntitlement,
  };

  static String productFor(AddOn addOn) => switch (addOn) {
    AddOn.kundliPdf => kundliPdf,
    AddOn.compatibilityPdf => compatibilityPdf,
    AddOn.varshphalPdf => varshphalPdf,
  };
}

class MembershipState {
  final bool premium;
  final Set<AddOn> addOns;

  /// When the current premium period ends (null when free or lifetime).
  final DateTime? premiumUntil;
  final bool willRenew;
  final PlanPeriod? plan;

  /// Store page where the user manages or cancels the subscription.
  final String? managementUrl;

  /// Store transaction ids of every Vastu report bought, one per property.
  final List<String> vastuReports;

  const MembershipState({
    this.premium = false,
    this.addOns = const {},
    this.premiumUntil,
    this.willRenew = false,
    this.plan,
    this.managementUrl,
    this.vastuReports = const [],
  });

  static const free = MembershipState();

  bool canUse(PremiumFeature feature) =>
      premium || addOns.any((a) => a.feature == feature);

  bool owns(AddOn addOn) => premium || addOns.contains(addOn);

  int? get profileLimit => premium ? null : freeProfileLimit;

  @override
  bool operator ==(Object other) =>
      other is MembershipState &&
      other.premium == premium &&
      other.addOns.length == addOns.length &&
      other.addOns.containsAll(addOns) &&
      other.premiumUntil == premiumUntil &&
      other.willRenew == willRenew &&
      other.plan == plan &&
      other.managementUrl == managementUrl &&
      _sameList(other.vastuReports, vastuReports);

  @override
  int get hashCode => Object.hash(
    premium,
    Object.hashAllUnordered(addOns),
    premiumUntil,
    willRenew,
    plan,
    managementUrl,
    Object.hashAll(vastuReports),
  );
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The Vastu report product as the store prices it for this user.
/// Questions added by one AI question pack.
const int aiPackSize = 10;

/// A pack of AI astrologer questions as the store prices it.
class AiPackOffer {
  final String priceLabel;
  final Object handle;

  const AiPackOffer({required this.priceLabel, required this.handle});
}

class VastuReportOffer {
  final String priceLabel;
  final Object handle;

  const VastuReportOffer({required this.priceLabel, required this.handle});
}

/// A subscription plan as the store prices it for this user.
class PlanOffer {
  final PlanPeriod period;
  final String priceLabel;
  final double price;
  final String currencyCode;

  /// Length of the free trial the store offers this user, if any.
  final int? trialDays;

  /// Opaque handle the purchases service uses to buy this plan.
  final Object handle;

  const PlanOffer({
    required this.period,
    required this.priceLabel,
    required this.price,
    required this.currencyCode,
    required this.handle,
    this.trialDays,
  });
}

class AddOnOffer {
  final AddOn addOn;
  final String priceLabel;
  final Object handle;

  const AddOnOffer({
    required this.addOn,
    required this.priceLabel,
    required this.handle,
  });
}

enum PurchaseOutcome { purchased, cancelled, pending, failed }

/// Yearly saving against twelve monthly payments, as a whole percentage.
int? yearlySavingPercent(List<PlanOffer> plans) {
  PlanOffer? find(PlanPeriod p) {
    for (final plan in plans) {
      if (plan.period == p) return plan;
    }
    return null;
  }

  final monthly = find(PlanPeriod.monthly);
  final yearly = find(PlanPeriod.yearly);
  if (monthly == null || yearly == null) return null;
  if (monthly.currencyCode != yearly.currencyCode || monthly.price <= 0) {
    return null;
  }
  final saving = 1 - yearly.price / (monthly.price * 12);
  if (saving <= 0) return null;
  return (saving * 100).round();
}
