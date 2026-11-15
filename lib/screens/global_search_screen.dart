import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../models/meeting.dart';
import '../models/organization.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
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
    final hasResults = _contacts.isNotEmpty ||
        _commitments.isNotEmpty ||
        _meetings.isNotEmpty ||
        _orgs.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search people, promises, meetings...',
            hintStyle: TextStyle(color: AppColors.muted(context), fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _currentQuery.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.search_rounded,
                    title: 'Search everything in RemembrAI',
                    message: 'Find contacts, promises, meeting notes, companies, or commitments by keyword.',
                  ),
                )
              : !hasResults
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results found',
                        message: 'No matches found for "$_currentQuery". Try a different keyword or name.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 80),
                      children: [
                        // Contacts
                        if (_contacts.isNotEmpty) ...[
                          AppSectionHeader(title: 'Contacts', count: _contacts.length),
                          const SizedBox(height: AppSpacing.xs),
                          ..._contacts.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: AppListRow(
                                  leading: AppAvatar(name: c.name, size: AppAvatarSize.sm),
                                  title: c.name,
                                  subtitle: c.subtitle.isNotEmpty ? c.subtitle : null,
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                                  onTap: () {
                                    AppHaptics.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: c.id!)),
                                    );
                                  },
                                ),
                              )),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Commitments
                        if (_commitments.isNotEmpty) ...[
                          AppSectionHeader(title: 'Promises & Commitments', count: _commitments.length),
                          const SizedBox(height: AppSpacing.xs),
                          ..._commitments.map((cm) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: AppListRow(
                                  leading: const Icon(Icons.handshake_outlined, size: 18, color: AppColors.primary),
                                  title: cm.title,
                                  subtitle: '${cm.type.label} · ${cm.status.label}',
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                                  onTap: () {
                                    AppHaptics.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CommitmentDetailScreen(commitmentId: cm.id!)),
                                    );
                                  },
                                ),
                              )),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Meetings
                        if (_meetings.isNotEmpty) ...[
                          AppSectionHeader(title: 'Meetings', count: _meetings.length),
                          const SizedBox(height: AppSpacing.xs),
                          ..._meetings.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: AppListRow(
                                  leading: const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                                  title: m.title,
                                  subtitle: [
                                    m.meetingDate.toLocal().toString().substring(0, 10),
                                    if (m.location != null) m.location!,
                                  ].join(' · '),
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                                  onTap: () {
                                    AppHaptics.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => MeetingDetailScreen(meetingId: m.id!)),
                                    );
                                  },
                                ),
                              )),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Organizations
                        if (_orgs.isNotEmpty) ...[
                          AppSectionHeader(title: 'Companies', count: _orgs.length),
                          const SizedBox(height: AppSpacing.xs),
                          ..._orgs.map((org) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: AppListRow(
                                  leading: AppAvatar(name: org.name, size: AppAvatarSize.sm),
                                  title: org.name,
                                  subtitle: org.industry,
                                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                                  onTap: () {
                                    AppHaptics.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => OrganizationDetailScreen(organizationId: org.id!)),
                                    );
                                  },
                                ),
                              )),
                        ],
                      ],
                    ),
    );
  }
}
