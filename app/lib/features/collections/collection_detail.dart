import 'learning_help.dart';
import 'collection_compact_action.dart';
import '../../ui/components/piko_collapsing_header.dart';
import 'collection_view_controls.dart';
import 'collection_hint_settings.dart';
import '../../ui/components/piko_form.dart';
import '../interchange/vocabulary_json_page.dart';
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
import '../../ui/components/piko_sleeping.dart';
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
import '../speed/speed_completion_notice.dart';
import '../speed/selected_speed_launch.dart';
import '../speed/speed_setup_dialog.dart'
    show SpeedSessionFactory, SelectedSpeedSessionFactory;
import '../categories/category_management.dart';
import '../categories/category_settings_page.dart';
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
    this.settingsOnly = false,
    super.key,
  }) : assert((reviewMembershipLoader == null) == (reviewCountPolicy == null));
  final bool settingsOnly;
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
  final _expandedHeaderFocus = FocusNode();
  final _expandedReviewFocus = FocusNode();
  final _expandedSpeedFocus = FocusNode();
  final _backFocus = FocusNode();
  final _compactBackFocus = FocusNode();
  final _compactMenuFocus = FocusNode();
  final _compactReviewFocus = FocusNode();
  final _compactSpeedFocus = FocusNode();
  final _expandedNoticeFocus = FocusNode();
  final _compactNoticeFocus = FocusNode();
  var _reviewLaunchKey = GlobalKey<ReviewLaunchState>();
  var _speedLaunchKey = GlobalKey<SpeedLaunchState>();
  Object? _launchKeysIdentity;
  bool _headerCompact = false;

  void _headerChanged(bool compact) {
    if (_headerCompact == compact) return;
    FocusNode? next;
    FocusNode? nextGroup;
    if (compact) {
      if (_expandedReviewFocus.hasFocus) {
        next = _compactReviewFocus;
      } else if (_expandedSpeedFocus.hasFocus) {
        next = _compactSpeedFocus;
      } else if (_menuFocus.hasFocus) {
        next = _compactMenuFocus;
      } else if (_expandedNoticeFocus.hasFocus) {
        next = _compactNoticeFocus;
      } else if (_expandedHeaderFocus.hasFocus) {
        next = _compactBackFocus;
      }
    } else if (_compactMenuFocus.hasFocus) {
      next = _menuFocus;
    } else if (_compactNoticeFocus.hasFocus) {
      next = _expandedNoticeFocus;
    } else if (_compactBackFocus.hasFocus ||
        _compactReviewFocus.hasFocus ||
        _compactSpeedFocus.hasFocus) {
      // The expanded launch may have disappeared after a count refresh.
      nextGroup = _compactReviewFocus.hasFocus
          ? _expandedReviewFocus
          : _compactSpeedFocus.hasFocus
          ? _expandedSpeedFocus
          : null;
      next = _backFocus;
    }
    setState(() => _headerCompact = compact);
    if (next != null) {
      final target = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          (nextGroup?.traversalDescendants.firstOrNull ?? target)
              .requestFocus();
        }
      });
    }
  }

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

  bool _settingsBusy = false;

  Future<void> _openMenu() async {
    final record = _currentCollection;
    if (record == null ||
        _menuRequest != null ||
        !_queryControlsAvailable ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final request = Object(), identity = _identity;
    final opener = FocusManager.instance.primaryFocus;
    setState(() => _menuRequest = request);
    _writeBarrier.freeze();
    try {
      await _writeBarrier.drain();
      await _mutations?.awaitPending();
      if (!mounted ||
          identity != _identity ||
          !identical(_menuRequest, request)) {
        return;
      }
      final owned = MaterialPageRoute<bool>(
        builder: (_) => CollectionDetail(
          repository: widget.repository,
          collectionId: record.id,
          vocabularyRepository: widget.vocabularyRepository,
          onPendingVocabularyWrites: widget.onPendingVocabularyWrites,
          interchangeBuilder: widget.interchangeBuilder,
          categoriesRepository: widget.categoriesRepository,
          categoryManagementBuilder: widget.categoryManagementBuilder,
          settingsOnly: true,
        ),
      );
      _menuDialog = owned;
      final deleted = await Navigator.of(context).push(owned);
      if (!mounted ||
          identity != _identity ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final remaining = deleted == true
          ? null
          : await widget.repository.watchById(record.id).first;
      if (mounted &&
          identity == _identity &&
          remaining == null &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted &&
          identity == _identity &&
          identical(_menuRequest, request)) {
        _menuDialog = null;
        _writeBarrier.release();
        setState(() => _menuRequest = null);
        if (ModalRoute.of(context)?.isCurrent == true) {
          if (opener?.context?.mounted == true && opener!.canRequestFocus) {
            opener.requestFocus();
          } else if (_menuFocus.context != null) {
            _menuFocus.requestFocus();
          } else {
            _compactMenuFocus.requestFocus();
          }
        }
      }
    }
  }

  Widget _settingsContent(
    CollectionRecord record, {
    bool ready = true,
    Object? loadError,
  }) {
    final copy = PikoCopyScope.of(context);
    final owner = _identity;
    bool available() =>
        mounted &&
        owner == _identity &&
        ready &&
        !_settingsBusy &&
        _currentCollection?.id == record.id &&
        ModalRoute.of(context)?.isCurrent == true;
    return PopScope(
      canPop: !_settingsBusy && !_deleting,
      child: PikoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PikoHeading(
              title: copy.text('settingsPreview.collectionSettings'),
              subtitle:
                  '${record.name} · ${record.targetLanguage.code.toUpperCase()} · ${record.nativeLanguage.code.toUpperCase()}',
              leading: PikoIconButton(
                icon: const PikoIcon(PikoIconName.arrowLeft),
                semanticLabel: copy.text('common.back'),
                onPressed: _settingsBusy || _deleting
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ),
            if (loadError != null)
              CollectionLoadFailure(onRetry: () => setState(_watch)),
            if (widget.vocabularyRepository is VocabularyContentRepository &&
                widget.vocabularyRepository is CollectionHintPreferences)
              PikoFormSection(
                title: copy.text('settingsPreview.learning'),
                children: [
                  PikoFormFieldRow(
                    child: CollectionHintSettings(
                      collectionId: record.id,
                      enabled: ready,
                      repository:
                          widget.vocabularyRepository!
                              as VocabularyContentRepository,
                      onPendingWrites: widget.onPendingVocabularyWrites,
                      onBusyChanged: (busy) {
                        if (mounted && owner == _identity) {
                          setState(() => _settingsBusy = busy);
                        }
                      },
                    ),
                  ),
                ],
              ),
            if (widget.categoriesRepository != null ||
                widget.categoryManagementBuilder != null)
              PikoFormSection(
                title: copy.text('settingsPreview.management'),
                children: [
                  PikoNavigationRow(
                    title: copy.text('catPreview.categories'),
                    onTap: _settingsBusy || !ready
                        ? null
                        : () {
                            if (!available()) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    widget.categoryManagementBuilder != null
                                    ? CategoryManagementPage(
                                        collectionId: record.id,
                                        collectionName: record.name,
                                        managementBuilder:
                                            widget.categoryManagementBuilder,
                                      )
                                    : CategorySettingsPage(
                                        collectionId: record.id,
                                        collectionName: record.name,
                                        repository:
                                            widget.categoriesRepository!,
                                        onPendingWrites:
                                            widget.onPendingVocabularyWrites,
                                      ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            if (widget.interchangeBuilder != null)
              PikoFormSection(
                title: copy.text('settingsPreview.data'),
                children: [
                  PikoNavigationRow(
                    title: copy.text('json.importTab'),
                    onTap: available()
                        ? () {
                            if (available()) _openInterchange();
                          }
                        : null,
                  ),
                  PikoFormRow(
                    title: copy.text('json.exportTab'),
                    trailing: const PikoIcon(PikoIconName.upload),
                    onTap: available()
                        ? () {
                            if (available()) _openInterchange(export: true);
                          }
                        : null,
                  ),
                ],
              ),
            PikoFormGroup(
              children: [
                PikoFormRow(
                  key: const ValueKey('collection-menu-delete'),
                  title: copy.text('collection.delete'),
                  danger: true,
                  trailing: const PikoIcon(PikoIconName.trash),
                  onTap: !available() || _deleting
                      ? null
                      : () {
                          if (available()) _deleteCollection();
                        },
                ),
              ],
            ),
            if (_deleting) Text(copy.text('collection.deleting')),
            if (_deleteError != null)
              Text(
                copy.text('collection.deleteFailed'),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
          ],
        ),
      ),
    );
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
          categories: widget.categoriesRepository,
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
      if (mounted && route?.isCurrent == true) Navigator.of(context).pop(true);
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

  Future<void> _openInterchange({bool export = false}) async {
    final record = _currentCollection, builder = widget.interchangeBuilder;
    if (record == null || builder == null || _openingEntry || _learningBusy) {
      return;
    }
    setState(() => _openingEntry = true);
    try {
      await showPikoDialog<Object?>(
        context,
        builder: (context) {
          final page = builder(context, record);
          return page is VocabularyJsonPage
              ? page.withExportView(export)
              : page;
        },
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
              PikoNavigationRow(
                title: copy.text('entry.manualMethod'),
                onTap: () => Navigator.of(context).pop('manual'),
              ),
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              PikoNavigationRow(
                title: copy.text('json.importTab'),
                onTap: () => Navigator.of(context).pop('import'),
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
      _settingsBusy = false;
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
    for (final focus in [
      _expandedHeaderFocus,
      _expandedReviewFocus,
      _expandedSpeedFocus,
      _backFocus,
      _compactBackFocus,
      _compactMenuFocus,
      _compactReviewFocus,
      _compactSpeedFocus,
      _expandedNoticeFocus,
      _compactNoticeFocus,
    ]) {
      focus.dispose();
    }
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
    final launchIdentity = (widget.collectionId, _identity, _reviewIdentity);
    if (_launchKeysIdentity != launchIdentity) {
      _launchKeysIdentity = launchIdentity;
      _reviewLaunchKey = GlobalKey<ReviewLaunchState>();
      _speedLaunchKey = GlobalKey<SpeedLaunchState>();
    }
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
          if (widget.settingsOnly) {
            if (_lastReadyCollection != null) {
              return _settingsContent(
                _lastReadyCollection!,
                ready: ready,
                loadError: snapshot.error,
              );
            }
            return PikoPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PikoHeading(
                    title: copy.text('settingsPreview.collectionSettings'),
                    leading: PikoIconButton(
                      icon: const PikoIcon(PikoIconName.arrowLeft),
                      semanticLabel: copy.text('common.back'),
                      onPressed: _settingsBusy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  if (snapshot.hasError)
                    CollectionLoadFailure(onRetry: () => setState(_watch))
                  else
                    Text(
                      copy.text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'collection.loading'
                            : 'collection.notFound',
                      ),
                    ),
                ],
              ),
            );
          }
          final expandedHeader = Focus(
            focusNode: _expandedHeaderFocus,
            canRequestFocus: false,
            child: ColoredBox(
              color: pikoDesign.color('bg'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailHeading(record, ready),
                  if (_speedCompletedCount != null && ready)
                    SpeedCompletionNotice(
                      count: _speedCompletedCount!,
                      dismissFocusNode: _expandedNoticeFocus,
                      onDismiss: () =>
                          setState(() => _speedCompletedCount = null),
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
                  else if (snapshot.connectionState == ConnectionState.waiting)
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
                              categoriesRepository: widget.categoriesRepository,
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
                                    reviewIdentityForBuild == _reviewIdentity) {
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
                              categoriesRepository: widget.categoriesRepository,
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
                                    reviewIdentityForBuild == _reviewIdentity) {
                                  if (!busy) barrierForBuild.release();
                                  setState(() => _openingReview = busy);
                                }
                              },
                              presentation:
                                  ReviewLaunchPresentation.collectionCard,
                            ),
                    ),
                ],
              ),
            ),
          );
          final page = PikoPage.slivers(
            hasPinnedHeader: widget.queryBinding != null,
            safeAreaBottom: widget.queryBinding == null,
            key: ValueKey('collection-page-${widget.collectionId}'),
            interactionAnchor: _interactionAnchor,
            physics: const CollectionScrollPhysics(),
            slivers: [
              if (widget.queryBinding != null)
                PikoCollapsingHeader(
                  key: ValueKey('collection-header-${widget.collectionId}'),
                  expanded: expandedHeader,
                  compact: _compactHeading(
                    record,
                    ready,
                    collectionFailed: snapshot.hasError,
                    collectionMissing:
                        !snapshot.hasError &&
                        snapshot.connectionState == ConnectionState.active &&
                        record == null,
                  ),
                  keepExpanded: _renaming,
                  onCompactChanged: _headerChanged,
                )
              else
                SliverToBoxAdapter(child: expandedHeader),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                              action: Wrap(
                                alignment: WrapAlignment.end,
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
                  metadataError: snapshot.hasError ? snapshot.error : null,
                  onRetryMetadata: () => setState(_watch),
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
      final message = Text(
        copy.text(
          pending
              ? 'r2.pending'
              : binding.scope.restricted
              ? 'collection.filteredNoReview'
              : 'r2.caughtUp',
        ),
      );
      final sleeping =
          binding.ready &&
          !pending &&
          !_learningBusy &&
          _speedCompletedCount == null &&
          _directions.every(
            (direction) =>
                snapshot.directions[direction]!.newSpeedItems.isEmpty,
          );
      normal = !_directionReady
          ? const SizedBox.shrink()
          : sleeping
          ? Row(
              children: [
                Expanded(child: message),
                SizedBox(
                  width: pikoDesign.dimension(
                    'components.collectionReview.mascotGap',
                  ),
                ),
                const PikoSleeping(),
              ],
            )
          : message;
    } else if (widget.reviewSessionFactory != null) {
      normal = ReviewLaunch(
        key: _reviewLaunchKey,
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
        showMascot:
            _speedCompletedCount == null && _directionReady && binding.ready,
        dueCount: total,
        directionCounts: counts,
        availabilityChanges: binding,
        scopeIdentity: (binding, binding.scope.search, binding.scope.filters),
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
        Focus(
          focusNode: _expandedReviewFocus,
          canRequestFocus: false,
          child: normal,
        ),
        if (widget.speedSessionFactory != null)
          Padding(
            padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.2')),
            child: Focus(
              focusNode: _expandedSpeedFocus,
              canRequestFocus: false,
              child: SpeedLaunch(
                key: _speedLaunchKey,
                snapshot: snapshot,
                availabilityChanges: binding,
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
          ),
      ],
    );
  }

  Widget _compactHeading(
    CollectionRecord? record,
    bool ready, {
    required bool collectionFailed,
    required bool collectionMissing,
  }) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final binding = widget.queryBinding!;
    final snapshot = _heldLearningSnapshot ?? binding.snapshot;
    final resolved =
        ready && _directionReady && (binding.ready || _learningBusy);
    final directionError =
        !_directionReady && widget.directionBinding?.value?.error != null;
    final failed =
        collectionFailed ||
        collectionMissing ||
        binding.error != null ||
        directionError;
    final reviewCount = resolved
        ? _directions.fold<int>(
            0,
            (sum, direction) =>
                sum + (snapshot?.directions[direction]?.dueCount ?? 0),
          )
        : null;
    final speedCount = resolved
        ? _directions.fold<int>(
            0,
            (sum, direction) =>
                sum +
                (snapshot?.directions[direction]?.newSpeedItems.length ?? 0),
          )
        : null;
    final waiting =
        resolved &&
        reviewCount == 0 &&
        _directions.any(
          (direction) =>
              (snapshot?.directions[direction]?.pendingRetryCount ?? 0) > 0,
        );
    final enabled =
        resolved &&
        !_learningBusy &&
        !_openingEntry &&
        _deleteRequest == null &&
        _renameRequest == null &&
        _mutations?.isBusy != true;
    String label(bool speed, int? count) => count == null
        ? copy.text(
            failed ? 'collection.compactFailed' : 'collection.compactLoading',
            {'mode': copy.text(speed ? 'action.speed' : 'action.review')},
          )
        : !speed && waiting
        ? copy.text('collection.compactPending')
        : copy.text(
            speed ? 'collection.compactSpeed' : 'collection.compactReview',
            {'count': count},
          );
    final total = snapshot?.allEntries.length;
    return ColoredBox(
      color: d.color('bg'),
      child: Padding(
        padding: EdgeInsets.only(bottom: d.dimension('spacing.2')),
        child: Column(
          key: const ValueKey('collection-compact-header'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PikoIconButton(
                  key: const ValueKey('collection-compact-back'),
                  focusNode: _compactBackFocus,
                  semanticLabel: copy.text('common.back'),
                  icon: const PikoIcon(PikoIconName.arrowLeft),
                  variant: PikoButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                PikoIconButton(
                  key: const ValueKey('collection-compact-menu'),
                  focusNode: _compactMenuFocus,
                  semanticLabel: copy.text(
                    'settingsPreview.collectionSettings',
                  ),
                  icon: const PikoIcon(PikoIconName.settings),
                  variant: PikoButtonVariant.ghost,
                  large: true,
                  onPressed:
                      ready &&
                          !_learningBusy &&
                          !_openingEntry &&
                          _deleteRequest == null &&
                          _renameRequest == null
                      ? _openMenu
                      : null,
                ),
              ],
            ),
            SizedBox(height: d.dimension('spacing.1')),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      record?.name ??
                          _lastReadyCollection?.name ??
                          copy.text('collection.title'),
                      style: TextStyle(
                        fontSize: d.dimension(
                          'components.collectionHeader.titleSize',
                        ),
                        fontWeight: d.weight('typography.titleWeight'),
                        height: d.dimension(
                          'components.collectionHeader.titleLineHeight',
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: d.dimension('spacing.2')),
                Expanded(
                  child: CollectionCompactAction(
                    key: const ValueKey('collection-review-compact'),
                    label: label(false, reviewCount),
                    count: reviewCount?.toString() ?? (failed ? '!' : '…'),
                    focusNode: _compactReviewFocus,
                    onPressed:
                        enabled &&
                            (reviewCount ?? 0) > 0 &&
                            widget.reviewSessionFactory != null
                        ? () => _reviewLaunchKey.currentState?.openMerged()
                        : null,
                  ),
                ),
                SizedBox(width: d.dimension('spacing.2')),
                Expanded(
                  child: CollectionCompactAction(
                    key: const ValueKey('collection-speed-compact'),
                    speed: true,
                    label: label(true, speedCount),
                    count: speedCount?.toString() ?? (failed ? '!' : '…'),
                    focusNode: _compactSpeedFocus,
                    onPressed:
                        enabled &&
                            (speedCount ?? 0) > 0 &&
                            widget.speedSessionFactory != null
                        ? () => _speedLaunchKey.currentState?.openMerged()
                        : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: d.dimension('spacing.1')),
            Text(
              total == null
                  ? copy.text('collection.loading')
                  : copy.text(total == 1 ? 'common.entry' : 'common.entries', {
                      'count': total,
                    }),
              style: TextStyle(
                fontSize: d.dimension('typography.small'),
                color: d.color('muted'),
              ),
            ),
            if (_speedCompletedCount != null && ready)
              SpeedCompletionNotice(
                count: _speedCompletedCount!,
                showArtwork: false,
                dismissFocusNode: _compactNoticeFocus,
                onDismiss: () => setState(() => _speedCompletedCount = null),
              ),
            if (!resolved)
              Text(
                copy.text(
                  collectionMissing
                      ? 'collection.notFound'
                      : collectionFailed
                      ? 'collection.loadFailed'
                      : failed
                      ? 'collection.reviewLoadFailed'
                      : 'collection.reviewLoading',
                ),
              ),
            if (failed && !collectionMissing)
              Align(
                alignment: Alignment.centerLeft,
                child: PikoButton(
                  label: copy.text('action.retry'),
                  variant: PikoButtonVariant.ghost,
                  onPressed: binding.loading
                      ? null
                      : () {
                          if (collectionFailed) setState(_watch);
                          if (directionError) {
                            widget.directionBinding?.value?.retry();
                          }
                          if (binding.error != null) binding.refresh();
                        },
                ),
              ),
            if (waiting) Text(copy.text('r2.pending')),
            if (_reviewLaunchKey.currentState?.hasLaunchError == true ||
                _speedLaunchKey.currentState?.hasLaunchError == true)
              Text(
                copy.text('learn.prepareFailed'),
                style: TextStyle(color: d.color('danger')),
              ),
          ],
        ),
      ),
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
        focusNode: _backFocus,
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
            semanticLabel: copy.text('settingsPreview.collectionSettings'),
            icon: const PikoIcon(PikoIconName.settings),
            variant: PikoButtonVariant.ghost,
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
