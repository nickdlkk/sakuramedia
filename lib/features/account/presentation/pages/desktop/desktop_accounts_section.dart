import 'package:flutter/material.dart';
import 'package:sakuramedia/features/account/presentation/pages/mobile/mobile_accounts_page.dart';

/// Desktop 配置页账号与权限 tab。
/// 这里直接复用 MobileAccountsPage，让内部 ListView 使用 IndexedStack 提供的有界高度。
class DesktopAccountsSection extends StatelessWidget {
  const DesktopAccountsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileAccountsPage();
  }
}
