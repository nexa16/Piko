import 'data/ai/ai_connection_controller.dart';
import 'platform/ai_credential_vault.dart';
import 'features/ai/ai_entry_session_coordinator.dart';
import 'data/ai/ai_contract.dart';
import 'data/ai/managed_ai_provider.dart';
import 'data/local/sqlite_ai_service.dart';
import 'features/ai/ai_page.dart';
import 'dart:async';
import 'package:drift/drift.dart' show LazyDatabase;
import 'package:flutter/material.dart';
import 'data/local/sqlite_full_export_service.dart';
import 'data/collections_repository.dart';
import 'data/local/database_connection.dart';
import 'data/local/piko_database.dart';
import 'data/local/sqlite_collections_repository.dart';
import 'data/local/sqlite_vocabulary_repository.dart';
import 'data/local/sqlite_vocabulary_deletion.dart';
import 'data/local/sqlite_learning_repository.dart';
import 'data/local/sqlite_settings_repository.dart';
import 'data/local/sqlite_vocabulary_json_service.dart';
import 'data/local/sqlite_collection_query.dart';
import 'data/local/sqlite_categories_repository.dart';
import 'features/interchange/vocabulary_json_page.dart';
import 'platform/vocabulary_json_platform.dart';
import 'data/learning_item.dart';
import 'data/review_due_membership.dart';
import 'data/settings_repository.dart';
import 'features/collections/collection_review_count.dart';
import 'features/collections/collection_query_binding.dart';
import 'features/collections/collection_view_scope.dart';
import 'features/learning/due_learning_session.dart';
import 'features/collections/collections_home.dart';
import 'features/entry/entry_session_controller.dart';
import 'features/entry/entry_session_route.dart';
import 'features/vocabulary/collection_vocabulary_mutations.dart';
import 'features/settings/app_language_controller.dart';
import 'features/settings/preferred_direction_controller.dart';
import 'features/settings/settings_route.dart';
import 'features/settings/collection_settings_overview.dart';
import 'features/collections/collection_detail.dart';
import 'shared/interface_locale.dart';
import 'shared/copy_scope.dart';
import 'ui/components/piko_button.dart';
import 'ui/components/piko_page.dart';
import 'ui/piko_theme.dart';
import 'speed_runtime.dart';
import 'data/local/sqlite_statistics_repository.dart';
import 'features/statistics/statistics_binding.dart';
import 'features/statistics/statistics_page.dart';
import 'platform/device_clock_changes.dart';

/// Owns private runtime storage. Injected feature repositories remain caller-owned.
class PikoRuntime extends StatefulWidget {
  const PikoRuntime({
    super.key,
    this.databaseFactory,
    this.settingsRepositoryFactory,
    this.jsonPlatform,
    this.aiProvider,
  });

  /// Test/composition injection; the runtime owns the returned database.
  final PikoDatabase Function()? databaseFactory;

  /// Composition seam; uses the same runtime-owned database, never a second store.
  final SettingsRepository Function(PikoDatabase)? settingsRepositoryFactory;
  final VocabularyJsonPlatform? jsonPlatform;
  final AiProvider? aiProvider;
  @override
  State<PikoRuntime> createState() => _PikoRuntimeState();
}

class _PikoRuntimeState extends State<PikoRuntime> {
  late final database =
      widget.databaseFactory?.call() ??
      PikoDatabase(LazyDatabase(() async => openPikoDatabase()));
  late final collections = SqliteCollectionsRepository(
    database,
    interfaceLanguage: () => _language?.locale.value.languageCode ?? 'en',
  );
  late final vocabulary = SqliteVocabularyRepository(
    database,
    ai: pikoAiEnabled ? AiSupport(aiService, aiProvider) : null,
  );
  late final aiService = SqliteAiService(database);
  late final aiAccess = AiConnectionController(
    configuration: AiConnectionConfiguration.environment,
    vault: const AndroidAiCredentialVault(),
    gateway: SupabaseAiAuthGateway(AiConnectionConfiguration.environment),
  );
  late final aiProvider =
      widget.aiProvider ??
      ManagedAiProvider(
        endpoint: AiConnectionConfiguration.environment.available
            ? Uri.tryParse(AiConnectionConfiguration.environment.endpoint)
            : null,
        publishableKey: AiConnectionConfiguration.environment.publishableKey,
        access: aiAccess,
      );
  Widget _aiPage(BuildContext context, CollectionRecord collection) =>
      !pikoAiEnabled
      ? const SizedBox.shrink()
      : AiPage(
          service: aiService,
          provider: aiProvider,
          collectionId: collection.id,
          collectionName: collection.name,
          registerPending: trackWrites,
        );

