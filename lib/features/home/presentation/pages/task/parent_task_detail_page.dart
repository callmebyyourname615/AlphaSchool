import 'package:flutter/material.dart';

import '../../../../../core/theme/app_icons.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'parent_task_attachments_page.dart';
import 'parent_task_chat_page.dart';
import 'parent_task_list_page.dart';
import 'parent_task_submission_service.dart';

// Same light, DESIGN.md-aligned palette as parent_task_list_page.dart /
// contact_page.dart (re-declared per-file, matching this codebase's existing
// convention rather than a new shared constants file).
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

class ParentTaskDetailPage extends StatefulWidget {
  final ParentTaskItem task;
  final StudentCardItem student;

  const ParentTaskDetailPage({
    super.key,
    required this.task,
    required this.student,
  });

  @override
  State<ParentTaskDetailPage> createState() => _ParentTaskDetailPageState();
}

class _ParentTaskDetailPageState extends State<ParentTaskDetailPage> {
  final _submissionService = TaskSubmissionService();
  int _progressPct = 0;
  List<TaskSubmissionSlot> _submissionSlots = const [];

  /// One task can have several submission rounds. Show its latest reviewed
  /// round: this is the score currently assigned by the teacher in portal.
  TaskSubmissionSlot? get _latestReviewedSlot {
    final reviewed =
        _submissionSlots
            .where((slot) => slot.score != null && slot.maxScore != null)
            .toList()
          ..sort((a, b) => b.scheduleIndex.compareTo(a.scheduleIndex));
    return reviewed.isEmpty ? null : reviewed.first;
  }

