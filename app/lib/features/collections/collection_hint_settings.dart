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
    super.key,
  });
  final String collectionId;
  final VocabularyContentRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<CollectionHintSettings> createState() => _CollectionHintSettingsState();
}

class _CollectionHintSettingsState extends State<CollectionHintSettings> {
  bool? value;
  bool busy = false, failed = false;
  bool? attempted;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final v = await widget.repository.readHintVisibilityDefault(
        collectionId: widget.collectionId,
      );
      if (mounted) {
        setState(() {
          value = v == HintVisibility.always;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> save(bool next) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
      attempted = next;
    });
    widget.onBusyChanged?.call(true);
    final operation = (widget.repository as CollectionHintPreferences)
        .setCollectionHintDefault(widget.collectionId, next);
    widget.onPendingWrites?.call(operation);
    try {
      await operation;
      if (mounted) setState(() => value = next);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
      widget.onBusyChanged?.call(false);
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
            onChanged: busy ? null : save,
          ),
        if (failed) ...[
          Text(copy.text('vocab.hintDefaultFailed')),
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: busy
                ? null
                : () => attempted == null ? load() : save(attempted!),
          ),
        ],
      ],
    );
  }
}
