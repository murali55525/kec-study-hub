import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../models/study_material.dart';
import '../widgets/animated_scale_button.dart';
import 'dart:io' show File;
import 'dart:typed_data';

class ProfilePage extends StatefulWidget {
  final String deviceId;
  final String token;
  final String userName;

  const ProfilePage({super.key, required this.deviceId, required this.token, required this.userName});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  List<StudyMaterial> _materials = [];
  bool _isLoadingMaterials = true;
  String? _materialsError;

  @override
  void initState() {
    super.initState();
    debugPrint('ProfilePage init with deviceId: ${widget.deviceId}, token: ${widget.token}');
    _loadProfile();
    _fetchUserMaterials();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('userName') ?? widget.userName;
      _emailController.text = prefs.getString('userEmail') ?? '';
      _bioController.text = prefs.getString('userBio') ?? '';
    });
  }

  Future<void> _fetchUserMaterials() async {
    setState(() {
      _isLoadingMaterials = true;
      _materialsError = null;
    });
    try {
      final url = 'http://localhost:5000/user-materials?deviceId=${widget.deviceId}';
      debugPrint('Fetching user materials from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      debugPrint('Fetch user materials response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('Fetched materials count: ${data.length}');
        if (data.isNotEmpty) {
          debugPrint('First material: ${data[0]}');
        }
        setState(() {
          _materials = data.map((item) => StudyMaterial.fromJson(item)).toList();
          _isLoadingMaterials = false;
        });
      } else {
        setState(() {
          _materialsError = 'Failed to load materials: ${response.statusCode} - ${response.body}';
          _isLoadingMaterials = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user materials: $e');
      setState(() {
        _materialsError = 'Error fetching materials: $e';
        _isLoadingMaterials = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userBio', _bioController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/users/change-password'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: jsonEncode({'currentPassword': _currentPasswordController.text, 'newPassword': _newPasswordController.text}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!')));
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to change password: ${jsonDecode(response.body)['message']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error changing password: $e')));
      }
    }
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:5000/study-materials/$materialId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'deviceId': widget.deviceId}),
      );
      debugPrint('Delete material response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() => _materials.removeWhere((material) => material.id == materialId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material deleted successfully!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete material: ${jsonDecode(response.body)['message'] ?? response.statusCode}')));
        }
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting material: $e')));
      }
    }
  }

  Future<void> _editMaterial(StudyMaterial material) async {
    final _subjectNameController = TextEditingController(text: material.subjectName);
    final _courseCodeController = TextEditingController(text: material.courseCode);
    final _materialTypeController = TextEditingController(text: material.materialType);
    final _semesterController = TextEditingController(text: material.semester);
    final _descriptionController = TextEditingController(text: material.description);
    final _departmentController = TextEditingController(text: material.department);
    final _yearController = TextEditingController(text: material.year);
    String? _selectedFileName;
    Uint8List? _fileBytes;
    String? _filePath;

    Future<void> _pickFile() async {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _selectedFileName = result.files.single.name;
            if (kIsWeb) {
              _fileBytes = result.files.single.bytes;
              _filePath = null;
            } else {
              _filePath = result.files.single.path;
              _fileBytes = null;
            }
          });
          debugPrint('File selected: $_selectedFileName');
        }
      } catch (e) {
        debugPrint('File picker error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
        }
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Material', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _subjectNameController, decoration: const InputDecoration(labelText: 'Subject Name')),
              TextField(controller: _courseCodeController, decoration: const InputDecoration(labelText: 'Course Code')),
              TextField(controller: _materialTypeController, decoration: const InputDecoration(labelText: 'Material Type')),
              TextField(controller: _semesterController, decoration: const InputDecoration(labelText: 'Semester')),
              TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              TextField(controller: _departmentController, decoration: const InputDecoration(labelText: 'Department')),
              TextField(controller: _yearController, decoration: const InputDecoration(labelText: 'Year')),
              const SizedBox(height: 16),
              Text('Current File: ${material.fileUrl.split('/').last}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickFile,
                child: Text(
                  _selectedFileName == null ? 'Replace File' : 'New File: $_selectedFileName',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (_subjectNameController.text.isEmpty ||
                  _courseCodeController.text.isEmpty ||
                  _materialTypeController.text.isEmpty ||
                  _semesterController.text.isEmpty ||
                  _departmentController.text.isEmpty ||
                  _yearController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields are required except description and file.')));
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      var request = http.MultipartRequest('PUT', Uri.parse('http://localhost:5000/study-materials/${material.id}'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';

      request.fields['subjectName'] = _subjectNameController.text;
      request.fields['courseCode'] = _courseCodeController.text;
      request.fields['materialType'] = _materialTypeController.text;
      request.fields['semester'] = _semesterController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['department'] = _departmentController.text;
      request.fields['year'] = _yearController.text;
      request.fields['uploadedBy'] = widget.deviceId;

      if (kIsWeb && _fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: _selectedFileName));
      } else if (_filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', _filePath!, filename: _selectedFileName));
      }

      debugPrint('Sending edit request to: http://localhost:5000/study-materials/${material.id}');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('Edit material response: ${response.statusCode} - $responseBody');

      if (response.statusCode == 200) {
        final updatedMaterial = StudyMaterial.fromJson(jsonDecode(responseBody));
        debugPrint('New fileUrl from server: ${updatedMaterial.fileUrl}');
        setState(() {
          final index = _materials.indexWhere((m) => m.id == material.id);
          if (index != -1) {
            _materials[index] = updatedMaterial;
          } else {
            debugPrint('Material not found in list for update: ${material.id}');
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material updated successfully!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update material: ${jsonDecode(responseBody)['message'] ?? response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Edit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating material: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFCADCFC),
              child: Text(widget.userName[0].toUpperCase(), style: GoogleFonts.poppins(fontSize: 48, color: const Color(0xFF00246B))),
            ),
            const SizedBox(height: 16),
            Text('Profile', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name'), enabled: false),
                    const SizedBox(height: 16),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), enabled: false),
                    const SizedBox(height: 16),
                    TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
                    const SizedBox(height: 24),
                    AnimatedScaleButton(onPressed: _updateProfile, child: Text('Update Bio', style: GoogleFonts.poppins(fontSize: 18))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Change Password', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
                    const SizedBox(height: 16),
                    TextField(controller: _currentPasswordController, decoration: const InputDecoration(labelText: 'Current Password'), obscureText: true),
                    const SizedBox(height: 16),
                    TextField(controller: _newPasswordController, decoration: const InputDecoration(labelText: 'New Password'), obscureText: true),
                    const SizedBox(height: 16),
                    TextField(controller: _confirmPasswordController, decoration: const InputDecoration(labelText: 'Confirm New Password'), obscureText: true),
                    const SizedBox(height: 24),
                    AnimatedScaleButton(onPressed: _changePassword, child: Text('Change Password', style: GoogleFonts.poppins(fontSize: 18))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Uploaded Materials', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF00246B)),
                  onPressed: _fetchUserMaterials,
                  tooltip: 'Refresh Materials',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingMaterials
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00246B)))
                : _materialsError != null
                    ? Text(_materialsError!, style: GoogleFonts.poppins(color: Colors.red))
                    : _materials.isEmpty
                        ? Text('No materials uploaded yet', style: GoogleFonts.poppins(color: const Color(0xFF00246B)))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _materials.length,
                            itemBuilder: (context, index) {
                              final material = _materials[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8), // Should be 'bottom: 8'
                                child: ListTile(
                                  title: Text(material.subjectName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF00246B))),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Likes: ${material.likes} • Views: ${material.views} • Downloads: ${material.downloads}',
                                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF00246B)),
                                      ),
                                      Text(
                                        'File: ${material.fileUrl.split('/').last}',
                                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _editMaterial(material),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteMaterial(material.id),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}