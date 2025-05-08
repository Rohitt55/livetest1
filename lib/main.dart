import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExpenseMate',
      theme: ThemeData(
        fontFamily: 'NotoSans',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFFDF7F0),
      ),
      debugShowCheckedModeBanner: false,
      home: const EntryPoint(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => HomeScreen(), // ✅ Removed const to allow rebuild
        '/profile': (context) => const ProfileScreen(),
        '/statistics': (context) => const StatisticsScreen(),
        '/transactions': (context) => const TransactionScreen(),
        '/add': (context) => const AddTransactionScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  Widget? _startScreen;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
      _startScreen = const WelcomeScreen();
    } else {
      _startScreen = const HomeScreen();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_startScreen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _startScreen!;
  }
}
