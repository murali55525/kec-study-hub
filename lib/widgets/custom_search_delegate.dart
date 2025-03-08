import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform, Directory, File;
import '../screens/material_preview_screen.dart'; // Corrected path
import '../models/study_material.dart';

class CustomSearchDelegate extends SearchDelegate {
  final String deviceId;
  final String token;
  final String initialQuery;

  CustomSearchDelegate({required this.deviceId, required this.token, required this.initialQuery}) : super(searchFieldLabel: 'Search resources...');

  @override
  List<Widget> buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  Future<List<StudyMaterial>> _searchMaterials() async {
    debugPrint('Searching materials with query: $query');
    final response = await http.get(
      Uri.parse('http://localhost:5000/study-materials/search?query=${query.isEmpty ? initialQuery : query}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    debugPrint('Search response: ${response.statusCode}');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => StudyMaterial.fromJson(item)).toList();
    } else {
      throw Exception('Failed to search materials: ${response.statusCode}');
    }
  }

  Future<void> _downloadFile(String url, String fileName, BuildContext context) async {
    try {
      debugPrint('Downloading file from: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('Download response: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch file: HTTP ${response.statusCode}');
      }

      String extension = url.split('.').last.split('?')[0].toLowerCase();
      final sanitizedFileName = '$fileName.$extension';

      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: blobUrl)
          ..setAttribute('download', sanitizedFileName)
          ..click();
        html.Url.revokeObjectUrl(blobUrl);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading file... Check your browser downloads.')));
      } else {
        PermissionStatus status;
        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          status = androidInfo.version.sdkInt >= 33 ? await Permission.manageExternalStorage.request() : await Permission.storage.request();
          if (!status.isGranted) throw Exception('Storage permission denied.');
        }

        Directory? directory = Platform.isAndroid ? Directory('/storage/emulated/0/Download') : await getApplicationDocumentsDirectory();
        if (Platform.isAndroid && !(await directory.exists())) {
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            directory = Directory('${directory.path}/Downloads');
            if (!(await directory.exists())) await directory.create(recursive: true);
          }
        } else if (Platform.isIOS) {
          directory = Directory('${directory.path}/Downloads');
          if (!(await directory.exists())) await directory.create(recursive: true);
        }

        if (directory == null) throw Exception('Failed to determine download directory');
        final filePath = '${directory.path}/$sanitizedFileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('File downloaded to: $filePath');

        if (Platform.isIOS) {
          await Share.shareXFiles([XFile(filePath)], text: 'Downloaded file: $sanitizedFileName');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File downloaded to $filePath')));
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
    }
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<StudyMaterial>>(
      future: _searchMaterials(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00246B)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.poppins(color: const Color(0xFF00246B))));
        }
        final results = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final material = results[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                title: Text(material.subjectName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF00246B))),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Department: ${material.department}', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                        Text('Year: ${material.year}', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                        Text('Semester: ${material.semester}', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                        Text('Uploaded At: ${DateFormat('dd MMM yyyy').format(material.uploadedAt)}', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                        Text('Uploaded By: ${material.uploadedBy}', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                        if (material.description.isNotEmpty) Text('Description: ${material.description}', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Color(0xFF00246B)),
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                var recent = (jsonDecode(prefs.getString('recentlyViewed') ?? '[]') as List).map((item) => StudyMaterial.fromJson(item)).toList();
                                if (!recent.any((item) => item.id == material.id)) {
                                  recent.insert(0, material);
                                  if (recent.length > 10) recent = recent.sublist(0, 10);
                                  await prefs.setString('recentlyViewed', jsonEncode(recent.map((item) => item.toJson()).toList()));
                                }
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => MaterialPreviewScreen(material: material, onDownload: _downloadFile),
                                ));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.download, color: Color(0xFF00246B)),
                              onPressed: () => _downloadFile(material.fileUrl, material.subjectName, context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}