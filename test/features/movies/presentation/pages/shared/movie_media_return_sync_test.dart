import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actor_detail_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_detail_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final scenario in ['last', 'remaining', 'failure']) {
      testWidgets('${mobile ? '移动' : '桌面'}女优列表删除资源返回同步：$scenario', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(430, 932)
            : const Size(1280, 1600);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final session = SessionStore.inMemory();
        await session.saveBaseUrl('https://api.example.com');
        await session.saveTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime(2099),
        );
        final bundle = await createTestApiBundle(session);
        addTearDown(() {
          bundle.dispose();
          session.dispose();
        });
        final adapter = bundle.adapter;
        adapter.enqueueJson(
          method: 'GET',
          path: '/actors/1',
          body: {'id': 1, 'name': '演员一号'},
        );
        adapter.enqueueJson(
          method: 'GET',
          path: '/movies',
          body: {
            'items': [
              {
                'movie_number': 'ABC-001',
                'title': 'Movie 1',
                'can_play': true,
                'is_subscribed': false,
              },
            ],
            'page': 1,
            'page_size': 24,
            'total': 1,
          },
        );
        adapter.enqueueJson(
          method: 'GET',
          path: '/movies/ABC-001',
          body: _detail(scenario == 'remaining' ? [1, 2] : [1]),
        );
        adapter.setFallbackJson(
          method: 'GET',
          path: '/movies/ABC-001/similar',
          body: {'items': []},
        );
        adapter.setFallbackJson(
          method: 'GET',
          path: '/movies/ABC-001/collection-status',
          body: {'is_collection': false},
        );
        adapter.setFallbackJson(
          method: 'GET',
          path: '/media-libraries',
          body: [],
        );
        final platform = mobile ? 'mobile' : 'desktop';
        final router = GoRouter(
          initialLocation: '/$platform/library/actors/1',
          routes: [
            GoRoute(
              path: '/$platform/library/actors/:actorId',
              builder: (_, __) => Scaffold(
                body: mobile
                    ? const MobileActorDetailPage(actorId: 1)
                    : const DesktopActorDetailPage(actorId: 1),
              ),
            ),
            GoRoute(
              path: '/$platform/library/movies/:movieNumber',
              builder: (_, __) => Scaffold(
                body: mobile
                    ? const MobileMovieDetailPage(movieNumber: 'ABC-001')
                    : const DesktopMovieDetailPage(movieNumber: 'ABC-001'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: bundle.riverpodOverrides(),
            child: OKToast(
              child: MaterialApp.router(
                theme: sakuraThemeData,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const Key('movie-summary-card-ABC-001'));
        final playable = find.byKey(
          const Key('movie-summary-card-status-playable-ABC-001'),
        );
        expect(playable, findsOneWidget);
        await tester.tap(card);
        await tester.pumpAndSettle();
        adapter.enqueueJson(
          method: 'DELETE',
          path: '/media/1',
          statusCode: scenario == 'failure' ? 500 : 204,
        );
        if (scenario != 'failure') {
          adapter.enqueueJson(
            method: 'GET',
            path: '/movies/ABC-001',
            body: _detail(scenario == 'remaining' ? [2] : [], subscribed: true),
          );
        }
        final delete = find.byKey(const Key('movie-media-delete-button'));
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('movie-media-delete-confirm')));
        await tester.pumpAndSettle();
        expect(adapter.hitCount('DELETE', '/media/1'), 1);
        router.pop();
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(playable, scenario == 'last' ? findsNothing : findsOneWidget);
        final badge = tester.widget<SubscriptionHeartBadge>(
          find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
        );
        expect(badge.isSubscribed, scenario != 'failure');
        expect(adapter.hitCount('GET', '/movies'), 1);
        expect(
          adapter.hitCount('GET', '/movies/ABC-001'),
          scenario == 'failure' ? 1 : 2,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

Map<String, dynamic> _detail(List<int> mediaIds, {bool subscribed = false}) => {
  'movie_number': 'ABC-001',
  'title': 'Movie 1',
  'can_play': mediaIds.isNotEmpty,
  'is_subscribed': subscribed,
  'media_items': [
    for (final id in mediaIds)
      {
        'media_id': id,
        'file_name': 'ABC-001-$id.mp4',
        'valid': true,
        'points': <dynamic>[],
      },
  ],
};
