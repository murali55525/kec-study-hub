class Report {
  final String id;
  final String materialId;
  final String reportedBy;
  final String reason;
  final DateTime reportedAt;

  Report({required this.id, required this.materialId, required this.reportedBy, required this.reason, required this.reportedAt});

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