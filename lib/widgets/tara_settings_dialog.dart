import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/tara_config.dart';
import '../core/theme/app_theme.dart';

/// Points the app at a running Tara voice relay (`tara_service`) without a
/// rebuild. For a deployed phone the relay must be HTTPS (a tunnel) so the
/// WebView mic works; a USB handset can keep `http://localhost:3000` with
/// `adb reverse tcp:3000 tcp:3000`.
class TaraSettingsDialog extends StatefulWidget {
  const TaraSettingsDialog({super.key});

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => const TaraSettingsDialog(),
      );

  @override
  State<TaraSettingsDialog> createState() => _TaraSettingsDialogState();
}

class _TaraSettingsDialogState extends State<TaraSettingsDialog> {
  late final TextEditingController _url;
  bool _testing = false;
  String? _feedback;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: TaraConfig.url);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _testing = true;
      _feedback = null;
    });
    await TaraConfig.setUrl(_url.text);

    var ok = false;
    var detail = '';
    try {
      final res = await http
          .get(Uri.parse('${TaraConfig.url}/health'))
          .timeout(const Duration(seconds: 6));
      ok = res.statusCode == 200;
      if (ok) {
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          detail = 'model ${body['model'] ?? '?'} · voice ${body['voice'] ?? '?'}';
        } catch (_) {}
      } else {
        detail = 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      detail = '$e';
    }

    if (!mounted) return;
    setState(() {
      _testing = false;
      _error = !ok;
      _feedback = ok
          ? 'Relay reachable. $detail'
          : 'Could not reach the relay ($detail). Start it with '
              '`npm start` in tara_service and expose it over HTTPS.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final secure = TaraConfig.isSecureContext;
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: AppColors.secondary, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text('Tara voice relay',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                color: secure ? AppColors.secondaryContainer : AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(secure ? Icons.lock : Icons.lock_open,
                      size: 16,
                      color: secure ? AppColors.secondary : AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      secure
                          ? 'Secure context — microphone allowed'
                          : 'Not a secure context — voice mic will be blocked (text chat still works)',
                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Relay URL',
                hintText: 'https://xxxx.trycloudflare.com',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            if (TaraConfig.isUsingSupabase) ...[
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
                  if (TaraConfig.hasOverride)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () async {
                        await TaraConfig.setUrl('');
                        setState(() {
                          _url.text = TaraConfig.url;
                        });
                      },
                      child: const Text('Reset to auto', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Zero-paste: start-backends.ps1 automatically syncs Cloudflare URLs to Supabase.\n'
              'Manual entry above is only needed for custom overrides.',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.4),
            ),

            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _error ? AppColors.errorContainer : AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _feedback!,
                  style: TextStyle(
                    fontSize: 11,
                    color: _error ? AppColors.error : AppColors.secondary,
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close', style: TextStyle(color: AppColors.onSurfaceVariant)),
        ),
        ElevatedButton(
          onPressed: _testing ? null : _saveAndTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _testing
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save & test'),
        ),
        TextButton(
          onPressed: _testing ? null : () => Navigator.pop(context, true),
          child: const Text('Save & reload'),
        ),
      ],
    );
  }
}
