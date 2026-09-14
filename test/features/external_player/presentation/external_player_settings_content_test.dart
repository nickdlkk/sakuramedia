import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/external_player/data/external_playback_mode.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sakuramedia/external_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SessionStore session;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    session = SessionStore.inMemory();
  });
  tearDown(() {
    session.dispose();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpSettings(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(session)],
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: ExternalPlayerSettingsContent()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('点击整行切换模式，切换播放器保留选择', (tester) async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {'id': 'vlc', 'label': 'VLC'},
      ],
    );
    await pumpSettings(tester);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ExternalPlayerSettingsContent));
    final container = ProviderScope.containerOf(context);
    await tester.ensureVisible(
      find.byKey(const Key('external-playback-mode-proxy')),
    );
    await tester.tap(find.byKey(const Key('external-playback-mode-proxy')));
    await tester.pumpAndSettle();
    expect(
      container
          .read(externalPlayerPreferenceProvider)
          .requireValue
          .playbackMode,
      ExternalPlaybackMode.proxy,
    );
    await tester.ensureVisible(find.byKey(const Key('external-player-vlc')));
    await tester.tap(find.byKey(const Key('external-player-vlc')));
    await tester.pumpAndSettle();
    expect(
      container.read(externalPlayerPreferenceProvider).requireValue.playerId,
      'vlc',
    );
    expect(
      container
          .read(externalPlayerPreferenceProvider)
          .requireValue
          .playbackMode,
      ExternalPlaybackMode.proxy,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('检测加载、空态和重新检测可用，窄屏大字可滚动到全部说明', (tester) async {
    final pending = Completer<List<Map<String, String>>>();
    var requests = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      requests++;
      if (requests == 1) return pending.future;
      return [
        {'id': 'vlc', 'label': 'VLC'},
      ];
    });
    await pumpSettings(tester, scale: 1.5);
    expect(find.text('正在检测已安装的播放器…'), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('未发现外部播放器'), findsOneWidget);
    await tester.tap(find.byKey(const Key('external-player-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('external-player-vlc')), findsOneWidget);
    expect(requests, 2);
    final footer = find.textContaining('所选模式不受媒体来源支持');
    await tester.ensureVisible(footer);
    expect(footer.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
