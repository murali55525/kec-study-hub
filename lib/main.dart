import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart'; // Added
import 'screens/login_page.dart';
import 'utils/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  String? deviceId = prefs.getString('deviceId');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('deviceId', deviceId);
  }

  runApp(KECStudyHubApp(isDarkMode: isDarkMode, deviceId: deviceId));
}

class KECStudyHubApp extends StatelessWidget {
  final bool isDarkMode;
  final String deviceId;

  const KECStudyHubApp({super.key, required this.isDarkMode, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KEC Study Hub',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        fontFamily: GoogleFonts.poppins().fontFamily,
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: const Color(0xFF00246B),
          displayColor: const Color(0xFF00246B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00246B),
          elevation: 0,
          foregroundColor: Color(0xFFFFFFFF),
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCADCFC),
            foregroundColor: const Color(0xFF00246B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 6,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shadowColor: Colors.black26,
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00246B))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCADCFC), width: 2)),
          filled: true,
          fillColor: Colors.white,
          labelStyle: GoogleFonts.poppins(color: const Color(0xFF00246B)),
        ),
        cardTheme: CardTheme(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black26,
          color: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        fontFamily: GoogleFonts.poppins().fontFamily,
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: const Color(0xFF00246B),
          displayColor: const Color(0xFF00246B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00246B),
          elevation: 0,
          foregroundColor: Color(0xFFFFFFFF),
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCADCFC),
            foregroundColor: const Color(0xFF00246B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 6,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shadowColor: Colors.black26,
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00246B))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCADCFC), width: 2)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          labelStyle: GoogleFonts.poppins(color: const Color(0xFF00246B)),
        ),
        cardTheme: CardTheme(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black26,
          color: Colors.grey[850],
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}