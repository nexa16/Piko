import 'package:flutter/widgets.dart';
import 'catalogs.dart';

/// One catalog access point for interface text and accessible labels.
class PikoCopyScope extends InheritedWidget {
  const PikoCopyScope({required this.copy, required super.child, super.key});
  final PikoCopy copy;

  static PikoCopy of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PikoCopyScope>();
    if (scope == null) {
      throw StateError('PikoCopyScope is missing above this widget');
    }
    return scope.copy;
  }

  @override
  bool updateShouldNotify(PikoCopyScope oldWidget) =>
      copy.locale != oldWidget.copy.locale;
}
