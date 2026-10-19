import 'package:flutter/material.dart';
import '../../data/ai/ai_contract.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_form.dart';

/// Notice and consent are checked by the backend, independently of the APK flag.
class AiPilotControl extends StatefulWidget {
  const AiPilotControl({
    super.key,
    required this.provider,
    required this.onReady,
    required this.onWithdraw,
    this.enabled = true,
  });
  final AiPilotAccess provider;
  final ValueChanged<bool> onReady;
  final VoidCallback onWithdraw;
  final bool enabled;
  @override
  State<AiPilotControl> createState() => _AiPilotControlState();
}

class _AiPilotControlState extends State<AiPilotControl> {
  Map<String, Object?>? notice;
  bool busy = false, withdrawn = false, withdrawalRequested = false;
  AiFailure? error;
  Future<void> run(String operation) async {
    if (busy) return;
    if (operation == 'withdraw') {
      withdrawalRequested = true;
      widget.onReady(false);
      widget.onWithdraw();
    }
    setState(() => busy = true);
    try {
      final result = await widget.provider.pilot(
        operation,
        operation == 'consent' ? {'version': notice!['version']} : const {},
      );
      if (!mounted) return;
      if (operation == 'withdraw') {
        withdrawn = true;
        notice = null;
      } else {
        if (['version', 'contact', 'processors', 'endsAt'].any(
          (k) => result[k] is! String || (result[k] as String).trim().isEmpty,
        )) {
          throw AiFailure.invalidResponse;
        }
        notice = result;
        widget.onReady(result['consented'] == true);
      }
      error = null;
    } catch (e) {
      if (mounted) {
        error = e is AiFailure ? e : AiFailure.unavailable;
        widget.onReady(false);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null)
          PikoFormFieldRow(
            child: Text(
              copy.text('ai.pilotDetails', {
                'contact': notice!['contact']!,
                'processors': notice!['processors']!,
                'end': notice!['endsAt']!,
              }),
            ),
          ),
        if (withdrawn)
          PikoFormFieldRow(child: Text(copy.text('ai.pilotWithdrawn'))),
        if (withdrawalRequested && !withdrawn && error != null)
          PikoFormFieldRow(child: Text(copy.text('ai.withdrawPending'))),
        if (error != null)
          PikoFormFieldRow(child: Text(copy.text('ai.error.${error!.name}'))),
        PikoFormFieldRow(
          child: PikoButton(
            key: const ValueKey('ai-pilot-notice'),
            label: copy.text('ai.pilotNotice'),
            onPressed: busy || withdrawalRequested || !widget.enabled
                ? null
                : () => run('notice'),
          ),
        ),
        if (!withdrawalRequested &&
            notice != null &&
            notice!['consented'] != true)
          PikoFormFieldRow(
            child: PikoButton(
              key: const ValueKey('ai-pilot-consent'),
              label: copy.text('ai.pilotAgree'),
              onPressed: busy || withdrawalRequested || !widget.enabled
                  ? null
                  : () => run('consent'),
            ),
          ),
        if (!withdrawn)
          PikoFormFieldRow(
            child: PikoButton(
              key: const ValueKey('ai-pilot-withdraw'),
              label: copy.text('ai.pilotWithdraw'),
              onPressed: busy ? null : () => run('withdraw'),
            ),
          ),
      ],
    );
  }
}
