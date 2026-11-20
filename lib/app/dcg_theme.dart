import 'package:flutter/material.dart';

import '../core/presentation.dart';

const _dcgGray = Color(0xFF888B8D);
const _coolGray4 = Color(0xFFBBBCBC);
const _coolGray6 = Color(0xFFA7A8A9);
const _charcoal = Color(0xFF171819);

ThemeData dcgTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dcgRed,
    brightness: brightness,
  ).copyWith(
    // Keep red text legible on charcoal and use the official red for fills.
    primary: dark ? const Color(0xFFFFA3B0) : dcgRed,
    onPrimary: dark ? _charcoal : Colors.white,
    primaryContainer: dark ? const Color(0xFF343638) : const Color(0xFFECEDEE),
    onPrimaryContainer: dark ? Colors.white : _charcoal,
    secondary: dark ? _coolGray6 : _dcgGray,
    onSecondary: _charcoal,
    secondaryContainer: dark ? const Color(0xFF343638) : _coolGray4,
    onSecondaryContainer: dark ? Colors.white : _charcoal,
    surface: dark ? _charcoal : Colors.white,
    surfaceDim: dark ? _charcoal : const Color(0xFFF0F0F1),
    surfaceBright: dark ? const Color(0xFF3B3D3E) : Colors.white,
    surfaceContainerLowest: dark ? const Color(0xFF121314) : Colors.white,
    surfaceContainerLow:
        dark ? const Color(0xFF222425) : const Color(0xFFF7F7F8),
    surfaceContainer: dark ? const Color(0xFF292B2D) : const Color(0xFFF1F1F2),
    surfaceContainerHigh:
        dark ? const Color(0xFF303234) : const Color(0xFFECEDEE),
    surfaceContainerHighest:
        dark ? const Color(0xFF393B3D) : const Color(0xFFE4E5E6),
    onSurface: dark ? Colors.white : _charcoal,
    onSurfaceVariant: dark ? _coolGray4 : const Color(0xFF484B4D),
    outline: dark ? _coolGray6 : _dcgGray,
    outlineVariant: dark ? const Color(0xFF505355) : _coolGray4,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          backgroundColor: dcgRed, foregroundColor: Colors.white),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: dcgRed,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.surfaceContainerHighest,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? scheme.primary : scheme.onSurface,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
  );
}
