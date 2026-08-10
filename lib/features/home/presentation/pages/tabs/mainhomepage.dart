import 'dart:async';
import 'dart:ui';
import 'home_skeleton.dart';
import 'menu_reads_service.dart';

import 'package:alpha_school/core/widgets/scanqrcode/scan_qr_code_page.dart';
import 'package:alpha_school/features/demo/DemoTest.dart';
import 'package:alpha_school/features/home/presentation/pages/appointment/appointment_page.dart';
import 'package:alpha_school/features/home/presentation/pages/appointment/appointment_service.dart';
import 'package:alpha_school/features/home/presentation/pages/attendance/attendance_page.dart';
import 'package:alpha_school/features/home/presentation/pages/attendance/attendance_service.dart';
import 'package:alpha_school/features/home/presentation/pages/calendar/calendar_page.dart';
import 'package:alpha_school/features/home/presentation/pages/calendar/calendar_year.dart';
import 'package:alpha_school/features/home/presentation/pages/contact/contact_page.dart';
import 'package:alpha_school/features/home/presentation/pages/gallery/gallery_page.dart';
import 'package:alpha_school/features/home/presentation/pages/homework/homework_page.dart';
import 'package:alpha_school/features/home/presentation/pages/homework/homework_service.dart';
import 'package:alpha_school/features/home/presentation/pages/news/news_page.dart';
import 'package:alpha_school/features/home/presentation/pages/notifications/notifications_page.dart';
import 'package:alpha_school/features/home/presentation/pages/participant/participant_page.dart';
import 'package:alpha_school/features/home/presentation/pages/participant/participant_service.dart';
import 'package:alpha_school/features/home/presentation/pages/profile/profile.dart';
import 'package:alpha_school/features/home/presentation/pages/saving/saving_page.dart';
import 'package:alpha_school/features/home/presentation/pages/task/parent_task_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:remixicon/remixicon.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/models/student_card_item.dart';

class ExplorePage extends StatefulWidget {
  final StudentCardItem? selectedStudent;
  final VoidCallback? onSwitchStudent;
  final bool switchingStudent;

  const ExplorePage({
    super.key,
    this.selectedStudent,
    this.onSwitchStudent,
    this.switchingStudent = false,
  });

  static const _bgAsset = "assets/images/homepagewall/homepagewallpaper.jpg";
  static const _profileAvatarAsset = "assets/images/profile/me.jpg";

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final GlobalKey _bellKey = GlobalKey();
  final _attendanceService = AttendanceService();
  final _participantService = ParticipantService();
  final _menuReadsService = MenuReadsService();

  late List<_NotificationItem> _notifications;

  bool _checkedIn = false;
  bool _isLate = false;
  TimeOfDay? _checkinTime;

  double _participantPercent = 0.0;
  int _unreadHomework = 0;
  int _unreadAppointments = 0;
  List<String> _homeworkIds = const [];
  List<String> _appointmentIds = const [];
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
    _loadLatestParticipantScore();
    _loadMenuUnreadCounts();

