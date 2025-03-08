import 'package:flutter/foundation.dart' show debugPrint;

class StudyMaterial {
  String id;
  String subjectName;
  String courseCode;
  String materialType;
  String semester;
  String description;
  String department;
  String year;
  String fileUrl;
  String uploadedBy;
  DateTime uploadedAt;
  int reportCount;
  int likes;        // Removed 'final'
  int views;        // Removed 'final'
  int downloads;    // Removed 'final'
  List<String> likedBy;     // Removed 'final'
  List<String> viewedBy;    // Removed 'final'
  List<String> downloadedBy;// Removed 'final'

  StudyMaterial({
    required this.id,
    required this.subjectName,
    required this.courseCode,
    required this.materialType,
    required this.semester,
    required this.description,
    required this.department,
    required this.year,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.reportCount,
    required this.likes,
    required this.views,
    required this.downloads,
    required this.likedBy,
    required this.viewedBy,
    required this.downloadedBy,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['_id'] ?? '',
      subjectName: json['subjectName'] ?? '',
      courseCode: json['courseCode'] ?? '',
      materialType: json['materialType'] ?? '',
      semester: json['semester'] ?? '',
      description: json['description'] ?? '',
      department: json['department'] ?? '',
      year: json['year'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      uploadedBy: json['uploadedBy'] ?? '',
      uploadedAt: DateTime.parse(json['uploadedAt'] ?? DateTime.now().toIso8601String()),
      reportCount: json['reportCount'] ?? 0,
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      downloads: json['downloads'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      viewedBy: List<String>.from(json['viewedBy'] ?? []),
      downloadedBy: List<String>.from(json['downloadedBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'subjectName': subjectName,
      'courseCode': courseCode,
      'materialType': materialType,
      'semester': semester,
      'description': description,
      'department': department,
      'year': year,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'reportCount': reportCount,
      'likes': likes,
      'views': views,
      'downloads': downloads,
      'likedBy': likedBy,
      'viewedBy': viewedBy,
      'downloadedBy': downloadedBy,
    };
  }
}