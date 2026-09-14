import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_drawer.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

void main() {
  testWidgets('移动筛选立即应用分辨率并支持全部与重置', (tester) async {
    final applied = <PlaylistFilterState>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMobilePlaylistFilterDrawer(
                context,
                current: PlaylistFilterState.initial,
                onChanged: applied.add,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('4K'));
    await tester.pumpAndSettle();
    expect(applied.last.resolution, PlaylistResolutionFilter.k4k);
    expect(
      tester
          .widget<AppTextButton>(
            find.byKey(const Key('playlist-filter-resolution-4K')),
          )
          .isSelected,
      isTrue,
    );
    expect(
      find.byKey(const Key('mobile-playlist-filter-drawer')),
      findsOneWidget,
    );
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(applied.last.resolution, isNull);
    await tester.tap(find.text('8K'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(applied.last.isDefault, isTrue);
    expect(tester.takeException(), isNull);
  });
}
