import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSections(
    WidgetTester tester, {
    PlaylistFilterState filterState = PlaylistFilterState.initial,
    required ValueChanged<PlaylistFilterState> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: SingleChildScrollView(
            child: PlaylistFilterSectionGroup(
              filterState: filterState,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('固定展示全部分辨率档位', (tester) async {
    await pumpSections(tester, onChanged: (_) {});
    for (final label in [
      '全部',
      '8K',
      '4K',
      '2K',
      '1080P',
      '720P',
      '480P',
      '360P',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('渲染全部排序字段 chip 且 sortField 为 null 时隐藏方向分节', (tester) async {
    await pumpSections(
      tester,
      filterState: PlaylistFilterState.initial,
      onChanged: (_) {},
    );

    expect(
      find.byKey(const Key('playlist-filter-sort-recent')),
      findsOneWidget,
    );
    for (final field in PlaylistSortField.values) {
      expect(
        find.byKey(Key('playlist-filter-sort-${field.apiValue}')),
        findsOneWidget,
      );
    }
    expect(find.text('升降序'), findsNothing);
  });

  testWidgets('选了排序字段后展示方向分节', (tester) async {
    await pumpSections(
      tester,
      filterState: PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.heat,
      ),
      onChanged: (_) {},
    );

    expect(find.text('升降序'), findsOneWidget);
    expect(
      find.byKey(const Key('playlist-filter-sort-direction-desc')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('playlist-filter-sort-direction-asc')),
      findsOneWidget,
    );
  });

  testWidgets('点击排序 chip 回传该字段，点击最近触达回传 null', (tester) async {
    final sortFields = <PlaylistSortField?>[];
    await pumpSections(
      tester,
      filterState: PlaylistFilterState.initial,
      onChanged: (state) => sortFields.add(state.sortField),
    );

    await tester.tap(find.byKey(const Key('playlist-filter-sort-heat')));
    await tester.tap(find.byKey(const Key('playlist-filter-sort-recent')));

    expect(sortFields, <PlaylistSortField?>[PlaylistSortField.heat, null]);
  });

  testWidgets('点击方向 chip 回传对应升降序', (tester) async {
    SortDirection? lastDirection;
    await pumpSections(
      tester,
      filterState: PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.addedAt,
      ),
      onChanged: (state) => lastDirection = state.sortDirection,
    );

    await tester.tap(
      find.byKey(const Key('playlist-filter-sort-direction-asc')),
    );

    expect(lastDirection, SortDirection.asc);
  });

  testWidgets('点击分辨率 chip 回传对应档位，点击全部回传 null', (tester) async {
    final resolutions = <PlaylistResolutionFilter?>[];
    await pumpSections(
      tester,
      onChanged: (state) => resolutions.add(state.resolution),
    );

    await tester.tap(find.byKey(const Key('playlist-filter-resolution-4K')));
    await tester.tap(find.byKey(const Key('playlist-filter-resolution-all')));

    expect(resolutions, <PlaylistResolutionFilter?>[
      PlaylistResolutionFilter.k4k,
      null,
    ]);
  });
}
