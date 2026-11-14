import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';

/// Data Privacy, Security, Export, and Deletion screen.
class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  final _db = DatabaseService();
  bool _isExporting = false;

  Future<void> _exportDataJson() async {
    setState(() => _isExporting = true);
    try {
      final jsonMap = await _db.exportDatabaseJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);

      await Clipboard.setData(ClipboardData(text: jsonStr));

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Backup Exported'),
            content: Text(
              'Your complete personal business memory database has been compiled into JSON and copied to your clipboard (${jsonStr.length} bytes).\n\nYou can paste and archive it safely.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importDataJson() async {
    final controller = TextEditingController();
    final jsonStr = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from Backup (JSON)'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste your exported JSON database content here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (jsonStr != null && jsonStr.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        final count = await _db.restoreDatabaseJson(parsed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully restored $count records into your database!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to parse backup JSON: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _wipeAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Delete All Memory Data?'),
        content: const Text(
          'This will permanently delete ALL contacts, commitments, reminders, meetings, and drafts from your device.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Permanently Erase All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _db.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All local database records have been erased.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Data Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '100% Local Device Storage',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RemembrAI is designed privacy-first. All your contacts, promises, meeting notes, and reminders are stored in an encrypted SQLite database on your device. No cloud sync is active without your explicit instruction.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('Data Portability', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Complete Memory (JSON)'),
            subtitle: const Text('Backup all records to a portable JSON file'),
            trailing: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy),
            onTap: _isExporting ? null : _exportDataJson,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Restore from Backup (JSON)'),
            subtitle: const Text('Restore or merge records from a backup JSON'),
            trailing: const Icon(Icons.restore),
            onTap: _importDataJson,
          ),
          const Divider(height: 32),

          Text('Data Deletion & Retention', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Erase All Personal Data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'Permanently delete all records from this phone',
            ),
            onTap: _wipeAllData,
          ),
        ],
      ),
    );
  }
}
