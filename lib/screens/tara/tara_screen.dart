import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/navigation.dart';
import '../../core/tara_config.dart';
import '../../services/db_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/tara_settings_dialog.dart';

/// Tara — the wellness companion. The WebView hosts the `tara_service` voice
/// UI (Gemini Live audio-to-audio); a chat button opens a text conversation
/// with the same Tara (`POST /chat`, plain Gemini, same persona).
///
/// Both paths scan for crisis language: the relay flags voice via the
/// `CrisisChannel` JS bridge, `/chat` returns `crisis: true`. Either way
/// [_escalate] raises a `crisis_alerts` row (Welfare Officer handoff) and
/// puts Tele-MANAS 14416 one tap away.
class TaraScreen extends StatefulWidget {
  const TaraScreen({super.key});

  @override
  State<TaraScreen> createState() => _TaraScreenState();
}

class _TaraScreenState extends State<TaraScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  bool _micGranted = false;
  bool _crisisHandled = false;

  @override
  void initState() {
    super.initState();
    context.read<DbService>().noteTaraOpened();
    _init();
  }

  Future<void> _init() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    _micGranted = status.isGranted;

    final sb = context.read<SupabaseService>();
    if (sb.remoteTaraUrl != null && sb.remoteTaraUrl!.isNotEmpty) {
      TaraConfig.syncFromSupabase(sb.remoteTaraUrl!);
    }



    final controller = WebViewController.fromPlatformCreationParams(
      const PlatformWebViewControllerCreationParams(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF02150F))
      ..addJavaScriptChannel(
        'CrisisChannel',
        onMessageReceived: (m) => _onCrisisMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == false) return;
            if (mounted) {
              setState(() {
                _loading = false;
                _error = err.description;
              });
            }
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
      await android.setOnPlatformPermissionRequest((request) => request.grant());
    }

    await controller.loadRequest(Uri.parse(TaraConfig.url));
    if (mounted) setState(() => _controller = controller);
  }

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
      _crisisHandled = false;
    });
    _controller?.loadRequest(Uri.parse(TaraConfig.url));
  }

  void _onCrisisMessage(String raw) {
    String? phrase;
    String? transcript;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      phrase = data['phrase'] as String?;
      transcript = data['transcript'] as String?;
    } catch (_) {}
    _escalate(phrase: phrase, transcript: transcript);
  }

  Future<void> _escalate({String? phrase, String? transcript}) async {
    if (_crisisHandled || !mounted) return;
    _crisisHandled = true;

    await context.read<DbService>().recordCrisisEscalation(
          source: 'tara',
          phrase: phrase,
          transcript: transcript,
        );

    if (mounted) _showCrisisSheet();
  }

  Future<void> _dialTeleManas() async {
    final uri = Uri.parse('tel:14416');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dial Tele-MANAS on 14416.')),
      );
    }
  }

  void _showCrisisSheet() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF12100F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite_rounded, color: Color(0xFFE88C7D), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "It sounds like you're carrying something really heavy",
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "You don't have to hold this alone. Tele-MANAS has trained "
              'counsellors ready right now — free, confidential, 24/7.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFFC9D6D0), height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16241F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF37675B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded,
                      size: 16, color: Color(0xFF9ED1C3)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your unit's duty Welfare Officer has been alerted for a "
                      'supportive check-in. This never goes to your command '
                      'chain.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF9ED1C3),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD24B3B),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _dialTeleManas();
                },
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call Tele-MANAS · 14416',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Stay in the conversation with Tara',
                    style: TextStyle(color: Color(0xFF9ED1C3))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF071A14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _TaraChatSheet(
        onCrisis: (phrase, lastUserText) =>
            _escalate(phrase: phrase, transcript: lastUserText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: const Color(0xFF02150F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02150F),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/mindfulness'),
        ),
        title: const Text('Tara · your companion',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Voice relay connection',
            icon: const Icon(Icons.settings_ethernet_rounded),
            onPressed: () async {
              final reload = await TaraSettingsDialog.show(context);
              if (reload == true && mounted) _reload();
            },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: (controller != null || _error != null) ? _reload : null,
          ),
        ],
      ),
      floatingActionButton: (_error == null)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF37675B),
              foregroundColor: Colors.white,
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Chat'),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _reload)
            else if (controller == null)
              const Center(
                  child: CircularProgressIndicator(color: Color(0xFF9ED1C3)))
            else ...[
              WebViewWidget(controller: controller),
              if (_loading)
                const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF9ED1C3))),
            ],
            if (_error == null && !_micGranted)
              const Align(
                alignment: Alignment.bottomCenter,
                child: _MicHint(
                  text: 'Microphone permission was denied — grant it in '
                      'Settings and reload for voice. Text chat still works.',
                ),
              )
            else if (_error == null && !TaraConfig.isSecureContext)
              const Align(
                alignment: Alignment.bottomCenter,
                child: _MicHint(
                  text: 'Tara is loading from a non-secure address, so voice '
                      'mic stays blocked. Use adb reverse + a localhost '
                      'TARA_URL. Text chat still works.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Text chat with Tara ────────────────────────────────────────────────────
class _ChatMsg {
  _ChatMsg(this.role, this.text);
  final String role; // 'user' | 'assistant'
  final String text;
}

class _TaraChatSheet extends StatefulWidget {
  const _TaraChatSheet({required this.onCrisis});

  /// (matchedPhrase, lastUserText) — raise the crisis escalation.
  final void Function(String? phrase, String lastUserText) onCrisis;

  @override
  State<_TaraChatSheet> createState() => _TaraChatSheetState();
}

class _TaraChatSheetState extends State<_TaraChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _messages = [
    _ChatMsg('assistant',
        "Hey, I'm Tara. Whatever's on your mind — the day, the duty, "
        "something heavier — I'm here. What's going on?"),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(_ChatMsg('user', text));
      _sending = true;
    });
    _toBottom();

    try {
      final res = await http
          .post(
            Uri.parse('${TaraConfig.url}/chat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': _messages
                  .map((m) => {'role': m.role, 'text': m.text})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = (data['reply'] as String?)?.trim();
        if (mounted) {
          setState(() => _messages
              .add(_ChatMsg('assistant', reply?.isNotEmpty == true ? reply! : "I'm here.")));
        }
        if (data['crisis'] == true) {
          widget.onCrisis(data['phrase'] as String?, text);
        }
      } else {
        _addError();
      }
    } catch (_) {
      _addError();
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
  }

  void _addError() {
    if (!mounted) return;
    setState(() => _messages.add(_ChatMsg('assistant',
        "I couldn't reach the service just now. Make sure the Tara server is "
        "running, then try again.")));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF37675B),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded,
                      color: Color(0xFF9ED1C3), size: 18),
                  const SizedBox(width: 8),
                  const Text('Chat with Tara',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF15332A)),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_sending && i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 6, top: 4),
                      child: Text('Tara is typing…',
                          style: TextStyle(
                              color: Color(0xFF7FA093),
                              fontSize: 12,
                              fontStyle: FontStyle.italic)),
                    );
                  }
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 10),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF37675B)
                            : const Color(0xFF102820),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isUser ? 14 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 14),
                        ),
                      ),
                      child: Text(m.text,
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: isUser
                                  ? Colors.white
                                  : const Color(0xFFE6F2EE))),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF071A14),
                border: Border(top: BorderSide(color: Color(0xFF15332A))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Message Tara…',
                        hintStyle: const TextStyle(color: Color(0xFF6F8F84)),
                        filled: true,
                        fillColor: const Color(0xFF102820),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF9ED1C3),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          size: 18, color: Color(0xFF02241F)),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: Color(0xFF9ED1C3)),
            const SizedBox(height: 14),
            const Text(
              "Can't reach the Tara service",
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Start it with:  cd SIH-2026/tara_service && npm start\n'
              'For a USB device also run:  adb reverse tcp:3000 tcp:3000\n\n'
              'URL: ${TaraConfig.url}\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF8AA79C), height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF37675B),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicHint extends StatelessWidget {
  const _MicHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 84),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF37675B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off_rounded, size: 16, color: Color(0xFF9ED1C3)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFE6F2EE), height: 1.35)),
          ),
        ],
      ),
    );
  }
}
