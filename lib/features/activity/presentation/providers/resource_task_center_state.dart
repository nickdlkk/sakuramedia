import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

@immutable
class ResourceTaskRecordsBucketState {
  const ResourceTaskRecordsBucketState({
    this.records = const <ResourceTaskRecordDto>[],
    this.nextPage = 1,
    this.hasMore = true,
    this.hasLoadedOnce = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.loadErrorMessage,
    this.loadMoreErrorMessage,
    this.loadRequestId = 0,
    this.filter = ResourceTaskRecordFilterState.initial,
    this.filterUpdate = const FilterUpdateState.idle(),
  });

  final List<ResourceTaskRecordDto> records;
  final int nextPage;
  final bool hasMore;
  final bool hasLoadedOnce;
  final bool isLoading;
  final bool isLoadingMore;
  final String? loadErrorMessage;
  final String? loadMoreErrorMessage;
  final int loadRequestId;
  final ResourceTaskRecordFilterState filter;
  final FilterUpdateState filterUpdate;

  ResourceTaskRecordsBucketState copyWith({
    List<ResourceTaskRecordDto>? records,
    int? nextPage,
    bool? hasMore,
    bool? hasLoadedOnce,
    bool? isLoading,
    bool? isLoadingMore,
    Object? loadErrorMessage = _unset,
    Object? loadMoreErrorMessage = _unset,
    int? loadRequestId,
    ResourceTaskRecordFilterState? filter,
    FilterUpdateState? filterUpdate,
  }) {
    return ResourceTaskRecordsBucketState(
      records: records == null
          ? this.records
          : List<ResourceTaskRecordDto>.unmodifiable(records),
      nextPage: nextPage ?? this.nextPage,
      hasMore: hasMore ?? this.hasMore,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadErrorMessage: identical(loadErrorMessage, _unset)
          ? this.loadErrorMessage
          : loadErrorMessage as String?,
      loadMoreErrorMessage: identical(loadMoreErrorMessage, _unset)
          ? this.loadMoreErrorMessage
          : loadMoreErrorMessage as String?,
      loadRequestId: loadRequestId ?? this.loadRequestId,
      filter: filter ?? this.filter,
      filterUpdate: filterUpdate ?? this.filterUpdate,
    );
  }
}

@immutable
class ResourceTaskCenterState {
  ResourceTaskCenterState({
    this.initialized = false,
    this.isInitialLoading = false,
    this.isRefreshingDefinitions = false,
    this.initialErrorMessage,
    this.definitionsRefreshErrorMessage,
    List<ResourceTaskDefinitionDto> definitions =
        const <ResourceTaskDefinitionDto>[],
    this.activeTaskKey,
    Map<String, ResourceTaskRecordsBucketState> buckets =
        const <String, ResourceTaskRecordsBucketState>{},
    this.selectedRecord,
    this.selectionMode = false,
    Set<int> selectedResourceIds = const <int>{},
    this.isResetting = false,
  }) : definitions = List<ResourceTaskDefinitionDto>.unmodifiable(definitions),
       buckets = Map<String, ResourceTaskRecordsBucketState>.unmodifiable(
         buckets,
       ),
       selectedResourceIds = Set<int>.unmodifiable(selectedResourceIds);

  static final ResourceTaskCenterState initial = ResourceTaskCenterState();

  final bool initialized;
  final bool isInitialLoading;
  final bool isRefreshingDefinitions;
  final String? initialErrorMessage;
  final String? definitionsRefreshErrorMessage;
  final List<ResourceTaskDefinitionDto> definitions;
  final String? activeTaskKey;
  final Map<String, ResourceTaskRecordsBucketState> buckets;
  final ResourceTaskRecordDto? selectedRecord;
  final bool selectionMode;
  final Set<int> selectedResourceIds;
  final bool isResetting;

  ResourceTaskRecordsBucketState? get activeBucket =>
      activeTaskKey == null ? null : buckets[activeTaskKey];

  ResourceTaskDefinitionDto? get activeDefinition {
    final key = activeTaskKey;
    if (key == null) return null;
    for (final definition in definitions) {
      if (definition.taskKey == key) return definition;
    }
    return null;
  }

  ResourceTaskRecordFilterState get filter =>
      activeBucket?.filter ?? ResourceTaskRecordFilterState.initial;
  List<ResourceTaskRecordDto> get activeRecords =>
      activeBucket?.records ?? const <ResourceTaskRecordDto>[];
  bool get isLoadingRecords => activeBucket?.isLoading ?? false;
  bool get isLoadingMoreRecords => activeBucket?.isLoadingMore ?? false;
  bool get hasMoreRecords => activeBucket?.hasMore ?? false;
  bool get hasLoadedActiveRecords => activeBucket?.hasLoadedOnce ?? false;
  String? get recordsLoadErrorMessage => activeBucket?.loadErrorMessage;
  String? get recordsLoadMoreErrorMessage => activeBucket?.loadMoreErrorMessage;
  bool get isDetailOpen => selectedRecord != null;
  int get selectedCount => selectedResourceIds.length;
  bool get hasSelection => selectedResourceIds.isNotEmpty;

  ResourceTaskCenterState copyWith({
    bool? initialized,
    bool? isInitialLoading,
    bool? isRefreshingDefinitions,
    Object? initialErrorMessage = _unset,
    Object? definitionsRefreshErrorMessage = _unset,
    List<ResourceTaskDefinitionDto>? definitions,
    Object? activeTaskKey = _unset,
    Map<String, ResourceTaskRecordsBucketState>? buckets,
    Object? selectedRecord = _unset,
    bool? selectionMode,
    Set<int>? selectedResourceIds,
    bool? isResetting,
  }) {
    return ResourceTaskCenterState(
      initialized: initialized ?? this.initialized,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshingDefinitions:
          isRefreshingDefinitions ?? this.isRefreshingDefinitions,
      initialErrorMessage: identical(initialErrorMessage, _unset)
          ? this.initialErrorMessage
          : initialErrorMessage as String?,
      definitionsRefreshErrorMessage:
          identical(definitionsRefreshErrorMessage, _unset)
          ? this.definitionsRefreshErrorMessage
          : definitionsRefreshErrorMessage as String?,
      definitions: definitions ?? this.definitions,
      activeTaskKey: identical(activeTaskKey, _unset)
          ? this.activeTaskKey
          : activeTaskKey as String?,
      buckets: buckets ?? this.buckets,
      selectedRecord: identical(selectedRecord, _unset)
          ? this.selectedRecord
          : selectedRecord as ResourceTaskRecordDto?,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedResourceIds: selectedResourceIds ?? this.selectedResourceIds,
      isResetting: isResetting ?? this.isResetting,
    );
  }
}

const Object _unset = Object();
