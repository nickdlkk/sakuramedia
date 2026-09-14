import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/video_collection_episode_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/episode_selector_overlay.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets('${mobile ? '移动' : '桌面'}选集更多不触发播放，移出与删除有独立语义', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = mobile
          ? const Size(844, 390)
          : const Size(1100, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int plays = 0;
      VideoCollectionEpisodeAction? action;
      await tester.pumpWidget(
        MaterialApp(
          theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => Stack(
                children: [
                  EpisodeSelectorOverlay(
                    isOpen: true,
                    itemCount: 1,
                    currentIndex: 0,
                    title: '选集 · 1',
                    onClose: () {},
                    itemBuilder: (_, index) => VideoEpisodeQueueItem(
                      video: VideoItemListItemDto.fromJson({
                        'id': 7,
                        'title': '第一集：湖畔日落',
                        'media_count': 1,
                      }),
                      index: 0,
                      isCurrent: true,
                      isBusy: false,
                      onPlay: () => plays++,
                      onActions: (position) async {
                        action = await showVideoCollectionEpisodeActions(
                          context: context,
                          title: '第一集：湖畔日落',
                          position: position,
                          useTouchOptimizedControls: mobile,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-more-7')));
      await tester.pumpAndSettle();
      expect(plays, 0);
      expect(find.text('保留视频和媒体文件'), findsOneWidget);
      expect(find.text('删除视频及全部关联媒体'), findsOneWidget);
      await tester.tap(find.byKey(const Key('video-episode-action-remove')));
      await tester.pumpAndSettle();
      expect(action, VideoCollectionEpisodeAction.remove);
      expect(plays, 0);
      if (mobile) {
        await tester.longPress(find.text('第一集：湖畔日落'));
      } else {
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await mouse.down(tester.getCenter(find.text('第一集：湖畔日落')));
        await mouse.up();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-episode-action-delete')));
      await tester.pumpAndSettle();
      expect(action, VideoCollectionEpisodeAction.delete);
      expect(plays, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('横屏删除确认可滚动，请求中防重复和关闭，失败可重试', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    var pending = Completer<void>();
    await tester.pumpWidget(
      OKToast(
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showVideoEpisodeDeleteConfirmation(
                  context: context,
                  title: '一段比较长的选集名称，包含多个场景和很多说明内容，名称应当最多显示两行',
                  onConfirm: () {
                    attempts++;
                    return pending.future;
                  },
                ),
                child: const Text('打开确认'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开确认'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('video-episode-delete-confirm'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(confirm);
    await tester.pump();
    await tester.tap(confirm);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    expect(attempts, 1);
    expect(confirm, findsOneWidget);
    pending.completeError(StateError('network unavailable'));
    await tester.pumpAndSettle();
    expect(confirm, findsOneWidget);
    pending = Completer<void>();
    await tester.tap(confirm);
    await tester.pump();
    expect(attempts, 2);
    pending.complete();
    await tester.pumpAndSettle();
    expect(confirm, findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
