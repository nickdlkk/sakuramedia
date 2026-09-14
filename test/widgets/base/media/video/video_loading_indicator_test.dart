import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS,
    TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('video loading keeps on-media color on ${platform.name}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: sakuraThemeData.copyWith(platform: platform),
        home: const Scaffold(backgroundColor: Colors.black,
          body: Center(child: VideoLoadingIndicator())),
      ));
      expect(find.text('正在加载…'), findsOneWidget);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator));
      expect(spinner.key, const Key('video-loading-spinner'));
      if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
        expect(tester.widget<CupertinoActivityIndicator>(
          find.byType(CupertinoActivityIndicator)).color,
          sakuraThemeData.appTextPalette.onMedia);
      } else {
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(spinner.valueColor!.value, sakuraThemeData.appTextPalette.onMedia);
        expect(spinner.backgroundColor, isNull);
      }
    });
  }
}
