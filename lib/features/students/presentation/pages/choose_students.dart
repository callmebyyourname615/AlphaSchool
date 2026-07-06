import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/student_card_item.dart'; // ✅ ใช้ตัวนี้ตัวเดียว

import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/student_info_form_page.dart';
import '../../../auth/presentation/pages/student_pending_page.dart';
import '../../data/student_service.dart';
import '../../../home/presentation/pages/home_shell_page.dart';
import 'scan_student_link_qr_page.dart';

/// Two ways a parent can add a student — filling in the full form, or
/// (once the linking logic is defined) scanning a QR code the school gives
/// them.
enum _AddStudentMethod { form, qr }

class StudentsCardListPage extends StatefulWidget {
  final List<StudentCardItem>? students;
  final ValueChanged<StudentCardItem>? onSelect;

  /// Called when the page wants to refresh its student list — e.g. after
  /// returning from the Add Student flow. Optional; callers that drive the
  /// list externally can provide this to re-fetch.
  final VoidCallback? onReload;

  const StudentsCardListPage({
    super.key,
    this.students,
    this.onSelect,
    this.onReload,
  });

  @override
  State<StudentsCardListPage> createState() => _StudentsCardListPageState();
}

class _StudentsCardListPageState extends State<StudentsCardListPage>
    with SingleTickerProviderStateMixin {
  static const double _maxWidth = 720;
  static const double _pageHPad = 16;
  static const double _topPad = 72;
  static const double _heroRadius = 24;
  static const double _s12 = 12;
  static const double _s16 = 16;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, .03),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  final StudentService _studentService = StudentService();
  late List<StudentCardItem> _students = List<StudentCardItem>.from(
    widget.students ?? _demoStudents,
  );

  List<StudentCardItem> get _items => _students;

  @override
  void didUpdateWidget(covariant StudentsCardListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.students, oldWidget.students)) {
      _students = List<StudentCardItem>.from(widget.students ?? _demoStudents);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ThemeData _effectiveTheme(Locale locale, bool dark) {
    return dark ? AppTheme.darkTheme(locale) : AppTheme.lightTheme(locale);
  }

  PageRouteBuilder<T> _smoothRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        final fade = Tween<double>(begin: 0, end: 1).animate(curved);
        final slide = Tween<Offset>(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(curved);
        final scale = Tween<double>(begin: .985, end: 1).animate(curved);

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
    );
  }

  void _goLogin() {
    Navigator.of(context).pushReplacement(_smoothRoute(const LoginPage()));
  }

  void _goHome(StudentCardItem student) {
    Navigator.of(
      context,
    ).pushReplacement(_smoothRoute(HomeShellPage(selectedStudent: student)));
  }

  Future<void> _reloadStudents() async {
    widget.onReload?.call();
    final session = await SessionService().load();
    if (!mounted) return;
    final parentId = session?.id.trim() ?? '';
    if (parentId.isEmpty) return;
    try {
      final fresh = await _studentService.fetchStudentsForParent(parentId);
      if (!mounted) return;
      setState(() => _students = fresh);
    } catch (_) {
      // Keep the current cards if refresh fails; the user can retry manually.
    }
  }

  Future<void> _openPendingStudent(StudentCardItem item) async {
    if (item.isQrLinkRequest) {
      final result = await Navigator.of(context).push<Object?>(
        _smoothRoute<Object?>(
          StudentPendingPage(
            studentId: item.id?.trim() ?? '',
            studentName: item.name,
            studentLocalId: item.studentId,
            initialApprovalStatus: item.approvalStatus,
            initialRejectReason: item.rejectReason,
            qrLinkRequestId: item.linkRequestId,
          ),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} has been linked to your account.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        await _reloadStudents();
        return;
      }
      if (result == 'add_another') {
        await _goAddStudent();
      }
      return;
    }
    final uuid = item.id?.trim() ?? '';
    if (uuid.isEmpty) {
      // No backend id (e.g. demo data) — nothing to poll. Fall back to a hint.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This student is pending admin approval.'),
        ),
      );
      return;
    }
    final result = await Navigator.of(context).push<Object?>(
      _smoothRoute<Object?>(
        StudentPendingPage(
          studentId: uuid,
          studentName: item.name,
          studentLocalId: item.studentId,
          initialApprovalStatus: item.approvalStatus,
          initialRejectReason: item.rejectReason,
        ),
      ),
    );
    if (!mounted) return;
    // Status flipped while the pending screen was open — refresh the list so
    // the card switches from pending to active.
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} has been approved.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      await _reloadStudents();
      return;
    }

    // The pending screen can return this action after an existing pending
    // student is selected. Start the same add-student flow as the page CTA.
    if (result == 'add_another') {
      await _goAddStudent();
      return;
    }

    final resubmitId = _resubmitStudentIdFrom(result) ?? uuid;
    if (_isResubmitAction(result)) {
      await _goResubmit(resubmitId);
      return;
    }

    if (result == 'deleted') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application deleted.')));
      await _reloadStudents();
    }
  }

  Future<void> _goResubmit(String studentId) async {
    final session = await SessionService().load();
    if (!mounted) return;
    final parentId = session?.id.trim() ?? '';
    if (parentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your session is missing. Please sign in again to resubmit.',
          ),
        ),
      );
      return;
    }
    final result = await Navigator.of(context).push<Object?>(
      _smoothRoute<Object?>(
        StudentInfoFormPage.resubmit(
          resubmitStudentId: studentId,
          parentId: parentId,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'resubmitted') {
      await _reloadStudents();
      return;
    }
    if (_isPendingAction(result)) {
      await _reloadStudents();
      await _openPendingResult(result);
    }
  }

  /// Entry point both the empty-state CTA and the list's trailing tile call.
  /// Shows the two-option picker, then dispatches to whichever path the
  /// parent chose.
  Future<void> _goAddStudent() async {
    final method = await _showAddStudentOptionsSheet();
    if (method == null || !mounted) return;
    if (method == _AddStudentMethod.form) {
      await _goAddStudentByForm();
    } else {
      await _goAddStudentByQr();
    }
  }

  Future<_AddStudentMethod?> _showAddStudentOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<_AddStudentMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddStudentOptionsSheet(isDark: isDark),
    );
  }

  Future<void> _goAddStudentByForm() async {
    final session = await SessionService().load();
    if (!mounted) return;
    final parentId = session?.id.trim() ?? '';
    if (parentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your session is missing. Please sign in again to add a student.',
          ),
        ),
      );
      return;
    }
    final result = await Navigator.of(context).push<Object>(
      _smoothRoute<Object>(StudentInfoFormPage.addOnly(parentId: parentId)),
    );
    if (!mounted) return;
    // Reload the student list so any newly-submitted student (pending) shows.
    await _reloadStudents();
    if (!mounted) return;
    // The pending screen lets the parent jump straight into another student
    // form — honor that without making them dig through the menu again.
    if (result == 'add_another') {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      await _goAddStudentByForm();
      return;
    }
    if (_isResubmitAction(result)) {
      final studentId = _resubmitStudentIdFrom(result);
      if (studentId == null || studentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open resubmit form. Student ID missing.'),
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      await _goResubmit(studentId);
    }
  }

  // Scans another guardian's student QR (from the Profile page) and submits
  // a link request. The student won't actually appear in this list until an
  // admin approves it, so there's nothing to reload immediately — the scan
  // screen itself already confirms submission before returning.
  Future<void> _goAddStudentByQr() async {
    final submitted = await Navigator.of(
      context,
    ).push<bool>(_smoothRoute<bool>(const ScanStudentLinkQrPage()));
    if (!mounted) return;
    if (submitted == true) {
      await _reloadStudents();
    }
  }

  bool _isResubmitAction(Object? result) {
    if (result == 'resubmit') return true;
    if (result is Map) return result['action']?.toString() == 'resubmit';
    return false;
  }

  String? _resubmitStudentIdFrom(Object? result) {
    if (result is Map) {
      final id = result['studentId']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }
    return null;
  }

  bool _isPendingAction(Object? result) {
    if (result is Map) return result['action']?.toString() == 'pending';
    return false;
  }

  Future<void> _openPendingResult(Object? result) async {
    if (result is! Map) return;
    final studentId = result['studentId']?.toString().trim() ?? '';
    if (studentId.isEmpty) return;
    final pendingResult = await Navigator.of(context).push<Object?>(
      _smoothRoute<Object?>(
        StudentPendingPage(
          studentId: studentId,
          studentName:
              result['studentName']?.toString().trim().isNotEmpty == true
              ? result['studentName'].toString().trim()
              : 'your child',
          nickname: result['nickname']?.toString().trim().isNotEmpty == true
              ? result['nickname'].toString().trim()
              : null,
          initialApprovalStatus: 'pending',
        ),
      ),
    );
    if (!mounted) return;
    if (_isResubmitAction(pendingResult)) {
      final id = _resubmitStudentIdFrom(pendingResult) ?? studentId;
      await _goResubmit(id);
    } else if (pendingResult == 'add_another') {
      await _goAddStudent();
    } else if (pendingResult == true) {
      await _reloadStudents();
    }
  }

  Future<void> _confirmLogout() async {
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(isDarkNow ? .55 : .35),
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text("Logout"),
          content: const Text("Do you want to logout and go to Login page?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) _goLogin();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        return AnimatedTheme(
          data: _effectiveTheme(locale, mode == ThemeMode.dark),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final cs = Theme.of(context).colorScheme;

              final bgA = isDark
                  ? AppColors.blue500
                  : AppColors.blue200.withOpacity(.16);
              final bgB = isDark
                  ? AppColors.blue400.withOpacity(.34)
                  : AppColors.blue100.withOpacity(.08);
              final bgC = isDark ? AppColors.dark : Colors.white;

              final glowA = (isDark ? AppColors.blue100 : AppColors.blue200)
                  .withOpacity(isDark ? .26 : .11);
              final glowB = (isDark ? AppColors.blue200 : AppColors.blue300)
                  .withOpacity(isDark ? .22 : .09);

              final titleColor = isDark ? Colors.white : AppColors.blue500;
              final muted = isDark
                  ? AppColors.grayUltraLight.withOpacity(.84)
                  : AppColors.gray;

              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [bgA, bgB, bgC],
                    ),
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Positioned(
                          top: -110,
                          left: -95,
                          child: _Glow(size: 320, color: glowA),
                        ),
                        Positioned(
                          bottom: -170,
                          right: -140,
                          child: _Glow(size: 420, color: glowB),
                        ),

                        Positioned(
                          top: 10,
                          left: 12,
                          right: 12,
                          child: FadeTransition(
                            opacity: _fade,
                            child: Row(
                              children: [
                                _LogoutButton(
                                  isDark: isDark,
                                  onTap: _confirmLogout,
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),

                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxWidth,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                _pageHPad,
                                _topPad,
                                _pageHPad,
                                _pageHPad,
                              ),
                              child: FadeTransition(
                                opacity: _fade,
                                child: SlideTransition(
                                  position: _slide,
                                  child: Column(
                                    children: [
                                      _Hero(
                                        isDark: isDark,
                                        titleColor: titleColor,
                                        muted: muted,
                                        count: _items.length,
                                      ),
                                      const SizedBox(height: _s16),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            _heroRadius,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 14,
                                              sigmaY: 14,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.blue500
                                                          .withOpacity(.50)
                                                    : Colors.white.withOpacity(
                                                        .88,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      _heroRadius,
                                                    ),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.white
                                                            .withOpacity(.10)
                                                      : AppColors.slate
                                                            .withOpacity(.12),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    blurRadius: 34,
                                                    offset: const Offset(0, 18),
                                                    color: Colors.black
                                                        .withOpacity(
                                                          isDark ? .38 : .10,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              child: _items.isEmpty
                                                  ? _EmptyStudents(
                                                      isDark: isDark,
                                                      titleColor: titleColor,
                                                      muted: muted,
                                                      onAdd: _goAddStudent,
                                                    )
                                                  : ListView.separated(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            _s16,
                                                          ),
                                                      physics:
                                                          const BouncingScrollPhysics(),
                                                      // +1 trailing slot for the Add Student button — it sits below
                                                      // the last card and naturally moves down as more cards land.
                                                      itemCount:
                                                          _items.length + 1,
                                                      separatorBuilder:
                                                          (_, __) =>
                                                              const SizedBox(
                                                                height: _s12,
                                                              ),
                                                      itemBuilder: (context, index) {
                                                        if (index ==
                                                            _items.length) {
                                                          return _AddStudentTile(
                                                            isDark: isDark,
                                                            onTap:
                                                                _goAddStudent,
                                                          );
                                                        }
                                                        final item =
                                                            _items[index];
                                                        final d =
                                                            280 + (index * 70);

                                                        return TweenAnimationBuilder<
                                                          double
                                                        >(
                                                          tween: Tween<double>(
                                                            begin: 0,
                                                            end: 1,
                                                          ),
                                                          duration: Duration(
                                                            milliseconds: d
                                                                .clamp(
                                                                  280,
                                                                  900,
                                                                ),
                                                          ),
                                                          curve: Curves
                                                              .easeOutCubic,
                                                          builder:
                                                              (
                                                                context,
                                                                t,
                                                                child,
                                                              ) {
                                                                return Opacity(
                                                                  opacity: t,
                                                                  child: Transform.translate(
                                                                    offset: Offset(
                                                                      0,
                                                                      (1 - t) *
                                                                          10,
                                                                    ),
                                                                    child:
                                                                        child,
                                                                  ),
                                                                );
                                                              },
                                                          child: _StudentCard(
                                                            isDark: isDark,
                                                            titleColor:
                                                                titleColor,
                                                            muted: muted,
                                                            cs: cs,
                                                            item: item,
                                                            onTap:
                                                                item.isApproved
                                                                ? () {
                                                                    final onSelect =
                                                                        widget
                                                                            .onSelect;
                                                                    if (onSelect !=
                                                                        null) {
                                                                      onSelect(
                                                                        item,
                                                                      );
                                                                      Navigator.of(
                                                                        context,
                                                                      ).pop<
                                                                        StudentCardItem
                                                                      >(item);
                                                                      return;
                                                                    }
                                                                    _goHome(
                                                                      item,
                                                                    );
                                                                  }
                                                                : () =>
                                                                      _openPendingStudent(
                                                                        item,
                                                                      ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                            ),
                                          ),
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
}

/// ✅ Demo list (ใช้ shared StudentCardItem)
const _demoStudents = <StudentCardItem>[
  StudentCardItem(
    studentId: "STU-2024-001",
    name: "Anouphong",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?schoolkid,student&sig=11",
  ),
  StudentCardItem(
    studentId: "STU-2024-014",
    name: "Timothy F.",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?boy,student,portrait&sig=12",
  ),
  StudentCardItem(
    studentId: "STU-2024-027",
    name: "Nok P.",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?girl,student,portrait&sig=13",
  ),
  StudentCardItem(
    studentId: "STU-2024-033",
    name: "Mina K.",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?teen,student,school&sig=14",
  ),
];

/// ===== UI widgets เดิมของคุณ (คงไว้ได้เลย) =====
class _Hero extends StatelessWidget {
  final bool isDark;
  final Color titleColor;
  final Color muted;
  final int count;

  const _Hero({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? AppColors.blue500.withOpacity(.44)
        : Colors.white.withOpacity(.78);
    final stroke = isDark
        ? Colors.white.withOpacity(.10)
        : AppColors.slate.withOpacity(.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.blue100, AppColors.blue300],
                  ),
                ),
                child: const Icon(LucideIcons.school, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Students",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Card view • $count students",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  static const double _radius = 24;

  final bool isDark;
  final Color titleColor;
  final Color muted;
  final ColorScheme cs;
  final StudentCardItem item;
  final VoidCallback onTap;

  const _StudentCard({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.cs,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.94);
    final bd = isDark
        ? Colors.white.withOpacity(.14)
        : AppColors.slate.withOpacity(.12);
    final accent = isDark ? AppColors.blue100 : AppColors.blue500;

    return Opacity(
      opacity: item.isApproved ? 1.0 : 0.78,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: bd),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(isDark ? .58 : .10),
                        accent.withOpacity(isDark ? .28 : .06),
                      ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(.12)
                          : AppColors.slate.withOpacity(.10),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: item.photoUrl == null
                        ? Center(
                            child: Icon(
                              LucideIcons.graduationCap,
                              size: 22,
                              color: accent.withOpacity(isDark ? .92 : .70),
                            ),
                          )
                        : Image.network(
                            item.photoUrl!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            frameBuilder:
                                (context, child, frame, wasSyncLoaded) {
                                  if (wasSyncLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    child: child,
                                  );
                                },
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accent.withOpacity(.9),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                LucideIcons.graduationCap,
                                size: 22,
                                color: accent.withOpacity(isDark ? .92 : .70),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: -.15,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(LucideIcons.idCard, size: 12, color: muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.studentId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (!item.isApproved) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.isRejected
                                ? const Color(0xFFFFF1F2)
                                : const Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: item.isRejected
                                  ? const Color(
                                      0xFFE11D48,
                                    ).withValues(alpha: .35)
                                  : const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: .45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isRejected
                                    ? LucideIcons.circleX
                                    : LucideIcons.hourglass,
                                size: 9,
                                color: item.isRejected
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                item.isRejected
                                    ? 'Rejected'
                                    : item.isQrLinkRequest
                                    ? 'QR Link Pending'
                                    : 'Pending Approval',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: item.isRejected
                                      ? const Color(0xFF9F1239)
                                      : const Color(0xFFB45309),
                                  letterSpacing: .4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: item.isApproved
                        ? (isDark
                              ? Colors.white.withOpacity(.08)
                              : cs.primary.withOpacity(.08))
                        : const Color(0xFFFFF7E6),
                    border: Border.all(
                      color: item.isApproved
                          ? (isDark
                                ? Colors.white.withOpacity(.10)
                                : cs.primary.withOpacity(.14))
                          : const Color(0xFFF59E0B).withOpacity(.40),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      item.isApproved
                          ? LucideIcons.chevronRight
                          : LucideIcons.hourglass,
                      size: 14,
                      color: item.isApproved
                          ? (isDark
                                ? Colors.white.withOpacity(.82)
                                : AppColors.blue500)
                          : const Color(0xFFB45309),
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

/// Bottom sheet offering the two ways to add a student. Pops the chosen
/// [_AddStudentMethod], or null if dismissed without a choice.
class _AddStudentOptionsSheet extends StatelessWidget {
  final bool isDark;

  const _AddStudentOptionsSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.dark : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.blue500;
    final muted = isDark
        ? AppColors.grayUltraLight.withOpacity(.70)
        : AppColors.gray;
    final handleColor = isDark
        ? Colors.white.withOpacity(.24)
        : AppColors.slate.withOpacity(.24);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? .45 : .12),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Add a student',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: titleColor,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Choose how you'd like to add your child.",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: 18),
            _AddOptionRow(
              isDark: isDark,
              icon: LucideIcons.fileText,
              title: 'Fill in a form',
              subtitle: "Enter your child's information yourself.",
              onTap: () => Navigator.of(context).pop(_AddStudentMethod.form),
            ),
            const SizedBox(height: 12),
            _AddOptionRow(
              isDark: isDark,
              icon: LucideIcons.qrCode,
              title: 'Scan QR code',
              subtitle: 'Add a student using a QR code from the school.',
              onTap: () => Navigator.of(context).pop(_AddStudentMethod.qr),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOptionRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddOptionRow({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.blue100 : AppColors.blue500;
    final tintFg = isDark ? Colors.white.withOpacity(.92) : AppColors.blue500;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark
        ? AppColors.grayUltraLight.withOpacity(.70)
        : AppColors.gray;
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : AppColors.slate.withOpacity(.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withOpacity(isDark ? .22 : .10),
                  border: Border.all(
                    color: accent.withOpacity(isDark ? .35 : .22),
                  ),
                ),
                child: Center(child: Icon(icon, size: 20, color: tintFg)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddStudentTile extends StatelessWidget {
  static const double _radius = 24;

  final bool isDark;
  final VoidCallback onTap;

  const _AddStudentTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.05)
        : Colors.white.withOpacity(.70);
    final border = isDark
        ? Colors.white.withOpacity(.16)
        : AppColors.blue500.withOpacity(.30);
    final accent = isDark ? AppColors.blue100 : AppColors.blue500;
    final tintFg = isDark ? Colors.white.withOpacity(.92) : AppColors.blue500;
    final muted = isDark
        ? Colors.white.withOpacity(.60)
        : AppColors.slate.withOpacity(.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: accent.withOpacity(isDark ? .22 : .10),
                  border: Border.all(
                    color: accent.withOpacity(isDark ? .35 : .22),
                  ),
                ),
                child: Center(
                  child: Icon(LucideIcons.userPlus, size: 22, color: tintFg),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add student',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tintFg,
                        letterSpacing: -.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submit a new application — admin will review it.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withOpacity(isDark ? .28 : .12),
                  border: Border.all(
                    color: accent.withOpacity(isDark ? .38 : .22),
                  ),
                ),
                child: Center(
                  child: Icon(LucideIcons.plus, size: 14, color: tintFg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _LogoutButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.86);
    final bd = isDark
        ? Colors.white.withOpacity(.14)
        : AppColors.slate.withOpacity(.12);

    final fg = isDark ? Colors.white : const Color(0xFFE11D48);
    final glow = (isDark ? fg : const Color(0xFFE11D48)).withOpacity(.14);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
          boxShadow: [
            BoxShadow(blurRadius: 22, offset: const Offset(0, 12), color: glow),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.logOut, size: 15, color: fg),
            const SizedBox(width: 8),
            Text(
              "Logout",
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                letterSpacing: -.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

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

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.onAdd,
  });

  final bool isDark;
  final Color titleColor;
  final Color muted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.blue100 : AppColors.blue500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withOpacity(isDark ? .35 : .14),
                  accent.withOpacity(isDark ? .15 : .06),
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(.12)
                    : AppColors.slate.withOpacity(.14),
              ),
            ),
            child: Center(
              child: Icon(
                LucideIcons.graduationCap,
                size: 36,
                color: accent.withOpacity(isDark ? .92 : .75),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No students yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w800,
              letterSpacing: -.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Let's add your child to get started.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? .12 : .06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(isDark ? .35 : .18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: tap “Add student” below and fill in your child’s information to link them to your account. Once submitted, an admin will review and approve.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: titleColor.withOpacity(.85),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.userPlus, size: 20),
              label: const Text('Add student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: accent.withOpacity(.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
