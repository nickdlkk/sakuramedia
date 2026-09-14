import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final outcome in ['success', 'cancel', 'failure']) {
      testWidgets('${mobile ? '移动' : '桌面'}批量取消后的强制处理：$outcome', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(430, 932)
            : const Size(1280, 900);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final session = SessionStore.inMemory();
        await session.saveBaseUrl('https://api.example.com');
        await session.saveTokens(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime(2099),
        );
        final bundle = await createTestApiBundle(session);
        addTearDown(() {
          bundle.dispose();
          session.dispose();
        });
        const original = MovieSubscriptionBatchToggleResult(
          requestedCount: 3,
          updatedCount: 1,
          skippedMovieNotFoundNumbers: ['MISSING'],
          skippedHasMediaNumbers: ['A-1'],
        );
        MovieSubscriptionBatchToggleResult? finalResult;
        await tester.pumpWidget(
          ProviderScope(
            overrides: bundle.riverpodOverrides(),
            child: AppPlatformScope(
              platform: mobile ? AppPlatform.mobile : AppPlatform.desktop,
              child: OKToast(
                child: MaterialApp(
                  theme: sakuraThemeData,
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        child: const Text('开始'),
                        onPressed: () async {
                          finalResult = await runMovieSubscriptionBatch(
                            context: context,
                            keyPrefix: 'test',
                            movieNumbers: ['DONE', 'A-1', 'MISSING'],
                            subscribe: false,
                            execute:
                                ({
                                  required movieNumbers,
                                  required subscribe,
                                }) async => original,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('开始'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('test-batch-unsubscribe-confirm')),
        );
        await tester.pumpAndSettle();
        final forceButton = find.byKey(
          const Key('movie-batch-force-unsubscribe-button'),
        );
        expect(forceButton, findsOneWidget);
        expect(bundle.adapter.requests, isEmpty);
        await tester.tap(forceButton);
        await tester.pumpAndSettle();
        expect(find.textContaining('所有媒体文件及记录'), findsOneWidget);
        expect(bundle.adapter.requests, isEmpty);
        final gates = List.generate(3, (_) => Completer<void>());
        if (outcome == 'cancel') {
          await tester.tap(find.text('取消'));
        } else {
          bundle.adapter.enqueueJson(
            method: 'GET',
            path: '/movies/A-1',
            body: {
              'movie_number': 'A-1',
              'can_play': true,
              'is_subscribed': true,
              'media_items': [
                {'media_id': 11},
                if (outcome == 'success') {'media_id': 12},
              ],
            },
          );
          if (outcome == 'success') {
            for (var i = 0; i < 2; i++) {
              bundle.adapter.enqueueResponder(
                method: 'DELETE',
                path: '/media/${11 + i}',
                responder: (_, _) async {
                  await gates[i].future;
                  return ResponseBody.fromBytes([], 204);
                },
              );
            }
          } else {
            bundle.adapter.enqueueJson(
              method: 'DELETE',
              path: '/media/11',
              statusCode: 500,
            );
          }
          bundle.adapter.enqueueJson(
            method: 'GET',
            path: '/movies/A-1',
            body: {
              'movie_number': 'A-1',
              'can_play': outcome == 'failure',
              'is_subscribed': true,
              'media_items': [],
            },
          );
          if (outcome == 'success') {
            bundle.adapter.enqueueResponder(
              method: 'POST',
              path: '/movies/unsubscriptions',
              responder: (_, _) async {
                await gates[2].future;
                return ResponseBody.fromString(
                  '{"requested_count":1,"updated_count":1,"skipped":[]}',
                  200,
                  headers: {
                    Headers.contentTypeHeader: [Headers.jsonContentType],
                  },
                );
              },
            );
          }
          await tester.tap(
            find.byKey(const Key('movie-batch-force-unsubscribe-confirm')),
          );
        }
        if (outcome == 'success') {
          for (var i = 0; i < 3; i++) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final indicator = tester.widget<LinearProgressIndicator>(
              find.byKey(const Key('movie-batch-force-unsubscribe-progress')),
            );
            expect(indicator.value, i / 2);
            expect(find.textContaining('已删除 $i/2 个媒体'), findsOneWidget);
            if (i == 2) expect(find.textContaining('正在批量取消订阅'), findsOneWidget);
            expect(tester.takeException(), isNull);
            gates[i].complete();
          }
        }
        await tester.pumpAndSettle();
        if (outcome == 'success') {
          expect(find.text('MISSING'), findsOneWidget);
          expect(forceButton, findsNothing);
          final modalContext = tester.element(find.text('MISSING'));
          Navigator.of(modalContext).pop();
          await tester.pumpAndSettle();
          expect(finalResult?.updatedCount, 2);
          expect(finalResult?.allSkippedNumbers, ['MISSING']);
          expect(bundle.adapter.requests.last.body, {
            'movie_numbers': ['A-1'],
          });
        } else {
          expect(finalResult, same(original));
          expect(bundle.adapter.hitCount('POST', '/movies/unsubscriptions'), 0);
          if (outcome == 'cancel') expect(bundle.adapter.requests, isEmpty);
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('普通订阅的未处理清单不提供强制取消', (tester) async {
    await tester.pumpWidget(
      OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('开始'),
                onPressed: () => showMovieSubscriptionBatchFeedback(
                  context,
                  const MovieSubscriptionBatchToggleResult(
                    requestedCount: 1,
                    updatedCount: 0,
                    skippedMovieNotFoundNumbers: ['MISSING'],
                    skippedHasMediaNumbers: [],
                  ),
                  subscribe: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-batch-force-unsubscribe-button')),
      findsNothing,
    );
    Navigator.of(tester.element(find.text('MISSING'))).pop();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
