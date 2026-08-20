import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';

/// 弹出移动端榜单筛选底部抽屉。
///
/// chip 选中态即时更新；榜单结果由 Provider 统一防抖刷新。
/// 抽屉没有“确定”按钮，关闭仅靠下拉或点遮罩。
/// [initialAnchor] 用于 chip 点击后定位到对应 section（source/board/period/sort）。
///
Future<void> showMobileRankingFilterDrawer(
  BuildContext context, {
  required RankingSummaryScope scope,
  RankingFilterAnchor? initialAnchor,
  VoidCallback? onFilterChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-rankings-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => _MobileRankingFilterDrawerContent(
      scope: scope,
      initialAnchor: initialAnchor,
      onFilterChanged: onFilterChanged,
    ),
  );
}

class _MobileRankingFilterDrawerContent extends ConsumerStatefulWidget {
  const _MobileRankingFilterDrawerContent({
    required this.scope,
    required this.initialAnchor,
    required this.onFilterChanged,
  });

  final RankingSummaryScope scope;
  final RankingFilterAnchor? initialAnchor;
  final VoidCallback? onFilterChanged;

  @override
  ConsumerState<_MobileRankingFilterDrawerContent> createState() =>
      _MobileRankingFilterDrawerContentState();
}

class _MobileRankingFilterDrawerContentState
    extends ConsumerState<_MobileRankingFilterDrawerContent> {
  late final RankingFilterSectionKeys _sectionKeys;

  @override
  void initState() {
    super.initState();
    _sectionKeys = RankingFilterSectionKeys();
    final anchor = widget.initialAnchor;
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final keyContext = _sectionKeys.forAnchor(anchor).currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 240),
            alignment: 0.05,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters =
        ref.watch(rankingSummaryProvider(widget.scope)).value?.filters ??
        RankingFilterState.initial;
    return AppMobileFilterDrawerScaffold(
      // 榜单没有「恢复默认」语义（来源/榜单必须二选一），故不带 footer。
      scrollViewKey: const Key('mobile-rankings-filter-scroll-view'),
      child: RankingFilterSectionGroup(
        sources: filters.sources,
        selectedSource: filters.selectedSource,
        boards: filters.boards,
        selectedBoard: filters.selectedBoard,
        selectedPeriod: filters.selectedPeriod,
        onSourceChanged: (value) {
          if (filters.selectedSource?.sourceKey == value.sourceKey) {
            return;
          }
          widget.onFilterChanged?.call();
          unawaited(
            ref
                .read(rankingSummaryProvider(widget.scope).notifier)
                .selectSource(value),
          );
        },
        onBoardChanged: (value) {
          if (filters.selectedBoard?.boardKey == value.boardKey) {
            return;
          }
          widget.onFilterChanged?.call();
          unawaited(
            ref
                .read(rankingSummaryProvider(widget.scope).notifier)
                .selectBoard(value),
          );
        },
        onPeriodChanged: (value) {
          if (filters.selectedPeriod == value) return;
          widget.onFilterChanged?.call();
          unawaited(
            ref
                .read(rankingSummaryProvider(widget.scope).notifier)
                .selectPeriod(value),
          );
        },
        selectedSortField: filters.selectedSortField,
        selectedSortDirection: filters.selectedSortDirection,
        onSortChanged: (field, direction) {
          if (filters.selectedSortField == field &&
              filters.selectedSortDirection == direction) {
            return;
          }
          widget.onFilterChanged?.call();
          unawaited(
            ref
                .read(rankingSummaryProvider(widget.scope).notifier)
                .selectSort(field, direction),
          );
        },
        sectionKeys: _sectionKeys,
      ),
    );
  }
}
