import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_review_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// 影片详情展开面板：评论 + 磁力搜索 + 缩略图，纵向排列。
class MovieInlineDetailPicker extends StatelessWidget {
  const MovieInlineDetailPicker({
    super.key,
    required this.movieNumber,
    this.onClose,
  });

  final String movieNumber;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    movieNumber,
                    style: resolveAppTextStyle(context,
                        size: AppTextSize.s14, tone: AppTextTone.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderSubtle, thickness: 1),

          // 评论（最上）
          _InlineReviewSection(movieNumber: movieNumber),

          // 磁力搜索（中）
          _InlineMagnetSection(movieNumber: movieNumber),

          // 缩略图（最下）— 列表页无 mediaId，显示占位
          _InlineThumbnailPlaceholder(),
        ],
      ),
    );
  }
}

// ── 评论 Section ─────────────────────────────────────────────────────────────

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

  late final ScrollController _scrollController;
  int _lastAutoLoad = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = ref.read(movieDetailReviewProvider(widget.movieNumber));
    if (_scrollController.position.extentAfter > 200) {
      _lastAutoLoad = -1;
      return;
    }
    if (state.items.length == _lastAutoLoad) return;
    _lastAutoLoad = state.items.length;
    _controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movieDetailReviewProvider(widget.movieNumber));

    return _SectionWrapper(
      title: '评论',
      child: state.isInitialLoading && state.items.isEmpty
          ? _buildSkeleton(context)
          : state.initialErrorMessage != null && state.items.isEmpty
              ? _buildError(state.initialErrorMessage!, () => _controller.loadInitial(), context)
              : state.items.isEmpty
                  ? const AppEmptyState(message: '暂无评论')
                  : SizedBox(
                      height: 280,
                      child: ListView.separated(
                        controller: _scrollController,
                        key: const Key('inline-review-list'),
                        itemCount: state.items.length + 1,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: context.appSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index < state.items.length) {
                            return _ReviewCard(review: state.items[index]);
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
                    ),
    );
  }

  Widget _buildSkeleton(BuildContext ctx) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(height: ctx.appSpacing.sm),
        itemBuilder: (_, __) => Container(
          height: 64,
          decoration: BoxDecoration(
            color: ctx.appColors.surfaceMuted,
            borderRadius: ctx.appRadius.mdBorder,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg, VoidCallback onRetry, BuildContext ctx) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg,
              style: resolveAppTextStyle(ctx,
                  size: AppTextSize.s14, tone: AppTextTone.secondary)),
          SizedBox(height: ctx.appSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final MovieReviewDto review;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final reviewDate = review.createdAt != null
        ? _formatDate(review.createdAt!)
        : '';

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.username.trim().isEmpty
                    ? '匿名用户'
                    : review.username,
                style: resolveAppTextStyle(context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium),
              ),
              SizedBox(width: spacing.xs),
              Icon(Icons.star_rounded,
                  size: 12, color: colors.movieDetailScoreIcon),
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
          SizedBox(height: spacing.xs),
          Text(
            review.content.trim().isEmpty
                ? '暂无评论内容'
                : review.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(context,
                size: AppTextSize.s12, tone: AppTextTone.secondary),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── 磁力 Section ─────────────────────────────────────────────────────────────

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.search();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movieDetailMagnetProvider(widget.movieNumber));
    final spacing = context.appSpacing;

    return _SectionWrapper(
      title: '磁力搜索',
      child: state.isLoading && state.items.isEmpty
          ? _buildSkeleton(context)
          : state.errorMessage != null && state.items.isEmpty
              ? _buildError(state.errorMessage!, () => _controller.search(), context)
              : state.items.isEmpty && state.hasSearched
                  ? const AppEmptyState(message: '暂无磁力资源')
                  : Column(
                      children: [
                        // Sort bar
                        SizedBox(
                          height: 28,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final field in MovieDetailMagnetSortField.values)
                                Padding(
                                  padding: EdgeInsets.only(right: spacing.xs),
                                  child: AppTextButton(
                                    key: Key('inline-magnet-sort-${field.name}'),
                                    label: field.label,
                                    size: AppTextButtonSize.xSmall,
                                    isSelected: state.selectedSortField == field,
                                    onPressed: () => _controller.setSortField(field),
                                  ),
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
                        ),
                        SizedBox(height: spacing.sm),
                        if (state.items.isEmpty)
                          const Center(
                              child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CupertinoActivityIndicator(),
                          ))
                        else
                          SizedBox(
                            height: 240,
                            child: ListView.separated(
                              key: const Key('inline-magnet-list'),
                              itemCount: state.sortedItems.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: spacing.sm),
                              itemBuilder: (context, index) {
                                return _MagnetCard(
                                  candidate: state.sortedItems[index],
                                  movieNumber: widget.movieNumber,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
    );
  }

  Widget _buildSkeleton(BuildContext ctx) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(height: ctx.appSpacing.sm),
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

  Widget _buildError(String msg, VoidCallback onRetry, BuildContext ctx) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg,
              style: resolveAppTextStyle(ctx,
                  size: AppTextSize.s14, tone: AppTextTone.secondary)),
          SizedBox(height: ctx.appSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _MagnetCard extends ConsumerStatefulWidget {
  const _MagnetCard({required this.candidate, required this.movieNumber});
  final DownloadCandidateDto candidate;
  final String movieNumber;

  @override
  ConsumerState<_MagnetCard> createState() => _MagnetCardState();
}

class _MagnetCardState extends ConsumerState<_MagnetCard> {
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
      final ctrl =
          ref.read(movieDetailMagnetProvider(widget.movieNumber).notifier);
      await ctrl.submitCandidate(widget.candidate, clientId: _selectedClientId!);
      if (mounted) {
        final name = widget.candidate.selectableDownloadClients
            .where((c) => c.id == _selectedClientId).firstOrNull?.name ?? '下载器';
        showToast('已提交到 $name');
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (_) {
      if (mounted) {
        showToast('提交失败');
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final magnetUrl = candidate.magnetUrl ?? '';

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: indexer badge + title + copy button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (candidate.indexerName.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(right: spacing.xs),
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.xs,
                              vertical: spacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.movieCardPlayableBadgeBackground
                                  .withValues(alpha: 0.2),
                              borderRadius: context.appRadius.xsBorder,
                            ),
                            child: Text(
                              candidate.indexerName,
                              style: resolveAppTextStyle(context,
                                  size: AppTextSize.s10,
                                  weight: AppTextWeight.medium,
                                  tone: AppTextTone.primary),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            candidate.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: resolveAppTextStyle(context,
                                size: AppTextSize.s12,
                                weight: AppTextWeight.medium),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    Wrap(
                      spacing: spacing.sm,
                      children: [
                        Text(
                          '做种: ${candidate.seeders}',
                          style: resolveAppTextStyle(context,
                              size: AppTextSize.s10,
                              tone: AppTextTone.muted),
                        ),
                        Text(
                          formatFileSize(candidate.sizeBytes),
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
                GestureDetector(
                  onTap: () async {
                    final copied = await copyTextToClipboard(magnetUrl);
                    if (context.mounted) {
                      showToast(copied ? '磁力链接已复制' : '复制失败');
                    }
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.sm),
          // Bottom: client selector + action button
          if (candidate.selectableDownloadClients.isNotEmpty)
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    child: AppSelectField<int>(
                      value: _selectedClientId,
                      size: AppSelectFieldSize.compact,
                      items: candidate.selectableDownloadClients
                          .map((c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedClientId = v),
                    ),
                  ),
                  SizedBox(width: spacing.xs),
                  AppButton(
                    key: const Key('inline-magnet-submit'),
                    size: AppButtonSize.xSmall,
                    label: _submitted
                        ? '已提交'
                        : candidate.hasDownloadSource ? '提交下载' : '无资源',
                    variant: _submitted
                        ? AppButtonVariant.ghost
                        : AppButtonVariant.primary,
                    isLoading: _isSubmitting,
                    onPressed:
                        (_submitted || !candidate.hasDownloadSource)
                            ? null
                            : _handleSubmit,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 缩略图占位 ───────────────────────────────────────────────────────────────

class _InlineThumbnailPlaceholder extends StatelessWidget {
  const _InlineThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _SectionWrapper(
      title: '缩略图',
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            SizedBox(height: context.appSpacing.sm),
            Text(
              '点击进入详情页查看缩略图',
              style: resolveAppTextStyle(context,
                  size: AppTextSize.s12, tone: AppTextTone.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _SectionWrapper extends StatelessWidget {
  const _SectionWrapper({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: resolveAppTextStyle(context,
                size: AppTextSize.s12, tone: AppTextTone.secondary),
          ),
          SizedBox(height: spacing.sm),
          child,
        ],
      ),
    );
  }
}
