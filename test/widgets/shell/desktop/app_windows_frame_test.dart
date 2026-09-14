import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_frame.dart';

void main() {
  for (final mode in ['normal', 'maximized', 'fullscreen']) {
    testWidgets('resize handles respect initial $mode window state', (
      tester,
    ) async {
      const channel = MethodChannel('window_manager');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        return switch (call.method) {
          'isMaximized' => mode == 'maximized',
          'isFullScreen' => mode == 'fullscreen',
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AppWindowsFrame(child: Scaffold(body: Text('Content'))),
        ),
      );
      await tester.pumpAndSettle();

      // Normal windows expose all eight edge/corner cursors; maximized and
      // fullscreen windows must not intercept content at the edges.
      final resizeCursors = tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where(
            (region) => const [
              SystemMouseCursors.resizeUpLeft,
              SystemMouseCursors.resizeUp,
              SystemMouseCursors.resizeUpRight,
              SystemMouseCursors.resizeLeft,
              SystemMouseCursors.resizeRight,
              SystemMouseCursors.resizeDownLeft,
              SystemMouseCursors.resizeDown,
              SystemMouseCursors.resizeDownRight,
            ].contains(region.cursor),
          );
      expect(resizeCursors.length, mode == 'normal' ? 8 : 0);
      expect(find.text('Content'), findsOneWidget);
    });
  }
}
