import 'package:flutter/material.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

/// 弹出移动端播放列表影片筛选底部抽屉。
///
/// 内容与桌面 `AppListHeader` 的就地浮层面板**完全一致**（同一个
/// [PlaylistFilterSectionGroup] + 同一个 [AppFilterPanelFooter]），行为也一致：
/// 即时生效、重置在 footer 里。两端只有外层容器不同。
Future<void> showMobilePlaylistFilterDrawer(
  BuildContext context, {
  required PlaylistFilterState current,
  required ValueChanged<PlaylistFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-playlist-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => _MobilePlaylistFilterDrawerContent(
      current: current,
      onChanged: onChanged,
    ),
  );
}

class _MobilePlaylistFilterDrawerContent extends StatefulWidget {
  const _MobilePlaylistFilterDrawerContent({
    required this.current,
    required this.onChanged,
  });

  final PlaylistFilterState current;
  final ValueChanged<PlaylistFilterState> onChanged;

  @override
  State<_MobilePlaylistFilterDrawerContent> createState() =>
      _MobilePlaylistFilterDrawerContentState();
}

class _MobilePlaylistFilterDrawerContentState
    extends State<_MobilePlaylistFilterDrawerContent> {
  late PlaylistFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  /// 就地反映选中态 + 即时向外应用——不是「等确定的草稿」。
  void _apply(PlaylistFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-playlist-filter-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local.isDefault,
        onReset: () => _apply(PlaylistFilterState.initial),
      ),
      child: PlaylistFilterSectionGroup(filterState: _local, onChanged: _apply),
    );
  }
}
