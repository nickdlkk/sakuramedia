import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_providers.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_provider.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/overview_skeleton_page.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/pump_with_providers.dart';
import '../../../../../support/test_api_bundle.dart';

/// 锁住 tab 序号 reporter 的三个易碎语义(迁 Riverpod Notifier 前后都必须成立):
/// 1. 首帧对齐推迟到 postFrame——build 期写 provider 会抛
///    「setState() called during build」;
/// 2. 切 tab 后 provider 值跟随;
/// 3. 相同值不通知监听方(拖动动画每帧回调不引起壳重建)。
void main() {
  Future<SessionStore> buildSessionStore() async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-04T12:00:00Z'),
    );
    return sessionStore;
  }

  int readIndex(WidgetTester tester) {
    final context = tester.element(
      find.byKey(const Key('mobile-overview-skeleton-page')),
    );
    final container = ProviderScope.containerOf(context, listen: false);
    return container.read(mobileOverviewTabIndexProvider);
  }

  testWidgets(
    'reporter aligns provider after first frame without build-phase crash',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sessionStore = await buildSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      await pumpWithProviders(
        tester,
        home: const MobileOverviewSkeletonPage(),
        bundle: bundle,
      );
      // 首帧对齐走 postFrame,这里若在 build 期写 provider 会直接抛异常挂掉。
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(readIndex(tester), 0);
      // 收干净页面内启动的一次性 Timer(标签页里的请求/动画),避免尾部断言。
      await tester.pumpAndSettle();
    },
  );

  testWidgets('provider value follows tab switches and dedupes same value', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sessionStore = await buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);

    await pumpWithProviders(
      tester,
      home: const MobileOverviewSkeletonPage(),
      bundle: bundle,
    );
    await tester.pump();

    final context = tester.element(
      find.byKey(const Key('mobile-overview-tab-view')),
    );
    final tabController = DefaultTabController.of(context);
    final container = ProviderScope.containerOf(context, listen: false);

    var notifications = 0;
    final subscription = container.listen(mobileOverviewTabIndexProvider, (
      _,
      __,
    ) {
      notifications += 1;
    });
    addTearDown(subscription.close);

    tabController.animateTo(3);
    await tester.pumpAndSettle();
    expect(readIndex(tester), 3);
    final notificationsAfterSwitch = notifications;
    expect(notificationsAfterSwitch, greaterThan(0));

    // 相同值再上报:不触发监听方。
    tabController.animateTo(3);
    await tester.pumpAndSettle();
    expect(notifications, notificationsAfterSwitch);
  });

  testWidgets('keeps the My tab input after visiting every overview tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sessionStore = await buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);

    await pumpWithProviders(
      tester,
      home: const MobileOverviewSkeletonPage(),
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const Key('mobile-overview-my-search-input'));
    await tester.enterText(input, 'SSNI-888');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    final context = tester.element(
      find.byKey(const Key('mobile-overview-tab-view')),
    );
    final tabController = DefaultTabController.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final audits =
        <({int index, bool Function() exists, Object Function() notifier})>[
          (
            index: 1,
            exists: () => container.exists(clipsOverviewProvider),
            notifier: () => container.read(clipsOverviewProvider.notifier),
          ),
          (
            index: 2,
            exists: () => container.exists(discoveryDailyPreviewProvider(10)),
            notifier: () =>
                container.read(discoveryDailyPreviewProvider(10).notifier),
          ),
          (
            index: 3,
            exists: () => container.exists(momentsProvider),
            notifier: () => container.read(momentsProvider.notifier),
          ),
        ];
    for (final audit in audits) {
      tabController.animateTo(audit.index);
      await tester.pumpAndSettle();
      final notifierBefore = audit.notifier();
      expect(audit.exists(), isTrue);

      tabController.animateTo(0);
      await tester.pumpAndSettle();
      expect(audit.exists(), isTrue);

      tabController.animateTo(audit.index);
      await tester.pumpAndSettle();
      expect(identical(audit.notifier(), notifierBefore), isTrue);
    }
    tabController.animateTo(0);
    await tester.pumpAndSettle();

    expect(tester.widget<TextFormField>(input).controller!.text, 'SSNI-888');
  });
}
