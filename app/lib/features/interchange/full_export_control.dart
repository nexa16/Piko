import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/full_export.dart';
import '../../platform/vocabulary_json_platform.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/piko_theme.dart';

class FullExportControl extends StatefulWidget {
  const FullExportControl({
    super.key,
    required this.service,
    required this.platform,
    required this.registerPending,
  });
  final FullExportService service;
  final VocabularyJsonPlatform platform;
  final ValueChanged<Future<void>> registerPending;
  @override
  State<FullExportControl> createState() => _FullExportControlState();
}

class _FullExportControlState extends State<FullExportControl> {
  final focus = FocusNode();
  Object? request;
  String? message;
  bool failed = false;

  @override
  void didUpdateWidget(FullExportControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.platform != widget.platform) {
      request = null;
      message = null;
      failed = false;
    }
  }

  @override
  void dispose() {
    request = null;
    focus.dispose();
    super.dispose();
  }

  void start() {
    if (request != null || ModalRoute.of(context)?.isCurrent != true) return;
    final token = Object(),
        service = widget.service,
        platform = widget.platform;
    final route = ModalRoute.of(context);
    final restoreFocus = focus.hasFocus;
    final drained = Completer<void>();
    widget.registerPending(drained.future);
    setState(() {
      request = token;
      failed = false;
      message = 'fullExport.preparing';
    });
    bool current() =>
        mounted && identical(request, token) && route?.isCurrent == true;
    Future<void> run() async {
      var next = 'fullExport.cancelled', error = false;
      try {
        final json = await service.exportAll();
        if (!current()) return;
        if (await platform.saveFile(json)) next = 'json.fileSaved';
      } catch (_) {
        next = 'fullExport.failed';
        error = true;
      } finally {
        if (mounted && identical(request, token)) {
          final visible = route?.isCurrent == true;
          setState(() {
            request = null;
            message = visible ? next : null;
            failed = visible && error;
          });
          if (visible && restoreFocus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && request == null && route?.isCurrent == true) {
                focus.requestFocus();
              }
            });
          }
        }
        drained.complete();
      }
    }

    unawaited(run());
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Padding(
      padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.4')),
      child: PikoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PikoButton(
              key: const ValueKey('settings-full-export'),
              focusNode: focus,
              label: copy.text(failed ? 'action.retry' : 'fullExport.action'),
              onPressed: request == null ? start : null,
            ),
            if (message case final key?) ...[
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              Semantics(
                liveRegion: true,
                child: Text(
                  copy.text(key),
                  key: const ValueKey('full-export-status'),
                  style: failed
                      ? TextStyle(color: pikoDesign.color('danger'))
                      : null,
                ),
              ),
            ],
            SizedBox(height: pikoDesign.dimension('spacing.2')),
            Text(copy.text('fullExport.description')),
          ],
        ),
      ),
    );
  }
}
