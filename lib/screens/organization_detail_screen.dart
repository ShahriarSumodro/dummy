import 'package:flutter/material.dart';
import '../models/organization.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../services/database_service.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text('Delete "${_org?.name}"? Linked contacts will remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
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
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_org == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Company not found')),
      );
    }

    final org = _org!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(org.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editOrg,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteOrg,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                org.initials,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              org.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (org.industry != null)
            Center(
              child: Text(
                org.industry!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Details ListTiles
          if (org.website != null)
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Website'),
              subtitle: Text(org.website!),
            ),
          if (org.address != null)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Address'),
              subtitle: Text(org.address!),
            ),
          if (org.notes != null)
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Notes'),
              subtitle: Text(org.notes!),
            ),

          const Divider(height: 32),

          // Associated Contacts
          Text(
            'People at ${org.name} (${_contacts.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (_contacts.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No contacts linked to ${org.name} yet.'),
              ),
            )
          else
            ..._contacts.map((c) => ListTile(
                  leading: CircleAvatar(
                    child: Text(c.initials),
                  ),
                  title: Text(c.name),
                  subtitle: c.role != null ? Text(c.role!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactDetailScreen(contactId: c.id!),
                    ),
                  ),
                )),

          const SizedBox(height: 24),

          // Associated Commitments
          Text(
            'Commitments with ${org.name} (${_commitments.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (_commitments.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No pending commitments with this company.'),
              ),
            )
          else
            ..._commitments.map((cm) => ListTile(
                  leading: const Icon(Icons.handshake_outlined),
                  title: Text(cm.title),
                  subtitle: Text('${cm.type.label} · ${cm.status.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommitmentDetailScreen(commitmentId: cm.id!),
                    ),
                  ),
                )),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
