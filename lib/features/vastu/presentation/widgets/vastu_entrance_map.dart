import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../domain/entities/vastu_entry_direction.dart';
import '../../domain/entities/vastu_entry_segment.dart';

class VastuEntranceMap extends StatelessWidget {
  const VastuEntranceMap({
    super.key,
    required this.selectedSegment,
    required this.onSegmentSelected,
  });

  final VastuEntrySegment selectedSegment;
  final ValueChanged<VastuEntrySegment> onSegmentSelected;

  static const _northSegments = <VastuEntrySegment>[
    VastuEntrySegment.n1,
    VastuEntrySegment.n2,
    VastuEntrySegment.n3,
    VastuEntrySegment.n4,
    VastuEntrySegment.n5,
    VastuEntrySegment.n6,
    VastuEntrySegment.n7,
    VastuEntrySegment.n8,
  ];

  static const _eastSegments = <VastuEntrySegment>[
    VastuEntrySegment.e1,
    VastuEntrySegment.e2,
    VastuEntrySegment.e3,
    VastuEntrySegment.e4,
    VastuEntrySegment.e5,
    VastuEntrySegment.e6,
    VastuEntrySegment.e7,
    VastuEntrySegment.e8,
  ];

  static const _southSegments = <VastuEntrySegment>[
    VastuEntrySegment.s1,
    VastuEntrySegment.s2,
    VastuEntrySegment.s3,
    VastuEntrySegment.s4,
    VastuEntrySegment.s5,
    VastuEntrySegment.s6,
    VastuEntrySegment.s7,
    VastuEntrySegment.s8,
  ];

  static const _westSegments = <VastuEntrySegment>[
    VastuEntrySegment.w1,
    VastuEntrySegment.w2,
    VastuEntrySegment.w3,
    VastuEntrySegment.w4,
    VastuEntrySegment.w5,
    VastuEntrySegment.w6,
    VastuEntrySegment.w7,
    VastuEntrySegment.w8,
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: const Key('vastu-entrance-map'),
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final houseInset = size.width * 0.23;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),

              Positioned(
                left: houseInset,
                top: houseInset,
                right: houseInset,
                bottom: houseInset,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      context.l10n.house.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              ..._buildNorthSegments(size),
              ..._buildSouthSegments(size),
              ..._buildWestSegments(size),
              ..._buildEastSegments(size),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildNorthSegments(Size size) {
    return List.generate(8, (index) {
      final segment = _northSegments[index];

      return _segment(
        segment: segment,
        left: size.width * (index / 8),
        top: 0,
        width: size.width / 8,
        height: size.height * 0.20,
      );
    });
  }

  List<Widget> _buildSouthSegments(Size size) {
    return List.generate(8, (index) {
      final segment = _southSegments[index];

      return _segment(
        segment: segment,
        left: size.width * (index / 8),
        top: size.height * 0.80,
        width: size.width / 8,
        height: size.height * 0.20,
      );
    });
  }

  List<Widget> _buildWestSegments(Size size) {
    return List.generate(8, (index) {
      final segment = _westSegments[index];

      return _segment(
        segment: segment,
        left: 0,
        top: size.height * (0.20 + (index * 0.075)),
        width: size.width * 0.20,
        height: size.height * 0.075,
      );
    });
  }

  List<Widget> _buildEastSegments(Size size) {
    return List.generate(8, (index) {
      final segment = _eastSegments[index];

      return _segment(
        segment: segment,
        left: size.width * 0.80,
        top: size.height * (0.20 + (index * 0.075)),
        width: size.width * 0.20,
        height: size.height * 0.075,
      );
    });
  }

  Widget _segment({
    required VastuEntrySegment segment,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final isSelected = segment == selectedSegment;

        final directionLabel = switch (segment.direction) {
          VastuEntryDirection.north => context.l10n.vastuNorth,
          VastuEntryDirection.east => context.l10n.vastuEast,
          VastuEntryDirection.south => context.l10n.vastuSouth,
          VastuEntryDirection.west => context.l10n.vastuWest,
          VastuEntryDirection.northeast => segment.direction.name,
          VastuEntryDirection.southeast => segment.direction.name,
          VastuEntryDirection.southwest => segment.direction.name,
          VastuEntryDirection.northwest => segment.direction.name,
        };

        final semanticsLabel = '$directionLabel ${segment.code}';

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          key: Key('vastu-map-segment-${segment.code}'),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                key: Key('vastu-map-semantics-${segment.code}'),
                container: true,
                button: true,
                selected: isSelected,
                excludeSemantics: true,
                label: semanticsLabel,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSegmentSelected(segment),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        segment.code,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
