import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildWatcherTheme() {
  const scheme = ColorScheme.dark(
    primary: WColors.primary,
    onPrimary: WColors.text,
    secondary: WColors.data,
    onSecondary: WColors.base,
    error: WColors.down,
    onError: WColors.text,
    surface: WColors.base,
    onSurface: WColors.text,
    surfaceContainer: WColors.surface,
    surfaceContainerHigh: WColors.raised,
    outline: WColors.separator,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: WColors.base,
    fontFamily: 'Geist',
    textTheme: const TextTheme(
      displayLarge: WText.status,
      headlineLarge: WText.large,
      titleMedium: WText.title,
      bodyLarge: WText.body,
      bodyMedium: WText.body,
      bodySmall: WText.caption,
      labelMedium: WText.label,
    ),
    dividerColor: WColors.separator,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: WColors.primary),
  );
}
