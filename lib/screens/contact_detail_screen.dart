import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../models/interaction.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'contact_form_screen.dart';
import 'commitment_form_screen.dart';
import 'commitment_detail_screen.dart';
import 'briefing_screen.dart';

/// Detail screen for a single contact.
/// Executive view showing contact metadata, touchpoint health, quick communication
/// channels, linked commitments, and full interaction audit trail.
class ContactDetailScreen extends StatefulWidget {
  final int contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _db = DatabaseService();
  Contact? _contact;
  List<Commitment> _commitments = [];
  List<Interaction> _interactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final contact = await _db.getContact(widget.contactId);
    final commitments = await _db.getCommitmentsForContact(widget.contactId);
    final interactions = await _db.getInteractions(contactId: widget.contactId, limit: 40);
    if (mounted) {
      setState(() {
        _contact = contact;
        _commitments = commitments;
        _interactions = interactions;
        _loading = false;
      });
    }
  }

  Future<void> _logInteractionDialog() async {
    if (_contact == null) return;
    AppHaptics.lightImpact();
    InteractionType selectedType = InteractionType.call;
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    await AppBottomSheet.show<void>(
      context: context,
      title: 'Log Activity with ${_contact!.name}',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTIVITY TYPE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                _buildInteractionTypeChip(InteractionType.call, 'Phone Call', Icons.phone_in_talk_rounded, selectedType, (t) {
                  setSheetState(() => selectedType = t);
                }),
                _buildInteractionTypeChip(InteractionType.meeting, 'Meeting', Icons.groups_rounded, selectedType, (t) {
                  setSheetState(() => selectedType = t);
                }),
                _buildInteractionTypeChip(InteractionType.note, 'Memo / Note', Icons.notes_rounded, selectedType, (t) {
                  setSheetState(() => selectedType = t);
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: titleController,
              label: 'Summary / Title *',
              hintText: 'e.g. Discussed Q3 roadmap & pricing',
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: notesController,
              label: 'Details / Key Points (optional)',
              hintText: 'Any specifics to remember...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save Activity',
              icon: Icons.check_rounded,
              fullWidth: true,
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                AppHaptics.success();
                await _db.insertInteraction(Interaction(
                  type: selectedType,
                  title: titleController.text.trim(),
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                  contactId: widget.contactId,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionTypeChip(
    InteractionType type,
    String label,
    IconData icon,
    InteractionType selected,
    ValueChanged<InteractionType> onSelect,
  ) {
    final isSelected = type == selected;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.muted(context)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.foreground(context),
      ),
      onSelected: (_) => onSelect(type),
    );
  }

  Future<void> _editContact() async {
    if (_contact == null) return;
    AppHaptics.lightImpact();
    final result = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(contact: _contact),
      ),
    );

    if (result != null) {
      await _db.updateContact(result);
      _loadData();
    }
  }

  Future<void> _deleteContact() async {
    AppHaptics.warning();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Delete "${_contact?.name}"? Linked promises and interactions will remain in your archive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      AppHaptics.success();
      await _db.deleteContact(widget.contactId);
      if (mounted) {
        Navigator.pop(context, true); // true = was deleted
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    final url = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            AppSkeleton(height: 140),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 80),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 180),
          ],
        ),
      );
    }

    if (_contact == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(),
        body: const Center(
          child: AppEmptyState(
            icon: Icons.person_off_rounded,
            title: 'Contact not found',
            message: 'This person record may have been merged or removed.',
          ),
        ),
      );
    }

    final contact = _contact!;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: 'View Executive Dossier',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BriefingScreen(initialContact: contact),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Contact',
            onPressed: _editContact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Contact',
            onPressed: _deleteContact,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
        children: [
          // ── Contact Header Card ──
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                AppAvatar(
                  name: contact.name,
                  size: AppAvatarSize.xl,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (contact.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.muted(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // Quick Action Shortcuts Strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (contact.phone != null && contact.phone!.isNotEmpty) ...[
                      _buildQuickActionBtn(
                        icon: Icons.phone_rounded,
                        label: 'Call',
                        onTap: () => _launchCall(contact.phone!),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildQuickActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'WhatsApp',
                        onTap: () => _launchWhatsApp(contact.phone!),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (contact.email != null && contact.email!.isNotEmpty) ...[
                      _buildQuickActionBtn(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        onTap: () => _launchEmail(contact.email!),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    _buildQuickActionBtn(
                      icon: Icons.auto_stories_rounded,
                      label: 'Dossier',
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BriefingScreen(initialContact: contact)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Metadata & Touchpoint Health ──
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOUCHPOINT RADAR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.muted(context),
                      ),
                    ),
                    AppBadge(
                      label: 'Every ${contact.cadenceDays} days',
                      variant: AppBadgeVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: contact.isDueForTouchpoint ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        contact.isDueForTouchpoint
                            ? 'Cadence overdue · Reconnect recommended'
                            : 'Cadence healthy · Touchpoints up to date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: contact.isDueForTouchpoint ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                if (contact.phone != null && contact.phone!.isNotEmpty)
                  _buildDetailRow(Icons.phone_outlined, 'Phone', contact.phone!),
                if (contact.email != null && contact.email!.isNotEmpty)
                  _buildDetailRow(Icons.email_outlined, 'Email', contact.email!),
                if (contact.company != null && contact.company!.isNotEmpty)
                  _buildDetailRow(Icons.business_outlined, 'Company', contact.company!),
                if (contact.role != null && contact.role!.isNotEmpty)
                  _buildDetailRow(Icons.badge_outlined, 'Role', contact.role!),
                if (contact.notes != null && contact.notes!.isNotEmpty)
                  _buildDetailRow(Icons.notes_rounded, 'Notes', contact.notes!),
                _buildDetailRow(Icons.calendar_today_rounded, 'Added', dateFormat.format(contact.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Commitments Section ──
          AppSectionHeader(
            title: 'Commitments',
            count: _commitments.length,
            actionLabel: '+ Add Promise',
            onAction: () async {
              AppHaptics.lightImpact();
              final res = await Navigator.push<Commitment>(
                context,
                MaterialPageRoute(
                  builder: (_) => CommitmentFormScreen(
                    preselectedContact: _contact,
                  ),
                ),
              );
              if (res != null) {
                await _db.insertCommitment(res);
                _loadData();
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_commitments.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No commitments linked to ${_contact!.name} yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted(context),
                ),
              ),
            )
          else
            ..._commitments.map((c) {
              final isCompleted = c.status == CommitmentStatus.completed;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppListRow(
                  leading: Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: c.isOverdue
                        ? AppColors.error
                        : (isCompleted ? AppColors.success : AppColors.primary),
                    size: 20,
                  ),
                  title: c.title,
                  subtitle: '${c.type.label}${c.dueDate != null ? ' · Due ${dateFormat.format(c.dueDate!)}' : ''}',
                  badge: c.isOverdue
                      ? const AppBadge(label: 'Overdue', variant: AppBadgeVariant.error)
                      : (isCompleted
                          ? const AppBadge(label: 'Done', variant: AppBadgeVariant.success)
                          : null),
                  onTap: () async {
                    AppHaptics.lightImpact();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommitmentDetailScreen(
                          commitmentId: c.id!,
                        ),
                      ),
                    );
                    _loadData();
                  },
                ),
              );
            }),

          const SizedBox(height: AppSpacing.lg),

          // ── Activity & Timeline Section ──
          AppSectionHeader(
            title: 'Activity & Timeline',
            count: _interactions.length,
            actionLabel: '+ Log Activity',
            onAction: _logInteractionDialog,
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_interactions.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No activity logged with ${_contact!.name} yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted(context),
                ),
              ),
            )
          else
            ..._interactions.map((i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppListRow(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.subtle(context),
                    child: Icon(
                      _getInteractionIcon(i.type),
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  title: i.title,
                  subtitle: [
                    i.type.label,
                    if (i.notes != null && i.notes!.isNotEmpty) i.notes!,
                  ].join(' · '),
                  trailing: Text(
                    DateFormat('MMM d, h:mm a').format(i.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.subtle(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border(context), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.muted(context)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getInteractionIcon(InteractionType type) {
    switch (type) {
      case InteractionType.call:
        return Icons.phone_in_talk_rounded;
      case InteractionType.meeting:
        return Icons.groups_rounded;
      case InteractionType.note:
        return Icons.notes_rounded;
      case InteractionType.commitmentCreated:
        return Icons.add_task_rounded;
      case InteractionType.commitmentCompleted:
        return Icons.task_alt_rounded;
      case InteractionType.draftSent:
        return Icons.send_rounded;
      case InteractionType.reminderFired:
        return Icons.alarm_on_rounded;
    }
  }
}
