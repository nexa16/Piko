import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../data/categories_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_checkbox.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

/// Returns one confirmed dimension draft. Dismissal returns null. The caller
/// merges it into its vocabulary draft and owns the eventual assignment write.
Future<CategoryAssignmentRecord?> showCategoryAssignmentPicker(
  BuildContext context, {
  required String? entryId,
  required CategoryDimensionRecord dimension,
  required CategoriesRepository repository,
  Set<String>? initialValueIds,
  ValueChanged<Future<void>>? onPendingWrites,
}) {
  final key = GlobalKey<_CategoryAssignmentPickerState>();
  return showPikoDialog<CategoryAssignmentRecord>(
    context,
    canDismiss: () => key.currentState?.pending != true,
    builder: (_) => CategoryAssignmentPicker(
      key: key,
      entryId: entryId,
      dimension: dimension,
      repository: repository,
      initialValueIds: initialValueIds,
      onPendingWrites: onPendingWrites,
    ),
  );
}

class CategoryAssignmentPicker extends StatefulWidget {
  const CategoryAssignmentPicker({
    super.key,
    required this.entryId,
    required this.dimension,
    required this.repository,
    this.initialValueIds,
    this.onPendingWrites,
  });
  final String? entryId;
  final CategoryDimensionRecord dimension;
  final CategoriesRepository repository;
  final Set<String>? initialValueIds;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<CategoryAssignmentPicker> createState() =>
      _CategoryAssignmentPickerState();
}

class _CategoryAssignmentPickerState extends State<CategoryAssignmentPicker> {
  final query = TextEditingController(), newValueName = TextEditingController();
  final newValueFocus = FocusNode();
  final listScroll = ScrollController();
  final fullList = GlobalKey(), search = GlobalKey(), creation = GlobalKey();
  StreamSubscription<List<CategoryValueRecord>>? valuesSubscription;
  List<CategoryValueRecord> values = const [];
  Set<String> opening = const {}, selected = const {};
  late CategoryDimensionRecord dimension;
  bool ready = false, pending = false, overflow = false, scheduled = false;
  Object? error;
  Object? valueError;
  bool creatingValue = false;
  int generation = 0;
  double fullHeight = 0, searchHeight = 0, creationHeight = 0;
  bool get changed => !setEquals(opening, selected);

  @override
  void initState() {
    super.initState();
    dimension = widget.dimension;
    track(load());
  }

  void track(Future<void> accepted) => widget.onPendingWrites?.call(accepted);

