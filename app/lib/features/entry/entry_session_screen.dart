import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_deletion.dart';
import '../../data/categories_repository.dart';
import '../categories/vocabulary_categories.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_entry_header.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_swipe_reveal.dart';
import '../../ui/piko_theme.dart';
import 'entry_session_controller.dart';

/// Production entry content. The caller owns the session and deletion service;
/// Collection route wiring and swipe presentation are separate specifications.
class EntrySessionScreen extends StatefulWidget {
  const EntrySessionScreen({
    required this.collection,
    required this.session,
    this.onOpenInterchange,
    this.onPendingWrites,
    this.categoriesRepository,
    super.key,
  });
  final CollectionRecord collection;
  final EntrySessionController session;
  final Future<void> Function()? onOpenInterchange;
  final ValueChanged<Future<void>>? onPendingWrites;
  final CategoriesRepository? categoriesRepository;
  @override
  State<EntrySessionScreen> createState() => _EntrySessionScreenState();
}

class _Editors {
  _Editors(EntryDraft value, VoidCallback onFocus)
    : target = TextEditingController(text: value.targetText),
      native = TextEditingController(text: value.nativeText) {
    targetFocus.addListener(() {
      if (targetFocus.hasFocus) onFocus();
    });
    nativeFocus.addListener(() {
      if (nativeFocus.hasFocus) onFocus();
    });
  }
  final TextEditingController target, native;
  final targetFocus = FocusNode(), nativeFocus = FocusNode();
  final targetBounds = GlobalKey(), nativeBounds = GlobalKey();
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
  final retiredEditors = <_Editors>{};
  double bottomPadding = 0;
  double? lastViewportHeight;
  bool visibilityRequested = true, followEditor = true, alignDraftStart = true;
  bool userScrolling = false, scheduled = false, adjusting = false;
  bool centerRequested = true;
  bool releaseAnchor = false, jumping = false;
  bool settleSelection = false;
  bool structuralAnchoring = false;
  bool draftFocusRequested = true;
  String? anchorId;
  double? anchorCenter;
  Object? deletionError, undoFeedback;
  String? deletionErrorId;
  Object? exitRequest;
  bool exitDraining = false, allowPop = false;
  ModalRoute<dynamic>? exitDialog;
  int advancementRevision = 0;
  late String previousActiveId;
  late List<String> previousIds;
  (String?, Object?) previousUndo = (null, null);
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
    advancementRevision = session.advancementRevision;
    previousActiveId = activeId;
    previousIds = ids;
    draftFocusRequested = activeId == draftId;
    session.addListener(changed);
  }

  @override
  void didUpdateWidget(EntrySessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != session) {
      oldWidget.session.removeListener(changed);
      oldWidget.session.forgetUndo();
      for (final editor in editors.values) {
        editor.dispose();
      }
      editors.clear();
      cards.clear();
      deletionError = null;
      deletionErrorId = null;
      undoFeedback = null;
      exitRequest = null;
      exitDraining = false;
      allowPop = false;
      dismissOwnedExitDialog();
      bottomPadding = 0;
      lastViewportHeight = null;
      visibilityRequested = true;
      followEditor = true;
      alignDraftStart = activeId == draftId;
      userScrolling = false;
      adjusting = false;
      releaseAnchor = false;
      settleSelection = false;
      jumping = false;
      anchorId = null;
      anchorCenter = null;
      advancementRevision = session.advancementRevision;
      previousActiveId = activeId;
      previousIds = ids;
      previousUndo = (null, null);
      structuralAnchoring = false;
      centerRequested = true;
      draftFocusRequested = activeId == draftId;
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
    for (final id in editors.keys.where((id) => !ids.contains(id)).toList()) {
      final editor = editors.remove(id)!;
      cards.remove(id);
      retiredEditors.add(editor);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (retiredEditors.remove(editor)) editor.dispose();
      });
    }
    final advanced = session.advancementRevision != advancementRevision;
    final latestUndo = session.undoEntries.lastOrNull;
    final nextUndo = (latestUndo?.entry.id, latestUndo?.error);
    final structuralChange =
        previousIds.join('|') != ids.join('|') || previousUndo != nextUndo;
    if (structuralChange &&
        !advanced &&
        activeId == previousActiveId &&
        !structuralAnchoring) {
      anchorId = activeId;
      anchorCenter = center(activeId);
      structuralAnchoring = true;
    }
    if (advanced || (activeId != previousActiveId && !adjusting)) {
      advancementRevision = session.advancementRevision;
      centerRequested = true;
      structuralAnchoring = false;
    } else if (!adjusting && !structuralAnchoring) {
      anchorId = activeId;
      anchorCenter = center(activeId);
    }
    if (advanced || activeId != previousActiveId) {
      draftFocusRequested = activeId == draftId;
      visibilityRequested = draftFocusRequested;
      followEditor = draftFocusRequested;
      alignDraftStart = draftFocusRequested;
      if (!draftFocusRequested) {
        // Browsing a saved card must not carry a hidden draft's input focus or
        // reopen the software keyboard. Stack keyboard focus stays independent.
        for (final editor in editors.values) {
          if (editor.targetFocus.hasFocus) editor.targetFocus.unfocus();
          if (editor.nativeFocus.hasFocus) editor.nativeFocus.unfocus();
        }
      }
    }
    previousActiveId = activeId;
    previousIds = ids;
    previousUndo = nextUndo;
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
      final last = cards[draftId]?.currentContext?.findRenderObject();
      if (last is! RenderBox) return;
      final viewportChanged = lastViewportHeight != box.size.height;
      lastViewportHeight = box.size.height;
      if (viewportChanged && followEditor) visibilityRequested = true;
      var nextBottom = math.max(0.0, (box.size.height - last.size.height) / 2);
      // Only trailing space may retain a draft's structural anchor. The first
      // card always starts at the normal content edge, never a centering spacer.
      if (!centerRequested && anchorCenter != null && !userScrolling) {
        final viewportTop = box.localToGlobal(Offset.zero).dy;
        if (anchorId == draftId) {
          nextBottom = math.max(
            nextBottom,
            viewportTop +
                box.size.height -
                anchorCenter! -
                last.size.height / 2,
          );
        }
      }
      if ((bottomPadding - nextBottom).abs() > 0.5) {
        if (!centerRequested && anchorId == activeId && anchorCenter != null) {
          final current = center(activeId);
          if (current != null) jump(scroll.offset + current - anchorCenter!);
        }
        setState(() {
          bottomPadding = nextBottom;
        });
        scheduleLayout();
        return;
      }
      if (centerRequested && activeId != draftId) {
        centerRequested = false;
        final current = center(activeId);
        final middle = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
        if (current != null) {
          jump(scroll.offset + current - middle);
          if (anchorId == activeId) anchorCenter = middle;
        }
      } else if (!visibilityRequested &&
          anchorId == activeId &&
          anchorCenter != null) {
        final current = center(activeId);
        if (current != null) jump(scroll.offset + current - anchorCenter!);
      }
      centerRequested = false;
      structuralAnchoring = false;
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
      if (draftFocusRequested &&
          activeId == draftId &&
          !session.isBusy &&
          !exitDraining &&
          !userScrolling &&
          !adjusting &&
          editor != null) {
        draftFocusRequested = false;
        editor.targetFocus.requestFocus();
        // Focus and EditableText's caret reveal settle on the next layout. Its
        // old native-field geometry must not drive the fresh draft's reveal.
        visibilityRequested = true;
        scheduleLayout();
        return;
      }
      if (visibilityRequested &&
          !userScrolling &&
          !adjusting &&
          editor != null) {
        final target = editor.targetBounds.currentContext?.findRenderObject();
        final native = editor.nativeBounds.currentContext?.findRenderObject();
        if (target is RenderBox &&
            native is RenderBox &&
            target.hasSize &&
            native.hasSize) {
          final viewportTop = box.localToGlobal(Offset.zero).dy;
          final viewportBottom = viewportTop + box.size.height;
          final firstTop = target.localToGlobal(Offset.zero).dy;
          final lastBottom = native
              .localToGlobal(Offset(0, native.size.height))
              .dy;
          final pairFits = lastBottom - firstTop <= box.size.height;
          final focused = editor.nativeFocus.hasFocus && !alignDraftStart
              ? native
              : target;
          final top = pairFits
              ? firstTop
              : focused.localToGlobal(Offset.zero).dy;
          final bottom = pairFits
              ? lastBottom
              : focused.localToGlobal(Offset(0, focused.size.height)).dy;
          var delta = 0.0;
          if (alignDraftStart ||
              top < viewportTop ||
              bottom - top > box.size.height) {
            delta = top - viewportTop;
          } else if (bottom > viewportBottom) {
            delta = bottom - viewportBottom;
          }
          jump(scroll.offset + delta);
          visibilityRequested = false;
          alignDraftStart = false;
        }
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
    // At the top boundary expansion grows down from the content edge. Keeping
    // the old compact center would scroll away the first card's beginning.
    anchorCenter =
        id == ids.first &&
            scroll.offset <= scroll.position.minScrollExtent + 0.5
        ? null
        : center(id);
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
    if (scroll.offset <= scroll.position.minScrollExtent + 0.5) {
      select(ids.first);
      return;
    }
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
      if (event.direction != ScrollDirection.idle) {
        structuralAnchoring = false;
        userScrolling = true;
        followEditor = false;
        visibilityRequested = false;
        alignDraftStart = false;
      }
    }
    if (event is ScrollUpdateNotification &&
        userScrolling &&
        anchorCenter != null) {
      anchorCenter = anchorCenter! - (event.scrollDelta ?? 0);
    }
    if (event is ScrollUpdateNotification &&
        !userScrolling &&
        followEditor &&
        !adjusting &&
        !session.isBusy) {
      // EditableText can reveal only its caret after focus or a structural
      // change. Reconcile that completed movement with the full labeled field.
      // Deliberate user scrolling has already disabled this follow behavior.
      visibilityRequested = true;
      scheduleLayout();
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
    try {
      final operation = initiatingSession.confirmAndNext();
      widget.onPendingWrites?.call(
        operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await operation;
    } catch (_) {
      // The controller owns revision-aware validation, including rechecks when
      // reopening the same raw draft after a conflicting saved entry changes.
    }
  }

  Future<void> deleteEntry(String id) async {
    if (exitRequest != null || exitDraining) return;
    final initiatingSession = session;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    setState(() {
      deletionError = null;
      deletionErrorId = null;
      undoFeedback = null;
    });
    try {
      await initiatingSession.deleteSavedEntry(id);
    } catch (error) {
      if (mounted &&
          identical(session, initiatingSession) &&
          route?.isCurrent == true) {
        setState(() {
          deletionError = error;
          deletionErrorId = id;
        });
      }
    }
  }

  Future<void> undoEntry(String id) async {
    if (exitRequest != null || exitDraining) return;
    final initiatingSession = session;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    setState(() => undoFeedback = null);
    try {
      await initiatingSession.undoDeletion(id);
    } catch (error) {
      if (mounted &&
          identical(session, initiatingSession) &&
          route?.isCurrent == true) {
        setState(() => undoFeedback = error);
      }
    }
  }

  String undoErrorKey(Object error) => switch (error) {
    VocabularyUndoFailure.expired ||
    VocabularyUndoFailure.alreadyUsed ||
    VocabularyUndoFailure.invalidReceipt => 'vocab.undoExpired',
    VocabularyUndoFailure.duplicatePair => 'vocab.inlineDuplicate',
    _ => 'vocab.undoFailed',
  };

  Widget undoBar(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final latest = session.undoEntries.lastOrNull;
    if (latest == null) {
      return undoFeedback == null
          ? const SizedBox.shrink()
          : Semantics(
              liveRegion: true,
              child: Text(
                copy.text(undoErrorKey(undoFeedback!)),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
            );
    }
    return Container(
      key: ValueKey('undo-${latest.entry.id}'),
      padding: EdgeInsets.all(pikoDesign.dimension('spacing.3')),
      decoration: BoxDecoration(
        color: pikoDesign.color('tint'),
        borderRadius: BorderRadius.circular(
          pikoDesign.dimension('components.buttons.radius'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: pikoDesign.dimension('spacing.3'),
            runSpacing: pikoDesign.dimension('spacing.2'),
            children: [
              Semantics(
                liveRegion: true,
                child: Text(copy.text('vocab.deleted')),
              ),
              PikoButton(
                label: copy.text('vocab.undo'),
                variant: PikoButtonVariant.ghost,
                onPressed: session.isBusy || exitDraining || exitRequest != null
                    ? null
                    : () => undoEntry(latest.entry.id),
              ),
            ],
          ),
          Text(
            '${latest.entry.targetText} · ${latest.entry.nativeText}',
            // Identification is bounded; full text remains in the editor and
            // this Text's semantics. A long entry cannot consume the viewport.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pikoDesign.color('muted'),
              fontSize: pikoDesign.dimension('typography.small'),
            ),
          ),
          if (latest.error != null || undoFeedback != null)
            Semantics(
              liveRegion: true,
              child: Text(
                copy.text(undoErrorKey(latest.error ?? undoFeedback!)),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> complete() async {
    if (exitRequest != null || session.isConfirming || exitDraining) return;
    final initiatingSession = session;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    try {
      final operation = initiatingSession.completeSession();
      widget.onPendingWrites?.call(
        operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await operation;
      if (!mounted ||
          !identical(session, initiatingSession) ||
          route?.isCurrent != true) {
        return;
      }
      await requestExit();
    } catch (_) {
      if (!mounted || !identical(session, initiatingSession)) return;
      setState(() {
        centerRequested = true;
      });
      scheduleLayout();
    }
  }

  Future<void> openInterchange() async {
    final open = widget.onOpenInterchange;
    if (open == null || exitDraining || exitRequest != null || session.isBusy)
      return;
    final owner = session;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    setState(() => exitDraining = true);
    FocusScope.of(context).unfocus();
    try {
      final draining = owner.awaitSavedEdits();
      widget.onPendingWrites?.call(draining);
      await draining;
      if (!mounted || session != owner || route?.isCurrent != true) return;
      await open();
      if (!mounted || session != owner || route?.isCurrent != true) return;
      final refreshing = owner.refreshSavedEntries();
      widget.onPendingWrites?.call(refreshing);
      await refreshing;
    } catch (_) {
      if (mounted && session == owner && route?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PikoCopyScope.of(context).text('entry.saveFailed')),
          ),
        );
      }
    } finally {
      if (mounted && session == owner) setState(() => exitDraining = false);
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
              draft.nativeText.trim().isNotEmpty ||
              draft.assignments.isNotEmpty)) {
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
              purpose: PikoDialogPurpose.confirmation,
              title: copy.text('entry.exitTitle'),
              body: Text(copy.text('entry.exitWarning')),
              actions: [
                PikoDialogAction(
                  label: copy.text('entry.continue'),
                  role: PikoDialogActionRole.safe,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                PikoDialogAction(
                  label: copy.text('entry.discard'),
                  role: PikoDialogActionRole.destructive,
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
    CategoryValidation() => 'category.selectionInvalid',
    _ => 'entry.saveFailed',
  };

  Widget card(String id, int index, BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final owningSession = session;
    final draft = id == draftId;
    final saved = draft ? null : session.savedEntryState(id);
    final values = draft ? session.draft : saved!.draft;
    final editor = editors.putIfAbsent(
      id,
      () => _Editors(values, () {
        if (!mounted || id != activeId || userScrolling) return;
        visibilityRequested = true;
        followEditor = true;
        scheduleLayout();
      }),
    )..sync(values);
    final active = id == activeId;
    final error = draft ? session.draftError : saved!.error;
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
        widget.onPendingWrites?.call(session.awaitSavedEdits());
      }
    }

    Widget field(bool target) => SizedBox(
      key: target ? editor.targetBounds : editor.nativeBounds,
      child: PikoTextField(
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
        textInputAction: target ? TextInputAction.next : TextInputAction.done,
        // Keep traversal inside this editor and guard even a cached IME callback.
        onEditingComplete: () {},
        onSubmitted: (_) {
          if (session.isBusy || exitDraining || id != activeId) return;
          if (target) {
            editor.nativeFocus.requestFocus();
          } else {
            editor.nativeFocus.unfocus();
          }
        },
        error:
            error ==
                (target
                    ? VocabularyValidation.requiredTarget
                    : VocabularyValidation.requiredNative)
            ? copy.text(errorKey(error!))
            : null,
        onChanged: (value) => edit(target, value),
      ),
    );
    Widget reveal(Widget child) => draft
        ? child
        : PikoSwipeReveal(
            label: copy.text('vocab.delete'),
            enabled:
                !active &&
                !session.isBusy &&
                !exitDraining &&
                exitRequest == null,
            onDelete: session.supportsDeletion ? () => deleteEntry(id) : null,
            child: child,
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
      child: reveal(
        animate(
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
                        if (draft &&
                            values.targetText.trim().isEmpty &&
                            values.nativeText.trim().isEmpty)
                          Text(
                            copy.text('entry.newVocabulary'),
                            style: TextStyle(
                              fontSize: pikoDesign.dimension('typography.body'),
                              fontWeight: pikoDesign.weight(
                                'typography.titleWeight',
                              ),
                            ),
                          )
                        else ...[
                          if (values.targetText.trim().isNotEmpty)
                            Text(
                              values.targetText,
                              style: TextStyle(
                                fontSize: pikoDesign.dimension(
                                  'typography.body',
                                ),
                                fontWeight: pikoDesign.weight(
                                  'typography.titleWeight',
                                ),
                              ),
                            ),
                          if (values.targetText.trim().isNotEmpty &&
                              values.nativeText.trim().isNotEmpty)
                            SizedBox(
                              height: pikoDesign.dimension(
                                'components.entryStack.previewGap',
                              ),
                            ),
                          if (values.nativeText.trim().isNotEmpty)
                            Text(
                              values.nativeText,
                              style: TextStyle(
                                fontSize: pikoDesign.dimension(
                                  'typography.body',
                                ),
                                color: pikoDesign.color('muted'),
                              ),
                            ),
                        ],
                        if (widget.categoriesRepository != null &&
                            values.assignments.isNotEmpty)
                          VocabularyCategories(
                            key: ObjectKey(owningSession),
                            collectionId: widget.collection.id,
                            entryId: draft ? null : id,
                            repository: widget.categoriesRepository!,
                            draftAssignments: values.assignments,
                          ),
                        if (error != null)
                          Text(
                            copy.text(errorKey(error)),
                            style: TextStyle(color: pikoDesign.color('danger')),
                          ),
                        if (deletionErrorId == id && deletionError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              copy.text('vocab.deleteFailed'),
                              style: TextStyle(
                                color: pikoDesign.color('danger'),
                              ),
                            ),
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
                          if (widget.categoriesRepository != null &&
                              session.supportsCategories)
                            VocabularyCategories(
                              key: ObjectKey(owningSession),
                              collectionId: widget.collection.id,
                              entryId: draft ? null : id,
                              repository: widget.categoriesRepository!,
                              draftAssignments: values.assignments,
                              disabled:
                                  !active ||
                                  session.isBusy ||
                                  exitDraining ||
                                  exitRequest != null,
                              onPendingWrites: widget.onPendingWrites,
                              onMetadataChanged:
                                  session.isBusy ||
                                      exitDraining ||
                                      exitRequest != null
                                  ? null
                                  : () {
                                      if (!mounted || session != owningSession)
                                        return;
                                      final owner = session;
                                      final refreshing = owner
                                          .refreshCategoryReferences(
                                            widget.categoriesRepository!,
                                          );
                                      widget.onPendingWrites?.call(
                                        refreshing.then(
                                          (_) => owner.awaitSavedEdits(),
                                        ),
                                      );
                                    },
                              onSelection: (assignment) {
                                if (!mounted ||
                                    session != owningSession ||
                                    !active ||
                                    id != activeId ||
                                    session.isBusy ||
                                    exitDraining ||
                                    exitRequest != null ||
                                    ModalRoute.of(context)?.isCurrent != true) {
                                  return;
                                }
                                session.setCategoryValues(
                                  entryId: draft ? null : id,
                                  dimensionId: assignment.dimensionId,
                                  valueIds: assignment.valueIds,
                                );
                                final owner = session;
                                final refreshing = owner
                                    .refreshCategoryReferences(
                                      widget.categoriesRepository!,
                                    );
                                widget.onPendingWrites?.call(
                                  refreshing.then(
                                    (_) => owner.awaitSavedEdits(),
                                  ),
                                );
                              },
                            ),
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
                          if (error != null &&
                              error is! VocabularyValidation &&
                              error is! CategoryValidation)
                            PikoButton(
                              label: copy.text('action.retry'),
                              onPressed: session.isBusy || exitDraining
                                  ? null
                                  : draft
                                  ? confirm
                                  : () => session.retrySavedEntry(id),
                            ),
                          if (!draft && session.supportsDeletion)
                            PikoButton(
                              label: copy.text('vocab.delete'),
                              icon: const PikoIcon(PikoIconName.trash),
                              variant: PikoButtonVariant.dangerGhost,
                              onPressed:
                                  session.isBusy ||
                                      exitDraining ||
                                      exitRequest != null
                                  ? null
                                  : () => deleteEntry(id),
                            ),
                          if (deletionErrorId == id && deletionError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                copy.text('vocab.deleteFailed'),
                                style: TextStyle(
                                  color: pikoDesign.color('danger'),
                                ),
                              ),
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
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      pikoDesign.dimension('layout.pageTop'),
                      horizontal,
                      0,
                    ),
                    child: Column(
                      children: [
                        PikoEntryHeader(
                          title: copy.text('entry.title'),
                          backLabel: copy.text('common.back'),
                          completionLabel: copy.text('entry.complete'),
                          onBack: session.isBusy || exitDraining
                              ? null
                              : requestExit,
                          onComplete:
                              session.isBusy ||
                                  exitDraining ||
                                  exitRequest != null
                              ? null
                              : complete,
                        ),
                        if (widget.onOpenInterchange != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: PikoButton(
                              label: copy.text('json.title'),
                              variant: PikoButtonVariant.ghost,
                              onPressed:
                                  session.isBusy ||
                                      exitDraining ||
                                      exitRequest != null
                                  ? null
                                  : openInterchange,
                            ),
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
                        undoBar(context),
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
    session.forgetUndo();
    for (final editor in editors.values) {
      editor.dispose();
    }
    for (final editor in retiredEditors) {
      editor.dispose();
    }
    retiredEditors.clear();
    scroll.dispose();
    stackFocus.dispose();
    super.dispose();
  }
}
