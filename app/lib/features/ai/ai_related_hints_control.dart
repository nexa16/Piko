import 'package:flutter/material.dart';
import '../../data/ai/ai_contract.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_form.dart';
import 'ai_page.dart';

/// Discovery is an entirely local read. It never creates a temporary saved card
/// or sends requests while the learner types.
class AiRelatedHintsControl extends StatefulWidget {
  const AiRelatedHintsControl({
    super.key,
    required this.support,
    required this.anchor,
    required this.collectionName,
    required this.settleAnchor,
    this.enabled = true,
    this.onStaged,
    this.onApplied,
    this.registerPending,
  });
  final AiSupport support;
  final AiEntry anchor;
  final String collectionName;
  final bool enabled;
  final Future<AiEntry> Function() settleAnchor;
  final Future<void> Function(AiStagedHints)? onStaged;
  final Future<void> Function(AiAdoption)? onApplied;
  final void Function(Future<void>)? registerPending;
  @override
  State<AiRelatedHintsControl> createState() => _AiRelatedHintsControlState();
}

class _AiRelatedHintsControlState extends State<AiRelatedHintsControl> {
  int count = 0, _revision = 0;
  bool opening = false;
  AiFailure? error;
  @override
  void initState() {
    super.initState();
    _discover();
  }

  @override
  void didUpdateWidget(AiRelatedHintsControl old) {
    super.didUpdateWidget(old);
    if (old.support != widget.support ||
        aiContentKey(old.anchor.toJson()) !=
            aiContentKey(widget.anchor.toJson())) {
      _discover();
    }
  }

  Future<void> _discover() async {
    final owner = ++_revision;
    if (!widget.support.service.enabled) return;
    try {
      final group = (await widget.support.service.snapshot(
        widget.anchor.record.collectionId,
      )).related(widget.anchor);
      if (mounted && owner == _revision) {
        setState(() => count = group.entries.length - 1);
      }
    } catch (_) {
      if (mounted && owner == _revision) setState(() => count = 0);
    }
  }

  Future<void> _open() async {
    if (opening || !widget.enabled || !widget.support.service.enabled) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final revision = _revision;
      final anchor = await widget.settleAnchor();
      if (!mounted || revision != _revision) throw AiFailure.stale;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final selected = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) => AiPage(
            service: widget.support.service,
            provider: widget.support.provider,
            collectionId: anchor.record.collectionId,
            collectionName: widget.collectionName,
            anchor: anchor,
            stageOnly: widget.onStaged != null,
            initialAction: AiAction.hints,
            registerPending: widget.registerPending,
          ),
        ),
      );
      if (!mounted) return;
      if (selected is AiStagedHints && widget.onStaged != null) {
        await widget.onStaged!(selected);
      }
      if (selected is AiAdopted && widget.onApplied != null) {
        await widget.onApplied!(selected.adoption);
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is AiFailure ? failure : AiFailure.unavailable,
        );
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        _discover();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.support.service.enabled || count == 0) {
      return const SizedBox.shrink();
    }
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PikoNavigationRow(
          key: const ValueKey('ai-related-hints'),
          title: copy.text('ai.action.hints'),
          subtitle: copy.text('ai.relatedCount', {'count': count}),
          onTap:
              !widget.enabled ||
                  opening ||
                  widget.anchor.record.targetText.trim().isEmpty ||
                  widget.anchor.record.nativeText.trim().isEmpty
              ? null
              : _open,
        ),
        if (error != null)
          PikoFormFieldRow(child: Text(copy.text('ai.error.${error!.name}'))),
        if (error != null)
          PikoButton(
            label: copy.text('action.retry'),
            variant: PikoButtonVariant.ghost,
            onPressed: opening ? null : _open,
          ),
      ],
    );
  }
}
