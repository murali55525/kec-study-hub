import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' show Platform, Directory, File;
import 'package:intl/intl.dart';
import 'resource_list_screen.dart';
import 'material_preview_screen.dart';
import '../models/study_material.dart';
import '../models/report.dart';
import '../widgets/custom_search_bar.dart';

class ResourcesPage extends StatefulWidget {
  final String deviceId;
  final String token;

  const ResourcesPage({super.key, required this.deviceId, required this.token});

  @override
  State<ResourcesPage> createState() => ResourcesPageState();
}

class ResourcesPageState extends State<ResourcesPage> {
  String selectedFilterDepartment = 'All';
  String? selectedYear;
  final List<String> departments = ['All', 'CSE', 'ECE', 'Mech', 'Civil', 'EEE'];
  final List<String> years = ['1', '2', '3', '4'];
  bool _isLoading = true;
  String? _errorMessage;
  List<StudyMaterial> _materials = [];
  List<StudyMaterial> pinnedResources = [];
  Map<String, List<String>> comments = {};
  Set<String> _likedMaterials = {};
  Set<String> _viewedMaterials = {};
  Set<String> _downloadedMaterials = {};

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
    _loadPinnedResources();
    _loadComments();
  }

  Future<void> _fetchMaterials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      String url = 'http://localhost:5000/study-materials';
      List<String> queryParams = [];
      if (selectedFilterDepartment != 'All') queryParams.add('department=$selectedFilterDepartment');
      if (selectedYear != null) queryParams.add('year=$selectedYear');
      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';
      debugPrint('Fetching materials from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      debugPrint('Fetch materials response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<StudyMaterial> materials = data.map((item) => StudyMaterial.fromJson(item)).toList();
        materials.sort((a, b) {
          int likesCompare = (b.likes ?? 0).compareTo(a.likes ?? 0);
          if (likesCompare != 0) return likesCompare;
          if (a.subjectName == b.subjectName) {
            return (b.views ?? 0).compareTo(a.views ?? 0);
          }
          return a.subjectName.compareTo(b.subjectName);
        });
        setState(() {
          _materials = materials;
          _likedMaterials.clear();
          _viewedMaterials.clear();
          _downloadedMaterials.clear();
          for (var material in _materials) {
            if (material.likedBy.contains(widget.deviceId)) _likedMaterials.add(material.id);
            if (material.viewedBy.contains(widget.deviceId)) _viewedMaterials.add(material.id);
            if (material.downloadedBy.contains(widget.deviceId)) {
              _downloadedMaterials.add(material.id);
              debugPrint('Material ${material.id} already downloaded by ${widget.deviceId}');
            }
          }
        });
      } else {
        setState(() => _errorMessage = 'Failed to load materials: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching materials: $e');
      setState(() => _errorMessage = 'Error fetching materials: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadPinnedResources() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => pinnedResources = (jsonDecode(prefs.getString('pinnedResources') ?? '[]') as List)
        .map((item) => StudyMaterial.fromJson(item))
        .toList());
  }

  Future<void> _loadComments() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => comments = (jsonDecode(prefs.getString('comments') ?? '{}') as Map)
        .map((key, value) => MapEntry(key, List<String>.from(value))));
  }

  Future<void> _saveComments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('comments', jsonEncode(comments));
  }

  Future<void> _togglePin(StudyMaterial material) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pinnedResources.any((item) => item.id == material.id)) {
        pinnedResources.removeWhere((item) => item.id == material.id);
      } else {
        pinnedResources.add(material);
      }
    });
    await prefs.setString('pinnedResources', jsonEncode(pinnedResources.map((item) => item.toJson()).toList()));
    _fetchMaterials();
  }

  Future<void> _reportMaterial(String materialId) async {
    final reportReasonController = TextEditingController();
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report Material', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
        content: TextField(
            controller: reportReasonController, decoration: const InputDecoration(labelText: 'Reason for Reporting'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (reportReasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason for reporting.')));
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('Submit Report', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      debugPrint('Reporting material: $materialId');
      final response = await http.post(
        Uri.parse('http://localhost:5000/report-material'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: jsonEncode({'materialId': materialId, 'deviceId': widget.deviceId, 'reason': reportReasonController.text}),
      );
      debugPrint('Report response: ${response.statusCode}');
      if (response.statusCode == 201) {
        await _fetchMaterials();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material reported successfully!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to report material: ${jsonDecode(response.body)['message']}')));
        }
      }
    } catch (e) {
      debugPrint('Report error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reporting material: $e')));
      }
    }
  }

  Future<List<Report>> _fetchReports(String materialId) async {
    debugPrint('Fetching reports for material: $materialId');
    final response = await http.get(
      Uri.parse('http://localhost:5000/reports/$materialId'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    debugPrint('Fetch reports response: ${response.statusCode}');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Report.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load reports: ${response.statusCode}');
    }
  }

  Future<void> _downloadFile(String url, String fileName, BuildContext context) async {
    final material = _materials.firstWhere((m) => m.fileUrl == url);

    try {
      debugPrint('Downloading file from: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('Download response: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch file: HTTP ${response.statusCode}');
      }

      String extension = url.split('.').last.split('?')[0].toLowerCase();
      final sanitizedFileName = '$fileName-${DateTime.now().millisecondsSinceEpoch}.$extension';

      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: blobUrl)
          ..setAttribute('download', sanitizedFileName)
          ..click();
        html.Url.revokeObjectUrl(blobUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading file... Check your browser downloads.')));
        }
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

        if (Platform.isIOS && mounted) {
          await Share.shareXFiles([XFile(filePath)], text: 'Downloaded file: $sanitizedFileName');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File downloaded to $filePath')));
        }
      }

      if (!_downloadedMaterials.contains(material.id)) {
        await _incrementDownload(material.id);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
      }
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
          final material = _materials.firstWhere((m) => m.id == materialId);
          material.downloadedBy.add(widget.deviceId);
          material.downloads = (material.downloads ?? 0) + 1;
          _downloadedMaterials.add(material.id);
          _materials.sort((a, b) {
            int likesCompare = (b.likes ?? 0).compareTo(a.likes ?? 0);
            if (likesCompare != 0) return likesCompare;
            if (a.subjectName == b.subjectName) {
              return (b.views ?? 0).compareTo(a.views ?? 0);
            }
            return a.subjectName.compareTo(b.subjectName);
          });
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
          final material = _materials.firstWhere((m) => m.id == materialId);
          material.likedBy.add(widget.deviceId);
          material.likes = (material.likes ?? 0) + 1;
          _likedMaterials.add(material.id);
          _materials.sort((a, b) {
            int likesCompare = (b.likes ?? 0).compareTo(a.likes ?? 0);
            if (likesCompare != 0) return likesCompare;
            if (a.subjectName == b.subjectName) {
              return (b.views ?? 0).compareTo(a.views ?? 0);
            }
            return a.subjectName.compareTo(b.subjectName);
          });
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
      final prefs = await SharedPreferences.getInstance();
      var recent = (jsonDecode(prefs.getString('recentlyViewed') ?? '[]') as List)
          .map((item) => StudyMaterial.fromJson(item))
          .toList();
      if (!recent.any((item) => item.id == materialId)) {
        recent.insert(0, _materials.firstWhere((m) => m.id == materialId));
        if (recent.length > 10) recent = recent.sublist(0, 10);
        await prefs.setString('recentlyViewed', jsonEncode(recent.map((item) => item.toJson()).toList()));
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MaterialPreviewScreen(
            material: _materials.firstWhere((m) => m.id == materialId),
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
          final material = _materials.firstWhere((m) => m.id == materialId);
          material.viewedBy.add(widget.deviceId);
          material.views = (material.views ?? 0) + 1;
          _viewedMaterials.add(material.id);
          _materials.sort((a, b) {
            int likesCompare = (b.likes ?? 0).compareTo(a.likes ?? 0);
            if (likesCompare != 0) return likesCompare;
            if (a.subjectName == b.subjectName) {
              return (b.views ?? 0).compareTo(a.views ?? 0);
            }
            return a.subjectName.compareTo(b.subjectName);
          });
          final prefs = SharedPreferences.getInstance();
          prefs.then((prefs) {
            var recent = (jsonDecode(prefs.getString('recentlyViewed') ?? '[]') as List)
                .map((item) => StudyMaterial.fromJson(item))
                .toList();
            if (!recent.any((item) => item.id == materialId)) {
              recent.insert(0, material);
              if (recent.length > 10) recent = recent.sublist(0, 10);
              prefs.setString('recentlyViewed', jsonEncode(recent.map((item) => item.toJson()).toList()));
            }
          });
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaterialPreviewScreen(
              material: _materials.firstWhere((m) => m.id == materialId),
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

  Future<void> _showReportsDialog(String materialId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reports for Material', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
        content: FutureBuilder<List<Report>>(
          future: _fetchReports(materialId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Text('Error: ${snapshot.error}', style: GoogleFonts.poppins());
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) return Text('No reports for this material.', style: GoogleFonts.poppins());
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return ListTile(
                    title: Text('Reported by: ${report.reportedBy.substring(0, 8)}...', style: GoogleFonts.poppins()),
                    subtitle: Text(
                        'Reason: ${report.reason}\nReported At: ${DateFormat('dd MMM yyyy HH:mm').format(report.reportedAt)}',
                        style: GoogleFonts.poppins(fontSize: 12)),
                  );
                },
              ),
            );
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.poppins()))],
      ),
    );
  }

  Future<void> _showCommentsDialog(String materialId) async {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Comments', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (comments[materialId]?.isNotEmpty ?? false)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: comments[materialId]!.length,
                    itemBuilder: (context, index) => ListTile(
                        title: Text(comments[materialId]![index], style: GoogleFonts.poppins(fontSize: 14))),
                  ),
                )
              else
                Text('No comments yet.', style: GoogleFonts.poppins()),
              const SizedBox(height: 16),
              TextField(controller: commentController, decoration: const InputDecoration(labelText: 'Add a comment'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.isNotEmpty) {
                setState(() {
                  comments[materialId] = comments[materialId] ?? [];
                  comments[materialId]!.add(commentController.text);
                });
                _saveComments();
                Navigator.pop(context);
              }
            },
            child: Text('Submit', style: GoogleFonts.poppins()),
          ),
        ],
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
            CustomSearchBar(token: widget.token, deviceId: widget.deviceId),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedFilterDepartment,
                    decoration: const InputDecoration(labelText: 'Filter by Department'),
                    items: departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: GoogleFonts.poppins()))).toList(),
                    onChanged: (value) => setState(() {
                      selectedFilterDepartment = value!;
                      _fetchMaterials();
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: 'Filter by Year'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years', style: TextStyle(fontFamily: 'Poppins'))),
                      ...years.map((year) => DropdownMenuItem(value: year, child: Text(year, style: GoogleFonts.poppins()))),
                    ],
                    onChanged: (value) => setState(() {
                      selectedYear = value;
                      _fetchMaterials();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00246B)))
                : _materials.isEmpty
                    ? Center(child: Text('No materials found.', style: GoogleFonts.poppins(color: const Color(0xFF00246B))))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _materials.length,
                        itemBuilder: (context, index) {
                          final material = _materials[index];
                          final isPinned = pinnedResources.any((item) => item.id == material.id);
                          final hasLiked = _likedMaterials.contains(material.id);
                          final hasViewed = _viewedMaterials.contains(material.id);
                          final hasDownloaded = _downloadedMaterials.contains(material.id);
                          debugPrint('Rendering material: ${material.subjectName}, Likes: ${material.likes}, Views: ${material.views}, Downloads: ${material.downloads}, DownloadedBy: ${material.downloadedBy}');
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ExpansionTile(
                              title: Text(material.subjectName,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF00246B))),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Department: ${material.department}',
                                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                                      Text('Year: ${material.year}',
                                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                                      Text('Semester: ${material.semester}',
                                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                                      Text('Uploaded At: ${DateFormat('dd MMM yyyy').format(material.uploadedAt)}',
                                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                                      Text('Uploaded By: ${material.uploadedBy}',
                                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
                                      if (material.description.isNotEmpty)
                                        Text('Description: ${material.description}',
                                            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF00246B))),
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
                                      if (material.reportCount > 0)
                                        GestureDetector(
                                          onTap: () => _showReportsDialog(material.id),
                                          child: Text('Reports: ${material.reportCount}',
                                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: hasLiked ? null : () => _likeMaterial(material.id),
                                            icon: Icon(Icons.thumb_up,
                                                size: 18, color: hasLiked ? Colors.grey : Colors.blue),
                                            label: Text(hasLiked ? 'Liked' : 'Like'),
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: hasLiked ? Colors.grey : Colors.blue,
                                              backgroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              textStyle: GoogleFonts.poppins(fontSize: 14),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.visibility,
                                                color: hasViewed ? Colors.grey : const Color(0xFF00246B)),
                                            onPressed: () => _incrementView(material.id),
                                            tooltip: 'View',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.download, color: Color(0xFF00246B)),
                                            onPressed: () => _downloadFile(material.fileUrl, material.subjectName, context),
                                            tooltip: 'Download',
                                          ),
                                          IconButton(
                                            icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                                color: isPinned ? Colors.red : const Color(0xFF00246B)),
                                            onPressed: () => _togglePin(material),
                                            tooltip: 'Pin',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.report, color: Colors.red),
                                            onPressed: () => _reportMaterial(material.id),
                                            tooltip: 'Report',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.comment, color: Color(0xFF00246B)),
                                            onPressed: () => _showCommentsDialog(material.id),
                                            tooltip: 'Comment',
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
                      ),
            if (_errorMessage != null)
              Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}