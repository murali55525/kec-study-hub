import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show debugPrint;
import 'resource_list_screen.dart';
import '../models/study_material.dart';
import '../widgets/exam_date_dialog.dart';
import '../widgets/study_plan_dialog.dart';
import '../utils/notifications.dart';

class HomeDashboard extends StatefulWidget {
  final String deviceId;
  final String token;
  final String userName;

  const HomeDashboard({super.key, required this.deviceId, required this.token, required this.userName});

  @override
  State<HomeDashboard> createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> {
  List<StudyMaterial> recentlyViewed = [];
  List<StudyMaterial> pinnedResources = [];
  List<Map<String, dynamic>> examDates = [];
  List<Map<String, dynamic>> studyPlans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentlyViewed = (jsonDecode(prefs.getString('recentlyViewed') ?? '[]') as List)
          .map((item) => StudyMaterial.fromJson(item))
          .toList();
      pinnedResources = (jsonDecode(prefs.getString('pinnedResources') ?? '[]') as List)
          .map((item) => StudyMaterial.fromJson(item))
          .toList();
      examDates = (jsonDecode(prefs.getString('examDates') ?? '[]') as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      studyPlans = (jsonDecode(prefs.getString('studyPlans') ?? '[]') as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    });
    await _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    for (var exam in examDates) {
      final date = DateTime.parse(exam['date']);
      if (date.isAfter(DateTime.now())) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          exam.hashCode,
          'Exam Reminder: ${exam['name']}',
          'Prepare for ${exam['name']} on ${DateFormat('dd MMM yyyy').format(date)}',
          tz.TZDateTime.from(date.subtract(const Duration(days: 1)), tz.local),
          const NotificationDetails(
              android: AndroidNotificationDetails('exam_channel', 'Exam Reminders',
                  channelDescription: 'Reminders for upcoming exams')),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    for (var plan in studyPlans) {
      final date = DateTime.parse(plan['date']);
      if (date.isAfter(DateTime.now())) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          plan.hashCode,
          'Study Plan: ${plan['task']}',
          'Reminder: ${plan['task']} today at ${plan['time']}',
          tz.TZDateTime.from(date, tz.local),
          const NotificationDetails(
              android: AndroidNotificationDetails('study_channel', 'Study Plan Reminders',
                  channelDescription: 'Daily study plan reminders')),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  void _showResources(String title, List<StudyMaterial> resources) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResourceListScreen(
          title: title,
          resources: resources,
          token: widget.token,
          deviceId: widget.deviceId, // Added deviceId
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildCard(
                  title: 'Recently Viewed',
                  icon: Icons.history,
                  content: recentlyViewed.isEmpty
                      ? Center(
                          child: Text('No recent views',
                              style: GoogleFonts.poppins(color: const Color(0xFF00246B))))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: recentlyViewed.length > 3 ? 3 : recentlyViewed.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(recentlyViewed[index].subjectName,
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 14)),
                            subtitle: Text(recentlyViewed[index].department,
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 12)),
                          ),
                        ),
                  onTap: () => _showResources('Recently Viewed', recentlyViewed),
                ),
                _buildCard(
                  title: 'Pinned Resources',
                  icon: Icons.push_pin,
                  content: pinnedResources.isEmpty
                      ? Center(
                          child: Text('No pinned resources',
                              style: GoogleFonts.poppins(color: const Color(0xFF00246B))))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: pinnedResources.length > 3 ? 3 : pinnedResources.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(pinnedResources[index].subjectName,
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 14)),
                            subtitle: Text(pinnedResources[index].department,
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 12)),
                          ),
                        ),
                  onTap: () => _showResources('Pinned Resources', pinnedResources),
                ),
                _buildCard(
                  title: 'Exam Dates',
                  icon: Icons.calendar_today,
                  content: examDates.isEmpty
                      ? Center(
                          child: Text('No exams scheduled',
                              style: GoogleFonts.poppins(color: const Color(0xFF00246B))))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: examDates.length > 3 ? 3 : examDates.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(examDates[index]['name'],
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 14)),
                            subtitle: Text(
                                DateFormat('dd MMM yyyy')
                                    .format(DateTime.parse(examDates[index]['date'])),
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 12)),
                          ),
                        ),
                  onTap: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                        context: context, builder: (context) => const ExamDateDialog());
                    if (result != null) {
                      setState(() => examDates.add(result));
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('examDates', jsonEncode(examDates));
                      await _scheduleNotifications();
                    }
                  },
                ),
                _buildCard(
                  title: 'Study Plan',
                  icon: Icons.book,
                  content: studyPlans.isEmpty
                      ? Center(
                          child: Text('No study plans',
                              style: GoogleFonts.poppins(color: const Color(0xFF00246B))))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: studyPlans.length > 3 ? 3 : studyPlans.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(studyPlans[index]['task'],
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 14)),
                            subtitle: Text(
                                '${studyPlans[index]['time']} - ${DateFormat('dd MMM').format(DateTime.parse(studyPlans[index]['date']))}',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF00246B), fontSize: 12)),
                          ),
                        ),
                  onTap: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                        context: context, builder: (context) => const StudyPlanDialog());
                    if (result != null) {
                      setState(() => studyPlans.add(result));
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('studyPlans', jsonEncode(studyPlans));
                      await _scheduleNotifications();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
      {required String title,
      required IconData icon,
      required Widget content,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF00246B), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00246B)),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}