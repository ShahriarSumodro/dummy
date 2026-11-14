import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import 'contact_form_screen.dart';
import 'contact_detail_screen.dart';
import 'organizations_screen.dart';

/// People / Contacts screen.
/// Shows a searchable list of contacts with add, view, and search.
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
    final _ = await Navigator.push<bool>(
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
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _loadContacts();
      }
    });
  }

  Future<void> _checkDuplicates() async {
    final duplicates = await _db.findDuplicateContacts();
    if (!mounted) return;

    if (duplicates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicate contacts found. Your directory is clean!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.merge_type, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Duplicate Contacts Detected (${duplicates.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'RemembrAI can merge secondary contact information, promises, and interactions into the primary contact.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ...duplicates.map((dup) {
                final Contact primary = dup['primary'] as Contact;
                final Contact duplicate = dup['duplicate'] as Contact;
                final String reason = dup['reason'] as String;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Primary: ${primary.name} (${primary.company ?? primary.role ?? 'No company'})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Duplicate: ${duplicate.name} (${duplicate.company ?? duplicate.role ?? 'No company'})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: () async {
                            await _db.mergeContacts(primary.id!, duplicate.id!);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadContacts();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Merged "${duplicate.name}" into "${primary.name}".',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Merge Duplicates'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
                onChanged: (query) => _loadContacts(query: query),
              )
            : const Text('People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.merge_type),
            tooltip: 'Merge Duplicate Contacts',
            onPressed: _checkDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.business_outlined),
            tooltip: 'Companies Directory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrganizationsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState(theme)
              : _buildContactList(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searching ? Icons.search_off : Icons.people_outline,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              _searching ? 'No matches found' : 'No contacts yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _searching
                  ? 'Try a different search term.'
                  : 'Tap + to add people you work with.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList(ThemeData theme) {
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              contact.initials,
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(contact.name),
          subtitle: contact.subtitle.isNotEmpty
              ? Text(contact.subtitle)
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openContact(contact),
        );
      },
    );
  }
}