  late final categories = SqliteCategoriesRepository(database);
  late final learning = SqliteLearningRepository(database);
  late final trash = SqliteVocabularyDeletionService(database);
  late final jsonService = SqliteVocabularyJsonService(database);
  late final fullExportService = SqliteFullExportService(database);
  late final collectionQuery = SqliteCollectionQueryService(database);
  StatisticsBinding? _statistics;
  late final speedRuntime = PikoSpeedRuntime(
    learning: learning,
    clock: database.clock,
    onPendingWrites: trackWrites,
  );
  late final jsonPlatform =
      widget.jsonPlatform ?? SystemVocabularyJsonPlatform();
  late final settings =
      widget.settingsRepositoryFactory?.call(database) ??
      SqliteSettingsRepository(database);
  AppLanguageController? _language;
  final _languageBinding = ValueNotifier<AppLanguageController?>(null);
  late final _direction = PreferredDirectionController(
    repository: settings,
    registerPending: trackWrites,
  );
  final _directionBinding = ValueNotifier<PreferredDirectionController?>(null);
  bool _directionStarted = false;
  Future<void> _languageDependencies = Future<void>.value();
  bool _bootstrapped = false;
  late final _collectionScopes = CollectionViewScopes(
    repository: settings,
    registerPending: trackWrites,
  );
  final _collectionBindings = <String, CollectionQueryBinding>{};

