import 'package:flutter/material.dart';
import '../models/ai_extraction_result.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

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
    AppHaptics.success();
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
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Disentangle Participants', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
              children: [
                // Executive Assistant Context Banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Multi-Party Conversation Disentangled',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'RemembrAI detected ${_editList.length} distinct people in this discussion. Tell me who they are and what they do to personalize your commitments.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Participant Cards
                ..._editList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final tag = item.originalContact.placeholderTag ??
                      'Person ${String.fromCharCode(65 + idx)}';

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppBadge(
                              label: tag,
                              variant: AppBadgeVariant.neutral,
                            ),
                            const Spacer(),
                            Text(
                              'Participant #${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted(context),
                              ),
                            ),
                          ],
                        ),

                        if (item.originalContact.detectedContext != null &&
                            item.originalContact.detectedContext!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.subtle(context),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.muted(context)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Context in meeting: "${item.originalContact.detectedContext}"',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.muted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),

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
                            AppHaptics.lightImpact();
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

                            return AppTextField(
                              controller: controller,
                              label: 'Who was $tag? (Real Name) *',
                              hintText: 'e.g. Raju, Tanvir, Sarah...',
                              prefixIcon: Icons.person_outline_rounded,
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Role / What he does
                        AppTextField(
                          controller: item.roleController,
                          label: 'Role / What they do',
                          hintText: 'e.g. Lead Designer, Legal Advisor, Investor',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Relationship to you
                        AppTextField(
                          controller: item.relationshipController,
                          label: 'Relationship to you',
                          hintText: 'e.g. Client, Colleague, Vendor, Founder',
                          prefixIcon: Icons.handshake_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Company
                        AppTextField(
                          controller: item.companyController,
                          label: 'Company / Organization (optional)',
                          hintText: 'e.g. Apex Corp, TechVentures',
                          prefixIcon: Icons.business_outlined,
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Confirm & Link to My Commitments',
                  icon: Icons.check_circle_rounded,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  onPressed: _applyResolutions,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}
