import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF3567E8);
  static const ink = Color(0xFF263449);
  static const muted = Color(0xFF65748A);
  static const shell = Color(0xFFF4F6F9);
  static const line = Color(0xFFE4E9F0);
  static const selection = Color(0xFFEAF0FB);
  static const green = Color(0xFF23835A);
  static const red = Color(0xFFBD3C49);
  static const amber = Color(0xFFA96818);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Microsoft YaHei',
  fontFamilyFallback: const ['Segoe UI', 'Arial'],
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
    onSurface: AppColors.ink,
    error: AppColors.red,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: AppColors.ink),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
  ),
  dividerColor: AppColors.line,
  dividerTheme: const DividerThemeData(
    color: AppColors.line,
    thickness: 1,
    space: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      textStyle: const TextStyle(
        fontFamily: 'Microsoft YaHei',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: AppColors.muted,
      iconSize: 18,
      minimumSize: const Size(30, 30),
      padding: const EdgeInsets.all(5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    side: const BorderSide(color: Color(0xFFB9C4D3), width: 1.2),
    visualDensity: VisualDensity.compact,
  ),
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 500),
  ),
  splashFactory: NoSplash.splashFactory,
);

Color methodColor(String method) => switch (method) {
  'GET' => AppColors.green,
  'POST' => AppColors.amber,
  'DELETE' => AppColors.red,
  _ => AppColors.primary,
};

const codeStyle = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Microsoft YaHei'],
  fontSize: 13,
  height: 1.65,
  color: AppColors.ink,
);
