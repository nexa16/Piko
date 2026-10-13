import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import 'entry_session_controller.dart';

/// Production entry content. The caller owns the session; route exit,
/// global completion and deletion are separate specifications.
class EntrySessionScreen extends StatefulWidget {
  const EntrySessionScreen({
    required this.collection,
    required this.session,
    super.key,
  });
  final CollectionRecord collection;
  final EntrySessionController session;
  @override
  State<EntrySessionScreen> createState() => _EntrySessionScreenState();
}

class _Editors {
  _Editors(EntryDraft value)
    : target = TextEditingController(text: value.targetText),
      native = TextEditingController(text: value.nativeText);
  final TextEditingController target, native;
  final targetFocus = FocusNode(), nativeFocus = FocusNode();
  void sync(EntryDraft value) {
    if (target.text != value.targetText) target.text = value.targetText;
    if (native.text != value.nativeText) native.text = value.nativeText;
  }

  void dispose() {
    target.dispose();
    native.dispose();
    targetFocus.dispose();
    nativeFocus.dispose();
  }
}

class _EntrySessionScreenState extends State<EntrySessionScreen> {
  static const draftId = 'draft';
  final scroll = ScrollController();
  final stackFocus = FocusNode();
  final viewport = GlobalKey();
  final cards = <String, GlobalKey>{};
  final editors = <String, _Editors>{};
  double topPadding = 0, bottomPadding = 0;
  bool userScrolling = false, scheduled = false, adjusting = false;
  bool centerRequested = true;
  bool releaseAnchor = false, jumping = false;
  bool settleSelection = false;
  String? anchorId;
  double? anchorCenter;
  Object? confirmError;
  int confirmedCount = 0;
  late EntryDraft lastDraft;
  EntrySessionController get session => widget.session;
  String get activeId => session.activeEntryId ?? draftId;
  List<String> get ids => [
    ...session.confirmedEntries.map((e) => e.id),
    draftId,
  ];

  @override
  void initState() {
    super.initState();
    assert(widget.collection.id == session.collectionId);
    confirmedCount = session.confirmedEntries.length;
    lastDraft = session.draft;
    session.addListener(changed);
  }

