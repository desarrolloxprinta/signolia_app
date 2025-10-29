// lib/ui/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrandColors {
  static const primary   = Color(0xFF347778); // azul verdoso marca
  static const secondary = Color(0xFFEF7F1A); // naranja enlaces/acentos
  static const text      = Color(0xFF0C0B0B);
  static const accent    = Color(0xFF833766);
}

class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.primary,
      onPrimary: Colors.white,
      secondary: BrandColors.secondary, // enlaces y acentos
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: BrandColors.text,
      error: Colors.redAccent,
      onError: Colors.white,
      tertiary: BrandColors.accent,
      onTertiary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white, // asegura blanco
    );

    return base.copyWith(
      // ✅ Cabecera negra unificada (título/íconos blancos + status bar claro)
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.light, // status bar icons claros
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),

      textTheme: base.textTheme.apply(
        bodyColor: BrandColors.text,
        displayColor: BrandColors.text,
      ),

      // Enlaces/acciones en naranja
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.secondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.secondary,
          side: const BorderSide(color: BrandColors.secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE9ECEF)),
      chipTheme: base.chipTheme.copyWith(
        color: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFFE9ECEF)),
        labelStyle: const TextStyle(color: BrandColors.text),
      ),
    );
  }
}
