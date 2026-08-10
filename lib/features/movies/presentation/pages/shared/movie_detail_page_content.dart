import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/media/data/media_play_url_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_review_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_playback_options.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_playback_options_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_number_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_title.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_clip_strip.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_media_item_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_gallery.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_similar_movie_strip.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_tag_wrap.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';

typedef MovieDetailScrollViewBuilder =
    Widget Function(
      BuildContext context,
      Widget content,
      ScrollPhysics? scrollPhysics,
    );

class MovieDetailPageContent extends StatelessWidget {
  const MovieDetailPageContent({
    super.key,
    required this.movie,
    required this.selectedPreviewKey,
    required this.selectedPreviewUrl,
    required this.isCollection,
    required this.isSubscribed,
    required this.isCollectionUpdating,
    required this.isSubscriptionUpdating,
    required this.selectedMediaId,
    required this.statItems,
    required this.similarMovies,
    required this.isSimilarMoviesLoading,
    required this.onInspectorTap,
    required this.onPlaylistTap,
    required this.onCollectionToggle,
    required this.onMediaSelect,
    this.isDeletingSelectedMedia = false,
    this.onDeleteSelectedMedia,
    this.mediaItemsOverride,
    this.storageDescriptors = const <int, MediaStorageDescriptor>{},
    this.onOpenMediaPointPreview,
    this.onRequestMediaPointMenu,
    this.onPlayTap,
    this.onSubscriptionTap,
    this.onMoreActionsTap,
    this.onActorTap,
    this.onSeriesTap,
    this.onTagTap,
    this.onRequestPlotImageMenu,
    this.onOpenPlotPreview,
    this.similarMoviesErrorMessage,
    this.onRetrySimilarMovies,
    this.onSimilarMovieTap,
    this.clips = const <MediaClipDto>[],
    this.isClipsLoading = false,
    this.clipsErrorMessage,
    this.onRetryClips,
    this.onPlayClip,
    this.onRenameClip,
    this.onDeleteClip,
    this.onAddClipToCollection,
    this.contentPadding = EdgeInsets.zero,
    this.bottomInfoBarVariant = MovieDetailBottomInfoBarVariant.desktopCard,
    this.scrollPhysics,
    this.scrollViewBuilder,
    this.isMoreActionsUpdating = false,
    this.sourceOptions,
    this.selectedPlaySource,
    this.onPlaySourceChanged,
    this.mergedPlaybackAvailable = false,
    this.selectedPlayMode = MoviePlayUrlMode.single,
    this.onPlayModeChanged,
    this.isPlayLoading = false,
  });

