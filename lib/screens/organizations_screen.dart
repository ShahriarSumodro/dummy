import 'package:flutter/material.dart';
import '../models/organization.dart';
import '../services/database_service.dart';
import 'organization_form_screen.dart';
import 'organization_detail_screen.dart';

/// Screen listing all organizations/companies with search & active counts.
class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final _db = DatabaseService();
  List<Organization> _orgs = [];
  bool _loading = true;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations({String? query}) async {
    try {
      final orgs = await _db.getAllOrganizations(searchQuery: query).timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );
      if (mounted) {
        setState(() {
          _orgs = orgs;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading organizations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addOrg() async {
    final result = await Navigator.push<Organization>(
      context,
      MaterialPageRoute(builder: (_) => const OrganizationFormScreen()),
    );
    if (result != null) {
      await _db.insertOrganization(result);
      _loadOrganizations();
    }
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
                  hintText: 'Search companies...',
                  border: InputBorder.none,
                ),
                onChanged: (q) => _loadOrganizations(query: q),
              )
            : const Text('Companies & Organizations'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _loadOrganizations();
                }
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 70,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No companies added yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Group your contacts and commitments by company or client organization.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _orgs.length,
                  itemBuilder: (context, index) {
                    final org = _orgs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            org.initials,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          org.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (org.industry != null) org.industry!,
                            '${org.contactCount} contact(s)',
                            if (org.activeCommitmentCount > 0)
                              '${org.activeCommitmentCount} active promise(s)',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrganizationDetailScreen(
                                organizationId: org.id!,
                              ),
                            ),
                          );
                          if (updated == true) _loadOrganizations();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrg,
        child: const Icon(Icons.add_business),
      ),
    );
  }
}
