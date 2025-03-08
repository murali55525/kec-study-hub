import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'admin_page.dart';
import 'home_screen.dart';
import '../widgets/animated_scale_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.userAgent ?? 'web-device-id';
      } else if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown-ios-id';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return 'placeholder-device-id-${DateTime.now().millisecondsSinceEpoch}'; // Fallback with timestamp
  }

  Future<void> _login() async {
    if (!_emailController.text.endsWith('@kongu.edu')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only @kongu.edu emails are allowed')));
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim(), 'password': _passwordController.text.trim()}),
      );

      debugPrint('Login response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Login successful, token: ${data['token']}');
        final prefs = await SharedPreferences.getInstance();
        String deviceId = await _getDeviceId(); // Define deviceId here

        // Store user data in SharedPreferences
        await prefs.setString('userName', data['name']);
        await prefs.setString('userEmail', data['email']);
        await prefs.setString('token', data['token']);
        await prefs.setString('deviceId', deviceId);

        if (!mounted) return;

        if (_emailController.text == 'admin@kongu.edu') {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => AdminPage(
                token: data['token'],
                deviceId: deviceId, // Pass the defined deviceId
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(
                deviceId: deviceId, // Pass the defined deviceId
                token: data['token'],
                userName: data['name'],
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: ${jsonDecode(response.body)['message'] ?? 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error occurred')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCADCFC),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.school, size: 50, color: Color(0xFF00246B)),
                  ),
                  const SizedBox(height: 40),
                  Text('KEC Study Hub', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
                  const SizedBox(height: 8),
                  Text('Sign in to your account', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFF00246B))),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _emailController,
                    style: GoogleFonts.poppins(color: const Color(0xFF00246B)),
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email, color: Color(0xFF00246B))),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    style: GoogleFonts.poppins(color: const Color(0xFF00246B)),
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock, color: Color(0xFF00246B))),
                    obscureText: true,
                  ),
                  const SizedBox(height: 40),
                  AnimatedScaleButton(onPressed: _login, child: Text('Login', style: GoogleFonts.poppins(fontSize: 18))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}