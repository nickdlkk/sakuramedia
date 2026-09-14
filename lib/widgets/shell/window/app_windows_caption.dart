import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:window_manager/window_manager.dart';

bool get usesAppWindowsCaption =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Reuses the native-style controls and maximize-state listener from window_manager.
class AppWindowsCaption extends StatelessWidget {
  const AppWindowsCaption({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final height = context.appComponentTokens.desktopTitleBarHeight;
    return SizedBox(
      height: height,
      width: standalone ? null : height * 3,
      child: WindowCaption(
        brightness: Theme.of(context).brightness,
        backgroundColor: context.appColors.surfaceElevated,
        title: standalone
            ? Text(
                'SakuraMedia',
                style: resolveAppTextStyle(context, size: AppTextSize.s14),
              )
            : null,
      ),
    );
  }
}
