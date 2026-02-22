import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_page_template.dart';

// ✅ เพิ่ม import HomeShell (ปรับ path ให้ตรงโปรเจกต์คุณ)
import '../home_shell_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const double _maxWidth = 680;

  static const String _bgAsset = "assets/images/homepagewall/mainbg.jpeg";

  final List<_StudentInfo> _students = const [
    _StudentInfo(id: "S001", name: "Khampheng S."),
    _StudentInfo(id: "S002", name: "Noy P."),
  ];

  late final String _selectedStudentId = _students.first.id;

  late final Map<String, List<_AttendanceRow>> _data = {
    "S001": _demoRowsA(),
    "S002": _demoRowsB(),
  };

  _AttendStatus? _filter;
  DateTime? _month;

  // ✅ กด back -> ไป HomeShell แบบชัวร์
  void _goHomeShell() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShellPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final locale = Localizations.localeOf(context);
        final base = (mode == ThemeMode.dark)
            ? AppTheme.darkTheme(locale)
            : AppTheme.lightTheme(locale);

        return AnimatedTheme(
          data: base,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Builder(
            builder: (context) {
              final t = Theme.of(context);
              final isDark = t.brightness == Brightness.dark;

              final student = _students.firstWhere(
                (s) => s.id == _selectedStudentId,
                orElse: () => _students.first,
              );

              final allRows =
                  _data[_selectedStudentId] ?? const <_AttendanceRow>[];

              final monthRows = _month == null
                  ? allRows
                  : allRows
                        .where(
                          (e) =>
                              e.date.year == _month!.year &&
                              e.date.month == _month!.month,
                        )
                        .toList();

              final rows = _filter == null
                  ? monthRows
                  : monthRows.where((e) => e.status == _filter).toList();

              final comeCount = monthRows
                  .where((e) => e.status == _AttendStatus.comeIn)
                  .length;
              final absentCount = monthRows
                  .where((e) => e.status == _AttendStatus.notCome)
                  .length;

              final textPrimary = isDark
                  ? Colors.white
                  : const Color(0xFF111827);
              final textMuted = isDark
                  ? Colors.white.withOpacity(.72)
                  : const Color(0xFF6B7280);

              // ✅ Premium dark palette
              final border = isDark
                  ? Colors.white.withOpacity(.12)
                  : Colors.black.withOpacity(.06);
              final shadow = Colors.black.withOpacity(isDark ? .45 : .08);

              final Gradient premiumPanelGrad = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B2B5B).withOpacity(.78),
                  const Color(0xFF071A33).withOpacity(.88),
                  const Color(0xFF060B16).withOpacity(.92),
                ],
              );

              return AppPageTemplate(
                title: "ຕິດຕາມການມາໂຮງຮຽນ",
                backgroundAsset: _bgAsset,
                scrollable: false,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

                // ✅ เปลี่ยนจาก maybePop เป็นไป HomeShell
                onBack: _goHomeShell,

                // ✅ ให้ template เป็น premium dark gradient ด้วย
                premiumDark: true,
                child: SizedBox.expand(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StudentInfoBar(
                                isDark: isDark,
                                border: border,
                                studentText:
                                    "Student: ${student.name}  •  ID: ${student.id}",
                              )
                              .animate()
                              .fadeIn(duration: 200.ms)
                              .slideY(
                                begin: .06,
                                end: 0,
                                duration: 220.ms,
                                curve: Curves.easeOut,
                              ),
                          const SizedBox(height: 12),
                          _Panel(
                                isDark: isDark,
                                color: isDark ? null : const Color(0xFFF7F8FA),
                                gradient: isDark ? premiumPanelGrad : null,
                                border: border,
                                shadow: shadow,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _MonthPickerRow(
                                          isDark: isDark,
                                          border: border,
                                          textPrimary: textPrimary,
                                          textMuted: textMuted,
                                          selectedMonth: _month,
                                          onPick: () => _pickMonth(context),
                                          onClear: () =>
                                              setState(() => _month = null),
                                        )
                                        .animate()
                                        .fadeIn(duration: 200.ms)
                                        .slideY(begin: .06, end: 0),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Track student attendance",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15.5,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCard(
                                            isDark: isDark,
                                            title: "Come in",
                                            value: comeCount,
                                            icon: Icons.check_circle_rounded,
                                            color: const Color(0xFF22C55E),
                                            selected:
                                                _filter == _AttendStatus.comeIn,
                                            onTap: () => _toggleFilter(
                                              _AttendStatus.comeIn,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _StatCard(
                                            isDark: isDark,
                                            title: "Not come",
                                            value: absentCount,
                                            icon: Icons.cancel_rounded,
                                            color: const Color(0xFFEF4444),
                                            selected:
                                                _filter ==
                                                _AttendStatus.notCome,
                                            onTap: () => _toggleFilter(
                                              _AttendStatus.notCome,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_filter != null || _month != null) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                            children: [
                                              Icon(
                                                Icons.filter_alt_rounded,
                                                size: 16,
                                                color: textMuted,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _activeFilterText(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => setState(() {
                                                  _filter = null;
                                                  _month = null;
                                                }),
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                child: Text(
                                                  "Clear",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                          .animate()
                                          .fadeIn(duration: 160.ms)
                                          .slideY(begin: .06, end: 0),
                                    ],
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 220.ms, delay: 40.ms)
                              .slideY(begin: .08, end: 0),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _Panel(
                              isDark: isDark,
                              color: isDark ? null : const Color(0xFFF7F8FA),
                              gradient: isDark ? premiumPanelGrad : null,
                              border: border,
                              shadow: shadow,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Column(
                                  children: [
                                    _TableHeader(
                                      isDark: isDark,
                                      border: border,
                                      textMuted: textMuted,
                                    ),
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration: 220.ms,
                                        switchInCurve: Curves.easeOut,
                                        switchOutCurve: Curves.easeOut,
                                        transitionBuilder: (child, anim) {
                                          final fade = CurvedAnimation(
                                            parent: anim,
                                            curve: Curves.easeOut,
                                          );
                                          final slide = Tween<Offset>(
                                            begin: const Offset(0, .02),
                                            end: Offset.zero,
                                          ).animate(fade);

                                          return FadeTransition(
                                            opacity: fade,
                                            child: SlideTransition(
                                              position: slide,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: rows.isEmpty
                                            ? _EmptyState(
                                                key: ValueKey(
                                                  "empty_${_filter}_${_month?.toIso8601String()}",
                                                ),
                                                isDark: isDark,
                                              )
                                            : ListView.separated(
                                                key: ValueKey(
                                                  "list_${_filter}_${_month?.toIso8601String()}_${rows.length}",
                                                ),
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      10,
                                                      10,
                                                      10,
                                                      12,
                                                    ),
                                                itemCount: rows.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(height: 8),
                                                itemBuilder: (context, i) {
                                                  return _AttendanceRowTile(
                                                        isDark: isDark,
                                                        border: border,
                                                        row: rows[i],
                                                      )
                                                      .animate()
                                                      .fadeIn(
                                                        duration: 180.ms,
                                                        delay: (35 * i).ms,
                                                      )
                                                      .slideY(
                                                        begin: .06,
                                                        end: 0,
                                                        duration: 180.ms,
                                                        curve: Curves.easeOut,
                                                      );
                                                },
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 220.ms, delay: 80.ms).slideY(begin: .08, end: 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _activeFilterText() {
    final parts = <String>[];

    if (_month != null) {
      parts.add("Month: ${DateFormat("MMMM yyyy").format(_month!)}");
    }
    if (_filter != null) {
      parts.add(
        "Status: ${_filter == _AttendStatus.comeIn ? "Come in" : "Not come"}",
      );
    }

    return "Filter: ${parts.join("  •  ")}";
  }

  void _toggleFilter(_AttendStatus s) {
    setState(() {
      _filter = (_filter == s) ? null : s;
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    final selected = await showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final t = Theme.of(ctx);
        final isDark = t.brightness == Brightness.dark;

        final bg = isDark ? const Color(0xFF070B12) : Colors.white;
        final border = isDark
            ? Colors.white.withOpacity(.12)
            : Colors.black.withOpacity(.08);

        final now = DateTime.now();
        final months = List.generate(
          18,
          (i) => DateTime(now.year, now.month - i, 1),
        );

        String label(DateTime d) => DateFormat("MMMM yyyy").format(d);

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                  color: Colors.black.withOpacity(isDark ? .60 : .18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        (isDark
                                ? Colors.white.withOpacity(.18)
                                : Colors.black.withOpacity(.12))
                            .withOpacity(.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Select month",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text(
                          "All",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    itemCount: months.length + 1,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: border),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        final selectedAll = _month == null;
                        return ListTile(
                          onTap: () => Navigator.pop(ctx, null),
                          leading: Icon(
                            selectedAll
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                          ),
                          title: const Text(
                            "All months",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        );
                      }

                      final d = months[i - 1];
                      final selectedThis =
                          _month != null &&
                          _month!.year == d.year &&
                          _month!.month == d.month;

                      return ListTile(
                        onTap: () => Navigator.pop(ctx, d),
                        leading: Icon(
                          selectedThis
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                        ),
                        title: Text(
                          label(d),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    setState(() {
      _month = selected;
    });
  }

  List<_AttendanceRow> _demoRowsA() {
    final base = DateTime.now();
    return [
      _AttendanceRow(
        date: base,
        status: _AttendStatus.comeIn,
        reason: "Normal",
        note: null,
        checkIn: const TimeOfDay(hour: 7, minute: 55),
      ),
      _AttendanceRow(
        date: base.subtract(const Duration(days: 1)),
        status: _AttendStatus.notCome,
        reason: "Sick",
        note: "Parent called",
        checkIn: null,
      ),
      _AttendanceRow(
        date: base.subtract(const Duration(days: 2)),
        status: _AttendStatus.comeIn,
        reason: "Late",
        note: null,
        checkIn: const TimeOfDay(hour: 8, minute: 20),
      ),
      _AttendanceRow(
        date: base.subtract(const Duration(days: 3)),
        status: _AttendStatus.comeIn,
        reason: "Normal",
        note: null,
        checkIn: const TimeOfDay(hour: 7, minute: 58),
      ),
      _AttendanceRow(
        date: base.subtract(const Duration(days: 4)),
        status: _AttendStatus.notCome,
        reason: "Personal",
        note: "Travel",
        checkIn: null,
      ),
      _AttendanceRow(
        date: DateTime(base.year, base.month - 1, 18),
        status: _AttendStatus.comeIn,
        reason: "Normal",
        note: null,
        checkIn: const TimeOfDay(hour: 7, minute: 52),
      ),
      _AttendanceRow(
        date: DateTime(base.year, base.month - 2, 9),
        status: _AttendStatus.notCome,
        reason: "Sick",
        note: "Clinic",
        checkIn: null,
      ),
    ];
  }

  List<_AttendanceRow> _demoRowsB() {
    final base = DateTime.now();
    return [
      _AttendanceRow(
        date: base,
        status: _AttendStatus.comeIn,
        reason: "Normal",
        note: null,
        checkIn: const TimeOfDay(hour: 7, minute: 50),
      ),
      _AttendanceRow(
        date: base.subtract(const Duration(days: 1)),
        status: _AttendStatus.comeIn,
        reason: "Normal",
        note: null,
        checkIn: const TimeOfDay(hour: 7, minute: 53),
      ),
      _AttendanceRow(
        date: base.subtract(const Duration(days: 2)),
        status: _AttendStatus.notCome,
        reason: "Sick",
        note: "Fever",
        checkIn: null,
      ),
      _AttendanceRow(
        date: DateTime(base.year, base.month - 1, 2),
        status: _AttendStatus.comeIn,
        reason: "Late",
        note: null,
        checkIn: const TimeOfDay(hour: 8, minute: 10),
      ),
    ];
  }
}

// =====================
// Month picker row
// =====================
class _MonthPickerRow extends StatelessWidget {
  final bool isDark;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final DateTime? selectedMonth;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _MonthPickerRow({
    required this.isDark,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.selectedMonth,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final pillBg = isDark
        ? const Color(0xFF071A33).withOpacity(.55)
        : Colors.white;

    final label = selectedMonth == null
        ? "All months"
        : DateFormat("MMMM yyyy").format(selectedMonth!);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: textPrimary.withOpacity(.92),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: textMuted),
                ],
              ),
            ),
          ),
        ),
        if (selectedMonth != null) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              "Clear",
              style: TextStyle(fontWeight: FontWeight.w900, color: textPrimary),
            ),
          ),
        ],
      ],
    );
  }
}

// =====================
// Student info bar
// =====================
class _StudentInfoBar extends StatelessWidget {
  final bool isDark;
  final Color border;
  final String studentText;

  const _StudentInfoBar({
    required this.isDark,
    required this.border,
    required this.studentText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF071A33).withOpacity(.45)
        : const Color(0xFFF2F4FF);
    final fg = isDark ? Colors.white.withOpacity(.92) : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 18, color: fg.withOpacity(.90)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              studentText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// Panel (รองรับ gradient)
// =====================
class _Panel extends StatelessWidget {
  final bool isDark;
  final Color? color;
  final Gradient? gradient;
  final Color border;
  final Color shadow;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const _Panel({
    required this.isDark,
    required this.border,
    required this.shadow,
    required this.child,
    this.color,
    this.gradient,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: child,
    );
  }
}

// =====================
// Models
// =====================
class _StudentInfo {
  final String id;
  final String name;

  const _StudentInfo({required this.id, required this.name});
}

enum _AttendStatus { comeIn, notCome }

class _AttendanceRow {
  final DateTime date;
  final _AttendStatus status;
  final String reason;
  final String? note;
  final TimeOfDay? checkIn;

  const _AttendanceRow({
    required this.date,
    required this.status,
    required this.reason,
    required this.note,
    required this.checkIn,
  });

  String get dateText => DateFormat("yyyy/MM/dd").format(date);

  String get checkInText {
    final t = checkIn;
    if (t == null) return "";
    final hh = t.hour.toString().padLeft(2, "0");
    final mm = t.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }
}

// =====================
// UI pieces
// =====================
class _StatCard extends StatefulWidget {
  final bool isDark;
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.isDark,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    final bg = selected
        ? widget.color.withOpacity(widget.isDark ? .28 : .20)
        : (widget.isDark
              ? const Color(0xFF071A33).withOpacity(.45)
              : const Color(0xFFFFFFFF));

    final borderC = selected
        ? widget.color.withOpacity(.95)
        : (widget.isDark
              ? Colors.white.withOpacity(.14)
              : Colors.black.withOpacity(.06));

    final titleColor = selected
        ? Colors.white.withOpacity(.92)
        : (widget.isDark
              ? Colors.white.withOpacity(.86)
              : const Color(0xFF111827));

    final valueColor = selected
        ? Colors.white
        : (widget.isDark ? Colors.white : const Color(0xFF111827));

    final iconBubbleBg = selected
        ? Colors.white.withOpacity(widget.isDark ? .18 : .30)
        : widget.color.withOpacity(widget.isDark ? .22 : .14);

    final iconColor = selected ? Colors.white : widget.color;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: 120.ms,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: 200.ms,
            curve: Curves.easeOut,
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderC, width: selected ? 1.4 : 1.0),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                        color: widget.color.withOpacity(
                          widget.isDark ? .20 : .18,
                        ),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBubbleBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "${widget.value}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: valueColor,
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

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF071A33).withOpacity(.40)
        : const Color(0xFFF7F8FA);

    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);

    final c = isDark ? Colors.white.withOpacity(.80) : const Color(0xFF6B7280);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: c),
            const SizedBox(width: 10),
            Text(
              "No records found",
              style: TextStyle(fontWeight: FontWeight.w900, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final bool isDark;
  final Color border;
  final Color textMuted;

  const _TableHeader({
    required this.isDark,
    required this.border,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF071A33).withOpacity(.35)
        : const Color(0xFFF2F4FF);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          _HeadCell("Date", flex: 12, color: textMuted),
          _HeadCell("Reason", flex: 14, color: textMuted),
          _HeadCell("Note", flex: 16, color: textMuted),
          _HeadCell("Status", flex: 12, color: textMuted, alignRight: true),
        ],
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  final String text;
  final int flex;
  final Color color;
  final bool alignRight;

  const _HeadCell(
    this.text, {
    required this.flex,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: .2,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AttendanceRowTile extends StatelessWidget {
  final bool isDark;
  final Color border;
  final _AttendanceRow row;

  const _AttendanceRowTile({
    required this.isDark,
    required this.border,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final isCome = row.status == _AttendStatus.comeIn;

    const green = Color(0xFF22C55E);
    const red = Color(0xFFEF4444);

    final chipColor = isCome ? green : red;
    final chipBg = chipColor.withOpacity(isDark ? .18 : .12);

    final noteText = isCome ? "" : (row.note ?? "");
    final isLate = row.reason.trim().toLowerCase() == "late";
    final reasonColorOverride = isLate ? red : null;

    final tileBg = isDark
        ? const Color(0xFF071A33).withOpacity(.35)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BodyCell(row.dateText, flex: 12, isDark: isDark),
          _BodyCell(
            row.reason,
            flex: 14,
            isDark: isDark,
            colorOverride: reasonColorOverride,
          ),
          _BodyCell(noteText, flex: 16, isDark: isDark, mutedIfEmpty: true),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: chipColor.withOpacity(.55)),
                    ),
                    child: Text(
                      isCome ? "Come in" : "Not come",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.3,
                        color: chipColor,
                      ),
                    ),
                  ),
                  if (isCome && row.checkIn != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Check-in ${row.checkInText}",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: isDark
                            ? Colors.white.withOpacity(.78)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isDark;
  final bool mutedIfEmpty;
  final Color? colorOverride;

  const _BodyCell(
    this.text, {
    required this.flex,
    required this.isDark,
    this.mutedIfEmpty = false,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = text.trim().isEmpty;

    Color baseColor;
    if (colorOverride != null) {
      baseColor = colorOverride!;
    } else if (isEmpty && mutedIfEmpty) {
      baseColor = isDark
          ? Colors.white.withOpacity(.25)
          : const Color(0xFF9CA3AF);
    } else {
      baseColor = isDark ? Colors.white : const Color(0xFF111827);
    }

    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          height: 1.15,
          color: baseColor,
        ),
      ),
    );
  }
}
