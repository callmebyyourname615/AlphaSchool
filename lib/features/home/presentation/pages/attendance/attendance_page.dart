import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';

const _blue = Color(0xFF0756D1);
const _text = Color(0xFF082653);
const _muted = Color(0xFF647594);
const _border = Color(0xFFE3E9F2);
const _softBlue = Color(0xFFF1F6FF);
const _green = Color(0xFF13B96D);
const _red = Color(0xFFEF4444);
const _background = Color(0xFFF7F9FC);

enum _AttendanceFilter { present, absent }

String _t(BuildContext context, String key) =>
    AppLocalizations.of(context).t(key);

String _monthName(BuildContext context, int month) {
  const keys = [
    'monthJanuary',
    'monthFebruary',
    'monthMarch',
    'monthApril',
    'monthMay',
    'monthJune',
    'monthJuly',
    'monthAugust',
    'monthSeptember',
    'monthOctober',
    'monthNovember',
    'monthDecember',
  ];
  return _t(context, keys[month - 1]);
}

String _monthYear(BuildContext context, DateTime date) =>
    '${_monthName(context, date.month)} ${date.year}';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.selectedStudent});

  final StudentCardItem? selectedStudent;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _service = AttendanceService();
  DateTime? _month;
  _AttendanceFilter? _filter;
  List<AttendanceRecord> _records = const [];
  bool _loading = true;
  bool _error = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AttendancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_studentKey(oldWidget.selectedStudent) !=
        _studentKey(widget.selectedStudent)) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool preferCache = true}) async {
    final token = ++_loadToken;
    final student = widget.selectedStudent;
    if (student == null) {
      if (!mounted) return;
      setState(() {
        _records = const [];
        _loading = false;
        _error = false;
      });
      return;
    }

    var hasCache = false;
    if (preferCache) {
      final cached = await _service.readCachedHistory(student, month: _month);
      if (!mounted || token != _loadToken) return;
      if (cached != null) {
        hasCache = true;
        setState(() {
          _records = cached;
          _loading = false;
          _error = false;
        });
      }
    }

    if (!hasCache) {
      setState(() {
        _records = const [];
        _loading = true;
        _error = false;
      });
    }

    try {
      final records = await _service.fetchHistory(student, month: _month);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _records = records;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _error = _records.isEmpty;
      });
    }
  }

  String _studentKey(StudentCardItem? student) {
    if (student == null) return '';
    final internalId = student.id?.trim() ?? '';
    return internalId.isNotEmpty ? internalId : student.studentId.trim();
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MonthPickerSheet(
        initialMonth: _month ?? now,
        firstYear: now.year - 3,
        lastYear: now.year + 1,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = DateTime(picked.year, picked.month);
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.selectedStudent;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                _Header(onBack: () => Navigator.maybePop(context)),
                Expanded(
                  child: student == null
                      ? const _NoStudent()
                      : _error
                      ? _ErrorState(onRetry: () => unawaited(_load()))
                      : _loading && _records.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: _blue),
                        )
                      : _Content(
                          student: student,
                          records: _records,
                          filter: _filter,
                          month: _month,
                          onPickMonth: _selectMonth,
                          onClearMonth: () {
                            setState(() => _month = null);
                            unawaited(_load());
                          },
                          onRefresh: () => _load(preferCache: false),
                          onFilterChanged: (filter) => setState(() {
                            _filter = _filter == filter ? null : filter;
                          }),
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

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.initialMonth,
    required this.firstYear,
    required this.lastYear,
  });

  final DateTime initialMonth;
  final int firstYear;
  final int lastYear;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  _t(context, 'selectMonth'),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _year > widget.firstYear
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _year < widget.lastYear
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(LucideIcons.chevronRight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final selected =
                  _year == widget.initialMonth.year &&
                  month == widget.initialMonth.month;

              return InkWell(
                onTap: () => Navigator.pop(context, DateTime(_year, month)),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? _blue : _background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? _blue : _border),
                  ),
                  child: Text(
                    _monthName(context, month),
                    style: TextStyle(
                      color: selected ? Colors.white : _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(LucideIcons.arrowLeft, size: 18),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: Colors.white,
              foregroundColor: _blue,
            ),
          ),
          Expanded(
            child: Text(
              _t(context, 'attendanceTracking'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.student,
    required this.records,
    required this.filter,
    required this.month,
    required this.onPickMonth,
    required this.onClearMonth,
    required this.onRefresh,
    required this.onFilterChanged,
  });

  final StudentCardItem student;
  final List<AttendanceRecord> records;
  final _AttendanceFilter? filter;
  final DateTime? month;
  final VoidCallback onPickMonth;
  final VoidCallback onClearMonth;
  final Future<void> Function() onRefresh;
  final ValueChanged<_AttendanceFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final present = records.where((record) => record.isPresent).length;
    final absent = records.length - present;
    final filteredRecords = switch (filter) {
      _AttendanceFilter.present =>
        records.where((record) => record.isPresent).toList(),
      _AttendanceFilter.absent =>
        records.where((record) => !record.isPresent).toList(),
      null => records,
    };

    return RefreshIndicator(
      color: _blue,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          _StudentBar(student: student),
          const SizedBox(height: 16),
          _Summary(
            month: month,
            present: present,
            absent: absent,
            filter: filter,
            onPickMonth: onPickMonth,
            onClearMonth: onClearMonth,
            onFilterChanged: onFilterChanged,
          ),
          const SizedBox(height: 16),
          _AttendanceList(records: filteredRecords),
        ],
      ),
    );
  }
}

