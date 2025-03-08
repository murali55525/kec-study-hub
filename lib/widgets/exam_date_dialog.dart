import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ExamDateDialog extends StatefulWidget {
  const ExamDateDialog({super.key});

  @override
  State<ExamDateDialog> createState() => _ExamDateDialogState();
}

class _ExamDateDialogState extends State<ExamDateDialog> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add Exam Date', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Exam Name')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              _selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2026),
              );
              setState(() {});
            },
            child: Text(
              _selectedDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_selectedDate!),
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins())),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty && _selectedDate != null) {
              Navigator.pop(context, {'name': _nameController.text, 'date': _selectedDate!.toIso8601String()});
            }
          },
          child: Text('Add', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}