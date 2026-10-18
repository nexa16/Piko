import '../../data/ai/ai_connection_controller.dart';
import '../../data/ai/managed_ai_provider.dart';
import 'ai_connection_control.dart';
import 'package:flutter/material.dart';
import '../../data/ai/ai_contract.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_checkbox.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_preference_picker.dart';
import '../../ui/piko_theme.dart';
import 'ai_operation_controller.dart';

final class AiAdopted {
  const AiAdopted(this.adoption);
  final AiAdoption adoption;
}

final class AiStagedHints {
  AiStagedHints(this.plan, Set<String> selected, {this.allowPartial = false})
    : selected = Set.unmodifiable(selected);
  final AiPlan plan;
  final Set<String> selected;
  final bool allowPartial;
}

class AiPage extends StatefulWidget {
  const AiPage({
    super.key,
    required this.service,
    required this.provider,
    required this.collectionId,
    required this.collectionName,
    this.registerPending,
    this.anchor,
    this.stageOnly = false,
    this.initialAction = AiAction.generate,
  });
  final AiContentService service;
  final AiProvider provider;
  final String collectionId, collectionName;
  final void Function(Future<void>)? registerPending;
  final AiEntry? anchor;
  final bool stageOnly;
  final AiAction initialAction;
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  late final controller = AiOperationController(
    service: widget.service,
    provider: widget.provider,
    collectionId: widget.collectionId,
    registerPending: widget.registerPending,
  )..addListener(_changed);
  final goal = TextEditingController();
  late AiAction action = widget.initialAction;
  bool allowGroups = true,
      allowValues = true,
      comprehensive = false,
      consent = false;
  List<AiEntry>? related;
  Set<String> targets = {};
  @override
  void initState() {
    super.initState();
    if (widget.anchor != null && widget.service.enabled) _loadRelated();
  }

