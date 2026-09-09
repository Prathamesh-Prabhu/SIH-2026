import 'package:flutter/material.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';

class HrDataIngestionScreen extends StatefulWidget {
  const HrDataIngestionScreen({super.key});

  @override
  State<HrDataIngestionScreen> createState() => _HrDataIngestionScreenState();
}

class _HrDataIngestionScreenState extends State<HrDataIngestionScreen> {
  final _db = DbService();
  bool _isProcessing = false;
  Map<String, dynamic>? _lastBatchResult;

  // Sample CSV data for one-tap demo testing
  final String _sampleCsvContent = '''service_id,duty_hours,leave_balance,deployment_zone
CAPF-88214,48,26,Northern Sector
CAPF-88215,56,12,Northern Sector
CAPF-88216,52,18,Western Outpost
CAPF-88217,64,4,High Altitude Outpost
,44,30,Eastern Sector
CAPF-88219,40,32,Base Depot
CAPF-88220,58,8,Northern Sector''';

  Future<void> _processSampleUpload() async {
    setState(() => _isProcessing = true);

    final lines = _sampleCsvContent.split('\n');
    final result = await _db.processHrCsvIngestion(
      filename: 'CAPF_Sector4_Roster_Batch_A.csv',
      lines: lines,
    );

    setState(() {
      _isProcessing = false;
      _lastBatchResult = result;
    });

    if (mounted && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processed: ${result['acceptedCount']} accepted, ${result['rejectedCount']} rejected (missing ID)'),
          backgroundColor: Colors.green[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/hr-overview'),
        ),
        title: const Text('Data Ingestion • Tier 2 Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
                        SizedBox(width: 8),
                        Text('Standardized Roster Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload .csv formatted duty rosters. All records undergo schema validation, duplicate detection, and pseudonymization before touching the ML analytics engine.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Standard template columns: service_id, duty_hours, leave_balance, deployment_zone')),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Template Specs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green[800],
                            side: BorderSide(color: Colors.green[800]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Drag & Drop / Upload Area
              GestureDetector(
                onTap: _isProcessing ? null : _processSampleUpload,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal[200]!, width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cloud_upload_outlined, color: Colors.teal[700], size: 30),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tap to Ingest Sample CSV Roster',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Simulates Tier-2 batch: CAPF_Sector4_Roster_Batch_A.csv (7 records with validation)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      if (_isProcessing)
                        const CircularProgressIndicator(color: AppColors.secondary)
                      else
                        ElevatedButton(
                          onPressed: _processSampleUpload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Parse & Ingest Roster'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Ingestion Validation Report
              if (_lastBatchResult != null) ...[
                const Text('Ingestion Validation Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Accepted & Pseudonymized', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            Text('${_lastBatchResult!['acceptedCount']} Rows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[900])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rejected (Missing ID)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 4),
                            Text('${_lastBatchResult!['rejectedCount']} Rows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[900])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock, size: 16, color: AppColors.secondary),
                          SizedBox(width: 6),
                          Text('Rotating Token Sample (Pseudonymized)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Token: token_a94f83b2... • Duty: 48 hrs/wk • Leave: 26d • Zone: Northern Sector\n(Original Service ID destroyed in analytics ingestion buffer per PRD §2)',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