  @override
  void didUpdateWidget(EntrySessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != session) {
      oldWidget.session.removeListener(changed);
      for (final editor in editors.values) {
        editor.dispose();
      }
      editors.clear();
      cards.clear();
      confirmError = null;
      topPadding = 0;
      bottomPadding = 0;
      userScrolling = false;
      adjusting = false;
      releaseAnchor = false;
      settleSelection = false;
      jumping = false;
      anchorId = null;
      anchorCenter = null;
      confirmedCount = session.confirmedEntries.length;
      lastDraft = session.draft;
      centerRequested = true;
      session.addListener(changed);
    }
  }

  double? center(String id) {
    final box = cards[id]?.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset(0, box.size.height / 2)).dy
        : null;
  }

  void changed() {
    if (!mounted) return;
    if (lastDraft.targetText != session.draft.targetText ||
        lastDraft.nativeText != session.draft.nativeText) {
      confirmError = null;
    }
    lastDraft = session.draft;
    if (session.confirmedEntries.length != confirmedCount) {
      confirmedCount = session.confirmedEntries.length;
      centerRequested = true;
      confirmError = null;
    } else if (!adjusting) {
      anchorId = activeId;
      anchorCenter = center(activeId);
    }
    setState(() {});
    scheduleLayout();
  }

  void scheduleLayout() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted || !scroll.hasClients) return;
      final box = viewport.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final first = cards[ids.first]?.currentContext?.findRenderObject();
      final last = cards[draftId]?.currentContext?.findRenderObject();
      if (first is! RenderBox || last is! RenderBox) return;
      final nextTop = math.max(0.0, (box.size.height - first.size.height) / 2);
      final nextBottom = math.max(
        0.0,
        (box.size.height - last.size.height) / 2,
      );
      if ((topPadding - nextTop).abs() > 0.5 ||
          (bottomPadding - nextBottom).abs() > 0.5) {
        if (!centerRequested && anchorId == activeId && anchorCenter != null) {
          final current = center(activeId);
          if (current != null) jump(scroll.offset + current - anchorCenter!);
        }
        setState(() {
          topPadding = nextTop;
          bottomPadding = nextBottom;
        });
        scheduleLayout();
        return;
      }
      if (centerRequested) {
        centerRequested = false;
        final current = center(activeId);
        final middle = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
        if (current != null) {
          jump(scroll.offset + current - middle);
          if (anchorId == activeId) anchorCenter = middle;
        }
      } else if (anchorId == activeId && anchorCenter != null) {
        final current = center(activeId);
        if (current != null) jump(scroll.offset + current - anchorCenter!);
      }
      if (releaseAnchor || MediaQuery.disableAnimationsOf(context)) {
        anchorId = null;
        anchorCenter = null;
        adjusting = false;
        releaseAnchor = false;
        if (settleSelection) {
          settleSelection = false;
          final wasScrolling = userScrolling;
          userScrolling = true;
          nearest();
          userScrolling = wasScrolling;
        }
      }
      final editor = editors[activeId];
      final focused = editor?.targetFocus.hasFocus == true
          ? editor?.targetFocus
          : editor?.nativeFocus.hasFocus == true
          ? editor?.nativeFocus
          : null;
      if (focused?.context != null && !userScrolling && !adjusting) {
        Scrollable.ensureVisible(focused!.context!, duration: Duration.zero);
      }
    });
  }

  void jump(double offset) {
    final next = offset.clamp(
      scroll.position.minScrollExtent,
      scroll.position.maxScrollExtent,
    );
    if ((next - scroll.offset).abs() > 0.5) {
      jumping = true;
      scroll.jumpTo(next);
      jumping = false;
    }
  }

  void select(String id, {bool centerCard = false}) {
    if (session.isConfirming || id == activeId) return;
    anchorId = id;
    anchorCenter = center(id);
    adjusting = true;
    releaseAnchor = false;
    centerRequested = centerCard;
    if (id == draftId) {
      session.selectDraft();
    } else {
      session.selectSavedEntry(id);
    }
    scheduleLayout();
  }

  void nearest() {
    if (!mounted || adjusting || session.isConfirming || !userScrolling) return;
    final box = viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final middle = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
    var best = activeId;
    var distance = ((center(best) ?? middle) - middle).abs();
    for (final id in ids) {
      final point = center(id);
      if (point != null && (point - middle).abs() < distance) {
        best = id;
        distance = (point - middle).abs();
      }
    }
    select(best);
  }

  bool notification(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    if (jumping) return false;
    if (event is UserScrollNotification) {
      if (event.direction != ScrollDirection.idle) userScrolling = true;
    }
    if (event is ScrollUpdateNotification &&
        userScrolling &&
        anchorCenter != null) {
      anchorCenter = anchorCenter! - (event.scrollDelta ?? 0);
    }
    if (event is ScrollUpdateNotification && userScrolling && !adjusting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => nearest());
    }
    if (event is ScrollEndNotification) {
      if (adjusting) {
        settleSelection = true;
      } else {
        nearest();
      }
      userScrolling = false;
    }
    return false;
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (!stackFocus.hasPrimaryFocus ||
        session.isConfirming ||
        event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
        ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (direction == 0) return KeyEventResult.ignored;
    final index = (ids.indexOf(activeId) + direction).clamp(0, ids.length - 1);
    select(ids[index], centerCard: true);
    return KeyEventResult.handled;
  }

  Future<void> confirm() async {
    final initiatingSession = session;
    setState(() {
      confirmError = null;
    });
    try {
      await initiatingSession.confirmAndNext();
    } catch (error) {
      if (mounted && identical(session, initiatingSession)) {
        setState(() {
          confirmError = error;
        });
      }
    }
  }

  String errorKey(Object error) => switch (error) {
    VocabularyValidation.requiredTarget => 'entry.requiredTarget',
    VocabularyValidation.requiredNative => 'entry.requiredNative',
    VocabularyValidation.duplicatePair => 'vocab.inlineDuplicate',
    VocabularyValidation.entryNotFound => 'entry.notFound',
    _ => 'entry.saveFailed',
  };

  Widget card(String id, int index, BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final draft = id == draftId;
    final saved = draft ? null : session.savedEntryState(id);
    final values = draft ? session.draft : saved!.draft;
    final editor = editors.putIfAbsent(id, () => _Editors(values))
      ..sync(values);
    final active = id == activeId;
    final error = draft ? confirmError : saved!.error;
    void edit(bool target, String value) {
      if (draft) {
        if (target) {
          session.setTargetText(value);
        } else {
          session.setNativeText(value);
        }
      } else {
        session.editSavedEntry(
          id,
          targetText: target ? value : null,
          nativeText: target ? null : value,
        );
      }
    }

    Widget field(bool target) => PikoTextField(
      key: ValueKey('$id-${target ? 'target' : 'native'}'),
      label: copy.text(
        (target
                ? widget.collection.targetLanguage
                : widget.collection.nativeLanguage)
            .copyKey,
      ),
      controller: target ? editor.target : editor.native,
      focusNode: target ? editor.targetFocus : editor.nativeFocus,
      enabled: !session.isConfirming,
      error:
          error ==
              (target
                  ? VocabularyValidation.requiredTarget
                  : VocabularyValidation.requiredNative)
          ? copy.text(errorKey(error!))
          : null,
      onChanged: (value) => edit(target, value),
    );
    Widget animate(Widget child) => MediaQuery.disableAnimationsOf(context)
        ? child
        : NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              scheduleLayout();
              return false;
            },
            child: SizeChangedLayoutNotifier(
              child: AnimatedSize(
                duration: PikoTheme.motion(context),
                onEnd: () {
                  if (id == anchorId) releaseAnchor = true;
                  scheduleLayout();
                },
                child: child,
              ),
            ),
          );
    return Padding(
      key: cards.putIfAbsent(id, GlobalKey.new),
      padding: EdgeInsets.symmetric(
        vertical: pikoDesign.dimension('spacing.2'),
      ),
      child: animate(
        PikoCard(
          key: ValueKey('entry-card-$id'),
          selected: active,
          padding: EdgeInsets.all(pikoDesign.dimension('spacing.4')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(copy.text('entry.number', {'count': index + 1})),
                  Text(
                    copy.text(
                      draft
                          ? (session.isConfirming
                                ? 'entry.saving'
                                : 'entry.new')
                          : saved!.isSaving
                          ? 'entry.saving'
                          : error != null
                          ? 'entry.unsaved'
                          : 'entry.saved',
                    ),
                  ),
                ],
              ),
              if (!active)
                Padding(
                  padding: EdgeInsets.only(
                    top: pikoDesign.dimension('spacing.3'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        values.targetText.isEmpty
                            ? copy.text('entry.targetPlaceholder')
                            : values.targetText,
                      ),
                      Text(
                        values.nativeText.isEmpty
                            ? copy.text('entry.nativePlaceholder')
                            : values.nativeText,
                      ),
                      if (error != null)
                        Text(
                          copy.text(errorKey(error)),
                          style: TextStyle(color: pikoDesign.color('danger')),
                        ),
                    ],
                  ),
                ),
              ExcludeFocus(
                excluding: !active,
                child: ExcludeSemantics(
                  excluding: !active,
                  child: Offstage(
                    offstage: !active,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: pikoDesign.dimension('spacing.4')),
                        field(true),
                        SizedBox(height: pikoDesign.dimension('spacing.4')),
                        field(false),
                        SizedBox(height: pikoDesign.dimension('spacing.3')),
                        if (draft)
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text(
                                copy.text(
                                  session.isConfirming
                                      ? 'entry.saving'
                                      : 'entry.draft',
                                ),
                              ),
                              PikoIconButton(
                                icon: const PikoIcon(PikoIconName.check),
                                semanticLabel: copy.text('action.saveNext'),
                                onPressed: session.isConfirming
                                    ? null
                                    : confirm,
                              ),
                            ],
                          )
                        else
                          Text(
                            copy.text(
                              saved!.isSaving
                                  ? 'entry.saving'
                                  : error != null
                                  ? 'entry.unsaved'
                                  : 'entry.autoSave',
                            ),
                          ),
                        if (error != null &&
                            error != VocabularyValidation.requiredTarget &&
                            error != VocabularyValidation.requiredNative)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              copy.text(errorKey(error)),
                              style: TextStyle(
                                color: pikoDesign.color('danger'),
                              ),
                            ),
                          ),
                        if (!draft &&
                            error != null &&
                            error is! VocabularyValidation)
                          PikoButton(
                            label: copy.text('action.retry'),
                            onPressed: session.isConfirming
                                ? null
                                : () => session.retrySavedEntry(id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    scheduleLayout();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = pikoDesign.dimension(
              constraints.maxWidth <=
                      pikoDesign.dimension('layout.mobileBreakpoint')
                  ? 'layout.mobilePadding'
                  : 'layout.pagePadding',
            );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: pikoDesign.dimension('controls.contentWidth'),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  child: Column(
                    children: [
                      PikoHeading(title: copy.text('entry.title')),
                      Expanded(
                        child: SizedBox(
                          key: viewport,
                          child: Focus(
                            focusNode: stackFocus,
                            onKeyEvent: key,
                            child: Semantics(
                              label: copy.text('entry.stackLabel'),
                              child: NotificationListener<ScrollNotification>(
                                onNotification: notification,
                                child: SingleChildScrollView(
                                  key: const ValueKey('entry-stack'),
                                  controller: scroll,
                                  physics: session.isConfirming
                                      ? const NeverScrollableScrollPhysics()
                                      : const ClampingScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    top: topPadding,
                                    bottom: bottomPadding,
                                  ),
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < ids.length; i++)
                                        card(ids[i], i, context),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    session.removeListener(changed);
    for (final editor in editors.values) {
      editor.dispose();
    }
    scroll.dispose();
    stackFocus.dispose();
    super.dispose();
  }
}
