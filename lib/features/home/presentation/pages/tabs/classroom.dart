// classroom_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ✅ ปรับ path ให้ตรงโปรเจกต์คุณ
import '../../../../../core/widgets/app_page_template.dart';

// =====================
// Models (bind real data later)
// =====================

enum HomeworkStatus { submitted, pending }

class HomeworkItem {
  final String subject;
  final String grade; // e.g. M.2 / ມ.2
  final HomeworkStatus status;
  final double? score;
  final DateTime? sentAt;
  final DateTime deadline;

  const HomeworkItem({
    required this.subject,
    required this.grade,
    required this.status,
    this.score,
    this.sentAt,
    required this.deadline,
  });
}

class ScheduleClass {
  final String subject;
  final String time1;
  final String time2;
  final String teacher;

  const ScheduleClass({
    required this.subject,
    required this.time1,
    required this.time2,
    required this.teacher,
  });
}

class DaySchedule {
  final String day; // ຈັນ-ສຸກ / Mon-Fri
  final List<ScheduleClass> classes;

  const DaySchedule({required this.day, required this.classes});
}

class ClassroomData {
  final String roomName;
  final String homeroomTeacherTitle;
  final String homeroomTeacherName;
  final List<DaySchedule> scheduleMonFri;
  final List<HomeworkItem> homeworks;

  const ClassroomData({
    required this.roomName,
    required this.homeroomTeacherTitle,
    required this.homeroomTeacherName,
    required this.scheduleMonFri,
    required this.homeworks,
  });
}

// =====================
// Page (NO Bottom Bar)
// =====================

class ClassroomPage extends StatefulWidget {
  final ClassroomData? data;
  const ClassroomPage({super.key, this.data});

  static const _bgAsset = "assets/images/homepagewall/mainbg.jpeg";

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  int _filter = 0; // 0=all, 1=not sent, 2=done
  late final ClassroomData _data = widget.data ?? _mock();

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final done = data.homeworks
        .where((h) => h.status == HomeworkStatus.submitted)
        .length;
    final notSent = data.homeworks.length - done;

    final list = _filter == 0
        ? data.homeworks
        : _filter == 1
        ? data.homeworks
              .where((h) => h.status == HomeworkStatus.pending)
              .toList()
        : data.homeworks
              .where((h) => h.status == HomeworkStatus.submitted)
              .toList();

    final ratio = data.homeworks.isEmpty ? 0.0 : done / data.homeworks.length;

