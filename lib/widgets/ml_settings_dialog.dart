import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../services/ml_service.dart';
import '../services/supabase_service.dart';

/// Lets a reviewer point the app at a running Analytics & ML microservice
/// without rebuilding — useful when the service runs on another host or when
/// a USB-attached handset needs `adb reverse tcp:8000 tcp:8000`.
class MlSettingsDialog extends StatefulWidget {
  const MlSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const MlSettingsDialog(),
    );
  }

  @override
  State<MlSettingsDialog> createState() => _MlSettingsDialogState();
}

class _MlSettingsDialogState extends State<MlSettingsDialog> {
  final _ml = MlService();
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  bool _isTesting = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _ml.baseUrl);
    _tokenController = TextEditingController(text: _ml.token);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _isTesting = true;
      _feedback = null;
    });

    final ok = await _ml.updateEndpoint(
      _urlController.text,
      _tokenController.text,
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _feedbackIsError = !ok;
      _feedback = ok
          ? 'Connected. ${_ml.statusMessage}'
          : 'Could not reach the service. Please verify your connection or service status.';
    });
  }


  @override
  Widget build(BuildContext context) {
    final sb = context.watch<SupabaseService>();
    final remoteMl = sb.remoteMlUrl;

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.insights_outlined, color: AppColors.secondary, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text('Analytics & ML Service',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _ml.isOnline
                    ? AppColors.secondaryContainer
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _ml.isOnline ? Icons.check_circle : Icons.error_outline,
                    size: 16,
                    color: _ml.isOnline ? AppColors.secondary : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ml.statusMessage,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Service Base URL',
                hintText: 'http://localhost:8000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            if (remoteMl != null && remoteMl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Auto-synced from Supabase (system_config)',
                      style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () {
                      setState(() {
                        _urlController.text = remoteMl;
                      });
                      _saveAndTest();
                    },
                    child: const Text('Reset to auto', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Internal Service Token',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Service endpoint is managed automatically via cloud configuration.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4),
            ),

            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _feedbackIsError
                      ? AppColors.errorContainer
                      : AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _feedback!,
                  style: TextStyle(
                    fontSize: 11,
                    color: _feedbackIsError
                        ? AppColors.error
                        : AppColors.secondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close',
              style: TextStyle(color: AppColors.onSurfaceVariant)),
        ),
        ElevatedButton(
          onPressed: _isTesting ? null : _saveAndTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save & Test'),
        ),
      ],
    );
  }
}
