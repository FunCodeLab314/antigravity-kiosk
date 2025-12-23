
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/service_providers.dart';
import '../models/history_record.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<HistoryRecord> _records = [];
  bool _loading = true;
  
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'actionTime';
  
  final Map<String, String> _sortOptions = {
    'actionTime': 'Date & Time',
    'patientName': 'Patient Name',
    'patientNumber': 'Patient Number',
    'adminName': 'Admin/Nurse',
  };

  @override
  void initState() {
    super.initState();
    // Load history after build
    Future.microtask(_loadHistory);
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final records = await ref.read(firestoreServiceProvider).getHistory(
        startDate: _startDate,
        endDate: _endDate,
        sortBy: _sortBy,
      );
      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading history: $e"))
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadHistory();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadHistory();
  }

  void _changeSortOrder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sort By"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _sortOptions.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: _sortBy,
              onChanged: (value) {
                Navigator.pop(ctx);
                setState(() => _sortBy = value!);
                _loadHistory();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _generatePDF() {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No records to export"))
      );
      return;
    }

    ref.read(reportServiceProvider).generateHistoryReport(context, _records, _sortOptions[_sortBy]!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("Medication History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            tooltip: "Export PDF",
            onPressed: _generatePDF,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? "${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}"
                          : "Select Date Range",
                    ),
                  ),
                ),
                if (_startDate != null)
                   IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: _clearDateFilter),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _changeSortOrder,
                  icon: const Icon(Icons.sort),
                  label: const Text("Sort"),
                ),
              ],
            ),
          ),
          if (!_loading)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Text("${_records.length} record(s) found"),
                ],
              ),
            ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                ? const Center(child: Text("No records found"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryCard(_records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HistoryRecord record) {
    Color statusColor = record.status == 'taken' ? Colors.green : Colors.orange;
    IconData statusIcon = record.status == 'taken' ? Icons.check_circle : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             Row(
               children: [
                 CircleAvatar(child: Text("P${record.patientNumber}")),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(record.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                       Text("${record.medicationName} (${record.mealType.toUpperCase()})"),
                     ],
                   ),
                 ),
                 Chip(
                   label: Text(record.status.toUpperCase()),
                   backgroundColor: statusColor.withOpacity(0.2),
                   avatar: Icon(statusIcon, size: 16, color: statusColor),
                 ),
               ],
             ),
             const Divider(),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Slot ${record.slotNumber}"),
                 Text(DateFormat('yyyy-MM-dd HH:mm').format(record.actionTime)),
               ],
             )
          ],
        ),
      ),
    );
  }
}
