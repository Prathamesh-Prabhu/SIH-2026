import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/navigation.dart';
import '../../core/tara_config.dart';
import '../../services/db_service.dart';
import '../../services/supabase_service.dart';

/// Tara — the wellness companion. The screen is the `tara_service` voice UI
/// (Gemini Live audio-to-audio) in a WebView; a small chat icon in the app bar
/// opens a text conversation with the same Tara (`POST /chat`, plain Gemini,
/// same persona). The two don't depend on each other — text chat works whether
/// or not a voice call is running.
///
/// Leaving the screen or backgrounding the app hangs up any live voice call so
/// nothing keeps the mic + Gemini session running unattended.
///
/// Both paths scan for crisis language (voice via the `CrisisChannel` JS bridge,
/// `/chat` via `crisis: true`); either way [_escalate] raises a `crisis_alerts`
/// row and puts Tele-MANAS 14416 one tap away.
class TaraScreen extends StatefulWidget {
  const TaraScreen({super.key});

  @override
  State<TaraScreen> createState() => _TaraScreenState();
}

class _TaraScreenState extends State<TaraScreen> with WidgetsBindingObserver {
  static const _ink = Color(0xFF02150F);
  static const _mint = Color(0xFF9ED1C3);
  static const _pine = Color(0xFF37675B);

  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  bool _micGranted = false;
  bool _crisisHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<DbService>().noteTaraOpened();
    _init();
  }

  @override
  void dispose() {
    _hangUpVoice();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app going to the background must not leave a live mic + Gemini
    // session running behind it.
    if (state != AppLifecycleState.resumed) _hangUpVoice();
  }

  void _hangUpVoice() {
    try {
      _controller?.runJavaScript('window.__taraEndCall && window.__taraEndCall();');
    } catch (_) {}
  }

  /// Resolves the relay endpoint (Supabase → .env → localhost), used by both
  /// the voice WebView and the text chat.
  Future<void> _resolveEndpoint() async {
    final sb = context.read<SupabaseService>();
    if (sb.remoteTaraUrl == null || sb.remoteTaraUrl!.isEmpty) {
      await sb.fetchSystemEndpoints();
    }
    if (sb.remoteTaraUrl != null && sb.remoteTaraUrl!.isNotEmpty) {
      TaraConfig.syncFromSupabase(sb.remoteTaraUrl!);
    }
  }

  Future<void> _init() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    _micGranted = status.isGranted;

    await _resolveEndpoint();

    // Nudge the relay awake — a free-tier host sleeps when idle and the first
    // request otherwise cold-starts (and can time the chat out).
    unawaited(http
        .get(Uri.parse('${TaraConfig.url}/health'))
        .timeout(const Duration(seconds: 60))
        .catchError((_) => http.Response('', 408)));

    final controller = WebViewController.fromPlatformCreationParams(
      const PlatformWebViewControllerCreationParams(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_ink)
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

  Future<void> _reload() async {
    setState(() {
      _error = null;
      _loading = true;
      _crisisHandled = false;
    });
    await _resolveEndpoint();
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

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF071A14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _pine, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 6),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded, color: _mint, size: 18),
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
                child: _TaraChatBody(
                  onCrisis: (phrase, lastUserText) =>
                      _escalate(phrase: phrase, transcript: lastUserText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              'counsellors ready right now (free, confidential, 24/7).',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFFC9D6D0), height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16241F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _pine),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 16, color: _mint),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your unit's duty Welfare Officer has been alerted for a "
                      'supportive check-in. This never goes to your command '
                      'chain.',
                      style: TextStyle(
                          fontSize: 11.5, color: _mint, height: 1.4),
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
                    style: TextStyle(color: _mint)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
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
            tooltip: 'Chat with Tara',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: _error == null ? _openChat : null,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: (controller != null || _error != null) ? _reload : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _reload)
            else if (controller == null)
              const Center(child: CircularProgressIndicator(color: _mint))
            else ...[
              WebViewWidget(controller: controller),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: _mint)),
            ],
            if (_error == null && !_micGranted)
              const Align(
                alignment: Alignment.bottomCenter,
                child: _MicHint(
                  text: 'Microphone permission was denied: grant it in Settings '
                      'and reload for voice. Text chat still works.',
                ),
              )
            else if (_error == null && !TaraConfig.isSecureContext)
              const Align(
                alignment: Alignment.bottomCenter,
                child: _MicHint(
                  text: 'Tara needs a secure HTTPS connection for microphone '
                      'access. Text chat still works.',
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

class _TaraChatBody extends StatefulWidget {
  const _TaraChatBody({required this.onCrisis});

  /// (matchedPhrase, lastUserText) — raise the crisis escalation.
  final void Function(String? phrase, String lastUserText) onCrisis;

  @override
  State<_TaraChatBody> createState() => _TaraChatBodyState();
}

class _TaraChatBodyState extends State<_TaraChatBody> {
  static const _langPrefsKey = 'manofit_tara_chat_lang';

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _messages = [
    _ChatMsg(
        'assistant',
        "Hey, I'm Tara — English or हिंदी, whichever's easier. Whatever's on "
        "your mind: the day, the duty, or something heavier, I'm here. "
        "What's going on?"),
  ];
  bool _sending = false;
  String _lang = 'auto'; // 'auto' | 'en' | 'hi'

  @override
  void initState() {
    super.initState();
    _restoreLang();
  }

  Future<void> _restoreLang() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_langPrefsKey);
      if ((v == 'auto' || v == 'en' || v == 'hi') && mounted) {
        setState(() => _lang = v!);
      }
    } catch (_) {}
  }

  void _setLang(String v) {
    if (v == _lang) return;
    setState(() => _lang = v);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_langPrefsKey, v))
        .catchError((_) => false);
  }

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

  /// POSTs the conversation, retrying once — the relay host may have been
  /// asleep and the first hit just woke it.
  Future<http.Response?> _postChat(String payload) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .post(
              Uri.parse('${TaraConfig.url}/chat'),
              headers: const {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 75));
        if (res.statusCode == 200) return res;
      } catch (_) {
        // fall through to the retry
      }
      if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
    }
    return null;
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

    final payload = jsonEncode({
      'lang': _lang,
      'messages':
          _messages.map((m) => {'role': m.role, 'text': m.text}).toList(),
    });

    final res = await _postChat(payload);
    if (!mounted) return;

    if (res != null) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = (data['reply'] as String?)?.trim();
        setState(() => _messages.add(_ChatMsg(
            'assistant', reply?.isNotEmpty == true ? reply! : "I'm here.")));
        if (data['crisis'] == true) {
          widget.onCrisis(data['phrase'] as String?, text);
        }
      } catch (_) {
        _addError();
      }
    } else {
      _addError();
    }

    setState(() => _sending = false);
    _toBottom();
  }

  void _addError() {
    if (!mounted) return;
    setState(() => _messages.add(_ChatMsg(
        'assistant',
        "Sorry — I'm taking a moment to come online. Give it a few seconds "
        "and send that again.")));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatLangBar(current: _lang, onChanged: _setLang),
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
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78),
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
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
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
    );
  }
}

class _ChatLangBar extends StatelessWidget {
  const _ChatLangBar({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF071A14),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          const Icon(Icons.translate_rounded, size: 14, color: Color(0xFF7FA093)),
          const SizedBox(width: 8),
          const Text('Language',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF7FA093))),
          const Spacer(),
          _pill('Auto', 'auto'),
          _pill('EN', 'en'),
          _pill('हिं', 'hi'),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    final active = current == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF9ED1C3) : const Color(0xFF102820),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color:
                    active ? const Color(0xFF02241F) : const Color(0xFF7FA093),
              )),
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
            const Icon(Icons.cloud_off_rounded, size: 44, color: Color(0xFF9ED1C3)),
            const SizedBox(height: 14),
            const Text(
              "Can't reach the Tara service",
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to reach the Tara service.\n'
              'Please verify your connection and service status.\n\n$message',
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
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
