import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';
import '../widgets/quick_screen_switcher.dart';

class AiCompanionScreen extends StatefulWidget {
  const AiCompanionScreen({super.key});

  @override
  State<AiCompanionScreen> createState() => _AiCompanionScreenState();
}

class _AiCompanionScreenState extends State<AiCompanionScreen> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _db = DbService();

  bool _isListening = false;
  bool _isSending = false;
  bool _crisisModeActive = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'assistant',
      'message': 'Welcome Dhruv. I am your confidential AI wellness companion. How has your shift or duty been feeling today?',
      'is_crisis': false,
    },
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add({'sender': 'user', 'message': clean, 'is_crisis': false});
      _isSending = true;
    });

    _scrollToBottom();

    final result = await _db.sendCompanionMessage(clean);

    if (mounted) {
      setState(() {
        _isSending = false;
        _messages.add({
          'sender': 'assistant',
          'message': result['reply'] as String,
          'is_crisis': result['isCrisis'] as bool,
        });
        if (result['isCrisis'] == true) {
          _crisisModeActive = true;
          _showTeleManasDialog();
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showTeleManasDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tele-MANAS Support',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your safety and mental peace come first. We detected high situational stress in your message.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Tele-MANAS (14416) is India\'s 24/7 dedicated confidential armed forces & citizen psychological helpline. Free and immediate.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay in Chat', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.call, size: 16),
            label: const Text('Call 14416 Now'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dialing Tele-MANAS (14416)...')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: const QuickScreenSwitcher(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('AI Companion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 12, color: AppColors.secondary),
                SizedBox(width: 4),
                Text('Encrypted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Emergency Support Banner (Tele-MANAS 14416)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _crisisModeActive ? AppColors.errorContainer : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: _crisisModeActive ? Border.all(color: AppColors.error, width: 1.5) : null,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _crisisModeActive ? AppColors.error : AppColors.secondaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.call, size: 16, color: _crisisModeActive ? Colors.white : AppColors.onSecondaryContainer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tele-MANAS • 14416',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _crisisModeActive ? AppColors.error : AppColors.primary,
                          ),
                        ),
                        Text(
                          _crisisModeActive ? 'Priority Crisis Escalation Active' : '24/7 Priority Helpline Support',
                          style: TextStyle(
                            fontSize: 11,
                            color: _crisisModeActive ? AppColors.error : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecting to Tele-MANAS (14416)...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _crisisModeActive ? AppColors.error : AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Voice Orb Card (Central Viewport)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _isListening = !_isListening);
                      if (_isListening) {
                        _sendMessage('Reporting situational fatigue after 12-hour convoy escort duty.');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: _isListening ? 90 : 76,
                      height: _isListening ? 90 : 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? AppColors.secondaryContainer : AppColors.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? AppColors.secondary : AppColors.primary).withOpacity(0.3),
                            blurRadius: _isListening ? 20 : 10,
                            spreadRadius: _isListening ? 4 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.graphic_eq_rounded,
                        color: _isListening ? AppColors.primary : AppColors.secondaryFixed,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isListening ? 'Listening... Tap to stop' : 'Tap Orb to Speak or Type Below',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            // Quick Prompt Chips
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _promptChip('Decompress after shift'),
                  const SizedBox(width: 8),
                  _promptChip('Grounding exercise (3 min)'),
                  const SizedBox(width: 8),
                  _promptChip('Test Crisis Keyword (Tele-MANAS)'),
                  const SizedBox(width: 8),
                  _promptChip('Reflect on today'),
                ],
              ),
            ),

            // Chat Messages Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';
                  final isCrisis = msg['is_crisis'] == true;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCrisis
                            ? AppColors.errorContainer
                            : (isUser ? AppColors.primaryContainer : AppColors.surfaceContainerLowest),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        msg['message'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCrisis
                              ? AppColors.error
                              : (isUser ? Colors.white : AppColors.onSurface),
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isSending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)),
              ),

            // Chat Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Speak freely in confidence...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 13),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      onPressed: () => _sendMessage(_textController.text),
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

  Widget _promptChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: AppColors.outlineVariant),
      onPressed: () {
        if (text.contains('Crisis')) {
          _sendMessage('I feel completely hopeless and cannot take this anymore.');
        } else {
          _sendMessage(text);
        }
      },
    );
  }
}
