import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  late TestApiBundle bundle;

  setUp(() async {
    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    bundle = await createTestApiBundle(session);
  });

  tearDown(() {
    bundle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> pumpPage(
    WidgetTester tester,
    TargetPlatform platform, {
    int count = 1,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _page('ABC-001', count: count),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData.copyWith(platform: platform),
            home: const Scaffold(body: MobileMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Completer<ResponseBody> holdRequest() {
    final response = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/movies',
      responder: (_, __) => response.future,
    );
    addTearDown(() {
      if (!response.isCompleted) response.complete(_response('ABC-002'));
    });
    return response;
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform 列表滚动时筛选栏固定且不重复请求', (tester) async {
      await pumpPage(tester, platform, count: 40);
      final header = find.byKey(const Key('mobile-movies-filter-button'));
      final initialTop = tester.getTopLeft(header).dy;
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(500);
      await tester.pump();
      expect(tester.getTopLeft(header).dy, initialTop);
      expect(scroll.offset, 500);
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);
      scroll.jumpTo(0);
      await tester.pump();
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$platform 下拉刷新失败保留列表，后续刷新仍可正常完成', (tester) async {
      await pumpPage(tester, platform);
      final failed = holdRequest();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('app-filter-result-loading-overlay')),
        findsNothing,
      );
      failed.complete(
        ResponseBody.fromString(
          '{}',
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
      final retry = holdRequest();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('app-filter-result-loading-overlay')),
        findsNothing,
      );
      retry.complete(_response('ABC-002'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-summary-card-ABC-002')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$platform 下拉刷新只显示顶部加载图标，完成后筛选仍有加载反馈', (tester) async {
      await pumpPage(tester, platform);
      final refresh = holdRequest();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));

      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('app-filter-result-loading-overlay')),
        findsNothing,
      );
      expect(
        platform == TargetPlatform.iOS
            ? find.byType(CupertinoActivityIndicator)
            : find.byType(RefreshProgressIndicator),
        findsOneWidget,
      );

      refresh.complete(_response('ABC-002'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-summary-card-ABC-002')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsNothing);

      final filterResponse = holdRequest();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MobileMoviesPage)),
      );
      unawaited(
        container
            .read(
              movieSummaryProvider(
                const MovieSummaryScope.movies(cacheKey: 'mobile:movies:list'),
              ).notifier,
            )
            .applyMovieFilter(
              MovieFilterState.initial.copyWith(
                status: MovieStatusFilter.subscribed,
              ),
            ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('app-filter-result-loading-overlay')),
        findsOneWidget,
      );
      filterResponse.complete(_response('ABC-003'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('app-filter-result-loading-overlay')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

Map<String, dynamic> _page(String number, {int count = 1}) => {
  'items': [
    for (var i = 0; i < count; i++)
      {
        'javdb_id': '$number-$i',
        'movie_number': i == 0 ? number : '$number-$i',
        'title': number,
        'cover_image': null,
        'is_subscribed': false,
        'can_play': false,
      },
  ],
  'page': 1,
  'page_size': 24,
  'total': count,
};

ResponseBody _response(String number) => ResponseBody.fromString(
  jsonEncode(_page(number)),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
