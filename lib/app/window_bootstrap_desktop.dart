import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const Size _defaultWindowSize = Size(1280, 720);
const Size _minimumWindowSize = Size(1280, 720);

const String _prefsWidthKey = 'desktop_window:width';
const String _prefsHeightKey = 'desktop_window:height';
const String _prefsMaximizedKey = 'desktop_window:maximized';

Future<void> bootstrapDesktopWindow() async {
  await windowManager.ensureInitialized();
  final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
  final isWindows = defaultTargetPlatform == TargetPlatform.windows;

  final restored = await _readPersistedWindowState();

  final windowOptions = WindowOptions(
    size: restored.size,
    minimumSize: _minimumWindowSize,
    center: true,
    backgroundColor: isMacOS || isWindows
        ? Colors.transparent
        : const AppColors.defaults().surfaceCard,
    skipTaskbar: false,
    titleBarStyle: isMacOS || isWindows
        ? TitleBarStyle.hidden
        : TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (isWindows) {
      // Hidden title bars still reserve native side/bottom resize borders.
      await windowManager.setAsFrameless();
      // Frameless windows default to no shadow; enable the native DWM shadow
      // after switching modes (setHasShadow is a no-op on framed Windows).
      await windowManager.setHasShadow(true);
      await acrylic.Window.initialize();
      final windowsBuild = await const MethodChannel(
        'sakuramedia/window_effects',
      ).invokeMethod<int>('getWindowsBuildNumber');
      // Apply after window_manager's frame setup: Acrylic extends the DWM
      // backdrop across the client area, visible through the sidebar only.
      await acrylic.Window.setEffect(
        // Acrylic stalls native window dragging on Windows 10. Aero keeps
        // the sidebar blurred without that compositor performance issue.
        effect: (windowsBuild ?? 0) >= 22000
            ? acrylic.WindowEffect.acrylic
            : acrylic.WindowEffect.aero,
        color: const AppColors.defaults().desktopSidebarGlassTint,
        dark: false,
      );
    }
    if (restored.maximized) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });

  windowManager.addListener(_DesktopWindowStatePersistor());
}

class _PersistedWindowState {
  const _PersistedWindowState({required this.size, required this.maximized});
  final Size size;
  final bool maximized;
}

Future<_PersistedWindowState> _readPersistedWindowState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble(_prefsWidthKey);
    final height = prefs.getDouble(_prefsHeightKey);
    final maximized = prefs.getBool(_prefsMaximizedKey) ?? false;
    if (width == null || height == null) {
      return _PersistedWindowState(
        size: _defaultWindowSize,
        maximized: maximized,
      );
    }
    return _PersistedWindowState(
      size: Size(
        width.clamp(_minimumWindowSize.width, 10000),
        height.clamp(_minimumWindowSize.height, 10000),
      ),
      maximized: maximized,
    );
  } catch (_) {
    return const _PersistedWindowState(
      size: _defaultWindowSize,
      maximized: false,
    );
  }
}

class _DesktopWindowStatePersistor extends WindowListener {
  @override
  Future<void> onWindowResized() async {
    if (await windowManager.isMaximized()) return;
    final size = await windowManager.getSize();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsWidthKey, size.width);
      await prefs.setDouble(_prefsHeightKey, size.height);
    } catch (_) {
      // 持久化失败不影响窗口运行,忽略
    }
  }

  @override
  Future<void> onWindowMaximize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsMaximizedKey, true);
    } catch (_) {
      // 忽略
    }
  }

  @override
  Future<void> onWindowUnmaximize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsMaximizedKey, false);
    } catch (_) {
      // 忽略
    }
  }
}