  @override
  void didUpdateWidget(CategoryAssignmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId ||
        oldWidget.repository != widget.repository ||
        oldWidget.dimension.id != widget.dimension.id ||
        oldWidget.dimension.collectionId != widget.dimension.collectionId) {
      dimension = widget.dimension;
      creatingValue = false;
      valueError = null;
      newValueName.clear();
      track(load());
    }
  }

  bool owned(int revision) => mounted && generation == revision;

  Future<void> load() async {
    final revision = ++generation;
    final repository = widget.repository;
    final requested = widget.dimension;
    final initial = widget.initialValueIds == null
        ? null
        : Set<String>.of(widget.initialValueIds!);
    final entryId = widget.entryId;
    await valuesSubscription?.cancel();
    if (!owned(revision)) return;
    setState(() {
      ready = false;
      pending = false;
      error = null;
    });
    try {
      final actual = await repository.dimensionById(requested.id);
      if (actual == null || actual.collectionId != requested.collectionId) {
        throw CategoryValidation.dimensionNotFound;
      }
      final assignments = initial == null && entryId != null
          ? await repository.assignments(entryId)
          : const <CategoryAssignmentRecord>[];
      final existing =
          initial ??
          assignments
              .where((row) => row.dimensionId == actual.id)
              .firstOrNull
              ?.valueIds ??
          const <String>{};
      final loaded = await repository.values(actual.id);
      if (!owned(revision)) return;
      setState(() {
        dimension = actual;
        opening = Set.unmodifiable(existing);
        selected = Set.unmodifiable(existing);
        values = List.unmodifiable(loaded);
        ready = true;
      });
      valuesSubscription = repository
          .watchValues(actual.id)
          .listen(
            (next) {
              if (!owned(revision)) return;
              setState(() {
                values = List.unmodifiable(next);
              });
            },
            onError: (Object failure) {
              if (owned(revision)) {
                setState(() {
                  error = failure;
                });
              }
            },
          );
    } catch (failure) {
      if (owned(revision)) {
        setState(() {
          error = failure;
        });
      }
    }
  }

  Future<void> apply() async {
    if (!ready ||
        pending ||
        !changed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final revision = generation;
    final result = Set<String>.unmodifiable(selected);
    setState(() {
      pending = true;
      error = null;
    });
    try {
      final actual = await widget.repository.dimensionById(dimension.id);
      final currentValues = await widget.repository.values(dimension.id);
      if (!mounted || !owned(revision)) return;
      if (ModalRoute.of(context)?.isCurrent != true) {
        setState(() {
          pending = false;
        });
        return;
      }
      if (actual == null ||
          actual.collectionId != dimension.collectionId ||
          !currentValues.map((value) => value.id).toSet().containsAll(result) ||
          (actual.mode == CategoryMode.single && result.length > 1)) {
        throw CategoryValidation.cardinalityViolation;
      }
      Navigator.of(context).pop(
        CategoryAssignmentRecord(dimensionId: dimension.id, valueIds: result),
      );
    } catch (failure) {
      if (owned(revision)) {
        setState(() {
          pending = false;
          error = failure;
        });
      }
    }
  }

  Future<void> createValue() async {
    if (!ready ||
        pending ||
        !creatingValue ||
        newValueName.text.isEmpty ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final revision = generation;
    final snapshot = newValueName.text;
    setState(() {
      pending = true;
      valueError = null;
    });
    try {
      final actual = await widget.repository.dimensionById(dimension.id);
      if (!mounted || !owned(revision)) return;
      if (ModalRoute.of(context)?.isCurrent != true) {
        setState(() {
          pending = false;
        });
        return;
      }
      if (actual == null || actual.collectionId != dimension.collectionId) {
        throw CategoryValidation.dimensionNotFound;
      }
      final saved = await widget.repository.createValue(
        dimensionId: dimension.id,
        name: snapshot,
      );
      if (!owned(revision)) return;
      if (saved.dimensionId != dimension.id) {
        throw CategoryValidation.invalidOwnership;
      }
      setState(() {
        // Definition creation never changes the staged assignment set/query.
        if (!values.any((value) => value.id == saved.id)) {
          values = List.unmodifiable([...values, saved]);
        }
        creatingValue = false;
        pending = false;
        newValueName.clear();
      });
      newValueFocus.unfocus();
    } catch (failure) {
      if (owned(revision)) {
        setState(() {
          pending = false;
          valueError = failure;
        });
      }
    }
  }

  void measure(double baseCap) {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted) return;
      double height(GlobalKey key) {
        final box = key.currentContext?.findRenderObject();
        return box is RenderBox && box.hasSize ? box.size.height : 0;
      }

      final nextFull = height(fullList), nextSearch = height(search);
      final nextCreation = height(creation);
      final nextOverflow = nextFull > baseCap + .5;
      if ((fullHeight - nextFull).abs() > .5 ||
          (searchHeight - nextSearch).abs() > .5 ||
          (creationHeight - nextCreation).abs() > .5 ||
          overflow != nextOverflow) {
        setState(() {
          fullHeight = nextFull;
          searchHeight = nextSearch;
          creationHeight = nextCreation;
          overflow = nextOverflow;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), design = pikoDesign;
    final buildGeneration = generation;
    final minRow = design.dimension('components.buttons.height');
    final media = MediaQuery.of(context);
    final contentWidth = math.max(
      1.0,
      math.min(
            design.dimension('components.dialogs.maxWidth'),
            media.size.width - design.dimension('spacing.4') * 2,
          ) -
          design.dimension('spacing.6') * 2,
    );
    final title =
        TextPainter(
          textDirection: Directionality.of(context),
          textScaler: media.textScaler,
          text: TextSpan(
            text: dimension.name,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontSize: design.dimension('components.dialogs.titleSize'),
              fontWeight: design.weight('typography.titleWeight'),
            ),
          ),
        )..layout(
          maxWidth: math.max(
            1.0,
            contentWidth -
                design.dimension('controls.largeHeight') -
                design.dimension('spacing.3') -
                design.dimension('components.icons.size') -
                design.dimension('spacing.2'),
          ),
        );
    final footer = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: media.textScaler,
      text: TextSpan(
        text: copy.text('r2.apply'),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    )..layout(maxWidth: contentWidth);
    final chrome =
        design.dimension('spacing.4') * 2 +
        design.dimension('spacing.6') * 2 +
        math.max(title.height, design.dimension('controls.largeHeight')) +
        design.dimension('spacing.3') +
        math.max(minRow, footer.height + design.dimension('spacing.2') * 2) +
        design.dimension('spacing.4');
    title.dispose();
    footer.dispose();
    final baseCap = math.max(
      minRow,
      math.min(
        design.dimension('components.categoryPicker.listHeight'),
        media.size.height -
            media.viewInsets.bottom -
            media.padding.vertical -
            chrome -
            math.max(minRow, creationHeight),
      ),
    );
    final showSearch = overflow || query.text.isNotEmpty;
    final cap = math.max(minRow, baseCap - (showSearch ? searchHeight : 0));
    final needle = query.text.trim().toLowerCase();
    final filtered = values
        .where((value) => value.name.toLowerCase().contains(needle))
        .toList();
    measure(baseCap);
    Widget row(CategoryValueRecord value, {bool measuring = false}) =>
        PikoCheckbox(
          key: measuring ? null : ValueKey('category-value-${value.id}'),
          label: value.name,
          value: selected.contains(value.id),
          onChanged: measuring || pending
              ? null
              : (checked) {
                  if (!owned(buildGeneration) ||
                      pending ||
                      !ready ||
                      ModalRoute.of(context)?.isCurrent != true) {
                    return;
                  }
                  setState(() {
                    final next =
                        dimension.mode == CategoryMode.single && checked
                        ? <String>{}
                        : {...selected};
                    if (checked) {
                      next.add(value.id);
                    } else {
                      next.remove(value.id);
                    }
                    selected = Set.unmodifiable(next);
                    error = null;
                  });
                },
        );
    return PikoDialog(
      title: dimension.name,
      purpose: PikoDialogPurpose.selection,
      onBack: () {
        if (!pending && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      },
      dismissible: !pending,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!ready && error == null) const LinearProgressIndicator(),
          if (ready) ...[
            if (showSearch)
              Padding(
                key: search,
                padding: EdgeInsets.only(bottom: design.dimension('spacing.2')),
                child: PikoTextField(
                  key: const ValueKey('category-value-search'),
                  label: copy.text('r2.categorySearch'),
                  controller: query,
                  enabled: !pending,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Stack(
              children: [
                Offstage(
                  child: ExcludeFocus(
                    child: ExcludeSemantics(
                      child: Column(
                        key: fullList,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final value in values)
                            row(value, measuring: true),
                        ],
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: cap),
                  child: PikoAnchoredBoxScrollView(
                    key: const ValueKey('category-value-list'),
                    controller: listScroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (filtered.isEmpty)
                          Text(
                            copy.text(
                              values.isEmpty
                                  ? 'category.emptyValues'
                                  : 'r2.noValueMatches',
                            ),
                          ),
                        for (final value in filtered) row(value),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              key: creation,
              padding: EdgeInsets.only(top: design.dimension('spacing.2')),
              child: creatingValue
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: PikoTextField(
                                key: const ValueKey('category-new-value-name'),
                                label: copy.text('r2.valueName'),
                                controller: newValueName,
                                focusNode: newValueFocus,
                                enabled: !pending,
                                textInputAction: TextInputAction.done,
                                onEditingComplete: () {},
                                onSubmitted: (_) {
                                  if (owned(buildGeneration)) {
                                    track(createValue());
                                  }
                                },
                                onChanged: (_) => setState(() {
                                  valueError = null;
                                }),
                              ),
                            ),
                            if (newValueName.text.isNotEmpty) ...[
                              SizedBox(width: design.dimension('spacing.2')),
                              PikoIconButton(
                                icon: const PikoIcon(PikoIconName.check),
                                semanticLabel: copy.text('r2.saveValue'),
                                large: true,
                                variant: PikoButtonVariant.primary,
                                onPressed: pending
                                    ? null
                                    : () {
                                        if (owned(buildGeneration)) {
                                          track(createValue());
                                        }
                                      },
                              ),
                            ],
                          ],
                        ),
                        if (valueError != null)
                          Text(
                            copy.text(
                              valueError is CategoryValidation
                                  ? 'r2.valueInvalid'
                                  : 'category.valueSaveFailed',
                            ),
                            style: TextStyle(color: design.color('danger')),
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PikoButton(
                            label: copy.text('action.cancel'),
                            variant: PikoButtonVariant.ghost,
                            onPressed: pending
                                ? null
                                : () {
                                    if (!owned(buildGeneration)) return;
                                    setState(() {
                                      creatingValue = false;
                                      valueError = null;
                                      newValueName.clear();
                                    });
                                  },
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PikoButton(
                        label: copy.text('r2.addValue'),
                        variant: PikoButtonVariant.ghost,
                        onPressed: pending
                            ? null
                            : () {
                                if (!owned(buildGeneration) ||
                                    ModalRoute.of(context)?.isCurrent != true) {
                                  return;
                                }
                                setState(() {
                                  creatingValue = true;
                                  valueError = null;
                                });
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (owned(buildGeneration) && creatingValue) {
                                    newValueFocus.requestFocus();
                                  }
                                });
                              },
                      ),
                    ),
            ),
          ],
          if (error != null) ...[
            Text(
              copy.text(
                error is CategoryValidation
                    ? 'category.selectionInvalid'
                    : 'category.loadFailed',
              ),
              style: TextStyle(color: design.color('danger')),
            ),
            if (!ready)
              PikoButton(
                label: copy.text('action.retry'),
                onPressed: () => track(load()),
              ),
          ],
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('r2.apply'),
          icon: const PikoIcon(PikoIconName.check),
          onPressed: !ready || !changed || pending
              ? null
              : () => track(apply()),
        ),
      ],
    );
  }

  @override
  void dispose() {
    generation++;
    unawaited(valuesSubscription?.cancel());
    query.dispose();
    newValueName.dispose();
    newValueFocus.dispose();
    listScroll.dispose();
    super.dispose();
  }
}