  final MovieDetailDto movie;
  final List<MovieMediaItemDto>? mediaItemsOverride;
  final Map<int, MediaStorageDescriptor> storageDescriptors;
  final String selectedPreviewKey;
  final String? selectedPreviewUrl;
  final bool isCollection;
  final bool isSubscribed;
  final bool isCollectionUpdating;
  final bool isSubscriptionUpdating;
  final bool isMoreActionsUpdating;
  final int? selectedMediaId;
  final List<MovieDetailStatItem> statItems;
  final List<MovieListItemDto> similarMovies;
  final bool isSimilarMoviesLoading;
  final VoidCallback onInspectorTap;
  final VoidCallback onPlaylistTap;
  final VoidCallback? onCollectionToggle;
  final ValueChanged<MovieMediaItemDto> onMediaSelect;
  final bool isDeletingSelectedMedia;
  final ValueChanged<MovieMediaItemDto>? onDeleteSelectedMedia;
  final void Function(MovieMediaItemDto mediaItem, MovieMediaPointDto point)?
  onOpenMediaPointPreview;
  final Future<void> Function(
    BuildContext context,
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    Offset globalPosition,
  )?
  onRequestMediaPointMenu;
  final VoidCallback? onPlayTap;
  final VoidCallback? onSubscriptionTap;
  final Future<void> Function(Offset globalPosition)? onMoreActionsTap;
  final ValueChanged<MovieActorDto>? onActorTap;
  final VoidCallback? onSeriesTap;
  final ValueChanged<MovieTagDto>? onTagTap;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )?
  onRequestPlotImageMenu;
  final ValueChanged<int>? onOpenPlotPreview;
  final String? similarMoviesErrorMessage;
  final VoidCallback? onRetrySimilarMovies;
  final ValueChanged<MovieListItemDto>? onSimilarMovieTap;
  final List<MediaClipDto> clips;
  final bool isClipsLoading;
  final String? clipsErrorMessage;
  final VoidCallback? onRetryClips;
  final ValueChanged<MediaClipDto>? onPlayClip;
  final ValueChanged<MediaClipDto>? onRenameClip;
  final ValueChanged<MediaClipDto>? onDeleteClip;
  final ValueChanged<MediaClipDto>? onAddClipToCollection;
  final EdgeInsetsGeometry contentPadding;
  final MovieDetailBottomInfoBarVariant bottomInfoBarVariant;
  final ScrollPhysics? scrollPhysics;
  final MovieDetailScrollViewBuilder? scrollViewBuilder;

  /// 播放源/播放模式选择配置。`sourceOptions` 为空表示本片无可播媒体（隐藏选择行）。
  final MoviePlaybackSourceOptions? sourceOptions;
  final MoviePlayUrlSource? selectedPlaySource;
  final ValueChanged<MoviePlayUrlSource>? onPlaySourceChanged;
  final bool mergedPlaybackAvailable;
  final MoviePlayUrlMode selectedPlayMode;
  final ValueChanged<MoviePlayUrlMode>? onPlayModeChanged;

  /// 播放动作进行中（合并播放探测/拉起外部播放器），透传给 hero 播放按钮显示 loading。
  final bool isPlayLoading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = _resolveViewportHeight(context, constraints);
          final heroHeight = viewportHeight * 0.3;
          final scrollBottomPadding =
              bottomInfoBarVariant ==
                      MovieDetailBottomInfoBarVariant.mobileFullWidth
                  ? context.appComponentTokens.movieDetailBottomBarMinHeight
                  : context.appComponentTokens.movieDetailBottomBarMinHeight +
                      context.appSpacing.sm;

          final content = Padding(
            padding: EdgeInsets.only(bottom: scrollBottomPadding),
            child: Padding(
              padding: contentPadding,
              child: _buildDetailBody(context: context, heroHeight: heroHeight),
            ),
          );
          final scrollableContent =
              scrollViewBuilder?.call(context, content, scrollPhysics) ??
              SingleChildScrollView(physics: scrollPhysics, child: content);

          if (bottomInfoBarVariant ==
              MovieDetailBottomInfoBarVariant.desktopCard) {
            return Column(
              children: [
                Expanded(child: scrollableContent),
                SizedBox(height: context.appSpacing.xs),
                MovieDetailBottomInfoBar(
                  items: statItems,
                  onTap: onInspectorTap,
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: scrollableContent),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MovieDetailBottomInfoBar(
                  items: statItems,
                  onTap: onInspectorTap,
                  variant: MovieDetailBottomInfoBarVariant.mobileFullWidth,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailBody({
    required BuildContext context,
    required double heroHeight,
  }) {
    final mediaItems = mediaItemsOverride ?? movie.mediaItems;
    final orderedActors = <MovieActorDto>[
      ...movie.actors.where((actor) => actor.isFemale),
      ...movie.actors.where((actor) => !actor.isFemale),
    ];
    final playlistTrigger = AppIconButton(
      key: const Key('movie-detail-playlist-trigger'),
      onPressed: onPlaylistTap,
      icon: Icon(
        Icons.playlist_add_rounded,
        size: context.appComponentTokens.iconSizeLg,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: '加入播放列表',
    );
    final collectionTrigger = TextButton(
      key: const Key('movie-detail-collection-trigger'),
      onPressed: isCollectionUpdating ? null : onCollectionToggle,
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primary,
        ),
        padding: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return EdgeInsets.symmetric(
              horizontal: context.appSpacing.sm,
              vertical: context.appSpacing.md,
            );
          }
          return EdgeInsets.symmetric(
            horizontal: context.appSpacing.xs,
            vertical: 0,
          );
        }),
      ),
      child: Text(
        isCollection ? '标记单体' : '标记合集',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.tertiary,
        ).copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );

    return Column(
      key: const Key('movie-detail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailTitle(
          title: movie.preferredTitle,
          movieNumber: movie.movieNumber,
        ),
        MovieDetailHeroCard(
          height: heroHeight,
          mainImageKey: selectedPreviewKey,
          mainImageUrl: selectedPreviewUrl,
          heat: movie.heat,
          canPlay: movie.canPlay,
          isSubscribed: isSubscribed,
          isCollection: isCollection,
          onSubscriptionTap: onSubscriptionTap,
          isSubscriptionUpdating: isSubscriptionUpdating,
          onMoreActionsTap: onMoreActionsTap,
          isMoreActionsUpdating: isMoreActionsUpdating,
          isPlayLoading: isPlayLoading,
          onPlayTap: onPlayTap,
        ),
        SizedBox(height: context.appSpacing.lg),
        MoviePlotGallery(
          plotImages: movie.plotImages,
          onRequestImageMenu: onRequestPlotImageMenu,
          onOpenPreview: onOpenPlotPreview,
        ),
        SizedBox(height: context.appComponentTokens.movieDetailSectionGap),
        MovieDetailNumberBar(
          movieNumber: movie.movieNumber,
          summary: movie.preferredDescription,
          wantWatchCount: movie.wantWatchCount,
          watchedCount: movie.watchedCount,
          score: movie.score,
          commentCount: movie.commentCount,
          heat: movie.heat,
          scoreNumber: movie.scoreNumber,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              collectionTrigger,
              SizedBox(width: context.appSpacing.xs),
              playlistTrigger,
            ],
          ),
        ),
        ..._buildInlineMetaItems(context, movie, onSeriesTap),
        MovieDetailSection(
          title: '标签',
          child: MovieTagWrap(tags: movie.tags, onTagTap: onTagTap),
        ),
        MovieDetailSection(
          title: '演员',
          child: MovieActorWrap(actors: orderedActors, onActorTap: onActorTap),
        ),
        if (mediaItems.isNotEmpty)
          MovieDetailSection(
            title: '媒体源',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sourceOptions != null)
                  MoviePlaybackOptionsBar(
                    sourceOptions: sourceOptions!,
                    selectedSource: selectedPlaySource,
                    onSourceChanged: onPlaySourceChanged ?? (_) {},
                    mergedAvailable: mergedPlaybackAvailable,
                    selectedMode: selectedPlayMode,
                    onModeChanged: onPlayModeChanged ?? (_) {},
                  ),
                if (sourceOptions != null)
                  SizedBox(height: context.appSpacing.sm),
                MovieMediaItemList(
                  mediaItems: mediaItems,
                  selectedMediaId: selectedMediaId,
                  storageDescriptors: storageDescriptors,
                  onSelect: onMediaSelect,
                  isDeletingSelectedMedia: isDeletingSelectedMedia,
                  onDeleteSelectedMedia: onDeleteSelectedMedia,
                  onOpenPointPreview: onOpenMediaPointPreview,
                  onRequestPointMenu: onRequestMediaPointMenu,
                ),
              ],
            ),
          ),
        if (isClipsLoading || clipsErrorMessage != null || clips.isNotEmpty)
          MovieDetailSection(
            title: '切片',
            titleKey: const Key('movie-clips-title'),
            child: MovieClipStrip(
              clips: clips,
              isLoading: isClipsLoading,
              errorMessage: clipsErrorMessage,
              onRetry: onRetryClips,
              onPlayClip: onPlayClip ?? (_) {},
              onRenameClip: onRenameClip ?? (_) {},
              onDeleteClip: onDeleteClip ?? (_) {},
              onAddClipToCollection: onAddClipToCollection ?? (_) {},
            ),
          ),
        MovieDetailSection(
          title: '相似影片',
          titleKey: const Key('movie-similar-movies-title'),
          child: MovieSimilarMovieStrip(
            movies: similarMovies,
            isLoading: isSimilarMoviesLoading,
            errorMessage: similarMoviesErrorMessage,
            onRetry: onRetrySimilarMovies,
            onMovieTap: onSimilarMovieTap,
            onMovieMenuRequest:
                (movie, globalPosition) => requestMovieCollectionMenu(
                  context,
                  movie.movieNumber,
                  globalPosition,
                  isSubscribed: movie.isSubscribed,
                ),
          ),
        ),

        // ── Inline: 评论 ──────────────────────────────────────────────
        MovieDetailSection(
          title: '评论',
          titleKey: const Key('movie-detail-inline-review-title'),
          child: _InlineReviewSection(movieNumber: movie.movieNumber),
        ),

        // ── Inline: 磁力搜索 ─────────────────────────────────────────
        MovieDetailSection(
          title: '磁力搜索',
          titleKey: const Key('movie-detail-inline-magnet-title'),
          child: _InlineMagnetSection(movieNumber: movie.movieNumber),
        ),

        // ── Inline: 缩略图 ─────────────────────────────────────────────
        MovieDetailSection(
          title: '缩略图',
          titleKey: const Key('movie-detail-inline-thumbnail-title'),
          child: _InlineThumbnailSection(
            movieNumber: movie.movieNumber,
            mediaId: selectedMediaId,
          ),
        ),
      ],
    );
  }
}

