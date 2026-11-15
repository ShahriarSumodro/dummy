import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

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
    AppHaptics.mediumImpact();
    setState(() => _isExporting = true);
    try {
      final jsonMap = await _db.exportDatabaseJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);

      await Clipboard.setData(ClipboardData(text: jsonStr));

      if (mounted) {
        AppHaptics.success();
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
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importDataJson() async {
    AppHaptics.lightImpact();
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
        AppHaptics.mediumImpact();
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        final count = await _db.restoreDatabaseJson(parsed);
        if (mounted) {
          AppHaptics.success();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully restored $count records into your database!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppHaptics.warning();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to parse backup JSON: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          );
        }
      }
    }
  }

  Future<void> _wipeAllData() async {
    AppHaptics.warning();
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Permanently Erase All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      AppHaptics.success();
      await _db.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All local database records have been erased.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Data Privacy & Security', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Privacy Banner
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      '100% Local Device Storage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Dummy. is built privacy-first. All your contacts, promises, meeting notes, and reminders reside in an SQLite database on your device. No cloud sync is active without your explicit instruction.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: 'Data Portability & Backup'),
          const SizedBox(height: AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListRow(
                  leading: const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
                  title: 'Export Complete Memory (JSON)',
                  subtitle: 'Backup all records to a portable JSON file on clipboard',
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                  onTap: _isExporting ? null : _exportDataJson,
                ),
                const Divider(height: 1),
                AppListRow(
                  leading: const Icon(Icons.upload_file_rounded, size: 20, color: AppColors.primary),
                  title: 'Restore from Backup (JSON)',
                  subtitle: 'Restore or merge records from a previous backup JSON',
                  trailing: const Icon(Icons.restore_rounded, size: 18, color: Colors.grey),
                  onTap: _importDataJson,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: 'Data Deletion & Retention'),
          const SizedBox(height: AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 22),
              title: 'Erase All Personal Data',
              subtitle: 'Permanently wipe all contacts, promises, meetings & settings',
              onTap: _wipeAllData,
            ),
          ),
        ],
      ),
    );
  }
}
