import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_dashboard.dart';
import 'resources_page.dart';
import 'upload_material_screen.dart';
import 'discussion_forum_page.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  final String deviceId;
  final String token;
  final String userName;

  const HomeScreen({super.key, required this.deviceId, required this.token, required this.userName});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _pages = [
      HomeDashboard(deviceId: widget.deviceId, token: widget.token, userName: widget.userName),
      ResourcesPage(deviceId: widget.deviceId, token: widget.token),
      UploadMaterialScreen(deviceId: widget.deviceId, token: widget.token),
      const DiscussionForumPage(),
      ProfilePage(deviceId: widget.deviceId, token: widget.token, userName: widget.userName),
    ];
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('isDarkMode') ?? false);
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('KEC Study Hub', style: GoogleFonts.poppins(fontSize: 20)),
            Text('Welcome, ${widget.userName}', style: GoogleFonts.poppins(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFFCADCFC),
        unselectedItemColor: const Color(0xFF00246B),
        showUnselectedLabels: true,
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Resources'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Add Resources'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Forum'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}