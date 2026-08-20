import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  MovieSubscriptionEvents broadcaster() =>
      container.read(movieSubscriptionEventsProvider.notifier);

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;

    // status-counts 在每次 mutation 后都会被刷一次，给它一个常驻兜底响应，
    // 免得每个用例都要按次数排队。
    adapter.setFallbackJson(
      method: 'GET',
      path: '/movie-subscriptions/status-counts',
      body: <String, dynamic>{'total': 3, 'missing': 3},
    );

    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        movieSubscriptionsApiProvider.overrideWithValue(
          MovieSubscriptionsApi(apiClient: apiClient),
        ),
        moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
        activityApiProvider.overrideWithValue(
          ActivityApi(
            apiClient: apiClient,
            streamClient: createActivityEventStreamClient(
              apiClient: apiClient,
              sessionStore: sessionStore,
            ),
          ),
        ),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  /// 默认落在「缺资源」签，所以首屏请求必然带 status=missing。
  Future<void> primeFirstPage({
    List<Map<String, dynamic>>? items,
    int? total,
  }) async {
    final resolved =
        items ??
        <Map<String, dynamic>>[
          _item(number: 'A-1', status: 'missing', attemptCount: 2),
          _item(number: 'A-2', status: 'missing', attemptCount: 1),
          _item(number: 'A-3', status: 'missing'),
        ];
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: resolved, total: total ?? resolved.length),
    );
    await container.read(movieSubscriptionManagerProvider.future);
  }

  test('默认筛选落在「缺资源」而不是全部', () async {
    await primeFirstPage();

    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.filter.status, MovieSubscriptionStatus.missing);
    expect(adapter.requests.first.uri.queryParameters['status'], 'missing');
  });

  test('applyStatus 切签重新拉取并退出多选', () async {
    await primeFirstPage();
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);
    notifier.enterSelectionMode();
    notifier.toggleSelection('A-1');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(
        items: <Map<String, dynamic>>[
          _item(number: 'B-1', status: 'exhausted'),
        ],
        total: 1,
      ),
    );
    await notifier.applyStatus(MovieSubscriptionStatus.exhausted);

    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.filter.status, MovieSubscriptionStatus.exhausted);
    expect(state.paged.items.single.movieNumber, 'B-1');
    expect(state.selectionMode, isFalse);
    expect(state.selectedMovieNumbers, isEmpty);
    expect(adapter.requests.last.uri.queryParameters['status'], 'exhausted');
  });

  test('面板重置只清排序与搜索，保留当前分段签', () async {
    await primeFirstPage();
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);

    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: const <Map<String, dynamic>>[]),
    );
    await notifier.applyFilterState(
      const MovieSubscriptionFilterState(
        status: MovieSubscriptionStatus.missing,
        sort: MovieSubscriptionSort.attemptCountDesc,
        search: 'ABP',
      ),
    );
    expect(adapter.requests.last.uri.queryParameters['search'], 'ABP');

    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: const <Map<String, dynamic>>[]),
    );
    final current =
        container.read(movieSubscriptionManagerProvider).requireValue.filter;
    await notifier.applyFilterState(current.resetPanel());

    final query = adapter.requests.last.uri.queryParameters;
    expect(query['status'], 'missing');
    expect(query.containsKey('search'), isFalse);
    // sort 在筛选状态里非空，重置只是拨回默认值，仍然显式下发。
    expect(query['sort'], 'subscribed_at:desc');
  });

  test('全选切换：已全选时再点即清空', () async {
    await primeFirstPage();
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);

    notifier.toggleSelectAllLoaded();
    expect(
      container
          .read(movieSubscriptionManagerProvider)
          .requireValue
          .selectionCount,
      3,
    );

    notifier.toggleSelectAllLoaded();
    expect(
      container
          .read(movieSubscriptionManagerProvider)
          .requireValue
          .selectedMovieNumbers,
      isEmpty,
    );
  });

  test('重置查询后条目离开「缺资源」签并扣减 total', () async {
    await primeFirstPage();
    adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      body: _actionResult(accepted: <int>[1]),
    );

    final result = await container
        .read(movieSubscriptionManagerProvider.notifier)
        .resetSearch('A-1');

    expect(result.hasError, isFalse);
    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'A-2',
      'A-3',
    ]);
    expect(state.paged.total, 2);
    expect(state.isPending('A-1'), isFalse);
  });

  test('停在「待查」签时重置只改字段、不移除行', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(
        items: <Map<String, dynamic>>[
          _item(number: 'A-1', status: 'missing', attemptCount: 2),
        ],
        total: 1,
      ),
    );
    await container.read(movieSubscriptionManagerProvider.future);

    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(
        items: <Map<String, dynamic>>[
          _item(
            number: 'A-1',
            status: 'pending',
            attemptCount: 2,
            lastSearchedAt: '2026-07-20T02:30:00',
          ),
        ],
        total: 1,
      ),
    );
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);
    await notifier.applyStatus(MovieSubscriptionStatus.pending);

    adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      body: _actionResult(accepted: <int>[1]),
    );
    await notifier.resetSearch('A-1');

    final item =
        container
            .read(movieSubscriptionManagerProvider)
            .requireValue
            .paged
            .items
            .single;
    expect(item.movieNumber, 'A-1');
    expect(item.status, MovieSubscriptionStatus.pending);
    expect(item.attemptCount, 0);
    expect(item.lastSearchedAt, isNull);
  });

  test('批量重置跳过已入库 / 下载中的选中项', () async {
    await primeFirstPage(
      items: <Map<String, dynamic>>[
        _item(number: 'A-1', status: 'missing'),
        _item(number: 'A-2', status: 'imported'),
        _item(number: 'A-3', status: 'downloading'),
      ],
    );
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);
    notifier.toggleSelectAllLoaded();
    expect(
      container
          .read(movieSubscriptionManagerProvider)
          .requireValue
          .resettableSelectionCount,
      1,
    );

    adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      body: _actionResult(accepted: <int>[1]),
    );
    final result = await notifier.batchResetSearch();

    expect(result.affectedCount, 1);
    final actionRequest = adapter.requests.firstWhere(
      (request) => request.path == '/system/resource-task-actions',
    );
    expect(actionRequest.body, containsPair('resource_ids', <int>[1]));
    expect(
      actionRequest.body,
      containsPair('task_key', 'subscribed_movie_auto_download'),
    );
    expect(actionRequest.body, containsPair('action', 'reset_retry_budget'));
  });

  test('重置失败保留原列表并回传中文错误', () async {
    await primeFirstPage();
    adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );

    final result = await container
        .read(movieSubscriptionManagerProvider.notifier)
        .resetSearch('A-1');

    expect(result.hasError, isTrue);
    expect(result.errorMessage, isNotEmpty);
    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.paged.items, hasLength(3));
    expect(state.isPending('A-1'), isFalse);
  });

  test('取消订阅移除行并广播给其它页面', () async {
    await primeFirstPage();
    final changes = <MovieSubscriptionChange>[];
    container.listen(movieSubscriptionEventsProvider, (_, next) {
      final batch = next.value;
      if (batch != null) changes.addAll(batch);
    });

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/A-1/subscription',
      statusCode: 204,
    );
    final result = await container
        .read(movieSubscriptionManagerProvider.notifier)
        .unsubscribe('A-1');

    expect(result.status, MovieSubscriptionToggleStatus.unsubscribed);
    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'A-2',
      'A-3',
    ]);
    expect(state.paged.total, 2);
    expect(changes.single.movieNumber, 'A-1');
    expect(changes.single.isSubscribed, isFalse);
  });

  test('后端以「存在媒体」拒绝时行保留，结果归 blockedByMedia', () async {
    await primeFirstPage();
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/A-1/subscription',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'movie_subscription_has_media'},
      },
    );

    final result = await container
        .read(movieSubscriptionManagerProvider.notifier)
        .unsubscribe('A-1');

    expect(result.status, MovieSubscriptionToggleStatus.blockedByMedia);
    expect(
      container.read(movieSubscriptionManagerProvider).requireValue.paged.items,
      hasLength(3),
    );
  });

  test('批量取消订阅：接受项移除、跳过项保持选中', () async {
    await primeFirstPage();
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);
    notifier.toggleSelectAllLoaded();

    adapter.enqueueJson(
      method: 'POST',
      path: '/movies/unsubscriptions',
      body: <String, dynamic>{
        'requested_count': 3,
        'updated_count': 2,
        'skipped_count': 1,
        'skipped': <Map<String, dynamic>>[
          <String, dynamic>{'movie_number': 'A-3', 'reason': 'has_media'},
        ],
      },
    );
    final result = await notifier.batchUnsubscribe();

    expect(result.updatedCount, 2);
    expect(result.skippedHasMediaNumbers, <String>['A-3']);
    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>['A-3']);
    expect(state.selectedMovieNumbers, <String>{'A-3'});
    expect(state.runningBatchAction, isNull);
  });

  test('外部页面取消订阅的广播会把本页对应行摘掉', () async {
    await primeFirstPage();

    // 真实页面会一直 watch 本 provider；测试里补一个订阅者，否则 Riverpod 会把
    // 无人监听的 provider 的入站订阅挂起，广播根本流不进来。
    container.listen(movieSubscriptionManagerProvider, (_, __) {});
    broadcaster().reportChange(movieNumber: 'A-2', isSubscribed: false);
    // 广播要经过 StreamController → StreamProvider → ref.listen 三跳异步投递，
    // 单个 microtask 不够，给它几毫秒。
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.paged.items.map((item) => item.movieNumber), <String>[
      'A-1',
      'A-3',
    ]);
    expect(state.paged.total, 2);
  });

  test('一键重置全部已放弃后整页重拉', () async {
    await primeFirstPage();
    final notifier = container.read(movieSubscriptionManagerProvider.notifier);

    adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      body: _actionResult(
        accepted: List<int>.generate(12, (index) => index + 100),
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: const <Map<String, dynamic>>[]),
    );

    final result = await notifier.resetAllExhausted();

    expect(result.affectedCount, 12);
    final actionRequest = adapter.requests.firstWhere(
      (request) => request.path == '/system/resource-task-actions',
    );
    // 批量按状态圈定：不带 resource_ids 键，state 圈 exhausted。
    expect(actionRequest.body, isNot(contains('resource_ids')));
    expect(actionRequest.body, containsPair('state', 'exhausted'));
    expect(actionRequest.body, containsPair('action', 'reset_retry_budget'));
    final state = container.read(movieSubscriptionManagerProvider).requireValue;
    expect(state.paged.items, isEmpty);
    expect(state.runningBatchAction, isNull);
  });
}

/// 番号尾号即 movie_id（A-1 → 1），让统一 action 的 resource_ids 断言可预测。
int _movieIdFor(String number) => int.parse(number.split('-').last);

/// 统一 action 的成功响应体。
Map<String, dynamic> _actionResult({required List<int> accepted}) {
  return <String, dynamic>{
    'task_key': 'subscribed_movie_auto_download',
    'action': 'reset_retry_budget',
    'task_run_id': null,
    'accepted_resource_ids': accepted,
    'skipped': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _item({
  required String number,
  required String status,
  int attemptCount = 0,
  int attemptLimit = 3,
  String? lastSearchedAt,
}) {
  return <String, dynamic>{
    'movie_id': _movieIdFor(number),
    'movie_number': number,
    'title': 'Title $number',
    'status': status,
    'is_fresh': false,
    'attempt_count': attemptCount,
    'attempt_limit': attemptLimit,
    'last_searched_at': lastSearchedAt,
    'dead_download_task_count': 0,
    'media_count': 0,
  };
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  int? total,
  int page = 1,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': 20,
    'total': total ?? items.length,
  };
}
