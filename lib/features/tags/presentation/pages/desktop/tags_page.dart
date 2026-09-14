import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/tag_movie_summary_content.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_header.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

class DesktopTagsPage extends ConsumerStatefulWidget {
  const DesktopTagsPage({super.key, this.initialTagId});

  /// 从影片详情页跳入时携带的预选标签；为空表示一级导航入口。
  final int? initialTagId;

  @override
  ConsumerState<DesktopTagsPage> createState() => _DesktopTagsPageState();
}

class _DesktopTagsPageState extends ConsumerState<DesktopTagsPage> {
  final _tagHeaderKey = GlobalKey();
  late final TagSelectionScope _selectionScope = widget.initialTagId == null
      ? const TagSelectionScope.desktopRoot()
      : TagSelectionScope.desktopDetail(initialTagId: widget.initialTagId!);
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
      return ColoredBox(
        color: context.appColors.surfaceElevated,
        child: AppFixedHeaderLayout(
          key: const Key('tags-page'),
          header: _buildSelectorPanel(),
          child: const Center(child: AppEmptyState(message: '请选择标签查看影片')),
        ),
      );
    }

    return TagMovieSummaryContent(
      key: const Key('tags-page'),
      selection: selection,
      headerLeading: _buildSelectorPanel(),
      scope: _movieScope,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('tags-page-movies'),
      totalKey: const Key('tags-page-total'),
      sectionSpacing: context.appSpacing.lg,
      registerPageRefresh: true,
      onMovieTap: (context, movieNumber) => context.pushDesktopMovieDetail(
        movieNumber: movieNumber,
        fallbackPath: desktopTagsPath,
      ),
      bodyBuilder: (context, scrollController, sliver, _) => CustomScrollView(
        key: PageStorageKey<String>('${_selectionScope.instanceKey}:movies'),
        controller: scrollController,
        slivers: [sliver],
      ),
    );
  }

  Widget _buildSelectorPanel() => TagSelectionHeader(
    key: _tagHeaderKey,
    scope: _selectionScope,
    mobile: false,
  );
}
