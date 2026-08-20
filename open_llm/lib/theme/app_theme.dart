import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff9ad7ff),
        scaffoldBackgroundColor: const Color(0xff0b1117),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff1769aa),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}