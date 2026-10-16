import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_json.dart';
import '../../platform/vocabulary_json_platform.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';

class VocabularyJsonDraft {
  TextEditingValue input = TextEditingValue.empty;
  Set<VocabularyJsonGroup> groups = Set.unmodifiable(VocabularyJsonGroup.all);
  bool expanded = false;
}

enum VocabularyJsonReturn { collection }

enum _JsonView { importJson, exportJson }

enum _TransferSection { example, input, review, exportJson }

@immutable
final class _TransferState {
  const _TransferState({
    this.busy = false,
    this.messageKey,
    this.failed = false,
    this.fallback,
    this.example = false,
    this.arguments = const {},
  });
  final bool busy, failed, example;
  final String? messageKey, fallback;
  final Map<String, Object> arguments;
}

@immutable
final class _ImportReview {
  _ImportReview(this.capability, this.revision)
    : issues = List.unmodifiable(capability.issues),
      newCount = capability.newCount,
      updatedCount = capability.updatedCount,
      unchangedCount = capability.unchangedCount,
      errorCount = capability.errorCount,
      canApply = capability.canApply;
  final VocabularyJsonPreview capability;
  final int revision, newCount, updatedCount, unchangedCount, errorCount;
  final List<VocabularyJsonIssue> issues;
  final bool canApply;
  Map<String, Object> get counts => {
    'added': newCount,
    'updated': updatedCount,
    'unchanged': unchangedCount,
    'errors': errorCount,
  };
}

/// One opened Collection's interchange surface. Platform access and storage
/// remain caller-owned; editable input is never replaced by an export/example.
class VocabularyJsonPage extends StatefulWidget {
  const VocabularyJsonPage({
    super.key,
    required this.collection,
    required this.service,
    required this.platform,
    this.onPendingWrites,
    this.onImported,
    this.asDialog = false,
    this.draft,
  });
  final bool asDialog;
  final VocabularyJsonDraft? draft;
  final CollectionRecord collection;
  final VocabularyJsonService service;
  final VocabularyJsonPlatform platform;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<VocabularyJsonApplyResult>? onImported;
  @override
  State<VocabularyJsonPage> createState() => _VocabularyJsonPageState();
}

