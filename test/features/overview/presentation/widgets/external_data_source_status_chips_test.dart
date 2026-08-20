import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/external_data_source_status_chips.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('未检测时徽章显示未检测图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: null,
        isTesting: false,
      ),
    );

    expect(
      find.byKey(const Key('overview-external-data-source-javdb')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.text('JavDB'), findsOneWidget);
  });

  testWidgets('健康显示成功图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: true,
        isTesting: false,
      ),
    );

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('异常显示失败图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: false,
        isTesting: false,
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets('检测中时徽章用 spinner 替代图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: true,
        isTesting: true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('keyPrefix 决定徽章 Key 前缀', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: null,
        isTesting: false,
        keyPrefix: 'mobile-system-overview',
      ),
    );

    expect(
      find.byKey(
        const Key('mobile-system-overview-external-data-source-javdb'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpChips(WidgetTester tester, Widget chips) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(body: Center(child: chips)),
    ),
  );
}
