import "package:flutter/material.dart";

class AppTheme {
  static const Color primaryColor = Color(0xFF5B5FC7);
  static const Color primaryLight = Color(0xFF7B7FDE);
  static const Color accentColor = Color(0xFF3DB8A0);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true, brightness: Brightness.light,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF8F9FB),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, scrolledUnderElevation: 1),
    cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: Colors.white, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0)),
    navigationBarTheme: NavigationBarThemeData(elevation: 1, backgroundColor: Colors.white, indicatorColor: primaryColor.withAlpha(30),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
        ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor)
        : const TextStyle(fontSize: 12, color: Colors.grey))),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: const Color(0xFF1E1E1E), surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade800)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryLight, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: primaryLight, foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0)),
    navigationBarTheme: NavigationBarThemeData(elevation: 1, backgroundColor: const Color(0xFF1E1E1E), indicatorColor: primaryColor.withAlpha(40),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
        ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryLight)
        : TextStyle(fontSize: 12, color: Colors.grey.shade500))),
  );
}