  Future<void> _loadRelated() async {
    try {
      final entries = (await widget.service.snapshot(
        widget.collectionId,
      )).related(widget.anchor!).entries;
      if (mounted) {
        setState(() {
          related = entries;
          targets = entries.map((e) => e.record.id).toSet();
        });
      }
    } catch (_) {
      if (mounted) setState(() => controller.error = AiFailure.unavailable);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _invalidate() {
    controller.invalidate();
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    goal.dispose();
    super.dispose();
  }

  String _text(String key) => PikoCopyScope.of(context).text(key);
  bool get busy => controller.applying;
  AiConnectionController? get connection {
    final p = widget.provider;
    return p is ManagedAiProvider && p.access is AiConnectionController
        ? p.access as AiConnectionController
        : null;
  }

  Future<void> _start() async {
    if (!consent || busy || ModalRoute.of(context)?.isCurrent == false) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.start(
      action: action,
      goal: goal.text,
      comprehensiveLevel: action == AiAction.generate && comprehensive,
      allowGroups: allowGroups,
      allowValues: allowValues,
      anchor: widget.anchor,
      targets: action == AiAction.hints ? targets : null,
    );
  }

  Future<void> _apply() async {
    if (!controller.canApply || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.stageOnly) {
      if (!await widget.service.applicable(
        controller.plan!.request,
        currentDraft: widget.anchor,
      )) {
        if (mounted) setState(() => controller.error = AiFailure.stale);
        return;
      }
      if (mounted) {
        Navigator.of(context).pop(
          AiStagedHints(
            controller.plan!,
            controller.selected,
            allowPartial: controller.allowPartial,
          ),
        );
      }
      return;
    }
    try {
      final result = await controller.apply();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(AiAdopted(result));
      }
    } catch (_) {
      /* The controller keeps choices and localized failure. */
    }
  }

  String _value(Object? value, {String? field}) {
    if (value == null) return _text('ai.noHint');
    if (field == 'assignments' && value is Map) {
      final plan = controller.plan!;
      final groupNames = {
        for (final g in plan.request.snapshot.groups)
          g.dimension.id: g.dimension.name,
        for (final g in plan.groups) g.id: g.name,
      };
      final valueNames = {
        for (final g in plan.request.snapshot.groups)
          for (final v in g.values) v.id: v.name,
        for (final v in plan.values) v.id: v.name,
      };
      return value.entries
          .map(
            (g) =>
                '${groupNames[g.key] ?? _text('ai.unavailableClassification')}: ${(g.value as Iterable).map((v) => valueNames[v] ?? _text('ai.unavailableClassification')).join(', ')}',
          )
          .join('\n');
    }
    if (field == 'examples' && value is Iterable) {
      return value
          .map((v) => '${(v as Map)['target']}\n${v['native']}')
          .join('\n\n');
    }
    return value.toString();
  }

  Widget _proposal(
    String id,
    String title,
    List<Widget> children, {
    bool applicable = true,
  }) => PikoFormGroup(
    children: [
      PikoFormFieldRow(
        child: PikoCheckbox(
          key: ValueKey('ai-select-$id'),
          label: title,
          value: controller.selected.contains(id),
          onChanged: busy || controller.applied || !applicable
              ? null
              : (v) => controller.choose(id, v),
        ),
      ),
      PikoFormFieldRow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );
  List<Widget> _preview() {
    final plan = controller.plan;
    if (plan == null) return [];
    final entries = {
      for (final e in plan.request.snapshot.entries) e.record.id: e,
    };
    final gap = SizedBox(height: pikoDesign.dimension('spacing.4'));
    return [
      PikoFormHeading(title: _text('ai.preview')),
      Text(
        PikoCopyScope.of(context).text('ai.counts', {
          'cards': plan.cards.length,
          'changes': plan.edits.where((e) => e.applicable).length,
        }),
      ),
      Text(
        PikoCopyScope.of(context).text('ai.coverage', {
          'processed': plan.processedIds.length,
          'total': plan.request.snapshot.entries.length,
        }),
      ),
      Text(_text('ai.reviewReminder')),
      gap,
      if (!plan.complete)
        PikoCheckbox(
          label: _text('ai.partialConsent'),
          value: controller.allowPartial,
          onChanged: busy
              ? null
              : (v) => setState(() => controller.allowPartial = v),
        ),
      if (controller.canContinue)
        PikoButton(
          key: const ValueKey('ai-continue'),
          label: _text('ai.continue'),
          onPressed: controller.continueGeneration,
        ),
      if (plan.cards.isNotEmpty &&
          plan.request.snapshot.groups
              .where((g) => g.acquisitionSource)
              .any(
                (g) => plan.cards.any(
                  (c) => !c.assignments.containsKey(g.dimension.id),
                ),
              ))
        Text(_text('ai.missingSource')),
      for (final limitation in plan.limitations) Text(limitation),
      gap,
      if (plan.groups.isNotEmpty || plan.values.isNotEmpty)
        Text(_text('ai.definitionDependencies')),
      for (final group in plan.groups) ...[
        _proposal(group.id, group.name, [
          Text(_text('ai.newGroup')),
          Text(_text('ai.mode.${group.mode!.name}')),
          Text(group.reason),
        ]),
        gap,
      ],
      for (final value in plan.values) ...[
        _proposal(value.id, value.name, [
          Text(_text('ai.newValue')),
          Text(value.reason),
        ]),
        gap,
      ],
      for (final card in plan.cards) ...[
        _proposal(card.id, '${card.target} — ${card.native}', [
          Text(card.content.hintText ?? _text('ai.noHint')),
          for (final e in card.content.examples) ...[
            Text(e.targetText),
            Text(e.nativeText),
            gap,
          ],
          Text(_value(card.assignments, field: 'assignments')),
          Text(card.reason),
        ]),
        gap,
      ],
      for (final edit in plan.edits) ...[
        _proposal(
          edit.id,
          '${entries[edit.entryId]!.record.targetText} — ${entries[edit.entryId]!.record.nativeText}: ${_text('ai.field.${edit.field}')}',
          [
            Text(_text('ai.outcome.${edit.outcome.name}')),
            Text(
              '${_text('ai.current')}: ${_value(switch (edit.field) {
                'target' => entries[edit.entryId]!.record.targetText,
                'native' => entries[edit.entryId]!.record.nativeText,
                'hint' => entries[edit.entryId]!.record.content.hintText,
                'examples' => [
                  for (final e in entries[edit.entryId]!.record.content.examples) {'target': e.targetText, 'native': e.nativeText},
                ],
                'assignments' => entries[edit.entryId]!.assignments,
                _ => null,
              }, field: edit.field)}',
            ),
            if (edit.applicable)
              Text(
                '${_text('ai.proposed')}: ${_value(edit.value, field: edit.field)}',
              ),
            Text(edit.reason),
            Text(edit.rule),
          ],
          applicable: edit.applicable,
        ),
        gap,
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.service.enabled) return const SizedBox.shrink();
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        bottomNavigationBar: controller.plan == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(d.dimension('spacing.4')),
                  child: PikoButton(
                    key: const ValueKey('ai-apply'),
                    label: _text(
                      controller.applied
                          ? 'ai.applied'
                          : widget.stageOnly
                          ? 'ai.stage'
                          : 'ai.apply',
                    ),
                    onPressed: controller.canApply ? _apply : null,
                  ),
                ),
              ),
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoFormHeading(
                title: _text('ai.title'),
                subtitle: widget.collectionName,
                leading: PikoIconButton(
                  semanticLabel: copy.text('common.back'),
                  icon: const PikoIcon(PikoIconName.arrowLeft),
                  variant: PikoButtonVariant.ghost,
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              PikoFormSection(
                title: _text('ai.request'),
                children: [
                  if (widget.anchor == null)
                    PikoPreferencePicker<AiAction>(
                      label: _text('ai.action'),
                      value: action,
                      choices: [
                        for (final a in [
                          AiAction.generate,
                          AiAction.gaps,
                          AiAction.review,
                        ])
                          (a, _text('ai.action.${a.name}')),
                      ],
                      onChanged: busy
                          ? null
                          : (a) {
                              _invalidate();
                              setState(() => action = a);
                            },
                    ),
                  PikoFormFieldRow(
                    child: PikoField(
                      label: _text('ai.goal'),
                      child: TextField(
                        key: const ValueKey('ai-goal'),
                        controller: goal,
                        enabled: !busy,
                        minLines: 2,
                        maxLines: null,
                        decoration: pikoInputDecoration(),
                        onChanged: (_) => _invalidate(),
                      ),
                    ),
                  ),
                  if (action == AiAction.generate)
                    PikoFormFieldRow(
                      child: PikoCheckbox(
                        label: _text('ai.comprehensive'),
                        value: comprehensive,
                        onChanged: busy
                            ? null
                            : (v) {
                                _invalidate();
                                setState(() => comprehensive = v);
                              },
                      ),
                    ),
                  if (action != AiAction.hints) ...[
                    PikoFormFieldRow(
                      child: PikoCheckbox(
                        label: _text('ai.allowGroups'),
                        value: allowGroups,
                        onChanged: busy
                            ? null
                            : (v) {
                                _invalidate();
                                setState(() => allowGroups = v);
                              },
                      ),
                    ),
                    PikoFormFieldRow(
                      child: PikoCheckbox(
                        label: _text('ai.allowValues'),
                        value: allowValues,
                        onChanged: busy
                            ? null
                            : (v) {
                                _invalidate();
                                setState(() => allowValues = v);
                              },
                      ),
                    ),
                  ],
                  if (action == AiAction.hints) ...[
                    PikoFormFieldRow(child: Text(_text('ai.hintScope'))),
                    for (final entry in related ?? <AiEntry>[])
                      PikoFormFieldRow(
                        child: PikoCheckbox(
                          label:
                              '${entry.record.targetText} — ${entry.record.nativeText}',
                          value: targets.contains(entry.record.id),
                          onChanged: busy
                              ? null
                              : (v) {
                                  _invalidate();
                                  setState(
                                    () => v
                                        ? targets.add(entry.record.id)
                                        : targets.remove(entry.record.id),
                                  );
                                },
                        ),
                      ),
                  ],
                ],
              ),
              PikoFormSection(
                title: _text('ai.privacyTitle'),
                children: [
                  PikoFormFieldRow(child: Text(_text('ai.privacy'))),
                  PikoFormFieldRow(
                    child: PikoCheckbox(
                      label: _text('ai.consent'),
                      value: consent,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => consent = v),
                    ),
                  ),
                  if (connection != null)
                    AiConnectionControl(
                      connection: connection!,
                      consent: consent,
                      enabled: !busy && !controller.requesting,
                    ),
                ],
              ),
              if (controller.error != null)
                Text(
                  _text('ai.error.${controller.error!.name}'),
                  key: const ValueKey('ai-error'),
                ),
              PikoButton(
                key: const ValueKey('ai-start'),
                label: _text(
                  controller.requesting ? 'ai.requesting' : 'ai.start',
                ),
                onPressed:
                    busy ||
                        controller.requesting ||
                        !consent ||
                        (connection != null && !connection!.configured) ||
                        (action == AiAction.generate &&
                            goal.text.trim().isEmpty) ||
                        (action == AiAction.hints &&
                            (related == null ||
                                related!.length < 2 ||
                                targets.isEmpty))
                    ? null
                    : _start,
              ),
              if (controller.requesting || controller.plan != null)
                PikoButton(
                  label: _text('ai.discard'),
                  variant: PikoButtonVariant.ghost,
                  onPressed: busy ? null : controller.cancel,
                ),
              SizedBox(height: d.dimension('spacing.6')),
              ..._preview(),
            ],
          ),
        ),
      ),
    );
  }
}
