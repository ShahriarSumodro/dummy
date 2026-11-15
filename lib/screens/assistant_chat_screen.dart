import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_query_service.dart';
import '../services/voice_service.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String> sourceReferences;
  final List<String> suggestedNextActions;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.sourceReferences = const [],
    this.suggestedNextActions = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Interactive Assistant Chat Screen.
/// Answers grounded questions about personal business memory without hallucinations.
class AssistantChatScreen extends StatefulWidget {
  final String? initialQuery;

  const AssistantChatScreen({super.key, this.initialQuery});

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final _queryService = AiQueryService();
  final _voiceService = VoiceService();
  final _db = DatabaseService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<_ChatMessage> _messages = [];
  bool _isThinking = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isLoadingHistory = true;

  static const _sampleQuestions = [
    'What commitments are pending?',
    'What did I promise recently?',
    'Which clients need a follow-up?',
    'Show my recent meeting notes',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final stored = await _db.getChatMessages(limit: 60);
      if (mounted) {
        setState(() {
          if (stored.isNotEmpty) {
            _messages.clear();
            for (final m in stored) {
              _messages.add(
                _ChatMessage(
                  text: m['text'] as String,
                  isUser: m['is_user'] as bool,
                  sourceReferences: List<String>.from(m['source_references'] ?? []),
                  suggestedNextActions: List<String>.from(m['suggested_next_actions'] ?? []),
                  timestamp: DateTime.tryParse(m['timestamp'] as String? ?? ''),
                ),
              );
            }
          } else {
            _messages.add(
              _ChatMessage(
                text:
                    'Hello! I am Dummy., your personal AI companion. Ask me anything about your contacts, commitments, or schedule — or just chat naturally.',
                isUser: false,
                suggestedNextActions: _sampleQuestions,
              ),
            );
          }
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  'Hello! I am Dummy., your personal AI companion. Ask me anything about your contacts, commitments, or schedule — or just chat naturally.',
              isUser: false,
              suggestedNextActions: _sampleQuestions,
            ),
          );
          _isLoadingHistory = false;
        });
      }
    }

    if (widget.initialQuery != null) {
      _sendQuery(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _voiceService.stop();
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleChatVoiceInput() async {
    AppHaptics.lightImpact();
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_textController.text.trim().isNotEmpty) {
        _sendQuery(_textController.text);
      }
    } else {
      if (!_speechAvailable) {
        _speechAvailable = await _speech.initialize(
          onError: (_) {
            if (mounted) setState(() => _isListening = false);
          },
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              if (mounted && _isListening) setState(() => _isListening = false);
            }
          },
        );
      }
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Microphone permission or speech recognition unavailable.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          );
        }
        return;
      }

      setState(() => _isListening = true);
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _textController.text = result.recognizedWords;
              });
              if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
                _speech.stop();
                setState(() => _isListening = false);
                _sendQuery(result.recognizedWords);
              }
            }
          },
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
        );
      } catch (e) {
        debugPrint('Error starting chat STT: $e');
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isThinking) return;

    AppHaptics.lightImpact();
    setState(() {
      _messages.add(_ChatMessage(text: cleanQuery, isUser: true));
      _isThinking = true;
      _textController.clear();
    });
    _scrollToBottom();

    // Persist user message to SQLite
    try {
      await _db.insertChatMessage(text: cleanQuery, isUser: true);
    } catch (_) {}

    try {
      final history = _messages
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      final response = await _queryService.queryMemory(cleanQuery, conversationHistory: history);
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: response.answer,
              isUser: false,
              sourceReferences: response.sourceReferences,
              suggestedNextActions: response.suggestedNextActions,
            ),
          );
        });

        // Persist companion response to SQLite
        try {
          await _db.insertChatMessage(
            text: response.answer,
            isUser: false,
            sourceReferences: response.sourceReferences,
            suggestedNextActions: response.suggestedNextActions,
          );
        } catch (_) {}

        // Automatically speak response if auto-speak setting is active
        try {
          final settings = await _db.getAssistantSettings();
          if (settings.autoSpeakResponses) {
            _voiceService.speak(response.answer);
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        final errorText = 'Unable to query companion: $e';
        setState(() {
          _messages.add(
            _ChatMessage(
              text: errorText,
              isUser: false,
            ),
          );
        });
        try {
          await _db.insertChatMessage(text: errorText, isUser: false);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _confirmClearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text(
          'This will clear your current chat history. Your saved contacts, commitments, and meetings will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      AppHaptics.mediumImpact();
      _voiceService.stop();
      await _db.clearChatMessages();
      setState(() {
        _messages.clear();
        _messages.add(
          _ChatMessage(
            text:
                'Hello! I am Dummy., your personal AI companion. How can I help you right now?',
            isUser: false,
            suggestedNextActions: _sampleQuestions,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.psychology_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text('Dummy.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        actions: [
          ValueListenableBuilder<TtsState>(
            valueListenable: _voiceService.ttsState,
            builder: (context, state, _) {
              if (state == TtsState.playing) {
                return IconButton(
                  icon: const Icon(Icons.stop_circle_rounded, color: AppColors.error),
                  tooltip: 'Stop Speaking',
                  onPressed: () => _voiceService.stop(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear Conversation',
            onPressed: _confirmClearConversation,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          if (_isThinking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Searching verified memory...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border(
                top: BorderSide(color: AppColors.border(context), width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask memory (e.g. What did I promise?)...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.muted(context)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.subtle(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _sendQuery,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                    color: _isListening ? AppColors.error : AppColors.primary,
                    tooltip: _isListening ? 'Listening... Tap to send' : 'Speak Question',
                    onPressed: _toggleChatVoiceInput,
                  ),
                  const SizedBox(width: 2),
                  InkWell(
                    onTap: () => _sendQuery(_textController.text),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: msg.isUser
              ? AppColors.primary
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.lg).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(2) : null,
            bottomLeft: !msg.isUser ? const Radius.circular(2) : null,
          ),
          border: !msg.isUser ? Border.all(color: AppColors.border(context), width: 0.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              msg.text,
              style: TextStyle(
                color: msg.isUser ? Colors.white : AppColors.foreground(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),

            if (msg.sourceReferences.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: msg.sourceReferences.map((ref) {
                  return AppBadge(label: ref, variant: AppBadgeVariant.neutral);
                }).toList(),
              ),
            ],

            if (msg.suggestedNextActions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: msg.suggestedNextActions.map((action) {
                  return ActionChip(
                    label: Text(action, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _sendQuery(action),
                  );
                }).toList(),
              ),
            ],

            if (!msg.isUser) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: _voiceService.currentSpeakingText,
                    builder: (context, speakingText, _) {
                      final isThisSpeaking = speakingText == msg.text;
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        onTap: () {
                          AppHaptics.lightImpact();
                          _voiceService.speak(msg.text);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isThisSpeaking ? Icons.volume_up_rounded : Icons.volume_down_outlined,
                                size: 15,
                                color: isThisSpeaking ? AppColors.primary : AppColors.muted(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isThisSpeaking ? 'Speaking...' : 'Speak',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isThisSpeaking ? FontWeight.bold : FontWeight.normal,
                                  color: isThisSpeaking ? AppColors.primary : AppColors.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