List<Widget> _buildInlineMetaItems(
  BuildContext context,
  MovieDetailDto movie,
  VoidCallback? onSeriesTap,
) {
  final items = <_MovieInlineMetaItem>[
    _MovieInlineMetaItem(
      label: '系列',
      value: movie.seriesName.trim(),
      onTap: movie.seriesId == null ? null : onSeriesTap,
    ),
    _MovieInlineMetaItem(label: '厂商', value: movie.makerName.trim()),
    _MovieInlineMetaItem(label: '导演', value: movie.directorName.trim()),
  ].where((item) => item.value.isNotEmpty).toList(growable: false);

  if (items.isEmpty) {
    return const <Widget>[];
  }

  return <Widget>[
    Padding(
      padding: EdgeInsets.only(
        bottom: context.appComponentTokens.movieDetailSectionGap,
      ),
      child: Column(
        key: const Key('movie-detail-inline-meta-group'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) SizedBox(height: context.appSpacing.sm),
            _MovieInlineMetaRow(item: items[index]),
          ],
        ],
      ),
    ),
  ];
}

class _MovieInlineMetaItem {
  const _MovieInlineMetaItem({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _MovieInlineMetaRow extends StatelessWidget {
  const _MovieInlineMetaRow({required this.item});

  final _MovieInlineMetaItem item;

  @override
  Widget build(BuildContext context) {
    final textStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final label = '${item.label} · ${item.value}';
    final onTap = item.onTap;
    if (onTap == null) {
      return Text(label, style: textStyle);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('movie-detail-series-link'),
        onTap: onTap,
        borderRadius: context.appRadius.xsBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.xs,
            vertical: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textStyle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: context.appSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MovieDetailLoadingSkeleton extends StatelessWidget {
  const MovieDetailLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = _resolveViewportHeight(context, constraints) * 0.3;
        final availableWidth = _resolveViewportWidth(context, constraints);
        final titleWidth = math.min(240.0, availableWidth * 0.56);
        final movieNumberWidth = math.min(180.0, availableWidth * 0.4);
        final summaryWidth = math.min(520.0, availableWidth * 0.82);
        final labelWidth = math.min(120.0, availableWidth * 0.3);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                key: const Key('movie-detail-loading-skeleton'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(height: 28, width: titleWidth),
                  SizedBox(height: context.appSpacing.lg),
                  _SkeletonBlock(height: heroHeight),
                  SizedBox(height: context.appSpacing.lg),
                  _SkeletonBlock(
                    height:
                        context
                            .appComponentTokens
                            .movieDetailPlotThumbnailHeight,
                  ),
                  SizedBox(
                    height: context.appComponentTokens.movieDetailSectionGap,
                  ),
                  _SkeletonBlock(height: 18, width: movieNumberWidth),
                  SizedBox(height: context.appSpacing.xs),
                  _SkeletonBlock(height: 16, width: summaryWidth),
                  SizedBox(height: context.appSpacing.xs),
                  _SkeletonBlock(height: 18, width: summaryWidth),
                  SizedBox(height: context.appSpacing.xxl),
                  _SkeletonBlock(height: 18, width: labelWidth),
                  SizedBox(height: context.appSpacing.md),
                  const _SkeletonBlock(height: 64),
                  SizedBox(height: context.appSpacing.lg),
                  _SkeletonBlock(height: 18, width: labelWidth),
                  SizedBox(height: context.appSpacing.md),
                  const _SkeletonBlock(height: 96),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class MovieDetailErrorState extends StatelessWidget {
  const MovieDetailErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.lg),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline sections: 评论 / 磁力搜索 / 缩略图
// ─────────────────────────────────────────────────────────────────────────────

class _InlineReviewSection extends ConsumerStatefulWidget {
  const _InlineReviewSection({required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<_InlineReviewSection> createState() =>
      _InlineReviewSectionState();
}

class _InlineReviewSectionState extends ConsumerState<_InlineReviewSection> {
  MovieDetailReview get _controller =>
      ref.read(movieDetailReviewProvider(widget.movieNumber).notifier);
  MovieDetailReviewState get _state =>
      ref.read(movieDetailReviewProvider(widget.movieNumber));

  late final ScrollController _scrollController;
  int _lastAutoLoadTriggerItemCount = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.loadInitial());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 200) {
      _lastAutoLoadTriggerItemCount = -1;
      return;
    }
    if (_state.items.length == _lastAutoLoadTriggerItemCount) return;
    _lastAutoLoadTriggerItemCount = _state.items.length;
    _controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movieDetailReviewProvider(widget.movieNumber));

    if (state.isInitialLoading && state.items.isEmpty) {
      return _buildSkeleton();
    }

    if (state.initialErrorMessage != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.initialErrorMessage!,
                style: resolveAppTextStyle(context, size: AppTextSize.s14,
                    tone: AppTextTone.secondary)),
            SizedBox(height: context.appSpacing.md),
            TextButton(
                onPressed: _controller.loadInitial, child: const Text('重试')),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(child: AppEmptyState(message: '暂无评论'));
    }

    return SizedBox(
      height: 320,
      child: ListView.separated(
        controller: _scrollController,
        key: const Key('inline-review-list'),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, __) =>
            SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            return _InlineReviewCard(review: state.items[index]);
          }
          if (state.isLoadingMore) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(8),
              child: CupertinoActivityIndicator(),
            ));
          }
          if (state.loadMoreErrorMessage != null) {
            return Center(
                child: TextButton(
                    onPressed: _controller.loadMore,
                    child: Text(state.loadMoreErrorMessage!)));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, __) =>
            SizedBox(height: context.appSpacing.sm),
        itemBuilder: (_, __) => Container(
          height: 64,
          decoration: BoxDecoration(
            color: context.appColors.surfaceMuted,
            borderRadius: context.appRadius.mdBorder,
          ),
        ),
      ),
    );
  }
}

