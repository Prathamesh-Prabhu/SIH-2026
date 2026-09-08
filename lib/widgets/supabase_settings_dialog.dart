import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/supabase_service.dart';

class SupabaseSettingsDialog extends StatefulWidget {
  const SupabaseSettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const SupabaseSettingsDialog(),
    );
  }

  @override
  State<SupabaseSettingsDialog> createState() => _SupabaseSettingsDialogState();
}

class _SupabaseSettingsDialogState extends State<SupabaseSettingsDialog> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _supabase = SupabaseService();
  bool _testing = false;
  String? _statusMessage;
  bool _statusSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _supabase.currentUrl;
    _keyCtrl.text = _supabase.currentAnonKey;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
    });

    final res = await _supabase.testConnection(_urlCtrl.text, _keyCtrl.text);
    setState(() {
      _testing = false;
      _statusSuccess = res['success'] == true;
      _statusMessage = res['message'] as String?;
    });
  }

  Future<void> _save() async {
    final success = await _supabase.updateCredentials(_urlCtrl.text, _keyCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Supabase credentials saved successfully!' : 'Failed to save credentials'),
          backgroundColor: success ? AppColors.secondary : AppColors.error,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hub_outlined, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supabase Backend Config',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                        ),
                        Text(
                          _supabase.isMockMode ? 'Current Mode: Local Mock/Demo' : 'Current Mode: Live Supabase Connected',
                          style: TextStyle(
                            fontSize: 12,
                            color: _supabase.isMockMode ? AppColors.secondary : Colors.green[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Supabase Project URL',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://xyz.supabase.co',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Supabase Anon / Public Key',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keyCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusSuccess ? AppColors.secondaryContainer.withOpacity(0.5) : AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusSuccess ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18,
                        color: _statusSuccess ? AppColors.secondary : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusSuccess ? AppColors.onSecondaryContainer : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Test'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save & Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
