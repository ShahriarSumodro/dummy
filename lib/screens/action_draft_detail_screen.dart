import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/action_draft.dart';
import '../services/database_service.dart';

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
    _subjectController =
        TextEditingController(text: widget.draft.subject ?? '');
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
    final updated = widget.draft.copyWith(
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      status: _status,
    );
    await _db.updateActionDraft(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft updated.')),
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
              backgroundColor: Colors.green.shade800,
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
    final phone = _cleanPhoneNumber(widget.draft.recipientContact);
    final text = _bodyController.text;
    final encodedText = Uri.encodeComponent(text);
    final uri = phone.isNotEmpty
        ? Uri.parse('https://wa.me/$phone?text=$encodedText')
        : Uri.parse('https://wa.me/?text=$encodedText');
    await _launchChannel(uri: uri, channelName: 'WhatsApp');
  }

  Future<void> _launchEmail() async {
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
    final phone = _cleanPhoneNumber(widget.draft.recipientContact);
    final body = _bodyController.text;
    final encodedBody = Uri.encodeComponent(body);
    final uri = Uri.parse(
      phone.isNotEmpty ? 'sms:$phone?body=$encodedBody' : 'sms:?body=$encodedBody',
    );
    await _launchChannel(uri: uri, channelName: 'SMS');
  }

  void _copyToClipboard() {
    final text = _subjectController.text.isNotEmpty
        ? 'Subject: ${_subjectController.text}\n\n${_bodyController.text}'
        : _bodyController.text;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.draft.type.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy text',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save changes',
            onPressed: _updateDraft,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permission level info chip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Permission Gate: Generated as draft. Review and edit before sending.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (widget.draft.recipientName != null) ...[
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text('Recipient: ${widget.draft.recipientName}'),
              subtitle: widget.draft.recipientContact != null
                  ? Text(widget.draft.recipientContact!)
                  : null,
            ),
            const Divider(height: 24),
          ],

          if (widget.draft.type == DraftType.email) ...[
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _bodyController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Message Body',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Direct Communication Channels
          Text(
            'Direct Channel Launchers',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green.shade800,
                  ),
                  onPressed: _launchWhatsApp,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                    foregroundColor: Colors.blue.shade800,
                  ),
                  onPressed: _launchEmail,
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Email'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                    foregroundColor: Colors.deepPurple.shade800,
                  ),
                  onPressed: _launchSms,
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('SMS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status & Approval Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _status = DraftStatus.approved);
                    _updateDraft();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Approve Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    _copyToClipboard();
                    setState(() => _status = DraftStatus.sent);
                    _updateDraft();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Copy & Mark Sent'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