    return AppPageTemplate(
      title: "Classroom",
      backgroundAsset: ClassroomPage._bgAsset,
      showBack: true,
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
                roomName: data.roomName,
                teacherTitle: data.homeroomTeacherTitle,
                teacherName: data.homeroomTeacherName,
              )
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 14),

          _ScheduleButtonsCard(schedule: data.scheduleMonFri)
              .animate()
              .fadeIn(duration: 260.ms, delay: 60.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child:
                    Text(
                          "Homework",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? _DarkTokens.on : Colors.black87,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 220.ms, delay: 90.ms)
                        .slideX(begin: 0.03, end: 0),
              ),
              Text(
                    "All ${data.homeworks.length} • Done $done • Not sent $notSent",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? _DarkTokens.onMuted : Colors.black54,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 220.ms, delay: 120.ms)
                  .slideX(begin: 0.03, end: 0),
            ],
          ),

          const SizedBox(height: 10),

          _ProgressBar(ratio: ratio)
              .animate()
              .fadeIn(duration: 220.ms, delay: 150.ms)
              .slideX(begin: 0.03, end: 0),

          const SizedBox(height: 12),

          _FilterRow(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              )
              .animate()
              .fadeIn(duration: 220.ms, delay: 180.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final hw = list[i];
              return _HomeworkCard(item: hw)
                  .animate()
                  .fadeIn(duration: 220.ms, delay: (220 + i * 70).ms)
                  .slideY(begin: 0.07, end: 0, curve: Curves.easeOutCubic);
            },
          ),
        ],
      ),
    );
  }

  ClassroomData _mock() {
    final now = DateTime.now();
    return ClassroomData(
      roomName: "ຫ້ອງຮຽນ ມ.2/3",
      homeroomTeacherTitle: "ອາຈານປະຈໍາຫ້ອງ",
      homeroomTeacherName: "ອ. ສົມຫຍິງ ໃຈດີ",
      scheduleMonFri: const [
        DaySchedule(
          day: "ຈັນ",
          classes: [
            ScheduleClass(
              subject: "ວິຊາ ພາສາອັງກິດ",
              time1: "08:00-10:00 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
            ScheduleClass(
              subject: "ວິຊາ ພາສາລາວ",
              time1: "08:00-10:00 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
            ScheduleClass(
              subject: "ວິຊາ ຄະນິດສາດ",
              time1: "08:00-10:00 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
          ],
        ),
        DaySchedule(
          day: "ອັງຄານ",
          classes: [
            ScheduleClass(
              subject: "ວິຊາ ວິທະຍາສາດ",
              time1: "08:00-09:30 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
            ScheduleClass(
              subject: "ວິຊາ ສັງຄົມ",
              time1: "09:30-11:00 AM",
              time2: "14:00-15:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
          ],
        ),
        DaySchedule(
          day: "ພຸດ",
          classes: [
            ScheduleClass(
              subject: "English",
              time1: "08:00-09:00 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
            ScheduleClass(
              subject: "Science",
              time1: "09:00-10:00 AM",
              time2: "14:00-15:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
          ],
        ),
        DaySchedule(
          day: "ພະຫັດ",
          classes: [
            ScheduleClass(
              subject: "Computer",
              time1: "08:00-10:00 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
          ],
        ),
        DaySchedule(
          day: "ສຸກ",
          classes: [
            ScheduleClass(
              subject: "Math",
              time1: "08:00-10:00 AM",
              time2: "13:00-14:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
            ScheduleClass(
              subject: "Activity",
              time1: "10:00-11:00 AM",
              time2: "14:00-15:00 PM",
              teacher: "Chanthasone Xaymani",
            ),
          ],
        ),
      ],
      homeworks: [
        HomeworkItem(
          subject: "Mathematics",
          grade: "M.2",
          status: HomeworkStatus.submitted,
          score: 9.5,
          sentAt: now.subtract(const Duration(hours: 20)),
          deadline: now.add(const Duration(days: 1)),
        ),
        HomeworkItem(
          subject: "English",
          grade: "M.2",
          status: HomeworkStatus.pending,
          deadline: now.add(const Duration(days: 2, hours: 3)),
        ),
        HomeworkItem(
          subject: "Science",
          grade: "M.2",
          status: HomeworkStatus.submitted,
          score: 8.0,
          sentAt: now.subtract(const Duration(days: 1, hours: 2)),
          deadline: now.add(const Duration(days: 3)),
        ),
        HomeworkItem(
          subject: "Thai",
          grade: "M.2",
          status: HomeworkStatus.pending,
          deadline: now.add(const Duration(hours: 14)),
        ),
      ],
    );
  }
}

// =====================
// Dark tokens + Glass surface (balance dark mode)
// =====================

class _DarkTokens {
  static const panelA = Color(0xFF0B2B5B);
  static const panelB = Color(0xFF071A33);
  static const panelC = Color(0xFF060B16);

  static Color border = Colors.white.withOpacity(.12);
  static Color shadow = Colors.black.withOpacity(.45);

  static Color on = Colors.white.withOpacity(.92);
  static Color onMuted = Colors.white.withOpacity(.72);
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// ✅ tint แบบ “จางเหมือนรูปตัวอย่าง”
  final Color? tint;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color blend(Color base, double amt) {
      final t = tint;
      if (t == null) return base;
      return Color.lerp(base, t, amt) ?? base;
    }

    final border = isDark ? _DarkTokens.border : Colors.black.withOpacity(.08);

    if (isDark) {
      final g1 = blend(_DarkTokens.panelA, .10).withOpacity(.72);
      final g2 = blend(_DarkTokens.panelB, .08).withOpacity(.86);
      final g3 = blend(_DarkTokens.panelC, .05).withOpacity(.92);

      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g1, g2, g3],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                  color: _DarkTokens.shadow,
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    }

    // light glass
    final baseTop = Colors.white.withOpacity(.92);
    final baseBottom = Colors.white.withOpacity(.78);
    final t = tint;
    final tintTop = t == null
        ? baseTop
        : (Color.lerp(baseTop, t, .06) ?? baseTop);
    final tintBottom = t == null
        ? baseBottom
        : (Color.lerp(baseBottom, t, .04) ?? baseBottom);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tintTop, tintBottom],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                offset: const Offset(0, 12),
                color: Colors.black.withOpacity(.10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModernChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color fg;
  final Color bg;
  final Color stroke;

  const _ModernChip({
    required this.text,
    this.icon,
    required this.fg,
    required this.bg,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// Widgets
// =====================

class _InfoCard extends StatelessWidget {
  final String roomName;
  final String teacherTitle;
  final String teacherName;

  const _InfoCard({
    required this.roomName,
    required this.teacherTitle,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.08),
            ),
            child: Icon(
              Icons.meeting_room_rounded,
              color: isDark ? _DarkTokens.on : Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Room",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? _DarkTokens.onMuted : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roomName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? _DarkTokens.on : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 18,
                      color: isDark ? _DarkTokens.onMuted : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "$teacherTitle • $teacherName",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? _DarkTokens.on : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleButtonsCard extends StatelessWidget {
  final List<DaySchedule> schedule;
  const _ScheduleButtonsCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: isDark ? _DarkTokens.onMuted : Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                "Schedule",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? _DarkTokens.on : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                "${schedule.length} days",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDark ? _DarkTokens.onMuted : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedule.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.70,
            ),
            itemBuilder: (context, i) {
              final d = schedule[i];
              final label = _dayShort(d.day);
              return _DayButton(
                    label: label,
                    onTap: () => _openDaySheet(context, d),
                  )
                  .animate()
                  .fadeIn(duration: 200.ms, delay: (40 + i * 60).ms)
                  .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic);
            },
          ),
        ],
      ),
    );
  }

  void _openDaySheet(BuildContext context, DaySchedule d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => _ScheduleDetailSheet(daySchedule: d),
    );
  }

  String _dayShort(String day) {
    final s = day.trim();

    const laoMap = {
      "ຈັນ": "ຈັນ",
      "ອັງ": "ອັງຄານ",
      "ອັງຄານ": "ອັງຄານ",
      "ພຸດ": "ພຸດ",
      "ພະຫັດ": "ພະຫັດ",
      "ສຸກ": "ສຸກ",
    };
    if (laoMap.containsKey(s)) return laoMap[s]!;

    if (s.contains("จันทร์")) return "ຈັນ";
    if (s.contains("อังคาร")) return "ອັງຄານ";
    if (s.contains("พุธ")) return "ພຸດ";
    if (s.contains("พฤหัส")) return "ພະຫັດ";
    if (s.contains("ศุกร์")) return "ສຸກ";

    final lower = s.toLowerCase();
    if (lower.startsWith("mon")) return "ຈັນ";
    if (lower.startsWith("tue")) return "ອັງຄານ";
    if (lower.startsWith("wed")) return "ພຸດ";
    if (lower.startsWith("thu")) return "ພະຫັດ";
    if (lower.startsWith("fri")) return "ສຸກ";

    return s;
  }
}

class _DayButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _DayButton({required this.label, required this.onTap});

  @override
  State<_DayButton> createState() => _DayButtonState();
}

class _DayButtonState extends State<_DayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.80);
    final stroke = isDark
        ? Colors.white.withOpacity(.16)
        : Colors.black.withOpacity(.10);
    final textC = isDark ? _DarkTokens.on : const Color(0xFF0F172A);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: 120.ms,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: stroke),
              color: bg,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textC,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================
// Overlay (clean + easy)
// =====================

class _ScheduleDetailSheet extends StatelessWidget {
  final DaySchedule daySchedule;
  const _ScheduleDetailSheet({required this.daySchedule});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(.12)
                      : Colors.black.withOpacity(.10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? const Color(0xFF0B1220) : Colors.white)
                        .withOpacity(isDark ? .94 : .90),
                    (isDark ? const Color(0xFF0B1220) : Colors.white)
                        .withOpacity(isDark ? .86 : .82),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 30,
                    offset: const Offset(0, -12),
                    color: Colors.black.withOpacity(isDark ? .40 : .14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                "Schedule",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? _DarkTokens.on
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _Pill(text: daySchedule.day, isDark: isDark),
                              const SizedBox(width: 10),
                              _Pill(
                                text: "${daySchedule.classes.length} classes",
                                isDark: isDark,
                                subtle: true,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark
                                ? _DarkTokens.onMuted
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: daySchedule.classes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final c = daySchedule.classes[i];
                          return _ScheduleClassCard(item: c)
                              .animate()
                              .fadeIn(duration: 200.ms, delay: (60 + i * 70).ms)
                              .slideY(
                                begin: 0.06,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.10, end: 0),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool subtle;
  const _Pill({required this.text, required this.isDark, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(subtle ? .08 : .12)
        : Colors.black.withOpacity(subtle ? .05 : .06);
    final stroke = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.08);
    final fg = isDark ? _DarkTokens.on : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stroke),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

class _ScheduleClassCard extends StatelessWidget {
  final ScheduleClass item;
  const _ScheduleClassCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.white.withOpacity(.96);
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.08);

    final labelC = isDark ? _DarkTokens.onMuted : Colors.black54;
    final valueC = isDark ? _DarkTokens.on : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.subject,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueC,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 18, color: labelC),
              const SizedBox(width: 8),
              Text(
                "Teacher",
                style: TextStyle(fontWeight: FontWeight.w800, color: labelC),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.teacher,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark ? _DarkTokens.on : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeBlock(
                  title: "Time 1",
                  value: item.time1,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBlock(
                  title: "Time 2",
                  value: item.time2,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String title;
  final String value;
  final bool isDark;

  const _TimeBlock({
    required this.title,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.04);
    final stroke = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);
    final labelC = isDark ? _DarkTokens.onMuted : Colors.black54;
    final valueC = isDark ? _DarkTokens.on : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: labelC),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w900, color: labelC),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: valueC),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _FilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget seg(String label, int v, IconData icon) {
      final active = value == v;

      final fg = active
          ? (isDark ? _DarkTokens.on : Colors.black87)
          : (isDark ? _DarkTokens.onMuted : Colors.black54);

      final bg = active
          ? (isDark
                ? Colors.white.withOpacity(.16)
                : Colors.white.withOpacity(.85))
          : (isDark
                ? Colors.white.withOpacity(.08)
                : Colors.white.withOpacity(.60));

      final stroke = active
          ? (isDark
                ? Colors.white.withOpacity(.22)
                : Colors.black.withOpacity(.10))
          : (isDark
                ? Colors.white.withOpacity(.10)
                : Colors.black.withOpacity(.08));

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: 220.ms,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: stroke),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w900, color: fg),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg("All", 0, Icons.grid_view_rounded),
        const SizedBox(width: 10),
        seg("Not sent", 1, Icons.error_outline_rounded),
        const SizedBox(width: 10),
        seg("Done", 2, Icons.verified_rounded),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double ratio;
  const _ProgressBar({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: bg,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth * ratio.clamp(0.0, 1.0);
            return Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: 360.ms,
                width: w,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF22C55E),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================
// Homework (pale like sample image)
// =====================

class _HomeworkCard extends StatelessWidget {
  final HomeworkItem item;
  const _HomeworkCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = item.status == HomeworkStatus.submitted;

    final doneFg = const Color(0xFF16A34A);
    final doneBg = const Color(0xFF16A34A).withOpacity(isDark ? .16 : .09);

    final redFg = const Color(0xFFDC2626);
    final redBg = const Color(0xFFDC2626).withOpacity(isDark ? .16 : .09);

    final tint = isDone ? doneFg : redFg;

    return _GlassCard(
      tint: tint,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.subject,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? _DarkTokens.on : Colors.black87,
                  ),
                ),
              ),
              _ModernChip(
                text: isDone ? "DONE" : "NOT SENT",
                icon: isDone
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                fg: isDone ? doneFg : redFg,
                bg: isDone ? doneBg : redBg,
                stroke: (isDone ? doneFg : redFg).withOpacity(.26),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaChip(
                label: "GRADE",
                value: item.grade,
                icon: Icons.class_rounded,
              ),
              _MetaChip(
                label: "SCORE",
                value: item.score == null
                    ? "-"
                    : item.score!.toStringAsFixed(1),
                icon: Icons.bar_chart_rounded,
              ),
              _MetaChip(
                label: "SENT",
                value: item.sentAt == null ? "-" : _fmt(item.sentAt!),
                icon: Icons.send_rounded,
              ),
              _MetaChip(
                label: "DUE",
                value: _fmt(item.deadline),
                icon: Icons.alarm_rounded,
                emphasize: !isDone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;

  const _MetaChip({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.04);
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);

    final labelColor = isDark ? _DarkTokens.onMuted : Colors.black54;
    final valueColor = emphasize
        ? (isDark ? _DarkTokens.on : Colors.black87)
        : (isDark ? _DarkTokens.on : Colors.black87);

    final accent = emphasize
        ? const Color(0xFFDC2626)
        : (isDark ? _DarkTokens.onMuted : Colors.black54);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(fontWeight: FontWeight.w800, color: labelColor),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: valueColor),
          ),
        ],
      ),
    );
  }
}
