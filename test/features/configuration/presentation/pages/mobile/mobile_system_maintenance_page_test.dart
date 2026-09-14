import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_system_maintenance_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'mobile-access-token',
      refreshToken: 'mobile-refresh-token',
      expiresAt: DateTime.parse('2026-09-02T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders image-search maintenance card on mobile', (
    tester,
  ) async {
    _enqueueImageSearchStatus(bundle);

    await _pumpPage(tester, bundle);

    expect(
      find.byKey(const Key('mobile-settings-system-maintenance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-system-maintenance-image-search-card')),
      findsOneWidget,
    );
    expect(find.text('重建索引'), findsOneWidget);
  });

  testWidgets('runs and explains media backfill tasks on mobile', (
    tester,
  ) async {
    _enqueueImageSearchStatus(bundle);

    await _pumpPage(tester, bundle);

    expect(find.text('媒体信息回填'), findsOneWidget);
    expect(find.textContaining('补齐时长、分辨率和视频信息'), findsOneWidget);
    expect(find.text('媒体文件哈希补算'), findsOneWidget);
    expect(find.textContaining('用于识别重复媒体'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/jobs/media_video_info_backfill/run',
      body: <String, dynamic>{
        'task_run_id': 1,
        'task_key': 'media_video_info_backfill',
        'state': 'pending',
      },
    );
    await tester.tap(
      find.byKey(
        const Key('mobile-system-maintenance-media_video_info_backfill-run'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      bundle.adapter.hitCount(
        'POST',
        '/system/jobs/media_video_info_backfill/run',
      ),
      1,
    );

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/jobs/media_file_hash_backfill/run',
      body: <String, dynamic>{
        'task_run_id': 2,
        'task_key': 'media_file_hash_backfill',
        'state': 'pending',
      },
    );
    await tester.tap(
      find.byKey(
        const Key('mobile-system-maintenance-media_file_hash_backfill-run'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      bundle.adapter.hitCount(
        'POST',
        '/system/jobs/media_file_hash_backfill/run',
      ),
      1,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('confirms and starts a required image-search rebuild', (
    tester,
  ) async {
    _enqueueImageSearchStatus(
      bundle,
      state: 'rebuild_required',
      indexedSpaceId: 'siglip2-old',
      currentSpaceId: 'siglip2-new',
    );
    await _pumpPage(tester, bundle);

    final resetButton = find.byKey(
      const Key('mobile-system-maintenance-image-search-reset'),
    );
    expect(
      tester.widget<AppButton>(resetButton).variant,
      AppButtonVariant.danger,
    );

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/reset',
      statusCode: 202,
    );
    _enqueueImageSearchStatus(
      bundle,
      state: 'rebuild_required',
      indexedSpaceId: 'siglip2-old',
      currentSpaceId: 'siglip2-new',
      isRebuilding: true,
    );

    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('mobile-system-maintenance-image-search-reset-confirm'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const Key('mobile-system-maintenance-image-search-reset-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/image-search/reset'), 1);
    expect(find.text('重建中'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(WidgetTester tester, TestApiBundle bundle) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          home: const AppPlatformScope(
            platform: AppPlatform.mobile,
            child: Scaffold(body: MobileSystemMaintenancePage()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueImageSearchStatus(
  TestApiBundle bundle, {
  String state = 'ready',
  String? indexedSpaceId,
  String? currentSpaceId,
  bool isRebuilding = false,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{
      'index_space': <String, dynamic>{
        'state': state,
        'indexed_space_id': indexedSpaceId,
        'current_space_id': currentSpaceId,
        'is_rebuilding': isRebuilding,
      },
    },
  );
}