class _VocabularyJsonPageState extends State<VocabularyJsonPage> {
  final input = TextEditingController(), fallback = TextEditingController();
  _TransferState transfer = const _TransferState();
  Object? request;
  int inputRevision = 0;
  Set<VocabularyJsonGroup> groups = Set.unmodifiable(VocabularyJsonGroup.all);
  _ImportReview? review;
  bool confirming = false, applying = false;
  bool expandedInput = false, returning = false;
  _JsonView view = _JsonView.importJson;
  _TransferSection transferSection = _TransferSection.input;
  ModalRoute<dynamic>? confirmationRoute;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      input.value = draft.input;
      groups = draft.groups;
      expandedInput = draft.expanded;
    }
  }

  @override
  void didUpdateWidget(VocabularyJsonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.service != widget.service ||
        oldWidget.platform != widget.platform) {
      request = null;
      inputRevision++;
      transfer = const _TransferState();
      review = null;
      confirming = false;
      applying = false;
      returning = false;
      dismissConfirmation();
      fallback.clear();
      if (oldWidget.collection.id != widget.collection.id) {
        input.clear();
        groups = Set.unmodifiable(VocabularyJsonGroup.all);
        view = _JsonView.importJson;
        expandedInput = false;
      }
    }
  }

  void dismissConfirmation() {
    final route = confirmationRoute;
    confirmationRoute = null;
    if (route?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route!.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  void invalidateInput() {
    inputRevision++;
    review = null;
    if (!transfer.busy && transferSection == _TransferSection.review) {
      transfer = const _TransferState();
    }
  }

  Object begin(_TransferSection section) {
    final token = Object();
    request = token;
    setState(() {
      transfer = const _TransferState(busy: true);
      transferSection = section;
    });
    return token;
  }

  bool current(Object token) {
    if (!mounted || !identical(request, token)) return false;
    if (ModalRoute.of(context)?.isCurrent == false) {
      setState(() {
        request = null;
        transfer = const _TransferState();
        confirming = false;
        applying = false;
        review = null;
      });
      return false;
    }
    return true;
  }

  void launch(Future<void> Function() operation) {
    if (!mounted ||
        transfer.busy ||
        returning ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final accepted = operation();
    widget.onPendingWrites?.call(accepted);
  }

  void finish(Object token, _TransferState next) {
    if (!current(token)) return;
    fallback.text = next.fallback ?? '';
    setState(() {
      request = null;
      transfer = next;
    });
  }

  Future<void> read({required bool file}) async {
    if (transfer.busy) return;
    final token = begin(_TransferSection.input);
    final revision = inputRevision;
    try {
      final text = file
          ? await widget.platform.readFile()
          : await widget.platform.readClipboard();
      if (!current(token)) return;
      if (text != null && inputRevision == revision) {
        input.text = text;
        invalidateInput();
      }
      finish(token, const _TransferState());
    } catch (error) {
      final key = switch (error) {
        JsonPlatformFailure.tooLarge => 'json.tooLarge',
        JsonPlatformFailure.invalidUtf8 => 'json.invalidUtf8',
        _ => file ? 'json.fileFailed' : 'json.clipboardFailed',
      };
      finish(token, _TransferState(messageKey: key, failed: true));
    }
  }

  Future<void> analyze() async {
    final token = begin(_TransferSection.review);
    final revision = inputRevision;
    final selected = Set<VocabularyJsonGroup>.unmodifiable(groups);
    setState(() {
      review = null;
    });
    try {
      final candidate = await widget.service.analyzeImport(
        collectionId: widget.collection.id,
        json: input.text,
        groups: selected,
      );
      if (!current(token)) return;
      if (revision != inputRevision) {
        finish(token, const _TransferState());
        return;
      }
      if (candidate.collectionId != widget.collection.id ||
          candidate.groups.length != selected.length ||
          !candidate.groups.containsAll(selected)) {
        throw VocabularyJsonApplyFailure.invalidPreview;
      }
      setState(() {
        review = _ImportReview(candidate, revision);
      });
      finish(token, const _TransferState());
    } catch (_) {
      finish(
        token,
        revision == inputRevision
            ? const _TransferState(
                messageKey: 'json.analyzeFailed',
                failed: true,
              )
            : const _TransferState(),
      );
    }
  }

  Future<void> confirmImport(_ImportReview expected) async {
    if (!identical(review, expected) ||
        expected.revision != inputRevision ||
        !expected.canApply) {
      return;
    }
    final token = begin(_TransferSection.review);
    confirming = true;
    final service = widget.service;
    final imported = widget.onImported;
    bool owned() =>
        mounted && identical(request, token) && identical(review, expected);
    try {
      final accepted = await showPikoDialog<bool>(
        context,
        canRestoreFocus: owned,
        builder: (dialogContext) {
          final route = ModalRoute.of(dialogContext);
          if (!owned()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (route?.isActive == true) route!.navigator?.removeRoute(route);
            });
            return const SizedBox.shrink();
          }
          confirmationRoute = route;
          final copy = PikoCopyScope.of(dialogContext);
          void choose(bool result) {
            if (owned() && route?.isCurrent == true) {
              Navigator.of(dialogContext).pop(result);
            }
          }

          return PikoDialog(
            purpose: PikoDialogPurpose.confirmation,
            title: copy.text('json.confirmTitle'),
            body: Text(
              copy.text('json.confirmReplacement', {
                'name': widget.collection.name,
              }),
            ),
            actions: [
              PikoDialogAction(
                label: copy.text('action.cancel'),
                role: PikoDialogActionRole.safe,
                onPressed: () => choose(false),
              ),
              PikoDialogAction(
                label: copy.text('json.apply'),
                onPressed: () => choose(true),
              ),
            ],
          );
        },
      );
      confirmationRoute = null;
      if (!current(token)) return;
      confirming = false;
      if (accepted != true ||
          !identical(review, expected) ||
          inputRevision != expected.revision) {
        finish(token, const _TransferState());
        return;
      }
      setState(() {
        applying = true;
      });
      final result = await service.applyImport(expected.capability);
      if (!current(token)) return;
      setState(() {
        review = null;
        applying = false;
      });
      finish(
        token,
        _TransferState(
          messageKey: 'json.importApplied',
          arguments: {
            'added': result.newCount,
            'updated': result.updatedCount,
            'unchanged': result.unchangedCount,
          },
        ),
      );
      // A caller's refresh notification cannot turn committed storage success
      // into a reported import failure.
      try {
        imported?.call(result);
      } catch (_) {
        /* Caller-owned notification. */
      }
    } catch (error) {
      if (!current(token)) return;
      setState(() {
        review = null;
        confirming = false;
        applying = false;
      });
      finish(
        token,
        _TransferState(
          messageKey: error is VocabularyJsonApplyFailure
              ? 'json.stalePreview'
              : 'json.applyFailed',
          failed: true,
        ),
      );
    }
  }

  String issueKey(VocabularyJsonIssueCode code) => switch (code) {
    VocabularyJsonIssueCode.groupsRequired => 'r2.jsonGroupsRequired',
    VocabularyJsonIssueCode.tooLarge => 'json.tooLarge',
    VocabularyJsonIssueCode.invalidJson => 'json.invalidSyntax',
    VocabularyJsonIssueCode.unsupportedVersion => 'json.unsupportedVersion',
    VocabularyJsonIssueCode.exactlyOneCollection => 'json.oneCollection',
    VocabularyJsonIssueCode.languageMismatch => 'json.languages',
    VocabularyJsonIssueCode.collectionNotFound => 'json.collectionMissing',
    VocabularyJsonIssueCode.foreignId => 'json.foreignId',
    VocabularyJsonIssueCode.invalidId ||
    VocabularyJsonIssueCode.duplicateId => 'r2.jsonIdentity',
    VocabularyJsonIssueCode.invalidField => 'json.invalidField',
    VocabularyJsonIssueCode.requiredTarget => 'entry.requiredTarget',
    VocabularyJsonIssueCode.requiredNative => 'entry.requiredNative',
    VocabularyJsonIssueCode.duplicatePair => 'r2.jsonDuplicate',
    VocabularyJsonIssueCode.unknownDimension ||
    VocabularyJsonIssueCode.unknownValue ||
    VocabularyJsonIssueCode.invalidOwnership ||
    VocabularyJsonIssueCode.duplicateName ||
    VocabularyJsonIssueCode.cardinalityViolation => 'r2.jsonCategory',
    VocabularyJsonIssueCode.invalidEnvelope ||
    VocabularyJsonIssueCode.unsupportedFormat => 'r2.jsonInvalid',
  };

  Future<void> export({bool example = false, bool download = false}) async {
    if (transfer.busy) return;
    final token = begin(
      example ? _TransferSection.example : _TransferSection.exportJson,
    );
    String? text;
    try {
      if (example) {
        final copy = PikoCopyScope.of(context);
        text = VocabularyJsonFormat.minimalSample(
          targetLanguage: widget.collection.targetLanguage.code,
          nativeLanguage: widget.collection.nativeLanguage.code,
          topic: copy.text('template.topic'),
          food: copy.text('template.food'),
          difficulty: copy.text('template.difficulty'),
          easy: copy.text('template.easy'),
        );
      } else {
        text = await widget.service.exportCollection(widget.collection.id);
      }
      if (!current(token)) return;
      if (download) {
        try {
          final saved = await widget.platform.saveFile(text);
          finish(
            token,
            _TransferState(messageKey: saved ? 'json.fileSaved' : null),
          );
        } catch (_) {
          finish(
            token,
            _TransferState(
              messageKey: 'json.saveFailed',
              failed: true,
              fallback: text,
            ),
          );
        }
      } else {
        try {
          await widget.platform.copyText(text);
          finish(token, const _TransferState(messageKey: 'json.copied'));
        } catch (_) {
          finish(
            token,
            _TransferState(
              messageKey: 'json.clipboardFailed',
              failed: true,
              fallback: text,
              example: example,
            ),
          );
        }
      }
    } catch (_) {
      finish(
        token,
        const _TransferState(messageKey: 'json.exportFailed', failed: true),
      );
    }
  }

  Future<void> returnToCollection() async {
    if (!mounted || transfer.busy || returning) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route?.isCurrent != true || !navigator.canPop()) return;
    final collectionId = widget.collection.id;
    final service = widget.service;
    final platform = widget.platform;
    setState(() => returning = true);
    // Give PopScope the permitted state before the deliberate typed return.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted &&
        !transfer.busy &&
        route?.isCurrent == true &&
        widget.collection.id == collectionId &&
        widget.service == service &&
        widget.platform == platform) {
      navigator.pop<VocabularyJsonReturn>(VocabularyJsonReturn.collection);
    }
    if (mounted) setState(() => returning = false);
  }

  Widget feedback(BuildContext context, _TransferSection section) {
    if (confirming ||
        transferSection != section ||
        !(transfer.busy ||
            transfer.messageKey != null ||
            transfer.fallback != null)) {
      return const SizedBox.shrink();
    }
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.dimension('spacing.2')),
        if (transfer.busy || transfer.messageKey != null)
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transfer.busy) ...[
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: d.dimension('components.icons.size'),
                      child: CircularProgressIndicator(
                        strokeWidth: d.dimension('states.borderWidth'),
                      ),
                    ),
                  ),
                  SizedBox(width: d.dimension('spacing.2')),
                ],
                Expanded(
                  child: Text(
                    copy.text(
                      transfer.busy ? 'json.working' : transfer.messageKey!,
                      transfer.busy ? const {} : transfer.arguments,
                    ),
                    style: TextStyle(
                      color: d.color(transfer.failed ? 'danger' : 'ink'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (transfer.fallback != null) ...[
          SizedBox(height: d.dimension('spacing.2')),
          PikoField(
            label: copy.text(
              transfer.example ? 'json.exampleNotice' : 'json.export',
            ),
            child: TextField(
              key: const ValueKey('json-fallback'),
              controller: fallback,
              readOnly: true,
              minLines: 4,
              maxLines: 8,
              decoration: pikoInputDecoration(),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final gap = d.dimension('spacing.4');
    final collectionId = widget.collection.id;
    final service = widget.service;
    final platform = widget.platform;
    final currentView = view;
    Widget action(
      String key,
      VoidCallback callback, {
      PikoButtonVariant variant = PikoButtonVariant.neutral,
    }) => PikoButton(
      label: copy.text(key),
      onPressed: transfer.busy || returning
          ? null
          : () {
              if (!mounted ||
                  transfer.busy ||
                  returning ||
                  view != currentView ||
                  widget.collection.id != collectionId ||
                  widget.service != service ||
                  widget.platform != platform) {
                return;
              }
              callback();
            },
      variant: variant,
    );
    Widget tab(_JsonView value) => Expanded(
      child: Semantics(
        selected: view == value,
        child: PikoButton(
          key: ValueKey(
            value == _JsonView.importJson
                ? 'json-import-tab'
                : 'json-export-tab',
          ),
          label: copy.text(
            value == _JsonView.importJson ? 'json.importTab' : 'json.exportTab',
          ),
          variant: view == value
              ? PikoButtonVariant.primary
              : PikoButtonVariant.neutral,
          onPressed: transfer.busy || returning
              ? null
              : () {
                  if (!mounted ||
                      transfer.busy ||
                      returning ||
                      widget.collection.id != collectionId ||
                      widget.service != service ||
                      widget.platform != platform ||
                      ModalRoute.of(context)?.isCurrent != true ||
                      view == value) {
                    return;
                  }
                  FocusScope.of(context).unfocus();
                  setState(() {
                    view = value;
                    transfer = const _TransferState();
                    fallback.clear();
                  });
                },
        ),
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asDialog)
          PikoHeading(
            title: copy.text('json.title'),
            subtitle: widget.collection.name,
            leading: PikoButton(
              label: copy.text('common.back'),
              variant: PikoButtonVariant.ghost,
              onPressed: transfer.busy || returning ? null : returnToCollection,
            ),
          ),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tab(_JsonView.importJson),
            SizedBox(width: d.dimension('spacing.2')),
            tab(_JsonView.exportJson),
          ],
        ),
        SizedBox(height: gap),
        if (view == _JsonView.exportJson) ...[
          Text(copy.text('json.collectionNotice')),
          SizedBox(height: gap),
          Wrap(
            spacing: d.dimension('spacing.2'),
            runSpacing: d.dimension('spacing.2'),
            children: [
              action(
                'json.copy',
                () => launch(() => export()),
                variant: PikoButtonVariant.primary,
              ),
              action(
                'json.download',
                () => launch(() => export(download: true)),
                variant: PikoButtonVariant.primary,
              ),
            ],
          ),
          feedback(context, _TransferSection.exportJson),
        ] else ...[
          Text(copy.text('json.exampleNotice')),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: action(
              'json.example',
              () => launch(() => export(example: true)),
            ),
          ),
          feedback(context, _TransferSection.example),
          SizedBox(height: gap),
          Wrap(
            spacing: d.dimension('spacing.2'),
            runSpacing: d.dimension('spacing.2'),
            children: [
              action('json.file', () => launch(() => read(file: true))),
              action('json.paste', () => launch(() => read(file: false))),
            ],
          ),
          SizedBox(height: d.dimension('spacing.2')),
          PikoField(
            label: copy.text('json.input'),
            child: TextField(
              key: const ValueKey('json-input'),
              controller: input,
              enabled: !confirming && !applying && !returning,
              minLines: expandedInput ? 6 : 2,
              maxLines: expandedInput ? 12 : 4,
              decoration: pikoInputDecoration(),
              onChanged: (_) => setState(invalidateInput),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: action(
              expandedInput ? 'json.collapseInput' : 'json.expandInput',
              () => setState(() => expandedInput = !expandedInput),
            ),
          ),
          feedback(context, _TransferSection.input),
          SizedBox(height: gap),
          Text(copy.text('r2.jsonNotice')),
          SizedBox(height: d.dimension('spacing.2')),
          Text(copy.text('r2.jsonMetadata')),
          SizedBox(height: gap),
          Text(copy.text('r2.jsonGroups')),
          for (final group in VocabularyJsonGroup.values)
            CheckboxListTile(
              key: ValueKey('json-group-${group.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                copy.text(switch (group) {
                  VocabularyJsonGroup.targetText => 'r2.targetText',
                  VocabularyJsonGroup.nativeText => 'r2.nativeText',
                  VocabularyJsonGroup.categoryAssignments =>
                    'r2.categoryAssignments',
                  VocabularyJsonGroup.example => 'vocab.examples',
                  VocabularyJsonGroup.hint => 'vocab.hint',
                }),
              ),
              value: groups.contains(group),
              onChanged: transfer.busy || returning
                  ? null
                  : (selected) {
                      setState(() {
                        final next = {...groups};
                        if (selected == true) {
                          next.add(group);
                        } else {
                          next.remove(group);
                        }
                        groups = Set.unmodifiable(next);
                        invalidateInput();
                      });
                    },
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: action(
              'json.analyze',
              () => launch(analyze),
              variant: PikoButtonVariant.primary,
            ),
          ),
          if (review case final result?) ...[
            SizedBox(height: gap),
            Text(copy.text('r2.jsonSummary', result.counts)),
            for (final issue in result.issues) ...[
              SizedBox(height: d.dimension('spacing.2')),
              Text(
                copy.text(
                  issue.row == null ? 'json.issuePath' : 'json.issueLocation',
                  {
                    'path': issue.path,
                    if (issue.row != null) 'row': issue.row!,
                  },
                ),
              ),
              Text(
                copy.text(issueKey(issue.code)),
                style: TextStyle(color: d.color('danger')),
              ),
            ],
            if (result.canApply)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: action(
                  'json.apply',
                  () => launch(() => confirmImport(result)),
                  variant: PikoButtonVariant.primary,
                ),
              ),
          ],
          feedback(context, _TransferSection.review),
          if (transferSection == _TransferSection.review &&
              transfer.messageKey == 'json.importApplied') ...[
            SizedBox(height: d.dimension('spacing.2')),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: action(
                'json.returnToCollection',
                returnToCollection,
                variant: PikoButtonVariant.primary,
              ),
            ),
          ],
        ],
      ],
    );
    return PopScope<VocabularyJsonReturn>(
      canPop: returning && !transfer.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(returnToCollection());
      },
      child: widget.asDialog
          ? PikoDialog(
              title: copy.text('json.title'),
              dismissible: !transfer.busy && !confirming && !applying,
              onClose: returnToCollection,
              body: content,
            )
          : Scaffold(body: PikoPage(child: content)),
    );
  }

  @override
  void dispose() {
    request = null;
    dismissConfirmation();
    final draft = widget.draft;
    if (draft != null) {
      draft.input = input.value;
      draft.groups = Set.unmodifiable(groups);
      draft.expanded = expandedInput;
    }
    input.dispose();
    fallback.dispose();
    super.dispose();
  }
}
