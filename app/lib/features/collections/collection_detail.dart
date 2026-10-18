import 'learning_help.dart';
import 'collection_view_controls.dart';
import 'collection_hint_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/clock.dart';
import '../../data/collections_repository.dart';
import '../../data/collection_query.dart';
import '../../data/categories_repository.dart';
import '../../data/learning_item.dart';
import '../../data/preferred_direction.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_heading_action.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/components/piko_page_navigation.dart';
import '../vocabulary/vocabulary_selection.dart';
import '../vocabulary/vocabulary_selection_panel.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/piko_theme.dart';
import '../entry/entry_session_route.dart';
import '../learning/review_launch.dart';
import '../vocabulary/collection_vocabulary.dart';
import '../vocabulary/collection_vocabulary_mutations.dart';
import 'collection_write_barrier.dart';
import 'collection_entry_count.dart';
import 'collection_review_count.dart';
import 'collection_review_entry_point.dart';
import 'collection_query_binding.dart';
import 'collection_search_field.dart';
import 'collection_scroll_physics.dart';
import 'filter_selection_dialog.dart';
import '../speed/speed_launch.dart';
import '../speed/selected_speed_launch.dart';
import '../speed/speed_setup_dialog.dart'
    show SpeedSessionFactory, SelectedSpeedSessionFactory;
import '../categories/category_management.dart';
import '../settings/preferred_direction_controller.dart';

class CollectionLoadFailure extends StatelessWidget {
  const CollectionLoadFailure({required this.onRetry, super.key});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Column(
      children: [
        Text(copy.text('collection.loadFailed')),
        PikoButton(label: copy.text('action.retry'), onPressed: onRetry),
      ],
    );
  }
}

class CollectionDetail extends StatefulWidget {
  const CollectionDetail({
    required this.repository,
    required this.collectionId,
    this.entrySessionFactory,
    this.interchangeBuilder,
    this.vocabularyRepository,
    this.onPendingVocabularyWrites,
    this.vocabularyMutationsFactory,
    this.reviewSessionFactory,
    this.reviewMembershipLoader,
    this.reviewCountPolicy,
    this.reviewCountClock = const SystemPikoClock(),
    this.categoryManagementBuilder,
    this.queryBinding,
    this.speedSessionFactory,
    this.selectedSpeedSessionFactory,
    this.categoriesRepository,
    this.directionBinding,
    super.key,
  }) : assert((reviewMembershipLoader == null) == (reviewCountPolicy == null));
  final CollectionsRepository repository;
  final String collectionId;
  final EntrySessionFactory? entrySessionFactory;
  final Widget Function(BuildContext, CollectionRecord)? interchangeBuilder;
  final VocabularyRepository? vocabularyRepository;
  final ValueChanged<Future<void>>? onPendingVocabularyWrites;
  final CollectionVocabularyMutationsFactory? vocabularyMutationsFactory;
  final ReviewSessionFactory? reviewSessionFactory;
  final CollectionReviewMembershipLoader? reviewMembershipLoader;
  final CollectionReviewCountPolicy? reviewCountPolicy;
  final PikoClock reviewCountClock;

  /// Category controls expand inside the Collection menu, retaining its route.
  final WidgetBuilder? categoryManagementBuilder;

  /// Runtime-owned; this route listens but never disposes the shared projection.
  final CollectionQueryBinding? queryBinding;
  final SpeedSessionFactory? speedSessionFactory;
  final SelectedSpeedSessionFactory? selectedSpeedSessionFactory;
  final CategoriesRepository? categoriesRepository;
  final ValueListenable<PreferredDirectionController?>? directionBinding;
  @override
  State<CollectionDetail> createState() => _CollectionDetailState();
}

