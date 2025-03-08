import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:universal_html/html.dart' as html;
import 'dart:io' show Platform, Directory, File;
import 'dart:convert';
import 'material_preview_screen.dart';
import '../models/study_material.dart';

class ResourceListScreen extends StatefulWidget {
  final String title;
  final List<StudyMaterial> resources; // Initial resources (e.g., pinned)
  final String token;
  final String deviceId;

  const ResourceListScreen({
    super.key,
    required this.title,
    required this.resources,
    required this.token,
    required this.deviceId,
  });

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  late List<StudyMaterial> _sortedResources;
  String _sortBy = 'likes';
  Set<String> _likedMaterials = {};
  Set<String> _viewedMaterials = {};
  Set<String> _downloadedMaterials = {};

  @override
  void initState() {
    super.initState();
    _sortedResources = List.from(widget.resources);
    _fetchUpdatedMaterials(); // Fetch fresh data from server
  }

  Future<void> _fetchUpdatedMaterials() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/study-materials'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      debugPrint('Fetch materials response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<StudyMaterial> allMaterials = data.map((item) => StudyMaterial.fromJson(item)).toList();
        setState(() {
          // Update only the resources in the initial list
          _sortedResources = allMaterials.where((m) => widget.resources.any((r) => r.id == m.id)).toList();
          _likedMaterials.clear();
          _viewedMaterials.clear();
          _downloadedMaterials.clear();
          for (var material in _sortedResources) {
            debugPrint('Material: ${material.subjectName}, Likes: ${material.likes}, Views: ${material.views}, Downloads: ${material.downloads}');
            if (material.likedBy.contains(widget.deviceId)) _likedMaterials.add(material.id);
            if (material.viewedBy.contains(widget.deviceId)) _viewedMaterials.add(material.id);
            if (material.downloadedBy.contains(widget.deviceId)) _downloadedMaterials.add(material.id);
          }
          _sortResources();
        });
      } else {
        debugPrint('Failed to fetch updated materials: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching updated materials: $e');
    }
  }

  void _sortResources() {
    setState(() {
      _sortedResources.sort((a, b) {
        switch (_sortBy) {
          case 'likes':
            return (b.likes ?? 0).compareTo(a.likes ?? 0);
          case 'views':
            return (b.views ?? 0).compareTo(a.views ?? 0);
          case 'downloads':
            return (b.downloads ?? 0).compareTo(a.downloads ?? 0);
          default:
            final aScore = (a.likes ?? 0) + (a.views ?? 0) + (a.downloads ?? 0);
            final bScore = (b.likes ?? 0) + (b.views ?? 0) + (b.downloads ?? 0);
            return bScore.compareTo(aScore);
        }
      });
    });
  }

  Future<void> _downloadFile(String url, String fileName, BuildContext context) async {
    final material = _sortedResources.firstWhere((m) => m.fileUrl == url);

    try {
      debugPrint('Downloading file from: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('Download response: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch file: HTTP ${response.statusCode}');
      }

      String extension = url.split('.').last.split('?')[0].toLowerCase();
      final sanitizedFileName = '$fileName-${DateTime.now().millisecondsSinceEpoch}.$extension'; // Unique filename

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

      // Increment download count only if not already counted
      if (!_downloadedMaterials.contains(material.id)) {
        await _incrementDownload(material.id);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
    }
  }

  Future<void> _incrementDownload(String materialId) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/study-materials/$materialId/download'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'deviceId': widget.deviceId}),
      );
      debugPrint('Increment download response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          final material = _sortedResources.firstWhere((m) => m.id == materialId);
          material.downloadedBy.add(widget.deviceId);
          material.downloads = (material.downloads ?? 0) + 1;
          _downloadedMaterials.add(material.id);
          _sortResources();
        });
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to increment download: ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      debugPrint('Error incrementing download: $e');
    }
  }

  Future<void> _likeMaterial(String materialId) async {
    if (_likedMaterials.contains(materialId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already liked this resource')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/study-materials/$materialId/like'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'deviceId': widget.deviceId}),
      );
      debugPrint('Like response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          final material = _sortedResources.firstWhere((m) => m.id == materialId);
          material.likedBy.add(widget.deviceId);
          material.likes = (material.likes ?? 0) + 1;
          _likedMaterials.add(material.id);
          _sortResources();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resource liked successfully')),
        );
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to like resource: ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      debugPrint('Error liking material: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error liking resource: $e')),
      );
    }
  }

  Future<void> _incrementView(String materialId) async {
    if (_viewedMaterials.contains(materialId)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MaterialPreviewScreen(
            material: _sortedResources.firstWhere((m) => m.id == materialId),
            onDownload: _downloadFile,
          ),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/study-materials/$materialId/view'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'deviceId': widget.deviceId}),
      );
      debugPrint('Increment view response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          final material = _sortedResources.firstWhere((m) => m.id == materialId);
          material.viewedBy.add(widget.deviceId);
          material.views = (material.views ?? 0) + 1;
          _viewedMaterials.add(material.id);
          _sortResources();
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaterialPreviewScreen(
              material: _sortedResources.firstWhere((m) => m.id == materialId),
              onDownload: _downloadFile,
            ),
          ),
        );
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to view resource: ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      debugPrint('Error incrementing view: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error viewing resource: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building ResourceListScreen with ${_sortedResources.length} items');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.poppins()),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortResources();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'likes', child: Text('Sort by Likes')),
              const PopupMenuItem(value: 'views', child: Text('Sort by Views')),
              const PopupMenuItem(value: 'downloads', child: Text('Sort by Downloads')),
              const PopupMenuItem(value: 'combined', child: Text('Sort by Combined')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: _sortedResources.isEmpty
          ? Center(
              child: Text(
                'No ${widget.title} available',
                style: GoogleFonts.poppins(color: const Color(0xFF00246B), fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _sortedResources.length,
              itemBuilder: (context, index) {
                final material = _sortedResources[index];
                final hasLiked = _likedMaterials.contains(material.id);
                final hasViewed = _viewedMaterials.contains(material.id);
                final hasDownloaded = _downloadedMaterials.contains(material.id);
                debugPrint('Rendering item $index: ${material.subjectName}');
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material.subjectName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF00246B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${material.department} • Uploaded by: ${material.uploadedBy}',
                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF00246B)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.thumb_up, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text('${material.likes ?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.visibility, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('${material.views ?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.download, size: 16, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text('${material.downloads ?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: hasLiked ? null : () => _likeMaterial(material.id),
                              icon: Icon(Icons.thumb_up, size: 18, color: hasLiked ? Colors.grey : Colors.blue),
                              label: Text(hasLiked ? 'Liked' : 'Like'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: hasLiked ? Colors.grey : Colors.blue,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.visibility, color: hasViewed ? Colors.grey : const Color(0xFF00246B)),
                              onPressed: () => _incrementView(material.id),
                              tooltip: 'View',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.download, color: Color(0xFF00246B)), // Always enabled
                              onPressed: () => _downloadFile(material.fileUrl, material.subjectName, context),
                              tooltip: 'Download',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}