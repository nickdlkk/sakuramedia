import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

import '../../../../../support/test_api_bundle.dart';

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
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  void enqueueInitialLoad({int total = 2}) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: _actorJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: total),
    );
  }

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets('资料滚走后筛选栏吸顶，切筛选回到影片起点', (tester) async {
    enqueueInitialLoad(total: 40);
    await tester.pumpWidget(wrap(const MobileActorDetailPage(actorId: 1)));
    await tester.pumpAndSettle();
    final header = find.byKey(const Key('actor-detail-filter-trigger'));
    final initialTop = tester.getTopLeft(header).dy;
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    scroll.jumpTo(500);
    await tester.pump();
    final pinnedTop = tester.getTopLeft(header).dy;
    expect(pinnedTop, lessThan(initialTop));
    scroll.jumpTo(800);
    await tester.pump();
    expect(tester.getTopLeft(header).dy, pinnedTop);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1/years',
      body: [],
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 40),
    );
    await tester.tap(find.text('未订阅'));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(scroll.offset, lessThan(500));
    Navigator.of(
      tester.element(find.byKey(const Key('mobile-movies-filter-drawer'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(header).dy, pinnedTop);
    expect(tester.takeException(), isNull);
  });

  testWidgets('影片筛选走底部抽屉，而不是桌面就地浮层', (WidgetTester tester) async {
    enqueueInitialLoad();

    await tester.pumpWidget(wrap(const MobileActorDetailPage(actorId: 1)));
    await tester.pumpAndSettle();

    expect(find.byType(AppListHeader), findsOneWidget);

    // 打开筛选会懒加载年份选项。
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1/years',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'year': 2024, 'movie_count': 2},
      ],
    );

    await tester.tap(find.byKey(const Key('actor-detail-filter-trigger')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-movies-filter-drawer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('actor-detail-filter-panel')), findsNothing);
    // 年份分节在弹抽屉前已取回，不会停在转圈态（抽屉内容是打开瞬间的快照）。
    expect(find.text('发行年份'), findsOneWidget);
    expect(find.text('2024(2)'), findsOneWidget);
  });

  testWidgets('多选走移动布局：顶栏只留计数/全选，批量动作在底部条且不溢出', (WidgetTester tester) async {
    // 移动壳 body 左右各留 AppPageInsets.compact(8)，390 屏的可用宽是 374。
    // 桌面式一行 toolbar 在这个宽度下会 RenderFlex 溢出，故必须走移动布局。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(374, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    enqueueInitialLoad();

    await tester.pumpWidget(wrap(const MobileActorDetailPage(actorId: 1)));
    await tester.pumpAndSettle();

    // 移动端多选入口挂在卡片长按上，顶栏不常驻「选择」。
    expect(
      find.byKey(const Key('actor-detail-enter-selection-button')),
      findsNothing,
    );

    await tester.longPress(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('app-list-header-selection-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('actor-detail-batch-bottom-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('actor-detail-batch-blacklist-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/blacklist',
      statusCode: 204,
    );
    await tester.tap(
      find.byKey(const Key('actor-detail-batch-blacklist-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('actor-detail-batch-blacklist-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsNothing);
    expect(find.byKey(const Key('movie-summary-card-ABC-002')), findsOneWidget);
    expect(
      find.byKey(const Key('actor-detail-batch-bottom-bar')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('长按菜单屏蔽单片后立即移除影片并更新总数', (tester) async {
    enqueueInitialLoad();
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/blacklist',
      statusCode: 204,
    );
    await tester.pumpWidget(wrap(const MobileActorDetailPage(actorId: 1)));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('屏蔽影片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('屏蔽'));
    await tester.pumpAndSettle();
    expect(bundle.adapter.requests.singleWhere((r) => r.method == 'PUT').body, {
      'movie_numbers': ['ABC-001'],
    });
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsNothing);
    expect(find.byKey(const Key('movie-summary-card-ABC-002')), findsOneWidget);
    expect(find.text('作品 · 1 部'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _actorJson() {
  return <String, dynamic>{
    'id': 1,
    'javdb_id': 'javdb-1',
    'name': '演员一号',
    'alias_name': '',
    'profile_image': null,
    'is_subscribed': false,
  };
}

Map<String, dynamic> _moviesJson({int total = 2}) {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      for (var index = 0; index < total; index++)
        <String, dynamic>{
          'javdb_id': 'MovieA$index',
          'movie_number': 'ABC-00${index + 1}',
          'title': 'Movie $index',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
        },
    ],
    'page': 1,
    'page_size': 24,
    'total': total,
  };
}
