import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T10:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  test(
    'getBootstrap maps snapshot payload and bootstrap query names',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/activity/bootstrap',
        body: <String, dynamic>{
          'latest_event_id': 321,
          'notifications': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 101,
                'category': 'reminder',
                'title': '有新的影片可以播放了',
                'content': '本次后台处理新增可播放影片 1 部：SSIS-123',
                'is_read': false,
                'created_at': '2026-03-26T09:10:00Z',
                'updated_at': '2026-03-26T09:10:00Z',
              },
            ],
            'page': 1,
            'page_size': 20,
            'total': 24,
          },
          'unread_count': 3,
          'active_task_runs': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 88,
              'task_key': 'download_task_import',
              'task_name': '下载任务导入 SSIS-123',
              'trigger_type': 'manual',
              'state': 'running',
              'progress_current': 1,
              'progress_total': 3,
              'progress_text': '正在导入影片文件 SSIS-123',
              'created_at': '2026-03-26T09:10:00Z',
              'updated_at': '2026-03-26T09:11:00Z',
            },
          ],
          'task_runs': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 201,
                'task_key': 'download_task_import',
                'task_name': '下载任务导入 201',
                'trigger_type': 'manual',
                'state': 'completed',
                'progress_current': 3,
                'progress_total': 3,
                'progress_text': '导入完成',
                'created_at': '2026-03-26T09:10:00Z',
                'updated_at': '2026-03-26T09:20:00Z',
              },
            ],
            'page': 1,
            'page_size': 20,
            'total': 1,
          },
        },
      );

      final response = await bundle.activityApi.getBootstrap(
        notificationCategory: 'reminder',
        taskState: 'running',
        taskKey: 'download_task_import',
        taskTriggerType: 'manual',
        taskSort: 'started_at:desc',
      );

      expect(response.latestEventId, 321);
      expect(response.notifications.items.single.id, 101);
      expect(response.unreadCount, 3);
      expect(response.activeTaskRuns.single.id, 88);
      expect(response.taskRuns.items.single.id, 201);
      final request = bundle.adapter.requests.single;
      expect(request.uri.queryParameters['notification_category'], 'reminder');
      expect(
        request.uri.queryParameters.containsKey('notification_level'),
        isFalse,
      );
      expect(
        request.uri.queryParameters.containsKey('notification_archived'),
        isFalse,
      );
      expect(request.uri.queryParameters['task_state'], 'running');
      expect(request.uri.queryParameters['task_key'], 'download_task_import');
      expect(request.uri.queryParameters['task_trigger_type'], 'manual');
      expect(request.uri.queryParameters['task_sort'], 'started_at:desc');
    },
  );

  test('getNotifications maps filters and pagination', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/notifications',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'category': 'reminder',
            'title': '有新的影片可以播放了',
            'content': '本次后台处理新增可播放影片 1 部：SSIS-123',
            'is_read': false,
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:10:00Z',
          },
        ],
        'page': 2,
        'page_size': 10,
        'total': 24,
      },
    );

    final response = await bundle.activityApi.getNotifications(
      page: 2,
      pageSize: 10,
      category: 'reminder',
    );

    expect(response.items.single.id, 101);
    expect(response.total, 24);
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '10');
    expect(request.uri.queryParameters['category'], 'reminder');
    expect(request.uri.queryParameters.containsKey('level'), isFalse);
    expect(request.uri.queryParameters.containsKey('archived'), isFalse);
  });

  test('markNotificationsRead posts ids and maps read result', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read',
      body: <String, dynamic>{'updated_count': 3, 'unread_count': 5},
    );

    final result = await bundle.activityApi.markNotificationsRead(<int>[
      1,
      2,
      3,
    ]);

    expect(result.updatedCount, 3);
    expect(result.unreadCount, 5);
    final request = bundle.adapter.requests.single;
    expect(request.method.toUpperCase(), 'POST');
    expect(request.path, '/system/notifications/read');
    expect(request.body, <String, dynamic>{
      'ids': <int>[1, 2, 3],
    });
  });

  test('markAllNotificationsRead posts read-all and maps result', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read-all',
      body: <String, dynamic>{'updated_count': 8, 'unread_count': 0},
    );

    final result = await bundle.activityApi.markAllNotificationsRead();

    expect(result.updatedCount, 8);
    expect(result.unreadCount, 0);
    expect(
      bundle.adapter.hitCount('POST', '/system/notifications/read-all'),
      1,
    );
  });

  test('getTaskRuns maps filters and sort', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 88,
            'task_key': 'download_task_import',
            'task_name': '下载任务导入 SSIS-123',
            'trigger_type': 'manual',
            'state': 'running',
            'progress_current': 1,
            'progress_total': 3,
            'progress_text': '正在导入影片文件 SSIS-123',
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:11:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final response = await bundle.activityApi.getTaskRuns(
      state: 'running',
      taskKey: 'download_task_import',
      triggerType: 'manual',
      sort: 'started_at:desc',
    );

    expect(response.items.single.taskKey, 'download_task_import');
    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters['state'], 'running');
    expect(request.uri.queryParameters['task_key'], 'download_task_import');
    expect(request.uri.queryParameters['trigger_type'], 'manual');
    expect(request.uri.queryParameters['sort'], 'started_at:desc');
  });

  test('getJobs maps system job metadata and last task run', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/jobs',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'task_key': 'example_plugin_sync',
          'plugin_id': 'example_plugin',
          'log_name': 'example-plugin-sync',
          'cli_name': 'sync-example-plugin',
          'cli_help': '执行一次插件任务',
          'cron_setting':
              'plugins.job_crons.example_plugin.example_plugin_sync',
          'cron_expr': '0 2 * * *',
          'manual_trigger_allowed': true,
          'params_schema': <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{
              'movie_number': <String, dynamic>{'type': 'string'},
            },
            'required': <String>['movie_number'],
          },
          'last_task_run': <String, dynamic>{
            'id': 88,
            'task_key': 'example_plugin_sync',
            'task_name': '插件任务执行',
            'trigger_type': 'manual',
            'state': 'completed',
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:20:00Z',
          },
        },
      ],
    );

    final jobs = await bundle.activityApi.getJobs();

    expect(jobs, hasLength(1));
    expect(jobs.first.taskKey, 'example_plugin_sync');
    expect(jobs.first.manualTriggerAllowed, isTrue);
    expect(
      jobs.first.paramsSchema?['properties'],
      containsPair('movie_number', containsPair('type', 'string')),
    );
    expect(jobs.first.lastTaskRun?.id, 88);
    expect(bundle.adapter.hitCount('GET', '/system/jobs'), 1);
  });

  test('triggerJob maps manual job run endpoint', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/jobs/example_plugin_sync/run',
      body: <String, dynamic>{
        'task_run_id': 13,
        'task_key': 'example_plugin_sync',
        'state': 'pending',
      },
    );

    final response = await bundle.activityApi.triggerJob(
      taskKey: 'example_plugin_sync',
      params: <String, dynamic>{'movie_number': 'SSIS-123'},
    );

    expect(response.taskRunId, 13);
    expect(response.taskKey, 'example_plugin_sync');
    expect(response.state, 'pending');
    expect(bundle.adapter.requests.single.body, <String, dynamic>{
      'movie_number': 'SSIS-123',
    });
    expect(
      bundle.adapter.hitCount('POST', '/system/jobs/example_plugin_sync/run'),
      1,
    );
  });

  test('applyResourceTaskAction posts resource ids and maps result', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      body: <String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'action': 'reset_retry_budget',
        'task_run_id': null,
        'accepted_resource_ids': <int>[101, 202],
        'skipped': <Map<String, dynamic>>[
          <String, dynamic>{'resource_id': 303, 'reason': 'media_invalid'},
        ],
      },
    );

    final result = await bundle.activityApi.applyResourceTaskAction(
      taskKey: 'media_thumbnail_generation',
      action: 'reset_retry_budget',
      resourceIds: <int>[101, 202, 303],
    );

    expect(result.taskKey, 'media_thumbnail_generation');
    expect(result.action, 'reset_retry_budget');
    expect(result.taskRunId, isNull);
    expect(result.acceptedResourceIds, <int>[101, 202]);
    expect(result.acceptedCount, 2);
    expect(result.skippedCount, 1);
    expect(result.skipped.single.resourceId, 303);
    expect(result.skipped.single.reasonLabel, '媒体已失效');

    final request = bundle.adapter.requests.single;
    expect(request.method.toUpperCase(), 'POST');
    expect(request.path, '/system/resource-task-actions');
    expect(request.body, <String, dynamic>{
      'task_key': 'media_thumbnail_generation',
      'action': 'reset_retry_budget',
      'resource_ids': <int>[101, 202, 303],
    });
  });

  test(
    'applyResourceTaskAction omits resource ids and scopes by state',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/system/resource-task-actions',
        body: <String, dynamic>{
          'task_key': 'subscribed_movie_auto_download',
          'action': 'reset_retry_budget',
          'task_run_id': null,
          'accepted_resource_ids': <int>[7, 8, 9],
          'skipped': <Map<String, dynamic>>[],
        },
      );

      final result = await bundle.activityApi.applyResourceTaskAction(
        taskKey: 'subscribed_movie_auto_download',
        action: 'reset_retry_budget',
        state: 'exhausted',
      );

      expect(result.acceptedCount, 3);
      expect(result.hasSkipped, isFalse);

      // 批量按状态圈定：请求体不携带 resource_ids 键。
      final request = bundle.adapter.requests.single;
      expect(request.body, <String, dynamic>{
        'task_key': 'subscribed_movie_auto_download',
        'action': 'reset_retry_budget',
        'state': 'exhausted',
      });
    },
  );

  test('applyResourceTaskAction returns trackable run for rerun', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/resource-task-actions',
      body: <String, dynamic>{
        'task_key': 'movie_interaction_sync',
        'action': 'rerun',
        'task_run_id': 42,
        'accepted_resource_ids': <int>[11],
        'skipped': <Map<String, dynamic>>[],
      },
    );

    final result = await bundle.activityApi.applyResourceTaskAction(
      taskKey: 'movie_interaction_sync',
      action: 'rerun',
      resourceIds: <int>[11],
    );

    expect(result.taskRunId, 42);
    expect(result.acceptedResourceIds, <int>[11]);
  });

  test('streamEvents maps notification, task and read payloads', () async {
    bundle.adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: const <String>[
        'id: 121\n'
            'event: notification_created\n'
            'data: {"id":101,"category":"reminder","title":"有新的影片可以播放了","content":"ok","is_read":false}\n\n',
        'id: 122\n'
            'event: task_run_updated\n'
            'data: {"id":88,"task_key":"download_task_import","task_name":"下载任务导入 SSIS-123","trigger_type":"manual","state":"running","progress_current":2,"progress_total":3,"progress_text":"正在导入影片文件 SSIS-123","created_at":"2026-03-26T09:10:00Z","updated_at":"2026-03-26T09:11:00Z"}\n\n',
        'id: 123\n'
            'event: notifications_read\n'
            'data: {"ids":[101,102],"unread_count":4}\n\n',
        'id: 124\n'
            'event: notifications_read_all\n'
            'data: {"unread_count":0}\n\n',
      ],
    );

    final events = await bundle.activityApi
        .streamEvents(afterEventId: 120)
        .toList();

    expect(events[0].id, 121);
    expect(events[0].notification?.id, 101);
    expect(events[1].id, 122);
    expect(events[1].taskRun?.id, 88);
    expect(events[2].isNotificationsRead, isTrue);
    expect(events[2].notificationIds, <int>[101, 102]);
    expect(events[2].unreadCount, 4);
    expect(events[3].isNotificationsReadAll, isTrue);
    expect(events[3].unreadCount, 0);
  });
}
