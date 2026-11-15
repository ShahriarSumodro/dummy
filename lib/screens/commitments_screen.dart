import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../services/database_service.dart';
import '../theme/design_tokens.dart';
import '../theme/app_motion.dart';
import '../theme/app_haptics.dart';
import '../widgets/widgets.dart';
import 'commitment_form_screen.dart';
import 'commitment_detail_screen.dart';
import 'action_drafts_screen.dart';

/// Redesigned Commitments & Promises Screen.
/// Clean filter tabs, swipe-to-complete gestures, and semantic status badges.
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
    AppHaptics.lightImpact();
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
    AppHaptics.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommitmentDetailScreen(commitmentId: commitment.id!),
      ),
    );
    _loadCommitments();
  }

  Future<void> _toggleComplete(Commitment commitment) async {
    final isCompleting = commitment.status != CommitmentStatus.completed;
    if (isCompleting) {
      AppHaptics.success();
    } else {
      AppHaptics.lightImpact();
    }
    final updated = commitment.copyWith(
      status:
          isCompleting ? CommitmentStatus.completed : CommitmentStatus.pending,
      completedAt: isCompleting ? DateTime.now() : null,
    );
    await _db.updateCommitment(updated);
    _loadCommitments();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Promises & Tasks',
          style: TextStyle(
            color: primaryText,
            fontSize: AppTypography.subtitleSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'Action Drafts',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActionDraftsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Commitment',
            onPressed: _addCommitment,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      isDark ? AppColors.darkHairline : AppColors.lightHairline,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor:
                  isDark ? AppColors.darkAccent : AppColors.lightAccent,
              indicatorWeight: 2.5,
              labelColor:
                  isDark ? AppColors.darkAccent : AppColors.lightAccent,
              unselectedLabelColor: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
              labelStyle: const TextStyle(
                fontSize: AppTypography.secondarySize,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: AppTypography.secondarySize,
                fontWeight: FontWeight.w400,
              ),
              tabs: _filters.map((f) => Tab(text: f.label)).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.screenSide),
              children: [
                AppSkeleton.row(),
                const SizedBox(height: AppSpacing.sm),
                AppSkeleton.card(height: 76),
                const SizedBox(height: AppSpacing.xs),
                AppSkeleton.card(height: 76),
                const SizedBox(height: AppSpacing.xs),
                AppSkeleton.card(height: 76),
              ],
            )
          : Column(
              children: [
                // Clean Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenSide,
                    AppSpacing.sm,
                    AppSpacing.screenSide,
                    AppSpacing.xs,
                  ),
                  child: AppTextField(
                    controller: _searchController,
                    hintText: 'Search promises, people, notes...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  ),
                ),

                // Secondary Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenSide,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All Types',
                        isSelected: _typeFilter == null && !_overdueOnly,
                        onTap: () => setState(() {
                          _typeFilter = null;
                          _overdueOnly = false;
                        }),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _FilterPill(
                        label: 'Promised by Me',
                        isSelected: _typeFilter == CommitmentType.promiseMade,
                        onTap: () => setState(() {
                          _typeFilter =
                              _typeFilter == CommitmentType.promiseMade
                                  ? null
                                  : CommitmentType.promiseMade;
                        }),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _FilterPill(
                        label: 'Expecting',
                        isSelected:
                            _typeFilter == CommitmentType.promiseReceived,
                        onTap: () => setState(() {
                          _typeFilter =
                              _typeFilter == CommitmentType.promiseReceived
                                  ? null
                                  : CommitmentType.promiseReceived;
                        }),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _FilterPill(
                        label: 'Follow-ups',
                        isSelected: _typeFilter == CommitmentType.followUp,
                        onTap: () => setState(() {
                          _typeFilter = _typeFilter == CommitmentType.followUp
                              ? null
                              : CommitmentType.followUp;
                        }),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _FilterPill(
                        label: 'Tasks',
                        isSelected: _typeFilter == CommitmentType.task,
                        onTap: () => setState(() {
                          _typeFilter = _typeFilter == CommitmentType.task
                              ? null
                              : CommitmentType.task;
                        }),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _FilterPill(
                        label: 'Overdue',
                        isSelected: _overdueOnly,
                        isWarning: true,
                        onTap: () =>
                            setState(() => _overdueOnly = !_overdueOnly),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color:
                      isDark ? AppColors.darkHairline : AppColors.lightHairline,
                ),

                Expanded(
                  child: _filteredCommitments.isEmpty
                      ? AppEmptyState(
                          icon: _searchQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.handshake_outlined,
                          title: _searchQuery.isNotEmpty
                              ? 'No matching commitments'
                              : 'No commitments found',
                          description: _searchQuery.isNotEmpty
                              ? 'No promises or tasks matched "$_searchQuery".'
                              : 'Track promises and follow-ups so nothing slips through the cracks.',
                          actionLabel: _searchQuery.isEmpty ? '+ New Commitment' : null,
                          onAction: _searchQuery.isEmpty ? _addCommitment : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenSide,
                            AppSpacing.sm,
                            AppSpacing.screenSide,
                            100, // Space for floating bottom bar
                          ),
                          itemCount: _filteredCommitments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final c = _filteredCommitments[index];
                            return _CommitmentCard(
                              commitment: c,
                              onTap: () => _openCommitment(c),
                              onToggleComplete: () => _toggleComplete(c),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isWarning;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    this.isWarning = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    if (isSelected) {
      if (isWarning) {
        bg = isDark
            ? AppColors.semanticRedDarkSubtle
            : AppColors.semanticRedLight;
        fg = isDark ? AppColors.semanticRedDark : AppColors.semanticRed;
        border = fg.withValues(alpha: 0.3);
      } else {
        bg = isDark ? AppColors.darkAccentSubtle : AppColors.lightAccentSubtle;
        fg = isDark ? AppColors.darkAccent : AppColors.lightAccent;
        border = fg.withValues(alpha: 0.3);
      }
    } else {
      bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
      fg = isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;
      border = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    }

    return PressableScale(
      onTap: () {
        AppHaptics.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: AppTypography.captionSize,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  final Commitment commitment;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  const _CommitmentCard({
    required this.commitment,
    required this.onTap,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isComplete = commitment.status == CommitmentStatus.completed;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    AppBadge badge;
    if (commitment.isOverdue && !isComplete) {
      badge = AppBadge.overdue(isSmall: true);
    } else if (isComplete) {
      badge = AppBadge.done(isSmall: true);
    } else if (commitment.type == CommitmentType.promiseMade) {
      badge = const AppBadge(
        label: 'Promised',
        variant: AppBadgeVariant.accent,
        isSmall: true,
      );
    } else if (commitment.type == CommitmentType.promiseReceived) {
      badge = const AppBadge(
        label: 'Expecting',
        variant: AppBadgeVariant.neutral,
        isSmall: true,
      );
    } else {
      badge = const AppBadge(
        label: 'Task',
        variant: AppBadgeVariant.neutral,
        isSmall: true,
      );
    }

    final dateStr = commitment.dueDate != null
        ? DateFormat('EEE, MMM d · h:mm a').format(commitment.dueDate!)
        : null;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Complete Checkbox Toggle
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              isComplete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isComplete
                  ? (isDark
                      ? AppColors.semanticGreenDark
                      : AppColors.semanticGreen)
                  : (isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary),
              size: 22,
            ),
            onPressed: onToggleComplete,
          ),
          const SizedBox(width: AppSpacing.xs),

          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commitment.title,
                  style: TextStyle(
                    color: isComplete
                        ? secondaryText
                        : primaryText,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (commitment.contactName != null) ...[
                      Text(
                        commitment.contactName!,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent,
                          fontSize: AppTypography.captionSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(color: secondaryText),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (dateStr != null)
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: commitment.isOverdue && !isComplete
                              ? (isDark
                                  ? AppColors.semanticRedDark
                                  : AppColors.semanticRed)
                              : secondaryText,
                          fontSize: AppTypography.captionSize,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          badge,
        ],
      ),
    );
  }
}
