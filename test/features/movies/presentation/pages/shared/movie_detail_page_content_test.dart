import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_tag_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_gallery.dart';

void main() {
  testWidgets('personal info uses latest watch and opens playlist editor', (
    tester,
  ) async {
    var edits = 0;
    final media = _movieDetail().mediaItems.first;
    final movie = _movieDetail(
      mediaItems: [
        media.copyWith(
          progress: MovieMediaProgressDto(
            lastPositionSeconds: 3600,
            lastWatchedAt: DateTime(2026, 1, 1),
          ),
        ),
        media.copyWith(
          mediaId: 101,
          progress: MovieMediaProgressDto(
            lastPositionSeconds: 1938,
            lastWatchedAt: DateTime(2026, 2, 1),
          ),
        ),
      ],
      playlists: [
        for (var id = 1; id <= 3; id++)
          MoviePlaylistSummaryDto(
            id: id,
            name: '片单$id',
            kind: 'custom',
            isSystem: false,
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieDetailPageContent(
            movie: movie,
            selectedPreviewKey: 'preview',
            selectedPreviewUrl: null,
            isCollection: false,
            isSubscribed: false,
            isCollectionUpdating: false,
            isSubscriptionUpdating: false,
            selectedMediaId: 100,
            statItems: const [],
            similarMovies: const [],
            isSimilarMoviesLoading: false,
            onInspectorTap: _noop,
            onPlaylistTap: () => edits++,
            onCollectionToggle: _noop,
            onMediaSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('上次看到 32:18'), findsOneWidget);
    expect(find.text('片单1'), findsOneWidget);
    expect(find.text('共 3 个'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('movie-detail-playlist-trigger')));
    await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
    expect(edits, 1);
    await tester.ensureVisible(find.text('片单1'));
    await tester.tap(find.text('片单1'));
    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });

  for (final mobile in [true, false]) {
    for (final showTags in [true, false]) {
      for (final showActors in [true, false]) {
        testWidgets(
          'detail hides empty sections (mobile: $mobile, tags: $showTags, actors: $showActors)',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = mobile
                ? const Size(360, 760)
                : const Size(1100, 760);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            var actorTaps = 0;
            var tagTaps = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
                home: Scaffold(
                  body: MovieDetailPageContent(
                    movie: _movieDetail(
                      actors: showActors ? null : const [],
                      tags: showTags ? null : const [],
                    ),
                    selectedPreviewKey: 'movie-preview',
                    selectedPreviewUrl: null,
                    isCollection: false,
                    isSubscribed: false,
                    isCollectionUpdating: false,
                    isSubscriptionUpdating: false,
                    selectedMediaId: 100,
                    statItems: const [],
                    similarMovies: const [],
                    isSimilarMoviesLoading: false,
                    bottomInfoBarVariant: mobile
                        ? MovieDetailBottomInfoBarVariant.mobileFullWidth
                        : MovieDetailBottomInfoBarVariant.desktopCard,
                    onInspectorTap: _noop,
                    onPlaylistTap: _noop,
                    onCollectionToggle: _noop,
                    onMediaSelect: (_) {},
                    onActorTap: (_) => actorTaps++,
                    onTagTap: (_) => tagTaps++,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('标签'), showTags ? findsOneWidget : findsNothing);
            expect(find.text('演员'), showActors ? findsOneWidget : findsNothing);
            expect(find.text('暂无观看记录'), findsNothing);
            expect(find.textContaining('上次看到'), findsNothing);
            expect(find.byType(MoviePlotGallery), findsNothing);
            if (showTags) {
              await tester.ensureVisible(find.text('剧情'));
              await tester.tap(find.text('剧情'));
              expect(tagTaps, 1);
            }
            if (showActors) {
              await tester.ensureVisible(find.text('演员一'));
              await tester.tap(find.text('演员一'));
              expect(actorTaps, 1);
            }
            await tester.ensureVisible(find.text('媒体源'));
            expect(find.text('媒体源').hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('plugin movie displays its source and pending JavDB status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieDetailPageContent(
            movie: _movieDetail(javdbId: null, metadataSourceName: '示例来源'),
            selectedPreviewKey: 'movie-preview',
            selectedPreviewUrl: null,
            isCollection: false,
            isSubscribed: false,
            isCollectionUpdating: false,
            isSubscriptionUpdating: false,
            selectedMediaId: 100,
            statItems: const <MovieDetailStatItem>[],
            similarMovies: const <MovieListItemDto>[],
            isSimilarMoviesLoading: false,
            onInspectorTap: _noop,
            onPlaylistTap: _noop,
            onCollectionToggle: _noop,
            onMediaSelect: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('元数据 · 示例来源 · 待 JavDB 收录'), findsOneWidget);
  });

  test('movie DTOs accept plugin movies without a JavDB ID', () {
    final json = <String, dynamic>{
      'id': 12,
      'javdb_id': null,
      'movie_number': 'TEST-001',
      'title': 'Plugin title',
      'metadata_source': <String, dynamic>{
        'plugin_id': 'example',
        'display_name': '示例来源',
      },
    };
    final detail = MovieDetailDto.fromJson(json);
    final item = MovieListItemDto.fromJson(json);
    expect(detail.javdbId, isNull);
    expect(item.javdbId, isNull);
    expect(detail.metadataSourceName, '示例来源');
    expect(detail.score, 0);
    expect(detail.watchedCount, 0);
  });

  for (final seriesName in [
    'Attackers',
    '这是一个用于验证影片详情页面在窄屏下能够完整换行且不会溢出的超长系列名称',
  ]) {
    testWidgets(
      'movie detail wraps clickable series on narrow screens: $seriesName',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var tapCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: sakuraMobileThemeData,
            home: Scaffold(
              body: MovieDetailPageContent(
                movie: _movieDetail(seriesId: 7, seriesName: seriesName),
                selectedPreviewKey: 'movie-preview',
                selectedPreviewUrl: null,
                isCollection: false,
                isSubscribed: false,
                isCollectionUpdating: false,
                isSubscriptionUpdating: false,
                selectedMediaId: 100,
                statItems: const <MovieDetailStatItem>[],
                similarMovies: const <MovieListItemDto>[],
                isSimilarMoviesLoading: false,
                onInspectorTap: _noop,
                onPlaylistTap: _noop,
                onCollectionToggle: _noop,
                onMediaSelect: (_) {},
                onSeriesTap: () => tapCount += 1,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final seriesLink = find.byKey(const Key('movie-detail-series-link'));
        final seriesText = find.text('系列 · $seriesName');
        await tester.ensureVisible(seriesLink);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(seriesText).right,
          lessThanOrEqualTo(tester.getRect(seriesLink).right),
        );
        if (seriesName != 'Attackers') {
          expect(tester.getSize(seriesText).height, greaterThan(30));
        }
        await tester.tap(seriesLink);
        await tester.pump();

        expect(tapCount, 1);
        expect(
          find.descendant(
            of: find.byKey(const Key('movie-detail-series-link')),
            matching: find.byIcon(Icons.chevron_right_rounded),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('movie detail page content keeps series text plain without id', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieDetailPageContent(
            movie: _movieDetail(),
            selectedPreviewKey: 'movie-preview',
            selectedPreviewUrl: null,
            isCollection: false,
            isSubscribed: false,
            isCollectionUpdating: false,
            isSubscriptionUpdating: false,
            selectedMediaId: 100,
            statItems: const <MovieDetailStatItem>[],
            similarMovies: const <MovieListItemDto>[],
            isSimilarMoviesLoading: false,
            onInspectorTap: _noop,
            onPlaylistTap: _noop,
            onCollectionToggle: _noop,
            onMediaSelect: (_) {},
            onSeriesTap: _noop,
          ),
        ),
      ),
    );

    expect(find.text('系列 · Attackers'), findsOneWidget);
    expect(find.byKey(const Key('movie-detail-series-link')), findsNothing);
  });

  testWidgets(
    'movie detail page content keeps grouped meta spacing in mobile theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraMobileThemeData,
          home: Scaffold(
            body: MovieDetailPageContent(
              movie: _movieDetail(),
              selectedPreviewKey: 'movie-preview',
              selectedPreviewUrl: null,
              isCollection: false,
              isSubscribed: false,
              isCollectionUpdating: false,
              isSubscriptionUpdating: false,
              selectedMediaId: 100,
              statItems: const <MovieDetailStatItem>[
                MovieDetailStatItem(
                  icon: Icons.calendar_today_outlined,
                  label: '26/03/08',
                  tooltip: '发行日期',
                  iconColor: Color(0xFF6B625E),
                ),
              ],
              similarMovies: const <MovieListItemDto>[],
              isSimilarMoviesLoading: false,
              bottomInfoBarVariant:
                  MovieDetailBottomInfoBarVariant.mobileFullWidth,
              onInspectorTap: _noop,
              onPlaylistTap: _noop,
              onCollectionToggle: _noop,
              onMediaSelect: (_) {},
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('演员'));
      await tester.pumpAndSettle();

      final sectionGap = AppComponentTokens.mobile().movieDetailSectionGap;
      final seriesBottom = tester.getBottomLeft(find.text('系列 · Attackers')).dy;
      final makerTop = tester.getTopLeft(find.text('厂商 · S1 NO.1 STYLE')).dy;
      final makerBottom = tester
          .getBottomLeft(find.text('厂商 · S1 NO.1 STYLE'))
          .dy;
      final directorTop = tester.getTopLeft(find.text('导演 · 紋℃')).dy;
      final metaGroupBottom = tester
          .getBottomLeft(
            find.byKey(const Key('movie-detail-inline-meta-group')),
          )
          .dy;
      final tagTop = tester.getTopLeft(find.text('标签')).dy;
      final tagWrapBottom = tester.getBottomLeft(find.byType(MovieTagWrap)).dy;
      final actorTop = tester.getTopLeft(find.text('演员')).dy;

      expect(makerTop - seriesBottom, sakuraMobileThemeData.appSpacing.sm);
      expect(directorTop - makerBottom, sakuraMobileThemeData.appSpacing.sm);
      expect(makerTop - seriesBottom, lessThan(sectionGap));
      expect(directorTop - makerBottom, lessThan(sectionGap));
      expect(tagTop - metaGroupBottom, sectionGap);
      expect(actorTop - tagWrapBottom, sectionGap);
      expect(find.text('媒体源'), findsOneWidget);
      expect(find.byKey(const Key('movie-subtitles-title')), findsNothing);
      expect(find.byKey(const Key('movie-similar-movies-title')), findsNothing);
    },
  );

  testWidgets('movie detail places merge playback below the hero', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: MovieDetailPageContent(
            movie: _movieDetail(),
            selectedPreviewKey: 'movie-preview',
            selectedPreviewUrl: null,
            isCollection: false,
            isSubscribed: false,
            isCollectionUpdating: false,
            isSubscriptionUpdating: false,
            selectedMediaId: 100,
            statItems: const <MovieDetailStatItem>[],
            similarMovies: const <MovieListItemDto>[],
            isSimilarMoviesLoading: false,
            onInspectorTap: _noop,
            onPlaylistTap: _noop,
            onCollectionToggle: _noop,
            onMediaSelect: (_) {},
            mergePlaybackLabel: '合并播放 · 2 段',
            onMergePlaybackTap: () => tapCount += 1,
          ),
        ),
      ),
    );

    final action = find.byKey(const Key('movie-detail-merge-playback-button'));
    await tester.ensureVisible(action);

    final heroBottom = tester
        .getBottomLeft(find.byType(MovieDetailHeroCard))
        .dy;
    final actionTop = tester.getTopLeft(action).dy;
    final numberTop = tester
        .getTopLeft(find.byKey(const Key('movie-detail-number')))
        .dy;
    final button = tester.widget<AppButton>(action);

    expect(actionTop, greaterThanOrEqualTo(heroBottom));
    expect(actionTop, lessThan(numberTop));
    expect(button.variant, AppButtonVariant.primary);

    await tester.tap(action);
    await tester.pump();

    expect(tapCount, 1);
  });
}

MovieDetailDto _movieDetail({
  int? seriesId,
  String seriesName = 'Attackers',
  String? javdbId = 'javdb-1',
  String? metadataSourceName,
  List<MovieMediaItemDto>? mediaItems,
  List<MoviePlaylistSummaryDto> playlists = const [],
  List<MovieActorDto>? actors,
  List<MovieTagDto>? tags,
}) {
  return MovieDetailDto(
    javdbId: javdbId,
    metadataSourceName: metadataSourceName,
    movieNumber: 'ABC-001',
    title: 'Sample Movie',
    seriesId: seriesId,
    seriesName: seriesName,
    makerName: 'S1 NO.1 STYLE',
    directorName: '紋℃',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 120,
    score: 4.5,
    heat: 12,
    watchedCount: 12,
    wantWatchCount: 23,
    commentCount: 45,
    scoreNumber: 45,
    isCollection: false,
    isSubscribed: false,
    canPlay: false,
    summary: '',
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: actors ?? const <MovieActorDto>[
      MovieActorDto(
        id: 1,
        javdbId: 'actor-1',
        name: '演员一',
        aliasName: '演员一',
        gender: MovieActorDto.femaleGender,
        isSubscribed: false,
        profileImage: null,
      ),
      MovieActorDto(
        id: 2,
        javdbId: 'actor-2',
        name: '演员二',
        aliasName: '演员二',
        gender: 0,
        isSubscribed: false,
        profileImage: null,
      ),
    ],
    tags: tags ?? const <MovieTagDto>[
      MovieTagDto(tagId: 1, name: '单体作品'),
      MovieTagDto(tagId: 2, name: '剧情'),
    ],
    mediaItems:
        mediaItems ??
        const <MovieMediaItemDto>[
          MovieMediaItemDto(
            mediaId: 100,
            libraryId: 1,
            providerKey: 'filesystem',
            playUrl: '',
            fileName: 'ABC-001.mp4',
            resolution: '1920x1080',
            fileSizeBytes: 1073741824,
            durationSeconds: 7200,
            valid: true,
            progress: null,
            points: <MovieMediaPointDto>[],
          ),
        ],
    playlists: playlists,
  );
}

void _noop() {}
