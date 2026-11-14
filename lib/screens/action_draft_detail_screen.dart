import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/action_draft.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

/// Screen to view, edit, approve, copy, or mark an action draft as completed.
class ActionDraftDetailScreen extends StatefulWidget {
  final ActionDraft draft;

  const ActionDraftDetailScreen({super.key, required this.draft});

  @override
  State<ActionDraftDetailScreen> createState() =>
      _ActionDraftDetailScreenState();
}

class _ActionDraftDetailScreenState extends State<ActionDraftDetailScreen> {
  final _db = DatabaseService();
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  late DraftStatus _status;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.draft.subject ?? '');
    _bodyController = TextEditingController(text: widget.draft.body);
    _status = widget.draft.status;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _updateDraft() async {
    AppHaptics.success();
    final updated = widget.draft.copyWith(
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      status: _status,
    );
    await _db.updateActionDraft(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Draft updated.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _updateDraftQuietly() async {
    final updated = widget.draft.copyWith(
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      status: _status,
    );
    await _db.updateActionDraft(updated);
  }

  String _cleanPhoneNumber(String? contact) {
    if (contact == null) return '';
    return contact.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _launchChannel({
    required Uri uri,
    required String channelName,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        setState(() => _status = DraftStatus.sent);
        await _updateDraftQuietly();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opened $channelName & marked draft as sent!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          );
        }
      } else {
        throw Exception('Could not launch application');
      }
    } catch (e) {
      if (mounted) {
        _copyToClipboard();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open $channelName automatically. Text copied to clipboard!',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _launchWhatsApp() async {
    AppHaptics.lightImpact();
    final phone = _cleanPhoneNumber(widget.draft.recipientContact);
    final text = _bodyController.text;
    final encodedText = Uri.encodeComponent(text);
    final uri = phone.isNotEmpty
        ? Uri.parse('https://wa.me/$phone?text=$encodedText')
        : Uri.parse('https://wa.me/?text=$encodedText');
    await _launchChannel(uri: uri, channelName: 'WhatsApp');
  }

  Future<void> _launchEmail() async {
    AppHaptics.lightImpact();
    final contact = widget.draft.recipientContact;
    final email = (contact != null && contact.contains('@')) ? contact : '';
    final subject = _subjectController.text.trim();
    final body = _bodyController.text;

    final query = _encodeQueryParameters({
      if (subject.isNotEmpty) 'subject': subject,
      if (body.isNotEmpty) 'body': body,
    });

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: query.isNotEmpty ? query : null,
    );
    await _launchChannel(uri: uri, channelName: 'Email Client');
  }

  Future<void> _launchSms() async {
    AppHaptics.lightImpact();
    final phone = _cleanPhoneNumber(widget.draft.recipientContact);
    final body = _bodyController.text;
    final encodedBody = Uri.encodeComponent(body);
    final uri = Uri.parse(
      phone.isNotEmpty ? 'sms:$phone?body=$encodedBody' : 'sms:?body=$encodedBody',
    );
    await _launchChannel(uri: uri, channelName: 'SMS');
  }

  void _copyToClipboard() {
    AppHaptics.lightImpact();
    final text = _subjectController.text.isNotEmpty
        ? 'Subject: ${_subjectController.text}\n\n${_bodyController.text}'
        : _bodyController.text;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Draft copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(widget.draft.type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy text',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save changes',
            onPressed: _updateDraft,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
        children: [
          // Permission level info banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Permission Gate: Draft generated for your review. Edits remain private until explicitly dispatched.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (widget.draft.recipientName != null) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  AppAvatar(name: widget.draft.recipientName!, size: AppAvatarSize.sm),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipient: ${widget.draft.recipientName}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (widget.draft.recipientContact != null)
                          Text(
                            widget.draft.recipientContact!,
                            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                          ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: _status.label,
                    variant: _status == DraftStatus.sent
                        ? AppBadgeVariant.success
                        : (_status == DraftStatus.approved
                            ? AppBadgeVariant.neutral
                            : AppBadgeVariant.warning),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (widget.draft.type == DraftType.email) ...[
            AppTextField(
              controller: _subjectController,
              label: 'Email Subject',
              prefixIcon: Icons.subject_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          AppTextField(
            controller: _bodyController,
            label: 'Message Body',
            maxLines: 9,
            prefixIcon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Direct Communication Channels
          Text(
            'DIRECT CHANNEL DISPATCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.sm,
                  onPressed: _launchWhatsApp,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.sm,
                  onPressed: _launchEmail,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  label: 'SMS',
                  icon: Icons.sms_outlined,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.sm,
                  onPressed: _launchSms,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Status & Approval Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve Draft',
                  icon: Icons.check_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    setState(() => _status = DraftStatus.approved);
                    _updateDraft();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Copy & Mark Sent',
                  icon: Icons.send_rounded,
                  onPressed: () {
                    _copyToClipboard();
                    setState(() => _status = DraftStatus.sent);
                    _updateDraft();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
