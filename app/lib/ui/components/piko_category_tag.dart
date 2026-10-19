import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../data/category_tag_roles.dart';
import '../piko_theme.dart';

class PikoCategoryTag extends StatelessWidget {
  const PikoCategoryTag({required this.group, required this.label, super.key});
  final CategoryDimensionRecord group;
  final String label;
  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: d.dimension('spacing.2'),
        vertical: d.dimension('spacing.1'),
      ),
      decoration: BoxDecoration(
        color: d.color(categoryTagRole(group.tagColorRole, group.id)),
        borderRadius: BorderRadius.circular(
          d.dimension('components.buttons.radius'),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: d.color(d.text('categoryTags.foreground')),
          fontSize: d.dimension('typography.small'),
        ),
      ),
    );
  }
}
