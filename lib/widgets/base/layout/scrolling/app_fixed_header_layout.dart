import 'package:flutter/material.dart';

/// 列表控制栏占据自身高度，结果区使用剩余空间独立滚动。
class AppFixedHeaderLayout extends StatelessWidget {
  const AppFixedHeaderLayout({
    super.key,
    required this.header,
    required this.child,
  });

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      Expanded(child: child),
    ],
  );
}
