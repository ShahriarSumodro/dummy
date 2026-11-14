import 'package:flutter/material.dart';
import '../models/ai_extraction_result.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';

/// Screen that prompts the executive user to identify and disambiguate
/// multiple conversation participants detected in a 3-4 person discussion.
///
/// Example:
/// Transforms "Person A promised to deliver the design"
/// into "Raju (Lead Designer at Apex Corp) promised to deliver the design".
class MultiParticipantResolutionScreen extends StatefulWidget {
  final AiExtractionResult extractionResult;
  final VoidCallback onResolved;

  const MultiParticipantResolutionScreen({
    super.key,
    required this.extractionResult,
    required this.onResolved,
  });

  @override
  State<MultiParticipantResolutionScreen> createState() =>
      _MultiParticipantResolutionScreenState();
}

class _ParticipantEditData {
  final ExtractedContact originalContact;
  final TextEditingController nameController;
  final TextEditingController roleController;
  final TextEditingController relationshipController;
  final TextEditingController companyController;

  _ParticipantEditData({
    required this.originalContact,
    required String initialName,
    String? initialRole,
    String? initialRelationship,
    String? initialCompany,
  })  : nameController = TextEditingController(text: initialName),
        roleController = TextEditingController(text: initialRole ?? ''),
        relationshipController =
            TextEditingController(text: initialRelationship ?? ''),
        companyController = TextEditingController(text: initialCompany ?? '');

  void dispose() {
    nameController.dispose();
    roleController.dispose();
    relationshipController.dispose();
    companyController.dispose();
  }
}

class _MultiParticipantResolutionScreenState
    extends State<MultiParticipantResolutionScreen> {
  final _db = DatabaseService();
  final List<_ParticipantEditData> _editList = [];
  List<Contact> _knownContacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKnownContacts();
  }

  Future<void> _loadKnownContacts() async {
    final contacts = await _db.getAllContacts();
    _knownContacts = contacts;

    final unresolved = widget.extractionResult.unresolvedParticipants;
    for (final p in unresolved) {
      _editList.add(
        _ParticipantEditData(
          originalContact: p,
          initialName: p.name.startsWith('Person ') || p.name.startsWith('Speaker ')
              ? ''
              : p.name,
          initialRole: p.role,
          initialRelationship: p.relationship,
          initialCompany: p.company,
        ),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }

    // Dynamic voice announcement from assistant matching actual detected participants
    try {
      final count = _editList.length;
      if (count > 0) {
        final tags = _editList
            .map((e) => e.originalContact.placeholderTag ?? e.originalContact.name)
            .toList();
        String tagListStr;
        if (tags.length == 1) {
          tagListStr = tags.first;
        } else if (tags.length == 2) {
          tagListStr = '${tags[0]} and ${tags[1]}';
        } else {
          tagListStr = '${tags.sublist(0, tags.length - 1).join(', ')}, and ${tags.last}';
        }

        final voicePrompt = count == 1
            ? 'I detected $tagListStr in this discussion. Who is that person and what do they do? Tell me, and I will personalize your commitments.'
            : 'I detected $count participants in this discussion: $tagListStr. Tell me who they are and what they do, and I will update your appointments.';
        VoiceService().speak(voicePrompt);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final e in _editList) {
      e.dispose();
    }
    super.dispose();
  }

  void _applyResolutions() {
    for (final item in _editList) {
      final enteredName = item.nameController.text.trim();
      final finalName = enteredName.isNotEmpty
          ? enteredName
          : item.originalContact.name;

      widget.extractionResult.renameParticipant(
        item.originalContact.name,
        finalName,
        role: item.roleController.text.trim().isNotEmpty
            ? item.roleController.text.trim()
            : null,
        company: item.companyController.text.trim().isNotEmpty
            ? item.companyController.text.trim()
            : null,
        relationship: item.relationshipController.text.trim().isNotEmpty
            ? item.relationshipController.text.trim()
            : null,
      );
    }

    // Voice confirmation back
    final resolvedNames = _editList
        .map((e) => e.nameController.text.trim())
        .where((n) => n.isNotEmpty)
        .join(' and ');

    if (resolvedNames.isNotEmpty) {
      VoiceService().speak(
        'Got it! I linked $resolvedNames to your appointments and commitments.',
      );
    }

    widget.onResolved();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identify Discussion Participants'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Executive Assistant Context Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        radius: 18,
                        child: const Icon(Icons.people_outline, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multi-Party Conversation Disentangled',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RemembrAI detected ${_editList.length} distinct people in this discussion. Tell me their names and roles, and I will personalize all your commitments.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Participant Cards
                ..._editList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final tag = item.originalContact.placeholderTag ??
                      'Person ${String.fromCharCode(65 + idx)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: theme.colorScheme.secondaryContainer,
                              ),
                              const Spacer(),
                              Text(
                                'Participant #${idx + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),

                          if (item.originalContact.detectedContext != null &&
                              item.originalContact.detectedContext!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 15,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Context in meeting: "${item.originalContact.detectedContext}"',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Name input with known contact suggestions
                          Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return _knownContacts
                                  .where((c) => c.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ))
                                  .map((c) => c.name);
                            },
                            onSelected: (selection) {
                              item.nameController.text = selection;
                              final match = _knownContacts.firstWhere(
                                (c) => c.name == selection,
                              );
                              if (match.role != null) {
                                item.roleController.text = match.role!;
                              }
                              if (match.company != null) {
                                item.companyController.text = match.company!;
                              }
                              setState(() {});
                            },
                            fieldViewBuilder: (
                              context,
                              controller,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              // Sync controllers
                              if (controller.text.isEmpty &&
                                  item.nameController.text.isNotEmpty) {
                                controller.text = item.nameController.text;
                              }
                              controller.addListener(() {
                                item.nameController.text = controller.text;
                              });

                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Who was $tag? (Name)',
                                  hintText: 'e.g. Raju, Tanvir, Sarah...',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: const OutlineInputBorder(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Role / What he does
                          TextField(
                            controller: item.roleController,
                            decoration: InputDecoration(
                              labelText: 'What does this person do? (Role)',
                              hintText: 'e.g. Lead Designer, Legal Advisor, Investor',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Relationship to you
                          TextField(
                            controller: item.relationshipController,
                            decoration: const InputDecoration(
                              labelText: 'Who is this person to you? (Relationship)',
                              hintText: 'e.g. Client, Colleague, Vendor, Founder',
                              prefixIcon: Icon(Icons.handshake_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Company
                          TextField(
                            controller: item.companyController,
                            decoration: const InputDecoration(
                              labelText: 'Company / Organization (optional)',
                              hintText: 'e.g. Apex Corp, TechVentures',
                              prefixIcon: Icon(Icons.business_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyResolutions,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm & Link to My Commitments'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
