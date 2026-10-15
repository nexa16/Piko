import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import 'collection_view_scope.dart';

/// Session-only search. Matching and combined category constraints belong to
/// the Collection query; this control preserves the exact query the user typed.
class CollectionSearchField extends StatefulWidget {
  const CollectionSearchField({
    required this.scope,
    this.enabled = true,
    super.key,
  });
  final CollectionViewScope scope;
  final bool enabled;
  @override
  State<CollectionSearchField> createState() => _CollectionSearchFieldState();
}

class _CollectionSearchFieldState extends State<CollectionSearchField> {
  late final _text = TextEditingController(text: widget.scope.search);
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    widget.scope.addListener(_sync);
  }

  void _sync() {
    if (_text.text != widget.scope.search) {
      _text.value = TextEditingValue(
        text: widget.scope.search,
        selection: TextSelection.collapsed(offset: widget.scope.search.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CollectionSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      oldWidget.scope.removeListener(_sync);
      widget.scope.addListener(_sync);
      _sync();
    }
  }

  bool _canChange(CollectionViewScope expected) =>
      mounted &&
      widget.enabled &&
      identical(expected, widget.scope) &&
      ModalRoute.of(context)?.isCurrent == true;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final scope = widget.scope;
    return Semantics(
      label: copy.text('collection.search'),
      child: TextField(
        key: const ValueKey('collection-search'),
        controller: _text,
        focusNode: _focus,
        enabled: widget.enabled,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          if (_canChange(scope)) scope.setSearch(value);
        },
        decoration: pikoInputDecoration().copyWith(
          hintText: copy.text('collection.search'),
          prefixIcon: Padding(
            padding: EdgeInsets.all(pikoDesign.dimension('spacing.3')),
            child: const PikoIcon(PikoIconName.search),
          ),
          suffixIcon: scope.search.isEmpty
              ? null
              : PikoIconButton(
                  key: const ValueKey('collection-clear-search'),
                  semanticLabel: copy.text('r2.clearSearch'),
                  icon: const PikoIcon(PikoIconName.x),
                  large: true,
                  onPressed: !widget.enabled
                      ? null
                      : () {
                          if (!_canChange(scope)) return;
                          scope.setSearch('');
                          _focus.requestFocus();
                        },
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.scope.removeListener(_sync);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }
}
