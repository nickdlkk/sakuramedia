import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 影片筛选面板的行为测试。宿主是列表顶栏 `AppListHeader` 的就地浮层——原先挂在
/// 已删除的 `MovieFilterToolbar` 上，断言内容不变。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('普通影片库年份固定覆盖当前年到 2008 年且不带统计数量', () {
    final options = buildDefaultMovieFilterYearOptions(currentYear: 2026);

    expect(options.first.year, 2026);
    expect(options.last.year, movieFilterEarliestYear);
    expect(options, hasLength(19));
    expect(options.first.movieCount, isNull);
    expect(options.first.label, '2026');
  });

  Widget wrapHeader({
    required MovieFilterState filterState,
    required ValueChanged<MovieFilterState> onChanged,
    required VoidCallback onReset,
    List<MovieFilterYearOption>? yearOptions,
  }) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: AppListHeader(
            filterButtonKey: const Key('movies-filter-trigger'),
            filterLabel: filterState.triggerLabel,
            filterPanelKey: const Key('movies-filter-panel'),
            filterPanelExtraWidth: 260,
            filterPanelBuilder: (_) => MovieFilterSectionGroup(
              filterState: filterState,
              onChanged: onChanged,
              yearOptions: yearOptions,
            ),
            filterPanelFooter: AppFilterPanelFooter(
              isDefault: filterState.isDefault,
              onReset: onReset,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('影片筛选面板将长年份列表收为两行并可展开', (WidgetTester tester) async {
    final yearOptions = List<MovieFilterYearOption>.generate(
      30,
      (index) => MovieFilterYearOption(year: 2026 - index, movieCount: 1),
    );
    var filterState = MovieFilterState.initial;
    MovieFilterState? changedState;
    var resetCount = 0;

    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => wrapHeader(
          filterState: filterState,
          yearOptions: yearOptions,
          onChanged: (nextState) {
            changedState = nextState;
            setState(() => filterState = nextState);
          },
          onReset: () {
            resetCount += 1;
            setState(() => filterState = MovieFilterState.initial);
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movies-filter-trigger')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('movies-filter-panel')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('movies-filter-panel'))).height,
      lessThanOrEqualTo(420),
    );
    expect(find.text('重置'), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byKey(const Key('movies-filter-panel')),
      matching: find.byType(Scrollable),
    );
    expect(find.text('1997(1)'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('movie-filter-year-expand-toggle')),
      160,
      scrollable: scrollable.first,
    );
    expect(find.text('展开全部年份'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-filter-year-expand-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('收起年份'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1997(1)'),
      160,
      scrollable: scrollable.first,
    );
    await tester.tap(find.text('1997(1)'));
    await tester.pumpAndSettle();

    expect(changedState?.year, 1997);
    expect(find.text('重置'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    expect(resetCount, 1);
    expect(filterState.year, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通影片库使用前端年份范围，不展示后端统计数量', (WidgetTester tester) async {
    final currentYear = DateTime.now().year;
    var filterState = MovieFilterState.initial;
    MovieFilterState? changedState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => wrapHeader(
          filterState: filterState,
          onChanged: (nextState) {
            changedState = nextState;
            setState(() => filterState = nextState);
          },
          onReset: () => setState(() => filterState = MovieFilterState.initial),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movies-filter-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('$currentYear'), findsOneWidget);
    expect(find.text('$currentYear(1)'), findsNothing);

    await tester.tap(find.byKey(Key('movie-filter-year-$currentYear')));
    await tester.pumpAndSettle();

    expect(changedState?.year, currentYear);
  });

  testWidgets('影片筛选面板可选 FC2 番号来源并重置回默认', (WidgetTester tester) async {
    var filterState = MovieFilterState.initial;
    MovieFilterState? changedState;

    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => wrapHeader(
          filterState: filterState,
          onChanged: (nextState) {
            changedState = nextState;
            setState(() => filterState = nextState);
          },
          onReset: () {
            setState(() => filterState = MovieFilterState.initial);
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movies-filter-trigger')));
    await tester.pumpAndSettle();

    // 默认筛选下「番号来源」分组存在且选中「全部」。
    expect(find.text('番号来源'), findsOneWidget);
    expect(filterState.numberSource, MovieNumberSourceFilter.all);

    await tester.tap(find.text('FC2'));
    await tester.pumpAndSettle();

    expect(changedState?.numberSource, MovieNumberSourceFilter.fc2);
    expect(filterState.isDefault, isFalse);
    expect(find.text('重置'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    expect(filterState.numberSource, MovieNumberSourceFilter.all);
    expect(filterState.isDefault, isTrue);
    expect(tester.takeException(), isNull);
  });
}
