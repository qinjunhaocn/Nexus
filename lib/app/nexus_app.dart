import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import 'theme/app_theme.dart';

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  static const _fallbackSeed = Color(0xFF3F51B5);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.light,
            );
        final darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Nexus',
          debugShowCheckedModeBanner: false,
          theme: buildNexusTheme(lightScheme),
          darkTheme: buildNexusTheme(darkScheme),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}
