import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_stream_event_dto.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';

import '../../../../support/test_api_bundle.dart';

// 覆盖迁 Riverpod 后 DownloadTaskCenter 的核心用户路径：
// 首页加载 + 加载更多、筛选切换（保留 items + filterUpdate）、
// 暂停/恢复/删除 mutation，以及 SSE 重连期的连接收敛。

/// 把 SSE 换成可控的 [StreamController]：记录开了几条流、关了几条，
/// 用来验证「重连退避期间再次 connectStream」不会漏掉旧连接。
class _StreamingDownloadsApi extends DownloadsApi {
  _StreamingDownloadsApi({
    required super.apiClient,
    required super.streamClient,
  });

  final List<StreamController<DownloadTaskStreamEvent>> controllers =
      <StreamController<DownloadTaskStreamEvent>>[];
  int cancelCount = 0;

  @override
  Stream<DownloadTaskStreamEvent> streamDownloadTasks({
    int? clientId,
    String? movieNumber,
  }) {
    final controller = StreamController<DownloadTaskStreamEvent>(
      onCancel: () => cancelCount += 1,
    );
    controllers.add(controller);
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-07-10T10:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        downloadsApiProvider.overrideWithValue(bundle.downloadsApi),
        downloadClientsApiProvider.overrideWithValue(bundle.downloadClientsApi),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  Map<String, dynamic> taskJson({
    required int id,
    String downloadState = 'downloading',
    String importStatus = 'pending',
    String importStatusLabel = '等待导入',
    double progress = 0.0,
  }) {
    return <String, dynamic>{
      'id': id,
      'client_id': 2,
      'movie_number': 'ABC-00$id',
      'name': 'ABC-00$id',
      'info_hash': 'hash-$id',
      'save_path': '/mnt/$id',
      'progress': progress,
      'download_state': downloadState,
      'import_status': importStatus,
      'import_status_label': importStatusLabel,
      'created_at': '2026-07-10T08:0$id:00Z',
      'updated_at': '2026-07-10T08:0$id:00Z',
    };
  }

  void enqueueTaskPage(
    List<Map<String, dynamic>> items, {
    int page = 1,
    int? total,
  }) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-tasks',
      body: <String, dynamic>{
        'items': items,
        'page': page,
        'page_size': 20,
        'total': total ?? items.length,
      },
    );
  }

  void enqueueClients({List<Map<String, dynamic>>? clients}) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-clients',
      body:
          clients ??
          <Map<String, dynamic>>[
            {
              'id': 2,
              'name': 'qb-main',
              'kind': 'qbittorrent',
              'base_url': 'http://qb:8080',
              'username': 'admin',
              'client_save_path': '/downloads',
              'local_root_path': '/mnt/qb',
              'media_library_id': 1,
              'has_password': true,
            },
          ],
    );
  }

  test('build loads first page with default filter', () async {
    enqueueTaskPage([taskJson(id: 1)]);
    enqueueClients();

    final state = await container.read(downloadTaskCenterProvider.future);

    expect(state.paged.items, hasLength(1));
    expect(state.paged.items.first.task.id, 1);
    expect(state.filter, DownloadTaskFilterState.initial);
    expect(state.paged.filterUpdate.isIdle, isTrue);
    expect(state.clientNames[2], 'qb-main');
    expect(state.clientOptions.single.name, 'qb-main');
    expect(state.clientKinds[2], DownloadClientKind.qbittorrent);
    final taskRequest = bundle.adapter.requests.firstWhere(
      (r) => r.uri.path.endsWith('/download-tasks'),
    );
    expect(taskRequest.uri.queryParametersAll['download_state'], [
      'downloading',
      'stalled',
    ]);
  });

  test('客户端列表早于任务首页返回时仍会合并进 state（竞态回归）', () async {
    final tasksCompleter = Completer<ResponseBody>();
    final clientsResponded = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/download-tasks',
      responder: (_, __) => tasksCompleter.future,
    );
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/download-clients',
      responder: (_, __) async {
        clientsResponded.complete();
        return ResponseBody.fromString(
          jsonEncode(<Map<String, dynamic>>[
            {
              'id': 2,
              'name': 'qb-main',
              'kind': 'qbittorrent',
              'base_url': 'http://qb:8080',
              'username': 'admin',
              'client_save_path': '/downloads',
              'local_root_path': '/mnt/qb',
              'media_library_id': 1,
              'has_password': true,
            },
          ]),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    final stateFuture = container.read(downloadTaskCenterProvider.future);

    // 复现原竞态时序：客户端响应先完成，任务首页仍挂起。
    await clientsResponded.future;
    await Future<void>.delayed(Duration.zero);
    tasksCompleter.complete(
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'items': [taskJson(id: 1)],
          'page': 1,
          'page_size': 20,
          'total': 1,
        }),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );

    final state = await stateFuture;

    expect(state.paged.items.single.task.id, 1);
    expect(state.clientNames[2], 'qb-main');
    expect(state.clientOptions.single.name, 'qb-main');
    expect(state.clientKinds[2], DownloadClientKind.qbittorrent);
  });

  test('loadMore appends next page and preserves live overlay', () async {
    enqueueTaskPage([taskJson(id: 1)], total: 3);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    enqueueTaskPage([taskJson(id: 2), taskJson(id: 3)], page: 2, total: 3);

    await container.read(downloadTaskCenterProvider.notifier).loadMore();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [1, 2, 3]);
    expect(state.paged.hasMore, isFalse);
  });

  test(
    'applyFilter keeps old items visible and fetches with new params',
    () async {
      enqueueTaskPage([taskJson(id: 1)]);
      enqueueClients();
      await container.read(downloadTaskCenterProvider.future);

      enqueueTaskPage([taskJson(id: 42, downloadState: 'paused')]);

      final future = container
          .read(downloadTaskCenterProvider.notifier)
          .applyFilter(
            DownloadTaskFilterState.initial.copyWith(
              stateFilter: DownloadTaskStateFilter.paused,
            ),
          );

      // 切换过程中：filter 已更新，结果状态 loading，旧 items 仍在。
      final duringSwitch = container
          .read(downloadTaskCenterProvider)
          .requireValue;
      expect(duringSwitch.paged.filterUpdate.isLoading, isTrue);
      expect(duringSwitch.filter.stateFilter, DownloadTaskStateFilter.paused);
      expect(duringSwitch.paged.items.first.task.id, 1);

      await future;

      final done = container.read(downloadTaskCenterProvider).requireValue;
      expect(done.paged.filterUpdate.isIdle, isTrue);
      expect(done.paged.items.map((row) => row.task.id), [42]);
      expect(
        bundle.adapter.requests.last.uri.queryParameters,
        containsPair('download_state', 'paused'),
      );
    },
  );

  test('applyFilter 清掉 in-flight loadMore 的 isLoadingMore，首页失败不死锁', () async {
    enqueueTaskPage([taskJson(id: 1)], total: 3);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    // 挂起一个 loadMore：响应悬置，模拟切筛选时仍在飞的第 2 页请求。
    final pendingLoadMore = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/download-tasks',
      responder: (_, __) => pendingLoadMore.future,
    );
    final loadMoreFuture = container
        .read(downloadTaskCenterProvider.notifier)
        .loadMore();
    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(downloadTaskCenterProvider)
          .requireValue
          .paged
          .isLoadingMore,
      isTrue,
    );

    // 新筛选的首页拉取失败：被作废的 loadMore 永不回写，若不显式清
    // isLoadingMore 会永远卡 true——loadMore 短路、refresh 静默 no-op。
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-tasks',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );
    await container
        .read(downloadTaskCenterProvider.notifier)
        .applyFilter(
          DownloadTaskFilterState.initial.copyWith(
            stateFilter: DownloadTaskStateFilter.paused,
          ),
        );

    final afterFailure = container
        .read(downloadTaskCenterProvider)
        .requireValue;
    expect(afterFailure.paged.isLoadingMore, isFalse);
    expect(afterFailure.paged.filterUpdate.hasFailed, isTrue);
    // 切换失败保留旧 items，filter 已生效可再触发重试。
    expect(afterFailure.paged.items.map((row) => row.task.id), [1]);
    expect(afterFailure.filter.stateFilter, DownloadTaskStateFilter.paused);

    // 未死锁的证明：手动 refresh 能正常发起并成功。
    enqueueTaskPage([taskJson(id: 7, downloadState: 'paused')]);
    final refreshError = await container
        .read(downloadTaskCenterProvider.notifier)
        .refresh();
    expect(refreshError, isNull);
    expect(
      container
          .read(downloadTaskCenterProvider)
          .requireValue
          .paged
          .items
          .map((row) => row.task.id),
      [7],
    );

    // 收尾：让被作废的 loadMore 回来，断言不会覆盖新状态。
    pendingLoadMore.complete(
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'items': <Map<String, dynamic>>[taskJson(id: 2), taskJson(id: 3)],
          'page': 2,
          'page_size': 20,
          'total': 3,
        }),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );
    await loadMoreFuture;
    expect(
      container
          .read(downloadTaskCenterProvider)
          .requireValue
          .paged
          .items
          .map((row) => row.task.id),
      [7],
    );
  });

  test('applyFilter short-circuits when equal filter is supplied', () async {
    enqueueTaskPage([taskJson(id: 1)]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    final beforeHits = bundle.adapter.hitCount('GET', '/download-tasks');
    await container
        .read(downloadTaskCenterProvider.notifier)
        .applyFilter(DownloadTaskFilterState.initial);

    expect(bundle.adapter.hitCount('GET', '/download-tasks'), beforeHits);
  });

  test('pauseTask patches downloadState + clears pending on success', () async {
    enqueueTaskPage([taskJson(id: 5)]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-tasks/5/pause',
      body: <String, dynamic>{},
    );
    await container.read(downloadTaskCenterProvider.notifier).pauseTask(5);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.downloadState, 'paused');
    expect(state.isTaskPending(5), isFalse);
  });

  test('resumeTask flips state to downloading', () async {
    enqueueTaskPage([taskJson(id: 7, downloadState: 'paused')]);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-tasks/7/resume',
      body: <String, dynamic>{},
    );
    await container.read(downloadTaskCenterProvider.notifier).resumeTask(7);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.single.downloadState, 'downloading');
    expect(state.isTaskPending(7), isFalse);
  });

  test('deleteTask removes row + decrements total', () async {
    enqueueTaskPage([taskJson(id: 3), taskJson(id: 4)], total: 5);
    enqueueClients();
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-tasks/3',
      body: <String, dynamic>{},
    );
    await container
        .read(downloadTaskCenterProvider.notifier)
        .deleteTask(3, deleteFiles: false);

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.paged.items.map((row) => row.task.id), [4]);
    expect(state.paged.total, 4);
    expect(state.paged.hasMore, isTrue); // 1/4
  });

  test('重连退避期间再次 connectStream 不另开一条 SSE', () async {
    final streamingApi = _StreamingDownloadsApi(
      apiClient: bundle.apiClient,
      streamClient: bundle.sseEventStreamClient,
    );
    final streamContainer = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        downloadsApiProvider.overrideWithValue(streamingApi),
        downloadClientsApiProvider.overrideWithValue(bundle.downloadClientsApi),
      ],
      retry: (_, _) => null,
    );
    addTearDown(streamContainer.dispose);

    enqueueTaskPage([taskJson(id: 1)]);
    enqueueClients();
    await streamContainer.read(downloadTaskCenterProvider.future);

    final notifier = streamContainer.read(downloadTaskCenterProvider.notifier);
    await notifier.connectStream();
    expect(streamingApi.controllers, hasLength(1));
    expect(
      streamContainer.read(downloadTaskCenterProvider).requireValue.streamState,
      DownloadTaskStreamState.live,
    );

    // 流出错 → 进入退避重连。listen 用的是 cancelOnError: false，旧订阅还活着。
    streamingApi.controllers.first.addError(StateError('boom'));
    await pumpEventQueue();
    expect(
      streamContainer.read(downloadTaskCenterProvider).requireValue.streamState,
      DownloadTaskStreamState.reconnecting,
    );

    // 退避计时器还没到点时页面重新挂载并 connect：不许另开一条流，交给
    // SseChannel 按退避表续。（旧实现的守卫放行 reconnecting，会覆盖掉还没
    // cancel 的旧订阅，留下第二条无人持有却仍在推事件的连接。）
    await notifier.connectStream();
    expect(streamingApi.controllers, hasLength(1));
    expect(
      streamContainer.read(downloadTaskCenterProvider).requireValue.streamState,
      DownloadTaskStreamState.reconnecting,
    );
  });
}
