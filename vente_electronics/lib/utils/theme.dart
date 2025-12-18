// lib/utils/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF0066FF),
    scaffoldBackgroundColor: Colors.grey[50],
    cardColor: Colors.white,
    fontFamily: 'SF Pro',
    useMaterial3: true,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF0066FF),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
  );
}