import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/tag_movie_summary_content.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_header.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

/// 移动端标签页：标签多选区 + 所选标签下的影片列表。
class MobileTagsPage extends ConsumerStatefulWidget {
  const MobileTagsPage({super.key, this.initialTagId});

  /// 从影片详情页跳入时携带的预选标签；为空表示抽屉一级入口。
  final int? initialTagId;

  @override
  ConsumerState<MobileTagsPage> createState() => _MobileTagsPageState();
}

class _MobileTagsPageState extends ConsumerState<MobileTagsPage> {
  final _tagHeaderKey = GlobalKey();
  late final TagSelectionScope _selectionScope = widget.initialTagId == null
      ? const TagSelectionScope.mobileRoot()
      : TagSelectionScope.mobileDetail(initialTagId: widget.initialTagId!);
  late final MovieSummaryScope _movieScope = MovieSummaryScope.tags(
    instanceKey: _selectionScope.instanceKey,
    cacheKey: _selectionScope.cacheKey,
  );
  RiverpodPageHandle? _pageCacheHandle;

  @override
  void initState() {
    super.initState();
    final cacheKey = _selectionScope.cacheKey;
    if (cacheKey == null) {
      return;
    }
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: cacheKey,
          resolveLinks: () {
            final selectionLink = ref
                .read(tagSelectionProvider(_selectionScope).notifier)
                .cacheLink;
            final moviesLink = ref
                .read(movieSummaryProvider(_movieScope).notifier)
                .cacheLink;
            return [
              if (selectionLink != null) selectionLink,
              if (moviesLink != null) moviesLink,
            ];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(tagSelectionProvider(_selectionScope));
    if (!selection.hasSelection) {
      return AppFixedHeaderLayout(
        key: const Key('tags-page'),
        header: _buildSelectorPanel(),
        child: const Center(child: AppEmptyState(message: '请选择标签查看影片')),
      );
    }

    return TagMovieSummaryContent(
      key: const Key('tags-page'),
      selection: selection,
      headerLeading: _buildSelectorPanel(),
      scope: _movieScope,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('tags-page-movies'),
      totalKey: const Key('tags-page-total'),
      sectionSpacing: context.appSpacing.md,
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
      onMovieTap: (context, movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      headerBuilder: _buildMobileHeader,
      useMobileSelectionLayout: true,
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            key: PageStorageKey<String>(
              '${_selectionScope.instanceKey}:movies',
            ),
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) {
    return AppListHeader(
      filterButtonKey: const Key('mobile-tags-filter-button'),
      filterTooltip: '筛选',
      filterLabel: args.filterState.triggerLabel,
      onFilterTap: () => _openFilterDrawer(context, args),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('mobile-tags-page-total'),
          label: '${args.total} 部',
        ),
      ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) async {
    await showMobileMovieFilterDrawer(
      context,
      current: args.filterState,
      onChanged: args.onApply,
    );
  }

  Widget _buildSelectorPanel() => TagSelectionHeader(
    key: _tagHeaderKey,
    scope: _selectionScope,
    mobile: true,
  );
}
