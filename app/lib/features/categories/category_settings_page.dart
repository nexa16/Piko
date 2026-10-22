import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_switch.dart';
import '../../ui/piko_theme.dart';
import 'category_dimension_form.dart';
import 'category_order_list.dart';

class CategorySettingsPage extends StatefulWidget {
  const CategorySettingsPage({
    required this.collectionId,
    required this.collectionName,
    required this.repository,
    this.onPendingWrites,
    super.key,
  });
  final String collectionId, collectionName;
  final CategoriesRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  late Stream<List<CategoryDimensionRecord>> groups = widget.repository
      .watchDimensions(widget.collectionId);
  bool opening = false, ordering = false;
  Object? orderError;
  Future<void> moveGroups(
    List<CategoryDimensionRecord> current,
    int from,
    int to,
  ) async {
    if (opening || ordering || from == to) return;
    final ids = current.map((group) => group.id).toList();
    final next = [...ids];
    next.insert(to, next.removeAt(from));
    setState(() {
      ordering = true;
      orderError = null;
    });
    try {
      final operation = widget.repository.reorderDimensions(
        collectionId: widget.collectionId,
        expectedOrder: ids,
        orderedIds: next,
      );
      widget.onPendingWrites?.call(
        operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await operation;
    } catch (error) {
      if (mounted) setState(() => orderError = error);
    } finally {
      if (mounted) setState(() => ordering = false);
    }
  }

  @override
  void didUpdateWidget(CategorySettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId) {
      groups = widget.repository.watchDimensions(widget.collectionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Scaffold(
      body: PikoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PikoFormHeading(
              title: copy.text('catPreview.manage'),
              subtitle: widget.collectionName,
              leading: PikoIconButton(
                icon: const PikoIcon(PikoIconName.arrowLeft),
                semanticLabel: copy.text('common.back'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            StreamBuilder<List<CategoryDimensionRecord>>(
              stream: groups,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text(copy.text('category.managementLoadFailed')),
                      PikoButton(
                        label: copy.text('action.retry'),
                        onPressed: () => setState(
                          () => groups = widget.repository.watchDimensions(
                            widget.collectionId,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return PikoFormSection(
                  title: copy.text('catPreview.groups'),
                  children: [
                    if (snapshot.data!.isEmpty)
                      PikoFormFieldRow(
                        child: Text(copy.text('r2.noCategories')),
                      ),
                    CategoryOrderList<CategoryDimensionRecord>(
                      items: snapshot.data!,
                      id: (group) => group.id,
                      label: (group) => group.name,
                      enabled: !opening && !ordering,
                      onMove: (from, to) =>
                          moveGroups(snapshot.data!, from, to),
                      row: (group) => _CategoryOverviewRow(
                        key: ValueKey(group.id),
                        group: group,
                        repository: widget.repository,
                        onTap: () {
                          if (opening || ordering) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CategoryGroupSettingsPage(
                                group: group,
                                repository: widget.repository,
                                onPendingWrites: widget.onPendingWrites,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (orderError != null)
                      PikoFormFieldRow(
                        child: Text(
                          copy.text(
                            orderError == CategoryValidation.staleOrder
                                ? 'category.reorderStale'
                                : 'category.reorderFailed',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            PikoButton(
              label: copy.text('category.addDimension'),
              icon: const PikoIcon(PikoIconName.plus),
              variant: PikoButtonVariant.ghost,
              onPressed: opening || ordering
                  ? null
                  : () async {
                      if (ModalRoute.of(context)?.isCurrent != true) return;
                      setState(() => opening = true);
                      try {
                        await showCreateCategoryDimension(
                          context,
                          collectionId: widget.collectionId,
                          repository: widget.repository,
                          onPendingWrites: widget.onPendingWrites,
                        );
                      } finally {
                        if (mounted) setState(() => opening = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryOverviewRow extends StatefulWidget {
  const _CategoryOverviewRow({
    super.key,
    required this.group,
    required this.repository,
    required this.onTap,
  });
  final CategoryDimensionRecord group;
  final CategoriesRepository repository;
  final VoidCallback onTap;
  @override
  State<_CategoryOverviewRow> createState() => _CategoryOverviewRowState();
}

class _CategoryOverviewRowState extends State<_CategoryOverviewRow> {
  late Stream<List<CategoryValueRecord>> values = widget.repository.watchValues(
    widget.group.id,
  );
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return StreamBuilder<List<CategoryValueRecord>>(
      stream: values,
      builder: (context, snapshot) => PikoNavigationRow(
        title: widget.group.name,
        subtitle:
            '${copy.text(widget.group.mode == CategoryMode.single ? 'r2.single' : 'r2.multiple')} · ${snapshot.hasError
                ? copy.text('category.managementLoadFailed')
                : !snapshot.hasData
                ? copy.text('settings.loading')
                : '${snapshot.data!.length} ${copy.text('catPreview.values')}\n${snapshot.data!.map((value) => value.name).join(' · ')}'}',
        onTap: widget.onTap,
      ),
    );
  }
}

class CategoryGroupSettingsPage extends StatefulWidget {
  const CategoryGroupSettingsPage({
    required this.group,
    required this.repository,
    this.onPendingWrites,
    super.key,
  });
  final CategoryDimensionRecord group;
  final CategoriesRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<CategoryGroupSettingsPage> createState() =>
      _CategoryGroupSettingsPageState();
}

class _CategoryGroupSettingsPageState extends State<CategoryGroupSettingsPage> {
  late CategoryDimensionRecord opening = widget.group;
  late final name = TextEditingController(text: opening.name);
  late CategoryMode mode = opening.mode;
  late bool carry = opening.carryOver;
  late Stream<List<CategoryValueRecord>> values = widget.repository.watchValues(
    opening.id,
  );
  bool busy = false, leaving = false;
  Object? error;
  bool get changed =>
      name.text != opening.name ||
      mode != opening.mode ||
      carry != opening.carryOver;
  Future<T> write<T>(Future<T> Function() operation) async {
    if (!mounted || busy) throw StateError('Category write unavailable');
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final work = operation();
      widget.onPendingWrites?.call(
        work.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      return await work;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || !changed || ModalRoute.of(context)?.isCurrent != true) return;
    final raw = name.text, selected = mode, carried = carry;
    try {
      final saved = await write(
        () => widget.repository.updateDimension(
          id: opening.id,
          name: raw,
          mode: selected,
          carryOver: carried,
        ),
      );
      if (mounted) {
        setState(() {
          opening = saved;
          name.text = saved.name;
          mode = saved.mode;
          carry = saved.carryOver;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    }
  }

  Future<void> back() async {
    if (busy || leaving || ModalRoute.of(context)?.isCurrent != true) return;
    if (!changed) {
      Navigator.of(context).pop();
      return;
    }
    leaving = true;
    final copy = PikoCopyScope.of(context);
    try {
      final discard = await showPikoDialog<bool>(
        context,
        builder: (context) => PikoDialog(
          purpose: PikoDialogPurpose.confirmation,
          title: copy.text('form.discardTitle'),
          body: Text(copy.text('form.discardHelp')),
          actions: [
            PikoDialogAction(
              label: copy.text('entry.continue'),
              role: PikoDialogActionRole.safe,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            PikoDialogAction(
              label: copy.text('form.discard'),
              role: PikoDialogActionRole.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (mounted &&
          discard == true &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } finally {
      leaving = false;
    }
  }

  Future<void> pickMode() async {
    if (busy || ModalRoute.of(context)?.isCurrent != true) return;
    var pending = mode;
    final copy = PikoCopyScope.of(context);
    final selected = await showPikoDialog<CategoryMode>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PikoDialog(
          title: copy.text('r2.mode'),
          purpose: PikoDialogPurpose.selection,
          body: RadioGroup<CategoryMode>(
            groupValue: pending,
            onChanged: (value) {
              if (value != null) update(() => pending = value);
            },
            child: Column(
              children: [
                for (final value in CategoryMode.values)
                  RadioListTile<CategoryMode>(
                    value: value,
                    title: Text(
                      copy.text(
                        value == CategoryMode.single
                            ? 'r2.single'
                            : 'r2.multiple',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            PikoDialogAction(
              label: copy.text('r2.apply'),
              onPressed: pending == mode
                  ? null
                  : () => Navigator.of(context).pop(pending),
            ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) setState(() => mode = selected);
  }

  Future<void> remove({CategoryValueRecord? value}) async {
    if (busy || ModalRoute.of(context)?.isCurrent != true) return;
    final copy = PikoCopyScope.of(context);
    var deleting = false;
    Object? failure;
    final result = await showPikoDialog<bool>(
      context,
      canDismiss: () => !deleting,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PikoDialog(
          title: copy.text(
            value == null ? 'category.deleteDimension' : 'category.deleteValue',
          ),
          purpose: PikoDialogPurpose.confirmation,
          dismissible: !deleting,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(value?.name ?? opening.name),
              Text(
                copy.text(
                  value == null
                      ? 'category.deleteDimensionWarning'
                      : 'category.deleteValueWarning',
                  {'name': value?.name ?? opening.name},
                ),
              ),
              if (failure != null) Text(copy.text('category.deleteFailed')),
            ],
          ),
          actions: [
            PikoDialogAction(
              label: copy.text('action.cancel'),
              role: PikoDialogActionRole.safe,
              onPressed: deleting ? null : () => Navigator.of(context).pop(),
            ),
            PikoDialogAction(
              label: copy.text('catPreview.delete'),
              role: PikoDialogActionRole.destructive,
              onPressed: deleting
                  ? null
                  : () async {
                      update(() {
                        deleting = true;
                        failure = null;
                      });
                      try {
                        await write(
                          () => value == null
                              ? widget.repository.deleteDimension(opening.id)
                              : widget.repository.deleteValue(value.id),
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (error) {
                        if (context.mounted) {
                          update(() {
                            failure = error;
                            deleting = false;
                          });
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
    if (mounted &&
        result == true &&
        value == null &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> moveValues(
    List<CategoryValueRecord> current,
    int from,
    int to,
  ) async {
    if (busy || from == to) return;
    final ids = current.map((value) => value.id).toList();
    final next = [...ids];
    next.insert(to, next.removeAt(from));
    try {
      await write(
        () => widget.repository.reorderValues(
          dimensionId: opening.id,
          expectedOrder: ids,
          orderedIds: next,
        ),
      );
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    }
  }

  Future<void> editValue([CategoryValueRecord? value]) async {
    if (busy || ModalRoute.of(context)?.isCurrent != true) return;
    await showPikoDialog<void>(
      context,
      builder: (_) => _CategoryValueForm(
        value: value,
        groupId: opening.id,
        repository: widget.repository,
        onPendingWrites: widget.onPendingWrites,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PopScope(
      canPop: !busy && !changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoFormHeading(
                title: opening.name,
                leading: PikoIconButton(
                  icon: const PikoIcon(PikoIconName.arrowLeft),
                  semanticLabel: copy.text('common.back'),
                  onPressed: busy ? null : back,
                ),
              ),
              PikoFormSection(
                title: copy.text('catPreview.properties'),
                children: [
                  PikoFormFieldRow(
                    child: PikoTextField(
                      key: ValueKey('category-management-name-${opening.id}'),
                      label: copy.text('r2.name'),
                      controller: name,
                      enabled: !busy,
                      onChanged: (_) => setState(() => error = null),
                    ),
                  ),
                  PikoNavigationRow(
                    title: copy.text('r2.mode'),
                    subtitle: copy.text(
                      mode == CategoryMode.single ? 'r2.single' : 'r2.multiple',
                    ),
                    onTap: busy ? null : pickMode,
                  ),
                  PikoFormFieldRow(
                    child: PikoSwitch(
                      key: ValueKey('category-carry-over-${opening.id}'),
                      title: Text(copy.text('category.carryOver')),
                      subtitle: Text(copy.text('category.carryOverHelp')),
                      value: carry,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => carry = value),
                    ),
                  ),
                  PikoFormFieldRow(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: PikoButton(
                        label: copy.text('category.saveDimension'),
                        onPressed: busy || !changed ? null : save,
                      ),
                    ),
                  ),
                ],
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
              StreamBuilder<List<CategoryValueRecord>>(
                stream: values,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Text(copy.text('category.managementLoadFailed')),
                        PikoButton(
                          label: copy.text('action.retry'),
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => values = widget.repository.watchValues(
                                    opening.id,
                                  ),
                                ),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return PikoFormSection(
                    title: copy.text('catPreview.values'),
                    children: [
                      CategoryOrderList<CategoryValueRecord>(
                        items: snapshot.data!,
                        id: (value) => value.id,
                        label: (value) => value.name,
                        enabled: !busy,
                        onMove: (from, to) =>
                            moveValues(snapshot.data!, from, to),
                        row: (value) => PikoFormFieldRow(
                          child: Row(
                            children: [
                              Expanded(child: Text(value.name)),
                              PikoIconButton(
                                icon: const PikoIcon(PikoIconName.pencil),
                                semanticLabel: copy.text('r2.editValue'),
                                onPressed: busy ? null : () => editValue(value),
                              ),
                              PikoIconButton(
                                icon: const PikoIcon(PikoIconName.trash),
                                semanticLabel: copy.text(
                                  'category.deleteValue',
                                ),
                                variant: PikoButtonVariant.dangerGhost,
                                onPressed: busy
                                    ? null
                                    : () => remove(value: value),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PikoNavigationRow(
                        title: copy.text('r2.addValue'),
                        onTap: busy ? null : editValue,
                      ),
                    ],
                  );
                },
              ),
              PikoFormGroup(
                children: [
                  PikoFormRow(
                    title: copy.text('category.deleteDimension'),
                    danger: true,
                    trailing: const PikoIcon(PikoIconName.trash),
                    onTap: busy ? null : remove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}

class _CategoryValueForm extends StatefulWidget {
  const _CategoryValueForm({
    required this.groupId,
    required this.repository,
    this.value,
    this.onPendingWrites,
  });
  final String groupId;
  final CategoriesRepository repository;
  final CategoryValueRecord? value;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<_CategoryValueForm> createState() => _CategoryValueFormState();
}

class _CategoryValueFormState extends State<_CategoryValueForm> {
  late final name = TextEditingController(text: widget.value?.name ?? '');
  bool busy = false;
  Object? error;
  Future<void> save() async {
    if (busy || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final work = widget.value == null
          ? widget.repository.createValue(
              dimensionId: widget.groupId,
              name: name.text,
            )
          : widget.repository.renameValue(
              id: widget.value!.id,
              name: name.text,
            );
      widget.onPendingWrites?.call(
        work.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await work;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PikoDialog(
      presentation: PikoDialogPresentation.groupedForm,
      title: copy.text(widget.value == null ? 'r2.addValue' : 'r2.editValue'),
      dismissible: !busy,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PikoFormGroup(
            children: [
              PikoFormFieldRow(
                child: PikoTextField(
                  key: const ValueKey('category-value-name'),
                  label: copy.text('r2.valueName'),
                  controller: name,
                  enabled: !busy,
                  autofocus: true,
                  onChanged: (_) => setState(() => error = null),
                ),
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
            ),
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('r2.save'),
          onPressed: busy ? null : save,
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
