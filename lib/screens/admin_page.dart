import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

class AdminPage extends StatefulWidget {
  final String token;
  final String deviceId; // Required for DELETE request, even if admin bypasses uploadedBy check

  const AdminPage({super.key, required this.token, required this.deviceId});

  @override
  State<AdminPage> createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  // Controllers for student addition
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Controllers for study material update
  final _subjectNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _materialTypeController = TextEditingController();
  final _semesterController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedDepartment;
  String? _selectedYear;
  String? _selectedFileName;
  Uint8List? _fileBytes;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  List<StudyMaterial> _materials = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> departments = ['CSE', 'ECE', 'Mech', 'Civil', 'EEE'];
  final List<String> years = ['1', '2', '3', '4'];
  final List<String> materialTypes = ['Notes', 'Question Paper', 'Project Guide'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.forward();
    _fetchMaterials();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _subjectNameController.dispose();
    _courseCodeController.dispose();
    _materialTypeController.dispose();
    _semesterController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Fetch all study materials (admin sees all materials)
  Future<void> _fetchMaterials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/study-materials'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      debugPrint('Fetch materials response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _materials = data.map((item) => StudyMaterial.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load materials: ${response.statusCode} - ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching materials: $e';
        _isLoading = false;
      });
    }
  }

  // Fetch reports for a specific material
  Future<List<Report>> _fetchReports(String materialId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/reports/$materialId'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      debugPrint('Fetch reports response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Report.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load reports: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching reports: $e');
    }
  }

  // Add a single student
  Future<void> _addStudent() async {
    if (!_emailController.text.endsWith('@kongu.edu')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only @kongu.edu emails are allowed')),
        );
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/users/add-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token.trim()}',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        }),
      );
      debugPrint('Add student response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student added: ${data['email']}')),
          );
        }
        _nameController.clear();
        _emailController.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${jsonDecode(response.body)['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Bulk add students via CSV
  Future<void> _bulkAddStudents() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No CSV file selected')),
          );
        }
        return;
      }

      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      debugPrint('Selected CSV file: $fileName, Size: ${fileBytes.length} bytes');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/api/users/bulk-add-users'),
      );
      request.headers['Authorization'] = 'Bearer ${widget.token.trim()}';
      request.files.add(http.MultipartFile.fromBytes(
        'csvFile',
        fileBytes,
        filename: fileName,
      ));

      debugPrint('Sending bulk add request to: http://localhost:5000/api/users/bulk-add-users');
      final response = await request.send();
      final responseData = await http.Response.fromStream(response);
      debugPrint('Bulk add response: ${responseData.statusCode} - ${responseData.body}');

      if (responseData.statusCode == 201) {
        final data = jsonDecode(responseData.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bulk add completed: ${data['results'].length} students added')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bulk add failed: ${jsonDecode(responseData.body)['message'] ?? responseData.body}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Bulk add error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during bulk add: $e')),
        );
      }
    }
  }

  // Pick a file for study material update
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'txt'],
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _fileBytes = result.files.single.bytes;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  // Update a study material (Admin can edit any material by ID)
  Future<void> _updateMaterial(StudyMaterial material) async {
    _subjectNameController.text = material.subjectName;
    _courseCodeController.text = material.courseCode;
    _materialTypeController.text = material.materialType;
    _semesterController.text = material.semester;
    _descriptionController.text = material.description;
    _selectedDepartment = material.department;
    _selectedYear = material.year;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Material', style: GoogleFonts.poppins()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subjectNameController,
                decoration: const InputDecoration(labelText: 'Subject Name'),
              ),
              TextField(
                controller: _courseCodeController,
                decoration: const InputDecoration(labelText: 'Course Code'),
              ),
              DropdownButtonFormField<String>(
                value: _materialTypeController.text,
                decoration: const InputDecoration(labelText: 'Material Type'),
                items: materialTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => _materialTypeController.text = value!,
              ),
              TextField(
                controller: _semesterController,
                decoration: const InputDecoration(labelText: 'Semester'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Department'),
                items: departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))).toList(),
                onChanged: (value) => setState(() => _selectedDepartment = value),
              ),
              DropdownButtonFormField<String>(
                value: _selectedYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: years.map((year) => DropdownMenuItem(value: year, child: Text(year))).toList(),
                onChanged: (value) => setState(() => _selectedYear = value),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              ElevatedButton(
                onPressed: _pickFile,
                child: Text(_selectedFileName ?? 'Pick New File'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              var request = http.MultipartRequest(
                'PUT',
                Uri.parse('http://localhost:5000/study-materials/${material.id}'),
              );
              request.headers['Authorization'] = 'Bearer ${widget.token}';
              request.fields['subjectName'] = _subjectNameController.text;
              request.fields['courseCode'] = _courseCodeController.text;
              request.fields['materialType'] = _materialTypeController.text;
              request.fields['semester'] = _semesterController.text;
              request.fields['description'] = _descriptionController.text;
              request.fields['department'] = _selectedDepartment!;
              request.fields['year'] = _selectedYear!;
              request.fields['uploadedBy'] = material.uploadedBy; // Admin keeps original uploader
              if (_fileBytes != null) {
                request.files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: _selectedFileName));
              }

              debugPrint('Admin updating material: ${material.id}');
              final response = await request.send();
              final responseData = await http.Response.fromStream(response);
              debugPrint('Update response: ${responseData.statusCode} - ${responseData.body}');
              if (responseData.statusCode == 200) {
                _fetchMaterials(); // Refresh list after update
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Material updated successfully')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: ${jsonDecode(responseData.body)['message'] ?? responseData.body}')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Delete a study material (Admin can delete any material by ID)
  Future<void> _deleteMaterial(String materialId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:5000/study-materials/$materialId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'deviceId': widget.deviceId}), // Required by backend, even for admins
      );
      debugPrint('Admin deleting material: $materialId');
      debugPrint('Delete response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _materials.removeWhere((material) => material.id == materialId);
        });
        _fetchMaterials(); // Refresh list after deletion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Material deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${jsonDecode(response.body)['message'] ?? response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Show reports dialog
  void _showReportsDialog(String materialId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reports for Material', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: FutureBuilder<List<Report>>(
          future: _fetchReports(materialId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: GoogleFonts.poppins());
            }
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return Text('No reports for this material.', style: GoogleFonts.poppins());
            }
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
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // Logout
  void _logout() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Add Students Section
                Text(
                  'Add Students',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00246B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage student accounts',
                  style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF00246B)),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          style: GoogleFonts.poppins(color: const Color(0xFF00246B)),
                          decoration: const InputDecoration(
                            labelText: 'Student Name',
                            prefixIcon: Icon(Icons.person, color: Color(0xFF00246B)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          style: GoogleFonts.poppins(color: const Color(0xFF00246B)),
                          decoration: const InputDecoration(
                            labelText: 'Student Email',
                            prefixIcon: Icon(Icons.email, color: Color(0xFF00246B)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: ElevatedButton(
                                  onPressed: _addStudent,
                                  child: Text('Add Student', style: GoogleFonts.poppins(fontSize: 16)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: ElevatedButton(
                                  onPressed: _bulkAddStudents,
                                  child: Text('Bulk Add', style: GoogleFonts.poppins(fontSize: 16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Manage Study Materials Section
                const SizedBox(height: 24),
                Text(
                  'Manage Uploaded Materials',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00246B),
                  ),
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _materials.isEmpty
                        ? Text('No materials found', style: GoogleFonts.poppins())
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _materials.length,
                            itemBuilder: (context, index) {
                              final material = _materials[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ExpansionTile(
                                  title: Text(material.subjectName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${material.department} • ${material.year} • Semester ${material.semester} • Reports: ${material.reportCount}',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Uploaded By: ${material.uploadedBy}', style: GoogleFonts.poppins()),
                                          Text(
                                            'Uploaded At: ${DateFormat('dd MMM yyyy HH:mm').format(material.uploadedAt)}',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          Text('File URL: ${material.fileUrl}', style: GoogleFonts.poppins()),
                                          if (material.description.isNotEmpty)
                                            Text('Description: ${material.description}', style: GoogleFonts.poppins()),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                                onPressed: () => _updateMaterial(material),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _deleteMaterial(material.id),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.report, color: Colors.orange),
                                                onPressed: () => _showReportsDialog(material.id),
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// StudyMaterial class
class StudyMaterial {
  final String id;
  final String subjectName;
  final String courseCode;
  final String materialType;
  final String semester;
  final String description;
  final String department;
  final String fileUrl;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int reportCount;
  final String year;

  StudyMaterial({
    required this.id,
    required this.subjectName,
    required this.courseCode,
    required this.materialType,
    required this.semester,
    required this.description,
    required this.department,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.reportCount,
    required this.year,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['_id'],
      subjectName: json['subjectName'],
      courseCode: json['courseCode'] ?? '',
      materialType: json['materialType'],
      semester: json['semester'],
      description: json['description'],
      department: json['department'],
      fileUrl: json['fileUrl'],
      uploadedBy: json['uploadedBy'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
      reportCount: json['reportCount'] ?? 0,
      year: json['year'],
    );
  }
}

// Report class
class Report {
  final String id;
  final String materialId;
  final String reportedBy;
  final String reason;
  final DateTime reportedAt;

  Report({
    required this.id,
    required this.materialId,
    required this.reportedBy,
    required this.reason,
    required this.reportedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['_id'],
      materialId: json['materialId'],
      reportedBy: json['reportedBy'],
      reason: json['reason'],
      reportedAt: DateTime.parse(json['reportedAt']),
    );
  }
}

// Placeholder for LoginPage
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Login Page Placeholder')));
  }
}