import '../../domain/entities/vastu_category.dart';
import '../../domain/entities/vastu_tip.dart';
import '../../domain/repositories/vastu_tip_repository.dart';

class LocalVastuTipRepository implements VastuTipRepository {
  const LocalVastuTipRepository();

  static const _tips = <VastuTip>[
    VastuTip(
      title: 'Keep the entrance clear',
      category: VastuCategory.entrance,
      description:
          'A clean and welcoming entrance helps maintain a positive flow of energy into the home.',
      direction: 'Entrance',
      action:
          'Remove unnecessary shoes, boxes, clutter and unused items from the entrance area.',
    ),
    VastuTip(
      title: 'Brighten the northeast',
      category: VastuCategory.northeast,
      description:
          'The northeast is traditionally associated with clarity, openness and positive energy.',
      direction: 'Northeast',
      action: 'Keep the northeast area clean, open and well lit.',
    ),
    VastuTip(
      title: 'Keep the centre open',
      category: VastuCategory.centre,
      description:
          'An uncluttered centre helps maintain a balanced and spacious feeling within the home.',
      direction: 'Centre',
      action:
          'Avoid unnecessary heavy storage or clutter in the central area of the home.',
    ),
    VastuTip(
      title: 'Balance the southwest',
      category: VastuCategory.southwest,
      description:
          'The southwest is traditionally associated with stability and grounding.',
      direction: 'Southwest',
      action:
          'Keep the southwest stable, organized and suitable for heavier furnishings.',
    ),
  ];

  @override
  VastuTip getTipForDate(DateTime date) {
    final dayIndex = date.difference(DateTime(2026, 1, 1)).inDays;
    final index = dayIndex % _tips.length;

    return _tips[index < 0 ? index + _tips.length : index];
  }
}
