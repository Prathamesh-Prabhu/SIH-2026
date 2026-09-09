import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../services/db_service.dart';
import '../services/hr_analytics_controller.dart';

/// Tier 2 bulk-ingestion portal.
///
/// HR selects a real `.csv` or `.xlsx` duty roster from the device; the file is
/// parsed on-device, schema-validated, pseudonymized (SHA-256, PRD §2), and the
/// accepted rows replace the cohort the analytics/ML layer scores. Only the
/// pseudonym token and derived operational signals ever leave this screen — the
/// raw Service ID is hashed and discarded.
class HrDataIngestionScreen extends StatefulWidget {
  const HrDataIngestionScreen({super.key});

  @override
  State<HrDataIngestionScreen> createState() => _HrDataIngestionScreenState();
}

class _HrDataIngestionScreenState extends State<HrDataIngestionScreen> {
  static const _ink = Color(0xFF012D1D);
  static const _green = Color(0xFF24704F);
  static const _muted = Color(0xFF6B746E);

  final _db = DbService();

  bool _isProcessing = false;
  String? _pickedName;
  int _pickedBytes = 0;
  List<String>? _rows; // normalised CSV lines (header + data), ready to ingest
  String? _parseError;
  Map<String, dynamic>? _result;

  static const String _sampleCsv =
      '''service_id,unit_code,deployment_zone,duty_hours,leave_balance,consecutive_days,workload_perception,sleep_quality,exhaustion,mood_rating,peer_support
CAPF-90112,UNIT-104,High Altitude Outpost,86,52,27,5,2,5,2,3
CAPF-90113,UNIT-104,High Altitude Outpost,78,47,24,5,2,4,2,2
CAPF-90114,UNIT-104,CI Ops Corridor,74,44,21,4,3,4,3,3
CAPF-90115,UNIT-101,Border Outpost,71,41,20,4,2,4,3,2
CAPF-90116,UNIT-101,Border Outpost,63,38,16,4,3,3,3,4
CAPF-90117,UNIT-101,Border Outpost,58,34,14,3,4,3,4,4
CAPF-90118,UNIT-106,CI Ops Corridor,61,40,17,4,3,4,3,3
CAPF-90120,UNIT-106,Peace Station,49,22,7,2,4,2,4,4
CAPF-90121,UNIT-102,Peace Station,46,18,5,4,4,2,3,3
CAPF-90122,UNIT-102,Peace Station,44,16,4,2,5,1,5,5
CAPF-90124,UNIT-103,Peace Station,42,14,3,4,3,3,2,2
CAPF-90127,UNIT-105,Desert Forward Post,66,43,18,5,3,4,2,3
CAPF-90128,UNIT-105,Desert Forward Post,72,49,22,5,2,4,3,3
,UNIT-102,Peace Station,45,20,5,3,4,2,4,4
CAPF-90131,UNIT-103,Peace Station,not-logged,21,7,4,4,2,3,3
CAPF-90112,UNIT-104,High Altitude Outpost,86,52,27,5,2,5,2,3''';

  bool get _isExcel {
    final n = (_pickedName ?? '').toLowerCase();
    return n.endsWith('.xlsx') || n.endsWith('.xls');
  }

