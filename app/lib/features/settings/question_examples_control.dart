import 'package:flutter/material.dart';
import '../../data/settings_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_checkbox.dart';
import '../../ui/piko_theme.dart';

class QuestionExamplesControl extends StatefulWidget {
  const QuestionExamplesControl({
    required this.repository,
    required this.registerPending,
    super.key,
  });
  final SettingsRepository repository;
  final ValueChanged<Future<void>> registerPending;
  @override
  State<QuestionExamplesControl> createState() =>
      _QuestionExamplesControlState();
}

class _QuestionExamplesControlState extends State<QuestionExamplesControl> {
  bool ready = false, pending = false, value = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (pending) return;
    setState(() {
      pending = true;
      error = null;
    });
    try {
      final saved = await widget.repository.read('questionExamples');
      if (mounted) {
        setState(() {
          value = saved != 'false';
          ready = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  void select(bool requested) {
    if (pending || !ready || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      pending = true;
      error = null;
    });
    final operation = save(requested);
    widget.registerPending(operation);
  }

  Future<void> save(bool requested) async {
    try {
      await widget.repository.write('questionExamples', requested.toString());
      if (mounted) setState(() => value = requested);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => pending = false);
    }
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
            if (ready)
              PikoCheckbox(
                key: const ValueKey('settings-question-examples'),
                label: copy.text('settings.questionExamples'),
                value: value,
                onChanged: pending ? null : select,
              ),
            if (pending)
              Text(copy.text(ready ? 'settings.saving' : 'settings.loading')),
            if (error != null) ...[
              Text(
                copy.text(
                  ready ? 'settings.saveFailed' : 'settings.loadFailed',
                ),
              ),
              if (!ready)
                PikoButton(
                  label: copy.text('action.retry'),
                  onPressed: pending ? null : load,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
