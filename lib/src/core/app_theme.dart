import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const pink = Color(0xFFFA78A4);
  static const pinkBlack = Color(0xFFC16483);
  static const black = Color(0xFF000000);
  static const gray = Color(0xFFCACACA);
  static const grey = Color(0xFF878787);
  static const white = Color(0xFFFFFFFF);

  static ThemeData light() => _make(false);
  static ThemeData dark() => _make(true);

  static ThemeData _make(bool dark) {
    final surface = dark ? const Color(0xFF141414) : const Color(0xFFF7F7F8);
    final accent = dark ? pink : pinkBlack;
    final foreground = dark ? const Color(0xFFEDEDED) : black;
    final scheme = dark
        ? ColorScheme.fromSeed(
            seedColor: pink,
            brightness: Brightness.dark,
          ).copyWith(
            primary: pink,
            onPrimary: white,
            secondary: pinkBlack,
            surface: surface,
            onSurface: foreground,
            outline: const Color(0xFF5A5A5A),
          )
        : ColorScheme.fromSeed(
            seedColor: pink,
            brightness: Brightness.light,
          ).copyWith(
            primary: accent,
            onPrimary: white,
            secondary: pink,
            surface: Colors.white,
            onSurface: black,
            outline: const Color(0xFFBFBFC4),
          );
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF141414) : pink,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: foreground),
        titleMedium: TextStyle(color: foreground, fontSize: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: dark ? grey : const Color(0xFF9A9AA0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: dark ? black : white,
          minimumSize: const Size(88, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(88, 48),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      dividerColor: gray,
    );
  }
}
