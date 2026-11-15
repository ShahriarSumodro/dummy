import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../models/memory_item.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

/// Screen for browsing, searching, adding, editing, and managing long-term personal memories (Module 2).
class MemoriesScreen extends StatefulWidget {
  final int? filterContactId;
  final String? filterContactName;

  const MemoriesScreen({
    super.key,
    this.filterContactId,
    this.filterContactName,
  });

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final _db = DatabaseService();
  List<MemoryItem> _memories = [];
  List<Contact> _contacts = [];
  bool _loading = true;
  String _selectedCategory = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final contacts = await _db.getAllContacts();
      final memories = await _db.getAllMemories(
        category: _selectedCategory,
        contactId: widget.filterContactId,
        searchQuery: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _memories = memories;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showMemoryEditor([MemoryItem? existing]) async {
    AppHaptics.lightImpact();
    final isEditing = existing != null;
    final contentController = TextEditingController(text: existing?.content ?? '');
    MemoryCategory selectedCategory = existing?.category ?? MemoryCategory.fact;
    int? selectedContactId = existing?.contactId ?? widget.filterContactId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Edit Memory' : 'Add Personal Memory',
                        style: const TextStyle(
                          fontSize: AppTypography.titleSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category Selector
                  const Text(
                    'Memory Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: MemoryCategory.values.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.foreground(context),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedCategory = cat);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Contact Association
                  if (_contacts.isNotEmpty) ...[
                    DropdownButtonFormField<int?>(
                      value: selectedContactId,
                      decoration: const InputDecoration(
                        labelText: 'Link to Person (Optional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('About Myself / General Context'),
                        ),
                        ..._contacts.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text('${c.name}${c.company != null ? " (${c.company})" : ""}'),
                            )),
                      ],
                      onChanged: (val) {
                        setModalState(() => selectedContactId = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Content Input
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'What do you want Dummy. to remember?',
                      hintText: 'e.g. Karim prefers dark roast coffee without sugar; MVP launch date is late November.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final text = contentController.text.trim();
                            if (text.isEmpty) return;

                            if (isEditing) {
                              final updated = existing.copyWith(
                                content: text,
                                category: selectedCategory,
                                contactId: selectedContactId,
                              );
                              await _db.updateMemory(updated);
                            } else {
                              final newMemory = MemoryItem(
                                content: text,
                                category: selectedCategory,
                                contactId: selectedContactId,
                                source: 'user_stated',
                                isVerified: true,
                              );
                              await _db.insertMemory(newMemory);
                            }

                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadData();
                              AppHaptics.success();
                            }
                          },
                          child: Text(isEditing ? 'Save Changes' : 'Remember Fact'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMemory(MemoryItem memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: Text('Are you sure you want Dummy. to forget:\n"${memory.content}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );

    if (confirmed == true && memory.id != null) {
      AppHaptics.mediumImpact();
      await _db.deleteMemory(memory.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final categories = [
      {'key': 'all', 'label': 'All Memories'},
      ...MemoryCategory.values.map((c) => {'key': c.name, 'label': c.label}),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filterContactName != null
              ? '${widget.filterContactName} · Memories'
              : 'Personal & Business Memory',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Memory',
            onPressed: () => _showMemoryEditor(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Memory',
        onPressed: () => _showMemoryEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search memories, facts, preferences...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => _loadData(),
            ),
          ),

          // Horizontal Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      cat['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : primaryText,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    showCheckmark: false,
                    onSelected: (val) {
                      AppHaptics.selectionClick();
                      setState(() {
                        _selectedCategory = cat['key']!;
                      });
                      _loadData();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Content List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _memories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.psychology_outlined,
                                size: 56,
                                color: secondaryText.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No memories found',
                                style: TextStyle(
                                  fontSize: AppTypography.titleSize,
                                  fontWeight: FontWeight.w600,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tell Dummy. facts, preferences, project updates, or personal habits in conversation, or tap + to record one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppTypography.captionSize,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xs,
                            AppSpacing.md,
                            80, // Space for FAB
                          ),
                          itemCount: _memories.length,
                          itemBuilder: (context, index) {
                            final mem = _memories[index];
                            return _MemoryCard(
                              memory: mem,
                              onEdit: () => _showMemoryEditor(mem),
                              onDelete: () => _deleteMemory(mem),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryItem memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.memory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppBadge(
                label: memory.category.label,
                variant: _categoryVariant(memory.category),
              ),
              if (memory.contactName != null) ...[
                const SizedBox(width: AppSpacing.xs),
                AppBadge(
                  label: memory.contactName!,
                  variant: AppBadgeVariant.neutral,
                ),
              ],
              const Spacer(),
              Text(
                dateFormat.format(memory.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: secondaryText),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            memory.content,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  AppBadgeVariant _categoryVariant(MemoryCategory cat) {
    switch (cat) {
      case MemoryCategory.preference:
        return AppBadgeVariant.accent;
      case MemoryCategory.project:
        return AppBadgeVariant.warning;
      case MemoryCategory.decision:
        return AppBadgeVariant.success;
      case MemoryCategory.workingHabit:
        return AppBadgeVariant.neutral;
      case MemoryCategory.relationship:
        return AppBadgeVariant.accent;
      case MemoryCategory.goal:
        return AppBadgeVariant.success;
      default:
        return AppBadgeVariant.neutral;
    }
  }
}
