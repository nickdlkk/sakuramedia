import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 紧凑型启停开关。
///
/// 用于设置/管理类列表右侧的「启用/停用」操作。尺寸来自
/// [AppComponentTokens]（桌面 36×20、移动 44×24），开启态使用品牌色，
/// 避免 Material 默认 Switch 在桌面端显得过大。
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  /// 当前开关状态。
  final bool value;

  /// 状态变化回调；传 `null` 时开关置灰且不可点。
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = context.appComponentTokens;
    final enabled = onChanged != null;
    final trackWidth = tokens.switchTrackWidth;
    final trackHeight = tokens.switchTrackHeight;
    final thumbDiameter = tokens.switchThumbDiameter;
    final thumbInset = (trackHeight - thumbDiameter) / 2;
    final trackColor = !enabled
        ? colors.borderSubtle
        : value
        ? Theme.of(context).colorScheme.primary
        : colors.borderStrong;

    return Semantics(
      toggled: value,
      enabled: enabled,
      button: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: context.appRadius.pillBorder,
            onTap: enabled ? () => onChanged!(!value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: trackWidth,
              height: trackHeight,
              padding: EdgeInsets.all(thumbInset),
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: context.appRadius.pillBorder,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: thumbDiameter,
                  height: thumbDiameter,
                  decoration: BoxDecoration(
                    color: enabled ? colors.surfaceCard : colors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
