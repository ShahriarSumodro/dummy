import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../models/meeting.dart';
import '../models/organization.dart';
import '../services/database_service.dart';
import 'contact_detail_screen.dart';
import 'commitment_detail_screen.dart';
import 'meeting_detail_screen.dart';
import 'organization_detail_screen.dart';

/// Global unified search across all business memory entities.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  List<Commitment> _commitments = [];
  List<Meeting> _meetings = [];
  List<Organization> _orgs = [];

  bool _isSearching = false;
  String _currentQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _contacts.clear();
        _commitments.clear();
        _meetings.clear();
        _orgs.clear();
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = clean;
    });

    final results = await _db.searchAll(clean);

    if (mounted) {
      setState(() {
        _contacts = results['contacts'] as List<Contact>;
        _commitments = results['commitments'] as List<Commitment>;
        _meetings = results['meetings'] as List<Meeting>;
        _orgs = results['organizations'] as List<Organization>;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResults = _contacts.isNotEmpty ||
        _commitments.isNotEmpty ||
        _meetings.isNotEmpty ||
        _orgs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search people, promises, meetings...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: _performSearch,
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _currentQuery.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 70,
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search your complete business memory',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type a person name, company, topic, or keyword to instantly find relevant records.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : !hasResults
                  ? Center(
                      child: Text('No memories match "$_currentQuery"'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Contacts
                        if (_contacts.isNotEmpty) ...[
                          _sectionHeader('People (${_contacts.length})', theme),
                          ..._contacts.map((c) => ListTile(
                                leading: CircleAvatar(child: Text(c.initials)),
                                title: Text(c.name),
                                subtitle: Text(c.subtitle),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ContactDetailScreen(contactId: c.id!),
                                  ),
                                ),
                              )),
                          const Divider(height: 24),
                        ],

                        // Commitments
                        if (_commitments.isNotEmpty) ...[
                          _sectionHeader(
                              'Commitments (${_commitments.length})', theme),
                          ..._commitments.map((c) => ListTile(
                                leading: const Icon(Icons.handshake_outlined),
                                title: Text(c.title),
                                subtitle: Text(
                                    '${c.type.label} · ${c.status.label}${c.contactName != null ? " with ${c.contactName}" : ""}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommitmentDetailScreen(
                                      commitmentId: c.id!,
                                    ),
                                  ),
                                ),
                              )),
                          const Divider(height: 24),
                        ],

                        // Meetings
                        if (_meetings.isNotEmpty) ...[
                          _sectionHeader('Meetings (${_meetings.length})', theme),
                          ..._meetings.map((m) => ListTile(
                                leading: const Icon(Icons.meeting_room_outlined),
                                title: Text(m.title),
                                subtitle: Text(
                                    m.summary ?? m.rawNotes ?? 'No notes recorded'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MeetingDetailScreen(meetingId: m.id!),
                                  ),
                                ),
                              )),
                          const Divider(height: 24),
                        ],

                        // Organizations
                        if (_orgs.isNotEmpty) ...[
                          _sectionHeader(
                              'Companies (${_orgs.length})', theme),
                          ..._orgs.map((o) => ListTile(
                                leading: const Icon(Icons.business_outlined),
                                title: Text(o.name),
                                subtitle: o.industry != null
                                    ? Text(o.industry!)
                                    : null,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrganizationDetailScreen(
                                      organizationId: o.id!,
                                    ),
                                  ),
                                ),
                              )),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
