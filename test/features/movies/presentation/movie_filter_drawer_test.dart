import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('影片筛选抽屉与桌面面板同构且即时生效', (tester) async {
    final applied = <MovieFilterState>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showMobileMovieFilterDrawer(
                  context,
                  current: MovieFilterState.initial,
                  onChanged: applied.add,
                );
              },
              child: const Text('打开筛选'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();

    // 抽屉内容与桌面浮层面板同构：只有筛选分节 + footer，没有标题行、
    // 没有快捷筛选、没有确定按钮。
    expect(find.text('状态筛选'), findsOneWidget);
    expect(find.text('合集类型'), findsOneWidget);
    expect(find.byKey(const Key('movie-filter-heat-section-title')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2w'), findsOneWidget);
    expect(find.text('${DateTime.now().year}'), findsOneWidget);
    expect(find.text('筛选'), findsNothing);
    expect(find.text('确定'), findsNothing);
    expect(find.text('完成'), findsNothing);

    await tester.tap(find.text('已订阅'));
    await tester.pumpAndSettle();

    // 点完立刻生效，抽屉不关。
    expect(applied, hasLength(1));
    expect(applied.single.status, MovieStatusFilter.subscribed);
    expect(find.text('状态筛选'), findsOneWidget);

    // 未订阅与已订阅互补相邻，同样是即时生效。
    await tester.tap(find.text('未订阅'));
    await tester.pumpAndSettle();

    expect(applied, hasLength(2));
    expect(applied.last.status, MovieStatusFilter.unsubscribed);

    // 热度双滑块：拖右 thumb 松手才应用，且滑到顶之前传具体上限。
    final slider = find.byKey(const Key('movie-filter-heat-slider'));
    final rect = tester.getRect(slider);
    await tester.dragFrom(
      Offset(rect.right - 12, rect.center.dy),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    expect(applied, hasLength(3));
    final heatApplied = applied.last;
    expect(heatApplied.heatMin, isNull);
    expect(heatApplied.heatMax, isNotNull);
    expect(heatApplied.heatMax, lessThan(movieFilterHeatSliderMax));

    // 左 thumb 同样松手才生效：下限非 0 时映射为具体的 heat_min。
    await tester.dragFrom(
      Offset(rect.left + 12, rect.center.dy),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(applied, hasLength(4));
    expect(applied.last.heatMin, isNotNull);
    expect(applied.last.heatMin, greaterThan(0));

    // 重置在 footer 里，与桌面面板同一个 AppFilterPanelFooter；
    // 重置后热度条件一并清空，滑块回到 0 ~ 2w。
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    expect(applied, hasLength(5));
    expect(applied.last.isDefault, isTrue);
    expect(applied.last.heatMin, isNull);
    expect(applied.last.heatMax, isNull);
  });
}
