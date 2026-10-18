import '../../ui/components/piko_switch.dart';
import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../data/collection_query.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_content.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import '../categories/vocabulary_categories.dart';
import 'inline_vocabulary_edit_controller.dart';
import 'vocabulary_content_editor.dart';

String savedVocabularyErrorKey(Object error) =>
    vocabularyContentErrorKey(error) ??
    switch (error) {
      VocabularyValidation.requiredTarget => 'entry.requiredTarget',
      VocabularyValidation.requiredNative => 'entry.requiredNative',
      VocabularyValidation.duplicatePair => 'vocab.inlineDuplicate',
      VocabularyValidation.entryNotFound => 'entry.notFound',
      CategoryValidation() => 'category.selectionInvalid',
      _ => 'entry.saveFailed',
    };

/// Shared saved-card controls. The host owns input/focus and storage lifetime,
/// and must guard collapse/navigation by draining this controller.
class SavedVocabularyEditor extends StatelessWidget {
  const SavedVocabularyEditor({
    required this.collection,
    required this.repository,
    required this.edits,
    required this.target,
    required this.native,
    required this.targetFocus,
    required this.nativeFocus,
    required this.onCollapse,
    this.onDelete,
    this.categories,
    this.snapshot,
    this.busy = false,
    this.showHeader = true,
    this.onPendingWrites,
    super.key,
  });
  final CollectionRecord collection;
  final VocabularyRepository repository;
  final InlineVocabularyEditController edits;
  final TextEditingController target, native;
  final FocusNode targetFocus, nativeFocus;
  final VoidCallback onCollapse;
  final VoidCallback? onDelete;
  final CategoriesRepository? categories;
  final CollectionQuerySnapshot? snapshot;
  final bool busy, showHeader;
  final ValueChanged<Future<void>>? onPendingWrites;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final error = edits.error;
    bool admitted() => !busy && ModalRoute.of(context)?.isCurrent != false;
    void register() => onPendingWrites?.call(edits.awaitSavedEdits());
    Widget field(bool first) => PikoTextField(
      key: ValueKey('inline-${edits.entryId}-${first ? 'target' : 'native'}'),
      label: (first ? collection.targetLanguage : collection.nativeLanguage)
          .label(copy.locale),
      controller: first ? target : native,
      focusNode: first ? targetFocus : nativeFocus,
      enabled: !busy,
      style: Theme.of(context).textTheme.bodyMedium,
      error:
          error ==
              (first
                  ? VocabularyValidation.requiredTarget
                  : VocabularyValidation.requiredNative)
          ? copy.text(savedVocabularyErrorKey(error!))
          : null,
      onChanged: (value) {
        if (!admitted()) return;
        first ? edits.setTargetText(value) : edits.setNativeText(value);
        register();
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.text('vocab.inlineEdit'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        copy.text(
                          edits.isSaving
                              ? 'entry.saving'
                              : error != null || edits.hasUncommittedChanges
                              ? 'entry.unsaved'
                              : 'entry.saved',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              PikoIconButton(
                key: ValueKey('inline-complete-${edits.entryId}'),
                icon: const RotatedBox(
                  quarterTurns: 3,
                  child: PikoIcon(PikoIconName.chevronRight),
                ),
                semanticLabel: copy.text('vocab.inlineCollapse'),
                onPressed: busy ? null : onCollapse,
              ),
            ],
          ),
        SizedBox(height: pikoDesign.dimension('spacing.3')),
        PikoFormSection(
          title: copy.text('settingsPreview.vocabulary'),
          children: [
            PikoFormFieldRow(child: field(true)),
            PikoFormFieldRow(child: field(false)),
          ],
        ),
        if (edits.supportsContent)
          VocabularyContentEditor(
            value: edits.draft.content,
            makeDefault: false,
            enabled: !busy,
            error: error,
            collectionId: collection.id,
            preferences: repository is CollectionHintPreferences
                ? repository as CollectionHintPreferences
                : null,
            onPendingWrites: (operation) {
              final drain = edits.trackPreferenceWrite(operation);
              onPendingWrites?.call(drain);
            },
            targetLanguage: collection.targetLanguage.label(copy.locale),
            nativeLanguage: collection.nativeLanguage.label(copy.locale),
            onChanged: (value, _) {
              if (admitted()) {
                edits.setContent(value);
                register();
              }
            },
          ),
        if (categories != null && edits.supportsCategories)
          VocabularyCategories(
            collectionId: collection.id,
            entryId: edits.entryId,
            repository: categories!,
            snapshot: snapshot,
            draftAssignments: edits.draft.assignments,
            disabled: busy,
            onPendingWrites: onPendingWrites,
            onMetadataChanged: () {
              final work = edits.refreshCategoryReferences(categories!);
              onPendingWrites?.call(work);
            },
            onSelection: (value) {
              if (admitted()) {
                edits.setCategoryValues(value.dimensionId, value.valueIds);
                register();
              }
            },
          ),
        if (edits.supportsContent)
          PikoFormSection(
            title: copy.text('settingsPreview.learning'),
            children: [
              PikoFormFieldRow(
                child: PikoSwitch(
                  key: ValueKey('inline-active-${edits.entryId}'),

                  title: Text(copy.text('vocab.active')),
                  value: edits.draft.active,
                  subtitle: Text(
                    copy.text(
                      edits.draft.active
                          ? 'vocab.activeHelp'
                          : 'vocab.inactiveHelp',
                    ),
                  ),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (admitted()) {
                            edits.edit(active: value);
                            register();
                          }
                        },
                ),
              ),
            ],
          ),
        if (onDelete != null)
          PikoFormGroup(
            children: [
              PikoFormRow(
                key: ValueKey('inline-delete-${edits.entryId}'),
                title: copy.text('vocab.delete'),
                danger: true,
                trailing: const PikoIcon(PikoIconName.trash),
                onTap: busy
                    ? null
                    : () {
                        if (admitted()) onDelete!();
                      },
              ),
            ],
          ),
        if (!showHeader)
          Semantics(
            liveRegion: true,
            child: Text(
              copy.text(
                edits.isSaving
                    ? 'entry.saving'
                    : error != null || edits.hasUncommittedChanges
                    ? 'entry.unsaved'
                    : 'entry.saved',
              ),
            ),
          ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              copy.text(savedVocabularyErrorKey(error)),
              style: TextStyle(color: pikoDesign.color('danger')),
            ),
          ),
        if (error != null &&
            error is! VocabularyValidation &&
            error is! VocabularyContentValidation &&
            error is! CategoryValidation)
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: busy || edits.isSaving
                ? null
                : () {
                    edits.retry();
                    register();
                  },
          ),
      ],
    );
  }
}