  List<TaskSubmissionSlot> get _visibleSubmissionSlots {
    if (_submissionSlots.isNotEmpty) return _submissionSlots;
    return widget.task.submissionPlanDates
        .asMap()
        .entries
        .map(
          (entry) => TaskSubmissionSlot(
            scheduleIndex: entry.key + 1,
            dueAt: entry.value,
            status: 'pending',
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final studentId = widget.student.id ?? widget.student.studentId;
      final submission = await _submissionService.fetchSubmission(
        taskId: widget.task.id,
        studentId: studentId,
      );
      final raw = submission?['progress_pct'];
      final progress = raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '') ?? 0;
      final slots = widget.task.submissionPlanDates.isEmpty
          ? const <TaskSubmissionSlot>[]
          : await _submissionService.syncSlots(
              taskId: widget.task.id,
              studentId: studentId,
            );
      if (!mounted) return;
      setState(() {
        _progressPct = progress.clamp(0, 100);
        _submissionSlots = slots;
      });
    } catch (_) {
      // Leave it at 0 — the teacher hasn't recorded anything yet, or the
      // request failed; either way there's nothing useful to show.
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final student = widget.student;
    final reviewedSlot = _latestReviewedSlot;
    final style = kTaskSubjectStyles[task.subject]!;
    final teacherParts = _splitTeacher(task.teacher);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _OpenChatButton(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParentTaskChatPage(task: task, student: student),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHeader(
              onMoreTap: () => _toast(context, 'More options coming soon'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 86 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: style.bg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Icon(style.icon, size: 26, color: style.fg),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    task.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _kNavy,
                                    ),
                                  ),
                                  if (task.isNew)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _kPurpleBg,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: _kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Assigned by',
                      style: TextStyle(fontSize: 13, color: _kMutedSoft),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: _kBlueSoft,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            LucideIcons.user,
                            size: 19,
                            color: _kBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _kNavy,
                                  ),
                                  children: [
                                    TextSpan(text: teacherParts.name),
                                    if (teacherParts.role != null)
                                      TextSpan(
                                        text: ' (${teacherParts.role})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: _kMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Text(
                                'Alpha School',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _kMutedSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCell(
                              icon: LucideIcons.calendarDays,
                              iconColor: _kPurpleFg,
                              label: 'Due Date',
                              child: Column(
                                children: [
                                  Text(
                                    task.due,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: _kRed,
                                    ),
                                  ),
                                  Text(
                                    '(${task.daysLeft} days left)',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: _kRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _VerticalDivider(),
                          Expanded(
                            child: _SummaryCell(
                              icon: LucideIcons.star,
                              iconColor: _kBlue,
                              label: 'Score',
                              child: Text(
                                reviewedSlot == null
                                    ? 'Not graded'
                                    : '${reviewedSlot.score} / ${reviewedSlot.maxScore} pts',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _kBlue,
                                ),
                              ),
                            ),
                          ),
                          _VerticalDivider(),
                          Expanded(
                            child: _SummaryCell(
                              icon: LucideIcons.refreshCw,
                              iconColor: _kBlue,
                              label: 'Practice Target',
                              child: Text(
                                task.practiceTargetLabel ?? '—',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _kBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _Section(
                      title: 'Your Progress',
                      child: _ProgressCard(progress: _progressPct),
                    ),

                    if (_visibleSubmissionSlots.isNotEmpty)
                      _Section(
                        title:
                            'Submission plan · ${_visibleSubmissionSlots.length} rounds',
                        child: _SubmissionPlanCard(
                          slots: _visibleSubmissionSlots,
                          onSubmitTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParentTaskAttachmentsPage(
                                task: task,
                                student: student,
                              ),
                            ),
                          ),
                        ),
                      ),

                    _Section(
                      title: 'Description',
                      child: Text(
                        task.description.isEmpty
                            ? 'No description provided.'
                            : task.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _kMuted,
                          height: 1.5,
                        ),
                      ),
                    ),

                    _Section(
                      title: 'Attachments',
                      child: _RowCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentTaskAttachmentsPage(
                              task: task,
                              student: student,
                            ),
                          ),
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: task.files.isEmpty ? _kBg : _kRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: task.files.isEmpty
                              ? const Icon(
                                  LucideIcons.fileText,
                                  size: 18,
                                  color: _kMutedSoft,
                                )
                              : const Text(
                                  'FILE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        title: task.files.isEmpty
                            ? 'No attachments'
                            : task.files.length == 1
                            ? task.files.first.name
                            : '${task.files.length} files',
                        subtitle: task.files.isEmpty
                            ? 'The teacher hasn\'t added any files yet.'
                            : 'Tap to view all attachments',
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: _kMutedSoft,
                        ),
                      ),
                    ),

                    _Section(
                      title: 'To Submit',
                      child: _RowCard(
                        filled: true,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kPurpleBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            LucideIcons.camera,
                            size: 20,
                            color: _kPurpleFg,
                          ),
                        ),
                        title: 'Photo of your completed work',
                        subtitle: 'Upload clear photos or a PDF file.',
                        trailing: _UploadButton(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParentTaskAttachmentsPage(
                                task: task,
                                student: student,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherParts {
  final String name;
  final String? role;
  const _TeacherParts(this.name, this.role);
}

_TeacherParts _splitTeacher(String teacher) {
  final match = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*$').firstMatch(teacher);
  if (match == null) return _TeacherParts(teacher, null);
  return _TeacherParts(match.group(1) ?? teacher, match.group(2));
}

class _DetailHeader extends StatelessWidget {
  final VoidCallback onMoreTap;

  const _DetailHeader({required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.maybePop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(LucideIcons.chevronLeft, size: 24, color: _kNavy),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Task Detail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onMoreTap,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_horiz, size: 22, color: _kNavy),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  const _SummaryCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11.5, color: _kMutedSoft)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 46, color: _kBorder);
  }
}

class _SubmissionPlanCard extends StatelessWidget {
  const _SubmissionPlanCard({required this.slots, required this.onSubmitTap});

  final List<TaskSubmissionSlot> slots;
  final VoidCallback onSubmitTap;

  int get _submitted => slots
      .where(
        (slot) => const {'submitted', 'late', 'reviewed'}.contains(slot.status),
      )
      .length;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kBlueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.refreshCw,
                    color: _kBlue,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$_submitted of ${slots.length} checkpoints submitted',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                    ),
                  ),
                ),
                TextButton(onPressed: onSubmitTap, child: const Text('Submit')),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          for (var index = 0; index < slots.length; index++) ...[
            _SubmissionSlotRow(slot: slots[index]),
            if (index < slots.length - 1)
              const Divider(height: 1, color: _kBorder),
          ],
        ],
      ),
    );
  }
}

class _SubmissionSlotRow extends StatelessWidget {
  const _SubmissionSlotRow({required this.slot});

  final TaskSubmissionSlot slot;

  bool get _isSubmittedLate {
    if (slot.status == 'late') return true;
    final submittedAt = slot.submittedAt;
    if (!slot.isSubmitted || submittedAt == null) return false;
    return submittedAt.isAfter(_effectiveDueAt(slot.dueAt));
  }

  Color get _color => switch (slot.status) {
    'submitted' || 'reviewed' =>
      _isSubmittedLate ? const Color(0xFFB45309) : const Color(0xFF16A34A),
    'late' => const Color(0xFFB45309),
    'missed' => _kRed,
    _ => _kBlue,
  };

