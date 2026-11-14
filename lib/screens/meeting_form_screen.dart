import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/meeting.dart';
import '../models/organization.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';

/// Screen to create or edit a Meeting, complete with AI Action Item & Decision extraction.
class MeetingFormScreen extends StatefulWidget {
  final Meeting? meeting;

  const MeetingFormScreen({super.key, this.meeting});

  @override
  State<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends State<MeetingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late final TextEditingController _summaryController;

  DateTime _meetingDate = DateTime.now();
  int? _selectedOrgId;
  final List<int> _selectedAttendeeIds = [];

  List<String> _decisions = [];
  List<String> _actionItems = [];
  List<Map<String, dynamic>> _conflicts = [];

  List<Organization> _organizations = [];
  List<Contact> _contacts = [];
  bool _loadingRelations = true;
  bool _isExtracting = false;

  bool get _isEditing => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.meeting?.title ?? '');
    _locationController = TextEditingController(
      text: widget.meeting?.location ?? '',
    );
    _notesController = TextEditingController(
      text: widget.meeting?.rawNotes ?? '',
    );
    _summaryController = TextEditingController(
      text: widget.meeting?.summary ?? '',
    );

    if (widget.meeting != null) {
      _meetingDate = widget.meeting!.meetingDate;
      _selectedOrgId = widget.meeting!.organizationId;
      _selectedAttendeeIds.addAll(widget.meeting!.attendeeContactIds);
      _decisions = List.from(widget.meeting!.decisions);
      _actionItems = List.from(widget.meeting!.actionItems);
    }

    _loadRelations();
    _checkConflicts(_meetingDate);
  }

  Future<void> _checkConflicts(DateTime date) async {
    try {
      final conflicts = await _db.checkScheduleConflicts(
        date,
        excludeMeetingId: widget.meeting?.id,
      ).timeout(const Duration(seconds: 3), onTimeout: () => []);
      if (mounted) {
        setState(() => _conflicts = conflicts);
      }
    } catch (_) {}
  }

  Future<void> _loadRelations() async {
    try {
      final orgs = await _db.getAllOrganizations().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
      final contacts = await _db.getAllContacts().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
      if (mounted) {
        setState(() {
          _organizations = orgs;
          _contacts = contacts;
        });
      }
    } catch (_) {
      // Graceful fallback on missing relations
    } finally {
      if (mounted) {
        setState(() => _loadingRelations = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_meetingDate),
      );
      setState(() {
        _meetingDate = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? _meetingDate.hour,
          time?.minute ?? _meetingDate.minute,
        );
      });
      _checkConflicts(_meetingDate);
    }
  }

  Future<void> _extractIntelligenceWithAi() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter meeting notes first.')),
      );
      return;
    }

    setState(() => _isExtracting = true);

    try {
      final isMock = await AiServiceFactory.isMockMode();
      final apiKey = await AiServiceFactory.getApiKey();
      final provider = await AiServiceFactory.getProvider();

      if (!isMock && apiKey != null && apiKey.isNotEmpty) {
        if (apiKey.startsWith('gsk_') || provider == AiProvider.groq) {
          await _extractWithGroq(notes, apiKey);
        } else {
          await _extractWithGemini(notes, apiKey);
        }
      } else {
        await _extractWithMockRules(notes);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Decisions and action items extracted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Extraction error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _extractWithGemini(String notes, String apiKey) async {
    const model = 'gemini-2.0-flash';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final prompt =
        '''
Analyze these business meeting notes:
"$notes"

Return strictly valid JSON:
{
  "summary": "2-sentence executive summary of the meeting",
  "decisions": ["Key decision 1", "Key decision 2"],
  "action_items": ["Action item with assignee 1", "Action item with assignee 2"]
}
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.1,
        },
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final json = jsonDecode(text) as Map<String, dynamic>;

    setState(() {
      _summaryController.text = json['summary'] as String? ?? '';
      _decisions = List<String>.from(json['decisions'] ?? []);
      _actionItems = List<String>.from(json['action_items'] ?? []);
    });
  }

  Future<void> _extractWithGroq(String notes, String apiKey) async {
    const candidateModels = [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'llama-3.1-70b-versatile',
      'llama3-70b-8192',
      'llama3-8b-8192',
      'mixtral-8x7b-32768',
      'qwen-2.5-32b',
    ];
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final prompt =
        '''
Analyze these business meeting notes:
"$notes"

Return strictly valid JSON:
{
  "summary": "2-sentence executive summary of the meeting",
  "decisions": ["Key decision 1", "Key decision 2"],
  "action_items": ["Action item with assignee 1", "Action item with assignee 2"]
}
''';

    for (final model in candidateModels) {
      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0.1,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final rawJson = choices[0]['message']['content'] as String;
            final json = jsonDecode(rawJson) as Map<String, dynamic>;

            setState(() {
              _summaryController.text = json['summary'] as String? ?? '';
              _decisions = List<String>.from(json['decisions'] ?? []);
              _actionItems = List<String>.from(json['action_items'] ?? []);
            });
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }

    await _extractWithMockRules(notes);
  }

  Future<void> _extractWithMockRules(String notes) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final lines = notes.split('\n').where((l) => l.trim().isNotEmpty).toList();

    final decisions = <String>[];
    final actions = <String>[];

    for (final l in lines) {
      final lower = l.toLowerCase();
      if (lower.contains('agree') ||
          lower.contains('decided') ||
          lower.contains('approved')) {
        decisions.add(l.replaceAll(RegExp(r'^[-*•\d.]+\s*'), '').trim());
      } else if (lower.contains('will') ||
          lower.contains('need to') ||
          lower.contains('todo') ||
          lower.contains('action')) {
        actions.add(l.replaceAll(RegExp(r'^[-*•\d.]+\s*'), '').trim());
      }
    }

    if (decisions.isEmpty && lines.isNotEmpty) {
      decisions.add('Agreed on next steps as outlined in notes.');
    }
    if (actions.isEmpty && lines.isNotEmpty) {
      actions.add('Follow up on items discussed in meeting.');
    }

    setState(() {
      _summaryController.text = lines.isNotEmpty
          ? 'Meeting regarding ${_titleController.text.isNotEmpty ? _titleController.text : "key topics"}. Key points discussed and next actions aligned.'
          : '';
      _decisions = decisions;
      _actionItems = actions;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final meeting = Meeting(
      id: widget.meeting?.id,
      title: _titleController.text.trim(),
      meetingDate: _meetingDate,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      rawNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      summary: _summaryController.text.trim().isEmpty
          ? null
          : _summaryController.text.trim(),
      decisions: _decisions,
      actionItems: _actionItems,
      organizationId: _selectedOrgId,
      attendeeContactIds: _selectedAttendeeIds,
      isProcessed: _decisions.isNotEmpty || _actionItems.isNotEmpty,
    );

    Navigator.pop(context, meeting);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Meeting' : 'New Meeting'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: _loadingRelations
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Meeting Title *',
                      hintText: 'e.g. Q3 Partnership Review',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date & Time'),
                    subtitle: Text(dateFormat.format(_meetingDate)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: _pickDate,
                  ),
                  if (_conflicts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade700,
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Schedule Overlap Detected (${_conflicts.length})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ..._conflicts.map((c) {
                            final kind = (c['kind'] as String? ?? 'event')
                                .toUpperCase();
                            final title = c['title'] as String? ?? 'Untitled';
                            final date =
                                c['date'] as DateTime? ?? DateTime.now();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• $kind: "$title" at ${DateFormat('h:mm a').format(date)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location / Platform',
                      hintText: 'e.g. Google Meet, In-person at HQ, Zoom',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Organization Dropdown
                  DropdownButtonFormField<int>(
                    key: ValueKey(_selectedOrgId),
                    initialValue: _selectedOrgId,
                    decoration: const InputDecoration(
                      labelText: 'Related Company (optional)',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._organizations.map(
                        (org) => DropdownMenuItem(
                          value: org.id,
                          child: Text(org.name),
                        ),
                      ),
                    ],
                    onChanged: (id) => setState(() => _selectedOrgId = id),
                  ),
                  const SizedBox(height: 16),

                  // Attendees Selector
                  if (_contacts.isNotEmpty) ...[
                    Text(
                      'Select Attendees:',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _contacts.map((c) {
                        final isSelected = _selectedAttendeeIds.contains(c.id);
                        return FilterChip(
                          label: Text(c.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAttendeeIds.add(c.id!);
                              } else {
                                _selectedAttendeeIds.remove(c.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Raw Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Meeting Notes / Transcript',
                      hintText:
                          'Type key talking points, who attended, promises made, and decisions agreed upon...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI Extract Button
                  FilledButton.tonalIcon(
                    onPressed: _isExtracting
                        ? null
                        : _extractIntelligenceWithAi,
                    icon: _isExtracting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isExtracting
                          ? 'Analyzing Meeting...'
                          : 'Extract Decisions & Action Items (AI)',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary
                  if (_summaryController.text.isNotEmpty ||
                      _decisions.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text(
                      'AI Intelligence Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _summaryController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Executive Summary',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_decisions.isNotEmpty) ...[
                      Text(
                        'Decisions Agreed:',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      ..._decisions.map(
                        (d) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          title: Text(d),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_actionItems.isNotEmpty) ...[
                      Text(
                        'Action Items Extracted:',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      ..._actionItems.map(
                        (a) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.task_alt,
                            color: Colors.blue,
                            size: 20,
                          ),
                          title: Text(a),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
