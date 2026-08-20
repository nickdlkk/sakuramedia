import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/desktop/media_import_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty state when there are no import jobs', (
    tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(bundle, jobs: const <Map<String, dynamic>>[], total: 0);
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);

    await _pumpPage(tester, bundle: bundle);

    expect(find.byKey(const Key('media-import-page')), findsOneWidget);
    expect(find.byKey(const Key('media-import-create-button')), findsOneWidget);
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('renders a job row with status badge and counts', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(id: 3, taskRunId: 42, state: 'completed', imported: 5),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);

    await _pumpPage(tester, bundle: bundle);

    expect(find.byKey(const Key('media-import-job-path-3')), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('导入 5'), findsOneWidget);
  });

  testWidgets('JAV 字幕标签只提交 source_path 创建导入任务', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(bundle, jobs: const <Map<String, dynamic>>[], total: 0);
    _enqueueVideoJobsPage(bundle);
    _enqueueSubtitleJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _subtitleJobJson(id: 31, taskRunId: 91, state: 'completed'),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);

    await _pumpPage(tester, bundle: bundle);

    await tester.tap(find.byKey(const Key('media-import-tab-jav-subtitle')));
    await tester.pumpAndSettle();

    expect(find.text('JAV 字幕导入'), findsOneWidget);
    expect(find.byKey(const Key('media-import-job-path-31')), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/filesystem/entries',
      body: <String, dynamic>{
        'path': '/mnt/incoming/subtitles',
        'parent': '/mnt/incoming',
        'entries': <Map<String, dynamic>>[],
      },
    );
    await tester.tap(find.byKey(const Key('media-import-create-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('subtitle-import-directory-picker-modal')),
      findsOneWidget,
    );
    expect(find.textContaining('仅支持 .srt'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/subtitle-imports',
      statusCode: 202,
      body: <String, dynamic>{
        'subtitle_import_job_id': 32,
        'task_run_id': 92,
        'status': 'accepted',
      },
    );
    await tester.tap(
      find.byKey(const Key('subtitle-import-picker-submit-button')),
    );
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.lastWhere(
      (request) =>
          request.method == 'POST' && request.path == '/subtitle-imports',
    );
    expect(request.body, <String, dynamic>{
      'source_path': '/mnt/incoming/subtitles',
    });
    await _drainToast(tester);
  });

  testWidgets('virtualizes accumulated import jobs', (tester) async {
    _setDesktopViewport(tester, size: const Size(1200, 700));
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: List<Map<String, dynamic>>.generate(
        80,
        (index) => _jobJson(
          id: index + 1,
          taskRunId: index + 1000,
          state: 'completed',
          imported: 1,
        ),
      ),
      total: 80,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);

    await _pumpPage(tester, bundle: bundle);

    expect(find.byKey(const Key('media-import-job-path-1')), findsOneWidget);
    expect(find.byKey(const Key('media-import-job-path-80')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('media-import-job-path-80')),
      900,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('media-import-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-import-job-path-80')), findsOneWidget);
    expect(find.byKey(const Key('media-import-job-path-1')), findsNothing);
  });

  testWidgets('shows inline progress bar from a task_run SSE event', (
    tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(id: 3, taskRunId: 42, state: 'running', imported: 1),
      ],
      total: 1,
    );
    _enqueueVideoJobsPage(bundle);
    _enqueueSubtitleJobsPage(bundle);
    // 三个 controller 各连一路 SSE；三路都带同一条 JAV task_run 事件，
    // 保证无论 FIFO 出队顺序如何，JAV controller 都能拿到事件流（其它 task_key 会忽略它）。
    for (var i = 0; i < 3; i++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/activity/bootstrap',
        body: _bootstrapBody(latestEventId: 120),
      );
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/system/events/stream',
        chunks: <String>[
          'id: 121\n'
              'event: task_run_updated\n'
              'data: ${jsonEncode(_taskRunJson(id: 42, current: 3, total: 10))}\n\n',
        ],
      );
    }

    await _pumpPage(tester, bundle: bundle);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('3/10'), findsOneWidget);
  });

  testWidgets('expands failed files and shows retry action', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(
          id: 3,
          taskRunId: 42,
          state: 'completed',
          imported: 5,
          failed: 1,
        ),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/3',
      body: _jobJson(
        id: 3,
        taskRunId: 42,
        state: 'completed',
        imported: 5,
        failed: 1,
        failedFiles: <Map<String, dynamic>>[
          <String, dynamic>{
            'path': '/mnt/incoming/movies/ABP-123.mp4',
            'reason': 'movie_number_not_found',
            'detail': '',
            'kind': 'file',
          },
        ],
      ),
    );

    await _pumpPage(tester, bundle: bundle);

    await tester.tap(find.byKey(const Key('media-import-job-toggle-3')));
    await tester.pumpAndSettle();

    expect(find.text('/mnt/incoming/movies/ABP-123.mp4'), findsOneWidget);
    expect(find.byKey(const Key('media-import-retry-all-3')), findsOneWidget);
    expect(find.text('重导'), findsOneWidget);
  });

  testWidgets('virtualizes a large failed-file detail list', (tester) async {
    _setDesktopViewport(tester, size: const Size(1200, 700));
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(id: 33, taskRunId: 42, state: 'completed', failed: 100),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/33',
      body: _jobJson(
        id: 33,
        taskRunId: 42,
        state: 'completed',
        failed: 100,
        failedFiles: List<Map<String, dynamic>>.generate(
          100,
          (index) => <String, dynamic>{
            'path': '/mnt/incoming/movies/FAILED-${index + 1}.mp4',
            'reason': 'movie_number_not_found',
            'detail': '',
            'kind': 'file',
          },
        ),
      ),
    );

    await _pumpPage(tester, bundle: bundle);
    await tester.tap(find.byKey(const Key('media-import-job-toggle-33')));
    await tester.pumpAndSettle();

    final listKey = const Key('media-import-failed-file-list-33');
    expect(find.byKey(listKey), findsOneWidget);
    expect(find.text('/mnt/incoming/movies/FAILED-1.mp4'), findsOneWidget);
    expect(find.text('/mnt/incoming/movies/FAILED-100.mp4'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('/mnt/incoming/movies/FAILED-100.mp4'),
      700,
      scrollable: find.descendant(
        of: find.byKey(listKey),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('/mnt/incoming/movies/FAILED-100.mp4'), findsOneWidget);
    expect(find.text('/mnt/incoming/movies/FAILED-1.mp4'), findsNothing);
  });

  testWidgets('cloud115 job only exposes retry for failed source files', (
    tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(
          id: 9,
          taskRunId: 52,
          state: 'failed',
          failed: 1,
          sourcePath: 'cloud115:cid-source',
          sourceCid: 'cid-source',
          transferMode: 'copy',
        ),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/9',
      body: _jobJson(
        id: 9,
        taskRunId: 52,
        state: 'failed',
        failed: 1,
        sourcePath: 'cloud115:cid-source',
        sourceCid: 'cid-source',
        transferMode: 'copy',
        failedFiles: <Map<String, dynamic>>[
          <String, dynamic>{
            'path': 'ABP-123/movie.mp4',
            'reason': 'cloud115_transfer_failed',
            'detail': '',
            'kind': 'file',
          },
        ],
      ),
    );

    await _pumpPage(tester, bundle: bundle);

    expect(find.text('115 网盘'), findsOneWidget);
    expect(find.text('115 网盘目录'), findsWidgets);
    expect(find.text('复制并保留源文件'), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-import-job-toggle-9')));
    await tester.pumpAndSettle();

    expect(find.text('可重导'), findsOneWidget);
    expect(find.text('重导'), findsOneWidget);
    expect(find.text('重命名'), findsNothing);
    expect(find.text('删除'), findsNothing);
    // 失败项都是 kind=file → 走文件级重导，不出「重新导入」。
    expect(find.byKey(const Key('media-import-reimport-9')), findsNothing);
  });

  testWidgets('任务级失败（kind=job）的 115 作业出「重新导入」，按 source_cid 重建来源', (
    tester,
  ) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    final job = _jobJson(
      id: 11,
      taskRunId: 61,
      state: 'failed',
      failed: 1,
      sourcePath: '根目录/sakuramedia_downloads',
      sourceCid: 'cid-crashed',
      transferMode: 'cleanup-source',
      failedFiles: <Map<String, dynamic>>[
        <String, dynamic>{
          'path': '根目录/sakuramedia_downloads',
          'reason': 'import_job_crashed',
          'detail': 'http 400 on GET https://webapi.115.com/category/get',
          'kind': 'job',
        },
      ],
    );
    _enqueueJobsPage(bundle, jobs: <Map<String, dynamic>>[job], total: 1);
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/11',
      body: job,
    );

    await _pumpPage(tester, bundle: bundle);
    await tester.tap(find.byKey(const Key('media-import-job-toggle-11')));
    await tester.pumpAndSettle();

    // 任务级条目没有文件级操作，「重导全部失败」不出现，只留整体重新导入。
    expect(find.text('任务级'), findsOneWidget);
    expect(find.byKey(const Key('media-import-retry-all-11')), findsNothing);
    expect(find.text('重导'), findsNothing);
    final reimport = find.byKey(const Key('media-import-reimport-11'));
    expect(reimport, findsOneWidget);

    // 点击后按原参数新建作业，并刷新列表。
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs',
      body: <String, dynamic>{
        'import_job_id': 12,
        'task_run_id': 62,
        'status': 'pending',
      },
    );
    _enqueueJobsPage(bundle, jobs: <Map<String, dynamic>>[job], total: 1);

    await tester.tap(reimport);
    await tester.pumpAndSettle();

    final posted = bundle.adapter.requests.firstWhere(
      (request) => request.method == 'POST' && request.path == '/import-jobs',
    );
    expect(posted.body, <String, dynamic>{
      'library_id': 1,
      'source_cid': 'cid-crashed',
      'transfer_mode': 'cleanup-source',
    });

    await _drainToast(tester);
  });

  testWidgets('任务级失败的本地作业按 source_path 重建来源', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    final job = _jobJson(
      id: 13,
      taskRunId: 71,
      state: 'failed',
      failed: 1,
      sourcePath: '/mnt/incoming/movies',
      failedFiles: <Map<String, dynamic>>[
        <String, dynamic>{
          'path': '/mnt/incoming/movies',
          'reason': 'import_job_interrupted',
          'detail': '',
          'kind': 'job',
        },
      ],
    );
    _enqueueJobsPage(bundle, jobs: <Map<String, dynamic>>[job], total: 1);
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/13',
      body: job,
    );

    await _pumpPage(tester, bundle: bundle);
    await tester.tap(find.byKey(const Key('media-import-job-toggle-13')));
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/import-jobs',
      body: <String, dynamic>{
        'import_job_id': 14,
        'task_run_id': 72,
        'status': 'pending',
      },
    );
    _enqueueJobsPage(bundle, jobs: <Map<String, dynamic>>[job], total: 1);

    await tester.tap(find.byKey(const Key('media-import-reimport-13')));
    await tester.pumpAndSettle();

    final posted = bundle.adapter.requests.firstWhere(
      (request) => request.method == 'POST' && request.path == '/import-jobs',
    );
    expect(posted.body, <String, dynamic>{
      'library_id': 1,
      'source_path': '/mnt/incoming/movies',
      'transfer_mode': 'auto',
    });

    await _drainToast(tester);
  });

  testWidgets('纯跳过作业（failed=0、skipped>0）也能展开，渲染中文原因 + 已跳过徽标', (tester) async {
    _setDesktopViewport(tester);
    final sessionStore = await _createSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    _enqueueJobsPage(
      bundle,
      jobs: <Map<String, dynamic>>[
        _jobJson(
          id: 7,
          taskRunId: 99,
          state: 'completed',
          imported: 3,
          skipped: 2,
        ),
      ],
      total: 1,
    );
    _enqueueBootstrapAndStream(bundle);
    _enqueueVideoJobsPage(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/import-jobs/7',
      body: _jobJson(
        id: 7,
        taskRunId: 99,
        state: 'completed',
        imported: 3,
        skipped: 2,
        failedFiles: <Map<String, dynamic>>[
          <String, dynamic>{
            'path': '/mnt/incoming/movies/DUP-001.mp4',
            'reason': 'already_indexed_path',
            'detail': '',
            'kind': 'skipped',
          },
          <String, dynamic>{
            'path': '/mnt/incoming/movies/DUP-002.mp4',
            'reason': 'duplicate_fingerprint',
            'detail': '',
            'kind': 'skipped',
          },
        ],
      ),
    );

    await _pumpPage(tester, bundle: bundle);

    // failedCount=0 但 skippedCount>0：展开按钮仍出现。
    final toggle = find.byKey(const Key('media-import-job-toggle-7'));
    expect(toggle, findsOneWidget);
    expect(find.text('查看失败/跳过文件'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('/mnt/incoming/movies/DUP-001.mp4'), findsOneWidget);
    expect(find.text('/mnt/incoming/movies/DUP-002.mp4'), findsOneWidget);
    expect(find.textContaining('已在库中'), findsOneWidget);
    expect(find.textContaining('内容重复'), findsOneWidget);
    // 两条都是 skipped → 两个「已跳过」徽标。
    expect(find.text('已跳过'), findsNWidgets(2));
    // actionable 为空 → 「重导全部失败」按钮不出现。
    expect(find.byKey(const Key('media-import-retry-all-7')), findsNothing);
    // 行内不应出现「重导」按钮（skipped 不可操作）。
    expect(find.text('重导'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopMediaImportPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  // 卸载页面以触发 controller.dispose，取消 SSE 重连定时器，避免 pending timer 断言。
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

/// 等 oktoast 的自动消失定时器到期。操作类用例会弹 toast，若不排空，
/// `_pumpPage` 的 teardown 卸载组件时会撞上 "A Timer is still pending" 断言。
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void _setDesktopViewport(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<SessionStore> _createSessionStore() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
  );
  return sessionStore;
}

void _enqueueJobsPage(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> jobs,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/import-jobs',
    body: <String, dynamic>{
      'items': jobs,
      'page': 1,
      'page_size': 20,
      'total': total,
    },
  );
}

/// 资源导入页同时持有 JAV、PornBox 与字幕三个 controller，各自连一次 bootstrap + SSE。
/// 三路响应内容一致（FIFO 按 path 出队），因此每个共享端点入队三次。
void _enqueueBootstrapAndStream(TestApiBundle bundle) {
  _enqueueSubtitleJobsPage(bundle);
  for (var i = 0; i < 3; i++) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/activity/bootstrap',
      body: _bootstrapBody(latestEventId: 120),
    );
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[
        'id: 1\n'
            'event: heartbeat\n'
            'data: {}\n\n',
      ],
    );
  }
}

