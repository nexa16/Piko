import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_json.dart';
import '../../platform/vocabulary_json_platform.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';

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
  });
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
  ModalRoute<dynamic>? confirmationRoute;

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
      dismissConfirmation();
      fallback.clear();
      if (oldWidget.collection.id != widget.collection.id) {
        input.clear();
        groups = Set.unmodifiable(VocabularyJsonGroup.all);
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
  }

  Object begin() {
    final token = Object();
    request = token;
    setState(() {
      transfer = const _TransferState(busy: true);
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
    final token = begin();
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
    final token = begin();
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
    final token = begin();
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
    final token = begin();
    String? text;
    try {
      if (example) {
        text = widget.service.sampleJson();
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

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final gap = pikoDesign.dimension('spacing.4');
    final collectionId = widget.collection.id;
    final service = widget.service;
    final platform = widget.platform;
    Widget action(String key, VoidCallback callback) => PikoButton(
      label: copy.text(key),
      onPressed: transfer.busy
          ? null
          : () {
              if (!mounted ||
                  widget.collection.id != collectionId ||
                  widget.service != service ||
                  widget.platform != platform) {
                return;
              }
              callback();
            },
      variant: PikoButtonVariant.neutral,
    );
    return PopScope(
      canPop: !transfer.busy,
      child: Scaffold(
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoHeading(
                title: copy.text('json.title'),
                subtitle: widget.collection.name,
                leading: PikoButton(
                  label: copy.text('common.back'),
                  variant: PikoButtonVariant.ghost,
                  onPressed: transfer.busy
                      ? null
                      : () {
                          if (mounted &&
                              ModalRoute.of(context)?.isCurrent != false) {
                            Navigator.of(context).maybePop();
                          }
                        },
                ),
              ),
              SizedBox(height: gap),
              Text(copy.text('json.collectionNotice')),
              SizedBox(height: gap),
              Wrap(
                spacing: pikoDesign.dimension('spacing.2'),
                runSpacing: pikoDesign.dimension('spacing.2'),
                children: [
                  action('json.file', () => launch(() => read(file: true))),
                  action('json.paste', () => launch(() => read(file: false))),
                ],
              ),
              SizedBox(height: gap),
              PikoField(
                label: copy.text('json.input'),
                child: TextField(
                  key: const ValueKey('json-input'),
                  controller: input,
                  enabled: !confirming && !applying,
                  minLines: 6,
                  maxLines: 12,
                  decoration: pikoInputDecoration(),
                  onChanged: (_) {
                    setState(() {
                      invalidateInput();
                    });
                  },
                ),
              ),
              SizedBox(height: gap),
              Text(copy.text('r2.jsonNotice')),
              SizedBox(height: pikoDesign.dimension('spacing.2')),
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
                    }),
                  ),
                  value: groups.contains(group),
                  onChanged: transfer.busy
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
                child: action('json.analyze', () => launch(analyze)),
              ),
              if (review case final result?) ...[
                SizedBox(height: gap),
                Text(copy.text('r2.jsonSummary', result.counts)),
                for (final issue in result.issues) ...[
                  SizedBox(height: pikoDesign.dimension('spacing.2')),
                  Text(
                    copy.text(
                      issue.row == null
                          ? 'json.issuePath'
                          : 'json.issueLocation',
                      {
                        'path': issue.path,
                        if (issue.row != null) 'row': issue.row!,
                      },
                    ),
                  ),
                  Text(
                    copy.text(issueKey(issue.code)),
                    style: TextStyle(color: pikoDesign.color('danger')),
                  ),
                ],
                if (result.canApply)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: action(
                      'json.apply',
                      () => launch(() => confirmImport(result)),
                    ),
                  ),
              ],
              SizedBox(height: gap),
              Text(copy.text('json.exampleNotice')),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: action(
                  'json.example',
                  () => launch(() => export(example: true)),
                ),
              ),
              SizedBox(height: gap),
              PikoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      copy.text('json.export'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: pikoDesign.dimension('spacing.2')),
                    Wrap(
                      spacing: pikoDesign.dimension('spacing.2'),
                      runSpacing: pikoDesign.dimension('spacing.2'),
                      children: [
                        action('json.copy', () => launch(() => export())),
                        action(
                          'json.download',
                          () => launch(() => export(download: true)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (transfer.busy || transfer.messageKey != null) ...[
                SizedBox(height: gap),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    copy.text(
                      transfer.busy ? 'json.working' : transfer.messageKey!,
                      transfer.busy ? const {} : transfer.arguments,
                    ),
                    style: TextStyle(
                      color: pikoDesign.color(
                        transfer.failed ? 'danger' : 'muted',
                      ),
                    ),
                  ),
                ),
              ],
              if (transfer.fallback != null) ...[
                SizedBox(height: gap),
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
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    request = null;
    dismissConfirmation();
    input.dispose();
    fallback.dispose();
    super.dispose();
  }
}
