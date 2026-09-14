import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';

/// 仅隔离原生播放器创建；队列、菜单和状态仍使用真实页面逻辑。
final videoCollectionPlaybackFactoryProvider =
    Provider<({Player player, VideoController videoController}) Function()>(
      (ref) => () {
        final player = ThrottlingPlayer();
        return (
          player: player,
          videoController: VideoController(
            player,
            configuration: const VideoControllerConfiguration(hwdec: 'auto'),
          ),
        );
      },
    );
