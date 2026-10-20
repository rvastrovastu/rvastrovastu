import 'vastu_category.dart';

class VastuTip {
  const VastuTip({
    required this.title,
    required this.description,
    required this.direction,
    required this.action,
    required this.category,
  });

  final String title;
  final String description;
  final String direction;
  final String action;
  final VastuCategory category;
}
