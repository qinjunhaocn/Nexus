import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/nexus_app.dart';

void main() {
  testWidgets('renders the Nexus empty workspace', (tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();

    expect(find.text('Nexus'), findsOneWidget);
    expect(find.text('Your toolbox is ready'), findsOneWidget);
    expect(find.textContaining('Workspace is waiting'), findsOneWidget);
  });

  testWidgets('changes the selected destination', (tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tools is waiting'), findsOneWidget);
  });

  testWidgets('renders in system dark mode', (tester) async {
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.view.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.system);
    expect(find.text('Your toolbox is ready'), findsOneWidget);
  });
}
