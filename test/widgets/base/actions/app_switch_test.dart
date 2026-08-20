import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';

void main() {
  testWidgets('app switch uses compact track tokens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: AppSwitch(value: false, onChanged: null)),
      ),
    );

    final tokens = AppComponentTokens.defaults();
    expect(
      tester.getSize(find.byType(AppSwitch)),
      Size(tokens.switchTrackWidth, tokens.switchTrackHeight),
    );
  });

  testWidgets('app switch reports inverted value on tap', (
    WidgetTester tester,
  ) async {
    bool? toggled;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppSwitch(value: false, onChanged: (value) => toggled = value),
        ),
      ),
    );

    await tester.tap(find.byType(AppSwitch));
    expect(toggled, isTrue);
  });

  testWidgets('app switch is inert when onChanged is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(body: const AppSwitch(value: true, onChanged: null)),
      ),
    );

    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(AppSwitch),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNull);

    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
  });

  testWidgets('app switch uses brand primary when enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(body: AppSwitch(value: true, onChanged: (_) {})),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(AppSwitch),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, sakuraThemeData.colorScheme.primary);
  });

  testWidgets('app switch uses neutral track when off', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(body: AppSwitch(value: false, onChanged: (_) {})),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(AppSwitch),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.defaults().borderStrong);
  });
}
