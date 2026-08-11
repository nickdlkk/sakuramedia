import 'package:flutter/material.dart';

class AppImageActionTrigger extends StatelessWidget {
  const AppImageActionTrigger({
    super.key,
    required this.child,
    this.onRequestMenu,
    this.onTap,
    this.onLongPress,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final Widget child;
  final ValueChanged<Offset>? onRequestMenu;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) {
    final onRequestMenu = this.onRequestMenu;
    final onLongPress = this.onLongPress;
    return MouseRegion(
      cursor: mouseCursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPressStart: onRequestMenu != null
            ? (details) => onRequestMenu(details.globalPosition)
            : (onLongPress != null ? (_) => onLongPress() : null),
        onSecondaryTapDown:
            onRequestMenu == null
                ? null
                : (details) => onRequestMenu(details.globalPosition),
        child: child,
      ),
    );
  }
}
