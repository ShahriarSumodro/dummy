import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../services/database_service.dart';
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
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search meetings...',
                  border: InputBorder.none,
                ),
                onChanged: (q) => _loadMeetings(query: q),
              )
            : const Text('Meeting Intelligence'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _loadMeetings();
                }
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 70,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No meetings recorded yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log your client meetings and partner discussions. RemembrAI will summarize topics, decisions, and action items.',
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
                  itemCount: _meetings.length,
                  itemBuilder: (context, index) {
                    final m = _meetings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.groups_outlined,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          m.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                dateFormat.format(m.meetingDate),
                                if (m.organizationName != null) m.organizationName!,
                                if (m.location != null) m.location!,
                              ].join(' · '),
                            ),
                            if (m.actionItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${m.actionItems.length} action item(s)',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createMeeting,
        child: const Icon(Icons.add),
      ),
    );
  }
}
