import 'package:flutter/material.dart';
import 'package:sakuramedia/features/account/presentation/pages/desktop/desktop_accounts_section.dart';
import 'package:sakuramedia/features/account/presentation/pages/mobile/mobile_accounts_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/account_security_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/advanced_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/download_clients_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/download_preference_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/indexer_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/media_libraries_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/playlists_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/llm_settings_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_rail.dart';

class DesktopConfigurationPage extends StatefulWidget {
  const DesktopConfigurationPage({super.key});

  @override
  State<DesktopConfigurationPage> createState() =>
      _DesktopConfigurationPageState();
}

class _DesktopConfigurationPageState extends State<DesktopConfigurationPage> {
  static const int _defaultSelectedIndex = 1;
  static const int _advancedSettingsIndex = 7;

  int _selectedIndex = _defaultSelectedIndex;
  bool _advancedSettingsDirty = false;

  // 顺序即右侧 IndexedStack 的索引；itemKey 沿用原 tab key，保持深链/测试兼容。
  static const List<_ConfigurationCategory> _categories = [
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-account-security'),
      label: '账号安全',
      icon: Icons.shield_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-media-libraries'),
      label: '媒体库',
      icon: Icons.folder_open_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-downloads'),
      label: '下载器',
      icon: Icons.download_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-indexers'),
      label: '索引器',
      icon: Icons.travel_explore_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-download-preference'),
      label: '下载偏好',
      icon: Icons.low_priority_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-llm'),
      label: 'LLM 配置',
      icon: Icons.auto_awesome_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-playlists'),
      label: '播放列表',
      icon: Icons.playlist_play_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-advanced'),
      label: '高级设置',
      icon: Icons.tune_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-accounts'),
      label: '账号与权限',
      icon: Icons.group_outlined,
    ),
    // 媒体维护 / 媒体管理已迁出：并入侧边栏「管理 > 媒体管理」独立页（三 tab）。
  ];

  Future<void> _select(int index) async {
    if (_selectedIndex == index) {
      return;
    }
    if (_selectedIndex == _advancedSettingsIndex && _advancedSettingsDirty) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '有未保存的改动',
        message: '高级设置里还有未保存的改动，确认离开？',
        confirmLabel: '确认离开',
        dialogKey: const Key('configuration-advanced-leave-confirm-dialog'),
        confirmKey: const Key('configuration-advanced-leave-confirm-button'),
        cancelKey: const Key('configuration-advanced-leave-cancel-button'),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleAdvancedDirtyChanged(bool dirty) {
    if (_advancedSettingsDirty == dirty) {
      return;
    }
    setState(() {
      _advancedSettingsDirty = dirty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      key: const Key('configuration-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsRail(
          selectedIndex: _selectedIndex,
          onSelected: _select,
          items: [
            for (final category in _categories)
              AppSettingsRailItem(
                itemKey: category.itemKey,
                label: category.label,
                icon: category.icon,
              ),
          ],
        ),
        SizedBox(width: spacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: spacing.lg),
                child: Text(
                  _categories[_selectedIndex].label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s20,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  sizing: StackFit.expand,
                  children: [
                    const _ConfigurationTabScrollView(
                      child: AccountSecuritySection(),
                    ),
                    _ConfigurationTabScrollView(
                      child: MediaLibrariesSection(active: _selectedIndex == 1),
                    ),
                    _ConfigurationTabScrollView(
                      child: DownloadClientsSection(
                        active: _selectedIndex == 2,
                      ),
                    ),
                    _ConfigurationTabScrollView(
                      child: IndexerSettingsSection(
                        active: _selectedIndex == 3,
                      ),
                    ),
                    _ConfigurationTabScrollView(
                      child: DesktopDownloadPreferenceSection(
                        active: _selectedIndex == 4,
                      ),
                    ),
                    LlmSettingsPage(active: _selectedIndex == 5),
                    _ConfigurationTabScrollView(
                      child: PlaylistsSection(active: _selectedIndex == 6),
                    ),
                    _ConfigurationTabScrollView(
                      child: DesktopAdvancedSettingsSection(
                        active: _selectedIndex == _advancedSettingsIndex,
                        onDirtyChanged: _handleAdvancedDirtyChanged,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        right: context.appSpacing.lg,
                        bottom: context.appSpacing.xxl,
                      ),
                      child: MobileAccountsPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 系统设置左侧分类项描述。
class _ConfigurationCategory {
  const _ConfigurationCategory({
    required this.itemKey,
    required this.label,
    required this.icon,
  });

  final Key itemKey;
  final String label;
  final IconData icon;
}

class _ConfigurationTabScrollView extends StatelessWidget {
  const _ConfigurationTabScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          right: context.appSpacing.lg,
          bottom: context.appSpacing.xxl,
        ),
        child: _ErrorCapture(child: child),
      ),
    );
  }
}

class _ErrorCapture extends StatefulWidget {
  final Widget child;
  const _ErrorCapture({required this.child});
  @override
  State<_ErrorCapture> createState() => _ErrorCaptureState();
}

class _ErrorCaptureState extends State<_ErrorCapture> {
  Object? _error;
  StackTrace? _stack;
  bool _built = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_built) {
      _built = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _error == null) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.red.shade100,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ERROR: $_error',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_stack?.toString() ?? '', style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
    }
    try {
      return widget.child;
    } catch (e, st) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _error = e; _stack = st; });
      });
      return const SizedBox.shrink();
    }
  }
}
