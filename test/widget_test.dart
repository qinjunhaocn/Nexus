import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/nexus_app.dart';

void main() {
  testWidgets('renders the tinkering space', (tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();

    expect(find.text('Nexus'), findsOneWidget);
    expect(find.text('玩机空间'), findsWidgets);
    expect(find.text('LSPosed 启动器'), findsOneWidget);
    expect(find.text('镜像分区管理'), findsOneWidget);
  });

  testWidgets('changes the selected destination', (tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.textContaining('关于 正在等待'), findsOneWidget);
  });

  testWidgets('renders Android-only tools as unavailable on Windows', (
    tester,
  ) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('仅支持 Android'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '启动'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '启动'))
          .onPressed,
      isNull,
    );
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
    expect(find.text('玩机空间'), findsWidgets);
  });
}
