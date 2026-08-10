import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/api_config.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'parent_task_detail_page.dart';
import 'parent_task_service.dart';

// Light, DESIGN.md-aligned palette — same constants already used by
// contact_page.dart (no gradients/glass, matches AppColors' royal-blue family).
const _kNavy = Color(0xFF082653);
const _kBlue = Color(0xFF0756D1);
const _kBlueSoft = Color(0xFFEAF1FF);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF5F8FE);
const _kBorder = Color(0xFFE3E9F2);
const _kMuted = Color(0xFF647594);
const _kMutedSoft = Color(0xFF8A98B0);
const _kPurpleBg = Color(0xFFF3E8FF);
const _kPurpleFg = Color(0xFF9333EA);
const _kAmberBg = Color(0xFFFEF3C7);
const _kAmberFg = Color(0xFFB45309);
const _kDangerBg = Color(0xFFFEE2E2);

enum TaskSubjectKey {
  english,
  science,
  math,
  art,
  writing,
  social,
  music,
  discussion,
  general,
}

class TaskSubjectStyle {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;

  const TaskSubjectStyle({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.label,
  });
}

const Map<TaskSubjectKey, TaskSubjectStyle> kTaskSubjectStyles = {
  TaskSubjectKey.english: TaskSubjectStyle(
    bg: _kPurpleBg,
    fg: _kPurpleFg,
    icon: LucideIcons.bookOpen,
    label: 'English',
  ),
  TaskSubjectKey.science: TaskSubjectStyle(
    bg: Color(0xFFDCFCE7),
    fg: Color(0xFF16A34A),
    icon: FontAwesomeIcons.flask,
    label: 'Science',
  ),
  TaskSubjectKey.math: TaskSubjectStyle(
    bg: _kBlueSoft,
    fg: _kBlue,
    icon: FontAwesomeIcons.calculator,
    label: 'Math',
  ),
  TaskSubjectKey.art: TaskSubjectStyle(
    bg: Color(0xFFFFE9D6),
    fg: Color(0xFFEA580C),
    icon: FontAwesomeIcons.palette,
    label: 'Art',
  ),
  TaskSubjectKey.writing: TaskSubjectStyle(
    bg: _kAmberBg,
    fg: _kAmberFg,
    icon: FontAwesomeIcons.pen,
    label: 'Writing',
  ),
  TaskSubjectKey.social: TaskSubjectStyle(
    bg: Color(0xFFCCFBF1),
    fg: Color(0xFF0D9488),
    icon: LucideIcons.globe,
    label: 'Social Studies',
  ),
  TaskSubjectKey.music: TaskSubjectStyle(
    bg: Color(0xFFFCE7F3),
    fg: Color(0xFFDB2777),
    icon: FontAwesomeIcons.music,
    label: 'Music',
  ),
  TaskSubjectKey.discussion: TaskSubjectStyle(
    bg: _kPurpleBg,
    fg: _kPurpleFg,
    icon: LucideIcons.messageCircle,
    label: 'Discussion',
  ),
  TaskSubjectKey.general: TaskSubjectStyle(
    bg: _kBg,
    fg: _kMutedSoft,
    icon: LucideIcons.fileText,
    label: 'General',
  ),
};

class TaskFileRef {
  final String id;
  final String name;
  final String url;

  const TaskFileRef({required this.id, required this.name, required this.url});

  /// Builds a [TaskFileRef] from any `/files`-shaped API row (used for both
  /// a task's own attachments and a task submission's uploaded files).
  factory TaskFileRef.fromApi(Map<String, dynamic> json) {
    final path = (json['file_path'] ?? '').toString();
    final segments = path.split('/');
    final name = segments.isNotEmpty && segments.last.isNotEmpty
        ? segments.last
        : 'file';
    return TaskFileRef(
      id: (json['id'] ?? '').toString(),
      name: name,
      url: resolveFileUrl(path),
    );
  }

  /// Static uploads (e.g. `uploads/tasks/x.pdf`) live at the API host root,
  /// not under `/api/v2` — mirrors HomeworkService.resolveImageUrl.
  static String resolveFileUrl(String rawPath) {
    final clean = rawPath.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://'))
      return clean;
    var relative = clean.startsWith('/') ? clean.substring(1) : clean;
    if (relative.startsWith('uploads/')) {
      relative = relative.substring('uploads/'.length);
    }
    final base = Uri.parse(ApiConfig.baseUrl);
    return base.replace(path: '/uploads/$relative').toString();
  }
}

class TaskStatusStyle {
  final String label;
  final Color color;

  const TaskStatusStyle({required this.label, required this.color});
}

