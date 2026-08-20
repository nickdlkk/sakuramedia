import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

void main() {
  testWidgets('subscription heart badge keeps 24 layout with 44 hit area', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Center(
            child: SubscriptionHeartBadge(
              loadingKey: const Key('badge-loading'),
              isSubscribed: false,
              isUpdating: false,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    final badge = find.byType(SubscriptionHeartBadge);
    expect(badge, findsOneWidget);
    expect(
      tester.getSize(badge).width,
      AppComponentTokens.defaults().movieCardStatusBadgeSize,
    );
    expect(
      tester.getSize(badge).height,
      AppComponentTokens.defaults().movieCardStatusBadgeSize,
    );

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.favorite_border_rounded),
    );
    expect(icon.size, AppComponentTokens.defaults().iconSizeXl);

    // 点击 24 布局盒外、44 命中区内的位置同样触发订阅。
    final badgeCenter = tester.getCenter(badge);
    await tester.tapAt(badgeCenter + const Offset(16, 0));
    await tester.pump();
    expect(tapped, isTrue);

    // 命中区外（24 + 2*10 之外）不触发。
    tapped = false;
    await tester.tapAt(badgeCenter + const Offset(23, 0));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('subscription heart badge shows loading spinner while updating', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Center(
            child: SubscriptionHeartBadge(
              loadingKey: const Key('badge-loading'),
              isSubscribed: true,
              isUpdating: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('badge-loading')), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });
}
