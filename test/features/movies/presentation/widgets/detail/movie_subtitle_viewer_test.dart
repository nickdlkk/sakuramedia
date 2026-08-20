import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_viewer.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApiBundle bundle;

  setUp(() async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets('loads and shows the raw subtitle text in the desktop viewer', (
    WidgetTester tester,
  ) async {
    final item = MovieSubtitleItemDto(
      subtitleId: 501,
      fileName: 'ABC-001.zh.srt',
      createdAt: null,
      url: '/files/subtitles/501?expires=1700000900&signature=subtitle',
    );
    const subtitleText = '1\n00:00:01,000 --> 00:00:02,000\n你好\n';
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path:
          'https://api.example.com/files/subtitles/501?expires=1700000900&signature=subtitle',
      body: Uint8List.fromList(utf8.encode(subtitleText)),
    );

    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () =>
                      unawaited(showMovieSubtitleViewer(context, item: item)),
                  child: const Text('打开字幕'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开字幕'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-subtitle-viewer-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-subtitle-viewer-text')), findsOneWidget);
    expect(
      find.textContaining('00:00:01,000 --> 00:00:02,000'),
      findsOneWidget,
    );
    expect(find.textContaining('你好'), findsOneWidget);
  });
}