const Map<String, TaskStatusStyle> kTaskStatusStyles = {
  'draft': TaskStatusStyle(label: 'Draft', color: _kMutedSoft),
  'assigned': TaskStatusStyle(label: 'Assigned', color: _kBlue),
  'in_progress': TaskStatusStyle(
    label: 'In Progress',
    color: Color(0xFFB45309),
  ),
  'submitted': TaskStatusStyle(label: 'Submitted', color: Color(0xFF7C3AED)),
  'completed': TaskStatusStyle(label: 'Completed', color: Color(0xFF16A34A)),
  'overdue': TaskStatusStyle(label: 'Overdue', color: _kRed),
};

class ParentTaskItem {
  final String id;
  final String title;
  final TaskSubjectKey subject;
  final String teacher;
  final String description;
  final String due;
  final int daysLeft;
  final int messages;
  final bool isNew;
  final String status;
  final int? points;
  final int? practiceFrequency;
  final String? practiceFrequencyUnit;
  final List<TaskFileRef> files;
  final List<DateTime> submissionPlanDates;
  final bool allowLateSubmission;

  const ParentTaskItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.teacher,
    required this.description,
    required this.due,
    required this.daysLeft,
    required this.messages,
    this.isNew = false,
    this.status = 'assigned',
    this.points,
    this.practiceFrequency,
    this.practiceFrequencyUnit,
    this.files = const [],
    this.submissionPlanDates = const [],
    this.allowLateSubmission = false,
  });

  static const List<String> _inProgressStatuses = ['in_progress'];
  static const List<String> _completedStatuses = ['completed', 'submitted'];

  bool get isInProgress => _inProgressStatuses.contains(status);
  bool get isCompleted => _completedStatuses.contains(status);

  String? get practiceTargetLabel {
    if (practiceFrequency == null || practiceFrequency! < 1) return null;
    final unit = practiceFrequencyUnit == 'month' ? 'month' : 'week';
    return '$practiceFrequency per $unit';
  }

  TaskStatusStyle get statusStyle =>
      kTaskStatusStyles[status] ?? kTaskStatusStyles['assigned']!;

  /// Builds a [ParentTaskItem] from a raw `/tasks` API row (see Task entity
  /// in API_Alphaschool_Merge). [teacherName] is resolved separately from
  /// `/admins` since the task row only carries `added_by_id`.
  factory ParentTaskItem.fromApi(
    Map<String, dynamic> json, {
    String? teacherName,
  }) {
    final deadline = _parseDate(json['deadline']);
    final createdAt = _parseDate(json['created_at']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rawPoints = json['points'];
    final rawPracticeFrequency = json['practice_frequency'];
    final practiceFrequency = rawPracticeFrequency is num
        ? rawPracticeFrequency.toInt()
        : int.tryParse(rawPracticeFrequency?.toString() ?? '');
    final rawPracticeFrequencyUnit = json['practice_frequency_unit']
        ?.toString()
        .toLowerCase();
    final configuredPlanDates = _parseSubmissionPlanDates(json['settings']);
    // Tasks created before the submission-plan feature have no schedule in
    // `settings`. They still have one meaningful checkpoint: their deadline.
    // This preserves a clear plan for parents without inventing extra rounds.
    final submissionPlanDates = configuredPlanDates.isNotEmpty
        ? configuredPlanDates
        : deadline == null
        ? const <DateTime>[]
        : [deadline];

    return ParentTaskItem(
      id: (json['id'] ?? '').toString(),
      title: (json['name'] ?? 'Untitled task').toString(),
      subject: _resolveSubjectKey(json['subject']?.toString()),
      teacher: teacherName ?? 'Teacher',
      description: _stripHtml((json['description'] ?? '').toString()),
      due: deadline != null
          ? DateFormat('MMM d, yyyy').format(deadline)
          : 'No due date',
      daysLeft: deadline != null ? deadline.difference(today).inDays : 0,
      messages: 0,
      isNew: createdAt != null && now.difference(createdAt).inDays <= 3,
      status: (json['status'] ?? 'assigned').toString(),
      points: rawPoints is num
          ? rawPoints.toInt()
          : int.tryParse(rawPoints?.toString() ?? ''),
      practiceFrequency: practiceFrequency != null && practiceFrequency > 0
          ? practiceFrequency
          : null,
      practiceFrequencyUnit:
          rawPracticeFrequencyUnit == 'month' ||
              rawPracticeFrequencyUnit == 'week'
          ? rawPracticeFrequencyUnit
          : null,
      files: _parseFiles(json['files']),
      submissionPlanDates: submissionPlanDates,
      allowLateSubmission:
          _parseSettings(json['settings'])['allow_late_submission'] == true,
    );
  }

  static Map _parseSettings(dynamic rawSettings) {
    if (rawSettings is String) {
      try {
        rawSettings = jsonDecode(rawSettings);
      } catch (_) {
        return const {};
      }
    }
    return rawSettings is Map ? rawSettings : const {};
  }

  static List<DateTime> _parseSubmissionPlanDates(dynamic rawSettings) {
    final schedule = _parseSettings(rawSettings)['submission_schedule'];
    if (schedule is! Map || schedule['dates'] is! List) return const [];
    return schedule['dates']
        .map((value) => DateTime.tryParse(value.toString()))
        .whereType<DateTime>()
        .toList()
      ..sort();
  }

  static List<TaskFileRef> _parseFiles(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((f) => f['is_deleted'] != true)
        .map(TaskFileRef.fromApi)
        .toList();
  }

  // The admin panel saves `description` as rich-text HTML (from a WYSIWYG
  // editor) — strip tags/entities so it reads as plain text here, since this
  // app has no HTML renderer.
  static String _stripHtml(String value) {
    if (value.isEmpty) return value;
    final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final decoded = withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static TaskSubjectKey _resolveSubjectKey(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return TaskSubjectKey.general;
    for (final entry in kTaskSubjectStyles.entries) {
      if (entry.key.name == value || entry.value.label.toLowerCase() == value) {
        return entry.key;
      }
    }
    for (final entry in kTaskSubjectStyles.entries) {
      if (entry.key == TaskSubjectKey.general) continue;
      if (value.contains(entry.key.name) ||
          value.contains(entry.value.label.toLowerCase())) {
        return entry.key;
      }
    }
    return TaskSubjectKey.general;
  }
}

// ================= PAGE =================

class ParentTaskListPage extends StatefulWidget {
  final StudentCardItem? selectedStudent;

  const ParentTaskListPage({super.key, this.selectedStudent});

  @override
  State<ParentTaskListPage> createState() => _ParentTaskListPageState();
}

enum _LoadState { loading, loaded, error }

class _ParentTaskListPageState extends State<ParentTaskListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _searchCtrl = TextEditingController();
  final _taskService = TaskService();

  _LoadState _loadState = _LoadState.loading;
  List<ParentTaskItem> _tasks = const [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final tasks = await _taskService.fetchForStudent(
        studentId: widget.selectedStudent?.id,
        classId: widget.selectedStudent?.classId,
      );
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loadState = _LoadState.loaded;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loadState = _LoadState.error;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<ParentTaskItem> get _assignedTasks =>
      _tasks.where((t) => !t.isInProgress && !t.isCompleted).toList();

  List<ParentTaskItem> get _inProgressTasks =>
      _tasks.where((t) => t.isInProgress).toList();

  int get _completedCount => _tasks.where((t) => t.isCompleted).length;

  void _openDetail(ParentTaskItem task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Only reachable once tasks have loaded, which requires a selected
        // student (see the "No student selected" branch in _buildBody).
        builder: (_) =>
            ParentTaskDetailPage(task: task, student: widget.selectedStudent!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _BackButton(onTap: () => Navigator.maybePop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                      height: 1.0,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(bottomInset)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double bottomInset) {
    if (_loadState == _LoadState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.4),
      );
    }

    if (_loadState == _LoadState.error) {
      return _MessageState(
        icon: LucideIcons.circleAlert,
        title: 'Could not load tasks',
        message: _errorMessage,
        actionLabel: 'Retry',
        onAction: _loadTasks,
      );
    }

    if ((widget.selectedStudent?.id ?? '').isEmpty) {
      return const _MessageState(
        icon: LucideIcons.user,
        title: 'No student selected',
        message: 'Choose a student from the home screen to view their tasks.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _TaskTabBar(
            controller: _tab,
            assignedCount: _assignedTasks.length,
            inProgressCount: _inProgressTasks.length,
            completedCount: _completedCount,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _SearchFilterRow(
            controller: _searchCtrl,
            onFilterTap: () => _toast('Filter coming soon'),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _UpcomingList(
                tasks: _assignedTasks,
                bottomInset: bottomInset,
                onTapTask: _openDetail,
                onViewCalendar: () => _toast('Calendar coming soon'),
              ),
              _UpcomingList(
                tasks: _inProgressTasks,
                bottomInset: bottomInset,
                onTapTask: _openDetail,
                onViewCalendar: () => _toast('Calendar coming soon'),
              ),
              _CompletedPlaceholder(
                count: _completedCount,
                onSeeHistory: () => _toast('Task history coming soon'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= Back button =================

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: _kBorder)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(LucideIcons.chevronLeft, color: _kNavy, size: 18),
          ),
        ),
      ),
    );
  }
}

// ================= Tabs =================

class _TaskTabBar extends StatelessWidget {
  final TabController controller;
  final int assignedCount;
  final int inProgressCount;
  final int completedCount;

  const _TaskTabBar({
    required this.controller,
    required this.assignedCount,
    required this.inProgressCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _kBlue,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: _kBlue,
        unselectedLabelColor: _kMuted,
        labelPadding: const EdgeInsets.only(right: 22),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(text: 'Assigned ($assignedCount)'),
          Tab(text: 'In Progress ($inProgressCount)'),
          Tab(text: 'Completed ($completedCount)'),
        ],
      ),
    );
  }
}

