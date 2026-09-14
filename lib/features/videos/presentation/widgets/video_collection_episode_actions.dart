import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_episode_queue_item.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

enum VideoCollectionEpisodeAction { remove, delete }

Future<VideoCollectionEpisodeAction?> showVideoCollectionEpisodeActions({
  required BuildContext context,
  required String title,
  required Offset position,
  required bool useTouchOptimizedControls,
}) {
  Widget action(BuildContext context, VideoCollectionEpisodeAction value) {
    final deleting = value == VideoCollectionEpisodeAction.delete;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        deleting ? Icons.delete_outline_rounded : Icons.playlist_remove_rounded,
        color: deleting
            ? Theme.of(context).colorScheme.error
            : context.appTextPalette.secondary,
      ),
      title: Text(
        deleting ? '删除选集' : '移出合集',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          tone: deleting ? AppTextTone.error : AppTextTone.primary,
        ),
      ),
      subtitle: Text(
        deleting ? '删除视频及全部关联媒体' : '保留视频和媒体文件',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }

  if (useTouchOptimizedControls) {
    return showAppBottomDrawer<VideoCollectionEpisodeAction>(
      context: context,
      drawerKey: const Key('video-episode-actions'),
      maxHeightFactor: 0.9,
      builder: (sheetContext) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                sheetContext,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
              ),
            ),
            for (final value in VideoCollectionEpisodeAction.values)
              InkWell(
                key: Key('video-episode-action-${value.name}'),
                onTap: () => Navigator.of(sheetContext).pop(value),
                child: action(sheetContext, value),
              ),
            AppTextButton(
              label: '取消',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
  final overlay =
      Navigator.of(
            context,
            rootNavigator: true,
          ).overlay!.context.findRenderObject()!
          as RenderBox;
  final local = overlay.globalToLocal(position);
  return showMenu<VideoCollectionEpisodeAction>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(local.dx, local.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final value in VideoCollectionEpisodeAction.values)
        PopupMenuItem(
          value: value,
          key: Key('video-episode-action-${value.name}'),
          child: action(context, value),
        ),
    ],
  );
}

Future<bool> showVideoEpisodeDeleteConfirmation({
  required BuildContext context,
  required String title,
  required Future<void> Function() onConfirm,
}) => showAppConfirmDialog(
  context,
  title: '删除选集',
  message: '将删除该视频及全部关联媒体文件，并从所有合集中移除。此操作不可恢复。',
  extraContent: Text(
    title,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      tone: AppTextTone.primary,
    ),
  ),
  confirmLabel: '删除选集',
  danger: true,
  // 横屏使用紧凑确认窗；菜单仍为移动操作表。
  variant: AppConfirmVariant.dialog,
  confirmKey: const Key('video-episode-delete-confirm'),
  onConfirm: onConfirm,
);

class VideoEpisodeQueueItem extends StatelessWidget {
  const VideoEpisodeQueueItem({
    super.key,
    required this.video,
    required this.index,
    required this.isCurrent,
    required this.isBusy,
    required this.onPlay,
    required this.onActions,
  });

  final VideoItemListItemDto video;
  final int index;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback? onPlay;
  final ValueChanged<Offset>? onActions;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: onActions == null
        ? null
        : (details) => onActions!(details.globalPosition),
    onLongPressStart: onActions == null
        ? null
        : (details) => onActions!(details.globalPosition),
    child: CollectionEpisodeQueueItem(
      itemKey: Key('video-collection-play-queue-item-${video.id}'),
      coverUrl: video.coverImage?.bestAvailableUrl,
      coverStyle: CollectionQueueCoverStyle.containOnMuted,
      title: video.preferredTitle,
      subtitle: '第 ${index + 1} 集',
      isCurrent: isCurrent,
      onTap: onPlay,
      trailing: Builder(
        builder: (buttonContext) => AppIconButton(
          key: Key('video-episode-more-${video.id}'),
          size: AppIconButtonSize.regular,
          tooltip: '选集操作',
          icon: isBusy
              ? SizedBox.square(
                  dimension: context.appComponentTokens.iconSizeSm,
                  child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Icon(Icons.more_horiz_rounded),
          onPressed: onActions == null
              ? null
              : () {
                  final box = buttonContext.findRenderObject()! as RenderBox;
                  onActions!(
                    box.localToGlobal(Offset(box.size.width, box.size.height)),
                  );
                },
        ),
      ),
    ),
  );
}
