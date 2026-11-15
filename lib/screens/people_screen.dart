import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'contact_form_screen.dart';
import 'contact_detail_screen.dart';
import 'organizations_screen.dart';

/// People / Contacts screen.
/// Premium, clean contact directory with touchpoint cadence status,
/// duplicate detection, companies directory, and quick search.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _db = DatabaseService();
  List<Contact> _contacts = [];
  bool _loading = true;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts({String? query}) async {
    final contacts = await _db.getAllContacts(searchQuery: query);
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _addContact() async {
    AppHaptics.lightImpact();
    final result = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactFormScreen(),
      ),
    );

    if (result != null) {
      await _db.insertContact(result);
      _loadContacts();
    }
  }

  Future<void> _openContact(Contact contact) async {
    AppHaptics.lightImpact();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailScreen(contactId: contact.id!),
      ),
    );

    // Refresh list in case contact was edited or deleted.
    _loadContacts(
      query: _searching ? _searchController.text : null,
    );
  }

  void _toggleSearch() {
    AppHaptics.lightImpact();
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _loadContacts();
      }
    });
  }

  Future<void> _checkDuplicates() async {
    AppHaptics.mediumImpact();
    final duplicates = await _db.findDuplicateContacts();
    if (!mounted) return;

    if (duplicates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No duplicate contacts found. Directory is clean!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
      return;
    }

    await AppBottomSheet.show<void>(
      context: context,
      title: 'Duplicate Contacts Detected (${duplicates.length})',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RemembrAI can merge secondary contact information, promises, and interactions into the primary contact.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...duplicates.map((dup) {
            final Contact primary = dup['primary'] as Contact;
            final Contact duplicate = dup['duplicate'] as Contact;
            final String reason = dup['reason'] as String;

            return AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.merge_type_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Primary: ${primary.name} (${primary.company ?? primary.role ?? 'No company'})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Duplicate: ${duplicate.name} (${duplicate.company ?? duplicate.role ?? 'No company'})',
                    style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Merge Duplicates',
                    icon: Icons.call_merge_rounded,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.tonal,
                    onPressed: () async {
                      AppHaptics.success();
                      await _db.mergeContacts(primary.id!, duplicate.id!);
                      if (context.mounted) Navigator.pop(context);
                      _loadContacts();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Merged "${duplicate.name}" into "${primary.name}".',
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
                onChanged: (query) => _loadContacts(query: query),
              )
            : Row(
                children: [
                  const Text('People', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  if (!_loading && _contacts.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.subtle(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${_contacts.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.merge_type_rounded),
            tooltip: 'Find & Merge Duplicates',
            onPressed: _checkDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.business_outlined),
            tooltip: 'Companies Directory',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrganizationsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : _contacts.isEmpty
              ? _buildEmptyState()
              : _buildContactList(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72), // clear floating pill nav
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          onPressed: _addContact,
          child: const Icon(Icons.person_add_rounded),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppSkeleton(
          height: 64,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: AppEmptyState(
        icon: _searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
        title: _searching ? 'No matching contacts' : 'No contacts yet',
        message: _searching
            ? 'Try searching by a different name, company or role.'
            : 'Add business associates, clients, and partners to track commitments and touchpoint cadences.',
        actionLabel: _searching ? 'Clear Search' : 'Add First Contact',
        onAction: _searching
            ? () {
                _searchController.clear();
                _toggleSearch();
              }
            : _addContact,
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 100),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: AppListRow(
            leading: AppAvatar(
              name: contact.name,
              size: AppAvatarSize.md,
            ),
            title: contact.name,
            subtitle: contact.subtitle.isNotEmpty ? contact.subtitle : null,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
            onTap: () => _openContact(contact),
          ),
        );
      },
    );
  }
}
