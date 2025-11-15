import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const InnovaHackApp());
}

class InnovaHackApp extends StatelessWidget {
  const InnovaHackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emacruz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF148040), // Verde corporativo
        ),
        scaffoldBackgroundColor: const Color(0xFFF4EFE3), // Fondo beige
        useMaterial3: true,
        // Fonts más grandes para adultos mayores
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        // Botones más grandes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