    final now = DateTime.now();
    _notifications = [
      _NotificationItem(
        sender: "Alpha School",
        title: "ປະກາດສຳຄັນ",
        body: "ພົບກັນໃນການປະຊຸມຜູ້ປົກຄອງວັນສຸກ 15:00",
        time: now.subtract(const Duration(minutes: 18)),
        isUnread: true,
      ),
      _NotificationItem(
        sender: "Teacher - Ms. Lina",
        title: "ວຽກບ້ານ",
        body: "ສົ່ງວຽກບ້ານຄະນິດສາດ ກ່ອນ 18:00",
        time: now.subtract(const Duration(hours: 9)),
        isUnread: true,
      ),
      _NotificationItem(
        sender: "Finance Office",
        title: "ແຈ້ງເຕືອນຄ່າຮຽນ",
        body: "ກະລຸນາຊຳລະຄ່າຮຽນກ່ອນວັນທີ 28",
        time: now.subtract(const Duration(days: 1, hours: 3)),
        isUnread: false,
      ),
      _NotificationItem(
        sender: "Library",
        title: "ຄືນປຶ້ມ",
        body: "ປຶ້ມທີ່ຢືມຈະຄົບກຳນົດໃນ 2 ມື້",
        time: now.subtract(const Duration(days: 3, hours: 2)),
        isUnread: false,
      ),
    ];
  }

  String get _studentReadKey =>
      widget.selectedStudent?.id ?? widget.selectedStudent?.studentId ?? 'none';

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey =
        oldWidget.selectedStudent?.id ??
        oldWidget.selectedStudent?.studentId ??
        'none';
    if (oldKey != _studentReadKey) {
      setState(() => _isInitialLoading = true);
      _loadMenuUnreadCounts();
    }
  }

  Future<void> _loadMenuUnreadCounts() async {
    final student = widget.selectedStudent;
    final sid = student?.id;
    if (student == null || sid == null || sid.isEmpty) {
      if (mounted) {
        setState(() {
          _unreadHomework = 0;
          _unreadAppointments = 0;
          _homeworkIds = const [];
          _appointmentIds = const [];
          _isInitialLoading = false;
        });
      }
      return;
    }

    final keyAtFetch = _studentReadKey;

    try {
      final results = await Future.wait([
        HomeworkService().fetchForStudent(
          studentId: student.id,
          branchId: student.branchId,
          classId: student.classId,
        ),
        AppointmentService().fetchAppointments(),
        _menuReadsService.fetchReadIds(studentId: sid, resource: 'homework'),
        _menuReadsService.fetchReadIds(studentId: sid, resource: 'appointment'),
      ]);

      // Bail out if the student switched while we were fetching.
      if (!mounted || keyAtFetch != _studentReadKey) return;

      final homeworkIds = (results[0] as List)
          .map((item) => item.id as String)
          .toList();
      final appointmentIds = (results[1] as List)
          .map((item) => item.id as String)
          .toList();
      final readHomework = (results[2] as List<String>).toSet();
      final readAppointments = (results[3] as List<String>).toSet();

      setState(() {
        _homeworkIds = homeworkIds;
        _appointmentIds = appointmentIds;
        _unreadHomework = homeworkIds
            .where((id) => !readHomework.contains(id))
            .length;
        _unreadAppointments = appointmentIds
            .where((id) => !readAppointments.contains(id))
            .length;
      });
    } catch (_) {
      // Menu badges are non-blocking.
    } finally {
      if (mounted && keyAtFetch == _studentReadKey) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  /// Marks the currently-known item ids as read on the server and
  /// optimistically clears the badge.
  Future<void> _markMenuRead(String menu) async {
    final student = widget.selectedStudent;
    final sid = student?.id;
    if (student == null || sid == null || sid.isEmpty) return;

    if (menu == 'homework') {
      if (mounted) setState(() => _unreadHomework = 0);
      await _menuReadsService.markRead(
        studentId: sid,
        resource: 'homework',
        resourceIds: List<String>.from(_homeworkIds),
      );
    } else if (menu == 'appointments') {
      if (mounted) setState(() => _unreadAppointments = 0);
      await _menuReadsService.markRead(
        studentId: sid,
        resource: 'appointment',
        resourceIds: List<String>.from(_appointmentIds),
      );
    }
  }

  /// Loads the selected student's check-in status/time for today from
  /// `GET /attendances`. Failures (including "no selected student" / "no
  /// record yet for today") are swallowed and simply leave the card showing
  /// its "Not Checked-In" default -- a flaky fetch shouldn't block the page.
  Future<void> _loadTodayAttendance() async {
    final student = widget.selectedStudent;
    if (student == null) return;

    try {
      final attendance = await _attendanceService.fetchTodayAttendance(student);
      if (!mounted || attendance == null) return;

      setState(() {
        _checkedIn = attendance.checkedIn;
        _isLate = attendance.isLate;
        _checkinTime = attendance.checkinTime;
      });
    } catch (_) {
      // Keep the default "Not Checked-In" state on failure.
    }
  }

  /// Loads the selected student's latest day participation total (0–1) for the
  /// home tile. Failures leave the percent at 0.
  Future<void> _loadLatestParticipantScore() async {
    final student = widget.selectedStudent;
    if (student == null) return;

    try {
      final summary = await _participantService.fetchSummary(student);
      if (!mounted) return;
      setState(() {
        _participantPercent = (summary.latestPercent / 100).clamp(0.0, 1.0);
      });
    } catch (_) {
      // Keep 0 on failure.
    }
  }

  void _markAllRead() {
    setState(() {
      _notifications = _notifications
          .map((e) => e.copyWith(isUnread: false))
          .toList();
    });
  }

  int get _unreadCount => _notifications.where((e) => e.isUnread).length;

  // ✅ ตามที่คุณต้องการ: View all -> notifications_page.dart
  void _openAllNotifications() {
    final items = _notifications
        .map(
          (n) => NotificationEntry.fromPopup(
            sender: n.sender,
            title: n.title,
            body: n.body,
            time: n.time,
            isUnread: n.isUnread,
          ),
        )
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationDetailsPage(items: items)),
    );
  }

  void _showNotificationPopup() {
    final overlay = Overlay.of(context);
    final renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || renderBox == null) return;

    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final bellSize = renderBox.size;
    final bellTopLeft = renderBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );

    final double screenW = MediaQuery.of(context).size.width;
    final double maxW = (screenW * 0.86).clamp(280.0, 380.0);

    final double top = bellTopLeft.dy + bellSize.height + 10;
    double left = (bellTopLeft.dx + bellSize.width) - maxW;
    left = left.clamp(12.0, screenW - maxW - 12.0);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return _NotificationPopupOverlay(
          top: top,
          left: left,
          width: maxW,
          items: _notifications,
          onViewAll: () {
            _openAllNotifications();
          },
          onClosed: () {
            entry.remove();
            _markAllRead();
          },
        );
      },
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const HomeSkeleton();
    }

    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final today = DateTime.now();
    final bool checkedIn = _checkedIn;
    final bool isLate = _isLate;
    final TimeOfDay? checkinTime = _checkinTime;

    final student = widget.selectedStudent;
    final studentName = student?.name.trim().isNotEmpty == true
        ? student!.name.trim()
        : "Student";
    final studentClass = student?.className?.trim().isNotEmpty == true
        ? student!.className!.trim()
        : "Class not assigned";

    void go(Widget page) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    void openProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfilePage(student: widget.selectedStudent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final isSmallPhone = w < 360;
          final isTablet = w >= 600 && w < 1024;
          final isLargeTablet = w >= 1024;

          double clamp(double v, double min, double max) =>
              v.clamp(min, max).toDouble();
          final s = clamp(w / 375.0, 0.88, 1.35);

          final pagePadH = (isTablet || isLargeTablet) ? 22.0 : 18.0;
          final topPad = isSmallPhone ? 8.0 : 10.0;

          final gapAfterTopbar = isSmallPhone ? 8.0 : 12.0;
          final gapBetweenCards = isSmallPhone ? 8.0 : 12.0;

          final topCardH = isSmallPhone ? 170.0 : (isTablet ? 200.0 : 190.0);
          final miniCardH = isSmallPhone ? 82.0 : 96.0;

          final avatarRadius = isSmallPhone ? 20.0 : 24.0;
          final avatarIconSize = isSmallPhone ? 18.0 : 22.0;

          final topBtnSize = isSmallPhone ? 40.0 : 44.0;
          final topBtnIcon = isSmallPhone ? 18.0 : 20.0;

          final bgBlur = isSmallPhone ? 7.0 : 8.0;
          final headerBlur = isSmallPhone ? 14.0 : 16.0;
          final miniBlur = isSmallPhone ? 12.0 : 14.0;
          final sheetBlur = isSmallPhone ? 16.0 : 18.0;

          final topBarH = (avatarRadius * 2) + 6;
          final desiredHeader =
              topPad +
              topBarH +
              gapAfterTopbar +
              topCardH +
              gapBetweenCards +
              miniCardH;

          final headerMax = clamp(
            h * (isSmallPhone ? 0.62 : 0.58),
            280.0,
            520.0,
          );
          final headerH = clamp(desiredHeader, 280.0, headerMax);

          final bottomInset = MediaQuery.of(context).padding.bottom;

          return SizedBox(
            height: h,
            width: w,
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      Image.asset(
                            ExplorePage._bgAsset,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            alignment: Alignment.topCenter,
                          )
                          .animate()
                          .fadeIn(duration: 260.ms)
                          .scale(
                            begin: const Offset(1.02, 1.02),
                            end: const Offset(1, 1),
                            duration: 480.ms,
                            curve: Curves.easeOutCubic,
                          ),
                ),

                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: bgBlur, sigmaY: bgBlur),
                    child: const SizedBox.shrink(),
                  ),
                ),

                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(isDark ? .22 : .16),
                          Colors.black.withOpacity(isDark ? .38 : .28),
                          Colors.black.withOpacity(isDark ? .54 : .42),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        Positioned(
                          top: isSmallPhone ? -100.0 : -120.0,
                          left: isSmallPhone ? -70.0 : -90.0,
                          child: _GlowBlob(
                            size: (isSmallPhone ? 240.0 : 280.0) * s,
                            color: Colors.white.withOpacity(.10),
                          ),
                        ),
                        Positioned(
                          top: isSmallPhone ? 20.0 : 30.0,
                          right: isSmallPhone ? -95.0 : -120.0,
                          child: _GlowBlob(
                            size: (isSmallPhone ? 280.0 : 320.0) * s,
                            color: Colors.white.withOpacity(.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerH,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            pagePadH,
                            topPad,
                            pagePadH,
                            0.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InkResponse(
                                        onTap: openProfile,
                                        radius: avatarRadius + 12,
                                        child: Container(
                                          width: avatarRadius * 2,
                                          height: avatarRadius * 2,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white24,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                .20,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              ExplorePage._profileAvatarAsset,
                                              fit: BoxFit.cover,
                                              filterQuality: FilterQuality.high,
                                              errorBuilder: (_, __, ___) =>
                                                  Center(
                                                    child: FaIcon(
                                                      FontAwesomeIcons.user,
                                                      color: Colors.white,
                                                      size: avatarIconSize,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 220.ms)
                                      .scale(
                                        begin: const Offset(.9, .9),
                                        end: const Offset(1, 1),
                                        curve: Curves.easeOutBack,
                                        duration: 260.ms,
                                      ),
                                  SizedBox(width: isSmallPhone ? 10 : 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          studentName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: isSmallPhone ? 13.5 : 15,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          studentClass,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              .75,
                                            ),
                                            fontWeight: FontWeight.w800,
                                            fontSize: isSmallPhone ? 11.0 : 12,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(
                                    delay: 60.ms,
                                    duration: 220.ms,
                                  ),

                                  // ✅ BELL + badge + popup (adaptive popup)
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _TopIconButton(
                                            key: _bellKey,
                                            icon: FontAwesomeIcons.bell,
                                            onTap: _showNotificationPopup,
                                            size: topBtnSize,
                                            iconSize: topBtnIcon,
                                          )
                                          .animate()
                                          .fadeIn(
                                            delay: 100.ms,
                                            duration: 220.ms,
                                          )
                                          .slideX(begin: .15, end: 0),

                                      if (_unreadCount > 0)
                                        Positioned(
                                          right: 8,
                                          top: 7,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFFFF3B30),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  .92,
                                                ),
                                                width: 1.3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                  color: Colors.black
                                                      .withOpacity(.25),
                                                ),
                                              ],
                                            ),
                                          ).animate().fadeIn(duration: 180.ms),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(width: 10),

                                  _TopIconButton(
                                        icon: widget.switchingStudent
                                            ? FontAwesomeIcons.circleNotch
                                            : FontAwesomeIcons.arrowsRotate,
                                        onTap:
                                            widget.switchingStudent ||
                                                widget.onSwitchStudent == null
                                            ? null
                                            : widget.onSwitchStudent,
                                        size: topBtnSize,
                                        iconSize: topBtnIcon,
                                      )
                                      .animate()
                                      .fadeIn(delay: 140.ms, duration: 220.ms)
                                      .slideX(begin: .15, end: 0),
                                ],
                              ),

                              SizedBox(height: gapAfterTopbar),

                              _AttendanceCalendarCard(
                                    height: topCardH,
                                    blur: headerBlur,
                                    scale: s,
                                    isSmallPhone: isSmallPhone,
                                    date: today,
                                    checkedIn: checkedIn,
                                    isLate: isLate,
                                    checkinTime: checkinTime,
                                    isDark: isDark,
                                    participantPercent: _participantPercent,
                                    onTapAttendance: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AttendancePage(
                                            selectedStudent:
                                                widget.selectedStudent,
                                          ),
                                        ),
                                      );
                                    },
                                    onTapParticipant: () => go(
                                      ParticipantPage(
                                        selectedStudent: widget.selectedStudent,
                                      ),
                                    ),
                                    onTapCalendar: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const YearCalendarPage(),
                                        ),
                                      );
                                    },
                                  )
                                  .animate()
                                  .fadeIn(delay: 120.ms, duration: 260.ms)
                                  .slideY(
                                    begin: .18,
                                    end: 0,
                                    duration: 320.ms,
                                    curve: Curves.easeOutCubic,
                                  ),

                              SizedBox(height: gapBetweenCards),

                              IgnorePointer(
                                    ignoring: true,
                                    child: _MiniInfoCard(
                                      height: miniCardH,
                                      blur: miniBlur,
                                      scale: s,
                                      isSmallPhone: isSmallPhone,
                                      isTablet: isTablet || isLargeTablet,
                                      eventText: "ປີໃໝ່ລາວ 2026",
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 170.ms, duration: 260.ms)
                                  .slideY(
                                    begin: .18,
                                    end: 0,
                                    duration: 320.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: _WalletSheet(
                          isDark: isDark,
                          width: w,
                          isSmallPhone: isSmallPhone,
                          isTablet: isTablet,
                          isLargeTablet: isLargeTablet,
                          blur: sheetBlur,
                          scale: s,
                          selectedStudent: widget.selectedStudent,
                          unreadHomework: _unreadHomework,
                          unreadAppointments: _unreadAppointments,
                          onMenuRead: _markMenuRead,
                          onMenuRefresh: _loadMenuUnreadCounts,
                        ).animate().fadeIn(delay: 120.ms, duration: 240.ms),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  right: (isTablet || isLargeTablet) ? 22 : 16,
                  bottom: (12 + bottomInset).toDouble(),
                  child:
                      _ScanQrFab(
                            isSmallPhone: isSmallPhone,
                            onTap: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScanQrCodePage(),
                                ),
                              );

                              if (result != null) {
                                debugPrint("QR = $result");
                              }
                            },
                          )
                          .animate()
                          .fadeIn(delay: 220.ms, duration: 240.ms)
                          .scale(
                            begin: const Offset(.92, .92),
                            end: const Offset(1, 1),
                            duration: 260.ms,
                            curve: Curves.easeOutBack,
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ======================================================
// ✅ Notification Popup Overlay (FOLLOW DARK/LIGHT MODE)
// ======================================================

class _PopTokens {
  final bool isDark;

  final Color cardBgA;
  final Color cardBgB;
  final Color cardBgC;

  final Color title;
  final Color text;
  final Color sub;
  final Color line;

  final Color barrier;

  final Color blue;
  final Color green;
  final Color amber;
  final Color red;

  const _PopTokens({
    required this.isDark,
    required this.cardBgA,
    required this.cardBgB,
    required this.cardBgC,
    required this.title,
    required this.text,
    required this.sub,
    required this.line,
    required this.barrier,
    required this.blue,
    required this.green,
    required this.amber,
    required this.red,
  });

  static int _alpha(double o) => (o * 255).round().clamp(0, 255);
  static Color _o(Color c, double opacity) => c.withAlpha(_alpha(opacity));

  factory _PopTokens.of(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final cs = t.colorScheme;

    if (!isDark) {
      const base = Color(0xFFFFFFFF);
      return _PopTokens(
        isDark: false,
        cardBgA: _o(base, 0.92),
        cardBgB: _o(base, 0.82),
        cardBgC: _o(base, 0.74),
        title: const Color(0xFF111827),
        text: const Color(0xFF374151),
        sub: const Color(0xFF6B7280),
        line: const Color(0xFFE5E7EB),
        barrier: _o(Colors.black, 0.10),
        blue: const Color(0xFF2563EB),
        green: const Color(0xFF16A34A),
        amber: const Color(0xFFF59E0B),
        red: const Color(0xFFFF3B30),
      );
    }

    // dark / premium glass vibe (ตาม ColorScheme ของ AppTheme.darkTheme)
    const darkBase = Color(0xFF0B1220);
    final onSurface = cs.onSurface;
    final surface = cs.surface;

    return _PopTokens(
      isDark: true,
      cardBgA: _o(surface, 0.72),
      cardBgB: _o(darkBase, 0.62),
      cardBgC: _o(darkBase, 0.52),
      title: _o(onSurface, 0.96),
      text: _o(onSurface, 0.78),
      sub: _o(onSurface, 0.62),
      line: _o(Colors.white, 0.12),
      barrier: _o(Colors.black, 0.22),
      blue: cs.primary,
      green: const Color(0xFF22C55E),
      amber: const Color(0xFFFBBF24),
      red: const Color(0xFFFF453A),
    );
  }
}

class _PillStyle {
  final Color bg;
  final Color border;
  final Color fg;
  const _PillStyle(this.bg, this.border, this.fg);
}

class _NotificationPopupOverlay extends StatefulWidget {
  final double top;
  final double left;
  final double width;
  final List<_NotificationItem> items;

  final VoidCallback onViewAll;
  final VoidCallback onClosed;

  const _NotificationPopupOverlay({
    required this.top,
    required this.left,
    required this.width,
    required this.items,
    required this.onViewAll,
    required this.onClosed,
  });

  @override
  State<_NotificationPopupOverlay> createState() =>
      _NotificationPopupOverlayState();
}

class _NotificationPopupOverlayState extends State<_NotificationPopupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_c.status == AnimationStatus.dismissed) return;
    await _c.reverse();
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final tok = _PopTokens.of(context);

    final maxH = (MediaQuery.of(context).size.height * 0.55).clamp(
      260.0,
      420.0,
    );

    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final scale = Tween<double>(
      begin: 0.985,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    final slideY = Tween<double>(
      begin: -10.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: fade,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: Container(color: tok.barrier),
            ),
          ),
        ),
        Positioned(
          top: widget.top,
          left: widget.left,
          width: widget.width,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              return Opacity(
                opacity: fade.value,
                child: Transform.translate(
                  offset: Offset(0, slideY.value),
                  child: Transform.scale(
                    scale: scale.value,
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {},
                        child: _NotificationPopupCard(
                          width: widget.width,
                          maxHeight: maxH,
                          items: widget.items,
                          onClose: _close,
                          onViewAll: () async {
                            await _c.reverse();
                            widget.onClosed();
                            widget.onViewAll();
                          },
                          tok: tok,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationPopupCard extends StatelessWidget {
  final double width;
  final double maxHeight;
  final List<_NotificationItem> items;
  final VoidCallback onClose;
  final VoidCallback onViewAll;
  final _PopTokens tok;

  const _NotificationPopupCard({
    required this.width,
    required this.maxHeight,
    required this.items,
    required this.onClose,
    required this.onViewAll,
    required this.tok,
  });

  @override
  Widget build(BuildContext context) {
    final border = tok.line;

    final viewAllBg = tok.isDark
        ? _PopTokens._o(tok.blue, 0.16)
        : _PopTokens._o(tok.blue, 0.10);
    final viewAllBd = tok.isDark
        ? _PopTokens._o(tok.blue, 0.28)
        : _PopTokens._o(tok.blue, 0.22);

    final closeBg = tok.isDark
        ? _PopTokens._o(Colors.white, 0.06)
        : _PopTokens._o(Colors.white, 0.75);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tok.cardBgA, tok.cardBgB, tok.cardBgC],
            ),
            boxShadow: [
              BoxShadow(
                color: _PopTokens._o(Colors.black, tok.isDark ? 0.48 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                  child: Row(
                    children: [
                      FaIcon(FontAwesomeIcons.bell, color: tok.blue, size: 14),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Notifications",
                          style: TextStyle(
                            color: tok.title,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      InkResponse(
                        onTap: onViewAll,
                        radius: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: viewAllBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: viewAllBd),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "View all",
                                style: TextStyle(
                                  color: tok.blue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: _PopTokens._o(tok.blue, 0.95),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkResponse(
                        onTap: onClose,
                        radius: 22,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: closeBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tok.line),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: tok.title,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: tok.line),
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      final label = _timeGroupLabel(it.time);
                      final timeText = _fmtTime(it.time);

                      return _NotificationTile(
                            sender: it.sender,
                            title: it.title,
                            body: it.body,
                            timeText: timeText,
                            groupLabel: label,
                            unread: it.isUnread,
                            tok: tok,
                          )
                          .animate()
                          .fadeIn(delay: (40 + i * 45).ms, duration: 200.ms)
                          .slideX(
                            begin: .05,
                            end: 0,
                            duration: 240.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Tap outside to close",
                          style: TextStyle(
                            color: tok.sub,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tok.isDark
                              ? _PopTokens._o(Colors.white, 0.06)
                              : _PopTokens._o(Colors.white, 0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tok.line),
                        ),
                        child: Text(
                          "Recent: ${_recentScopeLabel(items)}",
                          style: TextStyle(
                            color: tok.sub,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, "0");
    final mm = dt.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }

  static String _timeGroupLabel(DateTime dt) {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(dt.year, dt.month, dt.day);
    final diffDays = d0.difference(d1).inDays;

    if (diffDays == 0) return "Today";
    if (diffDays == 1) return "Yesterday";
    if (diffDays <= 7) return "This week";
    return "Earlier";
  }

  static String _recentScopeLabel(List<_NotificationItem> items) {
    if (items.isEmpty) return "-";
    final latest = items
        .map((e) => e.time)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return _timeGroupLabel(latest);
  }
}

class _NotificationTile extends StatelessWidget {
  final String sender;
  final String title;
  final String body;
  final String timeText;
  final String groupLabel;
  final bool unread;
  final _PopTokens tok;

  const _NotificationTile({
    required this.sender,
    required this.title,
    required this.body,
    required this.timeText,
    required this.groupLabel,
    required this.unread,
    required this.tok,
  });

  @override
  Widget build(BuildContext context) {
    final bg = tok.isDark
        ? (unread
              ? _PopTokens._o(tok.blue, 0.14)
              : _PopTokens._o(Colors.white, 0.06))
        : (unread
              ? _PopTokens._o(tok.blue, 0.06)
              : _PopTokens._o(Colors.white, 0.70));

    final bd = tok.isDark
        ? (unread ? _PopTokens._o(tok.blue, 0.30) : tok.line)
        : (unread ? _PopTokens._o(tok.blue, 0.18) : tok.line);

    final pill = _pillStyle(groupLabel, tok);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unread ? tok.red : tok.line,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tok.sub,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tok.title,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.6,
                        height: 1.0,
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
                    timeText,
                    style: TextStyle(
                      color: tok.sub,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: pill.bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pill.border),
                    ),
                    child: Text(
                      groupLabel,
                      style: TextStyle(
                        color: pill.fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.2,
                        height: 1.0,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tok.text,
              fontWeight: FontWeight.w800,
              fontSize: 12.3,
              height: 1.20,
            ),
          ),
        ],
      ),
    );
  }

  static _PillStyle _pillStyle(String groupLabel, _PopTokens tok) {
    if (groupLabel == "Today") {
      return _PillStyle(
        _PopTokens._o(tok.blue, tok.isDark ? 0.18 : 0.12),
        _PopTokens._o(tok.blue, tok.isDark ? 0.32 : 0.25),
        tok.blue,
      );
    }
    if (groupLabel == "Yesterday") {
      return _PillStyle(
        _PopTokens._o(tok.amber, tok.isDark ? 0.18 : 0.14),
        _PopTokens._o(tok.amber, tok.isDark ? 0.32 : 0.25),
        tok.amber,
      );
    }
    if (groupLabel == "This week") {
      return _PillStyle(
        _PopTokens._o(tok.green, tok.isDark ? 0.16 : 0.12),
        _PopTokens._o(tok.green, tok.isDark ? 0.30 : 0.22),
        tok.green,
      );
    }
    return _PillStyle(
      tok.isDark
          ? _PopTokens._o(Colors.white, 0.06)
          : _PopTokens._o(Colors.white, 0.75),
      tok.line,
      tok.sub,
    );
  }
}

// ======================================================
// ✅ Model
// ======================================================
class _NotificationItem {
  final String sender;
  final String title;
  final String body;
  final DateTime time;
  final bool isUnread;

  const _NotificationItem({
    required this.sender,
    required this.title,
    required this.body,
    required this.time,
    required this.isUnread,
  });

  _NotificationItem copyWith({bool? isUnread}) {
    return _NotificationItem(
      sender: sender,
      title: title,
      body: body,
      time: time,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

// ======================================================
// ✅ Floating Scan QR Button (Dark Blue Premium)
// ======================================================
class _ScanQrFab extends StatelessWidget {
  final bool isSmallPhone;
  final VoidCallback onTap;

  const _ScanQrFab({required this.isSmallPhone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = isSmallPhone ? 68.0 : 78.0;
    final iconSize = (d * 0.58).clamp(32.0, 44.0);

    const premiumGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B2A66), Color(0xFF0A3E9A), Color(0xFF0A57D6)],
      stops: [0.0, 0.55, 1.0],
    );

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: d / 2,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: premiumGradient,
            border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                offset: const Offset(0, 16),
                color: Colors.black.withOpacity(.30),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Remix.qr_scan_2_line,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================
// ✅ TOP CARD: Attendance + Calendar
// =====================
class _AttendanceCalendarCard extends StatelessWidget {
  final double height;
  final double blur;
  final double scale;
  final bool isSmallPhone;

  final DateTime date;
  final bool checkedIn;
  final bool isLate;
  final TimeOfDay? checkinTime;
  final bool isDark;

  final double participantPercent;

  final VoidCallback onTapAttendance;
  final VoidCallback onTapCalendar;
  final VoidCallback? onTapParticipant;

  const _AttendanceCalendarCard({
    required this.height,
    required this.blur,
    required this.scale,
    required this.isSmallPhone,
    required this.date,
    required this.checkedIn,
    required this.isLate,
    required this.checkinTime,
    required this.isDark,
    required this.onTapAttendance,
    required this.onTapCalendar,
    this.onTapParticipant,
    this.participantPercent = 0.70,
  });

  String _fmtTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = isSmallPhone ? 12.5 : 13.0;
    final valueSize = isSmallPhone ? 15.0 : 16.0;
    final labelSize = isSmallPhone ? 11.0 : 12.0;

    final statusColor = isLate
        ? Colors.orangeAccent
        : checkedIn
        ? Colors.greenAccent
        : Colors.redAccent;
    final statusText = isLate
        ? "Check-in Late"
        : checkedIn
        ? "Checked-In"
        : "Not Checked-In";
    // Local copy so the null check below promotes it to a non-nullable
    // `TimeOfDay` for `_fmtTime` (the field itself can't be promoted).
    final checkinTime = this.checkinTime;

    final pct = participantPercent.clamp(0.0, 1.0);
    final pctLabel = "${(pct * 100).round()}%";

    final padL = isSmallPhone ? 14.0 : 16.0;
    final padT = isSmallPhone ? 12.0 : 14.0;
    final padR = isSmallPhone ? 12.0 : 14.0;
    final padB = isSmallPhone ? 12.0 : 14.0;

    final rowDivider = Container(
      height: 1,
      color: Colors.white.withOpacity(.20),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padL, padT, padR, padB),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.clipboardUser,
                            size: isSmallPhone ? 13.0 : 14.0,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "ຕິດຕາມການມາໂຮງຮຽນ",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: titleSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallPhone ? 10 : 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(.10),
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _TapScale(
                                    onTap: onTapAttendance,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallPhone ? 12 : 14,
                                        vertical: isSmallPhone ? 10 : 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                statusText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: valueSize,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (checkinTime != null) ...[
                                            const SizedBox(width: 12),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                FaIcon(
                                                  FontAwesomeIcons.clock,
                                                  size: isSmallPhone
                                                      ? 12.0
                                                      : 13.0,
                                                  color: Colors.white
                                                      .withOpacity(.88),
                                                ),
                                                const SizedBox(width: 8),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    _fmtTime(checkinTime),
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(.95),
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: valueSize,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                rowDivider,
                                Expanded(
                                  flex: 3,
                                  child: _TapScale(
                                    onTap: onTapParticipant ?? onTapAttendance,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        isSmallPhone ? 12 : 14,
                                        isSmallPhone ? 10 : 12,
                                        isSmallPhone ? 12 : 14,
                                        isSmallPhone ? 10 : 12,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              FaIcon(
                                                FontAwesomeIcons.userGroup,
                                                color: Colors.white.withOpacity(
                                                  .92,
                                                ),
                                                size: isSmallPhone
                                                    ? 13.0
                                                    : 14.0,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  "ຄະແນນການມີສ່ວນຮ່ວມ",
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(.96),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: labelSize,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: isSmallPhone ? 8 : 10,
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _PercentBar(
                                                  height: isSmallPhone
                                                      ? 12.0
                                                      : 14.0,
                                                  value: pct,
                                                  isSmallPhone: isSmallPhone,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  pctLabel,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(.98),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: isSmallPhone
                                                        ? 12.5
                                                        : 14.0,
                                                    height: 1.0,
                                                    letterSpacing: .2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, color: Colors.white.withOpacity(.12)),
              Expanded(
                child: _TapScale(
                  onTap: onTapCalendar,
                  child: Padding(
                    padding: EdgeInsets.all(isSmallPhone ? 12.0 : 14.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(.10),
                          ),
                        ),
                        child: _MonthCalendarGlass(
                          initialDate: date,
                          isDark: isDark,
                          isSmallPhone: isSmallPhone,
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
    );
  }
}

// =====================
// ✅ Calendar with header (NO prev/next)
// =====================
class _MonthCalendarGlass extends StatefulWidget {
  final DateTime initialDate;
  final bool isDark;
  final bool isSmallPhone;

  const _MonthCalendarGlass({
    required this.initialDate,
    required this.isDark,
    required this.isSmallPhone,
  });

  @override
  State<_MonthCalendarGlass> createState() => _MonthCalendarGlassState();
}

class _MonthCalendarGlassState extends State<_MonthCalendarGlass> {
  late final CalendarController _ctrl;
  late DateTime _display;

  static const _months = <String>[
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = CalendarController();
    _display = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _ctrl.displayDate = _display;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final headerH = widget.isSmallPhone ? 30.0 : 34.0;

    return Column(
      children: [
        Container(
          height: headerH,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF001E51), Color(0xFF003A8C), Color(0xFF001E51)],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(.20),
              ),
            ],
          ),
          child: Center(
            child: Text(
              "${_months[_display.month - 1]} ${_display.year}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.96),
                fontWeight: FontWeight.w900,
                fontSize: widget.isSmallPhone ? 11.0 : 12.0,
                letterSpacing: .2,
              ),
            ),
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: true,
            child: SfCalendar(
              controller: _ctrl,
              view: CalendarView.month,
              initialDisplayDate: widget.initialDate,
              backgroundColor: Colors.transparent,
              headerHeight: 0,
              monthViewSettings: const MonthViewSettings(
                showAgenda: false,
                navigationDirection: MonthNavigationDirection.horizontal,
              ),
              viewHeaderHeight: widget.isSmallPhone ? 18 : 26,
              viewHeaderStyle: ViewHeaderStyle(
                dayTextStyle: TextStyle(
                  color: Colors.white.withOpacity(.70),
                  fontWeight: FontWeight.w800,
                  fontSize: widget.isSmallPhone ? 9.5 : 10.5,
                ),
              ),
              todayHighlightColor: Colors.white.withOpacity(.90),
              selectionDecoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(.35),
                  width: 1,
                ),
              ),
              monthCellBuilder: (context, details) {
                final d = details.date;
                final now = DateTime.now();
                final isToday = _isSameDate(d, now);

                final inMonth =
                    d.month ==
                    (_ctrl.displayDate?.month ?? widget.initialDate.month);

                final textColor = inMonth
                    ? Colors.white.withOpacity(.88)
                    : Colors.white.withOpacity(.45);

                return Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday
                          ? Colors.white.withOpacity(.18)
                          : Colors.transparent,
                      border: isToday
                          ? Border.all(
                              color: Colors.white.withOpacity(.85),
                              width: 1.2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          color: isToday ? Colors.white : textColor,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w800,
                          fontSize: widget.isSmallPhone ? 10.0 : 10.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// =====================
// ✅ Mini info (Event & Announcement)
// =====================
class _MiniInfoCard extends StatelessWidget {
  final double height;
  final double blur;
  final double scale;
  final bool isSmallPhone;
  final bool isTablet;
  final String eventText;

  const _MiniInfoCard({
    required this.height,
    required this.blur,
    required this.scale,
    required this.isSmallPhone,
    required this.isTablet,
    required this.eventText,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmallPhone ? 16.0 : 18.0;
    final titleSize = isSmallPhone ? 13.0 : 14.0;
    final bodySize = isSmallPhone ? 12.5 : 13.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallPhone ? 14.0 : 16.0,
              isSmallPhone ? 12.0 : 14.0,
              isSmallPhone ? 14.0 : 16.0,
              isSmallPhone ? 12.0 : 14.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.bullhorn,
                      color: Colors.white.withOpacity(.92),
                      size: iconSize,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Event & Announcement",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.98),
                          fontWeight: FontWeight.w900,
                          fontSize: titleSize,
                          height: 1.0,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallPhone ? 8 : 10,
                        vertical: isSmallPhone ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(.18),
                        ),
                      ),
                      child: Text(
                        "Today",
                        style: TextStyle(
                          color: Colors.white.withOpacity(.92),
                          fontWeight: FontWeight.w800,
                          fontSize: isSmallPhone ? 10.0 : 11.0,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallPhone ? 8.0 : 10.0),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.calendarDays,
                      color: Colors.white.withOpacity(.85),
                      size: isSmallPhone ? 14.0 : 15.0,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        eventText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.95),
                          fontWeight: FontWeight.w900,
                          fontSize: bodySize,
                          height: 1.10,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ Percent bar
class _PercentBar extends StatelessWidget {
  final double height;
  final double value;
  final bool isSmallPhone;

  const _PercentBar({
    required this.height,
    required this.value,
    required this.isSmallPhone,
  });

  double _to01(double v) {
    if (v > 1.0) return (v / 100.0).clamp(0.0, 1.0);
    return v.clamp(0.0, 1.0);
  }

  static Color _rangeColor(double t) {
    const red = Color(0xFFEF4444);
    const yellow = Color(0xFFF59E0B);
    const green = Color(0xFF22C55E);
    if (t <= 0.5) {
      return Color.lerp(red, yellow, (t / 0.5).clamp(0.0, 1.0))!;
    }
    return Color.lerp(yellow, green, ((t - 0.5) / 0.5).clamp(0.0, 1.0))!;
  }

  @override
  Widget build(BuildContext context) {
    final v01 = _to01(value);
    final base = _rangeColor(v01);
    final highlight = Color.lerp(base, Colors.white, .25)!;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(.30),
                width: 1,
              ),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: v01),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                final markerLeft = (w * t - 1).clamp(0.0, w - 2.0);

                return Stack(
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: t,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [highlight, base],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: Colors.white.withOpacity(.40),
                      ),
                    ),
                    Positioned(
                      left: markerLeft,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Colors.white.withOpacity(.95),
                      ),
                    ),
                    Positioned(
                      left: (markerLeft - 3).clamp(0.0, w - 8.0),
                      top: (height / 2 - 4).clamp(0.0, height - 8.0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.98),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              color: Colors.black.withOpacity(.22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  const _TopIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size / 2 + 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: Colors.white.withOpacity(onTap == null ? .48 : .92),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

// =====================
// ✅ GLASS MENU SHEET
// =====================
class _WalletSheet extends StatelessWidget {
  final bool isDark;
  final double width;
  final bool isSmallPhone;
  final bool isTablet;
  final bool isLargeTablet;
  final double blur;
  final double scale;
  final StudentCardItem? selectedStudent;
  final int unreadHomework;
  final int unreadAppointments;
  final Future<void> Function(String menu) onMenuRead;
  final Future<void> Function() onMenuRefresh;

  const _WalletSheet({
    required this.isDark,
    required this.width,
    required this.isSmallPhone,
    required this.isTablet,
    required this.isLargeTablet,
    required this.blur,
    required this.scale,
    required this.unreadHomework,
    required this.unreadAppointments,
    required this.onMenuRead,
    required this.onMenuRefresh,
    this.selectedStudent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color.fromARGB(
      255,
      0,
      30,
      81,
    ).withOpacity(isDark ? .18 : .14);
    final border = Colors.white.withOpacity(isDark ? .18 : .22);

    final crossAxisCount = isLargeTablet ? 6 : (isTablet ? 5 : 4);
    final spacing = isSmallPhone ? 14.0 : 18.0;

    final childAspectRatio = isLargeTablet
        ? 0.95
        : isTablet
        ? 0.92
        : isSmallPhone
        ? 0.88
        : 0.92;

    final titleSize = isSmallPhone ? 16.0 : 18.0;

    final items = <_QuickMenuItem>[
      _QuickMenuItem(
        icon: FontAwesomeIcons.headset,
        label: "ຕິດຕໍ່ໂຮງຮຽນ",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactPage(selectedStudent: selectedStudent),
            ),
          );
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.piggyBank,
        label: "ເງິນຝາກປະຍັດ",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SavingPage(selectedStudent: selectedStudent),
            ),
          );
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.newspaper,
        label: "ຂ່າວ ແລະ ກິດຈະກຳ",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewsPage()),
          );
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.images,
        label: "ຄັງຮູບພາບ",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  GalleryPage(selectedStudentId: selectedStudent?.id),
            ),
          );
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.userClock,
        label: "ນັດໝາຍ",
        unreadCount: unreadAppointments,
        onTap: () async {
          // Fire-and-forget so the menu opens instantly even on slow networks.
          unawaited(onMenuRead('appointments'));
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppointmentPage()),
          );
          if (context.mounted) await onMenuRefresh();
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.book,
        label: "ວຽກບ້ານ",
        unreadCount: unreadHomework,
        onTap: () async {
          unawaited(onMenuRead('homework'));
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HomeworkPage(selectedStudent: selectedStudent),
            ),
          );
          if (context.mounted) await onMenuRefresh();
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.plus,
        label: "ວຽກພິເສດ",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ParentTaskListPage(selectedStudent: selectedStudent),
            ),
          );
        },
      ),
      _QuickMenuItem(
        icon: FontAwesomeIcons.fileAlt,
        label: "ລາຍງານ",
        onTap: () {},
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const revealTop = 12.0;

        return Column(
          children: [
            const SizedBox(height: revealTop),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  (isTablet || isLargeTablet) ? 18.0 : 14.0,
                  0.0,
                  (isTablet || isLargeTablet) ? 18.0 : 14.0,
                  (isTablet || isLargeTablet) ? 18.0 : 14.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                            color: Colors.black.withOpacity(isDark ? .30 : .14),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(.12),
                                    Colors.white.withOpacity(.04),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              isSmallPhone ? 16.0 : 18.0,
                              isSmallPhone ? 14.0 : 16.0,
                              isSmallPhone ? 16.0 : 18.0,
                              isSmallPhone ? 16.0 : 18.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "ເມນູທັງຫມົດ",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: titleSize,
                                  ),
                                ),
                                SizedBox(height: isSmallPhone ? 12.0 : 14.0),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: items.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: spacing,
                                        crossAxisSpacing: spacing,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                  itemBuilder: (context, i) {
                                    final it = items[i];
                                    return _QuickMenuTile(
                                          item: it,
                                          isDark: isDark,
                                          isSmallPhone: isSmallPhone,
                                          isTablet: isTablet || isLargeTablet,
                                        )
                                        .animate()
                                        .fadeIn(
                                          delay: (60 + i * 45).ms,
                                          duration: 220.ms,
                                        )
                                        .slideY(begin: .12, end: 0);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final int unreadCount;

  _QuickMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.unreadCount = 0,
  });
}

class _QuickMenuTile extends StatelessWidget {
  final _QuickMenuItem item;
  final bool isDark;
  final bool isSmallPhone;
  final bool isTablet;

  const _QuickMenuTile({
    required this.item,
    required this.isDark,
    required this.isSmallPhone,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled;

    final ring = Colors.white.withOpacity(enabled ? .85 : .35);
    final circleBg = Colors.white.withOpacity(enabled ? .08 : .04);

    final iconC = Colors.white.withOpacity(enabled ? .95 : .40);
    final textC = Colors.white.withOpacity(enabled ? .92 : .40);

    final double circle = isTablet ? 72.0 : (isSmallPhone ? 56.0 : 66.0);
    final double iconSize = isTablet ? 24.0 : (isSmallPhone ? 20.0 : 22.0);
    final double labelSize = isTablet ? 12.0 : (isSmallPhone ? 10.8 : 11.5);

    return InkResponse(
      onTap: enabled ? item.onTap : null,
      radius: circle,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleBg,
                  border: Border.all(color: ring, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withOpacity(enabled ? .18 : .08),
                    ),
                  ],
                ),
                child: Center(
                  child: FaIcon(item.icon, color: iconC, size: iconSize),
                ),
              ),
              if (item.unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isSmallPhone ? 8.0 : 10.0),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: 1.08,
              color: textC,
              fontWeight: FontWeight.w800,
              fontSize: labelSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const _TapScale({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// =====================
// ✅ Placeholder pages
// =====================
class AttendanceCalendarPage extends StatelessWidget {
  const AttendanceCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance & Calendar")),
      body: const Center(child: Text("AttendanceCalendarPage()")),
    );
  }
}

class EventAnnouncementPage extends StatelessWidget {
  const EventAnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Event & Announcement")),
      body: const Center(child: Text("EventAnnouncementPage()")),
    );
  }
}
