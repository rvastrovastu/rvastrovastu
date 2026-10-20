import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/membership/domain/membership.dart';
import 'package:rv_astro_vastu/features/membership/presentation/providers/membership_provider.dart';

import 'fake_purchases_service.dart';

void main() {
  test('free accounts get nothing premium and two profiles', () {
    const free = MembershipState.free;
    for (final feature in PremiumFeature.values) {
      expect(free.canUse(feature), isFalse, reason: feature.name);
    }
    expect(free.profileLimit, freeProfileLimit);
    expect(freeProfileLimit, 2);
  });

  test('premium unlocks everything with no profile limit', () {
    const premium = MembershipState(premium: true);
    expect(PremiumFeature.values.every(premium.canUse), isTrue);
    expect(premium.profileLimit, isNull);
    expect(premium.owns(AddOn.kundliPdf), isTrue);
  });

  test('an add-on unlocks only its own feature', () {
    const state = MembershipState(addOns: {AddOn.kundliPdf});
    expect(state.canUse(PremiumFeature.kundliPdf), isTrue);
    expect(state.canUse(PremiumFeature.compatibilityPdf), isFalse);
    expect(state.canUse(PremiumFeature.remedies), isFalse);
    expect(state.owns(AddOn.kundliPdf), isTrue);
  });

  test('yearly saving against twelve months', () {
    // $11.99 against 12 x $1.19 = $14.28.
    expect(yearlySavingPercent(FakePurchasesService.usPlans()), 16);
    expect(yearlySavingPercent(const []), isNull);
  });

  test('membership equality ignores add-on order', () {
    expect(
      const MembershipState(
        addOns: {AddOn.kundliPdf, AddOn.compatibilityPdf},
      ),
      const MembershipState(
        addOns: {AddOn.compatibilityPdf, AddOn.kundliPdf},
      ),
    );
  });

  test('free accounts can save two profiles, Premium any number', () {
    expect(canAddProfile(null, 0), isTrue);
    expect(canAddProfile(MembershipState.free, 1), isTrue);
    expect(canAddProfile(MembershipState.free, 2), isFalse);
    expect(
      canAddProfile(const MembershipState(addOns: {AddOn.kundliPdf}), 2),
      isFalse,
    );
    expect(canAddProfile(const MembershipState(premium: true), 40), isTrue);
  });
}
