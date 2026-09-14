import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

class DesktopFollowPage extends ConsumerStatefulWidget {
  const DesktopFollowPage({super.key});

  @override
  ConsumerState<DesktopFollowPage> createState() => _DesktopFollowPageState();
}

class _DesktopFollowPageState extends ConsumerState<DesktopFollowPage>
    with
        MultiSelectStateMixin<DesktopFollowPage, String>,
        MovieBatchSelectionMixin<DesktopFollowPage> {
  static const _scope = MovieSummaryScope.subscribedActorsLatest();
  late final ScrollController _scrollController;

  @override
  String get batchKeyPrefix => 'desktop-follow';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      ref.read(movieSummaryProvider(_scope).notifier).batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(movieSummaryProvider(_scope))
          .value
          ?.paged
          .items
          .map((movie) => movie.movieNumber)
          .toList(growable: false) ??
      const <String>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final summary = ref.read(movieSummaryProvider(_scope)).value;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(movieSummaryProvider(_scope).notifier).loadMore());
  }

  Future<void> _refresh() async {
    await ref.read(movieSummaryProvider(_scope).notifier).refresh();
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(movieSummaryProvider(_scope));
    final summary = moviesAsync.value;
    final paged = summary?.paged;
    ref.listen(movieCollectionTypeEventsProvider, (_, next) {
      final change = next.value;
      if (change == null ||
          change.targetType != MovieCollectionType.collection ||
          !selectionMode ||
          !selectedIds.contains(change.movieNumber)) {
        return;
      }
      setState(() => selectedIds.remove(change.movieNumber));
    });
    final items = paged?.items ?? const [];
    final isInitialLoading = moviesAsync.isLoading && summary == null;
    final initialErrorMessage = moviesAsync.hasError && summary == null
        ? _scope.initialLoadErrorText
        : null;
    final showFooter =
        items.isNotEmpty &&
        (paged!.isLoadingMore || paged.loadMoreErrorMessage != null);

    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: AppFixedHeaderLayout(
          header: selectionMode
              ? buildBatchSelectionToolbar()
              : AppFilterTotalHeader(
                  leading: Text(
                    '女优上新',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  totalText: '${paged?.total ?? 0} 部',
                  totalKey: const Key('desktop-follow-page-total'),
                  trailing: buildEnterSelectionButton(),
                ),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverMainAxisGroup(
                key: const Key('desktop-follow-page'),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.appSpacing.lg),
                  ),
                  MovieSummarySliver(
                    items: items,
                    isLoading: isInitialLoading,
                    errorMessage: initialErrorMessage,
                    onMovieTap: (movie) => context.pushDesktopMovieDetail(
                      movieNumber: movie.movieNumber,
                      fallbackPath: desktopFollowPath,
                    ),
                    onMovieMenuRequest: (movie, globalPosition) {
                      unawaited(
                        showMovieCollectionFeatureActionMenu(
                          context: context,
                          movieNumber: movie.movieNumber,
                          globalPosition: globalPosition,
                          isSubscribed: movie.isSubscribed,
                        ),
                      );
                    },
                    onMovieSubscriptionTap: (movie) =>
                        _toggleMovieSubscription(movie.movieNumber),
                    isMovieSubscriptionUpdating: (movie) =>
                        summary?.isSubscriptionUpdating(movie.movieNumber) ??
                        false,
                    emptyMessage: '暂无关注影片',
                    selectionMode: selectionMode,
                    isMovieSelected: (movie) => isSelected(movie.movieNumber),
                    onMovieSelectedChanged: (movie, _) =>
                        toggleSelect(movie.movieNumber),
                  ),
                  if (showFooter)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: context.appSpacing.md),
                        child: AppPagedLoadMoreFooter(
                          isLoading: paged.isLoadingMore,
                          errorMessage: paged.loadMoreErrorMessage,
                          onRetry: () => ref
                              .read(movieSummaryProvider(_scope).notifier)
                              .loadMore(),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
