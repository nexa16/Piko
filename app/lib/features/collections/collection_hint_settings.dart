import '../../ui/components/piko_switch.dart';
import 'package:flutter/material.dart';
import '../../data/vocabulary_content.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';

class CollectionHintSettings extends StatefulWidget {
  const CollectionHintSettings({
    required this.collectionId,
    required this.repository,
    this.onPendingWrites,
    this.onBusyChanged,
    this.enabled = true,
    super.key,
  });
  final String collectionId;
  final VocabularyContentRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool>? onBusyChanged;
  final bool enabled;
  @override
  State<CollectionHintSettings> createState() => _CollectionHintSettingsState();
}

class _CollectionHintSettingsState extends State<CollectionHintSettings> {
  bool? value;
  bool busy = false, failed = false;
  bool? attempted;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final revision = generation;
    try {
      final v = await widget.repository.readHintVisibilityDefault(
        collectionId: widget.collectionId,
      );
      if (mounted && generation == revision) {
        setState(() {
          value = v == HintVisibility.always;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == revision) setState(() => failed = true);
    }
  }

  Future<void> save(bool next) async {
    if (busy || !widget.enabled || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final revision = generation, changed = widget.onBusyChanged;
    setState(() {
      busy = true;
      failed = false;
      attempted = next;
    });
    changed?.call(true);
    final operation = (widget.repository as CollectionHintPreferences)
        .setCollectionHintDefault(widget.collectionId, next);
    widget.onPendingWrites?.call(operation);
    try {
      await operation;
      if (mounted && generation == revision) setState(() => value = next);
    } catch (_) {
      if (mounted && generation == revision) setState(() => failed = true);
    } finally {
      if (mounted && generation == revision) setState(() => busy = false);
      changed?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value == null && !failed) const LinearProgressIndicator(),
        if (value != null)
          PikoSwitch(
            key: const ValueKey('collection-hint-default'),

            title: Text(copy.text('vocab.collectionHintDefault')),
            subtitle: Text(copy.text('vocab.collectionHintDefaultHelp')),
            value: value!,
            onChanged: busy || !widget.enabled ? null : save,
          ),
        if (failed) ...[
          Text(copy.text('vocab.hintDefaultFailed')),
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: busy || !widget.enabled
                ? null
                : () => attempted == null ? load() : save(attempted!),
          ),
        ],
      ],
    );
  }

  @override
  void didUpdateWidget(CollectionHintSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId ||
        oldWidget.repository != widget.repository) {
      generation++;
      value = null;
      busy = false;
      failed = false;
      attempted = null;
      load();
    }
  }
}
