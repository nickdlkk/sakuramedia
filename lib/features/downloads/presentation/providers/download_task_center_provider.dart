import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_stream_event_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';
import 'package:sakuramedia/features/shared/presentation/providers/sse_channel.dart';

part 'download_task_center_provider.g.dart';

/// 下载任务中心（Riverpod）：分页拉 `/download-tasks` + SSE 实时进度 + 暂停/恢复/删除。
///
/// 迁移前对应：`DownloadTaskCenterController extends ChangeNotifier`。
///
/// 差异：
/// - 首屏 loading / error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）；
///   retry 走 `ref.invalidateSelf()`。
/// - 筛选切换（[applyFilter]）先同步更新筛选控件，保留旧列表并防抖刷新第一页。
/// - SSE 触发的「首页去抖合并」维持原生流程：独立 fetchPage(1) + 手工 upsert，
///   有 [_minMergeInterval] 限流兜底。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class DownloadTaskCenter extends _$DownloadTaskCenter
    with
        PagedAsyncNotifierMixin<DownloadTaskCenterState, DownloadTaskRowState> {
  static const int _pageSize = 20;
  static const Duration _mergeDebounce = Duration(milliseconds: 800);
  static const Duration _longDisconnectThreshold = Duration(minutes: 2);
  static const Duration _pollingInterval = Duration(seconds: 30);

  /// 两次「SSE 触发的第一页 merge」之间的最小时间间隔——防止死循环。
  /// 用户主动 refresh / applyFilter 走独立入口，不受影响。
  static const Duration _minMergeInterval = Duration(seconds: 15);

  DownloadTaskFilterState _activeFilter = DownloadTaskFilterState.initial;
  int _filterGeneration = 0;
  late final DebouncedLatestRequest _filterRequests = DebouncedLatestRequest();
  bool _restartStreamAfterFilter = false;

  /// 客户端列表先于任务首页返回时暂存，等 `build()` 完成后再合并，
  /// 避免「state 尚未就绪 → 名字被静默丢弃」的竞态。
  List<DownloadClientOption>? _pendingClientOptions;
  Map<int, String>? _pendingClientNames;
  Map<int, DownloadClientKind>? _pendingClientKinds;

  /// SSE 连接状态机：重连退避 / unsupported 轮询兜底 / 长断线补拉 / 微任务
  /// 合批全部由它承担，本 provider 只负责「事件怎么改状态」。
  ///
  /// 「拉第一页」的 800ms 去抖与 15s 硬闸**不在** channel 里:channel 的
  /// `mergeDebounce` / `minMergeInterval` 管的是事件批次的下发节奏，这里要限的
  /// 是被事件触发的**网络请求**（防死循环打爆第一页接口），两者不是一回事——
  /// 拿 channel 的闸来限会把实时进度也一并压到 15s 才更新。
  SseChannel<DownloadTaskStreamEvent>? _channel;
  Timer? _mergeDebounceTimer;
  DateTime? _lastFirstPageMergeAt;

  @override
  int get pageSize => _pageSize;

  @override
  String get initialLoadErrorText => '下载任务加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失败，请点击重试';

  @override
  PagedListState<DownloadTaskRowState> pagedOf(DownloadTaskCenterState s) =>
      s.paged;

  @override
  DownloadTaskCenterState applyPaged(
    DownloadTaskCenterState s,
    PagedListState<DownloadTaskRowState> paged,
  ) => s.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<DownloadTaskRowState>> fetchPage(
    int page,
    int pageSize,
  ) async {
    final filter = _activeFilter;
    final response = await ref
        .read(downloadsApiProvider)
        .getDownloadTasks(
          page: page,
          pageSize: pageSize,
          clientId: filter.clientId,
          movieNumber: filter.normalizedSearch.isEmpty
              ? null
              : filter.normalizedSearch,
          downloadStates: filter.stateFilter.apiValues,
          sort: 'created_at:desc',
        );
    final liveById = _liveOverlayById();
    return PaginatedResponseDto<DownloadTaskRowState>(
      items: response.items
          .map(
            (task) => DownloadTaskRowState(task: task, live: liveById[task.id]),
          )
          .toList(growable: false),
      page: response.page,
      pageSize: response.pageSize,
      total: response.total,
      syncedAt: response.syncedAt,
    );
  }

  @override
  Future<DownloadTaskCenterState> build() async {
    // 登出即失效：SSE / 重连退避 / 轮询都由下面的 onDispose 收尾。
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    ref.onDispose(() {
      _filterRequests.dispose();
      unawaited(_shutdownChannel());
      _cancelMergeDebounce();
    });
    unawaited(_loadClientOptionsInBackground());
    final paged = await loadInitialPage();
    return _mergePendingClientData(
      DownloadTaskCenterState.initial.copyWith(
        paged: paged,
        filter: _activeFilter,
      ),
    );
  }

  /// 保留态刷新：立即请求当前筛选，并复用筛选失败反馈。
  @override
  Future<String?> refresh() async {
    await retryFilter();
    return state.value?.paged.filterUpdate.errorMessage;
  }

  /// 切换筛选条件：State 立即更新，最终条件在 250ms 后请求并重连 SSE。
  Future<void> applyFilter(DownloadTaskFilterState next) {
    if (_activeFilter == next) return Future<void>.value();
    _activeFilter = next;
    _filterGeneration++;
    _restartStreamAfterFilter =
        _restartStreamAfterFilter ||
        state.value?.streamState == DownloadTaskStreamState.live ||
        state.value?.streamState == DownloadTaskStreamState.connecting ||
        state.value?.streamState == DownloadTaskStreamState.reconnecting ||
        state.value?.streamState == DownloadTaskStreamState.polling;
    final current = state.value;
    if (current == null) {
      return _filterRequests.schedule(_loadSelectedFilter);
    }

    invalidateInFlightLoadMore();
    state = AsyncData(
      current.copyWith(
        filter: next,
        paged: current.paged.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );
    return _filterRequests.schedule(_loadSelectedFilter);
  }

  Future<void> retryFilter() {
    final current = state.value;
    if (current != null) {
      invalidateInFlightLoadMore();
      state = AsyncData(
        current.copyWith(
          paged: current.paged.copyWith(
            isLoadingMore: false,
            loadMoreErrorMessage: null,
            filterUpdate: const FilterUpdateState.loading(),
          ),
        ),
      );
    }
    return _filterRequests.runNow(_loadSelectedFilter);
  }

  Future<void> _loadSelectedFilter(int requestId) async {
    final current = state.value;
    if (current == null) {
      await super.reload();
      return;
    }

    if (_restartStreamAfterFilter) {
      await _shutdownChannel();
      _cancelMergeDebounce();
      if (!_filterRequests.isCurrent(requestId) || isDisposed) return;
      final now = state.value ?? current;
      state = AsyncData(
        now.copyWith(streamState: DownloadTaskStreamState.idle),
      );
    }
    try {
      final firstPage = await loadInitialPage();
      if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
      final now = state.value ?? current;
      state = AsyncData(now.copyWith(paged: firstPage));
    } catch (error) {
      if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
      final now = state.value ?? current;
      state = AsyncData(
        now.copyWith(
          paged: now.paged.copyWith(
            filterUpdate: FilterUpdateState.failed(
              apiErrorMessage(error, fallback: '筛选结果更新失败，请重试'),
            ),
          ),
        ),
      );
    }

    if (_filterRequests.isCurrent(requestId) &&
        _restartStreamAfterFilter &&
        !isDisposed) {
      _restartStreamAfterFilter = false;
      unawaited(connectStream());
    }
  }

  @override
  Future<void> loadMore() {
    final current = state.value;
    if (current != null && !current.paged.filterUpdate.isIdle) {
      return Future<void>.value();
    }
    return super.loadMore();
  }

  /// 建连（幂等）。连接中 / 已连接 / 退避重连中 / 轮询中都直接返回——**退避期间
  /// 重复 connect 不再另开一条流**，交给 channel 按退避表续（旧实现放行
  /// `reconnecting`，会覆盖掉尚未 cancel 的旧订阅、留下第二条连接）。
  Future<void> connectStream() async {
    if (isDisposed) return;
    if (state.value == null) return;
    final channel = _channel;
    if (channel != null && channel.state != SseChannelState.idle) return;
    await _startChannel();
  }

  Future<void> disconnectStream() async {
    final now = state.value;
    if (now == null) return;
    if (now.streamState == DownloadTaskStreamState.idle) return;
    await _shutdownChannel();
    _cancelMergeDebounce();
    _updateStreamState(DownloadTaskStreamState.idle);
  }

  Future<void> pauseTask(int taskId) async {
    final now = state.value;
    if (now == null || now.pendingActionTaskIds.contains(taskId)) return;
    _addPending(taskId);
    try {
      await ref.read(downloadsApiProvider).pauseDownloadTask(taskId);
      if (isDisposed) return;
      _patchRowState(taskId, downloadState: 'paused');
    } finally {
      _removePending(taskId);
    }
  }

  Future<void> resumeTask(int taskId) async {
    final now = state.value;
    if (now == null || now.pendingActionTaskIds.contains(taskId)) return;
    _addPending(taskId);
    try {
      await ref.read(downloadsApiProvider).resumeDownloadTask(taskId);
      if (isDisposed) return;
      _patchRowState(taskId, downloadState: 'downloading');
    } finally {
      _removePending(taskId);
    }
  }

  Future<void> deleteTask(int taskId, {required bool deleteFiles}) async {
    final now = state.value;
    if (now == null || now.pendingActionTaskIds.contains(taskId)) return;
    _addPending(taskId);
    try {
      await ref
          .read(downloadsApiProvider)
          .deleteDownloadTask(taskId, deleteFiles: deleteFiles);
      if (isDisposed) return;
      _removeItemById(taskId);
    } finally {
      _removePending(taskId);
    }
  }

  // ─── internal ───────────────────────────────────────────────────────────

  Map<int, DownloadTaskProgressDto?> _liveOverlayById() {
    final overlay = <int, DownloadTaskProgressDto?>{};
    final current = state.value;
    if (current == null) return overlay;
    for (final row in current.paged.items) {
      overlay[row.task.id] = row.live;
    }
    return overlay;
  }

  Future<void> _loadClientOptionsInBackground() async {
    try {
      final clients = await ref.read(downloadClientsApiProvider).getClients();
      if (isDisposed) return;
      final options = clients
          .map(
            (client) => DownloadClientOption(
              id: client.id,
              name: client.name,
              kind: client.kind,
            ),
          )
          .toList(growable: false);
      final names = <int, String>{};
      final kinds = <int, DownloadClientKind>{};
      for (final client in clients) {
        names[client.id] = client.name;
        kinds[client.id] = client.kind;
      }
      final current = state.value;
      if (current == null) {
        _pendingClientOptions = options;
        _pendingClientNames = names;
        _pendingClientKinds = kinds;
        return;
      }
      state = AsyncData(
        current.copyWith(
          clientOptions: options,
          clientNames: names,
          clientKinds: kinds,
        ),
      );
    } catch (_) {
      // 静默：客户端名加载失败展示 `客户端 #<id>` 兜底。
    }
  }

  DownloadTaskCenterState _mergePendingClientData(
    DownloadTaskCenterState state,
  ) {
    final options = _pendingClientOptions;
    final names = _pendingClientNames;
    final kinds = _pendingClientKinds;
    if (options == null || names == null || kinds == null) {
      return state;
    }
    _pendingClientOptions = null;
    _pendingClientNames = null;
    _pendingClientKinds = null;
    return state.copyWith(
      clientOptions: options,
      clientNames: names,
      clientKinds: kinds,
    );
  }

  Future<void> _shutdownChannel() async {
    final channel = _channel;
    _channel = null;
    await channel?.shutdown();
  }

  /// 建连。重连退避（[kActivityBackoff]）、unsupported→30s 轮询兜底、断线超过
  /// 2 分钟先补拉第一页、微任务合批——全部是 [SseChannel] 的既有行为。
  Future<void> _startChannel() async {
    await _shutdownChannel();
    if (isDisposed) return;
    final channel = SseChannel<DownloadTaskStreamEvent>(
      // 筛选条件在连流那一刻才读，applyFilter 重连自然带上新参数。
      connect: ({String? afterEventId}) => ref
          .read(downloadsApiProvider)
          .streamDownloadTasks(
            clientId: _activeFilter.clientId,
            movieNumber: _activeFilter.normalizedSearch.isEmpty
                ? null
                : _activeFilter.normalizedSearch,
          ),
      mergeMode: SseMergeMode.microtask,
      pollingInterval: _pollingInterval,
      longDisconnectThreshold: _longDisconnectThreshold,
      onStateChanged: _applyChannelState,
      onPollingTick: () => unawaited(_reloadFirstPage()),
      onLongDisconnectRecover: _reloadFirstPage,
    );
    _channel = channel;
    await channel.start(
      // microtask 合批模式下事件走 onBatch；onEvent 只是模式改变时的等价兜底。
      onEvent: (event) => _applyStreamEvents(<DownloadTaskStreamEvent>[event]),
      onBatch: _applyStreamEvents,
    );
  }

  void _applyChannelState(SseChannelState next) {
    switch (next) {
      case SseChannelState.idle:
        _updateStreamState(DownloadTaskStreamState.idle);
      case SseChannelState.connecting:
        _updateStreamState(DownloadTaskStreamState.connecting);
      case SseChannelState.live:
        _updateStreamState(DownloadTaskStreamState.live);
      case SseChannelState.reconnecting:
        _updateStreamState(DownloadTaskStreamState.reconnecting);
      case SseChannelState.polling:
        _updateStreamState(DownloadTaskStreamState.polling);
      // 本域配了 pollingInterval，不会走「放弃订阅」这一支。
      case SseChannelState.unsupportedAbandoned:
        _updateStreamState(DownloadTaskStreamState.idle);
    }
  }

  /// 轮询 tick 与长断线补拉共用：整段替换第一页。这两条路径本来就是「本地可能
  /// 已经落后很多」的场景，以服务端为准，不做 upsert 合并。
  Future<void> _reloadFirstPage() async {
    final currentBefore = state.value;
    if (currentBefore == null || !currentBefore.paged.filterUpdate.isIdle) {
      return;
    }
    final filterGeneration = _filterGeneration;
    try {
      final firstPage = await loadInitialPage();
      if (isDisposed || filterGeneration != _filterGeneration) return;
      final current = state.value;
      if (current == null || !current.paged.filterUpdate.isIdle) return;
      state = AsyncData(current.copyWith(paged: firstPage));
    } catch (_) {
      // 保留最后一次成功状态。
    }
  }

  void _applyStreamEvents(List<DownloadTaskStreamEvent> events) {
    if (isDisposed || events.isEmpty) return;

    final initial = state.value;
    if (initial == null || !initial.paged.filterUpdate.isIdle) return;

    final firstPageComplete = initial.paged.items.length >= initial.paged.total;

    var current = initial;
    var scheduleFirstPageMerge = false;
    for (final event in events) {
      switch (event.kind) {
        case DownloadTaskStreamEventKind.heartbeat:
          if (current.streamState != DownloadTaskStreamState.live) {
            current = current.copyWith(
              streamState: DownloadTaskStreamState.live,
            );
          }
          break;
        case DownloadTaskStreamEventKind.snapshot:
          for (final item in event.snapshotItems) {
            final patched = _applyProgress(current, item);
            if (patched != null) {
              current = patched;
              final row = _rowById(current, item.taskId);
              if (row != null && !_rowMatchesFilter(row)) {
                current = _dropUnmatchedRow(current, item.taskId);
              }
            } else if (firstPageComplete && _progressMatchesFilter(item)) {
              scheduleFirstPageMerge = true;
            }
          }
          break;
        case DownloadTaskStreamEventKind.taskUpdated:
          final progress = event.progress;
          if (progress == null) break;
          final beforeState = _stateOf(current, progress.taskId);
          final patched = _applyProgress(current, progress);
          if (patched != null) {
            current = patched;
            final row = _rowById(current, progress.taskId);
            if (row != null && !_rowMatchesFilter(row)) {
              current = _dropUnmatchedRow(current, progress.taskId);
            } else if (beforeState != null &&
                (beforeState != 'completed' && beforeState != 'seeding') &&
                (progress.downloadState == 'completed' ||
                    progress.downloadState == 'seeding')) {
              scheduleFirstPageMerge = true;
            }
          } else if (firstPageComplete && _progressMatchesFilter(progress)) {
            scheduleFirstPageMerge = true;
          }
          break;
        case DownloadTaskStreamEventKind.taskRemoved:
          final removed = event.removed;
          if (removed == null) break;
          current = _dropUnmatchedRow(current, removed.taskId);
          break;
        case DownloadTaskStreamEventKind.clientTransfer:
          final transfer = event.clientTransfer;
          if (transfer == null) break;
          final existing =
              current.clientTransfers[transfer.clientId] ??
              DownloadClientTransferState(clientId: transfer.clientId);
          final nextMap = Map<int, DownloadClientTransferState>.of(
            current.clientTransfers,
          );
          nextMap[transfer.clientId] = existing.copyWith(
            downloadSpeedBytes: transfer.downloadSpeedBytes,
            uploadSpeedBytes: transfer.uploadSpeedBytes,
          );
          current = current.copyWith(clientTransfers: nextMap);
          break;
        case DownloadTaskStreamEventKind.clientHealth:
          final health = event.clientHealth;
          if (health == null) break;
          final existing =
              current.clientTransfers[health.clientId] ??
              DownloadClientTransferState(clientId: health.clientId);
          final nextMap = Map<int, DownloadClientTransferState>.of(
            current.clientTransfers,
          );
          nextMap[health.clientId] = existing.copyWith(
            isAvailable: health.isAvailable,
            unavailableMessage: health.isAvailable
                ? null
                : health.message ?? '客户端不可用',
            downloadSpeedBytes: health.isAvailable ? null : 0,
            uploadSpeedBytes: health.isAvailable ? null : 0,
          );
          current = current.copyWith(clientTransfers: nextMap);
          break;
        case DownloadTaskStreamEventKind.unknown:
          break;
      }
    }

    if (!identical(current, initial)) {
      state = AsyncData(current);
    }

    if (scheduleFirstPageMerge && _canScheduleFirstPageMerge()) {
      _scheduleFirstPageMerge();
    }
  }

  bool _canScheduleFirstPageMerge() {
    final last = _lastFirstPageMergeAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _minMergeInterval;
  }

  DownloadTaskCenterState? _applyProgress(
    DownloadTaskCenterState state,
    DownloadTaskProgressDto progress,
  ) {
    final items = state.paged.items;
    final index = items.indexWhere((row) => row.task.id == progress.taskId);
    if (index < 0) return null;
    final row = items[index];
    final next = List<DownloadTaskRowState>.from(items);
    next[index] = row.copyWith(live: progress);
    return state.copyWith(
      paged: state.paged.copyWith(
        items: List<DownloadTaskRowState>.unmodifiable(next),
      ),
    );
  }

  String? _stateOf(DownloadTaskCenterState state, int taskId) {
    for (final row in state.paged.items) {
      if (row.task.id == taskId) return row.downloadState;
    }
    return null;
  }

  DownloadTaskRowState? _rowById(DownloadTaskCenterState state, int taskId) {
    for (final row in state.paged.items) {
      if (row.task.id == taskId) return row;
    }
    return null;
  }

  void _patchRowState(int taskId, {required String downloadState}) {
    final current = state.value;
    if (current == null) return;
    final items = current.paged.items;
    final index = items.indexWhere((row) => row.task.id == taskId);
    if (index < 0) return;
    final row = items[index];
    final next = List<DownloadTaskRowState>.from(items);
    next[index] = row.copyWith(
      task: row.task.copyWith(downloadState: downloadState),
    );
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          items: List<DownloadTaskRowState>.unmodifiable(next),
        ),
      ),
    );
  }

  void _removeItemById(int taskId) {
    final current = state.value;
    if (current == null) return;
    final next = current.paged.items
        .where((row) => row.task.id != taskId)
        .toList(growable: false);
    if (next.length == current.paged.items.length) return;
    final total = current.paged.total > 0 ? current.paged.total - 1 : 0;
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          items: List<DownloadTaskRowState>.unmodifiable(next),
          total: total,
          hasMore: next.length < total,
        ),
      ),
    );
  }

  DownloadTaskCenterState _dropUnmatchedRow(
    DownloadTaskCenterState state,
    int taskId,
  ) {
    final next = state.paged.items
        .where((row) => row.task.id != taskId)
        .toList(growable: false);
    if (next.length == state.paged.items.length) return state;
    final total = state.paged.total > 0 ? state.paged.total - 1 : 0;
    return state.copyWith(
      paged: state.paged.copyWith(
        items: List<DownloadTaskRowState>.unmodifiable(next),
        total: total,
        hasMore: next.length < total,
      ),
    );
  }

  void _addPending(int taskId) {
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.pendingActionTaskIds)..add(taskId);
    state = AsyncData(current.copyWith(pendingActionTaskIds: next));
  }

  void _removePending(int taskId) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.pendingActionTaskIds)..remove(taskId);
    state = AsyncData(current.copyWith(pendingActionTaskIds: next));
  }

  void _updateStreamState(DownloadTaskStreamState next) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    if (current.streamState == next) return;
    state = AsyncData(current.copyWith(streamState: next));
  }

  bool _progressMatchesFilter(DownloadTaskProgressDto progress) {
    if (_activeFilter.clientId != null &&
        progress.clientId != _activeFilter.clientId) {
      return false;
    }
    final search = _activeFilter.normalizedSearch;
    if (search.isNotEmpty) {
      final movie = progress.movieNumber?.trim().toUpperCase() ?? '';
      if (movie != search.toUpperCase()) return false;
    }
    final expectedStates = _activeFilter.stateFilter.apiValues;
    if (expectedStates != null &&
        !expectedStates.contains(progress.downloadState)) {
      return false;
    }
    return true;
  }

  bool _rowMatchesFilter(DownloadTaskRowState row) {
    if (_activeFilter.clientId != null &&
        row.task.clientId != _activeFilter.clientId) {
      return false;
    }
    final search = _activeFilter.normalizedSearch;
    if (search.isNotEmpty) {
      final movie = row.task.movieNumber?.trim().toUpperCase() ?? '';
      if (movie != search.toUpperCase()) return false;
    }
    final expectedStates = _activeFilter.stateFilter.apiValues;
    if (expectedStates != null && !expectedStates.contains(row.downloadState)) {
      return false;
    }
    return true;
  }

  void _scheduleFirstPageMerge() {
    _cancelMergeDebounce();
    _mergeDebounceTimer = Timer(_mergeDebounce, () async {
      if (isDisposed) return;
      final currentBefore = state.value;
      if (currentBefore == null || !currentBefore.paged.filterUpdate.isIdle) {
        return;
      }
      final filterGeneration = _filterGeneration;
      try {
        final firstPage = await loadInitialPage();
        if (isDisposed || filterGeneration != _filterGeneration) return;
        final current = state.value;
        if (current == null || !current.paged.filterUpdate.isIdle) return;
        final merged = _mergeUpsertFirstPage(
          current.paged.items,
          firstPage.items,
        );
        state = AsyncData(
          current.copyWith(
            paged: current.paged.copyWith(
              items: List<DownloadTaskRowState>.unmodifiable(merged),
              total: firstPage.total,
              hasMore: merged.length < firstPage.total,
              syncedAt: firstPage.syncedAt,
            ),
          ),
        );
        _lastFirstPageMergeAt = DateTime.now();
      } catch (_) {
        // 后台合并失败静默；下一次事件或用户刷新兜底。
      }
    });
  }

  void _cancelMergeDebounce() {
    _mergeDebounceTimer?.cancel();
    _mergeDebounceTimer = null;
  }

  List<DownloadTaskRowState> _mergeUpsertFirstPage(
    List<DownloadTaskRowState> current,
    List<DownloadTaskRowState> firstPage,
  ) {
    final firstPageIds = <int>{};
    final byId = <int, DownloadTaskRowState>{};
    for (final row in current) {
      byId[row.task.id] = row;
    }
    final head = <DownloadTaskRowState>[];
    for (final row in firstPage) {
      firstPageIds.add(row.task.id);
      final existing = byId[row.task.id];
      if (existing != null) {
        // Preserve local `live` overlay across re-fetch (already handled in
        // fetchPage → PagedListState.fromFirstPage, but keep the overlay
        // from anything the SSE already patched in between).
        head.add(existing.copyWith(task: row.task));
      } else {
        head.add(row);
      }
    }
    // 保留分页 2+ 已加载但不在首页快照里的行。
    final tail = current
        .where((row) => !firstPageIds.contains(row.task.id))
        .toList(growable: false);
    return <DownloadTaskRowState>[...head, ...tail];
  }
}
