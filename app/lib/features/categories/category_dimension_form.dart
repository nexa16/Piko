import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

/// Creates only a definition. The caller keeps ownership of vocabulary text and
/// assignment drafts; a created dimension has no values or assigned entries.
Future<CategoryDimensionRecord?> showCreateCategoryDimension(
  BuildContext context, {
  required String collectionId,
  required CategoriesRepository repository,
  ValueChanged<Future<void>>? onPendingWrites,
}) {
  final key = GlobalKey<_CategoryDimensionFormState>();
  return showPikoDialog<CategoryDimensionRecord>(
    context,
    canDismiss: () => key.currentState?.pending != true,
    builder: (_) => CategoryDimensionForm(
      key: key,
      collectionId: collectionId,
      repository: repository,
      onPendingWrites: onPendingWrites,
    ),
  );
}

class CategoryDimensionForm extends StatefulWidget {
  const CategoryDimensionForm({
    super.key,
    required this.collectionId,
    required this.repository,
    this.onPendingWrites,
  });
  final String collectionId;
  final CategoriesRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<CategoryDimensionForm> createState() => _CategoryDimensionFormState();
}

class _CategoryDimensionFormState extends State<CategoryDimensionForm> {
  final name = TextEditingController();
  CategoryMode mode = CategoryMode.single;
  bool pending = false;
  Object? error;
  int generation = 0;
  bool get changed => name.text.isNotEmpty || mode != CategoryMode.single;

  @override
  void didUpdateWidget(CategoryDimensionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId ||
        oldWidget.repository != widget.repository) {
      generation++;
      name.clear();
      mode = CategoryMode.single;
      pending = false;
      error = null;
    }
  }

  Future<void> save() async {
    if (!mounted ||
        pending ||
        !changed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final revision = generation;
    final collectionId = widget.collectionId;
    final repository = widget.repository;
    final snapshot = name.text;
    final chosenMode = mode;
    setState(() {
      pending = true;
      error = null;
    });
    try {
      final saved = await repository.createDimension(
        collectionId: collectionId,
        name: snapshot,
        mode: chosenMode,
      );
      if (!mounted || generation != revision) return;
      if (ModalRoute.of(context)?.isCurrent != true) {
        setState(() {
          pending = false;
        });
        return;
      }
      if (saved.collectionId != collectionId || saved.mode != chosenMode) {
        throw CategoryValidation.invalidOwnership;
      }
      Navigator.of(context).pop(saved);
    } catch (failure) {
      if (mounted && generation == revision) {
        setState(() {
          pending = false;
          error = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), design = pikoDesign;
    final revision = generation;
    bool editable() =>
        mounted &&
        generation == revision &&
        !pending &&
        ModalRoute.of(context)?.isCurrent == true;
    return PikoDialog(
      title: copy.text('dialog.newDimension'),
      purpose: PikoDialogPurpose.form,
      dismissible: !pending,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PikoTextField(
            key: const ValueKey('category-dimension-name'),
            label: copy.text('r2.name'),
            controller: name,
            enabled: !pending,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (editable())
                setState(() {
                  error = null;
                });
            },
          ),
          SizedBox(height: design.dimension('spacing.4')),
          Text(copy.text('r2.mode')),
          RadioGroup<CategoryMode>(
            groupValue: mode,
            onChanged: (selected) {
              if (!editable() || selected == null) return;
              setState(() {
                mode = selected;
                error = null;
              });
            },
            child: Column(
              children: [
                for (final choice in CategoryMode.values)
                  RadioListTile<CategoryMode>(
                    key: ValueKey('category-dimension-mode-${choice.name}'),
                    value: choice,
                    enabled: !pending,
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        design.dimension('components.buttons.radius'),
                      ),
                    ),
                    selected: mode == choice,
                    selectedTileColor: design.color('tint'),
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
          if (error != null) ...[
            SizedBox(height: design.dimension('spacing.3')),
            Semantics(
              liveRegion: true,
              child: Text(
                copy.text(switch (error) {
                  CategoryValidation.requiredName ||
                  CategoryValidation.duplicateName =>
                    'category.dimensionNameInvalid',
                  CategoryValidation() => 'r2.categoryInvalid',
                  _ => 'category.dimensionSaveFailed',
                }),
                style: TextStyle(color: design.color('danger')),
              ),
            ),
          ],
        ],
      ),
      actions: changed
          ? [
              PikoDialogAction(
                label: copy.text('category.saveDimension'),
                icon: const PikoIcon(PikoIconName.check),
                onPressed: pending
                    ? null
                    : () {
                        if (!editable()) return;
                        final accepted = save();
                        widget.onPendingWrites?.call(accepted);
                      },
              ),
            ]
          : const [],
    );
  }

  @override
  void dispose() {
    generation++;
    name.dispose();
    super.dispose();
  }
}
