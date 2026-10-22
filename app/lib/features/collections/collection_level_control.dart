import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_preference_picker.dart';

class CollectionLevelControl extends StatefulWidget {
  const CollectionLevelControl({
    required this.collection,
    required this.repository,
    required this.enabled,
    this.onPendingWrites,
    this.onBusyChanged,
    super.key,
  });
  final CollectionRecord collection;
  final CollectionLevelRepository repository;
  final bool enabled;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<CollectionLevelControl> createState() => _CollectionLevelControlState();
}

class _CollectionLevelControlState extends State<CollectionLevelControl> {
  late String value = widget.collection.level;
  bool busy = false;
  Object? error;
  @override
  void didUpdateWidget(CollectionLevelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!busy) value = widget.collection.level;
  }

  Future<void> select(String level) async {
    if (busy || !widget.enabled || level == value) return;
    setState(() {
      busy = true;
      error = null;
    });
    widget.onBusyChanged?.call(true);
    final operation = widget.repository.setLevel(
      id: widget.collection.id,
      level: level,
    );
    widget.onPendingWrites?.call(
      operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      final saved = await operation;
      if (mounted) setState(() => value = saved.level);
    } catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PikoPreferencePicker<String>(
          key: const ValueKey('collection-settings-level'),
          label: copy.text('collection.level'),
          value: value,
          choices: [
            for (final level in CollectionRecord.levels) (level, level),
          ],
          onChanged: widget.enabled && !busy ? select : null,
        ),
        if (error != null) Text(copy.text('collection.saveFailed')),
      ],
    );
  }
}
