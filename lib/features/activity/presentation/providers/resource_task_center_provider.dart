import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_action_result_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/resource_task_center_state.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'resource_task_center_provider.g.dart';

@Riverpod(retry: kNoAsyncNotifierRetry)
class ResourceTaskCenter extends _$ResourceTaskCenter
    with AsyncNotifierDisposeGuardMixin<ResourceTaskCenterState> {
  static const int _pageSize = 20;
  static const String kMediaThumbnailTaskKey = 'media_thumbnail_generation';
  static const int maxBatchResetCount = 200;
  late final DebouncedLatestRequest _filterRequests = DebouncedLatestRequest();

  ResourceTaskCenterState get current =>
      state.value ?? ResourceTaskCenterState.initial;

  @override
  Future<ResourceTaskCenterState> build() async {
    attachDisposeGuard();
    ref.onDispose(_filterRequests.dispose);
    return _loadInitialState();
  }

  Future<ResourceTaskCenterState> _loadInitialState() async {
    try {
      final definitions = await ref
          .read(activityApiProvider)
          .getResourceTaskDefinitions();
      if (isDisposed) return ResourceTaskCenterState.initial;
      if (definitions.isEmpty) {
        return ResourceTaskCenterState.initial.copyWith(initialized: true);
      }
      final key = definitions.first.taskKey;
      var next = ResourceTaskCenterState.initial.copyWith(
        initialized: true,
        definitions: definitions,
        activeTaskKey: key,
        buckets: <String, ResourceTaskRecordsBucketState>{
          key: const ResourceTaskRecordsBucketState(isLoading: true),
        },
      );
      try {
        final response = await _fetchRecordsPage(
          key,
          page: 1,
          bucket: next.buckets[key]!,
        );
        next = _replaceBucket(
          next,
          key,
          _initialLoadSuccess(next.buckets[key]!, response),
        );
      } catch (error) {
        next = _replaceBucket(
          next,
          key,
          next.buckets[key]!.copyWith(
            isLoading: false,
            loadErrorMessage: apiErrorMessage(
              error,
              fallback: '资源任务记录加载失败，请稍后重试',
            ),
          ),
        );
      }
      return next;
    } catch (error) {
      return ResourceTaskCenterState.initial.copyWith(
        initialErrorMessage: apiErrorMessage(
          error,
          fallback: '资源任务定义加载失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> retryInitialize() async {
    state = const AsyncLoading<ResourceTaskCenterState>();
    final next = await _loadInitialState();
    if (!isDisposed) state = AsyncData(next);
  }

  Future<void> refreshDefinitions() async {
    if (current.isRefreshingDefinitions) return;
    state = AsyncData(
      current.copyWith(
        isRefreshingDefinitions: true,
        definitionsRefreshErrorMessage: null,
      ),
    );
    try {
      final definitions = await ref
          .read(activityApiProvider)
          .getResourceTaskDefinitions();
      if (isDisposed) return;
      var key = current.activeTaskKey;
      if (key != null && definitions.every((item) => item.taskKey != key)) {
        key = definitions.isEmpty ? null : definitions.first.taskKey;
      }
      key ??= definitions.isEmpty ? null : definitions.first.taskKey;
      state = AsyncData(
        current.copyWith(
          definitions: definitions,
          activeTaskKey: key,
          isRefreshingDefinitions: false,
        ),
      );
      if (key != null && !_bucketFor(key).hasLoadedOnce) {
        await _loadFirstPage(key);
      }
    } catch (error) {
      if (isDisposed) return;
      state = AsyncData(
        current.copyWith(
          isRefreshingDefinitions: false,
          definitionsRefreshErrorMessage: apiErrorMessage(
            error,
            fallback: '任务定义刷新失败，请稍后重试',
          ),
        ),
      );
    }
  }

  Future<void> selectTaskKey(String taskKey) async {
    if (current.activeTaskKey == taskKey) return;
    final bucket = _bucketFor(taskKey);
    state = AsyncData(
      _replaceBucket(
        current.copyWith(
          activeTaskKey: taskKey,
          selectionMode: false,
          selectedResourceIds: const <int>{},
        ),
        taskKey,
        bucket,
      ),
    );
    if (!bucket.hasLoadedOnce && !bucket.isLoading) {
      await _loadFirstPage(taskKey);
    }
  }

  Future<void> applyFilter(ResourceTaskRecordFilterState next) {
    final key = current.activeTaskKey;
    if (key == null) return Future<void>.value();
    final bucket = _bucketFor(key);
    if (bucket.filter == next) return Future<void>.value();
    final requestId = bucket.loadRequestId + 1;
    state = AsyncData(
      _replaceBucket(
        current.copyWith(
          selectionMode: false,
          selectedResourceIds: const <int>{},
        ),
        key,
        bucket.copyWith(
          filter: next,
          loadRequestId: requestId,
          isLoading: false,
          isLoadingMore: false,
          loadErrorMessage: null,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    return _filterRequests.schedule(
      (filterRequestId) =>
          _loadFilteredFirstPage(key, requestId, filterRequestId),
    );
  }

  void enterSelectionMode() {
    if (!supportsBatchReset || current.selectionMode) return;
    state = AsyncData(current.copyWith(selectionMode: true));
  }

  void exitSelectionMode() {
    if (!current.selectionMode && current.selectedResourceIds.isEmpty) return;
    state = AsyncData(
      current.copyWith(
        selectionMode: false,
        selectedResourceIds: const <int>{},
      ),
    );
  }

  bool toggleRecordSelection(int resourceId) {
    final selected = <int>{...current.selectedResourceIds};
    if (selected.remove(resourceId)) {
      state = AsyncData(current.copyWith(selectedResourceIds: selected));
      return true;
    }
    if (selected.length >= maxBatchResetCount) return false;
    selected.add(resourceId);
    state = AsyncData(current.copyWith(selectedResourceIds: selected));
    return true;
  }

  void toggleSelectAllVisibleFailed() {
    final visibleIds = _visibleFailedResourceIds();
    if (visibleIds.isEmpty) return;
    final selected = <int>{...current.selectedResourceIds};
    if (visibleIds.every(selected.contains)) {
      selected.removeAll(visibleIds);
    } else {
      selected.addAll(visibleIds);
    }
    state = AsyncData(current.copyWith(selectedResourceIds: selected));
  }

  Future<ResourceTaskActionResultDto?> resetSelectedFailed() async {
    final now = current;
    if (now.isResetting ||
        now.activeTaskKey != kMediaThumbnailTaskKey ||
        now.selectedResourceIds.isEmpty) {
      return null;
    }
    final ids = now.selectedResourceIds.toList(growable: false);
    state = AsyncData(now.copyWith(isResetting: true));
    try {
      final result = await ref
          .read(activityApiProvider)
          .applyResourceTaskAction(
            taskKey: kMediaThumbnailTaskKey,
            action: 'reset_retry_budget',
            resourceIds: ids,
          );
      if (isDisposed) return result;
      final resetIds = result.acceptedResourceIds.toSet();
      var next = _applySuccessfulReset(current, resetIds, result.acceptedCount);
      final keepSelected = next.selectedResourceIds
          .where((id) => !resetIds.contains(id))
          .toSet();
      next = next.copyWith(
        isResetting: false,
        selectedResourceIds: keepSelected,
        selectionMode: keepSelected.isNotEmpty,
      );
      state = AsyncData(next);
      return result;
    } catch (_) {
      if (!isDisposed) {
        state = AsyncData(current.copyWith(isResetting: false));
      }
      rethrow;
    }
  }

  Future<String> applyRecordAction({
    required String taskKey,
    required String action,
    required List<int> resourceIds,
  }) async {
    final result = await ref
        .read(activityApiProvider)
        .applyResourceTaskAction(
          taskKey: taskKey,
          action: action,
          resourceIds: resourceIds,
        );
    final accepted = result.acceptedCount;
    final skipped = result.skippedCount;
    await Future.wait(<Future<void>>[refreshRecords(), refreshDefinitions()]);
    final suffix = result.taskRunId != null
        ? '，已生成任务 #${result.taskRunId}'
        : '';
    return skipped == 0
        ? '已受理 $accepted 项$suffix'
        : '已受理 $accepted 项、跳过 $skipped 项$suffix';
  }

  Future<void> refreshRecords() async {
    final key = current.activeTaskKey;
    if (key == null) return;
    final bucket = _bucketFor(key);
    final requestId = bucket.loadRequestId + 1;
    state = AsyncData(
      _replaceBucket(
        current,
        key,
        bucket.copyWith(
          loadRequestId: requestId,
          isLoading: false,
          isLoadingMore: false,
          loadErrorMessage: null,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    await _filterRequests.runNow(
      (filterRequestId) =>
          _loadFilteredFirstPage(key, requestId, filterRequestId),
    );
  }

  Future<void> loadMoreRecords() async {
    final key = current.activeTaskKey;
    if (key == null) return;
    final bucket = _bucketFor(key);
    if (!bucket.hasMore ||
        bucket.isLoading ||
        bucket.isLoadingMore ||
        !bucket.filterUpdate.isIdle ||
        !bucket.hasLoadedOnce) {
      return;
    }
    final requestId = bucket.loadRequestId + 1;
    state = AsyncData(
      _replaceBucket(
        current,
        key,
        bucket.copyWith(
          loadRequestId: requestId,
          isLoadingMore: true,
          loadMoreErrorMessage: null,
        ),
      ),
    );
    try {
      final response = await _fetchRecordsPage(
        key,
        page: bucket.nextPage,
        bucket: bucket,
      );
      if (_isStaleRequest(key, requestId)) return;
      final latest = _bucketFor(key);
      final records = <ResourceTaskRecordDto>[
        ...latest.records,
        ...response.items,
      ];
      state = AsyncData(
        _replaceBucket(
          current,
          key,
          latest.copyWith(
            records: records,
            nextPage: response.page + 1,
            hasMore:
                response.items.length >= response.pageSize &&
                records.length < response.total,
            isLoadingMore: false,
          ),
        ),
      );
    } catch (error) {
      if (_isStaleRequest(key, requestId)) return;
      state = AsyncData(
        _replaceBucket(
          current,
          key,
          _bucketFor(key).copyWith(
            isLoadingMore: false,
            loadMoreErrorMessage: apiErrorMessage(
              error,
              fallback: '加载更多失败，请稍后重试',
            ),
          ),
        ),
      );
    }
  }

  void openDetail(ResourceTaskRecordDto record) {
    if (current.selectedRecord?.recordKey == record.recordKey) return;
    state = AsyncData(current.copyWith(selectedRecord: record));
  }

  void closeDetail() {
    if (current.selectedRecord == null) return;
    state = AsyncData(current.copyWith(selectedRecord: null));
  }

  Future<void> _loadFirstPage(String taskKey) async {
    _filterRequests.cancel();
    final bucket = _bucketFor(taskKey);
    final requestId = bucket.loadRequestId + 1;
    state = AsyncData(
      _replaceBucket(
        current,
        taskKey,
        bucket.copyWith(
          loadRequestId: requestId,
          isLoading: true,
          loadErrorMessage: null,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.idle(),
        ),
      ),
    );
    try {
      final response = await _fetchRecordsPage(
        taskKey,
        page: 1,
        bucket: bucket,
      );
      if (_isStaleRequest(taskKey, requestId)) return;
      state = AsyncData(
        _replaceBucket(
          current,
          taskKey,
          _initialLoadSuccess(_bucketFor(taskKey), response),
        ),
      );
    } catch (error) {
      if (_isStaleRequest(taskKey, requestId)) return;
      state = AsyncData(
        _replaceBucket(
          current,
          taskKey,
          _bucketFor(taskKey).copyWith(
            isLoading: false,
            loadErrorMessage: apiErrorMessage(
              error,
              fallback: '资源任务记录加载失败，请稍后重试',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadFilteredFirstPage(
    String taskKey,
    int requestId,
    int filterRequestId,
  ) async {
    final bucket = _bucketFor(taskKey);
    try {
      final response = await _fetchRecordsPage(
        taskKey,
        page: 1,
        bucket: bucket,
      );
      if (_isStaleRequest(taskKey, requestId) ||
          !_filterRequests.isCurrent(filterRequestId)) {
        return;
      }
      state = AsyncData(
        _replaceBucket(
          current,
          taskKey,
          _initialLoadSuccess(_bucketFor(taskKey), response),
        ),
      );
    } catch (error) {
      if (_isStaleRequest(taskKey, requestId) ||
          !_filterRequests.isCurrent(filterRequestId)) {
        return;
      }
      final latest = _bucketFor(taskKey);
      state = AsyncData(
        _replaceBucket(
          current,
          taskKey,
          latest.copyWith(
            isLoading: false,
            filterUpdate: FilterUpdateState.failed(
              apiErrorMessage(error, fallback: '筛选结果更新失败，请重试'),
            ),
          ),
        ),
      );
    }
  }

  Future<PaginatedResponseDto<ResourceTaskRecordDto>> _fetchRecordsPage(
    String taskKey, {
    required int page,
    required ResourceTaskRecordsBucketState bucket,
  }) {
    final search = bucket.filter.normalizedSearch;
    return ref
        .read(activityApiProvider)
        .getResourceTaskRecords(
          taskKey: taskKey,
          page: page,
          pageSize: _pageSize,
          state: bucket.filter.stateFilter.apiValue,
          search: search.isEmpty ? null : search,
          sort: bucket.filter.sort.apiValue,
        );
  }

  ResourceTaskRecordsBucketState _initialLoadSuccess(
    ResourceTaskRecordsBucketState bucket,
    PaginatedResponseDto<ResourceTaskRecordDto> response,
  ) {
    return bucket.copyWith(
      records: response.items,
      nextPage: response.page + 1,
      hasMore:
          response.items.length >= response.pageSize &&
          response.items.length < response.total,
      isLoading: false,
      hasLoadedOnce: true,
      loadErrorMessage: null,
      filterUpdate: const FilterUpdateState.idle(),
    );
  }

  ResourceTaskRecordsBucketState _bucketFor(String taskKey) =>
      current.buckets[taskKey] ?? const ResourceTaskRecordsBucketState();

  ResourceTaskCenterState _replaceBucket(
    ResourceTaskCenterState base,
    String taskKey,
    ResourceTaskRecordsBucketState bucket,
  ) {
    return base.copyWith(
      buckets: <String, ResourceTaskRecordsBucketState>{
        ...base.buckets,
        taskKey: bucket,
      },
    );
  }

  bool _isStaleRequest(String taskKey, int requestId) =>
      isDisposed || _bucketFor(taskKey).loadRequestId != requestId;

  List<int> _visibleFailedResourceIds() {
    final ids = <int>[];
    for (final record in current.activeRecords) {
      if (!record.canBatchReset) continue;
      ids.add(record.resourceId);
      if (ids.length >= maxBatchResetCount) break;
    }
    return ids;
  }

  ResourceTaskCenterState _applySuccessfulReset(
    ResourceTaskCenterState base,
    Set<int> resetIds,
    int resetCount,
  ) {
    var next = base;
    final bucket = base.buckets[kMediaThumbnailTaskKey];
    if (bucket != null && resetIds.isNotEmpty) {
      next = _replaceBucket(
        next,
        kMediaThumbnailTaskKey,
        bucket.copyWith(
          records: bucket.records
              .where((record) => !resetIds.contains(record.resourceId))
              .toList(),
        ),
      );
    }
    if (resetCount <= 0) return next;
    final definitions = next.definitions.map((definition) {
      if (definition.taskKey != kMediaThumbnailTaskKey) return definition;
      final counts = definition.stateCounts;
      final delta = resetCount > counts.failed ? counts.failed : resetCount;
      if (delta <= 0) return definition;
      return definition.copyWith(
        stateCounts: counts.copyWith(
          failed: counts.failed - delta,
          pending: counts.pending + delta,
        ),
      );
    }).toList();
    return next.copyWith(definitions: definitions);
  }

  bool get initialized => current.initialized;
  bool get isInitialLoading => state.isLoading || current.isInitialLoading;
  bool get isRefreshingDefinitions => current.isRefreshingDefinitions;
  String? get initialErrorMessage => current.initialErrorMessage;
  String? get definitionsRefreshErrorMessage =>
      current.definitionsRefreshErrorMessage;
  List<ResourceTaskDefinitionDto> get definitions => current.definitions;
  String? get activeTaskKey => current.activeTaskKey;
  ResourceTaskDefinitionDto? get activeDefinition => current.activeDefinition;
  ResourceTaskRecordFilterState get filter => current.filter;
  List<ResourceTaskRecordDto> get activeRecords => current.activeRecords;
  bool get isLoadingRecords => current.isLoadingRecords;
  bool get isLoadingMoreRecords => current.isLoadingMoreRecords;
  bool get hasMoreRecords => current.hasMoreRecords;
  bool get hasLoadedActiveRecords => current.hasLoadedActiveRecords;
  String? get recordsLoadErrorMessage => current.recordsLoadErrorMessage;
  String? get recordsLoadMoreErrorMessage =>
      current.recordsLoadMoreErrorMessage;
  FilterUpdateState get filterUpdate =>
      current.activeBucket?.filterUpdate ?? const FilterUpdateState.idle();
  ResourceTaskRecordDto? get selectedRecord => current.selectedRecord;
  bool get isDetailOpen => current.isDetailOpen;
  bool get selectionMode => current.selectionMode;
  int get selectedCount => current.selectedCount;
  bool get hasSelection => current.hasSelection;
  bool get isResetting => current.isResetting;
  bool get supportsBatchReset =>
      current.activeTaskKey == kMediaThumbnailTaskKey;
  bool isRecordSelected(int resourceId) =>
      current.selectedResourceIds.contains(resourceId);
  int get visibleFailedCount =>
      current.activeRecords.where((record) => record.canBatchReset).length;
  int get visibleFailedTotalCount =>
      current.activeRecords.where((record) => record.isFailed).length;
  bool get isAllVisibleFailedSelected {
    final ids = _visibleFailedResourceIds();
    return ids.isNotEmpty && ids.every(current.selectedResourceIds.contains);
  }
}
