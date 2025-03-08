import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StudyPlanDialog extends StatefulWidget {
  const StudyPlanDialog({super.key});

  @override
  State<StudyPlanDialog> createState() => _StudyPlanDialogState();
}

class _StudyPlanDialogState extends State<StudyPlanDialog> {
  final _taskController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add Study Plan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF00246B))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _taskController, decoration: const InputDecoration(labelText: 'Task')),
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              _selectedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              setState(() {});
            },
            child: Text(_selectedTime == null ? 'Select Time' : _selectedTime!.format(context), style: GoogleFonts.poppins()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins())),
        ElevatedButton(
          onPressed: () {
            if (_taskController.text.isNotEmpty && _selectedDate != null && _selectedTime != null) {
              final dateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
              Navigator.pop(context, {'task': _taskController.text, 'date': dateTime.toIso8601String(), 'time': _selectedTime!.format(context)});
            }
          },
          child: Text('Add', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}