class _InlineReviewCard extends StatelessWidget {
  const _InlineReviewCard({required this.review});
  final MovieReviewDto review;

  @override
  Widget build(BuildContext context) {
    final reviewDate = review.createdAt == null
        ? '--/--/--'
        : DateFormat('yy/MM/dd').format(review.createdAt!.toLocal());
    return Container(
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar placeholder
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.appColors.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (review.username.trim().isEmpty ? '匿' : review.username)
                    .substring(0, 1)
                    .toUpperCase(),
                style: resolveAppTextStyle(context, size: AppTextSize.s12,
                    weight: AppTextWeight.medium),
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.username.trim().isEmpty
                          ? '匿名用户'
                          : review.username,
                      style: resolveAppTextStyle(context, size: AppTextSize.s12,
                          weight: AppTextWeight.medium),
                    ),
                    SizedBox(width: context.appSpacing.xs),
                    Icon(Icons.star_rounded,
                        size: 12,
                        color: context.appColors.movieDetailScoreIcon),
                    Text('${review.score}',
                        style: resolveAppTextStyle(context,
                            size: AppTextSize.s10,
                            tone: AppTextTone.secondary)),
                    const Spacer(),
                    Text(reviewDate,
                        style: resolveAppTextStyle(context,
                            size: AppTextSize.s10,
                            tone: AppTextTone.muted)),
                  ],
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  review.content.trim().isEmpty
                      ? '暂无评论内容'
                      : review.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(context, size: AppTextSize.s12,
                      tone: AppTextTone.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMagnetSection extends ConsumerStatefulWidget {
  const _InlineMagnetSection({required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<_InlineMagnetSection> createState() =>
      _InlineMagnetSectionState();
}

class _InlineMagnetSectionState extends ConsumerState<_InlineMagnetSection> {
  MovieDetailMagnet get _controller =>
      ref.read(movieDetailMagnetProvider(widget.movieNumber).notifier);
  MovieDetailMagnetState get _state =>
      ref.read(movieDetailMagnetProvider(widget.movieNumber));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.search());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movieDetailMagnetProvider(widget.movieNumber));

    if (state.isLoading && state.items.isEmpty) {
      return _buildSkeleton(context);
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!,
                style: resolveAppTextStyle(context, size: AppTextSize.s14,
                    tone: AppTextTone.secondary)),
            SizedBox(height: context.appSpacing.md),
            TextButton(
                onPressed: () => _controller.search(),
                child: const Text('重试')),
          ],
        ),
      );
    }

    if (state.items.isEmpty && state.hasSearched) {
      return const Center(child: AppEmptyState(message: '暂无磁力资源'));
    }

    return Column(
      children: [
        // Sort bar
        Wrap(
          spacing: context.appSpacing.xs,
          children: [
            for (final field in MovieDetailMagnetSortField.values)
              AppTextButton(
                key: Key('inline-magnet-sort-${field.name}'),
                label: field.label,
                size: AppTextButtonSize.xSmall,
                isSelected: state.selectedSortField == field,
                onPressed: () => _controller.setSortField(field),
              ),
            AppTextButton(
              key: const Key('inline-magnet-dir'),
              label: state.selectedSortDirection ==
                      MovieDetailMagnetSortDirection.desc
                  ? '↓'
                  : '↑',
              size: AppTextButtonSize.xSmall,
              isSelected: false,
              onPressed: () => _controller.toggleSortDirection(),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.sm),
        if (state.items.isEmpty)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: CupertinoActivityIndicator(),
          ))
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              key: const Key('inline-magnet-list'),
              itemCount: state.sortedItems.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: context.appSpacing.sm),
              itemBuilder: (context, index) {
                final candidate = state.sortedItems[index];
                return _InlineMagnetCard(candidate: candidate, movieNumber: widget.movieNumber);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext ctx) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, __) =>
            SizedBox(height: ctx.appSpacing.sm),
        itemBuilder: (_, __) => Container(
          height: 52,
          decoration: BoxDecoration(
            color: ctx.appColors.surfaceMuted,
            borderRadius: ctx.appRadius.mdBorder,
          ),
        ),
      ),
    );
  }
}

