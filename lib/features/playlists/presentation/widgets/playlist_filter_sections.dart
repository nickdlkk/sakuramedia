import 'package:flutter/material.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 播放列表影片筛选的所有 section（分辨率 / 排序）的纵向 Column。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动筛选底部抽屉都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class PlaylistFilterSectionGroup extends StatelessWidget {
  const PlaylistFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final PlaylistFilterState filterState;
  final ValueChanged<PlaylistFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<PlaylistResolutionFilter?>(
          title: '分辨率',
          options: const [null, ...PlaylistResolutionFilter.values],
          selectedValue: filterState.resolution,
          labelBuilder: (value) => value?.label ?? '全部',
          optionKeyBuilder: (value) =>
              Key('playlist-filter-resolution-${value?.apiValue ?? 'all'}'),
          onSelected: (value) =>
              onChanged(filterState.copyWith(resolution: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        _PlaylistSortSection(filterState: filterState, onChanged: onChanged),
      ],
    );
  }
}

class _PlaylistSortSection extends StatelessWidget {
  const _PlaylistSortSection({
    required this.filterState,
    required this.onChanged,
  });

  final PlaylistFilterState filterState;
  final ValueChanged<PlaylistFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final sortField = filterState.sortField;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '排序方式',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: [
            // 最近触达 = 不传 sort，走后端默认（最近触达/入库倒序）。
            AppTextButton(
              key: const Key('playlist-filter-sort-recent'),
              label: '最近触达',
              size: AppTextButtonSize.xSmall,
              isSelected: sortField == null,
              onPressed: () => onChanged(filterState.copyWith(sortField: null)),
            ),
            for (final field in PlaylistSortField.values)
              AppTextButton(
                key: Key('playlist-filter-sort-${field.apiValue}'),
                label: field.label,
                size: AppTextButtonSize.xSmall,
                isSelected: field == sortField,
                onPressed: () =>
                    onChanged(filterState.copyWith(sortField: field)),
              ),
          ],
        ),
        if (sortField != null) ...[
          SizedBox(height: context.appSpacing.md),
          Text(
            '升降序',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          Wrap(
            spacing: context.appSpacing.sm,
            children: SortDirection.values
                .map(
                  (direction) => AppTextButton(
                    key: Key(
                      'playlist-filter-sort-direction-'
                      '${direction == SortDirection.desc ? 'desc' : 'asc'}',
                    ),
                    label: direction == SortDirection.desc ? '降序' : '升序',
                    size: AppTextButtonSize.xSmall,
                    isSelected: direction == filterState.sortDirection,
                    onPressed: () => onChanged(
                      filterState.copyWith(sortDirection: direction),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}