  Future<void> _pickFile() async {
    setState(() => _parseError = null);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls', 'txt'],
        withData: true,
      );
    } catch (e) {
      setState(() => _parseError = 'File picker unavailable: $e');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      setState(() => _parseError = 'Could not read the file contents. Try another file.');
      return;
    }

    try {
      final rows = _extractRows(f.name, bytes);
      if (rows.length < 2) {
        setState(() {
          _rows = null;
          _pickedName = f.name;
          _pickedBytes = f.size;
          _result = null;
          _parseError = 'No data rows found beneath the header.';
        });
        return;
      }
      setState(() {
        _pickedName = f.name;
        _pickedBytes = f.size;
        _rows = rows;
        _result = null;
        _parseError = null;
      });
    } catch (e) {
      setState(() {
        _rows = null;
        _pickedName = f.name;
        _result = null;
        _parseError = 'Could not parse "${f.name}": $e';
      });
    }
  }

  void _useSample() {
    setState(() {
      _pickedName = 'CAPF_Sector4_Roster_Sample.csv';
      _pickedBytes = utf8.encode(_sampleCsv).length;
      _rows = const LineSplitter().convert(_sampleCsv);
      _result = null;
      _parseError = null;
    });
  }

  /// Turns any supported file into a list of comma-joined rows so a single
  /// ingestion path handles both formats.
  List<String> _extractRows(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      final book = xlsx.Excel.decodeBytes(bytes);
      if (book.tables.isEmpty) throw 'the workbook has no sheets';
      final sheet = book.tables.values.first;
      final out = <String>[];
      for (final row in sheet.rows) {
        final cells = row.map(_cellText).toList();
        if (cells.every((c) => c.isEmpty)) continue; // skip blank rows
        out.add(cells.join(','));
      }
      return out;
    }
    // CSV / TXT
    return const LineSplitter()
        .convert(utf8.decode(bytes, allowMalformed: true))
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  String _cellText(xlsx.Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is xlsx.TextCellValue) {
      return (v.value.text ?? '').replaceAll(',', ' ').trim();
    }
    if (v is xlsx.IntCellValue) return v.value.toString();
    if (v is xlsx.DoubleCellValue) {
      final d = v.value;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    if (v is xlsx.BoolCellValue) return v.value.toString();
    if (v is xlsx.DateCellValue) {
      return '${v.year.toString().padLeft(4, '0')}-'
          '${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
    }
    return v.toString().replaceAll(',', ' ').trim();
  }

  Future<void> _ingest() async {
    final rows = _rows;
    if (rows == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    final res = await _db.processHrCsvIngestion(
      filename: _pickedName ?? 'roster.csv',
      lines: rows,
      source: _isExcel ? 'XLSX Upload' : 'CSV Upload',
    );

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _result = res;
    });

    final messenger = ScaffoldMessenger.of(context);
    if (res['success'] == true) {
      // Re-score the freshly ingested roster against the live model so the
      // overview and predictive board reflect this batch immediately.
      unawaited(HrAnalyticsController().refresh());
      messenger.showSnackBar(SnackBar(
        backgroundColor: _green,
        content: Text(
          'Committed: ${res['newCount']} new, ${res['updatedCount']} updated. '
          'Database: ${res['cohortSize']} personnel.',
        ),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade800,
        content: Text(res['error']?.toString() ?? 'Ingestion failed.'),
      ));
    }
  }

  String get _sizeLabel {
    if (_pickedBytes <= 0) return '';
    if (_pickedBytes < 1024) return '$_pickedBytes B';
    return '${(_pickedBytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final result = _result;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FBF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => context.backOr('/hr-overview'),
        ),
        title: const Text(
          'Data Ingestion • Tier 2 Portal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _ink),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _instructionsCard(),
              const SizedBox(height: 16),
              _pickerCard(rows),
              if (_parseError != null) ...[
                const SizedBox(height: 12),
                _errorBanner(_parseError!),
              ],
              if (result != null) ...[
                const SizedBox(height: 20),
                _reportSection(result),
              ],
              const SizedBox(height: 24),
              _recentBatches(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Instructions ─────────────────────────────────────────────────────────
  Widget _instructionsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: _green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Standardised roster upload',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a .csv or .xlsx duty roster. Every row is schema-validated, '
            'de-duplicated, and pseudonymised on-device before it reaches the '
            'analytics engine.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF3B443E)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDEBE2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REQUIRED COLUMNS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: _muted),
                ),
                SizedBox(height: 4),
                Text(
                  'service_id,  duty_hours,  leave_balance',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: _ink),
                ),
                SizedBox(height: 6),
                Text(
                  'Optional: unit_code,  deployment_zone,  consecutive_days\n'
                  'Wellness pulse (1-5): workload_perception,  sleep_quality,\n'
                  'exhaustion,  mood_rating,  manager_relationship,  peer_support',

                  style: TextStyle(fontSize: 11, height: 1.4, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── File picker ──────────────────────────────────────────────────────────
  Widget _pickerCard(List<String>? rows) {
    final hasFile = _pickedName != null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DottedZone(
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: Color(0xFFE3F2E9), shape: BoxShape.circle),
                  child: Icon(
                    hasFile
                        ? (_isExcel ? Icons.table_chart_outlined : Icons.insert_drive_file_outlined)
                        : Icons.cloud_upload_outlined,
                    color: _green,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasFile ? _pickedName! : 'Choose a CSV or Excel roster',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFile
                      ? [
                          if (_sizeLabel.isNotEmpty) _sizeLabel,
                          if (rows != null) '${rows.length - 1} data rows',
                          _isExcel ? 'XLSX' : 'CSV',
                        ].join('  ·  ')
                      : '.csv, .xlsx or .xls: parsed on this device',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickFile,
                      icon: const Icon(Icons.folder_open_outlined, size: 17),
                      label: Text(hasFile ? 'Choose another' : 'Browse files'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isProcessing ? null : _useSample,
                      icon: const Icon(Icons.dataset_outlined, size: 17),
                      label: const Text('Use sample roster'),
                      style: TextButton.styleFrom(foregroundColor: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (rows != null) ...[
            const SizedBox(height: 14),
            _previewTable(rows),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _ingest,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: Text(_isProcessing ? 'Validating & committing…' : 'Validate & commit batch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewTable(List<String> rows) {
    final header = rows.first.split(',');
    final sample = rows.skip(1).take(4).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4EDE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              'PREVIEW',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: _muted),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 34,
              horizontalMargin: 0,
              columnSpacing: 22,
              columns: [
                for (final h in header)
                  DataColumn(
                    label: Text(h.trim(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
                  ),
              ],
              rows: [
                for (final line in sample)
                  DataRow(
                    cells: [
                      for (var c = 0; c < header.length; c++)
                        DataCell(Text(
                          _nthCol(line, c),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF3B443E)),
                        )),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nthCol(String line, int index) {
    final parts = line.split(',');
    return index < parts.length ? parts[index].trim() : '';
  }

  // ── Validation report ────────────────────────────────────────────────────
  Widget _reportSection(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return _errorBanner(result['error']?.toString() ?? 'Ingestion failed.');
    }

    final accepted = (result['acceptedCount'] as int?) ?? 0;
    final rejected = (result['rejectedCount'] as int?) ?? 0;
    final added = (result['newCount'] as int?) ?? accepted;
    final updated = (result['updatedCount'] as int?) ?? 0;
    final cohortSize = (result['cohortSize'] as int?) ?? accepted;
    final total = (result['totalRows'] as int?) ?? (accepted + rejected);
    final reasons = (result['rejectionReasons'] as Map?)?.cast<String, int>() ?? const {};
    final sampleToken = result['sampleToken'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingestion validation report',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
        ),
        const SizedBox(height: 4),
        Text(
          '$total rows processed  ·  $added new, $updated updated  ·  '
          'database now $cohortSize personnel',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statTile(
                label: 'Accepted & pseudonymised',
                value: '$accepted',
                color: const Color(0xFF166534),
                bg: const Color(0xFFEAF6EE),
                border: const Color(0xFFBFE3CC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                label: 'Rejected at validation',
                value: '$rejected',
                color: const Color(0xFF9A2318),
                bg: const Color(0xFFFDECEA),
                border: const Color(0xFFF6C9C3),
              ),
            ),
          ],
        ),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why rows were rejected',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
                ),
                const SizedBox(height: 10),
                for (final e in (reasons.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value))))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B443E))),
                            ),
                            const SizedBox(width: 8),
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontSize: 11.5, fontWeight: FontWeight.w700, color: _ink)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: rejected == 0 ? 0 : e.value / rejected,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFEDE3E1),
                            color: const Color(0xFFCF5B4C),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (sampleToken != null) ...[
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 15, color: _green),
                    SizedBox(width: 6),
                    Text('Pseudonymised sample',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'token_$sampleToken…\nOriginal Service ID hashed (SHA-256) and discarded '
                  'in the ingestion buffer per PRD §2.',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF3B443E), height: 1.4),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.backOr('/hr-overview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFC1C8C2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to console'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: accepted == 0 ? null : () => context.push('/active-alerts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View predictive board'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4, color: color)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear ingested database?', style: TextStyle(fontSize: 16)),
        content: Text(
          'Removes all ${_db.hrFeatureRecords.length} personnel records and the '
          'ingestion history from this device. Cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2318), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _db.clearHrDatabase();
    unawaited(HrAnalyticsController().refresh());
    setState(() => _result = null);
  }

  // ── Recent batches ───────────────────────────────────────────────────────
  Widget _recentBatches() {
    final batches = _db.hrIngestionBatches;
    if (batches.isEmpty) return const SizedBox.shrink();
    final cohort = _db.hrFeatureRecords.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Recent ingestion runs',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink)),
            ),
            TextButton(
              onPressed: _confirmClear,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF9A2318)),
              child: const Text('Clear database', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        Text('$cohort personnel on file · batches accumulate across restarts',
            style: const TextStyle(fontSize: 10.5, color: _muted)),
        const SizedBox(height: 10),
        for (final b in batches.take(6))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5EFE8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: _green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b['filename']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${b['source'] ?? 'Upload'}  ·  ${b['accepted_rows'] ?? b['total_rows'] ?? 0} accepted'
                        '${(b['rejected_rows'] ?? 0) != 0 ? '  ·  ${b['rejected_rows']} rejected' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${b['status'] ?? ''}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _green),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Small shared pieces ──────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EFE8)),
      ),
      child: child,
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6C9C3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFF9A2318)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF7A1F16)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed drop-zone border used by the picker card.
class DottedZone extends StatelessWidget {
  const DottedZone({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFAFD6C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
