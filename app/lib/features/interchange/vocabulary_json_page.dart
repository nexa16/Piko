import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_json.dart';
import '../../platform/vocabulary_json_platform.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_field.dart';
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
  });
  final bool busy, failed, example;
  final String? messageKey, fallback;
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
  });
  final CollectionRecord collection;
  final VocabularyJsonService service;
  final VocabularyJsonPlatform platform;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<VocabularyJsonPage> createState() => _VocabularyJsonPageState();
}

class _VocabularyJsonPageState extends State<VocabularyJsonPage> {
  final input = TextEditingController(), fallback = TextEditingController();
  _TransferState transfer = const _TransferState();
  Object? request;
  int inputRevision = 0;

  @override
  void didUpdateWidget(VocabularyJsonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.service != widget.service ||
        oldWidget.platform != widget.platform) {
      request = null;
      inputRevision++;
      transfer = const _TransferState();
      fallback.clear();
      if (oldWidget.collection.id != widget.collection.id) input.clear();
    }
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
        inputRevision++;
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
                  minLines: 6,
                  maxLines: 12,
                  decoration: pikoInputDecoration(),
                  onChanged: (_) {
                    inputRevision++;
                  },
                ),
              ),
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
    input.dispose();
    fallback.dispose();
    super.dispose();
  }
}