class _CollectionDetailState extends State<CollectionDetail> with RouteAware {
  final _interactionAnchor = PikoInteractionAnchor();
  final _selection = VocabularySelection();
  RouteObserver<PageRoute<dynamic>>? _pageObserver;
  PageRoute<dynamic>? _pageRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = PikoPageNavigation.maybeOf(context);
    final route = ModalRoute.of(context);
    if (observer != _pageObserver || route != _pageRoute) {
      _pageObserver?.unsubscribe(this);
      _pageObserver = observer;
      _pageRoute = route is PageRoute<dynamic> ? route : null;
      if (observer != null && _pageRoute != null) {
        observer.subscribe(this, _pageRoute!);
      }
    }
  }

  @override
  void didPushNext() {
    _selection.clear();
    _interactionAnchor.clear();
  }

  bool get _directionReady =>
      widget.directionBinding == null ||
      widget.directionBinding!.value?.ready == true &&
          widget.directionBinding!.value?.pending == false;
  Set<LearningDirection> get _directions => !_directionReady
      ? const {}
      : (widget.directionBinding?.value?.value ?? PreferredDirection.both)
            .directions;
  late Stream<CollectionRecord?> _collection;
  bool _openingEntry = false;
  bool _openingReview = false;
  bool _openingSpeed = false;
  int? _speedCompletedCount;
  bool get _genuinelyEmpty =>
      widget.queryBinding?.ready == true &&
      widget.queryBinding!.snapshot!.allEntries.isEmpty;
  CollectionQuerySnapshot? _heldLearningSnapshot;
  bool get _learningBusy => _openingReview || _openingSpeed;
  bool _mutationWasBusy = false;
  int _reviewIdentity = 0;
  CollectionRecord? _currentCollection;
  CollectionRecord? _lastReadyCollection;
  CollectionVocabularyMutations? _mutations;
  CollectionWriteBarrier _writeBarrier = CollectionWriteBarrier();
  Object? _deleteRequest;
  Object? _deleteError;
  bool _deleting = false;
  int _identity = 0;
  ModalRoute<bool>? _deleteDialog;
  ModalRoute<bool>? _menuDialog;
  Object? _menuRequest;
  ModalRoute<CollectionFilterSelection>? _filterDialog;
  Object? _filterRequest;
  final _menuFocus = FocusNode();
  final _name = TextEditingController();
  late final _nameFocus = FocusNode(
    onKeyEvent: (_, event) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (event is KeyDownEvent) _saveRename();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
  final _renameFocus = FocusNode();
  bool _renaming = false;
  Object? _renameRequest;
  Object? _renameError;

  void _restoreRenameFocus(ModalRoute<dynamic>? route, int identity) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identity == _identity &&
          route?.isCurrent == true &&
          !_renaming &&
          _currentCollection != null) {
        _renameFocus.requestFocus();
      }
    });
  }

  void _beginRename() {
    final record = _currentCollection;
    final route = ModalRoute.of(context);
    if (record == null ||
        _renameRequest != null ||
        _deleteRequest != null ||
        _openingEntry ||
        _learningBusy ||
        route?.isCurrent != true) {
      return;
    }
    final identity = _identity;
    _name.value = TextEditingValue(
      text: record.name,
      selection: TextSelection(baseOffset: 0, extentOffset: record.name.length),
    );
    setState(() {
      _renaming = true;
      _renameError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identity == _identity &&
          _renaming &&
          _renameRequest == null &&
          route?.isCurrent == true) {
        _nameFocus.requestFocus();
      }
    });
  }

  void _cancelRename() {
    final route = ModalRoute.of(context);
    if (!_renaming ||
        _renameRequest != null ||
        _deleteRequest != null ||
        route?.isCurrent != true) {
      return;
    }
    setState(() {
      _renaming = false;
      _renameError = null;
    });
    _restoreRenameFocus(route, _identity);
  }

  Future<void> _saveRename() async {
    final record = _currentCollection;
    final route = ModalRoute.of(context);
    if (!_renaming ||
        record == null ||
        _renameRequest != null ||
        _deleteRequest != null ||
        route?.isCurrent != true) {
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _renameError = CollectionValidation.requiredName);
      _nameFocus.requestFocus();
      return;
    }
    final repository = widget.repository;
    final identity = _identity;
    final request = Object();
    final raw = _name.value;
    final register = widget.onPendingVocabularyWrites;
    bool current() =>
        mounted &&
        identity == _identity &&
        identical(_renameRequest, request) &&
        identical(repository, widget.repository) &&
        widget.collectionId == record.id;
    setState(() {
      _renameRequest = request;
      _renameError = null;
    });
    try {
      final operation = (() async {
        final saved = await repository.rename(id: record.id, name: raw.text);
        if (!current()) return;
        setState(() {
          _lastReadyCollection = saved;
          _renaming = false;
        });
        _restoreRenameFocus(route, identity);
      })();
      // Register accepted name work with its captured storage owner before close.
      register?.call(operation);
      await operation;
    } catch (error) {
      if (current()) {
        setState(() => _renameError = error);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identity == _identity &&
              _renaming &&
              _renameRequest == null &&
              route?.isCurrent == true &&
              identical(repository, widget.repository)) {
            _nameFocus.requestFocus();
          }
        });
      }
    } finally {
      if (current()) setState(() => _renameRequest = null);
    }
  }

  Widget _nameHeading(CollectionRecord record, bool ready) {
    final copy = PikoCopyScope.of(context);
    final gap = pikoDesign.dimension('spacing.2');
    final blocked = _renameRequest != null || _deleteRequest != null || !ready;
    if (!_renaming) {
      return Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              headingLevel: 1,
              child: Text(
                record.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SizedBox(width: gap),
          PikoIconButton(
            key: const ValueKey('collection-rename'),
            icon: const PikoIcon(PikoIconName.pencil),
            semanticLabel: copy.text('collection.rename'),
            focusNode: _renameFocus,
            onPressed: blocked || _openingEntry || _learningBusy
                ? null
                : _beginRename,
          ),
        ],
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancelRename,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: copy.text('collection.name'),
                  child: TextField(
                    key: const ValueKey('collection-name'),
                    controller: _name,
                    focusNode: _nameFocus,
                    enabled: !blocked,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveRename(),
                    onChanged: (_) {
                      if (_renameError != null) {
                        setState(() => _renameError = null);
                      }
                    },
                    decoration: pikoInputDecoration(),
                  ),
                ),
              ),
              SizedBox(width: gap),
              PikoIconButton(
                key: const ValueKey('collection-name-save'),
                icon: const PikoIcon(PikoIconName.check),
                semanticLabel: copy.text('action.saveName'),
                onPressed: blocked ? null : _saveRename,
              ),
              SizedBox(width: gap),
              PikoIconButton(
                key: const ValueKey('collection-name-cancel'),
                icon: const PikoIcon(PikoIconName.x),
                semanticLabel: copy.text('action.cancel'),
                onPressed: blocked ? null : _cancelRename,
              ),
            ],
          ),
          if (_renameError != null)
            Padding(
              padding: EdgeInsets.only(top: gap),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  copy.text(
                    _renameError == CollectionValidation.requiredName
                        ? 'collection.requiredName'
                        : 'collection.renameFailed',
                  ),
                  style: TextStyle(color: pikoDesign.color('danger')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _closeDeleteDialog() {
    final owned = _deleteDialog;
    _deleteDialog = null;
    if (owned != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (owned.isActive) owned.navigator?.removeRoute(owned);
      });
    }
  }

  void _closeMenu() {
    final owned = _menuDialog;
    _menuDialog = null;
    _menuRequest = null;
    if (owned != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (owned.isActive) owned.navigator?.removeRoute(owned);
      });
    }
  }

  Future<void> _openMenu() async {
    final record = _currentCollection;
    final route = ModalRoute.of(context);
    if (record == null ||
        _menuRequest != null ||
        _deleteRequest != null ||
        _renameRequest != null ||
        _openingEntry ||
        _learningBusy ||
        route?.isCurrent != true) {
      return;
    }
    final identity = _identity;
    final request = Object();
    final repository = widget.repository;
    final categoryBuilder = widget.categoryManagementBuilder;
    final categories = widget.categoriesRepository;
    final register = widget.onPendingVocabularyWrites;
    final pending = ValueNotifier(false);
    bool current() =>
        mounted &&
        identity == _identity &&
        identical(_menuRequest, request) &&
        identical(widget.repository, repository) &&
        widget.collectionId == record.id;
    setState(() => _menuRequest = request);
    var consumed = false;
    bool consume() {
      if (!current() ||
          consumed ||
          pending.value ||
          _menuDialog?.isCurrent != true) {
        return false;
      }
      consumed = true;
      return true;
    }

    try {
      final delete = await showPikoDialog<bool>(
        context,
        canRestoreFocus: () => current() && route?.isCurrent == true,
        canDismiss: consume,
        onRouteCreated: (owned) {
          if (current()) {
            _menuDialog = owned;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (owned.isActive) owned.navigator?.removeRoute(owned);
            });
          }
        },
        builder: (menuContext) {
          final copy = PikoCopyScope.of(menuContext);
          return ValueListenableBuilder<bool>(
            valueListenable: pending,
            builder: (_, writing, _) => Focus(
              autofocus: true,
              child: PikoDialog(
                purpose: PikoDialogPurpose.directChoice,
                dismissible: !writing,
                title: copy.text('r2.more'),
                onClose: () {
                  if (consume()) Navigator.of(menuContext).pop();
                },
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.interchangeBuilder != null)
                      PikoButton(
                        label: copy.text('json.title'),
                        onPressed: writing
                            ? null
                            : () {
                                if (consume()) {
                                  Navigator.of(menuContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) _openInterchange();
                                  });
                                }
                              },
                      ),
                    if (widget.vocabularyRepository
                            is VocabularyContentRepository &&
                        widget.vocabularyRepository
                            is CollectionHintPreferences)
                      ExpansionTile(
                        key: const ValueKey('collection-menu-settings'),
                        leading: const PikoIcon(PikoIconName.settings),
                        title: Text(copy.text('nav.settings')),
                        enabled: !writing,
                        maintainState: true,
                        children: [
                          CollectionHintSettings(
                            collectionId: record.id,
                            repository:
                                widget.vocabularyRepository!
                                    as VocabularyContentRepository,
                            onPendingWrites: register,
                            onBusyChanged: (busy) {
                              if (current()) pending.value = busy;
                            },
                          ),
                        ],
                      ),
                    if (categoryBuilder != null || categories != null)
                      ExpansionTile(
                        key: const ValueKey('collection-menu-categories'),
                        leading: const PikoIcon(PikoIconName.layers),
                        title: Text(copy.text('r2.editCategories')),
                        enabled: !writing,
                        maintainState: true,
                        children: [
                          if (categoryBuilder != null)
                            Builder(builder: categoryBuilder)
                          else
                            CategoryManagement(
                              collectionId: record.id,
                              repository: categories!,
                              onPendingWrites: register,
                              onPendingChanged: (busy) {
                                if (current()) pending.value = busy;
                              },
                            ),
                        ],
                      ),
                    PikoButton(
                      key: const ValueKey('collection-menu-delete'),
                      label: copy.text('collection.delete'),
                      icon: const PikoIcon(PikoIconName.trash),
                      variant: PikoButtonVariant.dangerGhost,
                      onPressed: writing
                          ? null
                          : () {
                              if (consume()) {
                                Navigator.of(menuContext).pop(true);
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!current()) return;
      _menuDialog = null;
      setState(() => _menuRequest = null);
      if (delete == true &&
          route?.isCurrent == true &&
          _currentCollection?.id == record.id) {
        await _deleteCollection();
      }
    } finally {
      if (current()) setState(() => _menuRequest = null);
      pending.dispose();
    }
  }

  bool get _queryControlsAvailable =>
      _currentCollection != null &&
      _deleteRequest == null &&
      _renameRequest == null &&
      !_openingEntry &&
      !_learningBusy &&
      _mutations?.isBusy != true;

  void _closeFilters() {
    final owned = _filterDialog;
    _filterDialog = null;
    _filterRequest = null;
    if (owned != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (owned.isActive) owned.navigator?.removeRoute(owned);
      });
    }
  }

  Future<void> _openFilters() async {
    final binding = widget.queryBinding;
    final route = ModalRoute.of(context);
    if (binding == null ||
        !binding.ready ||
        !_queryControlsAvailable ||
        _filterRequest != null ||
        route?.isCurrent != true) {
      return;
    }
    final identity = _identity;
    final request = Object();
    bool current() =>
        mounted &&
        identity == _identity &&
        identical(_filterRequest, request) &&
        identical(widget.queryBinding, binding);
    _filterRequest = request;
    var consumed = false;
    bool consume() {
      if (!current() || consumed || _filterDialog?.isCurrent != true) {
        return false;
      }
      consumed = true;
      return true;
    }

    try {
      final result = await showPikoDialog<CollectionFilterSelection>(
        context,
        canRestoreFocus: () => current() && route?.isCurrent == true,
        canDismiss: consume,
        onRouteCreated: (owned) {
          if (current()) {
            _filterDialog = owned;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (owned.isActive) owned.navigator?.removeRoute(owned);
            });
          }
        },
        builder: (dialogContext) => FilterSelectionDialog(
          snapshot: binding.snapshot!,
          opening: binding.scope.filters,
          canApply: () => current() && _queryControlsAvailable,
          onPendingWrites: widget.onPendingVocabularyWrites,
          reloadDefinitions: () => binding.service.query(
            collectionId: binding.collectionId,
            at: binding.clock.now().toUtc(),
          ),
          onClose: () {
            if (consume()) Navigator.of(dialogContext).pop();
          },
        ),
      );
      if (current() &&
          result != null &&
          route?.isCurrent == true &&
          _queryControlsAvailable) {
        binding.scope.setFilters(result);
      }
    } finally {
      if (current()) {
        _filterDialog = null;
        _filterRequest = null;
      }
    }
  }

  Future<void> _deleteCollection() async {
    final record = _currentCollection;
    final route = ModalRoute.of(context);
    if (_deleteRequest != null ||
        _renameRequest != null ||
        record == null ||
        _openingEntry ||
        _learningBusy ||
        route?.isCurrent == false) {
      return;
    }
    final repository = widget.repository;
    final identity = _identity;
    final request = Object();
    final barrier = _writeBarrier;
    final mutations = _mutations;
    final register = widget.onPendingVocabularyWrites;
    bool current() =>
        mounted &&
        identity == _identity &&
        identical(_deleteRequest, request) &&
        identical(widget.repository, repository) &&
        widget.collectionId == record.id;
    bool dialogConsumed = false;
    bool consumeDialog() {
      if (!current() || dialogConsumed || _deleteDialog?.isCurrent != true) {
        return false;
      }
      dialogConsumed = true;
      return true;
    }

    setState(() {
      _deleteRequest = request;
      _deleteError = null;
    });
    try {
      final confirmed = await showPikoDialog<bool>(
        context,
        canRestoreFocus: () =>
            current() && route?.isCurrent != false && !_deleting,
        canDismiss: consumeDialog,
        onRouteCreated: (owned) {
          if (current()) {
            _deleteDialog = owned;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (owned.isActive) owned.navigator?.removeRoute(owned);
            });
          }
        },
        builder: (dialogContext) {
          final copy = PikoCopyScope.of(dialogContext);
          return PikoDialog(
            purpose: PikoDialogPurpose.confirmation,
            onClose: () {
              if (consumeDialog()) Navigator.of(dialogContext).pop();
            },
            title: copy.text('collection.delete'),
            body: Text(
              copy.text('collection.deleteWarning', {'name': record.name}),
            ),
            actions: [
              PikoDialogAction(
                label: copy.text('action.cancel'),
                role: PikoDialogActionRole.safe,
                onPressed: () {
                  if (consumeDialog()) Navigator.of(dialogContext).pop();
                },
              ),
              PikoDialogAction(
                label: copy.text('collection.delete'),
                icon: const PikoIcon(PikoIconName.trash),
                role: PikoDialogActionRole.destructive,
                onPressed: () {
                  if (consumeDialog()) Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        },
      );
      if (!current() ||
          confirmed != true ||
          route?.isCurrent == false ||
          _currentCollection?.id != record.id) {
        return;
      }
      _deleteDialog = null;
      barrier.freeze();
      setState(() => _deleting = true);
      final operation = (() async {
        await barrier.drain();
        await mutations?.awaitPending();
        if (!current()) {
          return; // Never begin a new delete after route replacement/disposal.
        }
        await repository.delete(record.id);
        await mutations
            ?.end(); // Included in the registered accepted operation.
      })();
      register?.call(operation);
      await operation;
      if (!current()) return;
      _endMutations(register);
      if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
    } catch (error) {
      if (current()) setState(() => _deleteError = error);
    } finally {
      if (current()) {
        barrier.release();
        setState(() {
          _deleteRequest = null;
          _deleting = false;
        });
      }
    }
  }

  void _mutationChanged() {
    final busy = _mutations?.isBusy == true;
    if (mounted) {
      setState(() {
        if (_mutationWasBusy && !busy && !_learningBusy) _reviewIdentity++;
        _mutationWasBusy = busy;
      });
    } else {
      _mutationWasBusy = busy;
    }
  }

  void _createMutations() {
    _mutations = widget.vocabularyMutationsFactory?.call(widget.collectionId);
    _mutationWasBusy = _mutations?.isBusy == true;
    _mutations?.addListener(_mutationChanged);
  }

  void _endMutations(ValueChanged<Future<void>>? register) {
    final old = _mutations;
    _mutations = null;
    _mutationWasBusy = false;
    old?.removeListener(_mutationChanged);
    if (old != null) {
      final ending = old.end();
      register?.call(ending);
    }
  }

  Future<void> _openInterchange() async {
    final record = _currentCollection, builder = widget.interchangeBuilder;
    if (record == null || builder == null || _openingEntry || _learningBusy) {
      return;
    }
    setState(() => _openingEntry = true);
    try {
      await showPikoDialog<Object?>(
        context,
        builder: (context) => builder(context, record),
      );
    } finally {
      if (mounted) {
        setState(() => _openingEntry = false);
        widget.queryBinding?.refresh();
      }
    }
  }

  Future<void> _openEntry() async {
    if (widget.interchangeBuilder == null) {
      await _openManualEntry();
      return;
    }
    if (_openingEntry || _learningBusy) return;
    final method = await showPikoDialog<String>(
      context,
      builder: (context) {
        final copy = PikoCopyScope.of(context);
        return PikoDialog(
          title: copy.text('entry.chooseMethod'),
          purpose: PikoDialogPurpose.directChoice,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoButton(
                label: copy.text('entry.manualMethod'),
                onPressed: () => Navigator.of(context).pop('manual'),
              ),
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              PikoButton(
                label: copy.text('json.importTab'),
                onPressed: () => Navigator.of(context).pop('import'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (method == 'manual') await _openManualEntry();
    if (method == 'import') await _openInterchange();
  }

  Future<void> _openManualEntry() async {
    final record = _currentCollection;
    final factory = widget.entrySessionFactory;
    if (_openingEntry ||
        _learningBusy ||
        _renameRequest != null ||
        _deleteRequest != null ||
        _mutations?.isBusy == true ||
        record == null ||
        factory == null) {
      return;
    }
    setState(() => _openingEntry = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              EntrySessionRoute(collection: record, factory: factory),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingEntry = false;
          _reviewIdentity++;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.queryBinding?.scope.resetExpansion();
    _createMutations();
    _watch();
  }

  void _watch() {
    _currentCollection = null;
    _collection = widget.repository.watchById(widget.collectionId);
  }

  @override
  void didUpdateWidget(CollectionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId) _selection.clear();
    if (oldWidget.categoriesRepository != widget.categoriesRepository ||
        oldWidget.categoryManagementBuilder !=
            widget.categoryManagementBuilder) {
      _closeMenu();
    }
    if (oldWidget.collectionId != widget.collectionId ||
        oldWidget.repository != widget.repository ||
        oldWidget.vocabularyMutationsFactory !=
            widget.vocabularyMutationsFactory) {
      _identity++;
      _speedCompletedCount = null;
      _openingReview = false;
      _openingSpeed = false;
      _heldLearningSnapshot = null;
      _renaming = false;
      _renameRequest = null;
      _renameError = null;
      _name.clear();
      _closeDeleteDialog();
      _closeMenu();
      _closeFilters();
      _deleteRequest = null;
      _deleteError = null;
      _deleting = false;
      _writeBarrier.dispose();
      _writeBarrier = CollectionWriteBarrier();
      _endMutations(oldWidget.onPendingVocabularyWrites);
      _createMutations();
    }
    if (oldWidget.reviewSessionFactory != widget.reviewSessionFactory ||
        oldWidget.speedSessionFactory != widget.speedSessionFactory ||
        oldWidget.selectedSpeedSessionFactory !=
            widget.selectedSpeedSessionFactory ||
        oldWidget.queryBinding != widget.queryBinding ||
        oldWidget.reviewMembershipLoader != widget.reviewMembershipLoader ||
        oldWidget.reviewCountPolicy != widget.reviewCountPolicy ||
        !identical(oldWidget.reviewCountClock, widget.reviewCountClock) ||
        oldWidget.vocabularyRepository != widget.vocabularyRepository) {
      _closeFilters();
      _reviewIdentity++;
      if (_learningBusy) _writeBarrier.release();
      _openingReview = false;
      _openingSpeed = false;
      _heldLearningSnapshot = null;
    }
    if (oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId) {
      _lastReadyCollection = null;
      _watch();
    }
  }

  @override
  void dispose() {
    _pageObserver?.unsubscribe(this);
    _selection.dispose();
    _identity++;
    _name.dispose();
    _nameFocus.dispose();
    _renameFocus.dispose();
    _menuFocus.dispose();
    _closeDeleteDialog();
    _closeMenu();
    _closeFilters();
    _writeBarrier.dispose();
    _endMutations(widget.onPendingVocabularyWrites);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _selection,
    builder: (_, _) => _withDirections(context),
  );

  Widget _withDirections(BuildContext context) {
    final directionBinding = widget.directionBinding;
    if (directionBinding != null) {
      return ValueListenableBuilder(
        valueListenable: directionBinding,
        builder: (context, controller, _) => controller == null
            ? _withProjection(context)
            : ListenableBuilder(
                listenable: controller,
                builder: (context, _) => _withProjection(context),
              ),
      );
    }
    return _withProjection(context);
  }

  Widget _withProjection(BuildContext context) {
    final binding = widget.queryBinding;
    if (binding == null) return _build(context);
    return ListenableBuilder(
      listenable: binding,
      builder: (_, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final barrierForBuild = _writeBarrier;
    final registerForBuild = widget.onPendingVocabularyWrites;
    final identityForBuild = _identity;
    final reviewIdentityForBuild = _reviewIdentity;
    final mutationsForBuild = _mutations;
    return Scaffold(
      body: StreamBuilder<CollectionRecord?>(
        stream: _collection,
        builder: (context, snapshot) {
          final record = snapshot.data;
          final ready =
              !snapshot.hasError &&
              snapshot.connectionState != ConnectionState.waiting &&
              snapshot.connectionState != ConnectionState.none &&
              record != null;
          _currentCollection = ready ? record : null;
          if (ready) {
            _lastReadyCollection = record;
          } else if (!snapshot.hasError &&
              snapshot.connectionState != ConnectionState.waiting &&
              snapshot.connectionState != ConnectionState.none &&
              record == null) {
            _lastReadyCollection = null;
          }
          final page = PikoPage.slivers(
            safeAreaBottom: widget.queryBinding == null,
            key: ValueKey('collection-page-${widget.collectionId}'),
            interactionAnchor: _interactionAnchor,
            physics: const CollectionScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _detailHeading(record, ready),
                    if (_speedCompletedCount != null && ready)
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          key: const ValueKey('speed-completion-notice'),
                          children: [
                            Expanded(
                              child: Text(
                                _speedCompletedCount == 1
                                    ? copy.text('speed.completionNoticeOne')
                                    : copy.text('speed.completionNotice', {
                                        'count': _speedCompletedCount!,
                                      }),
                              ),
                            ),
                            PikoIconButton(
                              semanticLabel: copy.text(
                                'speed.dismissCompletion',
                              ),
                              icon: const PikoIcon(PikoIconName.x),
                              onPressed: () =>
                                  setState(() => _speedCompletedCount = null),
                            ),
                          ],
                        ),
                      ),
                    if (_deleting) Text(copy.text('collection.deleting')),
                    if (_deleteError != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          copy.text('collection.deleteFailed'),
                          style: TextStyle(color: pikoDesign.color('danger')),
                        ),
                      ),
                    if (snapshot.hasError)
                      CollectionLoadFailure(onRetry: () => setState(_watch))
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      Text(copy.text('collection.loading'))
                    else if (record == null)
                      Text(copy.text('collection.notFound')),
                    if (_lastReadyCollection != null &&
                        widget.queryBinding != null &&
                        (widget.reviewSessionFactory != null ||
                            widget.speedSessionFactory != null) &&
                        widget.vocabularyRepository != null)
                      Padding(
                        padding: EdgeInsets.only(
                          top: pikoDesign.dimension('spacing.2'),
                        ),
                        child: _projectedLearning(
                          enabled:
                              ready &&
                              _deleteRequest == null &&
                              _renameRequest == null &&
                              !_openingEntry &&
                              (_mutations?.isBusy != true || _learningBusy),
                          beforeLaunch: () async {
                            barrierForBuild.freeze();
                            await barrierForBuild.drain();
                            await mutationsForBuild?.awaitPending();
                          },
                          onBusyChanged: (speed, busy) {
                            if (mounted &&
                                identityForBuild == _identity &&
                                reviewIdentityForBuild == _reviewIdentity) {
                              setState(() {
                                if (busy) {
                                  _speedCompletedCount = null;
                                  _heldLearningSnapshot ??=
                                      widget.queryBinding!.snapshot;
                                }
                                if (speed) {
                                  _openingSpeed = busy;
                                } else {
                                  _openingReview = busy;
                                }
                                if (!_learningBusy) {
                                  _heldLearningSnapshot = null;
                                }
                              });
                              if (!_learningBusy) barrierForBuild.release();
                            }
                          },
                        ),
                      ),
                    if (_lastReadyCollection != null &&
                        widget.queryBinding == null &&
                        widget.reviewSessionFactory != null &&
                        widget.vocabularyRepository != null)
                      Padding(
                        key: ValueKey(
                          'review-launch-slot-${widget.collectionId}-$_identity-$_reviewIdentity',
                        ),
                        padding: EdgeInsets.only(
                          top: pikoDesign.dimension(
                            widget.reviewMembershipLoader == null
                                ? 'spacing.3'
                                : 'spacing.5',
                          ),
                        ),
                        child: widget.reviewMembershipLoader == null
                            ? ReviewLaunch(
                                key: ValueKey(
                                  'review-launch-${widget.collectionId}-$_identity-$_reviewIdentity',
                                ),
                                collection: _lastReadyCollection!,
                                factory: widget.reviewSessionFactory!,
                                vocabularyRepository:
                                    widget.vocabularyRepository!,
                                categoriesRepository:
                                    widget.categoriesRepository,
                                enabled:
                                    ready &&
                                    _deleteRequest == null &&
                                    _renameRequest == null &&
                                    !_openingEntry &&
                                    _mutations?.isBusy != true,
                                beforeLaunch: () async {
                                  barrierForBuild.freeze();
                                  await barrierForBuild.drain();
                                  await mutationsForBuild?.awaitPending();
                                },
                                onPendingWrites: registerForBuild,
                                onBusyChanged: (busy) {
                                  if (mounted &&
                                      identityForBuild == _identity &&
                                      reviewIdentityForBuild ==
                                          _reviewIdentity) {
                                    if (!busy) barrierForBuild.release();
                                    setState(() => _openingReview = busy);
                                  }
                                },
                              )
                            : CollectionReviewEntryPoint(
                                key: ValueKey(
                                  'review-launch-${widget.collectionId}-$_identity-$_reviewIdentity',
                                ),
                                collection: _lastReadyCollection!,
                                loader: widget.reviewMembershipLoader!,
                                policy: widget.reviewCountPolicy!,
                                clock: widget.reviewCountClock,
                                factory: widget.reviewSessionFactory!,
                                categoriesRepository:
                                    widget.categoriesRepository,
                                vocabularyRepository:
                                    widget.vocabularyRepository!,
                                enabled:
                                    ready &&
                                    _deleteRequest == null &&
                                    _renameRequest == null &&
                                    !_openingEntry &&
                                    _mutations?.isBusy != true,
                                beforeLaunch: () async {
                                  barrierForBuild.freeze();
                                  await barrierForBuild.drain();
                                  await mutationsForBuild?.awaitPending();
                                },
                                onPendingWrites: registerForBuild,
                                onBusyChanged: (busy) {
                                  if (mounted &&
                                      identityForBuild == _identity &&
                                      reviewIdentityForBuild ==
                                          _reviewIdentity) {
                                    if (!busy) barrierForBuild.release();
                                    setState(() => _openingReview = busy);
                                  }
                                },
                                presentation:
                                    ReviewLaunchPresentation.collectionCard,
                              ),
                      ),
                    if (ready &&
                        (widget.entrySessionFactory != null ||
                            widget.vocabularyRepository != null))
                      Padding(
                        padding: EdgeInsets.only(
                          top: pikoDesign.dimension(
                            'components.sectionHeading.topMargin',
                          ),
                          bottom: pikoDesign.dimension(
                            'components.sectionHeading.bottomMargin',
                          ),
                        ),
                        child: Builder(
                          builder: (context) {
                            final heading = Semantics(
                              header: true,
                              headingLevel: 2,
                              child: Text(
                                copy.text('collection.vocabulary'),
                                style: TextStyle(
                                  fontSize: pikoDesign.dimension(
                                    'components.sectionHeading.size',
                                  ),
                                  fontWeight: pikoDesign.weight(
                                    'components.sectionHeading.weight',
                                  ),
                                  color: pikoDesign.color('ink'),
                                ),
                              ),
                            );
                            if (widget.entrySessionFactory == null) {
                              return Row(
                                children: [
                                  Expanded(child: heading),
                                  if (widget.queryBinding != null)
                                    CollectionListMenu(
                                      binding: widget.queryBinding!,
                                      enabled: _queryControlsAvailable,
                                    ),
                                ],
                              );
                            }
                            return PikoHeadingAction(
                              heading: heading,
                              gap: pikoDesign.dimension(
                                'components.sectionHeading.gap',
                              ),
                              action: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.queryBinding != null)
                                    CollectionListMenu(
                                      binding: widget.queryBinding!,
                                      enabled: _queryControlsAvailable,
                                    ),
                                  Tooltip(
                                    message: copy.text('action.addEntry'),
                                    excludeFromSemantics: true,
                                    child: Semantics(
                                      label: copy.text('action.addEntry'),
                                      button: true,
                                      enabled:
                                          _deleteRequest == null &&
                                          _renameRequest == null &&
                                          !_openingEntry &&
                                          !_learningBusy &&
                                          _mutations?.isBusy != true,
                                      onTap:
                                          _deleteRequest != null ||
                                              _renameRequest != null ||
                                              _openingEntry ||
                                              _learningBusy ||
                                              _mutations?.isBusy == true
                                          ? null
                                          : _openEntry,
                                      child: ExcludeSemantics(
                                        child: PikoButton(
                                          label: copy.text(
                                            _genuinelyEmpty
                                                ? 'collection.addFirstWord'
                                                : 'action.new',
                                          ),
                                          icon: const PikoIcon(
                                            PikoIconName.plus,
                                          ),
                                          variant: _genuinelyEmpty
                                              ? PikoButtonVariant.primary
                                              : PikoButtonVariant.ghost,
                                          onPressed:
                                              _deleteRequest != null ||
                                                  _renameRequest != null ||
                                                  _openingEntry ||
                                                  _learningBusy ||
                                                  _mutations?.isBusy == true
                                              ? null
                                              : _openEntry,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (ready &&
                        widget.queryBinding != null &&
                        !_genuinelyEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: pikoDesign.dimension('spacing.3'),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CollectionSearchField(
                              scope: widget.queryBinding!.scope,
                              enabled: _queryControlsAvailable,
                            ),
                            SizedBox(height: pikoDesign.dimension('spacing.2')),
                            CollectionViewControls(
                              binding: widget.queryBinding!,
                              enabled: _queryControlsAvailable,
                              onFilters: _openFilters,
                            ),
                            CollectionListResults(
                              binding: widget.queryBinding!,
                              enabled: _queryControlsAvailable,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_lastReadyCollection != null &&
                  widget.vocabularyRepository != null)
                CollectionVocabulary(
                  sliver: true,
                  key: ValueKey('collection-vocabulary-${widget.collectionId}'),
                  collection: _lastReadyCollection!,
                  repository: widget.vocabularyRepository!,
                  queryBinding: widget.queryBinding,
                  preferredDirections: _directions,
                  categoriesRepository: widget.categoriesRepository,
                  onPendingWrites: (work) {
                    // Capture this build's barrier/dependency callback so old
                    // child work is registered with its original storage owner.
                    barrierForBuild.track(work);
                    registerForBuild?.call(work);
                  },
                  writeBarrier: barrierForBuild,
                  mutations: _mutations,
                  selection: widget.queryBinding == null ? null : _selection,
                ),
            ],
          );
          if (widget.queryBinding == null) return page;
          return Column(
            children: [
              Expanded(child: page),
              VocabularySelectionPanel(
                speedAction:
                    widget.selectedSpeedSessionFactory == null ||
                        widget.vocabularyRepository == null ||
                        _lastReadyCollection == null
                    ? null
                    : SelectedSpeedLaunch(
                        key: ValueKey(
                          'selected-speed-${widget.collectionId}-$_identity-$_reviewIdentity',
                        ),
                        collection: _lastReadyCollection!,
                        selection: _selection,
                        directions: _directions,
                        factory: widget.selectedSpeedSessionFactory!,
                        vocabularyRepository: widget.vocabularyRepository!,
                        categoriesRepository: widget.categoriesRepository,
                        enabled:
                            ready &&
                            _directionReady &&
                            !_openingReview &&
                            !_openingEntry &&
                            _deleteRequest == null &&
                            _renameRequest == null &&
                            (_mutations?.isBusy != true || _openingSpeed) &&
                            (widget.queryBinding!.ready || _openingSpeed) &&
                            widget.queryBinding!.scope.viewReady &&
                            !widget.queryBinding!.scope.viewPending,
                        beforeLaunch: () async {
                          barrierForBuild.freeze();
                          await barrierForBuild.drain();
                          await mutationsForBuild?.awaitPending();
                        },
                        loadScope: (selected) async {
                          final binding = widget.queryBinding!;
                          final snapshot = await binding.service.query(
                            collectionId: binding.collectionId,
                            at: binding.clock.now().toUtc(),
                            search: binding.scope.search,
                            filters: binding.scope.filters,
                          );
                          return SelectedSpeedScope(
                            snapshot,
                            selected,
                            binding.scope.view.sort,
                          );
                        },
                        onBusyChanged: (busy) {
                          if (!mounted ||
                              identityForBuild != _identity ||
                              reviewIdentityForBuild != _reviewIdentity) {
                            return;
                          }
                          setState(() {
                            _openingSpeed = busy;
                            if (busy) {
                              _speedCompletedCount = null;
                              _heldLearningSnapshot ??=
                                  widget.queryBinding!.snapshot;
                            } else {
                              _heldLearningSnapshot = null;
                            }
                          });
                          if (!busy) barrierForBuild.release();
                        },
                        onPendingWrites: registerForBuild,
                        onSessionClosed: widget.queryBinding!.refresh,
                        onCompleted: (count) {
                          if (mounted) {
                            setState(() => _speedCompletedCount = count);
                          }
                        },
                      ),
                selection: _selection,
                matchingIds:
                    widget.queryBinding!.snapshot?.entries
                        .map((entry) => entry.id)
                        .toList() ??
                    const [],
                enabled: _queryControlsAvailable,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _projectedLearning({
    required bool enabled,
    required Future<void> Function() beforeLaunch,
    required void Function(bool speed, bool busy) onBusyChanged,
  }) {
    final binding = widget.queryBinding!;
    final copy = PikoCopyScope.of(context);
    if (!binding.ready && !_learningBusy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.text(
              binding.error == null
                  ? 'collection.reviewLoading'
                  : 'collection.reviewLoadFailed',
            ),
          ),
          if (binding.error != null)
            PikoButton(
              label: copy.text('action.retry'),
              onPressed: binding.loading ? null : binding.refresh,
              variant: PikoButtonVariant.ghost,
            ),
        ],
      );
    }
    final snapshot = _heldLearningSnapshot ?? binding.snapshot!;
    if (snapshot.allEntries.isEmpty || snapshot.entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final counts = {
      for (final entry in snapshot.directions.entries)
        if (_directions.contains(entry.key)) entry.key: entry.value.dueCount,
    };
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final Widget normal;
    if (total == 0 && !_openingReview) {
      final pending = snapshot.directions.entries.any(
        (direction) =>
            _directions.contains(direction.key) &&
            direction.value.pendingRetryCount > 0,
      );
      normal = !_directionReady
          ? const SizedBox.shrink()
          : Text(
              copy.text(
                pending
                    ? 'r2.pending'
                    : binding.scope.restricted
                    ? 'collection.filteredNoReview'
                    : 'r2.caughtUp',
              ),
            );
    } else if (widget.reviewSessionFactory != null) {
      normal = ReviewLaunch(
        key: ValueKey(
          'projected-review-${widget.collectionId}-$_identity-$_reviewIdentity',
        ),
        collection: snapshot.collection,
        factory: widget.reviewSessionFactory!,
        vocabularyRepository: widget.vocabularyRepository!,
        categoriesRepository: widget.categoriesRepository,
        beforeLaunch: beforeLaunch,
        onPendingWrites: widget.onPendingVocabularyWrites,
        onBusyChanged: (busy) => onBusyChanged(false, busy),
        enabled:
            enabled &&
            _directionReady &&
            !_openingSpeed &&
            (binding.ready || _openingReview),
        presentation: ReviewLaunchPresentation.collectionCard,
        dueCount: total,
        directionCounts: counts,
        allowedDirections: _directions,
        directionCountsLoader: () async {
          final fresh = await binding.service.query(
            collectionId: binding.collectionId,
            at: binding.clock.now().toUtc(),
            search: binding.scope.search,
            filters: binding.scope.filters,
          );
          return {
            for (final entry in fresh.directions.entries)
              if (_directions.contains(entry.key))
                entry.key: entry.value.dueCount,
          };
        },
        onSessionClosed: binding.refresh,
      );
    } else {
      normal = const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        normal,
        if (widget.speedSessionFactory != null)
          Padding(
            padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.2')),
            child: SpeedLaunch(
              key: ValueKey(
                'projected-speed-${widget.collectionId}-$_identity-$_reviewIdentity',
              ),
              snapshot: snapshot,
              allowedDirections: _directions,
              scopeIdentity: (
                binding,
                binding.scope.search,
                binding.scope.filters,
              ),
              factory: widget.speedSessionFactory!,
              vocabularyRepository: widget.vocabularyRepository!,
              categoriesRepository: widget.categoriesRepository,
              beforeLaunch: beforeLaunch,
              onBusyChanged: (busy) => onBusyChanged(true, busy),
              onPendingWrites: widget.onPendingVocabularyWrites,
              onSessionClosed: binding.refresh,
              onCompleted: (count) {
                if (mounted) setState(() => _speedCompletedCount = count);
              },
              enabled:
                  enabled &&
                  _directionReady &&
                  !_openingReview &&
                  (binding.ready || _openingSpeed),
              snapshotLoader: () => binding.service.query(
                collectionId: binding.collectionId,
                at: binding.clock.now().toUtc(),
                search: binding.scope.search,
                filters: binding.scope.filters,
              ),
            ),
          ),
      ],
    );
  }

  Widget _detailHeading(CollectionRecord? record, bool ready) {
    final copy = PikoCopyScope.of(context);
    Widget heading(int? entryCount) => PikoHeading(
      title: record?.name ?? copy.text('collection.title'),
      subtitleInset: 0,
      subtitleContent: record == null
          ? null
          : LearningHelpMetadata(
              metadata: collectionEntryMetadata(context, record, entryCount),
            ),
      subtitle: record == null
          ? null
          : collectionEntryMetadata(context, record, entryCount),
      leading: PikoIconButton(
        semanticLabel: copy.text('common.back'),
        icon: const PikoIcon(PikoIconName.arrowLeft),
        variant: PikoButtonVariant.ghost,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleContent: _lastReadyCollection == null
          ? null
          : _nameHeading(_lastReadyCollection!, ready),
      titleMargin: _renaming ? pikoDesign.dimension('spacing.2') : null,
      actions: [
        if (ready)
          PikoIconButton(
            key: const ValueKey('collection-menu'),
            semanticLabel: copy.text('r2.more'),
            icon: const PikoIcon(PikoIconName.ellipsis),
            variant: PikoButtonVariant.neutral,
            large: true,
            focusNode: _menuFocus,
            onPressed:
                _deleteRequest != null ||
                    _openingEntry ||
                    _learningBusy ||
                    _renameRequest != null
                ? null
                : _openMenu,
          ),
      ],
    );
    if (widget.queryBinding != null) {
      return heading(widget.queryBinding!.snapshot?.allEntries.length);
    }
    final repository = widget.vocabularyRepository;
    if (record == null || repository == null) return heading(null);
    return CollectionEntryCount(
      repository: repository,
      collectionId: record.id,
      builder: (_, count) => heading(count),
    );
  }
}
