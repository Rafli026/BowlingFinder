import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BowlingFinderApp());
}

class BowlingFinderApp extends StatefulWidget {
  const BowlingFinderApp({super.key});

  @override
  State<BowlingFinderApp> createState() => _BowlingFinderAppState();
}

class _BowlingFinderAppState extends State<BowlingFinderApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bowling Finder Palembang',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return HomeScreen(
              onThemeChanged: (isDark) {
                setState(() {
                  _isDarkMode = isDark;
                });
              },
              isDarkMode: _isDarkMode,
            );
          }
          return const SignInScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
