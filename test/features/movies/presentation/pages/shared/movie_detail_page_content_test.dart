import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_review_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_tag_wrap.dart';

/// 复用同一套 overrides，所有测试都包裹了新加的内联组件，
/// 需要 Riverpod provider 兜底状态。
/// 注意用 overrideWith 而非 overrideWithValue：内联组件里会调用 .notifier
/// 必须返回真实 Notifier 类型才能通过类型检查。
List<Override> get _inlineProviderOverrides => [
      movieDetailReviewProvider('ABC-001').overrideWith(
        () => _FakeReviewNotifier(),
      ),
      movieDetailMagnetProvider('ABC-001').overrideWith(
        () => _FakeMagnetNotifier(),
      ),
      movieDetailThumbnailProvider(mediaId: 100).overrideWith(
        () => _FakeThumbnailNotifier(),
      ),
    ];

// Fake notifiers — 只改 state，不做网络请求
class _FakeReviewNotifier extends MovieDetailReview {
  @override
  MovieDetailReviewState build(String arg) => const MovieDetailReviewState();
}

class _FakeMagnetNotifier extends MovieDetailMagnet {
  @override
  MovieDetailMagnetState build(String arg) => const MovieDetailMagnetState();
}

class _FakeThumbnailNotifier extends MovieDetailThumbnail {
  @override
  MovieDetailThumbnailState build({int? mediaId}) =>
      const MovieDetailThumbnailState();
}

void main() {
  testWidgets('movie detail page content exposes clickable series row', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _inlineProviderOverrides,
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          home: Scaffold(
            body: MovieDetailPageContent(
              movie: _movieDetail(seriesId: 7),
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
      ),
    );

    await tester.tap(find.byKey(const Key('movie-detail-series-link')));
    await tester.pump();

    expect(tapCount, 1);
    expect(
      find.descendant(
        of: find.byKey(const Key('movie-detail-series-link')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('movie detail page content keeps series text plain without id', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _inlineProviderOverrides,
        child: MaterialApp(
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
      ),
    );

    expect(find.text('系列 · Attackers'), findsOneWidget);
    expect(find.byKey(const Key('movie-detail-series-link')), findsNothing);
  });

  testWidgets(
    'movie detail page content keeps grouped meta spacing in mobile theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _inlineProviderOverrides,
          child: MaterialApp(
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
        ),
      );

      await tester.ensureVisible(find.text('演员'));
      await tester.pumpAndSettle();

      final sectionGap = AppComponentTokens.mobile().movieDetailSectionGap;
      final seriesBottom = tester.getBottomLeft(find.text('系列 · Attackers')).dy;
      final makerTop = tester.getTopLeft(find.text('厂商 · S1 NO.1 STYLE')).dy;
      final makerBottom =
          tester.getBottomLeft(find.text('厂商 · S1 NO.1 STYLE')).dy;
      final directorTop = tester.getTopLeft(find.text('导演 · 紋℃')).dy;
      final metaGroupBottom =
          tester
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
    },
  );
}

MovieDetailDto _movieDetail({int? seriesId}) {
  return MovieDetailDto(
    javdbId: 'javdb-1',
    movieNumber: 'ABC-001',
    title: 'Sample Movie',
    titleZh: '',
    seriesId: seriesId,
    seriesName: 'Attackers',
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
    descZh: '中文简介',
    desc: '',
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[
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
    tags: const <MovieTagDto>[
      MovieTagDto(tagId: 1, name: '单体作品'),
      MovieTagDto(tagId: 2, name: '剧情'),
    ],
    mediaItems: const <MovieMediaItemDto>[
      MovieMediaItemDto(
        mediaId: 100,
        libraryId: 1,
        playUrl: '',
        storageMode: 'hardlink',
        resolution: '1920x1080',
        fileSizeBytes: 1073741824,
        durationSeconds: 7200,
        specialTags: '普通',
        valid: true,
        progress: null,
        points: <MovieMediaPointDto>[],
      ),
    ],
    playlists: const <MoviePlaylistSummaryDto>[],
  );
}

void _noop() {}