/// JAV 字幕标签作业列表（`/subtitle-imports`）；影片聚焦用例下默认空列表即可。
void _enqueueSubtitleJobsPage(
  TestApiBundle bundle, {
  List<Map<String, dynamic>> jobs = const <Map<String, dynamic>>[],
  int total = 0,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/subtitle-imports',
    body: <String, dynamic>{
      'items': jobs,
      'page': 1,
      'page_size': 20,
      'total': total,
    },
  );
}

/// PornBox 标签作业列表（`/video-imports`）；JAV 聚焦用例下默认空列表即可。
void _enqueueVideoJobsPage(
  TestApiBundle bundle, {
  List<Map<String, dynamic>> jobs = const <Map<String, dynamic>>[],
  int total = 0,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/video-imports',
    body: <String, dynamic>{
      'items': jobs,
      'page': 1,
      'page_size': 20,
      'total': total,
    },
  );
}

Map<String, dynamic> _bootstrapBody({required int latestEventId}) {
  return <String, dynamic>{
    'latest_event_id': latestEventId,
    'notifications': <String, dynamic>{
      'items': <Map<String, dynamic>>[],
      'page': 1,
      'page_size': 20,
      'total': 0,
    },
    'unread_count': 0,
    'active_task_runs': <Map<String, dynamic>>[],
    'task_runs': <String, dynamic>{
      'items': <Map<String, dynamic>>[],
      'page': 1,
      'page_size': 20,
      'total': 0,
    },
  };
}

