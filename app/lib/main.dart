import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'piko_runtime.dart';
import 'shared/catalogs.dart';
import 'shared/copy_scope.dart';
import 'shared/interface_locale.dart';
import 'ui/piko_theme.dart';
import 'ui/components/piko_icon.dart';
import 'ui/components/piko_page_navigation.dart';

void main() {
  registerPikoIconLicenses();
  runApp(const PikoApp());
}

class PikoApp extends StatefulWidget {
  const PikoApp({this.locale, this.localeController, this.home, super.key});

  final Locale? locale;
  final InterfaceLocaleController? localeController;
  final Widget? home;
  static const supportedLocales = InterfaceLocaleController.supportedLocales;

  @override
  State<PikoApp> createState() => _PikoAppState();
}

class _PikoAppState extends State<PikoApp> {
  final _pageObserver = RouteObserver<PageRoute<dynamic>>();
  InterfaceLocaleController? _owned;
  InterfaceLocaleController get _controller =>
      widget.localeController ??
      (_owned ??= InterfaceLocaleController(widget.locale));

  @override
  void didUpdateWidget(PikoApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localeController != null && _owned != null) {
      _owned!.dispose();
      _owned = null;
    } else if (widget.localeController == null &&
        oldWidget.locale != widget.locale) {
      _controller.value = InterfaceLocaleController.resolve(widget.locale);
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InterfaceLocaleScope(
      controller: _controller,
      child: ValueListenableBuilder<Locale>(
        valueListenable: _controller,
        builder: (context, selected, child) => _localizedApp(selected),
      ),
    );
  }

  Widget _localizedApp(Locale selected) {
    return PikoCopyScope(
      copy: PikoCopy(selected.languageCode),
      child: Builder(
        builder: (context) => MaterialApp(
          navigatorObservers: [_pageObserver],
          builder: (context, child) =>
              PikoPageNavigation(observer: _pageObserver, child: child!),
          locale: selected,
          supportedLocales: PikoApp.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          title: PikoCopyScope.of(context).text('app.name'),
          theme: PikoTheme.build(),
          debugShowCheckedModeBanner: false,
          home: widget.home ?? const PikoRuntime(),
        ),
      ),
    );
  }
}
