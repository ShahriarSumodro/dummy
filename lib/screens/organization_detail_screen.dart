import 'package:flutter/material.dart';
import '../models/organization.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'organization_form_screen.dart';
import 'contact_detail_screen.dart';
import 'commitment_detail_screen.dart';

/// Detail screen for an Organization / Company showing linked contacts and commitments.
class OrganizationDetailScreen extends StatefulWidget {
  final int organizationId;

  const OrganizationDetailScreen({super.key, required this.organizationId});

  @override
  State<OrganizationDetailScreen> createState() =>
      _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState extends State<OrganizationDetailScreen> {
  final _db = DatabaseService();
  Organization? _org;
  List<Contact> _contacts = [];
  List<Commitment> _commitments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final org = await _db.getOrganization(widget.organizationId);
    if (org != null) {
      final allContacts = await _db.getAllContacts();
      final relatedContacts = allContacts
          .where((c) =>
              c.company?.toLowerCase() == org.name.toLowerCase())
          .toList();

      final allCommitments = await _db.getAllCommitments();
      final contactIds = relatedContacts.map((c) => c.id).toSet();
      final relatedCommitments = allCommitments
          .where((cm) => cm.contactId != null && contactIds.contains(cm.contactId))
          .toList();

      if (mounted) {
        setState(() {
          _org = org;
          _contacts = relatedContacts;
          _commitments = relatedCommitments;
          _loading = false;
        });
      }
    }
  }

  Future<void> _editOrg() async {
    if (_org == null) return;
    AppHaptics.lightImpact();
    final updated = await Navigator.push<Organization>(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationFormScreen(organization: _org),
      ),
    );
    if (updated != null) {
      await _db.updateOrganization(updated);
      _loadData();
    }
  }

  Future<void> _deleteOrg() async {
    AppHaptics.warning();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text('Delete "${_org?.name}"? Linked contacts and promises will remain.'),
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
      await _db.deleteOrganization(widget.organizationId);
      if (mounted) {
        Navigator.pop(context, true);
      }
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
            AppSkeleton(height: 120),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 140),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 140),
          ],
        ),
      );
    }

    if (_org == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(),
        body: const Center(
          child: AppEmptyState(
            icon: Icons.business_outlined,
            title: 'Company not found',
            message: 'This company record may have been removed.',
          ),
        ),
      );
    }

    final org = _org!;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Company',
            onPressed: _editOrg,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Company',
            onPressed: _deleteOrg,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
        children: [
          // ── Header Card ──
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                AppAvatar(name: org.name, size: AppAvatarSize.xl),
                const SizedBox(height: AppSpacing.md),
                Text(
                  org.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (org.industry != null && org.industry!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppBadge(
                    label: org.industry!,
                    variant: AppBadgeVariant.neutral,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Details Card ──
          if ((org.website != null && org.website!.isNotEmpty) ||
              (org.address != null && org.address!.isNotEmpty) ||
              (org.notes != null && org.notes!.isNotEmpty)) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPANY DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (org.website != null && org.website!.isNotEmpty)
                    _buildRow(Icons.language_rounded, 'Website', org.website!),
                  if (org.address != null && org.address!.isNotEmpty)
                    _buildRow(Icons.location_on_outlined, 'Address', org.address!),
                  if (org.notes != null && org.notes!.isNotEmpty)
                    _buildRow(Icons.notes_rounded, 'Notes', org.notes!),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Associated Contacts ──
          AppSectionHeader(
            title: 'People at ${org.name}',
            count: _contacts.length,
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_contacts.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No contacts linked to ${org.name} yet.',
                style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
              ),
            )
          else
            ..._contacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AppListRow(
                    leading: AppAvatar(name: c.name, size: AppAvatarSize.sm),
                    title: c.name,
                    subtitle: c.role,
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      AppHaptics.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: c.id!)),
                      );
                    },
                  ),
                )),

          const SizedBox(height: AppSpacing.lg),

          // ── Associated Commitments ──
          AppSectionHeader(
            title: 'Commitments with ${org.name}',
            count: _commitments.length,
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_commitments.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No pending commitments with this company.',
                style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
              ),
            )
          else
            ..._commitments.map((cm) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AppListRow(
                    leading: const Icon(Icons.handshake_outlined, size: 20, color: AppColors.primary),
                    title: cm.title,
                    subtitle: '${cm.type.label} · ${cm.status.label}',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      AppHaptics.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommitmentDetailScreen(commitmentId: cm.id!),
                        ),
                      );
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.muted(context)),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
