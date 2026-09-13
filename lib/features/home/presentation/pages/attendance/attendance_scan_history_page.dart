import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_icons.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';

const _blue = Color(0xFF3B82F6);
const _navy = Color(0xFF1E2D5B);
const _text = Color(0xFF111827);
const _muted = Color(0xFF8A93A6);
const _border = Color(0xFFE6EAF2);
const _surface = Color(0xFFF8FAFD);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFF59E0B);
const _cyan = Color(0xFF0891B2);

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

String _weekdayShort(BuildContext context, DateTime date) {
  const keys = [
    'weekdayMonShort',
    'weekdayTueShort',
    'weekdayWedShort',
    'weekdayThuShort',
    'weekdayFriShort',
    'weekdaySatShort',
    'weekdaySunShort',
  ];
  return _t(context, keys[date.weekday - 1]);
}

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class AttendanceScanHistoryPage extends StatefulWidget {
  const AttendanceScanHistoryPage({super.key});

  @override
  State<AttendanceScanHistoryPage> createState() =>
      _AttendanceScanHistoryPageState();
}

class _AttendanceScanHistoryPageState extends State<AttendanceScanHistoryPage> {
  final _service = AttendanceService();
  DateTime _selectedDate = DateTime.now();
  List<StaffAttendanceScanRecord> _records = const [];
  bool _loading = true;
  bool _error = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final records = await _service.fetchStaffScanHistory(date: _selectedDate);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _records = const [];
        _loading = false;
        _error = true;
      });
    }
  }

  void _selectDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (_dateKey(normalized) == _dateKey(_selectedDate)) return;
    setState(() => _selectedDate = normalized);
    unawaited(_load());
  }

  void _goToday() => _selectDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                _Header(onBack: () => Navigator.maybePop(context)),
                Expanded(
                  child: RefreshIndicator(
                    color: _blue,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      children: [
                        _DateHeader(
                          selectedDate: _selectedDate,
                          onToday: _goToday,
                        ),
                        const SizedBox(height: 24),
                        _DayStrip(
                          selectedDate: _selectedDate,
                          onSelected: _selectDate,
                        ),
                        const SizedBox(height: 28),
                        if (_loading)
                          const _LoadingState()
                        else if (_error)
                          _ErrorState(onRetry: _load)
                        else ...[
                          _Summary(records: _records),
                          const SizedBox(height: 14),
                          _ScanList(records: _records),
                        ],
                      ],
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(LucideIcons.arrowLeft, color: _navy),
          ),
          Expanded(
            child: Text(
              _t(context, 'scanHistory'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _navy,
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

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.selectedDate, required this.onToday});

  final DateTime selectedDate;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1.5),
          ),
          child: const Icon(LucideIcons.calendarDays, color: _muted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            '${_monthName(context, selectedDate.month)} ${selectedDate.year}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _navy,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        TextButton(
          onPressed: onToday,
          child: Text(
            _t(context, 'today'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selectedDate, required this.onSelected});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      5,
      (index) => selectedDate.add(Duration(days: index - 2)),
    );

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DayTile(
                date: day,
                selected: DateUtils.isSameDay(day, selectedDate),
                onTap: () => onSelected(day),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 88,
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _blue : Colors.transparent),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _blue.withValues(alpha: .18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdayShort(context, date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? Colors.white : _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.records});

  final List<StaffAttendanceScanRecord> records;

  @override
  Widget build(BuildContext context) {
    final late = records.where((record) => record.isLate).length;
    final early = records.where((record) => record.isEarly).length;
    final onTime = records.where((record) => record.isOnTime).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            label: _t(context, 'scannedStudents'),
            value: records.length,
            icon: LucideIcons.scanQrCode,
            color: _blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryPill(
            label: _t(context, 'late'),
            value: late,
            icon: LucideIcons.clock,
            color: _orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryPill(
            label: early > 0
                ? _t(context, 'attendanceEarly')
                : _t(context, 'onTime'),
            value: early > 0 ? early : onTime,
            icon: LucideIcons.circleCheck,
            color: early > 0 ? _cyan : _green,
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanList extends StatelessWidget {
  const _ScanList({required this.records});

  final List<StaffAttendanceScanRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const _EmptyState();

    return Column(
      children: [
        for (final record in records) ...[
          _ScanRecordTile(record: record),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ScanRecordTile extends StatelessWidget {
  const _ScanRecordTile({required this.record});

  final StaffAttendanceScanRecord record;

  Color get _statusColor {
    if (record.isLate) return _orange;
    if (record.isEarly) return _cyan;
    return _green;
  }

  String _statusLabel(BuildContext context) {
    if (record.isLate) return _t(context, 'late');
    if (record.isEarly) return _t(context, 'attendanceEarly');
    return _t(context, 'onTime');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              record.studentName.trim().isNotEmpty
                  ? record.studentName.characters.first.toUpperCase()
                  : '?',
              style: TextStyle(
                color: _statusColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (record.className != '-') record.className,
                    if (record.studentCode.isNotEmpty) record.studentCode,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.checkIn.format(context),
                style: const TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(context),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 120),
      child: Center(child: CircularProgressIndicator(color: _blue)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 92),
      child: Column(
        children: [
          const Icon(LucideIcons.wifiOff, size: 46, color: _muted),
          const SizedBox(height: 14),
          Text(
            _t(context, 'unableToConnectTryAgain'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(_t(context, 'tryAgain'))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 92),
      child: Column(
        children: [
          const Icon(LucideIcons.listChecks, size: 54, color: _muted),
          const SizedBox(height: 16),
          Text(
            _t(context, 'noScanRecords'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(context, 'tryDifferentDayFromCalendar'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
