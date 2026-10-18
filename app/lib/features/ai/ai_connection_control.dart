import 'package:flutter/material.dart';
import '../../data/ai/ai_contract.dart';
import '../../data/ai/ai_connection_controller.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_form.dart';

class AiConnectionControl extends StatefulWidget {
  const AiConnectionControl({
    super.key,
    required this.connection,
    required this.consent,
    this.enabled = true,
  });
  final AiConnectionController connection;
  final bool consent, enabled;
  @override
  State<AiConnectionControl> createState() => _AiConnectionControlState();
}

class _AiConnectionControlState extends State<AiConnectionControl> {
  @override
  void initState() {
    super.initState();
    widget.connection.loadLocal();
  }

  Future<void> _connect() async {
    try {
      await widget.connection.connect();
    } catch (_) {
      /* Localized state retains explicit recovery. */
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.connection.disconnect();
    } catch (_) {
      if (mounted) {
        setState(() => widget.connection.error = AiFailure.unavailable);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.connection,
    builder: (context, _) {
      final c = widget.connection,
          copy = PikoCopyScope.of(context),
          busy = !widget.enabled || c.busy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PikoFormFieldRow(
            child: Text(
              copy.text(
                !c.configured
                    ? 'ai.connectionUnconfigured'
                    : c.busy
                    ? 'ai.connecting'
                    : c.deviceAccessId == null
                    ? 'ai.notConnected'
                    : 'ai.identityReady',
              ),
            ),
          ),
          if (c.deviceAccessId != null)
            PikoFormFieldRow(
              child: SelectableText(
                copy.text('ai.accessId', {'id': c.deviceAccessId!}),
              ),
            ),
          if (c.error != null)
            PikoFormFieldRow(
              child: Text(copy.text('ai.error.${c.error!.name}')),
            ),
          PikoFormFieldRow(
            child: PikoButton(
              label: copy.text('ai.connect'),
              onPressed: busy || !c.configured || !widget.consent
                  ? null
                  : _connect,
            ),
          ),
          if (c.deviceAccessId != null)
            PikoFormFieldRow(
              child: PikoButton(
                label: copy.text('ai.disconnect'),
                variant: PikoButtonVariant.ghost,
                onPressed: busy ? null : _disconnect,
              ),
            ),
        ],
      );
    },
  );
}
