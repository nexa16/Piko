import 'package:flutter/material.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../data/categories_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

/// Embedded under the Collection menu's Edit categories expansion. This widget
/// owns no navigation page and never writes vocabulary text or learning.
class CategoryManagement extends StatefulWidget {
  const CategoryManagement({
    super.key,
    required this.collectionId,
    required this.repository,
    this.onPendingWrites,
    this.onPendingChanged,
  });
  final String collectionId;
  final CategoriesRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool>? onPendingChanged;
  @override
  State<CategoryManagement> createState() => _CategoryManagementState();
}

typedef _Execute = Future<T> Function<T>(Future<T> Function() operation);

class _CategoryManagementState extends State<CategoryManagement> {
  late Stream<List<CategoryDimensionRecord>> dimensions;
  bool pending = false, creating = false;
  final expanded = <String>{};
  int generation = 0;
  @override
  void initState() {
    super.initState();
    dimensions = widget.repository.watchDimensions(widget.collectionId);
  }

  @override
  void didUpdateWidget(CategoryManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId ||
        oldWidget.repository != widget.repository) {
      generation++;
      pending = false;
      creating = false;
      expanded.clear();
      dimensions = widget.repository.watchDimensions(widget.collectionId);
    }
  }

  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!mounted || pending) {
      throw StateError('Category write unavailable');
    }
    final revision = generation;
    final changed = widget.onPendingChanged;
    setState(() {
      pending = true;
    });
    changed?.call(true);
    try {
      final accepted = operation();
      widget.onPendingWrites?.call(
        accepted.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {},
        ),
      );
      return await accepted;
    } finally {
      if (mounted && generation == revision) {
        setState(() {
          pending = false;
        });
        changed?.call(false);
      }
    }
  }

  Future<void> remove(
    CategoryDimensionRecord dimension, {
    CategoryValueRecord? value,
  }) async {
    if (!mounted ||
        pending ||
        dimension.collectionId != widget.collectionId ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final repository = widget.repository;
    final revision = generation;
    await showPikoDialog<bool>(
      context,
      builder: (_) => _DeleteCategory(
        dimension: dimension,
        value: value,
        canWrite: () => mounted && generation == revision,
        execute: execute,
        delete: () => value == null
            ? repository.deleteDimension(dimension.id)
            : repository.deleteValue(value.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final owner = generation;
    return StreamBuilder<List<CategoryDimensionRecord>>(
      stream: dimensions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              Text(copy.text('category.managementLoadFailed')),
              PikoButton(
                label: copy.text('action.retry'),
                onPressed: pending
                    ? null
                    : () {
                        if (!mounted || generation != owner) return;
                        setState(() {
                          dimensions = widget.repository.watchDimensions(
                            widget.collectionId,
                          );
                        });
                      },
              ),
            ],
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.data!.isEmpty) Text(copy.text('r2.noCategories')),
            for (final dimension in snapshot.data!)
              _DimensionBranch(
                key: ValueKey(dimension.id),
                dimension: dimension,
                repository: widget.repository,
                pending: pending,
                execute: execute,
                initiallyExpanded: expanded.contains(dimension.id),
                onExpanded: (isExpanded) {
                  if (isExpanded) {
                    expanded.add(dimension.id);
                  } else {
                    expanded.remove(dimension.id);
                  }
                },
                onDelete: () => remove(dimension),
              ),
            if (creating)
              _DimensionEditor(
                key: ValueKey('new-dimension-$owner'),
                collectionId: widget.collectionId,
                repository: widget.repository,
                pending: pending,
                execute: execute,
                onCancel: () => setState(() {
                  creating = false;
                }),
                onSaved: (dimension) {
                  if (!mounted || generation != owner) return;
                  setState(() {
                    creating = false;
                    expanded.add(dimension.id);
                  });
                },
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PikoButton(
                  label: copy.text('category.addDimension'),
                  icon: const PikoIcon(PikoIconName.plus),
                  variant: PikoButtonVariant.ghost,
                  onPressed: pending
                      ? null
                      : () {
                          if (!mounted || generation != owner) return;
                          setState(() {
                            creating = true;
                          });
                        },
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }
}

class _DimensionBranch extends StatefulWidget {
  const _DimensionBranch({
    super.key,
    required this.dimension,
    required this.repository,
    required this.pending,
    required this.execute,
    required this.initiallyExpanded,
    required this.onExpanded,
    required this.onDelete,
  });
  final CategoryDimensionRecord dimension;
  final CategoriesRepository repository;
  final bool pending, initiallyExpanded;
  final _Execute execute;
  final ValueChanged<bool> onExpanded;
  final VoidCallback onDelete;
  @override
  State<_DimensionBranch> createState() => _DimensionBranchState();
}

class _DimensionBranchState extends State<_DimensionBranch> {
  final _anchorHeader = GlobalKey();
  late Stream<List<CategoryValueRecord>> values;
  bool creating = false;
  @override
  void initState() {
    super.initState();
    values = widget.repository.watchValues(widget.dimension.id);
  }

  @override
  void didUpdateWidget(_DimensionBranch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      values = widget.repository.watchValues(widget.dimension.id);
    }
  }

  Future<void> deleteValue(CategoryValueRecord value) async {
    if (!mounted ||
        widget.pending ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final repository = widget.repository,
        dimension = widget.dimension,
        execute = widget.execute;
    await showPikoDialog<bool>(
      context,
      builder: (_) => _DeleteCategory(
        dimension: dimension,
        value: value,
        execute: execute,
        canWrite: () =>
            mounted &&
            widget.repository == repository &&
            widget.dimension.id == dimension.id,
        delete: () => repository.deleteValue(value.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return ExpansionTile(
      key: ValueKey('category-dimension-${widget.dimension.id}'),
      title: PikoAnchorRegion(
        key: _anchorHeader,
        child: Text(widget.dimension.name),
      ),
      initiallyExpanded: widget.initiallyExpanded,
      maintainState: true,
      onExpansionChanged: (expanded) {
        final header = _anchorHeader.currentContext;
        if (header != null) PikoAnchorRegion.capture(header);
        widget.onExpanded(expanded);
      },
      children: [
        _DimensionEditor(
          key: ValueKey('dimension-form-${widget.dimension.id}'),
          collectionId: widget.dimension.collectionId,
          dimension: widget.dimension,
          repository: widget.repository,
          pending: widget.pending,
          execute: widget.execute,
        ),
        StreamBuilder<List<CategoryValueRecord>>(
          stream: values,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(copy.text('category.managementLoadFailed')),
                  PikoButton(
                    label: copy.text('action.retry'),
                    onPressed: widget.pending
                        ? null
                        : () {
                            setState(() {
                              values = widget.repository.watchValues(
                                widget.dimension.id,
                              );
                            });
                          },
                  ),
                ],
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return Column(
              children: [
                for (final value in snapshot.data!)
                  _ValueEditor(
                    key: ValueKey(value.id),
                    value: value,
                    dimension: widget.dimension,
                    repository: widget.repository,
                    pending: widget.pending,
                    execute: widget.execute,
                    onDelete: () => deleteValue(value),
                  ),
              ],
            );
          },
        ),
        if (creating)
          _ValueEditor(
            key: ValueKey('new-value-${widget.dimension.id}'),
            dimension: widget.dimension,
            repository: widget.repository,
            pending: widget.pending,
            execute: widget.execute,
            onDone: () {
              if (mounted) {
                setState(() {
                  creating = false;
                });
              }
            },
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PikoButton(
              label: copy.text('r2.addValue'),
              icon: const PikoIcon(PikoIconName.plus),
              variant: PikoButtonVariant.ghost,
              onPressed: widget.pending
                  ? null
                  : () => setState(() {
                      creating = true;
                    }),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PikoButton(
            label: copy.text('category.deleteDimension'),
            icon: const PikoIcon(PikoIconName.trash),
            variant: PikoButtonVariant.dangerGhost,
            onPressed: widget.pending ? null : widget.onDelete,
          ),
        ),
      ],
    );
  }
}

class _DimensionEditor extends StatefulWidget {
  const _DimensionEditor({
    super.key,
    required this.collectionId,
    required this.repository,
    required this.pending,
    required this.execute,
    this.dimension,
    this.onSaved,
    this.onCancel,
  });
  final String collectionId;
  final CategoriesRepository repository;
  final CategoryDimensionRecord? dimension;
  final bool pending;
  final _Execute execute;
  final ValueChanged<CategoryDimensionRecord>? onSaved;
  final VoidCallback? onCancel;
  @override
  State<_DimensionEditor> createState() => _DimensionEditorState();
}

class _DimensionEditorState extends State<_DimensionEditor> {
  late final name = TextEditingController(text: widget.dimension?.name ?? '');
  late String openingName = name.text;
  late CategoryMode mode = widget.dimension?.mode ?? CategoryMode.single;
  late CategoryMode openingMode = mode;
  Object? error;
  bool saving = false;
  int generation = 0;
  bool get changed => name.text != openingName || mode != openingMode;
  @override
  void didUpdateWidget(_DimensionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId ||
        oldWidget.dimension?.id != widget.dimension?.id) {
      generation++;
      name.text = widget.dimension?.name ?? '';
      openingName = name.text;
      mode = widget.dimension?.mode ?? CategoryMode.single;
      openingMode = mode;
      saving = false;
      error = null;
      return;
    }
    if (!changed && widget.dimension != null) {
      name.text = widget.dimension!.name;
      openingName = name.text;
      mode = widget.dimension!.mode;
      openingMode = mode;
    }
  }

  Future<void> save() async {
    if (!mounted ||
        saving ||
        widget.pending ||
        !changed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final text = name.text, selectedMode = mode, dimension = widget.dimension;
    final revision = generation;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await widget.execute(
        () => dimension == null
            ? widget.repository.createDimension(
                collectionId: widget.collectionId,
                name: text,
                mode: selectedMode,
              )
            : widget.repository.updateDimension(
                id: dimension.id,
                name: text,
                mode: selectedMode,
              ),
      );
      if (!mounted || revision != generation) return;
      setState(() {
        name.text = saved.name;
        openingName = saved.name;
        mode = saved.mode;
        openingMode = saved.mode;
        error = null;
        saving = false;
      });
      widget.onSaved?.call(saved);
    } catch (failure) {
      if (mounted && revision == generation) {
        setState(() {
          error = failure;
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Padding(
      padding: EdgeInsets.all(pikoDesign.dimension('spacing.2')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PikoTextField(
            key: ValueKey(
              'category-management-name-${widget.dimension?.id ?? 'new'}',
            ),
            label: copy.text('r2.name'),
            controller: name,
            enabled: !widget.pending,
            onChanged: (_) => setState(() {
              error = null;
            }),
          ),
          Text(copy.text('r2.mode')),
          RadioGroup<CategoryMode>(
            groupValue: mode,
            onChanged: (next) {
              if (widget.pending || next == null) return;
              setState(() {
                mode = next;
                error = null;
              });
            },
            child: Column(
              children: [
                for (final choice in CategoryMode.values)
                  RadioListTile<CategoryMode>(
                    value: choice,
                    enabled: !widget.pending,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      copy.text(
                        choice == CategoryMode.single
                            ? 'r2.single'
                            : 'r2.multiple',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (error != null)
            Text(
              copy.text(
                error is CategoryValidation
                    ? 'r2.categoryInvalid'
                    : 'category.dimensionSaveFailed',
              ),
              style: TextStyle(color: pikoDesign.color('danger')),
            ),
          if (changed)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PikoButton(
                label: copy.text('category.saveDimension'),
                icon: const PikoIcon(PikoIconName.check),
                onPressed: widget.pending ? null : save,
              ),
            ),
          if (widget.onCancel != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PikoButton(
                label: copy.text('action.cancel'),
                variant: PikoButtonVariant.ghost,
                onPressed: widget.pending ? null : widget.onCancel,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}

class _ValueEditor extends StatefulWidget {
  const _ValueEditor({
    super.key,
    required this.dimension,
    required this.repository,
    required this.pending,
    required this.execute,
    this.value,
    this.onDelete,
    this.onDone,
  });
  final CategoryDimensionRecord dimension;
  final CategoriesRepository repository;
  final CategoryValueRecord? value;
  final bool pending;
  final _Execute execute;
  final VoidCallback? onDelete, onDone;
  @override
  State<_ValueEditor> createState() => _ValueEditorState();
}

class _ValueEditorState extends State<_ValueEditor> {
  late final name = TextEditingController(text: widget.value?.name ?? '');
  late bool editing = widget.value == null;
  Object? error;
  bool saving = false;
  int generation = 0;
  @override
  void didUpdateWidget(_ValueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.dimension.id != widget.dimension.id ||
        oldWidget.value?.id != widget.value?.id) {
      generation++;
      name.text = widget.value?.name ?? '';
      editing = widget.value == null;
      saving = false;
      error = null;
    }
  }

  bool get changed => name.text != (widget.value?.name ?? '');
  Future<void> save() async {
    if (!mounted ||
        saving ||
        widget.pending ||
        !changed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final value = widget.value;
    final revision = generation;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.execute(
        () => value == null
            ? widget.repository.createValue(
                dimensionId: widget.dimension.id,
                name: name.text,
              )
            : widget.repository.renameValue(id: value.id, name: name.text),
      );
      if (!mounted || revision != generation) return;
      setState(() {
        editing = false;
        error = null;
        saving = false;
      });
      widget.onDone?.call();
    } catch (failure) {
      if (mounted && revision == generation) {
        setState(() {
          error = failure;
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    if (!editing) {
      return Row(
        children: [
          Expanded(child: Text(widget.value!.name)),
          PikoIconButton(
            icon: const PikoIcon(PikoIconName.pencil),
            semanticLabel: copy.text('r2.editValue'),
            onPressed: widget.pending
                ? null
                : () => setState(() {
                    name.text = widget.value!.name;
                    editing = true;
                  }),
          ),
          PikoIconButton(
            icon: const PikoIcon(PikoIconName.trash),
            semanticLabel: copy.text('category.deleteValue'),
            variant: PikoButtonVariant.dangerGhost,
            onPressed: widget.pending ? null : widget.onDelete,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PikoTextField(
                key: ValueKey(
                  'category-management-value-${widget.value?.id ?? 'new-${widget.dimension.id}'}',
                ),
                label: copy.text('r2.valueName'),
                controller: name,
                enabled: !widget.pending,
                onChanged: (_) => setState(() {
                  error = null;
                }),
              ),
            ),
            if (changed)
              PikoIconButton(
                icon: const PikoIcon(PikoIconName.check),
                semanticLabel: copy.text('r2.saveValue'),
                variant: PikoButtonVariant.primary,
                onPressed: widget.pending ? null : save,
              ),
          ],
        ),
        if (error != null)
          Text(
            copy.text(
              error is CategoryValidation
                  ? 'r2.valueInvalid'
                  : 'category.valueSaveFailed',
            ),
            style: TextStyle(color: pikoDesign.color('danger')),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PikoButton(
            label: copy.text('action.cancel'),
            variant: PikoButtonVariant.ghost,
            onPressed: widget.pending
                ? null
                : () {
                    if (widget.value == null) {
                      widget.onDone?.call();
                    } else {
                      setState(() {
                        editing = false;
                        error = null;
                        name.text = widget.value!.name;
                      });
                    }
                  },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}

class _DeleteCategory extends StatefulWidget {
  const _DeleteCategory({
    required this.dimension,
    required this.execute,
    required this.delete,
    required this.canWrite,
    this.value,
  });
  final CategoryDimensionRecord dimension;
  final CategoryValueRecord? value;
  final _Execute execute;
  final Future<void> Function() delete;
  final bool Function() canWrite;
  @override
  State<_DeleteCategory> createState() => _DeleteCategoryState();
}

class _DeleteCategoryState extends State<_DeleteCategory> {
  bool pending = false;
  Object? error;
  Future<void> confirm() async {
    if (!mounted ||
        pending ||
        !widget.canWrite() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      pending = true;
      error = null;
    });
    try {
      await widget.execute(widget.delete);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          pending = false;
          error = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final title = copy.text(
      widget.value == null
          ? 'category.deleteDimension'
          : 'category.deleteValue',
    );
    return PikoDialog(
      title: title,
      purpose: PikoDialogPurpose.confirmation,
      dismissible: !pending,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.text(
              widget.value == null
                  ? 'category.deleteDimensionWarning'
                  : 'category.deleteValueWarning',
              {'name': widget.value?.name ?? widget.dimension.name},
            ),
          ),
          if (error != null)
            Text(
              copy.text('category.deleteFailed'),
              style: TextStyle(color: pikoDesign.color('danger')),
            ),
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('action.cancel'),
          role: PikoDialogActionRole.safe,
          onPressed: pending ? null : () => Navigator.of(context).pop(false),
        ),
        PikoDialogAction(
          label: title,
          role: PikoDialogActionRole.destructive,
          onPressed: pending ? null : confirm,
        ),
      ],
    );
  }
}