  String get _submitLabel => switch (slot.status) {
    'submitted' ||
    'reviewed' => _isSubmittedLate ? 'Late Submitted' : 'Early Submitted',
    'late' => 'Late Submitted',
    'missed' => 'Missed',
    _ => 'Waiting to submit',
  };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final due = slot.dueAt;
    final submitted = slot.submittedAt;
    final reviewed = slot.reviewedAt;
    final metrics = <_SlotMetric>[
      if (slot.progressPct != null)
        _SlotMetric(
          label: 'Progress',
          value: '${slot.progressPct!.clamp(0, 100)}%',
          percent: slot.progressPct!.clamp(0, 100),
          emphasis: false,
        ),
      if (slot.score != null && slot.maxScore != null)
        _SlotMetric(
          label: 'Score',
          value: '${slot.score} / ${slot.maxScore}',
          suffix: 'pts',
          percent: _scorePercent(slot.score!, slot.maxScore!),
          emphasis: true,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${slot.scheduleIndex}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(due),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _kNavy,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SlotStatusPill(label: _submitLabel, color: _color),
                  ],
                ),
                const SizedBox(height: 10),
                if (submitted == null)
                  const Text(
                    'Waiting for this checkpoint',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      height: 1.25,
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.send, size: 13, color: _kMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Sent ${_formatDate(submitted)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                if (reviewed != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: _kBlue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Reviewed ${_formatDate(reviewed)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _kBlue,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackMetrics = constraints.maxWidth < 300;
                      final children = [
                        for (
                          var index = 0;
                          index < metrics.length;
                          index++
                        ) ...[
                          if (stackMetrics)
                            _SlotMetricTile(metric: metrics[index])
                          else
                            Expanded(
                              child: _SlotMetricTile(metric: metrics[index]),
                            ),
                          if (index < metrics.length - 1)
                            SizedBox(
                              width: stackMetrics ? 0 : 10,
                              height: stackMetrics ? 10 : 0,
                            ),
                        ],
                      ];
                      return stackMetrics
                          ? Column(children: children)
                          : Row(children: children);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _effectiveDueAt(DateTime dueAt) {
  final hasExplicitTime =
      dueAt.hour != 0 ||
      dueAt.minute != 0 ||
      dueAt.second != 0 ||
      dueAt.millisecond != 0 ||
      dueAt.microsecond != 0;
  if (hasExplicitTime) return dueAt;
  return DateTime(dueAt.year, dueAt.month, dueAt.day, 23, 59, 59, 999, 999);
}

class _SlotStatusPill extends StatelessWidget {
  const _SlotStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        border: Border.all(color: color.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.05,
        ),
      ),
    );
  }
}

class _SlotMetric {
  final String label;
  final String value;
  final String? suffix;
  final int percent;
  final bool emphasis;

  const _SlotMetric({
    required this.label,
    required this.value,
    required this.percent,
    this.suffix,
    required this.emphasis,
  });
}

int _scorePercent(int score, int maxScore) {
  if (maxScore <= 0) return 0;
  return ((score / maxScore) * 100).round().clamp(0, 100);
}

Color _scoreTone(int percent) {
  if (percent < 50) return _kRed;
  if (percent < 80) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}

class _SlotMetricTile extends StatelessWidget {
  const _SlotMetricTile({required this.metric});

  final _SlotMetric metric;

  @override
  Widget build(BuildContext context) {
    final tone = _scoreTone(metric.percent);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        border: Border.all(color: tone.withValues(alpha: .22)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _kMuted,
                    height: 1.05,
                  ),
                ),
              ),
              Text(
                '${metric.percent}%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: tone,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: metric.emphasis ? 17 : 15,
                color: _kNavy,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
              children: [
                TextSpan(text: metric.value),
                if (metric.suffix != null)
                  TextSpan(
                    text: ' ${metric.suffix}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: metric.percent / 100,
              minHeight: 5,
              color: tone,
              backgroundColor: tone.withValues(alpha: .16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int progress;

  const _ProgressCard({required this.progress});

  String get _statusLabel {
    if (progress >= 100) return 'Completed';
    if (progress > 0) return 'In Progress';
    return 'Not Started';
  }

  String get _caption {
    if (progress >= 100) {
      return 'Your teacher has marked this task as complete.';
    }
    if (progress > 0) {
      return "Your teacher says you're $progress% of the way through this task.";
    }
    return "Your teacher hasn't recorded any progress on this task yet.";
  }

  Color get _tone {
    if (progress <= 30) return _kRed;
    if (progress <= 60) return const Color(0xFFF59E0B);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _ProgressRing(progress: progress, color: _tone),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _tone,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _caption,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int progress;
  final Color color;

  const _ProgressRing({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: progress / 100,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$progress%',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                ),
              ),
              const Text(
                'Progress',
                style: TextStyle(fontSize: 9, color: _kMutedSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool filled;
  final VoidCallback? onTap;

  const _RowCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: filled ? _kBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _kMutedSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UploadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kBlue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.upload, size: 13, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Upload',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.6;

    return SizedBox(
      width: width,
      height: 46,
      child: Material(
        color: _kBlue,
        borderRadius: BorderRadius.circular(24),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.messageCircle, size: 16, color: Colors.white),
                SizedBox(width: 7),
                Text(
                  'Open Chat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
