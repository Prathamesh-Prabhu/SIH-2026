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
import '../../widgets/tara_settings_dialog.dart';

/// Tara — the wellness companion, with two fully independent modes:
///
///  * **Chat** — a plain Flutter text conversation (`POST /chat`, non-Live
///    Gemini). No microphone, no WebView. Available the moment the screen opens.
///  * **Voice** — the `tara_service` WebView (Gemini Live audio-to-audio). Only
///    loaded, and only granted the mic, once the user opens this tab.
///
/// Switching to Chat, backgrounding the app, or leaving the screen all hang up
/// any live voice call so nothing keeps running unattended.
///
/// Both paths scan for crisis language (voice via the `CrisisChannel` JS bridge,
/// `/chat` via `crisis: true`); either way [_escalate] raises a `crisis_alerts`
/// row and puts Tele-MANAS 14416 one tap away.
class TaraScreen extends StatefulWidget {
  const TaraScreen({super.key});

  @override
  State<TaraScreen> createState() => _TaraScreenState();
}

enum _TaraMode { chat, voice }

class _TaraScreenState extends State<TaraScreen> with WidgetsBindingObserver {
  static const _modePrefsKey = 'manofit_tara_mode';
  static const _ink = Color(0xFF02150F);
  static const _mint = Color(0xFF9ED1C3);
  static const _pine = Color(0xFF37675B);

  WebViewController? _controller;
  bool _voiceLoading = true;
  String? _voiceError;
  bool _micGranted = false;
  bool _crisisHandled = false;

  _TaraMode _mode = _TaraMode.chat;
  bool _voiceRequested = false; // first time the Voice tab is opened
  bool _voiceIniting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<DbService>().noteTaraOpened();
    _restoreMode();
  }

  Future<void> _restoreMode() async {
    var restored = _TaraMode.chat;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_modePrefsKey) == 'voice') restored = _TaraMode.voice;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _mode = restored);
    if (restored == _TaraMode.voice) _activateVoice();
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

  Future<void> _persistMode(_TaraMode m) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modePrefsKey, m == _TaraMode.voice ? 'voice' : 'chat');
    } catch (_) {}
  }

  void _selectMode(_TaraMode m) {
    if (m == _mode) return;
    if (m == _TaraMode.chat) _hangUpVoice();
    setState(() => _mode = m);
    _persistMode(m);
    if (m == _TaraMode.voice) _activateVoice();
  }

  Future<void> _activateVoice() async {
    if (_voiceIniting || _controller != null) return;
    _voiceIniting = true;
    if (mounted) setState(() => _voiceRequested = true);
    await _initVoice();
    _voiceIniting = false;
  }

  Future<void> _initVoice() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    _micGranted = status.isGranted;

    final sb = context.read<SupabaseService>();
    if (sb.remoteTaraUrl == null || sb.remoteTaraUrl!.isEmpty) {
      await sb.fetchSystemEndpoints();
    }
    if (sb.remoteTaraUrl != null && sb.remoteTaraUrl!.isNotEmpty) {
      TaraConfig.syncFromSupabase(sb.remoteTaraUrl!);
    }

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
            if (mounted) setState(() => _voiceLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _voiceLoading = false);
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == false) return;
            if (mounted) {
              setState(() {
                _voiceLoading = false;
                _voiceError = err.description;
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

  Future<void> _reloadVoice() async {
    setState(() {
      _voiceError = null;
      _voiceLoading = true;
      _crisisHandled = false;
    });
    final sb = context.read<SupabaseService>();
    await sb.fetchSystemEndpoints();
    if (sb.remoteTaraUrl != null && sb.remoteTaraUrl!.isNotEmpty) {
      TaraConfig.syncFromSupabase(sb.remoteTaraUrl!);
    }
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
    final voiceMode = _mode == _TaraMode.voice;

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
          if (voiceMode) ...[
            IconButton(
              tooltip: 'Voice relay connection',
              icon: const Icon(Icons.settings_ethernet_rounded),
              onPressed: () async {
                final reload = await TaraSettingsDialog.show(context);
                if (reload == true && mounted) _reloadVoice();
              },
            ),
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: (_controller != null || _voiceError != null)
                  ? _reloadVoice
                  : null,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: _ModeToggle(current: _mode, onChanged: _selectMode),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          sizing: StackFit.expand,
          index: voiceMode ? 1 : 0,
          children: [
            _TaraChatView(
              onCrisis: (phrase, lastUserText) =>
                  _escalate(phrase: phrase, transcript: lastUserText),
            ),
            _voicePane(),
          ],
        ),
      ),
    );
  }

  Widget _voicePane() {
    if (!_voiceRequested || (_controller == null && _voiceError == null)) {
      return const Center(child: CircularProgressIndicator(color: _mint));
    }
    if (_voiceError != null) {
      return _ErrorPanel(message: _voiceError!, onRetry: _reloadVoice);
    }
    final controller = _controller!;
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (_voiceLoading)
          const Center(child: CircularProgressIndicator(color: _mint)),
        if (!_micGranted)
          const Align(
            alignment: Alignment.bottomCenter,
            child: _MicHint(
              text: 'Microphone permission was denied: grant it in Settings and '
                  'reload for voice. Use Chat in the meantime.',
            ),
          )
        else if (!TaraConfig.isSecureContext)
          const Align(
            alignment: Alignment.bottomCenter,
            child: _MicHint(
              text: 'Tara needs a secure HTTPS connection for microphone access. '
                  'Chat still works.',
            ),
          ),
      ],
    );
  }
}

// ── Voice / Chat mode toggle ───────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.current, required this.onChanged});

  final _TaraMode current;
  final ValueChanged<_TaraMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0C231C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x2E9ED1C3)),
        ),
        child: Row(
          children: [
            _seg('Chat', Icons.chat_bubble_outline_rounded, _TaraMode.chat),
            _seg('Voice', Icons.graphic_eq_rounded, _TaraMode.voice),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, IconData icon, _TaraMode mode) {
    final active = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [Color(0xFF9ED1C3), Color(0xFF37675B)])
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? const Color(0xFF02241F) : const Color(0xFF7FA093)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? const Color(0xFF02241F)
                        : const Color(0xFF7FA093),
                  )),
            ],
          ),
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

class _TaraChatView extends StatefulWidget {
  const _TaraChatView({required this.onCrisis});

  /// (matchedPhrase, lastUserText) — raise the crisis escalation.
  final void Function(String? phrase, String lastUserText) onCrisis;

  @override
  State<_TaraChatView> createState() => _TaraChatViewState();
}

class _TaraChatViewState extends State<_TaraChatView> {
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
              'lang': _lang,
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
          setState(() => _messages.add(_ChatMsg(
              'assistant', reply?.isNotEmpty == true ? reply! : "I'm here.")));
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
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13.5),
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
