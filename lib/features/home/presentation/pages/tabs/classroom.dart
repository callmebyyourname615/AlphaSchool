import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../../../shared/models/student_card_item.dart';
import 'classroom_timetable_model.dart';
import 'classroom_timetable_service.dart';

const _pageBlue = Color(0xFFDDE8FF);
const _surface = Color(0xFFFCFCFF);
const _text = Color(0xFF20243A);
const _muted = Color(0xFF85899A);
const _border = Color(0xFFE7E8EE);
const _purple = Color(0xFF3B82F6);
const _orange = Color(0xFFF5B15E);

class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key, this.selectedStudent});

  final StudentCardItem? selectedStudent;

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  late DateTime _selectedDate;
  final _service = ClassroomTimetableService();
  Future<List<ClassroomTimetableItem>>? _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = today.weekday == DateTime.saturday
        ? today.subtract(const Duration(days: 1))
        : today.weekday == DateTime.sunday
        ? today.add(const Duration(days: 1))
        : today;
    _load();
  }

  void _load() {
    final classId = widget.selectedStudent?.classId ?? '';
    _future = _service.fetchByClass(classId);
  }

  String get _selectedDay => switch (_selectedDate.weekday) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    _ => 'sunday',
  };

  List<DateTime> get _week {
    final monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - DateTime.monday),
    );
    return List.generate(5, (index) => monday.add(Duration(days: index)));
  }

  void _goToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDate = today.weekday == DateTime.saturday
          ? today.subtract(const Duration(days: 1))
          : today.weekday == DateTime.sunday
          ? today.add(const Duration(days: 1))
          : today;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBlue,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: _surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
                  child: _CalendarHeader(
                    selectedDate: _selectedDate,
                    week: _week,
                    onDateChanged: (date) =>
                        setState(() => _selectedDate = date),
                    onToday: _goToday,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 132),
                sliver: FutureBuilder<List<ClassroomTimetableItem>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if ((widget.selectedStudent?.classId ?? '').isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _ClassroomState(
                          icon: LucideIcons.userSearch,
                          message: 'Please select a student first.',
                        ),
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: CircularProgressIndicator(color: _purple),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: _ClassroomState(
                          icon: LucideIcons.wifiOff,
                          message: 'Could not load timetable.',
                          action: () => setState(_load),
                        ),
                      );
                    }
                    final lessons = (snapshot.data ?? const [])
                        .where((item) => item.dayOfWeek == _selectedDay)
                        .toList();
                    if (lessons.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _ClassroomState(
                          icon: LucideIcons.calendarCheck,
                          message: 'No classes scheduled for this day.',
                        ),
                      );
                    }
                    return SliverList.separated(
                      itemCount: lessons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) =>
                          _TimelineLesson(lesson: lessons[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selectedDate,
    required this.week,
    required this.onDateChanged,
    required this.onToday,
  });

  final DateTime selectedDate;
  final List<DateTime> week;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB8BBC5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.calendarDays,
                size: 16,
                color: _muted,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              DateFormat('MMM').format(selectedDate),
              style: const TextStyle(
                color: _text,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('yyyy').format(selectedDate),
              style: const TextStyle(
                color: _muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onToday,
              style: TextButton.styleFrom(
                foregroundColor: _purple,
                minimumSize: const Size(52, 44),
              ),
              child: const Text(
                'Today',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            for (final date in week)
              Expanded(
                child: _DayButton(
                  date: date,
                  selected: DateUtils.isSameDay(date, selectedDate),
                  onTap: () => onDateChanged(date),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _purple : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _purple.withValues(alpha: .22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              DateFormat('E').format(date).characters.first,
              style: TextStyle(
                color: selected ? Colors.white70 : const Color(0xFFB5B7C0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? Colors.white : _text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineLesson extends StatelessWidget {
  const _TimelineLesson({required this.lesson});

  final ClassroomTimetableItem lesson;

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay(hour: lesson.startHour, minute: lesson.startMinute);
    final end = TimeOfDay(hour: lesson.endHour, minute: lesson.endMinute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Transform.translate(
              offset: const Offset(-18, 0),
              child: Container(
                width: 17,
                height: 9,
                decoration: const BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(-10, 0),
              child: Text(
                '${_formatTime(start)} - ${_formatTime(end)}',
                style: const TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock3, size: 13, color: _purple),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(lesson.durationMinutes),
                    style: const TextStyle(
                      color: _purple,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(left: 20),
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.subject,
                style: const TextStyle(
                  color: _text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                lesson.note ?? widgetFallbackSubtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _InfoLine(
                icon: LucideIcons.user,
                title: lesson.teacher,
                subtitle: lesson.phone,
              ),
              const SizedBox(height: 14),
              _InfoLine(
                icon: LucideIcons.mapPin,
                title: lesson.className,
                subtitle: 'Classroom',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(int minutes) => '$minutes min';

  static const widgetFallbackSubtitle = 'Class timetable';
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F3F7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: const Color(0xFFB7BAC5)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF565A69),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassroomState extends StatelessWidget {
  const _ClassroomState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(icon, size: 34, color: _muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: action, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