class _InlineMagnetCard extends ConsumerStatefulWidget {
  const _InlineMagnetCard({required this.candidate, required this.movieNumber});
  final DownloadCandidateDto candidate;
  final String movieNumber;

  @override
  ConsumerState<_InlineMagnetCard> createState() => _InlineMagnetCardState();
}

class _InlineMagnetCardState extends ConsumerState<_InlineMagnetCard> {
  int? _selectedClientId;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final first = widget.candidate.selectableDownloadClients.firstOrNull;
    _selectedClientId = first?.id;
  }

  void _handleSubmit() async {
    if (_selectedClientId == null || !widget.candidate.hasDownloadSource) return;
    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(movieDetailMagnetProvider(widget.movieNumber).notifier);
      await controller.submitCandidate(widget.candidate, clientId: _selectedClientId!);
      if (mounted) {
        final name = widget.candidate.selectableDownloadClients
            .where((c) => c.id == _selectedClientId).firstOrNull?.name ?? '下载器';
        showToast('已提交到 $name');
        setState(() { _isSubmitting = false; _submitted = true; });
      }
    } catch (e) {
      if (mounted) { showToast('提交失败'); setState(() => _isSubmitting = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final magnetUrl = widget.candidate.magnetUrl ?? '';
    final clients = widget.candidate.selectableDownloadClients;

    return Container(
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.candidate.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(context, size: AppTextSize.s12,
                          weight: AppTextWeight.medium),
                    ),
                    SizedBox(height: context.appSpacing.xs),
                    Wrap(
                      spacing: context.appSpacing.sm,
                      children: [
                        Text(
                          '做种: ${widget.candidate.seeders}',
                          style: resolveAppTextStyle(context,
                              size: AppTextSize.s10,
                              tone: AppTextTone.muted),
                        ),
                        Text(
                          formatFileSize(widget.candidate.sizeBytes),
                          style: resolveAppTextStyle(context,
                              size: AppTextSize.s10,
                              tone: AppTextTone.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (magnetUrl.isNotEmpty)
                AppIconButton(
                  key: const Key('inline-magnet-copy'),
                  tooltip: '复制磁力链接',
                  size: AppIconButtonSize.mini,
                  onPressed: () async {
                    final copied = await copyTextToClipboard(magnetUrl);
                    if (context.mounted) {
                      showToast(copied ? '磁力链接已复制' : '复制失败');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                ),
            ],
          ),
          SizedBox(height: context.appSpacing.sm),
          // Download row: client selector + submit button
          if (clients.isNotEmpty)
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    child: AppSelectField<int>(
                      value: _selectedClientId,
                      size: AppSelectFieldSize.compact,
                      items: clients.map((c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedClientId = v),
                    ),
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  AppButton(
                    key: const Key('inline-magnet-submit'),
                    size: AppButtonSize.xSmall,
                    label: _submitted
                        ? '已提交'
                        : widget.candidate.hasDownloadSource ? '提交下载' : '无资源',
                    variant: _submitted ? AppButtonVariant.ghost : AppButtonVariant.primary,
                    isLoading: _isSubmitting,
                    onPressed: (_submitted || !widget.candidate.hasDownloadSource)
                        ? null : _handleSubmit,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineThumbnailSection extends ConsumerWidget {
  const _InlineThumbnailSection({
    required this.movieNumber,
    required this.mediaId,
  });

  final String movieNumber;
  final int? mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailThumbnailProvider(mediaId: mediaId));
    final controller =
        ref.read(movieDetailThumbnailProvider(mediaId: mediaId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar
        Wrap(
          spacing: 12,
          runSpacing: context.appSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final seconds in [10, 20, 30, 60])
              AppTextButton(
                key: Key('inline-thumb-interval-$seconds'),
                label: '$seconds秒',
                size: AppTextButtonSize.xSmall,
                isSelected: state.selectedIntervalSeconds == seconds,
                onPressed: () => controller.setIntervalSeconds(seconds),
              ),
            for (final cols in [2, 3, 4])
              AppTextButton(
                key: Key('inline-thumb-cols-$cols'),
                label: '$cols列',
                size: AppTextButtonSize.xSmall,
                isSelected: (state.columns ?? 3) == cols,
                onPressed: () => controller.setColumns(cols),
              ),
          ],
        ),
        SizedBox(height: context.appSpacing.md),
        if (state.isLoading && state.thumbnails.isEmpty)
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: const Center(child: CupertinoActivityIndicator()),
          )
        else if (state.errorMessage != null && state.thumbnails.isEmpty)
          Center(
            child: TextButton(
                onPressed: controller.retry, child: const Text('重试')),
          )
        else if (state.thumbnails.isEmpty)
          const Center(child: AppEmptyState(message: '暂无缩略图'))
        else
          SizedBox(
            height: 280,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = state.columns ?? 3;
                final spacing = context.appSpacing.xs;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                final itemHeight = itemWidth * 0.6;

                return GridView.builder(
                  key: const Key('inline-thumbnail-grid'),
                  scrollDirection: Axis.horizontal,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: itemWidth / itemHeight,
                  ),
                  itemCount: state.thumbnails.length,
                  itemBuilder: (context, index) {
                    final thumb = state.thumbnails[index];
                    return ClipRRect(
                      borderRadius: context.appRadius.smBorder,
                      child: thumb.image.resolvedUrl.isEmpty
                          ? Container(color: context.appColors.surfaceMuted)
                          : Image.network(
                              thumb.image.resolvedUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: context.appColors.surfaceMuted),
                            ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

double _resolveViewportHeight(
  BuildContext context,
  BoxConstraints constraints,
) {
  if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
    return constraints.maxHeight;
  }
  return MediaQuery.sizeOf(context).height;
}

double _resolveViewportWidth(BuildContext context, BoxConstraints constraints) {
  if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
    return constraints.maxWidth;
  }
  return MediaQuery.sizeOf(context).width;
}

List<MovieDetailStatItem> buildMovieDetailStatItems(
  BuildContext context,
  MovieDetailDto movie,
) {
  final releaseLabel =
      movie.releaseDate == null
          ? '--'
          : DateFormat('yy/MM/dd').format(movie.releaseDate!);
  final durationLabel =
      movie.durationMinutes > 0 ? '${movie.durationMinutes} 分钟' : '--';
  final scoreLabel = movie.score > 0 ? movie.score.toStringAsFixed(1) : '--';
  final commentCountLabel =
      movie.commentCount > 0 ? '${movie.commentCount}' : '--';
  final wantWatchCountLabel =
      movie.wantWatchCount > 0 ? '${movie.wantWatchCount}' : '--';

  return [
    MovieDetailStatItem(
      icon: Icons.calendar_today_outlined,
      label: releaseLabel,
      tooltip: '发行日期',
      iconColor: context.appColors.movieDetailReleaseDateIcon,
    ),
    MovieDetailStatItem(
      icon: Icons.schedule_outlined,
      label: durationLabel,
      tooltip: '影片时长',
      iconColor: context.appColors.movieDetailDurationIcon,
    ),
    MovieDetailStatItem(
      icon: Icons.star_outline_rounded,
      label: scoreLabel,
      tooltip: '评分',
      iconColor: context.appColors.movieDetailScoreIcon,
    ),
    MovieDetailStatItem(
      icon: Icons.chat_bubble_outline_rounded,
      label: commentCountLabel,
      tooltip: '评论数',
      iconColor: context.appColors.movieDetailCommentCountIcon,
    ),
    MovieDetailStatItem(
      icon: Icons.favorite_border_rounded,
      label: wantWatchCountLabel,
      tooltip: '想看人数',
      iconColor: context.appColors.movieDetailWantWatchCountIcon,
    ),
  ];
}

extension MovieMediaItemIterableX on Iterable<MovieMediaItemDto> {
  MovieMediaItemDto? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
