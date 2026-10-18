import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/components/piko_focus_highlight.dart';
import '../../ui/piko_theme.dart';
import 'ai_content.dart';
import 'entry_ai_controller.dart';

String aiFailureKey(AiFailure failure) => switch (failure) {
  AiFailure.unavailable => 'ai.unavailable',
  AiFailure.authentication => 'ai.authenticationFailed',
  AiFailure.limit => 'ai.limit',
  AiFailure.busy => 'ai.busy',
  AiFailure.invalidResponse => 'ai.invalidResponse',
  AiFailure.connection => 'ai.connectionFailed',
};

Future<bool> connectAi(BuildContext context, AiAccess access) async {
  if (access.enabled) return true;
  if (!access.configured || access.busy) return false;
  final copy = PikoCopyScope.of(context);
  final accepted = await showPikoDialog<bool>(
    context,
    builder: (dialogContext) => PikoDialog(
      purpose: PikoDialogPurpose.confirmation,
      title: copy.text('ai.connectionTitle'),
      body: Text(copy.text('ai.processing')),
      actions: [
        PikoDialogAction(
          label: copy.text('action.cancel'),
          role: PikoDialogActionRole.safe,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PikoDialogAction(
          label: copy.text('ai.enable'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  if (accepted != true ||
      !context.mounted ||
      ModalRoute.of(context)?.isCurrent != true) {
    return false;
  }
  await access.connect();
  return context.mounted && access.enabled;
}

class AiConnectionControl extends StatelessWidget {
  const AiConnectionControl({required this.access, super.key});
  final AiAccess access;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: access,
    builder: (context, _) {
      final copy = PikoCopyScope.of(context);
      return Padding(
        padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.4')),
        child: PikoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.text('ai.connectionTitle')),
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              Text(
                copy.text(
                  !access.configured
                      ? 'ai.unavailable'
                      : access.enabled
                      ? 'ai.connected'
                      : 'ai.disconnected',
                ),
              ),
              if (access.error case final error?)
                Semantics(
                  liveRegion: true,
                  child: Text(copy.text(aiFailureKey(error))),
                ),
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              PikoButton(
                key: const ValueKey('ai-connection'),
                label: copy.text(
                  access.busy
                      ? 'ai.connecting'
                      : access.enabled
                      ? 'ai.disconnect'
                      : 'ai.enable',
                ),
                onPressed: !access.configured || access.busy
                    ? null
                    : () async {
                        if (ModalRoute.of(context)?.isCurrent != true) return;
                        if (access.enabled) {
                          await access.disconnect();
                        } else {
                          await connectAi(context, access);
                        }
                      },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AiSuggestionControl extends StatefulWidget {
  const AiSuggestionControl({
    required this.controller,
    required this.task,
    super.key,
  });
  final EntryAiController controller;
  final AiTask task;
  @override
  State<AiSuggestionControl> createState() => _AiSuggestionControlState();
}

class _AiSuggestionControlState extends State<AiSuggestionControl> {
  bool connecting = false;
  final suggestFocus = FocusNode(),
      useFocus = FocusNode(),
      discardFocus = FocusNode();
  @override
  void dispose() {
    suggestFocus.dispose();
    useFocus.dispose();
    discardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller, task = widget.task;
      final access = controller.access, copy = PikoCopyScope.of(context);
      final owns = controller.task == task;
      final suggestion = owns ? controller.suggestion : null;
      Future<void> request() async {
        if (connecting ||
            !controller.eligible ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        setState(() => connecting = true);
        try {
          if (controller.error == AiFailure.authentication) {
            await access.disconnect();
            if (!context.mounted) return;
          }
          if (!await connectAi(context, access) ||
              !context.mounted ||
              !identical(controller, widget.controller) ||
              ModalRoute.of(context)?.isCurrent != true) {
            return;
          }
          await controller.request(task);
        } finally {
          if (mounted) setState(() => connecting = false);
        }
      }

      final available =
          access.configured &&
          controller.eligible &&
          (!access.busy || (controller.pending && !owns)) &&
          !connecting;
      void finish({required bool use}) {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (useFocus.hasFocus || discardFocus.hasFocus) {
          suggestFocus.requestFocus();
        }
        if (use) {
          controller.use();
        } else {
          controller.cancel();
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            key: ValueKey('ai-suggest-focus-${task.name}'),
            focusNode: suggestFocus,
            includeSemantics: false,
            onFocusChange: (_) {
              if (mounted) setState(() {});
            },
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                if (available) {
                  PikoAnchorRegion.capture(context);
                  request();
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: PikoFocusHighlight(
              builder: (context, visible) => MergeSemantics(
                child: Semantics(
                  focused: suggestFocus.hasFocus,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        pikoDesign.dimension('components.buttons.radius'),
                      ),
                      border: Border.all(
                        color: visible && suggestFocus.hasFocus
                            ? pikoDesign.color('primary')
                            : Colors.transparent,
                        width: pikoDesign.dimension('states.focusWidth'),
                      ),
                    ),
                    child: ExcludeFocus(
                      child: PikoButton(
                        key: ValueKey('ai-suggest-${task.name}'),
                        label: copy.text(
                          task == AiTask.example
                              ? 'ai.suggestExample'
                              : 'ai.suggestHint',
                        ),
                        icon: PikoIcon(
                          task == AiTask.example
                              ? PikoIconName.bookOpen
                              : PikoIconName.info,
                        ),
                        onPressed: available ? request : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!access.configured) Text(copy.text('ai.unavailable')),
          if (owns && controller.pending) ...[
            Semantics(
              liveRegion: true,
              child: Text(copy.text('ai.generating')),
            ),
            PikoButton(
              label: copy.text('action.cancel'),
              focusNode: discardFocus,
              onPressed: () => finish(use: false),
            ),
          ],
          if (owns && controller.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(copy.text(aiFailureKey(controller.error!))),
            ),
            PikoButton(
              label: copy.text('action.retry'),
              onPressed: access.busy ? null : request,
            ),
          ],
          if (access.error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(copy.text(aiFailureKey(error))),
            ),
          if (suggestion != null) ...[
            Text(copy.text('ai.review')),
            if (suggestion is AiExample) ...[
              Text(suggestion.pair.targetText),
              Text(suggestion.pair.nativeText),
            ],
            if (suggestion is AiHint) Text(suggestion.text),
            PikoButton(
              key: ValueKey('ai-use-${task.name}'),
              focusNode: useFocus,
              label: copy.text(
                task == AiTask.example
                    ? 'ai.useExample'
                    : (controller.session.draft.content.hintText
                              ?.trim()
                              .isNotEmpty ??
                          false)
                    ? 'ai.replaceHint'
                    : 'ai.useHint',
              ),
              onPressed: () => finish(use: true),
            ),
            PikoButton(
              label: copy.text('ai.discard'),
              focusNode: discardFocus,
              onPressed: () => finish(use: false),
              variant: PikoButtonVariant.ghost,
            ),
          ],
          SizedBox(height: pikoDesign.dimension('spacing.3')),
        ],
      );
    },
  );
}
