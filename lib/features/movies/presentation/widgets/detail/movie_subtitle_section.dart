import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';

class MovieSubtitleSection extends StatelessWidget {
  const MovieSubtitleSection({
    super.key,
    required this.items,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onOpenSubtitle,
  });

  final List<MovieSubtitleItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final Future<void> Function(MovieSubtitleItemDto item)? onOpenSubtitle;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AppSectionSkeleton(lineCount: 1);
    }

    final error = errorMessage?.trim();
    if (error != null && error.isNotEmpty) {
      return AppEmptyState(
        key: const Key('movie-subtitles-error'),
        icon: Icons.subtitles_outlined,
        title: '字幕列表加载失败',
        message: error,
        onRetry: onRetry == null ? null : () => unawaited(onRetry!()),
        retryKey: const Key('movie-subtitles-retry'),
      );
    }

    if (items.isEmpty) {
      return const AppEmptyState(
        key: Key('movie-subtitles-empty'),
        icon: Icons.subtitles_outlined,
        message: '暂无可用字幕',
      );
    }

    return MovieDetailPillWrap(
      key: const Key('movie-subtitles-list'),
      emptyMessage: '暂无可用字幕',
      items: [
        for (final item in items)
          MovieDetailPillItem(
            key: Key('movie-subtitle-item-${item.subtitleId}'),
            label: item.displayName,
            onTap: onOpenSubtitle == null
                ? null
                : () => unawaited(onOpenSubtitle!(item)),
          ),
      ],
    );
  }
}
