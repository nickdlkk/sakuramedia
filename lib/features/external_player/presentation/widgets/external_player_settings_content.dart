import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_playback_mode.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

/// 外部播放器设置的共用内容；移动与桌面使用同一份选择和持久化逻辑。
class ExternalPlayerSettingsContent extends ConsumerStatefulWidget {
  const ExternalPlayerSettingsContent({super.key, this.active = true});

  final bool active;

  @override
  ConsumerState<ExternalPlayerSettingsContent> createState() =>
      _ExternalPlayerSettingsContentState();
}

class _ExternalPlayerSettingsContentState
    extends ConsumerState<ExternalPlayerSettingsContent> {
  List<ExternalPlayerApp> _players = const <ExternalPlayerApp>[];
  bool _isLoading = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadIfActive();
  }

  @override
  void didUpdateWidget(covariant ExternalPlayerSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadIfActive();
  }

  void _loadIfActive() {
    if (!widget.active || _initialized) {
      return;
    }
    _initialized = true;
    unawaited(_loadPlayers());
  }

  Future<void> _loadPlayers() async {
    setState(() => _isLoading = true);
    const channel = ExternalPlayerChannel();
    final baseUrl = ref.read(sessionStoreProvider).baseUrl;
    final players = await channel.listPlayers(
      sampleUrl: baseUrl.isNotEmpty ? baseUrl : null,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _players = players;
      _isLoading = false;
    });
  }

  Future<void> _selectInApp() {
    return ref.read(externalPlayerPreferenceProvider.notifier).useInAppPlayer();
  }

  Future<void> _selectPlayer(ExternalPlayerApp player) {
    return ref
        .read(externalPlayerPreferenceProvider.notifier)
        .selectExternalPlayer(playerId: player.id, label: player.label);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox.shrink();
    }

    final spacing = context.appSpacing;
    final selection = ref.watch(externalPlayerPreferenceProvider).value;
    final selectedPlayerId = selection?.playerId;
    final playbackMode =
        selection?.playbackMode ?? ExternalPlaybackMode.followBackend;

    final cells = <Widget>[
      AppSettingCell(
        key: const Key('external-player-in-app'),
        icon: Icons.phonelink_ring_outlined,
        title: '应用内播放器',
        subtitle: '使用樱视内置播放器',
        trailing: selectedPlayerId == null ? const _SelectionCheckMark() : null,
        onTap: selection == null ? null : () => unawaited(_selectInApp()),
      ),
      for (final player in _players)
        AppSettingCell(
          key: Key('external-player-${player.id}'),
          icon: Icons.ondemand_video_outlined,
          title: player.label,
          trailing: selectedPlayerId == player.id
              ? const _SelectionCheckMark()
              : null,
          onTap: selection == null
              ? null
              : () => unawaited(_selectPlayer(player)),
        ),
      if (_isLoading)
        AppSettingCell(
          title: '正在检测已安装的播放器…',
          trailing: SizedBox.square(
            dimension: context.appComponentTokens.iconSizeSm,
            child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      if (!_isLoading && _players.isEmpty)
        const AppSettingCell(
          icon: Icons.video_library_outlined,
          title: '未发现外部播放器',
          subtitle: '安装网络视频播放器后，点击重新检测',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择播放器与播放方式，下次播放时生效。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                '默认播放器',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                ),
              ),
            ),
            AppTextButton(
              key: const Key('external-player-refresh'),
              label: '重新检测',
              size: AppTextButtonSize.small,
              onPressed: _isLoading ? null : () => unawaited(_loadPlayers()),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        AppSettingsGroup(footer: '选择外部播放器后，点击播放会直接打开该应用。', children: cells),
        SizedBox(height: spacing.xl),
        Text(
          '播放模式',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: spacing.sm),
        RadioGroup<ExternalPlaybackMode>(
          groupValue: playbackMode,
          onChanged: (mode) {
            if (mode == null || selection == null) return;
            unawaited(
              ref
                  .read(externalPlayerPreferenceProvider.notifier)
                  .selectPlaybackMode(mode),
            );
          },
          child: AppSettingsGroup(
            footer:
                '仅用于单个媒体的外部播放；合并播放和切片保持原有方式。'
                '所选模式不受媒体来源支持时会播放失败，不会自动切换。',
            children: [
              for (final mode in ExternalPlaybackMode.values)
                _PlaybackModeOption(
                  key: Key('external-playback-mode-${mode.name}'),
                  mode: mode,
                  selected: mode == playbackMode,
                  enabled: selection != null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackModeOption extends StatelessWidget {
  const _PlaybackModeOption({
    super.key,
    required this.mode,
    required this.selected,
    required this.enabled,
  });

  final ExternalPlaybackMode mode;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final (title, description) = switch (mode) {
      ExternalPlaybackMode.followBackend => ('默认', '跟随后端提供的播放方式，不改变播放地址。'),
      ExternalPlaybackMode.proxy => (
        '代理（Proxy）',
        '视频经服务器转发，兼容性更好；会占用服务器带宽。'
            '遇到直连或跨协议跳转失败时可尝试。',
      ),
      ExternalPlaybackMode.redirect => (
        '直连',
        '播放器直接连接媒体来源，减少服务器转发；'
            '需要播放器支持来源地址及重定向。',
      ),
    };
    return Material(
      color: Colors.transparent,
      child: RadioListTile<ExternalPlaybackMode>(
        value: mode,
        enabled: enabled,
        selected: selected,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.xs,
        ),
        title: Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
            tone: selected ? AppTextTone.accent : AppTextTone.primary,
          ),
        ),
        subtitle: Text(
          description,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
      ),
    );
  }
}

class _SelectionCheckMark extends StatelessWidget {
  const _SelectionCheckMark();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle_rounded,
      size: context.appComponentTokens.iconSizeMd,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
