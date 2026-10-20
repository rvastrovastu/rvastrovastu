import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rv_astro_vastu/features/membership/data/purchases_service.dart';
import 'package:rv_astro_vastu/features/membership/domain/membership.dart';
import 'package:rv_astro_vastu/features/membership/presentation/providers/membership_provider.dart';

/// Unlocks every Premium feature in widget tests of premium screens.
final premiumOverride = purchasesServiceProvider.overrideWithValue(
  const UnavailablePurchasesService(
    MembershipState(
      premium: true,
      addOns: {AddOn.kundliPdf, AddOn.compatibilityPdf},
    ),
  ),
);

/// A free account, for testing the locks.
final freeOverride = purchasesServiceProvider.overrideWithValue(
  const UnavailablePurchasesService(),
);