// ================= Search + Filter =================

class _SearchFilterRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFilterTap;

  const _SearchFilterRow({required this.controller, required this.onFilterTap});

  static final _fieldRadius = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14, color: _kNavy),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: const TextStyle(color: _kMutedSoft, fontSize: 14),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 17,
                  color: _kMutedSoft,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: _fieldRadius,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: _fieldRadius,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: _fieldRadius,
                  borderSide: const BorderSide(color: _kBlue, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          borderRadius: _fieldRadius,
          child: InkWell(
            borderRadius: _fieldRadius,
            onTap: onFilterTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.sliders, size: 15, color: _kNavy),
                  SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kNavy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================= Upcoming list =================

class _UpcomingList extends StatelessWidget {
  final List<ParentTaskItem> tasks;
  final double bottomInset;
  final ValueChanged<ParentTaskItem> onTapTask;
  final VoidCallback onViewCalendar;

  const _UpcomingList({
    required this.tasks,
    required this.bottomInset,
    required this.onTapTask,
    required this.onViewCalendar,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
        children: const [
          _MessageState(
            icon: LucideIcons.clipboardCheck,
            title: 'Nothing here yet',
            message: 'Tasks assigned to your child will show up here.',
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
      children: [
        const Text(
          'Upcoming Tasks',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kNavy,
          ),
        ),
        const SizedBox(height: 12),
        for (final task in tasks) ...[
          _TaskCard(task: task, onTap: () => onTapTask(task)),
          const SizedBox(height: 12),
        ],
        _CalendarPromo(onTap: onViewCalendar),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ParentTaskItem task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = kTaskSubjectStyles[task.subject]!;
    final urgent = task.daysLeft <= 2;
    final badgeBg = urgent ? _kDangerBg : _kAmberBg;
    final badgeFg = urgent ? _kRed : _kAmberFg;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(style.icon, size: 22, color: style.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: _kNavy,
                                  ),
                                ),
                              ),
                              if (task.isNew) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kPurpleBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _kPurpleFg,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${task.daysLeft} days left',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Due: ${task.due}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kRed,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: _kNavy),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.teacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kMutedSoft,
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.messageCircle,
                          size: 13,
                          color: _kMutedSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${task.messages}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kMutedSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: _kMutedSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarPromo extends StatelessWidget {
  final VoidCallback onTap;

  const _CalendarPromo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlueSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.calendarDays,
              size: 18,
              color: _kBlue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep track of due dates!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Submit your work on time and stay up to date.',
                  style: TextStyle(fontSize: 12, color: _kMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Calendar',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kBlue,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight, size: 11, color: _kBlue),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Completed tab placeholder =================

class _CompletedPlaceholder extends StatelessWidget {
  final int count;
  final VoidCallback onSeeHistory;

  const _CompletedPlaceholder({
    required this.count,
    required this.onSeeHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'No completed tasks yet.'
                : '$count ${count == 1 ? 'task' : 'tasks'} completed.',
            style: const TextStyle(fontSize: 13.5, color: _kMuted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              onPressed: onSeeHistory,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See full history →',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Compact task summary card — shared by the chat and attachments pages
// (anywhere that needs a "here's what this thread is about" header).
class TaskMiniCard extends StatelessWidget {
  final ParentTaskItem task;
  final VoidCallback onTap;

  const TaskMiniCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = kTaskSubjectStyles[task.subject]!;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(style.icon, size: 20, color: style.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _kNavy,
                            ),
                          ),
                        ),
                        if (task.isNew)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _kPurpleBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _kPurpleFg,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _kMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.calendarDays,
                          size: 12,
                          color: _kRed,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Due: ${task.due}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${task.daysLeft} days left',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: _kMutedSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= Shared message state =================

// Loading-error / empty-state / no-selection messaging, reused across the
// list page and its tabs so every "nothing to show" case teaches the user
// what to do next instead of a bare "no data" line.
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: _kBlueSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: _kBlue),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: _kMuted,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              Material(
                color: _kBlue,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
