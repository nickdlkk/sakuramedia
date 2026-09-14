import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selector_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

/// 固定区只显示入口和横向摘要，完整标签云在有界面板内滚动。
class TagSelectionHeader extends ConsumerWidget {
  const TagSelectionHeader({
    super.key,
    required this.scope,
    required this.mobile,
  });
  final TagSelectionScope scope;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(tagSelectionProvider(scope));
    final notifier = ref.read(tagSelectionProvider(scope).notifier);
    final label = selection.hasSelection
        ? '标签 · ${selection.selectedCount}'
        : '选择标签';
    final Widget trigger = mobile
        ? AppTextButton(
            key: const Key('tags-selector-trigger'),
            label: label,
            onPressed: () => showAppBottomDrawer<void>(
              context: context,
              drawerKey: const Key('tags-selector-drawer'),
              maxHeightFactor: 0.7,
              builder: (_) => SingleChildScrollView(
                child: _TagSelectionPanel(scope: scope),
              ),
            ),
          )
        : AppFilterPopover(
            triggerKey: const Key('tags-selector-trigger'),
            triggerLabel: label,
            panelKey: const Key('tags-selector-popover'),
            alignment: AppFilterPopoverAlignment.leftAlignedToTrigger,
            panelBuilder: (_) => _TagSelectionPanel(scope: scope),
          );
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.sm),
      child: Row(
        children: [
          trigger,
          if (selection.hasSelection) ...[
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tag in selection.selectedTags)
                      AppTextButton(
                        key: Key('tags-summary-${tag.tagId}'),
                        label: tag.name,
                        trailingIcon: const Icon(Icons.close),
                        size: AppTextButtonSize.xSmall,
                        onPressed: () => notifier.remove(tag.tagId),
                      ),
                    AppTextButton(
                      key: const Key('tags-summary-clear'),
                      label: '清空',
                      size: AppTextButtonSize.xSmall,
                      onPressed: notifier.clear,
                    ),
                  ],
                ),
              ),
            ),
            AppTextButton(
              key: const Key('tags-summary-match'),
              label: '匹配${selection.matchMode.label}',
              size: AppTextButtonSize.xSmall,
              onPressed: () => notifier.setMatchMode(
                selection.matchMode == TagMatchMode.or
                    ? TagMatchMode.and
                    : TagMatchMode.or,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagSelectionPanel extends ConsumerWidget {
  const _TagSelectionPanel({required this.scope});
  final TagSelectionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(tagSelectionProvider(scope));
    final notifier = ref.read(tagSelectionProvider(scope).notifier);
    return TagSelectorPanel(
      selection: selection,
      onToggleTag: notifier.toggle,
      onRemoveTag: notifier.remove,
      onClear: notifier.clear,
      onQueryChanged: notifier.setQuery,
      onToggleExpanded: notifier.toggleExpanded,
      onMatchModeChanged: notifier.setMatchMode,
      onRetry: () => unawaited(notifier.retry()),
    );
  }
}
