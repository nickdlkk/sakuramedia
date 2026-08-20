import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/subtitle_import_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late SubtitleImportApi api;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    api = SubtitleImportApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  test(
    'createImportJob only sends source_path and parses the accepted task',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/subtitle-imports',
        statusCode: 202,
        body: <String, dynamic>{
          'subtitle_import_job_id': 7,
          'task_run_id': 42,
          'status': 'accepted',
        },
      );

      final response = await api.createImportJob(
        sourcePath: '/mnt/incoming/subtitles',
      );

      expect(response.subtitleImportJobId, 7);
      expect(response.taskRunId, 42);
      expect(response.status, 'accepted');
      expect(adapter.requests.single.body, <String, dynamic>{
        'source_path': '/mnt/incoming/subtitles',
      });
    },
  );

  test(
    'listImportJobs parses a subtitle job without media-library semantics',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/subtitle-imports',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _jobJson(id: 3, taskRunId: 42, state: 'completed', imported: 2),
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );

      final page = await api.listImportJobs();

      final job = page.items.single;
      expect(job.sourcePath, '/mnt/incoming/subtitles');
      expect(job.importedCount, 2);
      expect(job.importModeLabel, isNull);
      expect(job.isCloud115, isFalse);
      expect(job.canMutateFailedSource, isTrue);
      expect(job.canReimport, isTrue);
    },
  );

  test('failure-file operations target subtitle import endpoints', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/subtitle-imports/3/retry',
      statusCode: 202,
      body: <String, dynamic>{
        'subtitle_import_job_id': 4,
        'task_run_id': 43,
        'status': 'accepted',
      },
    );
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/subtitle-imports/3/failed-files',
      body: _jobJson(
        id: 3,
        taskRunId: 42,
        state: 'completed',
        failedFiles: const <Map<String, dynamic>>[],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/subtitle-imports/3/failed-files/rename',
      body: _jobJson(
        id: 3,
        taskRunId: 42,
        state: 'completed',
        failedFiles: const <Map<String, dynamic>>[],
      ),
    );

    await api.retryFailedFiles(
      3,
      files: const <String>['/mnt/incoming/bad.srt'],
    );
    await api.deleteFailedFile(3, path: '/mnt/incoming/bad.srt');
    await api.renameFailedFile(
      3,
      path: '/mnt/incoming/bad.srt',
      newName: 'ABP-123.cht.srt',
    );

    expect(adapter.requests[0].body, <String, dynamic>{
      'files': <String>['/mnt/incoming/bad.srt'],
    });
    expect(adapter.requests[1].body, <String, dynamic>{
      'path': '/mnt/incoming/bad.srt',
    });
    expect(adapter.requests[2].body, <String, dynamic>{
      'path': '/mnt/incoming/bad.srt',
      'new_name': 'ABP-123.cht.srt',
    });
  });
}

Map<String, dynamic> _jobJson({
  required int id,
  required int taskRunId,
  required String state,
  int imported = 0,
  int skipped = 0,
  int failed = 0,
  List<Map<String, dynamic>>? failedFiles,
}) {
  return <String, dynamic>{
    'id': id,
    'source_path': '/mnt/incoming/subtitles',
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
