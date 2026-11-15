import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'meeting_form_screen.dart';
import 'meeting_detail_screen.dart';

/// Screen listing all recorded business meetings with search & filters.
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _db = DatabaseService();
  List<Meeting> _meetings = [];
  bool _loading = true;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings({String? query}) async {
    try {
      final meetings = await _db.getAllMeetings(searchQuery: query).timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );
      if (mounted) {
        setState(() {
          _meetings = meetings;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createMeeting() async {
    AppHaptics.lightImpact();
    final result = await Navigator.push<Meeting>(
      context,
      MaterialPageRoute(builder: (_) => const MeetingFormScreen()),
    );
    if (result != null) {
      await _db.insertMeeting(result);
      _loadMeetings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

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
                  hintText: 'Search meetings...',
                  border: InputBorder.none,
                ),
                onChanged: (q) => _loadMeetings(query: q),
              )
            : Row(
                children: [
                  const Text('Meetings Intel', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  if (!_loading && _meetings.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.subtle(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${_meetings.length}',
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
                  _loadMeetings();
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
                child: AppSkeleton(height: 76, borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            )
          : _meetings.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: _searching ? 'No matching meetings' : 'No meetings recorded yet',
                    message: _searching
                        ? 'Try a different search query.'
                        : 'Log client meetings and partner discussions. Dummy. will summarize topics, decisions, and action items.',
                    actionLabel: _searching ? 'Clear Search' : 'Log First Meeting',
                    onAction: _searching
                        ? () {
                            _searchController.clear();
                            setState(() => _searching = false);
                            _loadMeetings();
                          }
                        : _createMeeting,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
                  itemCount: _meetings.length,
                  itemBuilder: (context, index) {
                    final m = _meetings[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppListRow(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.subtle(context),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        title: m.title,
                        subtitle: [
                          dateFormat.format(m.meetingDate),
                          if (m.organizationName != null) m.organizationName!,
                          if (m.location != null) m.location!,
                        ].join(' · '),
                        badge: m.actionItems.isNotEmpty
                            ? AppBadge(
                                label: '${m.actionItems.length} actions',
                                variant: AppBadgeVariant.neutral,
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                        onTap: () async {
                          AppHaptics.lightImpact();
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetingDetailScreen(meetingId: m.id!),
                            ),
                          );
                          if (updated == true) _loadMeetings();
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
          onPressed: _createMeeting,
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}