  CollectionQueryBinding _collectionBinding(String id) =>
      _collectionBindings.putIfAbsent(
        id,
        () => CollectionQueryBinding(
          collectionId: id,
          service: collectionQuery,
          scope: _collectionScopes.forCollection(id),
          invalidations: database.tableUpdates().map((_) {}),
          clock: database.clock,
          onPendingWrites: trackWrites,
        ),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_directionStarted) {
      _directionStarted = true;
      scheduleMicrotask(() {
        if (!mounted) return;
        _directionBinding.value = _direction;
        _direction.load();
        setState(() {
          _statistics = StatisticsBinding(
            repository: SqliteStatisticsRepository(database),
            clock: database.clock,
            calendar: database.learningDayCalendar,
            clockChanges: deviceClockChanges(),
            onPendingWrites: trackWrites,
          );
        });
      });
    }
    final locale = InterfaceLocaleScope.of(context);
    if (_language?.locale == locale) return;
    final previous = _language;
    // Keep admitted work transitively even when an intermediate binding is
    // replaced before its deferred load begins.
    _languageDependencies = Future.wait<void>([
      _languageDependencies,
      if (previous != null) previous.awaitPending,
    ]);
    final after = _languageDependencies;
    previous?.removeListener(_languageChanged);
    previous?.dispose();
    final binding = AppLanguageController(
      repository: settings,
      locale: locale,
      registerPending: trackWrites,
    );
    _language = binding;
    binding.addListener(_languageChanged);
    // Defer notification of the app-wide controller until after this build.
    scheduleMicrotask(() {
      if (mounted && identical(_language, binding)) {
        _languageBinding.value = binding;
        binding.load(after: after);
      }
    });
  }

  void _languageChanged() {
    if (!mounted) return;
    setState(() {
      _bootstrapped |= _language!.ready;
    });
  }

  void _openSettings() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsRoute(
          collectionsBuilder: (_) => CollectionSettingsOverview(
            repository: collections,
            settingsBuilder: (_, collection) => CollectionDetail(
              repository: collections,
              collectionId: collection.id,
              settingsOnly: true,
              vocabularyRepository: vocabulary,
              categoriesRepository: categories,
              learningReset: learning,
              vocabularyTrash: trash,
              interchangeBuilder: _interchange,
              aiBuilder: pikoAiEnabled ? _aiPage : null,
              onPendingVocabularyWrites: trackWrites,
            ),
          ),
          binding: _languageBinding,
          directionBinding: _directionBinding,
          settingsRepository: settings,
          registerPending: trackWrites,
          fullExportService: fullExportService,
          fullExportPlatform: widget.jsonPlatform,
        ),
      ),
    );
  }

  void _openStatistics() {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _statistics == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatisticsPage(binding: _statistics!),
      ),
    );
  }

  final pendingVocabularyWrites = <Future<void>>{};
  void trackWrites(Future<void> future) {
    final tracked = future.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    pendingVocabularyWrites.add(tracked);
    unawaited(
      tracked.whenComplete(() => pendingVocabularyWrites.remove(tracked)),
    );
  }

  Future<void> closeDatabase() async {
    // Sibling route disposal registers its accepted editor queues synchronously
    // during the same unmount traversal, before this microtask continues.
    await Future<void>.value();
    while (pendingVocabularyWrites.isNotEmpty) {
      await Future.wait(pendingVocabularyWrites.toList());
    }
    await database.close();
  }

  final _jsonDrafts = <String, VocabularyJsonDraft>{};
  Widget _interchange(BuildContext context, CollectionRecord collection) =>
      VocabularyJsonPage(
        collection: collection,
        service: jsonService,
        platform: jsonPlatform,
        onPendingWrites: trackWrites,
        asDialog: true,
        draft: _jsonDrafts.putIfAbsent(collection.id, VocabularyJsonDraft.new),
      );

  EntrySessionResources _entrySession(String collectionId) {
    final deletion = SqliteVocabularyDeletionService(database);
    late final EntrySessionController session;
    final coordinator = pikoAiEnabled
        ? AiEntrySessionCoordinator(
            support: vocabulary.ai!,
            repository: vocabulary,
            session: () => session,
          )
        : null;
    session = EntrySessionController(
      collectionId: collectionId,
      repository: vocabulary,
      deletionService: deletion,
      clock: database.clock,
      confirmDraft: coordinator?.confirm,
    );
    return EntrySessionResources(
      learningReset: learning,
      aiCoordinator: coordinator,
      categoriesRepository: categories,
      onPendingWrites: trackWrites,
      session: session,
      deletionService: deletion,
    );
  }

  Future<DueLearningSession> _reviewSession(
    String collectionId,
    LearningDirection direction,
  ) async {
    final source = await learning.forCollection(
      collectionId: collectionId,
      direction: direction,
    );
    return DueLearningSession.start(
      source: source,
      cutoff: database.clock.now().toUtc(),
      clock: database.clock,
      onPendingWrites: trackWrites,
      presentationActive: false,
    );
  }

  Future<DueLearningSession> _selectedReviewSession(
    String collectionId,
    LearningDirection direction,
    Set<String> entryIds,
  ) async {
    final source = await learning.forCollection(
      collectionId: collectionId,
      direction: direction,
      entryIds: Set.unmodifiable(entryIds),
    );
    return DueLearningSession.start(
      source: source,
      cutoff: database.clock.now().toUtc(),
      clock: database.clock,
      onPendingWrites: trackWrites,
      presentationActive: false,
    );
  }

  Future<DueLearningSession> _detailReviewSession(
    String collectionId,
    LearningDirection direction,
  ) async {
    final scope = _collectionScopes.forCollection(collectionId);
    final snapshot = await collectionQuery.query(
      collectionId: collectionId,
      at: database.clock.now().toUtc(),
      search: scope.search,
      filters: scope.filters,
    );
    final source = await learning.forCollection(
      collectionId: collectionId,
      direction: direction,
      entryIds: snapshot.entries.map((entry) => entry.id).toSet(),
    );
    return DueLearningSession.start(
      source: source,
      cutoff: database.clock.now().toUtc(),
      clock: database.clock,
      onPendingWrites: trackWrites,
      presentationActive: false,
    );
  }

  Future<ReviewDueMembershipSnapshot> _reviewDueMemberships({
    required String collectionId,
    required DateTime at,
  }) async {
    final snapshot = await collectionQuery.query(
      collectionId: collectionId,
      at: at,
    );
    return ReviewDueMembershipSnapshot(
      memberships: snapshot.directions.values.expand(
        (direction) => direction.review,
      ),
      nextChangeAt: snapshot.nextChangeAt,
    );
  }

  CollectionVocabularyMutations _collectionMutations(String id) =>
      CollectionVocabularyMutations(
        collectionId: id,
        service: SqliteVocabularyDeletionService(database),
        clock: database.clock,
      );

  @override
  void dispose() {
    if (widget.aiProvider == null && pikoAiEnabled) {
      aiProvider.close();
      aiAccess.dispose();
    }
    _statistics?.dispose();
    trash.dispose();
    for (final binding in _collectionBindings.values) {
      binding.dispose();
    }
    _collectionScopes.dispose();
    _language?.removeListener(_languageChanged);
    _language?.dispose();
    _languageBinding.dispose();
    if (_directionStarted) _direction.dispose();
    _directionBinding.dispose();
    unawaited(closeDatabase());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      final copy = PikoCopyScope.of(context);
      final binding = _language!;
      return Scaffold(
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.text(
                  binding.error == null
                      ? 'settings.loading'
                      : binding.error is VocabularyMigrationCollision
                      ? 'storage.migrationCollision'
                      : 'settings.loadFailed',
                ),
              ),
              if (binding.error != null)
                PikoButton(
                  label: copy.text('action.retry'),
                  onPressed: binding.pending
                      ? null
                      : () {
                          if (mounted && identical(_language, binding)) {
                            binding.load();
                          }
                        },
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _language!.ready
            ? const SizedBox.shrink()
            : Material(
                child: Padding(
                  padding: EdgeInsets.all(pikoDesign.dimension('spacing.3')),
                  child: _replacementLanguageStatus(context),
                ),
              ),
        Expanded(
          child: CollectionsHome(
            learningReset: learning,
            vocabularyTrash: trash,
            repository: collections,
            entrySessionFactory: _entrySession,
            interchangeBuilder: _interchange,
            aiBuilder: pikoAiEnabled ? _aiPage : null,
            vocabularyRepository: vocabulary,
            categoriesRepository: categories,
            onPendingVocabularyWrites: trackWrites,
            vocabularyMutationsFactory: _collectionMutations,
            reviewSessionFactory: _reviewSession,
            detailReviewSessionFactory: _detailReviewSession,
            speedSessionFactory: speedRuntime.prepare,
            selectedSpeedSessionFactory: speedRuntime.prepareSelected,
            selectedReviewSessionFactory: _selectedReviewSession,
            queryBindingFactory: _collectionBinding,
            reviewMembershipLoader: _reviewDueMemberships,
            reviewCountPolicy: CollectionReviewCountPolicy.dueDirectionCards,
            reviewCountClock: database.clock,
            onOpenSettings: _openSettings,
            directionBinding: _directionBinding,
            statisticsBinding: _statistics,
            onOpenStatistics: _openStatistics,
          ),
        ),
      ],
    );
  }

  Widget _replacementLanguageStatus(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final binding = _language!;
    return Column(
      children: [
        Text(
          copy.text(
            binding.error == null ? 'settings.loading' : 'settings.loadFailed',
          ),
        ),
        if (binding.error != null)
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: () {
              if (mounted &&
                  identical(_language, binding) &&
                  !binding.pending) {
                binding.load();
              }
            },
          ),
      ],
    );
  }
}
