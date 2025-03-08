import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import '../models/study_material.dart';
import '../widgets/animated_scale_button.dart';
import 'dart:io' show File;

class UploadMaterialScreen extends StatefulWidget {
  final String deviceId;
  final String token;

  const UploadMaterialScreen({super.key, required this.deviceId, required this.token});

  @override
  State<UploadMaterialScreen> createState() => UploadMaterialScreenState();
}

class UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final _subjectNameController = TextEditingController();
  final _semesterController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseCodeController = TextEditingController();
  String? _selectedMaterialType;
  String? _selectedDepartment;
  String? _selectedYear;
  String? _selectedFileName;
  Uint8List? _fileBytes; // For web
  String? _filePath;     // For mobile
  bool _isUploading = false;
  String? _errorMessage;
  bool _pinResource = false;

  final List<String> departments = ['CSE', 'ECE', 'Mech', 'Civil', 'EEE'];
  final List<String> years = ['1', '2', '3', '4'];
  final List<String> materialTypes = ['Notes', 'Question Paper', 'Project Guide'];

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
          _errorMessage = null;
        });
        debugPrint('File selected: $_selectedFileName');
        debugPrint('Web bytes: ${_fileBytes?.length ?? "N/A"}, Mobile path: $_filePath');
      } else {
        setState(() => _errorMessage = 'No file selected.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking file: $e');
      debugPrint('File picker error: $e');
    }
  }

  Future<void> _uploadMaterial() async {
    debugPrint('Checking fields:');
    debugPrint('subjectName: ${_subjectNameController.text}');
    debugPrint('materialType: $_selectedMaterialType');
    debugPrint('semester: ${_semesterController.text}');
    debugPrint('courseCode: ${_courseCodeController.text}');
    debugPrint('department: $_selectedDepartment');
    debugPrint('year: $_selectedYear');
    debugPrint('description: ${_descriptionController.text}');
    debugPrint('fileName: $_selectedFileName');
    debugPrint('fileBytes: ${_fileBytes != null ? "Not null (${_fileBytes!.length} bytes)" : "Null"}');
    debugPrint('filePath: $_filePath');

    if (_subjectNameController.text.isEmpty ||
        _selectedMaterialType == null || _selectedMaterialType!.isEmpty ||
        _semesterController.text.isEmpty ||
        _courseCodeController.text.isEmpty ||
        _selectedDepartment == null ||
        _selectedYear == null ||
        _selectedFileName == null ||
        (_fileBytes == null && _filePath == null)) {
      setState(() => _errorMessage = 'All fields and a file are required.');
      debugPrint('Validation failed: One or more fields are empty or null');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://localhost:5000/study-materials'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.headers['Content-Type'] = 'multipart/form-data';
      request.fields['subjectName'] = _subjectNameController.text;
      request.fields['materialType'] = _selectedMaterialType!;
      request.fields['semester'] = _semesterController.text;
      request.fields['courseCode'] = _courseCodeController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['department'] = _selectedDepartment!;
      request.fields['year'] = _selectedYear!;
      request.fields['deviceId'] = widget.deviceId;
      final prefs = await SharedPreferences.getInstance();
      request.fields['uploadedBy'] = prefs.getString('userName') ?? 'Unknown';

      if (kIsWeb && _fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: _selectedFileName));
      } else if (_filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', _filePath!, filename: _selectedFileName));
      } else {
        throw Exception('No file data available for upload');
      }

      debugPrint('Uploading material to: http://localhost:5000/study-materials');
      final response = await request.send();
      final responseData = await http.Response.fromStream(response);
      debugPrint('Upload response: ${response.statusCode} - ${responseData.body}');
      debugPrint('Response headers: ${responseData.headers}');

      if (response.statusCode == 201) {
        if (responseData.headers['content-type']?.contains('application/json') ?? false) {
          final material = StudyMaterial.fromJson(jsonDecode(responseData.body));
          if (_pinResource) {
            final prefs = await SharedPreferences.getInstance();
            var pinned = (jsonDecode(prefs.getString('pinnedResources') ?? '[]') as List)
                .map((item) => StudyMaterial.fromJson(item))
                .toList();
            pinned.add(material);
            await prefs.setString('pinnedResources', jsonEncode(pinned.map((item) => item.toJson()).toList()));
          }
          _subjectNameController.clear();
          _courseCodeController.clear();
          _descriptionController.clear();
          _semesterController.clear();
          setState(() {
            _selectedMaterialType = null;
            _selectedFileName = null;
            _fileBytes = null;
            _filePath = null;
            _selectedDepartment = null;
            _selectedYear = null;
            _pinResource = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material uploaded successfully!')));
          }
        } else {
          throw FormatException('Expected JSON response, got ${responseData.headers['content-type']}');
        }
      } else {
        String errorMsg = responseData.body;
        if (responseData.headers['content-type']?.contains('application/json') ?? false) {
          errorMsg = jsonDecode(responseData.body)['message'] ?? responseData.body;
        }
        setState(() => _errorMessage = 'Upload failed: $errorMsg (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      setState(() => _errorMessage = 'Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
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
            Text('Add Resource', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
            const SizedBox(height: 8),
            Text('Upload study materials', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFF00246B))),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Fixed typo here
                  children: [
                    TextField(
                      controller: _subjectNameController,
                      decoration: const InputDecoration(labelText: 'Subject Name'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedMaterialType,
                      decoration: const InputDecoration(labelText: 'Material Type'),
                      items: materialTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: GoogleFonts.poppins()))).toList(),
                      onChanged: (value) => setState(() => _selectedMaterialType = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _semesterController,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _courseCodeController,
                      decoration: const InputDecoration(labelText: 'Course Code'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: GoogleFonts.poppins()))).toList(),
                      onChanged: (value) => setState(() => _selectedDepartment = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedYear,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: years.map((year) => DropdownMenuItem(value: year, child: Text(year, style: GoogleFonts.poppins()))).toList(),
                      onChanged: (value) => setState(() => _selectedYear = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Text('Attach File', style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF00246B))),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text('Upload File', style: GoogleFonts.poppins()),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCADCFC)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _selectedFileName ?? 'No file selected',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text('Pin this resource', style: GoogleFonts.poppins(color: const Color(0xFF00246B))),
                      value: _pinResource,
                      onChanged: (value) => setState(() => _pinResource = value!),
                      activeColor: const Color(0xFF00246B),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _isUploading
                          ? const CircularProgressIndicator()
                          : AnimatedScaleButton(
                              onPressed: _uploadMaterial,
                              child: Text('Submit', style: GoogleFonts.poppins(fontSize: 18)),
                            ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _semesterController.dispose();
    _descriptionController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }
}