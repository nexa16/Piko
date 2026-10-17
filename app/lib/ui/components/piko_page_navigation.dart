import 'package:flutter/material.dart';

/// Observes actual page departures, excluding same-page PopupRoutes.
class PikoPageNavigation extends InheritedWidget {
  const PikoPageNavigation({
    super.key,
    required this.observer,
    required super.child,
  });
  final RouteObserver<PageRoute<dynamic>> observer;
  static RouteObserver<PageRoute<dynamic>>? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PikoPageNavigation>()
          ?.observer;
  @override
  bool updateShouldNotify(PikoPageNavigation oldWidget) =>
      observer != oldWidget.observer;
}
