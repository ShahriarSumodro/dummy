import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../services/database_service.dart';
import 'commitment_form_screen.dart';
import 'commitment_detail_screen.dart';
import 'action_drafts_screen.dart';

/// Commitments screen with filter tabs.
class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabController;
  List<Commitment> _commitments = [];
  bool _loading = true;

  // Filter: null = all, or a specific status name.
  String? _statusFilter;
  CommitmentType? _typeFilter;
  bool _overdueOnly = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _filters = [
    (label: 'All', status: null),
    (label: 'Pending', status: 'pending'),
    (label: 'Completed', status: 'completed'),
    (label: 'Cancelled', status: 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _statusFilter = _filters[_tabController.index].status;
        _loadCommitments();
      }
    });
    _loadCommitments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommitments() async {
    final commitments =
        await _db.getAllCommitments(statusFilter: _statusFilter);
    if (mounted) {
      setState(() {
        _commitments = commitments;
        _loading = false;
      });
    }
  }

  List<Commitment> get _filteredCommitments {
    return _commitments.where((c) {
      if (_typeFilter != null && c.type != _typeFilter) return false;
      if (_overdueOnly && !c.isOverdue) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = c.title.toLowerCase().contains(q);
        final matchesContact =
            c.contactName != null && c.contactName!.toLowerCase().contains(q);
        final matchesDesc =
            c.description != null && c.description!.toLowerCase().contains(q);
        if (!matchesTitle && !matchesContact && !matchesDesc) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _addCommitment() async {
    final result = await Navigator.push<Commitment>(
      context,
      MaterialPageRoute(builder: (_) => const CommitmentFormScreen()),
    );
    if (result != null) {
      await _db.insertCommitment(result);
      _loadCommitments();
    }
  }

  Future<void> _openCommitment(Commitment commitment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommitmentDetailScreen(commitmentId: commitment.id!),
      ),
    );
    _loadCommitments();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commitments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.drafts_outlined),
            tooltip: 'View Prepared Drafts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActionDraftsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _filters.map((f) => Tab(text: f.label)).toList(),
          isScrollable: false,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search commitments & contacts...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),

                // Secondary filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Types'),
                        selected: _typeFilter == null,
                        onSelected: (selected) {
                          if (selected) setState(() => _typeFilter = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ...CommitmentType.values.map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(t.label),
                              selected: _typeFilter == t,
                              onSelected: (selected) {
                                setState(() => _typeFilter = selected ? t : null);
                              },
                            ),
                          )),
                      FilterChip(
                        avatar: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _overdueOnly ? Colors.white : theme.colorScheme.error,
                        ),
                        label: const Text('Overdue Only'),
                        selected: _overdueOnly,
                        selectedColor: theme.colorScheme.error,
                        labelStyle: TextStyle(
                          color: _overdueOnly ? Colors.white : theme.colorScheme.error,
                        ),
                        onSelected: (selected) {
                          setState(() => _overdueOnly = selected);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _filteredCommitments.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildList(theme),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCommitment,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final hasFilters = _searchQuery.isNotEmpty || _typeFilter != null || _overdueOnly;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.filter_alt_off : Icons.handshake_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matching commitments' : 'No commitments yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try clearing filters or search terms.'
                  : 'Tap + to track a promise, request, or follow-up.',
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

  Widget _buildList(ThemeData theme) {
    final dateFormat = DateFormat('MMM d');
    final list = _filteredCommitments;

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];
        final isComplete = c.status == CommitmentStatus.completed;
        final isOverdue = c.isOverdue;

        return ListTile(
          leading: Icon(
            isComplete
                ? Icons.check_circle
                : (isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.pending_outlined),
            color: isComplete
                ? Colors.green
                : (isOverdue ? theme.colorScheme.error : null),
          ),
          title: Text(
            c.title,
            style: TextStyle(
              decoration: isComplete ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            [
              c.type.label,
              if (c.contactName != null) c.contactName!,
            ].join(' · '),
          ),
          trailing: c.dueDate != null
              ? Text(
                  dateFormat.format(c.dueDate!),
                  style: TextStyle(
                    color: isOverdue ? theme.colorScheme.error : null,
                    fontWeight: isOverdue ? FontWeight.bold : null,
                  ),
                )
              : null,
          onTap: () => _openCommitment(c),
        );
      },
    );
  }
}
