// ─────────────────────────────────────────────────────────────────────────────
// main.dart
// ─────────────────────────────────────────────────────────────────────────────
// This is the ENTRY POINT of the Flutter app.
// Every Flutter app starts from the main() function.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'home_screen.dart'; // We import our home screen from a separate file

// main() is the first function Flutter calls when your app launches.
void main() {
  // WidgetsFlutterBinding.ensureInitialized() sets up the Flutter engine
  // before we run the app. Always call this before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // runApp() takes a Widget and makes it the root of the widget tree.
  // Everything on screen in Flutter is a Widget.
  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// MyApp — The Root Widget
// ─────────────────────────────────────────────────────────────────────────────
// StatelessWidget = a widget that doesn't change over time.
// It just describes how the app looks and sets up MaterialApp.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp is the top-level widget for apps using Material Design.
    // It handles navigation, theming, and routing.
    return MaterialApp(
      title: 'Barcode Scanner', // App name (shown in task switcher)
      debugShowCheckedModeBanner: false, // Hides the "DEBUG" banner top-right

      // ThemeData controls colors, fonts, and styles for the whole app
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo, // Main color of the app
        ),
        useMaterial3: true, // Use the latest Material Design (version 3)
      ),

      // home: defines which screen shows first when the app opens
      home: const HomeScreen(),
    );
  }
}
