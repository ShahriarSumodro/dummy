import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../models/action_draft.dart';
import '../services/database_service.dart';
import '../services/action_draft_service.dart';
import '../theme/design_tokens.dart';
import '../theme/app_haptics.dart';
import '../widgets/widgets.dart';
import 'commitment_form_screen.dart';
import 'action_draft_detail_screen.dart';
import 'contact_detail_screen.dart';

/// Redesigned Commitment Detail Screen.
/// Clean visual hierarchy, semantic status badges, and strict user confirmation gates.
class CommitmentDetailScreen extends StatefulWidget {
  final int commitmentId;

  const CommitmentDetailScreen({super.key, required this.commitmentId});

  @override
  State<CommitmentDetailScreen> createState() => _CommitmentDetailScreenState();
}

class _CommitmentDetailScreenState extends State<CommitmentDetailScreen> {
  final _db = DatabaseService();
  Commitment? _commitment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final all = await _db.getAllCommitments();
    final match = all.cast<Commitment?>().firstWhere(
          (c) => c!.id == widget.commitmentId,
          orElse: () => null,
        );
    if (mounted) {
      setState(() {
        _commitment = match;
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    if (_commitment == null) return;
    AppHaptics.lightImpact();
    final result = await Navigator.push<Commitment>(
      context,
      MaterialPageRoute(
        builder: (_) => CommitmentFormScreen(commitment: _commitment),
      ),
    );
    if (result != null) {
      await _db.updateCommitment(result);
      _loadData();
    }
  }

  Future<void> _toggleComplete() async {
    if (_commitment == null) return;
    final isCompleting = _commitment!.status != CommitmentStatus.completed;
    if (isCompleting) {
      AppHaptics.success();
    } else {
      AppHaptics.lightImpact();
    }
    final updated = _commitment!.copyWith(
      status: isCompleting
          ? CommitmentStatus.completed
          : CommitmentStatus.pending,
      completedAt: isCompleting ? DateTime.now() : null,
    );
    await _db.updateCommitment(updated);
    _loadData();
  }

  Future<void> _delete() async {
    AppHaptics.warning();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
          title: const Text('Delete Commitment'),
          content: Text('Permanently remove "${_commitment?.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.semanticRed,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _db.deleteCommitment(widget.commitmentId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _prepareFollowUpDraft() async {
    if (_commitment == null) return;
    AppHaptics.mediumImpact();

    final draftType = await AppBottomSheet.show<DraftType>(
      context: context,
      title: 'Select Message Channel',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenSide,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppListRow(
              leading: const Icon(Icons.email_outlined),
              title: 'Email Draft',
              subtitle: 'Prepared executive email ready for review',
              onTap: () => Navigator.pop(ctx, DraftType.email),
            ),
            AppListRow(
              leading: const Icon(Icons.chat_bubble_outline),
              title: 'WhatsApp Message',
              subtitle: 'Direct WhatsApp follow-up link',
              onTap: () => Navigator.pop(ctx, DraftType.whatsapp),
            ),
            AppListRow(
              leading: const Icon(Icons.sms_outlined),
              title: 'SMS Message',
              subtitle: 'Cellular text message draft',
              showDivider: false,
              onTap: () => Navigator.pop(ctx, DraftType.sms),
            ),
          ],
        ),
      ),
    );

    if (draftType == null || !mounted) return;

    final contact = _commitment!.contactId != null
        ? await _db.getContact(_commitment!.contactId!)
        : null;

    final draft = await ActionDraftService().generateDraftForCommitment(
      commitment: _commitment!,
      contact: contact,
      type: draftType,
    );

    final id = await _db.insertActionDraft(draft);
    final savedDraft = draft.copyWith(id: id);

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActionDraftDetailScreen(draft: savedDraft),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenSide),
          children: [
            AppSkeleton.card(height: 120),
            const SizedBox(height: AppSpacing.md),
            AppSkeleton.card(height: 80),
          ],
        ),
      );
    }

    if (_commitment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Commitment Not Found',
          description: 'This commitment may have been deleted or moved.',
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = _commitment!;
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');
    final isComplete = c.status == CommitmentStatus.completed;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    AppBadge badge;
    if (c.isOverdue && !isComplete) {
      badge = AppBadge.overdue();
    } else if (isComplete) {
      badge = AppBadge.done();
    } else if (c.type == CommitmentType.promiseMade) {
      badge = const AppBadge(
        label: 'Promise Made',
        variant: AppBadgeVariant.accent,
      );
    } else if (c.type == CommitmentType.promiseReceived) {
      badge = const AppBadge(
        label: 'Promise Received',
        variant: AppBadgeVariant.neutral,
      );
    } else {
      badge = const AppBadge(
        label: 'Task',
        variant: AppBadgeVariant.neutral,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commitment Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Commitment',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Commitment',
            onPressed: _delete,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenSide),
        children: [
          // Header Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    badge,
                    Text(
                      c.type.label,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: AppTypography.captionSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  c.title,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: AppTypography.titleSize,
                    fontWeight: FontWeight.w600,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                    letterSpacing: -0.3,
                  ),
                ),
                if (c.description != null && c.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    c.description!,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: AppTypography.bodySize,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Linked Contact Card
          if (c.contactName != null) ...[
            AppCard(
              onTap: c.contactId != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ContactDetailScreen(contactId: c.contactId!),
                        ),
                      )
                  : null,
              child: Row(
                children: [
                  AppAvatar(name: c.contactName!, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Associated Contact',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: AppTypography.captionSize,
                          ),
                        ),
                        Text(
                          c.contactName!,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.contactId != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: secondaryText,
                      size: 20,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Deadline & Timestamps Card
          AppCard(
            isSubtle: true,
            child: Column(
              children: [
                if (c.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: c.isOverdue && !isComplete
                            ? (isDark
                                ? AppColors.semanticRedDark
                                : AppColors.semanticRed)
                            : secondaryText,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Due Date',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: AppTypography.secondarySize,
                          ),
                        ),
                      ),
                      Text(
                        dateFormat.format(c.dueDate!),
                        style: TextStyle(
                          color: c.isOverdue && !isComplete
                              ? (isDark
                                  ? AppColors.semanticRedDark
                                  : AppColors.semanticRed)
                              : primaryText,
                          fontSize: AppTypography.secondarySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                if (c.completedAt != null) ...[
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.semanticGreenDark
                            : AppColors.semanticGreen,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: AppTypography.secondarySize,
                          ),
                        ),
                      ),
                      Text(
                        dateFormat.format(c.completedAt!),
                        style: TextStyle(
                          color: isDark
                              ? AppColors.semanticGreenDark
                              : AppColors.semanticGreen,
                          fontSize: AppTypography.secondarySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Primary Actions
          AppButton(
            label: isComplete ? 'Reopen as Pending' : 'Mark as Completed',
            icon: isComplete
                ? Icons.undo_rounded
                : Icons.check_circle_outline_rounded,
            variant: isComplete
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            size: AppButtonSize.large,
            isFullWidth: true,
            onPressed: _toggleComplete,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Prepare Follow-Up Draft (AI)',
            icon: Icons.edit_note_rounded,
            variant: AppButtonVariant.subtle,
            size: AppButtonSize.large,
            isFullWidth: true,
            onPressed: _prepareFollowUpDraft,
          ),
        ],
      ),
    );
  }
}