class _StudentBar extends StatelessWidget {
  const _StudentBar({required this.student});

  final StudentCardItem student;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.all(15),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: _softBlue,
          child: Icon(LucideIcons.user, color: _blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_t(context, 'student')}: ${student.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_t(context, 'classroomLabel')}: ${(student.className ?? '').trim().isEmpty ? '-' : student.className}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, height: 24, color: _border),
        const SizedBox(width: 12),
        Text(
          '${_t(context, 'studentIdLabel')}: ${student.studentId}',
          style: const TextStyle(
            color: _blue,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.month,
    required this.present,
    required this.absent,
    required this.filter,
    required this.onPickMonth,
    required this.onClearMonth,
    required this.onFilterChanged,
  });

  final DateTime? month;
  final int present;
  final int absent;
  final _AttendanceFilter? filter;
  final VoidCallback onPickMonth;
  final VoidCallback onClearMonth;
  final ValueChanged<_AttendanceFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPickMonth,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(LucideIcons.calendarDays, color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  month == null
                      ? _t(context, 'allMonths')
                      : _monthYear(context, month!),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (month != null)
                IconButton(
                  onPressed: onClearMonth,
                  icon: const Icon(LucideIcons.x, color: _muted),
                )
              else
                const Icon(LucideIcons.chevronDown, color: _muted),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t(context, 'trackStudentAttendance'),
          style: const TextStyle(
            color: _text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: _t(context, 'attended'),
                value: present,
                color: _green,
                icon: LucideIcons.check,
                selected: filter == _AttendanceFilter.present,
                onTap: () => onFilterChanged(_AttendanceFilter.present),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                label: _t(context, 'absent'),
                value: absent,
                color: _red,
                icon: LucideIcons.x,
                selected: filter == _AttendanceFilter.absent,
                onTap: () => onFilterChanged(_AttendanceFilter.absent),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: .06)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: .6)
                : const Color(0xFFE3E9F2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _t(context, 'daysCountLabel'),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(flex: 11, child: _Head(_t(context, 'date'))),
              Expanded(flex: 10, child: _Head(_t(context, 'reason'))),
              Expanded(flex: 10, child: _Head(_t(context, 'attendanceNote'))),
              Expanded(
                flex: 12,
                child: _Head(_t(context, 'status'), right: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Text(
              _t(context, 'noAttendanceRecords'),
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          for (final record in records) ...[
            _RecordRow(record: record),
            const SizedBox(height: 8),
          ],
      ],
    ),
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.isPresent ? _green : _red;
    final reason =
        record.reason ??
        (record.isLate
            ? _t(context, 'late')
            : record.isPresent
            ? _t(context, 'normal')
            : _t(context, 'absent'));
    final time = record.checkIn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: _Cell(DateFormat('yyyy/MM/dd').format(record.date)),
          ),
          Expanded(
            flex: 10,
            child: _Cell(reason, color: record.isLate ? _red : null),
          ),
          Expanded(
            flex: 10,
            child: _Cell(record.note ?? '–', muted: record.note == null),
          ),
          Expanded(
            flex: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.isPresent
                        ? _t(context, 'attended')
                        : _t(context, 'absent'),
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${_t(context, 'checkIn')}: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
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

class _Surface extends StatelessWidget {
  const _Surface({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: child,
  );
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.right = false});
  final String text;
  final bool right;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: const TextStyle(
      color: _muted,
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.color, this.muted = false});
  final String text;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color ?? (muted ? _muted : _text),
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _NoStudent extends StatelessWidget {
  const _NoStudent();
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      _t(context, 'pleaseSelectStudentFirst'),
      style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(
      onPressed: onRetry,
      style: FilledButton.styleFrom(backgroundColor: _blue),
      child: Text(_t(context, 'tryAgain')),
    ),
  );
}
