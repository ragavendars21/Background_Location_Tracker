import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/location/presentation/screens/home_screen.dart';

/// Root widget. No DI here — Riverpod's ProviderScope (in main.dart) owns
/// all dependency construction. App just configures MaterialApp.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Location Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
