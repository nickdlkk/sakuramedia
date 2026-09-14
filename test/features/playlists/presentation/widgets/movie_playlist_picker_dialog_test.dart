import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/theme.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'pending rows do not block other selections and failures roll back',
    (tester) async {
      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://api.example.com');
      await session.saveTokens(
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: DateTime(2030),
      );
      final bundle = await createTestApiBundle(session);
      addTearDown(() {
        bundle.dispose();
        session.dispose();
      });
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: [
          {'id': 1, 'name': '周末', 'movie_count': 3},
          {'id': 2, 'name': '精选', 'movie_count': 8},
        ],
      );
      final pending = Completer<ResponseBody>();
      bundle.adapter.enqueueResponder(
        method: 'PUT',
        path: '/playlists/1/movies/ABC-001',
        responder: (_, __) => pending.future,
      );
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/playlists/2/movies/ABC-001',
        statusCode: 204,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: OKToast(
            child: MaterialApp(
              theme: sakuraThemeData,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showMoviePlaylistPickerDialog(
                      context,
                      movieNumber: 'ABC-001',
                      initialPlaylists: const [],
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-playlist-option-1')));
      await tester.pump();
      expect(
        find.byKey(const Key('movie-playlist-updating-1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('movie-playlist-option-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const Key('movie-playlist-checkbox-2')),
            )
            .value,
        isTrue,
      );
      pending.complete(
        ResponseBody.fromString(
          '{}',
          400,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const Key('movie-playlist-checkbox-1')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const Key('movie-playlist-checkbox-2')),
            )
            .value,
        isTrue,
      );
      final closing = Completer<ResponseBody>();
      bundle.adapter.enqueueResponder(
        method: 'PUT',
        path: '/playlists/1/movies/ABC-001',
        responder: (_, __) => closing.future,
      );
      await tester.tap(find.byKey(const Key('movie-playlist-option-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('movie-playlist-close-button')));
      await tester.pumpAndSettle();
      closing.complete(
        ResponseBody.fromString(
          '{}',
          400,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
