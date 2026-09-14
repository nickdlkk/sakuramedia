import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';

void main() {
  testWidgets('吸顶栏动态增高、到达末尾和结果遮罩不重叠', (tester) async {
    final controller = ScrollController();
    final headerKey = GlobalKey();
    late StateSetter update;
    var headerHeight = 50.0;
    var isLoading = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AppFilterResultLoadingOverlay(
                isLoading: isLoading,
                hasPreviousItems: false,
                protectedHeaderKey: headerKey,
                scrollController: controller,
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 120, child: Text('资料')),
                    ),
                    AppPinnedListHeader(
                      key: headerKey,
                      color: Colors.white,
                      child: SizedBox(
                        key: const Key('header'),
                        height: headerHeight,
                        child: const Text('筛选'),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: 40,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 80, child: Text('结果 $i')),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    controller.jumpTo(500);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('header'))).dy, 0);
    update(() => headerHeight = 90);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('header'))).dy, 0);
    expect(tester.getSize(find.byKey(const Key('header'))).height, 90);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('header'))).dy, 0);
    update(() => isLoading = true);
    await tester.pump();
    final overlayClip = find
        .ancestor(
          of: find.byKey(const Key('app-filter-result-loading-overlay')),
          matching: find.byType(ClipRect),
        )
        .first;
    final clip = tester.renderObject<RenderClipRect>(overlayClip);
    expect(clip.clipper!.getClip(clip.size).top, 90);
    controller.jumpTo(0);
    await tester.pump();
    expect(clip.clipper!.getClip(clip.size).top, 210);
    update(() => isLoading = false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final count in [0, 1]) {
    testWidgets('短结果列表 $count 条仍保留控制栏', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                const AppPinnedListHeader(
                  color: Colors.white,
                  child: SizedBox(height: 50, child: Text('筛选')),
                ),
                SliverList.builder(
                  itemCount: count,
                  itemBuilder: (_, i) => const SizedBox(height: 80),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('筛选'), findsOneWidget);
      expect(tester.getTopLeft(find.text('筛选')).dy, 120);
      expect(tester.takeException(), isNull);
    });
  }
}
