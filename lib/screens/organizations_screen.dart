import 'package:flutter/material.dart';
import '../models/organization.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
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
          SnackBar(content: Text('Error loading companies: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addOrg() async {
    AppHaptics.lightImpact();
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
                  hintText: 'Search companies...',
                  border: InputBorder.none,
                ),
                onChanged: (q) => _loadOrganizations(query: q),
              )
            : Row(
                children: [
                  const Text('Companies', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  if (!_loading && _orgs.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.subtle(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${_orgs.length}',
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
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              AppHaptics.lightImpact();
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _loadOrganizations();
                }
              });
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 6,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppSkeleton(height: 72, borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            )
          : _orgs.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.business_outlined,
                    title: _searching ? 'No matching companies' : 'No companies added yet',
                    message: _searching
                        ? 'Try a different search term.'
                        : 'Group contacts and commitments by company or client organization.',
                    actionLabel: _searching ? 'Clear Search' : 'Add First Company',
                    onAction: _searching
                        ? () {
                            _searchController.clear();
                            setState(() => _searching = false);
                            _loadOrganizations();
                          }
                        : _addOrg,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 100),
                  itemCount: _orgs.length,
                  itemBuilder: (context, index) {
                    final org = _orgs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppListRow(
                        leading: AppAvatar(
                          name: org.name,
                          size: AppAvatarSize.md,
                        ),
                        title: org.name,
                        subtitle: [
                          if (org.industry != null) org.industry!,
                          '${org.contactCount} contact(s)',
                        ].join(' · '),
                        badge: org.activeCommitmentCount > 0
                            ? AppBadge(
                                label: '${org.activeCommitmentCount} promises',
                                variant: AppBadgeVariant.warning,
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                        onTap: () async {
                          AppHaptics.lightImpact();
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          onPressed: _addOrg,
          child: const Icon(Icons.add_business_rounded),
        ),
      ),
    );
  }
}
