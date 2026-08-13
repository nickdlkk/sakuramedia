import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/core/session/providers/saved_accounts_runtime_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/account/presentation/widgets/add_account_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

class MobileAccountsPage extends ConsumerWidget {
  const MobileAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final snapshot = ref.watch(savedAccountsRuntimeProvider);
    final notifier = ref.read(savedAccountsRuntimeProvider.notifier);

    return ListView(
      key: const Key('mobile-settings-accounts'),
      children: [
        Text(
          '管理已保存账号，并为每个账号单独控制模块可见性。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppButton(
          key: const Key('mobile-settings-accounts-add-button'),
          label: '添加账号',
          variant: AppButtonVariant.primary,
          onPressed: () async {
            final draft = await showAddAccountDialog(
              context,
              sessionStore: ref.read(sessionStoreProvider),
            );
            if (draft == null) {
              return;
            }
            await notifier.saveAuthenticatedAccount(
              baseUrl: draft.baseUrl,
              username: draft.username,
              password: draft.password,
              accessToken: draft.tokens.accessToken,
              refreshToken: draft.tokens.refreshToken,
              expiresAt: draft.tokens.expiresAt,
              enabledModules: draft.enabledModules,
              activate: false,
            );
            if (context.mounted) {
              showToast('账号已添加');
            }
          },
        ),
        SizedBox(height: spacing.lg),
        if (snapshot.accounts.isEmpty)
          const AppEmptyState(message: '还没有已保存账号')
        else
          Column(
            children: [
              for (final account in snapshot.accounts) ...[
                AppSettingsGroup(
                  children: [
                    AppSettingCell(
                      key: Key('mobile-saved-account-${account.id}'),
                      icon: Icons.person_outline_rounded,
                      title: account.displayLabel,
                      subtitle: account.subtitle,
                      trailing: AppBadge(
                        label:
                            snapshot.activeAccountId == account.id ? '当前账号' : '已保存',
                        tone:
                            snapshot.activeAccountId == account.id
                                ? AppBadgeTone.primary
                                : AppBadgeTone.neutral,
                        size: AppBadgeSize.compact,
                      ),
                      onTap:
                          snapshot.activeAccountId == account.id
                              ? null
                              : () async {
                                await notifier.activate(account.id);
                                if (context.mounted) {
                                  showToast('已切换账号');
                                }
                              },
                    ),
                    for (final module in AppModulePermission.values)
                      AppSettingCell(
                        key: Key('mobile-account-module-${account.id}-${module.name}'),
                        icon: module.icon,
                        title: module.label,
                        subtitle: module.description,
                        trailing: Switch(
                          value: account.enabledModules.contains(module),
                          onChanged: (selected) {
                            final next = <AppModulePermission>{
                              ...account.enabledModules,
                            };
                            if (selected) {
                              next.add(module);
                            } else {
                              next.remove(module);
                            }
                            notifier.updateEnabledModules(
                              accountId: account.id,
                              enabledModules: next,
                            );
                          },
                        ),
                      ),
                    AppSettingCell(
                      key: Key('mobile-account-remove-${account.id}'),
                      icon: Icons.delete_outline_rounded,
                      iconColor: context.appTextPalette.error,
                      title: '移除账号',
                      titleTone: AppTextTone.error,
                      trailing:
                          snapshot.accounts.length <= 1
                              ? const AppBadge(
                                label: '至少保留一个',
                                tone: AppBadgeTone.neutral,
                                size: AppBadgeSize.compact,
                              )
                              : null,
                      onTap:
                          snapshot.accounts.length <= 1
                              ? null
                              : () async {
                                final removingActive =
                                    snapshot.activeAccountId == account.id;
                                await notifier.removeAccount(account.id);
                                if (context.mounted) {
                                  showToast(
                                    removingActive ? '当前账号已移除并切换' : '账号已移除',
                                  );
                                }
                              },
                    ),
                  ],
                ),
                if (account != snapshot.accounts.last) SizedBox(height: spacing.md),
              ],
            ],
          ),
      ],
    );
  }
}
