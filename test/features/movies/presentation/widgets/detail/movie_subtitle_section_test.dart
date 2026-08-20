import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_section.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('renders subtitle files and opens the tapped file', (
    WidgetTester tester,
  ) async {
    MovieSubtitleItemDto? opened;
    final item = MovieSubtitleItemDto(
      subtitleId: 501,
      fileName: 'ABC-001.zh.srt',
      createdAt: DateTime.parse('2026-08-17T12:30:00Z'),
      url: '/files/subtitles/501?signature=test',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieSubtitleSection(
            items: <MovieSubtitleItemDto>[item],
            onOpenSubtitle: (value) async {
              opened = value;
            },
          ),
        ),
      ),
    );

    expect(find.text('ABC-001.zh.srt'), findsOneWidget);
    expect(find.text('2026-08-17 20:30'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('movie-subtitle-item-501'))).height,
      lessThan(40),
    );

    await tester.tap(find.byKey(const Key('movie-subtitle-item-501')));
    await tester.pump();

    expect(opened, same(item));
  });

  testWidgets('shows empty state when no subtitle file is available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: const Scaffold(
          body: MovieSubtitleSection(items: <MovieSubtitleItemDto>[]),
        ),
      ),
    );

    expect(find.byKey(const Key('movie-subtitles-empty')), findsOneWidget);
    expect(find.text('暂无可用字幕'), findsOneWidget);
  });

  testWidgets('falls back to subtitle id when file name is blank', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieSubtitleSection(
            items: <MovieSubtitleItemDto>[
              MovieSubtitleItemDto(
                subtitleId: 502,
                fileName: '  ',
                createdAt: null,
                url: '/files/subtitles/502',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('字幕 502'), findsOneWidget);
  });
}