Map<String, dynamic> _jobJson({
  required int id,
  required int taskRunId,
  required String state,
  int imported = 0,
  int skipped = 0,
  int failed = 0,
  String sourcePath = '/mnt/incoming/movies',
  String? sourceCid,
  String transferMode = 'auto',
  List<Map<String, dynamic>>? failedFiles,
}) {
  return <String, dynamic>{
    'id': id,
    'source_path': sourcePath,
    if (sourceCid != null) 'source_cid': sourceCid,
    'library_id': 1,
    'task_run_id': taskRunId,
    'state': state,
    'transfer_mode': transferMode,
    'imported_count': imported,
    'skipped_count': skipped,
    'failed_count': failed,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:05:00',
    if (failedFiles != null) 'failed_files': failedFiles,
  };
}

Map<String, dynamic> _subtitleJobJson({
  required int id,
  required int taskRunId,
  required String state,
  int imported = 0,
  int skipped = 0,
  int failed = 0,
  String sourcePath = '/mnt/incoming/subtitles',
  List<Map<String, dynamic>>? failedFiles,
}) {
  return <String, dynamic>{
    'id': id,
    'source_path': sourcePath,
    'task_run_id': taskRunId,
    'state': state,
    'transfer_mode': 'auto',
    'imported_count': imported,
    'skipped_count': skipped,
    'failed_count': failed,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:05:00',
    if (failedFiles != null) 'failed_files': failedFiles,
  };
}

Map<String, dynamic> _taskRunJson({
  required int id,
  required int current,
  required int total,
}) {
  return <String, dynamic>{
    'id': id,
    'task_key': 'media_directory_import',
    'task_name': '媒体导入',
    'trigger_type': 'manual',
    'state': 'running',
    'progress_current': current,
    'progress_total': total,
    'progress_text': '导入中',
    'result_text': null,
    'result_summary': <String, dynamic>{'import_job_id': 3},
    'error_message': null,
    'started_at': '2026-06-07 10:00:00',
    'finished_at': null,
    'created_at': '2026-06-07 10:00:00',
    'updated_at': '2026-06-07 10:01:00',
  };
}
