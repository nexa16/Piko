import 'ai_pilot_control.dart';
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
import '../../data/categories_repository.dart';
import '../../data/collection_query.dart';
import '../../data/collections_repository.dart';
import '../collections/filter_selection_dialog.dart';
import '../../ui/components/piko_dialog.dart';

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
  final goal = TextEditingController(),
      refinement = TextEditingController(),
      feedback = TextEditingController();
  bool pilotReady = false, feedbackBusy = false, feedbackSent = false;
  bool get ready =>
      consent && (widget.provider is! AiPilotAccess || pilotReady);
  AiPlan? get displayedPlan => controller.replacement ?? controller.plan;
  late AiAction action = widget.initialAction;
  bool allowGroups = true,
      allowValues = true,
      comprehensive = false,
      consent = false;
  List<AiEntry>? related;
  Set<String> targets = {};
  AiSnapshot? inventory;
  String level = 'A1', targetLevel = 'A1', categoryMode = 'improve';
  final goals = <String>{};
  final checks = <String>{
    'translations',
    'examples',
    'hints',
    'suitability',
    'structure',
    'categories',
  };
  Map<String, Set<String>> filters = {};
  final reviewedIds = <String>{};
  bool portionResolved = false;
  int? reviewSize;
  int? contextSize;
  int contextOffset = 0;
  List<String> contextInventoryIds = [];
  @override
  void initState() {
    super.initState();
    if (widget.anchor != null && widget.service.enabled) _loadRelated();
    if (widget.service.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    }
  }

  Future<void> _initialize() async {
    try {
      final data = await widget.service.snapshot(widget.collectionId);
      if (!mounted) return;
      setState(() {
        inventory = data;
        level = data.collection?.level ?? 'A1';
        targetLevel = level;
      });
      final c = connection;
      if (c != null) {
        await c.loadLocal();
        if (c.deviceAccessId != null &&
            !c.pilotStopped &&
            widget.provider is AiPilotAccess) {
          final notice = await (widget.provider as AiPilotAccess).pilot(
            'notice',
          );
          if (!mounted) return;
          setState(() {
            pilotReady = notice['consented'] == true;
            consent = pilotReady;
          });
        }
      }
    } catch (_) {
      /* First access remains explicit; no auto enrollment. */
    }
    if (mounted && !ready) await _showAccess();
  }

  Future<void> _showAccess() => showPikoDialog<void>(
    context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, refresh) => PikoDialog(
        title: _text('ai.privacyTitle'),
        purpose: PikoDialogPurpose.form,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_text('ai.privacy')),
            PikoCheckbox(
              key: const ValueKey('ai-consent'),
              label: _text('ai.consent'),
              value: consent,
              onChanged: (v) {
                setState(() => consent = v);
                refresh(() {});
              },
            ),
            if (connection != null)
              AiConnectionControl(connection: connection!, consent: consent),
            if (widget.provider case final AiPilotAccess pilot)
              AiPilotControl(
                provider: pilot,
                enabled: consent,
                onReady: (v) {
                  if (mounted) {
                    setState(() => pilotReady = v);
                    refresh(() {});
                  }
                },
                onWithdraw: () {
                  controller.stopWaiting();
                  controller.cancel();
                  setState(() {
                    consent = false;
                    pilotReady = false;
                  });
                  refresh(() {});
                },
              ),
          ],
        ),
      ),
    ),
  );

  AiOptions get options => AiOptions(
    level: level,
    goals: Set.of(goals),
    checks: Set.of(checks),
    categoryMode: categoryMode,
    filters: filters,
    reviewedIds: Set.of(reviewedIds),
    reviewSize: reviewSize,
    contextSize: contextSize,
    contextOffset: contextOffset,
    contextIds: contextSize == null
        ? null
        : contextInventoryIds.skip(contextOffset).take(contextSize!).toSet(),
  );
  int get matchingCount =>
      inventory?.entries.where(options.matches).length ?? 0;
  int get remainingCount =>
      inventory?.entries
          .where(
            (e) => options.matches(e) && !reviewedIds.contains(e.record.id),
          )
          .length ??
      0;

  Future<void> _filters() async {
    final source = inventory;
    if (source == null || source.collection == null) return;
    CollectionQuerySnapshot projection(AiSnapshot s) => CollectionQuerySnapshot(
      collection: s.collection!,
      allEntries: s.entries.map((e) => e.record),
      entries: s.entries.map((e) => e.record),
      categoryDimensions: s.groups.map((g) => g.dimension),
      categoryValues: {for (final g in s.groups) g.dimension.id: g.values},
      assignments: {
        for (final e in s.entries)
          e.record.id: [
            for (final a in e.assignments.entries)
              CategoryAssignmentRecord(dimensionId: a.key, valueIds: a.value),
          ],
      },
      directions: const {},
    );
    final selected = await showPikoDialog<CollectionFilterSelection>(
      context,
      builder: (_) => FilterSelectionDialog(
        snapshot: projection(source),
        opening: filters,
        reloadDefinitions: () async =>
            projection(await widget.service.snapshot(widget.collectionId)),
        canApply: () => !busy && !controller.requesting,
      ),
    );
    if (selected != null && mounted) {
      _invalidate();
      setState(() {
        filters = selected;
        reviewedIds.clear();
      });
    }
  }

  List<Widget> _requestFields() {
    void changed(VoidCallback f) {
      _invalidate();
      setState(f);
    }

    return [
      if (widget.anchor == null)
        PikoPreferencePicker<String>(
          label: _text('ai.action'),
          value: comprehensive ? 'comprehensive' : action.name,
          choices: [
            for (final a in ['generate', 'comprehensive', 'gaps', 'review'])
              (a, _text('ai.action.$a')),
          ],
          onChanged: busy
              ? null
              : (v) => changed(() {
                  comprehensive = v == 'comprehensive';
                  action = comprehensive
                      ? AiAction.generate
                      : AiAction.values.byName(v);
                  level = comprehensive ? 'A1' : targetLevel;
                  reviewedIds.clear();
                  portionResolved = false;
                  contextSize = null;
                  contextOffset = 0;
                }),
        ),
      if (action != AiAction.hints)
        if (contextSize != null)
          PikoFormFieldRow(
            child: Text(
              PikoCopyScope.of(context).text('ai.partialContext', {
                'count': (contextInventoryIds.length - contextOffset).clamp(
                  0,
                  contextSize!,
                ),
                'total': contextInventoryIds.length,
              }),
            ),
          ),
      if (action != AiAction.hints)
        PikoPreferencePicker<String>(
          label: _text(comprehensive ? 'ai.targetLevel' : 'collection.level'),
          value: targetLevel,
          choices: [for (final l in CollectionRecord.levels) (l, l)],
          onChanged: busy
              ? null
              : (v) => changed(() {
                  targetLevel = v;
                  if (!comprehensive) {
                    level = v;
                  } else {
                    level = 'A1';
                  }
                }),
        ),
      if (comprehensive)
        PikoFormFieldRow(
          child: Text('${_text('ai.currentStage')}: $level → $targetLevel'),
        ),
      if (comprehensive && portionResolved)
        Wrap(
          spacing: pikoDesign.dimension('spacing.2'),
          children: [
            PikoButton(
              label: _text('ai.anotherPortion'),
              onPressed:
                  busy ||
                      controller.requesting ||
                      (controller.plan != null && !controller.applied)
                  ? null
                  : () {
                      controller.cancel();
                      setState(() {});
                    },
            ),
            PikoButton(
              label: _text('ai.nextLevel'),
              onPressed:
                  busy ||
                      controller.requesting ||
                      (controller.plan != null && !controller.applied) ||
                      CollectionRecord.levels.indexOf(level) >=
                          CollectionRecord.levels.indexOf(targetLevel)
                  ? null
                  : () {
                      controller.cancel();
                      setState(() {
                        level = CollectionRecord
                            .levels[CollectionRecord.levels.indexOf(level) + 1];
                        portionResolved = false;
                      });
                    },
            ),
          ],
        ),
      if (action == AiAction.generate && !comprehensive)
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
      if (action == AiAction.generate && !comprehensive)
        PikoFormFieldRow(child: Text(_text('ai.topicExamples'))),
      if (action != AiAction.hints) ...[
        PikoFormFieldRow(child: Text(_text('ai.goals'))),
        for (final g in [
          'everyday',
          'travel',
          'social',
          'work',
          'study',
          'general',
        ])
          PikoFormFieldRow(
            child: PikoCheckbox(
              label: _text('ai.goal.$g'),
              value: goals.contains(g),
              onChanged: busy
                  ? null
                  : (v) => changed(() => v ? goals.add(g) : goals.remove(g)),
            ),
          ),
      ],
      if (action == AiAction.review) ...[
        PikoFormFieldRow(
          child: Text('${_text('ai.reviewCount')}: $matchingCount'),
        ),
        PikoButton(
          label: _text('action.filters'),
          onPressed: busy || controller.requesting ? null : _filters,
        ),
        for (final c in [
          'translations',
          'examples',
          'hints',
          'suitability',
          'structure',
          'categories',
        ])
          PikoFormFieldRow(
            child: PikoCheckbox(
              label: _text('ai.check.$c'),
              value: checks.contains(c),
              onChanged: busy
                  ? null
                  : (v) => changed(() => v ? checks.add(c) : checks.remove(c)),
            ),
          ),
        if (checks.contains('categories'))
          PikoPreferencePicker<String>(
            label: _text('ai.categoryMode'),
            value: categoryMode,
            choices: [
              for (final m in ['missing', 'improve', 'reclassify'])
                (m, _text('ai.categoryMode.$m')),
            ],
            onChanged: busy ? null : (m) => changed(() => categoryMode = m),
          ),
        if (reviewSize != null)
          PikoFormFieldRow(
            child: Text(
              PikoCopyScope.of(context).text('ai.reviewProgress', {
                'processed': reviewedIds.length,
                'next': remainingCount.clamp(0, reviewSize!),
                'remaining': remainingCount,
              }),
            ),
          ),
      ],
      if (action != AiAction.hints) ...[
        PikoFormFieldRow(
          child: PikoCheckbox(
            label: _text('ai.allowGroups'),
            value: allowGroups,
            onChanged: busy ? null : (v) => changed(() => allowGroups = v),
          ),
        ),
        PikoFormFieldRow(child: Text(_text('ai.groupExample'))),
        PikoFormFieldRow(
          child: PikoCheckbox(
            label: _text('ai.allowValues'),
            value: allowValues,
            onChanged: busy ? null : (v) => changed(() => allowValues = v),
          ),
        ),
        PikoFormFieldRow(child: Text(_text('ai.valueExample'))),
      ],
      if (action == AiAction.hints) ...[
        PikoFormFieldRow(child: Text(_text('ai.hintScope'))),
        for (final e in related ?? <AiEntry>[])
          PikoFormFieldRow(
            child: PikoCheckbox(
              label: '${e.record.targetText} — ${e.record.nativeText}',
              value: targets.contains(e.record.id),
              onChanged: busy
                  ? null
                  : (v) => changed(
                      () => v
                          ? targets.add(e.record.id)
                          : targets.remove(e.record.id),
                    ),
            ),
          ),
      ],
    ];
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
    reviewedIds.clear();
    portionResolved = false;
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    goal.dispose();
    refinement.dispose();
    feedback.dispose();
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
    if (!ready || busy || ModalRoute.of(context)?.isCurrent == false) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.start(
      action: action,
      goal: goal.text,
      comprehensiveLevel: action == AiAction.generate && comprehensive,
      allowGroups: allowGroups,
      allowValues: allowValues,
      anchor: widget.anchor,
      targets: action == AiAction.hints ? targets : null,
      options: options,
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
      if (mounted &&
          (comprehensive ||
              (action == AiAction.review && reviewSize != null) ||
              contextSize != null)) {
        final fresh = await widget.service.snapshot(widget.collectionId);
        if (mounted) {
          setState(() {
            inventory = fresh;
            portionResolved = true;
            if (action == AiAction.review) {
              reviewedIds.addAll(controller.plan!.processedIds);
            }
          });
        }
        return;
      }
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
      final plan = displayedPlan!;
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
          value:
              controller.replacement == null &&
              controller.selected.contains(id),
          onChanged:
              busy ||
                  controller.requesting ||
                  controller.replacement != null ||
                  controller.applied ||
                  !applicable
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
    final plan = displayedPlan;
    if (plan == null) return [];
    final entries = {
      for (final e in plan.request.snapshot.entries) e.record.id: e,
    };
    final gap = SizedBox(height: pikoDesign.dimension('spacing.4'));
    return [
      PikoFormHeading(
        title: _text(
          controller.replacement == null
              ? 'ai.preview'
              : 'ai.replacementPreview',
        ),
      ),
      if (controller.replacement != null) ...[
        Text(_text('ai.replacementHelp')),
        PikoButton(
          key: const ValueKey('ai-use-replacement'),
          label: _text('ai.useReplacement'),
          onPressed: controller.error == AiFailure.stale
              ? null
              : controller.acceptReplacement,
        ),
        PikoButton(
          key: const ValueKey('ai-keep-previous'),
          label: _text('ai.keepPrevious'),
          onPressed: controller.keepPrevious,
        ),
      ],
      if (plan.request.followUp?['instruction'] case final String instruction)
        Text('${_text('ai.refinementContext')}: $instruction'),
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
      if (!plan.complete && controller.replacement == null)
        PikoCheckbox(
          label: _text('ai.partialConsent'),
          value: controller.allowPartial,
          onChanged: busy || controller.requesting
              ? null
              : (v) => setState(() => controller.allowPartial = v),
        ),
      if (controller.plan != null &&
          !controller.applied &&
          (controller.plan!.request.action == AiAction.generate ||
              controller.plan!.request.action == AiAction.gaps) &&
          controller.replacement == null)
        PikoFormSection(
          title: _text('ai.refineTitle'),
          children: [
            PikoFormFieldRow(child: Text(_text('ai.refineHelp'))),
            PikoFormFieldRow(
              child: PikoField(
                label: _text('ai.refinement'),
                child: TextField(
                  key: const ValueKey('ai-refinement'),
                  controller: refinement,
                  enabled: controller.canReplace,
                  minLines: 2,
                  maxLines: null,
                  decoration: pikoInputDecoration(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            PikoFormFieldRow(
              child: PikoButton(
                key: const ValueKey('ai-refine'),
                label: _text('ai.refine'),
                onPressed:
                    !ready ||
                        !controller.canReplace ||
                        refinement.text.trim().isEmpty
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        controller.replaceGeneration(
                          instruction: refinement.text,
                        );
                      },
              ),
            ),
            PikoFormFieldRow(
              child: PikoButton(
                key: const ValueKey('ai-regenerate'),
                label: _text('ai.regenerate'),
                onPressed: !ready || !controller.canReplace
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        controller.replaceGeneration();
                      },
              ),
            ),
          ],
        ),
      if (controller.canContinue && ready && !comprehensive)
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
      if (widget.provider is AiPilotAccess && ready)
        PikoFormSection(
          title: _text('ai.feedbackTitle'),
          children: [
            PikoFormFieldRow(
              child: PikoField(
                label: _text('ai.feedback'),
                child: TextField(
                  key: const ValueKey('ai-feedback'),
                  controller: feedback,
                  enabled: !feedbackBusy && !controller.requesting,
                  minLines: 2,
                  maxLines: null,
                  maxLength: 4000,
                  decoration: pikoInputDecoration(),
                  onChanged: (_) => setState(() => feedbackSent = false),
                ),
              ),
            ),
            PikoFormFieldRow(
              child: PikoButton(
                label: _text(
                  feedbackSent ? 'ai.feedbackSent' : 'ai.feedbackSend',
                ),
                onPressed:
                    feedbackBusy ||
                        controller.requesting ||
                        feedback.text.trim().isEmpty
                    ? null
                    : () async {
                        setState(() => feedbackBusy = true);
                        try {
                          await (widget.provider as AiPilotAccess)
                              .pilot('feedback', {
                                'requestId': plan.request.id,
                                'text': feedback.text.trim(),
                              });
                          if (mounted) setState(() => feedbackSent = true);
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => controller.error = e is AiFailure
                                  ? e
                                  : AiFailure.unavailable,
                            );
                          }
                        } finally {
                          if (mounted) setState(() => feedbackBusy = false);
                        }
                      },
              ),
            ),
          ],
        ),
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
                children: _requestFields(),
              ),
              PikoButton(
                label: _text('ai.accessSettings'),
                variant: PikoButtonVariant.ghost,
                onPressed: busy ? null : _showAccess,
              ),
              if (controller.error != null)
                Text(
                  _text('ai.error.${controller.error!.name}'),
                  key: const ValueKey('ai-error'),
                ),
              if (controller.error == AiFailure.contextLimit &&
                  action != AiAction.hints)
                PikoButton(
                  label: _text(
                    action == AiAction.review
                        ? 'ai.smallerStep'
                        : 'ai.smallerContext',
                  ),
                  onPressed: () {
                    controller.cancel();
                    setState(() {
                      if (action == AiAction.review) {
                        reviewSize = reviewSize == null
                            ? 50
                            : (reviewSize! ~/ 2).clamp(1, 50);
                      } else {
                        contextSize = contextSize == null
                            ? 50
                            : (contextSize! ~/ 2).clamp(1, 50);
                        contextOffset = 0;
                        contextInventoryIds =
                            inventory?.entries
                                .map((e) => e.record.id)
                                .toList() ??
                            [];
                      }
                      reviewedIds.clear();
                    });
                  },
                ),
              if (contextSize != null && portionResolved)
                PikoButton(
                  label: _text('ai.nextContext'),
                  onPressed:
                      busy ||
                          controller.requesting ||
                          (controller.plan != null && !controller.applied) ||
                          contextOffset + contextSize! >=
                              contextInventoryIds.length
                      ? null
                      : () {
                          controller.cancel();
                          setState(() {
                            contextOffset += contextSize!;
                            portionResolved = false;
                          });
                        },
                ),
              if (action == AiAction.review &&
                  reviewSize != null &&
                  controller.plan != null)
                PikoButton(
                  label: _text('ai.nextStep'),
                  onPressed:
                      busy ||
                          controller.requesting ||
                          !controller.applied ||
                          remainingCount == 0
                      ? null
                      : () {
                          controller.cancel();
                          setState(() {});
                        },
                ),
              PikoButton(
                key: const ValueKey('ai-start'),
                label: _text(
                  controller.requesting ? 'ai.requesting' : 'ai.start',
                ),
                onPressed:
                    busy ||
                        controller.plan != null ||
                        controller.requesting ||
                        !ready ||
                        (connection != null && !connection!.configured) ||
                        (action == AiAction.generate &&
                            !comprehensive &&
                            goal.text.trim().isEmpty) ||
                        (action == AiAction.review &&
                            (checks.isEmpty || remainingCount == 0)) ||
                        (action == AiAction.hints &&
                            (related == null ||
                                related!.length < 2 ||
                                targets.isEmpty))
                    ? null
                    : _start,
              ),
              if (controller.requesting)
                PikoButton(
                  key: const ValueKey('ai-stop-waiting'),
                  label: _text('ai.stopWaiting'),
                  variant: PikoButtonVariant.ghost,
                  onPressed: controller.stopWaiting,
                ),
              if (!controller.requesting && controller.plan != null)
                PikoButton(
                  label: _text('ai.discard'),
                  variant: PikoButtonVariant.ghost,
                  onPressed: busy
                      ? null
                      : () {
                          if (action == AiAction.review && reviewSize != null) {
                            reviewedIds.addAll(controller.plan!.processedIds);
                          }
                          portionResolved = true;
                          controller.cancel();
                          setState(() {});
                        },
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
