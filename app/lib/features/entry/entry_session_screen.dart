import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import 'entry_session_controller.dart';

/// Production entry content. The caller owns the session; global completion,
/// Collection route wiring and deletion are separate specifications.
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
  Object? exitRequest;
  bool exitDraining = false, allowPop = false;
  ModalRoute<dynamic>? exitDialog;
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
      exitRequest = null;
      exitDraining = false;
      allowPop = false;
      dismissOwnedExitDialog();
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
    if (session.isCompleted) return;
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
    if (session.isBusy || exitDraining || id == activeId) return;
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
    if (!mounted ||
        adjusting ||
        session.isBusy ||
        exitDraining ||
        !userScrolling) {
      return;
    }
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
        session.isBusy ||
        exitDraining ||
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
    if (exitDraining || exitRequest != null) return;
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

  Future<void> complete() async {
    if (exitRequest != null || session.isConfirming || exitDraining) return;
    final initiatingSession = session;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    try {
      await initiatingSession.completeSession();
      if (!mounted ||
          !identical(session, initiatingSession) ||
          route?.isCurrent != true) {
        return;
      }
      await requestExit();
    } catch (error) {
      if (!mounted || !identical(session, initiatingSession)) return;
      setState(() {
        if (error is! SavedEntryCompletionBlocked) confirmError = error;
        centerRequested = true;
      });
      scheduleLayout();
    }
  }

  Future<void> requestExit() async {
    if (exitRequest != null || session.isBusy || allowPop) return;
    final request = Object();
    final initiatingSession = session;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    final navigator = Navigator.of(context);
    bool current() =>
        mounted &&
        identical(exitRequest, request) &&
        identical(session, initiatingSession) &&
        route?.isCurrent == true;
    exitRequest = request;
    try {
      final draft = initiatingSession.draft;
      if (!initiatingSession.isCompleted &&
          (draft.targetText.trim().isNotEmpty ||
              draft.nativeText.trim().isNotEmpty)) {
        final discard = await showPikoDialog<bool>(
          context,
          builder: (dialogContext) {
            final dialogRoute = ModalRoute.of(dialogContext);
            if (!mounted ||
                !identical(exitRequest, request) ||
                !identical(session, initiatingSession)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogRoute?.isActive == true) {
                  dialogRoute!.navigator?.removeRoute(dialogRoute);
                }
              });
              return const SizedBox.shrink();
            }
            exitDialog = dialogRoute;
            final copy = PikoCopyScope.of(dialogContext);
            return PikoDialog(
              title: copy.text('entry.exitTitle'),
              body: Text(copy.text('entry.exitWarning')),
              actions: [
                PikoButton(
                  label: copy.text('entry.continue'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                PikoButton(
                  label: copy.text('entry.discard'),
                  variant: PikoButtonVariant.dangerOutline,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );
        if (!current() || discard != true) return;
      }
      if (!current() || initiatingSession.isBusy) return;
      setState(() => exitDraining = true);
      await initiatingSession.awaitSavedEdits();
      if (!current()) return;
      setState(() => allowPop = true);
      // PopScope must receive the permitted state before the deliberate pop.
      await WidgetsBinding.instance.endOfFrame;
      if (current()) navigator.pop();
    } finally {
      if (mounted && identical(exitRequest, request)) {
        setState(() {
          exitRequest = null;
          exitDialog = null;
          exitDraining = false;
          allowPop = false;
        });
      }
    }
  }

  void dismissOwnedExitDialog() {
    final staleDialog = exitDialog;
    exitDialog = null;
    if (staleDialog?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (staleDialog!.isActive) {
          staleDialog.navigator?.removeRoute(staleDialog);
        }
      });
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
    final metaStyle = TextStyle(
      color: pikoDesign.color('muted'),
      fontSize: pikoDesign.dimension('typography.small'),
      height: pikoDesign.dimension('components.entryStack.metaLineHeight'),
    );
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
      enabled: !session.isBusy && !exitDraining,
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
          constraints: BoxConstraints(
            minHeight: pikoDesign.dimension(
              'components.entryStack.compactMinHeight',
            ),
          ),
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Duration(
                  milliseconds: pikoDesign
                      .dimension('components.entryStack.stateMotionMs')
                      .round(),
                ),
          padding: EdgeInsets.all(pikoDesign.dimension('spacing.4')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: pikoDesign.dimension('spacing.3'),
                runSpacing: pikoDesign.dimension('spacing.3'),
                children: [
                  Text(
                    copy.text('entry.number', {'count': index + 1}),
                    style: TextStyle(
                      color: pikoDesign.color('muted'),
                      fontSize: pikoDesign.dimension(
                        'components.entryStack.numberSize',
                      ),
                    ),
                  ),
                  Text(
                    copy.text(
                      draft
                          ? (session.isBusy ? 'entry.saving' : 'entry.new')
                          : saved!.isSaving
                          ? 'entry.saving'
                          : error != null
                          ? 'entry.unsaved'
                          : 'entry.saved',
                    ),
                    style: metaStyle.copyWith(
                      fontSize: pikoDesign.dimension(
                        'components.entryStack.statusSize',
                      ),
                    ),
                  ),
                ],
              ),
              if (!active)
                Padding(
                  padding: EdgeInsets.only(
                    top: pikoDesign.dimension(
                      'components.entryStack.previewTop',
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        values.targetText.isEmpty
                            ? copy.text('entry.targetPlaceholder')
                            : values.targetText,
                        style: TextStyle(
                          fontSize: pikoDesign.dimension('typography.body'),
                          fontWeight: pikoDesign.weight(
                            'typography.titleWeight',
                          ),
                        ),
                      ),
                      SizedBox(
                        height: pikoDesign.dimension(
                          'components.entryStack.previewGap',
                        ),
                      ),
                      Text(
                        values.nativeText.isEmpty
                            ? copy.text('entry.nativePlaceholder')
                            : values.nativeText,
                        style: TextStyle(
                          fontSize: pikoDesign.dimension('typography.body'),
                          color: pikoDesign.color('muted'),
                        ),
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
                            spacing: pikoDesign.dimension('spacing.3'),
                            runSpacing: pikoDesign.dimension('spacing.3'),
                            children: [
                              Text(
                                copy.text(
                                  session.isBusy
                                      ? 'entry.saving'
                                      : 'entry.draft',
                                ),
                                style: metaStyle,
                              ),
                              PikoIconButton(
                                icon: const PikoIcon(PikoIconName.check),
                                variant: PikoButtonVariant.primary,
                                large: true,
                                semanticLabel: copy.text('action.saveNext'),
                                onPressed: session.isBusy || exitDraining
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
                            style: metaStyle,
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
                            onPressed: session.isBusy || exitDraining
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
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) requestExit();
      },
      child: Scaffold(
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
                        PikoHeading(
                          title: copy.text('entry.title'),
                          leading: PikoButton(
                            label: copy.text('common.back'),
                            icon: const PikoIcon(PikoIconName.arrowLeft),
                            variant: PikoButtonVariant.ghost,
                            onPressed: session.isBusy || exitDraining
                                ? null
                                : requestExit,
                          ),
                          actions: [
                            PikoIconButton(
                              icon: const PikoIcon(PikoIconName.check),
                              semanticLabel: copy.text('entry.complete'),
                              onPressed:
                                  session.isBusy ||
                                      exitDraining ||
                                      exitRequest != null
                                  ? null
                                  : complete,
                            ),
                          ],
                        ),
                        Expanded(
                          child: session.isCompleted
                              ? Center(
                                  child: Text(copy.text('entry.completed')),
                                )
                              : SizedBox(
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
                                          physics:
                                              session.isBusy || exitDraining
                                              ? const NeverScrollableScrollPhysics()
                                              : const ClampingScrollPhysics(),
                                          padding: EdgeInsets.only(
                                            top: topPadding,
                                            bottom: bottomPadding,
                                          ),
                                          child: Column(
                                            children: [
                                              for (
                                                var i = 0;
                                                i < ids.length;
                                                i++
                                              )
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
      ),
    );
  }

  @override
  void dispose() {
    dismissOwnedExitDialog();
    session.removeListener(changed);
    for (final editor in editors.values) {
      editor.dispose();
    }
    scroll.dispose();
    stackFocus.dispose();
    super.dispose();
  }
}
