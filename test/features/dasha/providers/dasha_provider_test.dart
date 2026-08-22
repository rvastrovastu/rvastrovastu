import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_birth_data.dart';
import 'package:rv_astro_vastu/features/dasha/presentation/providers/dasha_provider.dart';

void main() {
  final birthData = DashaBirthData(
    birthDate: DateTime(1983, 1, 3, 6, 0),
    moonLongitude: 120.0,
  );

  test('dashaTimelineProvider generates Mahadasha timeline', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final timeline = container.read(dashaTimelineProvider(birthData));

    expect(timeline.periods, isNotEmpty);
    expect(timeline.periods.length, 9);

    for (final period in timeline.periods) {
      expect(period.level, 1);
      expect(period.endDate.isAfter(period.startDate), isTrue);
    }
  });

  test('currentDashaProvider returns a Mahadasha when available', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final current = container.read(currentDashaProvider(birthData));

    if (current != null) {
      expect(current.level, 1);
      expect(current.endDate.isAfter(current.startDate), isTrue);
    }
  });

  test('currentDashaResultProvider returns Mahadasha and Antardasha', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container.read(currentDashaResultProvider(birthData));

    expect(result.mahadasha, isNotNull);

    if (result.mahadasha != null) {
      expect(result.mahadasha!.level, 1);
      expect(
        result.mahadasha!.endDate.isAfter(result.mahadasha!.startDate),
        isTrue,
      );
    }

    if (result.antardasha != null) {
      expect(result.antardasha!.level, 2);
      expect(
        result.antardasha!.endDate.isAfter(result.antardasha!.startDate),
        isTrue,
      );
    }
  });

  test('currentDashaProvider matches currentDashaResultProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container.read(currentDashaResultProvider(birthData));
    final current = container.read(currentDashaProvider(birthData));

    expect(current, equals(result.mahadasha));
  });

  test('currentAntardashaProvider matches currentDashaResultProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container.read(currentDashaResultProvider(birthData));
    final current = container.read(currentAntardashaProvider(birthData));

    expect(current, equals(result.antardasha));
  });

  test('current Antardasha belongs to current Mahadasha', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container.read(currentDashaResultProvider(birthData));

    if (result.mahadasha != null && result.antardasha != null) {
      expect(
        !result.antardasha!.startDate.isBefore(result.mahadasha!.startDate),
        isTrue,
      );

      expect(
        !result.antardasha!.endDate.isAfter(result.mahadasha!.endDate),
        isTrue,
      );
    }
  });

  test('antardashaTimelineProvider generates nine Antardashas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final timeline = container.read(dashaTimelineProvider(birthData));

    final mahadasha = timeline.periods.first;

    final antardashas = container.read(antardashaTimelineProvider(mahadasha));

    expect(antardashas.length, 9);

    for (final period in antardashas) {
      expect(period.level, 2);
      expect(period.endDate.isAfter(period.startDate), isTrue);
    }
  });

  test('pratyantardashaTimelineProvider generates nine periods', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final timeline = container.read(dashaTimelineProvider(birthData));

    final mahadasha = timeline.periods.first;

    final antardashas = container.read(antardashaTimelineProvider(mahadasha));

    final antardasha = antardashas.first;

    final pratyantardashas = container.read(
      pratyantardashaTimelineProvider(antardasha),
    );

    expect(pratyantardashas.length, 9);

    for (final period in pratyantardashas) {
      expect(period.level, 3);
      expect(period.endDate.isAfter(period.startDate), isTrue);
    }
  });

  test('Antardasha periods remain inside Mahadasha bounds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final timeline = container.read(dashaTimelineProvider(birthData));

    final mahadasha = timeline.periods.first;

    final antardashas = container.read(antardashaTimelineProvider(mahadasha));

    expect(antardashas.first.startDate, mahadasha.startDate);
    expect(antardashas.last.endDate, mahadasha.endDate);
  });

  test('Pratyantardasha periods remain inside Antardasha bounds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final timeline = container.read(dashaTimelineProvider(birthData));

    final mahadasha = timeline.periods.first;

    final antardashas = container.read(antardashaTimelineProvider(mahadasha));

    final antardasha = antardashas.first;

    final pratyantardashas = container.read(
      pratyantardashaTimelineProvider(antardasha),
    );

    expect(pratyantardashas.first.startDate, antardasha.startDate);
    expect(pratyantardashas.last.endDate, antardasha.endDate);
  });

  test('Dasha periods are chronologically ordered', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final timeline = container.read(dashaTimelineProvider(birthData));

    for (var i = 1; i < timeline.periods.length; i++) {
      final previous = timeline.periods[i - 1];
      final current = timeline.periods[i];

      expect(current.startDate, previous.endDate);
    }
  });
}
