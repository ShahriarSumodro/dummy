import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_query_service.dart';
import '../services/voice_service.dart';
import '../services/database_service.dart';

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

  static const _sampleQuestions = [
    'What commitments are pending?',
    'What did I promise recently?',
    'Which clients need a follow-up?',
    'Show my recent meeting notes',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            'Hello! I am your personal business memory assistant. Ask me anything about your contacts, commitments, meetings, or promises.',
        isUser: false,
        suggestedNextActions: _sampleQuestions,
      ),
    );

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
            const SnackBar(content: Text('Microphone permission or speech recognition unavailable.')),
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

    setState(() {
      _messages.add(_ChatMessage(text: cleanQuery, isUser: true));
      _isThinking = true;
      _textController.clear();
    });
    _scrollToBottom();

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
        setState(() {
          _messages.add(
            _ChatMessage(
              text: 'Unable to query memory: $e',
              isUser: false,
            ),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology, size: 24),
            SizedBox(width: 8),
            Text('Memory Assistant'),
          ],
        ),
        actions: [
          ValueListenableBuilder<TtsState>(
            valueListenable: _voiceService.ttsState,
            builder: (context, state, _) {
              if (state == TtsState.playing) {
                return IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.tealAccent),
                  tooltip: 'Stop Speaking',
                  onPressed: () => _voiceService.stop(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Conversation Session',
            onPressed: () {
              _voiceService.stop();
              setState(() {
                _messages.clear();
                _messages.add(
                  _ChatMessage(
                    text:
                        'Session restarted. What would you like to review or plan?',
                    isUser: false,
                    suggestedNextActions: _sampleQuestions,
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, theme);
              },
            ),
          ),

          if (_isThinking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Searching verified memory...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask your memory (e.g. What did I promise?)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _sendQuery,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    color: _isListening ? Colors.red : theme.colorScheme.primary,
                    tooltip: _isListening ? 'Listening... Tap to send' : 'Speak Question',
                    onPressed: _toggleChatVoiceInput,
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () => _sendQuery(_textController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(0) : null,
            bottomLeft: !msg.isUser ? const Radius.circular(0) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              msg.text,
              style: TextStyle(
                color: msg.isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),

            if (msg.sourceReferences.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.sourceReferences.map((ref) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(ref, style: const TextStyle(fontSize: 10)),
                    backgroundColor: theme.colorScheme.surface,
                  );
                }).toList(),
              ),
            ],

            if (msg.suggestedNextActions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.suggestedNextActions.map((action) {
                  return ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(action, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _sendQuery(action),
                  );
                }).toList(),
              ),
            ],

            if (!msg.isUser) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: _voiceService.currentSpeakingText,
                    builder: (context, speakingText, _) {
                      final isThisSpeaking = speakingText == msg.text;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _voiceService.speak(msg.text),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isThisSpeaking ? Icons.volume_up : Icons.volume_down_outlined,
                                size: 16,
                                color: isThisSpeaking
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isThisSpeaking ? 'Speaking...' : 'Speak',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isThisSpeaking ? FontWeight.bold : FontWeight.normal,
                                  color: isThisSpeaking
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
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
