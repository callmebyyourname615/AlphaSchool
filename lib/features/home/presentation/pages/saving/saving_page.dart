import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/global_alert_service.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'saving_model.dart';
import 'saving_service.dart';
import 'withdrawal_pending_page.dart';

const _kNavy = Color(0xFF082653);
const _kBlue = Color(0xFF0756D1);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF5F8FE);
const _kCardBg = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE3E9F2);
const _kMuted = Color(0xFF647594);
const _kText = Color(0xFF082653);

class SavingPage extends StatefulWidget {
  const SavingPage({super.key, required this.selectedStudent});

  final StudentCardItem? selectedStudent;

  @override
  State<SavingPage> createState() => _SavingPageState();
}

class _SavingPageState extends State<SavingPage> with TickerProviderStateMixin {
  static const double _maxWidth = 680;

  late final TabController _tab;

  DateTime? _fromDate;
  DateTime? _toDate;

  final _service = SavingService();
  List<_SavingTxn> _personalData = const [];
  List<_SavingTxn> _classData = const [];
  double _personalBalance = 0;
  double _classBalance = 0;
  double _personalAvailableBalance = 0;
  double _personalNonAvailableBalance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate!.subtract(const Duration(days: 30));

    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // =========================
  // Date picker
  // =========================
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initStart = _fromDate ?? DateTime(now.year, now.month, now.day - 30);
    final initEnd = _toDate ?? DateTime(now.year, now.month, now.day);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: DateTimeRange(start: initStart, end: initEnd),
      builder: (context, child) {
        final t = Theme.of(context);
        final isDark = t.brightness == Brightness.dark;

        return Theme(
          data: t.copyWith(
            colorScheme: t.colorScheme.copyWith(
              primary: AppColors.blue500,
              surface: isDark ? AppTheme.darkBluePremium : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;
    setState(() {
      _fromDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _toDate = DateTime(range.end.year, range.end.month, range.end.day);
    });
  }

  void _resetRange() {
    final now = DateTime.now();
    setState(() {
      _toDate = DateTime(now.year, now.month, now.day);
      _fromDate = _toDate!.subtract(const Duration(days: 30));
    });
  }

  // =========================
  // Withdraw action (Personal only)
  // =========================
  Future<void> _load() async {
    final id = widget.selectedStudent?.id?.trim() ?? '';
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Student ID is unavailable. Please select the student again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetch(
        studentId: id,
        classId: widget.selectedStudent?.classId,
      );
      if (!mounted) return;
      setState(() {
        _personalData = data.personal.map(_toTxn).toList();
        _classData = data.classTransactions.map(_toTxn).toList();
        _personalBalance = data.personalBalance;
        _classBalance = data.classBalance;
        _personalAvailableBalance = data.personalAvailableBalance;
        _personalNonAvailableBalance = data.personalNonAvailableBalance;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openPendingWithdrawal(_SavingTxn txn) async {
    final id = (txn.payReceiveId ?? '').trim();
    if (id.isEmpty) return;
    final studentName = (widget.selectedStudent?.name ?? '').trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WithdrawalPendingPage(
          payReceiveId: id,
          amount: txn.outAmount,
          studentName: studentName.isEmpty ? 'Your child' : studentName,
          initialStatus: txn.payReceiveStatus ?? 'pending',
        ),
      ),
    );
    if (!mounted) return;
    // Refresh — the parent may have refreshed status on the detail page
    // and the row's badge/color should reflect any change.
    await _load();
  }

  _SavingTxn _toTxn(SavingTransaction item) => _SavingTxn(
    date: item.createdAt,
    inAmount: item.transactionType == 'DEPOSIT' ? item.amount : 0,
    outAmount: item.transactionType == 'WITHDRAW' ? item.amount : 0,
    closingBalance: item.closingBalance,
    payReceiveId: item.payReceiveId,
    payReceiveStatus: item.payReceiveStatus,
  );

  Future<void> _onWithdrawPressed() async {
    final available = _personalAvailableBalance;
    if (available <= 0) {
      GlobalAlert.showWarning(
        title: 'Unable to withdraw',
        message: 'There is no available balance to withdraw yet.',
      );
      return;
    }
    List<WithdrawalReason> reasons;
    GlobalAlert.showLoading(message: 'Loading withdrawal reasons...');
    try {
      reasons = await _service.fetchWithdrawalReasons();
      GlobalAlert.dismiss();
    } catch (error) {
      GlobalAlert.dismiss();
      GlobalAlert.showError(
        title: 'Unable to withdraw',
        message: error.toString(),
      );
      return;
    }
    if (!mounted) return;
    if (reasons.isEmpty) {
      GlobalAlert.showWarning(
        title: 'Unable to withdraw',
        message: 'No active withdrawal reason is configured by the school.',
      );
      return;
    }

    final request =
        await showGeneralDialog<
          ({double amount, String reasonId, String note})
        >(
          context: context,
          barrierLabel: 'Withdraw',
          barrierDismissible: true,
          barrierColor: const Color(0xFF071B55).withValues(alpha: .45),
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => const SizedBox.shrink(),
          transitionBuilder: (ctx, anim, _, __) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1).animate(curved),
                child: _WithdrawSheet(
                  available: available,
                  nonAvailable: _personalNonAvailableBalance,
                  reasons: reasons,
                ),
              ),
            );
          },
        );
    if (request == null || !mounted) return;
    if (request.amount > available) {
      GlobalAlert.showWarning(
        title: 'Amount not available',
        message:
            'You can withdraw up to ${NumberFormat('#,##0').format(available)} only.',
      );
      return;
    }
    final confirmed = await GlobalAlert.showConfirmation(
      title: 'Confirm withdrawal',
      message:
          'Request withdrawal of ${NumberFormat('#,##0').format(request.amount)}?',
    );
    if (confirmed != true) return;
    GlobalAlert.showLoading(message: 'Submitting withdrawal request...');
    try {
      final created = await _service.requestWithdrawal(
        studentId: widget.selectedStudent!.id!,
        amount: request.amount,
        withdrawReasonId: request.reasonId,
        note: request.note,
      );
      GlobalAlert.dismiss();
      if (!mounted) return;
      final payReceiveId =
          (created['id'] ??
                  created['payReceiveId'] ??
                  created['pay_receive_id'] ??
                  '')
              .toString();
      final initialStatus = (created['status'] ?? 'pending').toString();
      final studentName = (widget.selectedStudent?.name ?? '').trim();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WithdrawalPendingPage(
            payReceiveId: payReceiveId,
            amount: request.amount,
            studentName: studentName.isEmpty ? 'Your child' : studentName,
            initialStatus: initialStatus,
            note: request.note.isEmpty ? null : request.note,
          ),
        ),
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      GlobalAlert.dismiss();
      GlobalAlert.showError(
        title: 'Withdrawal failed',
        message: error.toString(),
      );
    }
  }

  // =========================
  // Data selection + compute
  // =========================
  List<_SavingTxn> _dataForTab(int index) =>
      index == 0 ? _personalData : _classData;

  _SavingView _buildView(List<_SavingTxn> raw, double currentBalance) {
    final from = _fromDate;
    final to = _toDate;

    final filtered = raw.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final okFrom = from == null
          ? true
          : !d.isBefore(DateTime(from.year, from.month, from.day));
      final okTo = to == null
          ? true
          : !d.isAfter(DateTime(to.year, to.month, to.day));
      return okFrom && okTo;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    final rows = <_SavingRow>[];
    for (final e in filtered) {
      rows.add(_SavingRow(txn: e, balance: e.closingBalance));
    }

    final totalIn = filtered.fold<double>(0, (s, e) => s + e.inAmount);
    final totalOut = filtered.fold<double>(0, (s, e) => s + e.outAmount);
    final totalBalance = currentBalance;

    final latestIn = filtered
        .where((e) => e.inAmount > 0)
        .fold<_SavingTxn?>(
          null,
          (best, e) => (best == null || e.date.isAfter(best.date)) ? e : best,
        );

    return _SavingView(
      rows: rows,
      totalIn: totalIn,
      totalOut: totalOut,
      totalBalance: totalBalance,
      latestIn: latestIn,
    );
  }

  // =========================
  // UI
  // =========================
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
              final bottomInset = MediaQuery.of(context).padding.bottom;
              const isDark = false;
              const border = _kBorder;
              final shadow = Colors.black.withValues(alpha: .06);
              const textPrimary = _kText;
              const textMuted = _kMuted;
              return Scaffold(
                backgroundColor: _kBg,
                body: SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SavingHeader(
                            studentName: widget.selectedStudent?.name ?? '',
                            onBack: () => Navigator.maybePop(context),
                            onRefresh: _load,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child:
                                _Panel(
                                      isDark: isDark,
                                      border: border,
                                      shadow: shadow,
                                      color: _kCardBg,
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        12,
                                        12,
                                        12,
                                      ),
                                      child: Column(
                                        children: [
                                          _RangeBar(
                                            isDark: isDark,
                                            from: _fromDate,
                                            to: _toDate,
                                            onTap: _pickRange,
                                            onLongPress: _resetRange,
                                            textPrimary: textPrimary,
                                            textMuted: textMuted,
                                            border: border,
                                          ),
                                          const SizedBox(height: 10),
                                          _CleanTabBar(
                                            isDark: isDark,
                                            controller: _tab,
                                            border: border,
                                            textPrimary: textPrimary,
                                            textMuted: textMuted,
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 220.ms)
                                    .slideY(
                                      begin: .04,
                                      end: 0,
                                      duration: 360.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                          ),

                          const SizedBox(height: 12),

                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16 + bottomInset,
                              ),
                              child: _loading
                                  ? const _SavingLoadCard()
                                  : _error != null
                                  ? _SavingErrorCard(
                                      message: _error!,
                                      onRetry: _load,
                                    )
                                  : TabBarView(
                                      controller: _tab,
                                      children: [
                                        _SavingTabBody(
                                          isDark: isDark,
                                          border: border,
                                          shadow: shadow,
                                          textPrimary: textPrimary,
                                          textMuted: textMuted,
                                          dataBuilder: () => _buildView(
                                            _dataForTab(0),
                                            _personalBalance,
                                          ),
                                          onWithdraw: _onWithdrawPressed,
                                          onPendingTap: _openPendingWithdrawal,
                                          typeLabel: "ສ່ວນບຸກຄົນ",
                                          availableBalance:
                                              _personalAvailableBalance,
                                          nonAvailableBalance:
                                              _personalNonAvailableBalance,
                                        ),
                                        _SavingTabBody(
                                          isDark: isDark,
                                          border: border,
                                          shadow: shadow,
                                          textPrimary: textPrimary,
                                          textMuted: textMuted,
                                          dataBuilder: () => _buildView(
                                            _dataForTab(1),
                                            _classBalance,
                                          ),
                                          onWithdraw: null,
                                          typeLabel: "ຫ້ອງຮຽນ",
                                          availableBalance: _classBalance,
                                          nonAvailableBalance: 0,
                                        ),
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
            },
          ),
        );
      },
    );
  }
}

// ======================================================
// PANEL
// ======================================================
class _SavingHeader extends StatelessWidget {
  final String studentName;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _SavingHeader({
    required this.studentName,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = studentName.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: _kBorder)),
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(LucideIcons.arrowLeft, color: _kNavy, size: 17),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Savings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  cleanName.isEmpty ? 'Student saving activity' : cleanName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: _kBorder)),
            child: InkWell(
              onTap: onRefresh,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(LucideIcons.refreshCw, color: _kNavy, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingLoadCard extends StatelessWidget {
  const _SavingLoadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.6),
      ),
    );
  }
}

class _SavingErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SavingErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.circleAlert, color: _kRed, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final bool isDark;
  final Color? color;
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
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 16, offset: const Offset(0, 4), color: shadow),
        ],
      ),
      child: child,
    );
  }
}

// ======================================================
// RANGE + TAB BAR
// ======================================================
class _RangeBar extends StatelessWidget {
  final bool isDark;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  final Color textPrimary;
  final Color textMuted;
  final Color border;

  const _RangeBar({
    required this.isDark,
    required this.from,
    required this.to,
    required this.onTap,
    this.onLongPress,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final df = _numericDateFmt();

    final fromText = from == null ? "Any" : df.format(from!);
    final toText = to == null ? "Any" : df.format(to!);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendarDays, color: _kBlue, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$fromText  →  $toText",
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: .2,
                ),
              ),
            ),
            const Text(
              "ຄົ້ນຫາ",
              style: TextStyle(
                color: _kBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, color: _kBlue, size: 14),
          ],
        ),
      ),
    );
  }
}

class _CleanTabBar extends StatelessWidget {
  final bool isDark;
  final TabController controller;
  final Color border;
  final Color textPrimary;
  final Color textMuted;

  const _CleanTabBar({
    required this.isDark,
    required this.controller,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(12),
        indicator: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: .2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: .2,
        ),
        tabs: const [
          Tab(height: 36, text: "ສ່ວນບຸກຄົນ"),
          Tab(height: 36, text: "ຫ້ອງຮຽນ"),
        ],
      ),
    );
  }
}

// ======================================================
// TAB BODY
// ======================================================
class _SavingTabBody extends StatelessWidget {
  final bool isDark;

  final Color border;
  final Color shadow;
  final Color textPrimary;
  final Color textMuted;

  final _SavingView Function() dataBuilder;

  /// ✅ Personal มีปุ่ม / Class ส่ง null เพื่อซ่อนปุ่ม
  final VoidCallback? onWithdraw;

  /// Tap handler for a pending-withdrawal row (routes to the tracking page).
  final void Function(_SavingTxn txn)? onPendingTap;

  /// ✅ เพิ่ม: type label
  final String typeLabel;
  final double availableBalance;
  final double nonAvailableBalance;

  const _SavingTabBody({
    required this.isDark,
    required this.border,
    required this.shadow,
    required this.textPrimary,
    required this.textMuted,
    required this.dataBuilder,
    required this.onWithdraw,
    this.onPendingTap,
    required this.typeLabel,
    required this.availableBalance,
    required this.nonAvailableBalance,
  });

  /// Flattens rows (already newest-first) into a date-header + row sequence
  /// so each calendar day is only labeled once instead of on every row.
  List<Object> _ledgerEntries(List<_SavingRow> rows) {
    final df = _numericDateFmt();
    final entries = <Object>[];
    DateTime? lastDay;
    for (final r in rows) {
      final day = DateTime(r.txn.date.year, r.txn.date.month, r.txn.date.day);
      if (lastDay == null || day != lastDay) {
        entries.add(df.format(day));
        lastDay = day;
      }
      entries.add(r);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final view = dataBuilder();
    final rows = view.rows;
    final entries = _ledgerEntries(rows);

    return _Panel(
          isDark: isDark,
          border: border,
          shadow: shadow,
          color: _kCardBg,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                _TableHeader(
                  isDark: isDark,
                  border: border,
                  textMuted: textMuted,
                  rowsCount: rows.length,
                ).animate().fadeIn(duration: 180.ms),
                Expanded(
                  child: rows.isEmpty
                      ? const _SavingEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 10),
                          itemCount: entries.length,
                          itemBuilder: (context, i) {
                            final entry = entries[i];
                            if (entry is String) {
                              return _DateGroupHeader(
                                label: entry,
                                textMuted: textMuted,
                              );
                            }
                            final precededByRow =
                                i > 0 && entries[i - 1] is _SavingRow;
                            return _TableRowItem(
                                  isDark: isDark,
                                  row: entry as _SavingRow,
                                  textPrimary: textPrimary,
                                  onPendingTap: onPendingTap,
                                  showTopBorder: precededByRow,
                                )
                                .animate()
                                .fadeIn(duration: 140.ms, delay: (14 * i).ms)
                                .slideY(begin: .05, end: 0, duration: 140.ms);
                          },
                        ),
                ),
                _SavingDetailPremium(
                      view: view,
                      border: border,
                      onWithdraw: onWithdraw,
                      typeLabel: typeLabel,
                      availableBalance: availableBalance,
                      nonAvailableBalance: nonAvailableBalance,
                    )
                    .animate()
                    .fadeIn(duration: 240.ms, delay: 70.ms)
                    .slideY(begin: .06, end: 0, duration: 240.ms),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 220.ms, delay: 80.ms)
        .slideY(begin: .08, end: 0);
  }
}

// ======================================================
// TABLE WIDGETS
// ======================================================
class _TableHeader extends StatelessWidget {
  final bool isDark;
  final Color border;
  final Color textMuted;
  final int rowsCount;

  const _TableHeader({
    required this.isDark,
    required this.border,
    required this.textMuted,
    required this.rowsCount,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: AppColors.grayLight,
      fontWeight: FontWeight.w700,
      letterSpacing: .4,
      fontSize: 11,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: const Row(
        children: [
          Expanded(child: Text("Transaction", style: headerStyle)),
          Text("Amount / Balance", style: headerStyle),
        ],
      ),
    );
  }
}

/// Sticky-feeling section header shown once per calendar day so the date
/// isn't repeated on every row — lets more transactions fit on screen.
class _DateGroupHeader extends StatelessWidget {
  final String label;
  final Color textMuted;

  const _DateGroupHeader({required this.label, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Text(
        label,
        style: TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SavingEmptyState extends StatelessWidget {
  const _SavingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.wallet, color: _kBlue, size: 22),
            ),
            const SizedBox(height: 12),
            const Text(
              'No data in selected range',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kText,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try another date range or refresh this page.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableRowItem extends StatelessWidget {
  final bool isDark;
  final _SavingRow row;
  final Color textPrimary;
  final void Function(_SavingTxn txn)? onPendingTap;

  /// The date now lives in the group header above, so only rows after the
  /// very first one in the whole list need a separating hairline.
  final bool showTopBorder;

  const _TableRowItem({
    required this.isDark,
    required this.row,
    required this.textPrimary,
    this.onPendingTap,
    this.showTopBorder = true,
  });

  static const _amberSoft = Color(0xFFFFF7E6);
  static const _amberBorder = Color(0xFFFDE68A);
  static const _amberDeep = Color(0xFFB45309);
  static const _green = Color(0xFF22C55E);
  static const _greenSoft = Color(0xFFDCFCE7);
  static const _red = Color(0xFFEF4444);
  static const _redSoft = Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final nf = _safeNumFmt(locale);

    final pending = row.txn.isPendingWithdrawal;
    final net = row.txn.inAmount > 0 ? row.txn.inAmount : -row.txn.outAmount;
    final isDeposit = net > 0;

    final netText = net == 0
        ? ""
        : pending
        // Pending withdrawals aren't finalized — show the requested amount
        // without a minus sign so it doesn't look like the balance already
        // dropped.
        ? nf.format(net.abs())
        : (isDeposit ? "+${nf.format(net)}" : "−${nf.format(net.abs())}");

    final netColor = pending
        ? _amberDeep
        : isDeposit
        ? _green
        : (net < 0 ? _red : Colors.black.withOpacity(.25));

    final balText = nf.format(row.balance.abs());
    final balPrefix = row.balance >= 0 ? "" : "−";

    final rowBg = pending ? _amberSoft : Colors.transparent;
    final label = pending
        ? 'Pending withdrawal'
        : (isDeposit ? 'Deposit' : 'Withdrawal');
    final iconColor = pending ? _amberDeep : (isDeposit ? _green : _red);
    final iconBg = pending ? Colors.white : (isDeposit ? _greenSoft : _redSoft);
    final icon = isDeposit
        ? LucideIcons.arrowDownLeft
        : LucideIcons.arrowUpRight;

    Widget body = Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: rowBg,
        border: pending
            ? Border.all(color: _amberBorder)
            : (showTopBorder ? Border(top: BorderSide(color: _kBorder)) : null),
        borderRadius: pending ? BorderRadius.circular(12) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              pending ? LucideIcons.hourglass : icon,
              size: 14,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    netText,
                    style: TextStyle(
                      color: netColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 15,
                      color: _amberDeep,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                "$balPrefix$balText",
                style: const TextStyle(
                  color: _kMuted,
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (pending && onPendingTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(onTap: () => onPendingTap!(row.txn), child: body),
      );
    }

    return body;
  }
}

// ======================================================
// SAVING DETAIL (ซ่อนปุ่มได้ด้วย onWithdraw == null)
// ======================================================
class _SavingDetailPremium extends StatefulWidget {
  final _SavingView view;
  final Color border;

  /// ✅ null = ไม่มีปุ่ม (ใช้กับ Class)
  final VoidCallback? onWithdraw;

  /// ✅ เพิ่ม: type label
  final String typeLabel;
  final double availableBalance;
  final double nonAvailableBalance;

  const _SavingDetailPremium({
    required this.view,
    required this.border,
    required this.onWithdraw,
    required this.typeLabel,
    required this.availableBalance,
    required this.nonAvailableBalance,
  });

  @override
  State<_SavingDetailPremium> createState() => _SavingDetailPremiumState();
}

class _SavingDetailPremiumState extends State<_SavingDetailPremium> {
  // Collapsed by default so the transaction list above keeps most of the
  // screen — the breakdown is reference info parents open on demand rather
  // than something they need at a glance every time.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final border = widget.border;
    final onWithdraw = widget.onWithdraw;
    final typeLabel = widget.typeLabel;
    final availableBalance = widget.availableBalance;
    final nonAvailableBalance = widget.nonAvailableBalance;
    final locale = Localizations.localeOf(context).toString();
    final nf = _safeNumFmt(locale);

    final totalInText = nf.format(view.totalIn);
    final totalOutText = nf.format(view.totalOut);

    final latest = view.latestIn;
    final latestText = latest == null ? "-" : nf.format(latest.inAmount);

    final bal = view.totalBalance;
    final balText = nf.format(bal);
    final availableText = nf.format(availableBalance);
    final nonAvailableText = nf.format(nonAvailableBalance);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      "ລາຍລະອຽດ ",
                      style: const TextStyle(
                        color: _kNavy,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    const Icon(LucideIcons.info, size: 15, color: _kMuted),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        children: [
                          _DetailLine(
                            label: "ປະເພດ :",
                            value: typeLabel,
                            labelColor: _kMuted,
                            valueColor: _kText,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: _kBorder,
                            ),
                          ),
                          _DetailLine(
                            label: "ຍອດຍົກມາ :",
                            value: latestText,
                            labelColor: _kMuted,
                            valueColor: _kText,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: _kBorder,
                            ),
                          ),
                          _DetailLine(
                            label: "ຍອດເຄື່ອນໄຫວຝາກ :",
                            value: totalInText,
                            labelColor: _kMuted,
                            valueColor: _kText,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: _kBorder,
                            ),
                          ),
                          _DetailLine(
                            label: "ຍອດເຄື່ອນໄຫວຖອນ :",
                            value: totalOutText,
                            labelColor: _kMuted,
                            valueColor: _kText,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: _kBorder,
                            ),
                          ),
                          _DetailLine(
                            label: "Available :",
                            value: availableText,
                            labelColor: _kMuted,
                            valueColor: _kGreen,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: _kBorder,
                            ),
                          ),
                          _DetailLine(
                            label: "Non available :",
                            value: nonAvailableText,
                            labelColor: _kMuted,
                            valueColor: _kRed,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: _kBorder,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                "ຍອດເຫຼືອທ້າຍ :",
                                style: const TextStyle(
                                  color: _kMuted,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .2,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                balText,
                                style: const TextStyle(
                                  color: _kNavy,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                  fontSize: 18.0,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (onWithdraw != null) ...[
            const SizedBox(height: 12),
            _BigWithdrawButton(onTap: onWithdraw),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _DetailLine({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w600,
            letterSpacing: .1,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
            fontSize: 13,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _BigWithdrawButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BigWithdrawButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: _kBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(LucideIcons.handCoins, color: Colors.white, size: 17),
              SizedBox(width: 9),
              Text(
                "Withdraw money",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// MODELS
// ======================================================
class _SavingTxn {
  final DateTime date;
  final double inAmount;
  final double outAmount;
  final double closingBalance;
  // PayReceive cross-reference — populated for WITHDRAW rows that still
  // have an in-flight approval flow. Lets the row render amber and route
  // to the tracking page.
  final String? payReceiveId;
  final String? payReceiveStatus;

  const _SavingTxn({
    required this.date,
    required this.inAmount,
    required this.outAmount,
    required this.closingBalance,
    this.payReceiveId,
    this.payReceiveStatus,
  });

  /// A withdrawal is still "pending" from the parent's POV whenever the
  /// PayReceive hasn't reached a terminal state (received / rejected).
  bool get isPendingWithdrawal {
    if (outAmount <= 0) return false;
    final s = (payReceiveStatus ?? '').toLowerCase();
    if (s.isEmpty) return false;
    return s == 'pending' ||
        s == 'admin_confirmed' ||
        s == 'super_admin_approved';
  }
}

class _SavingRow {
  final _SavingTxn txn;
  final double balance;

  const _SavingRow({required this.txn, required this.balance});
}

class _SavingView {
  final List<_SavingRow> rows;
  final double totalIn;
  final double totalOut;
  final double totalBalance;
  final _SavingTxn? latestIn;

  const _SavingView({
    required this.rows,
    required this.totalIn,
    required this.totalOut,
    required this.totalBalance,
    required this.latestIn,
  });
}

// ======================================================
// FORMAT HELPERS
// ======================================================
/// Savings dates are always numeric so they remain compact and consistent
/// across Lao, Thai and English device locales.
DateFormat _numericDateFmt() => DateFormat('dd/MM/yyyy', 'en');

NumberFormat _safeNumFmt(String localeTag) {
  try {
    return NumberFormat.decimalPattern(localeTag);
  } catch (_) {
    return NumberFormat.decimalPattern('en');
  }
}

/// Minimal, modern withdraw dialog.
///
/// Returns `({double amount, String reasonId})` via `Navigator.pop` to keep
/// the existing caller contract untouched.
class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({
    required this.available,
    required this.nonAvailable,
    required this.reasons,
  });

  final double available;
  final double nonAvailable;
  final List<WithdrawalReason> reasons;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  static const _blue = Color(0xFF0756D1);
  static const _navy = Color(0xFF071B55);
  static const _muted = Color(0xFF64739B);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate100 = Color(0xFFEFF2F8);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _rose = Color(0xFFE11D48);

  late final TextEditingController _amountController = TextEditingController();
  late final TextEditingController _noteController = TextEditingController();
  late WithdrawalReason _reason;
  String? _amountError;

  final _amountFmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _reason = widget.reasons.first;
    _amountController.addListener(_validate);
  }

  @override
  void dispose() {
    _amountController.removeListener(_validate);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;

  double get _percent =>
      widget.available <= 0 ? 0 : (_amount / widget.available).clamp(0, 1.0);

  double get _totalWallet => widget.available + widget.nonAvailable;

  double get _availableShare =>
      _totalWallet <= 0 ? 1 : (widget.available / _totalWallet).clamp(0, 1.0);

  void _validate() {
    final v = _amount;
    String? err;
    if (_amountController.text.trim().isEmpty) {
      err = null;
    } else if (v <= 0) {
      err = 'Enter an amount greater than zero';
    } else if (v > widget.available) {
      err = 'Exceeds your available balance';
    }
    // Always rebuild on input changes — the Continue button's enabled state
    // and the live meter both depend on the current amount, so reacting only
    // when the error string flips would leave them stuck.
    setState(() => _amountError = err);
  }

  void _setPercent(double p) {
    final v = (widget.available * p).floor();
    final text = v == 0 ? '' : _amountFmt.format(v);
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Index of the quick-preset chip matching the current amount, so the
  /// segmented control can show which one is active (or none, if the user
  /// typed a custom amount).
  int? get _activePreset {
    if (_amountController.text.trim().isEmpty) return null;
    const presets = [.25, .50, .75, 1.0];
    for (var i = 0; i < presets.length; i++) {
      if ((widget.available * presets[i]).floor() == _amount.floor()) {
        return i;
      }
    }
    return null;
  }

  bool get _canContinue =>
      _amountError == null && _amount > 0 && _amount <= widget.available;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: media.viewInsets.bottom > 0 ? 16 : 48,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 22,
              bottom: 20 + media.viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildWalletSummary(),
                const SizedBox(height: 24),
                _label('Amount to withdraw'),
                const SizedBox(height: 10),
                _buildAmountField(),
                const SizedBox(height: 14),
                _buildQuickChips(),
                const SizedBox(height: 22),
                _label('Note', optional: true),
                const SizedBox(height: 8),
                _buildNoteField(),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Withdraw money',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                  letterSpacing: -.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tell the school how much to release.',
                style: TextStyle(fontSize: 13, color: _muted, height: 1.35),
              ),
            ],
          ),
        ),
        Material(
          color: _slate50,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(LucideIcons.x, size: 16, color: _muted),
            ),
          ),
        ),
      ],
    );
  }

  /// Wallet snapshot: available vs. locked (non-available) balance, with a
  /// two-segment bar showing their share of the total wallet.
  Widget _buildWalletSummary() {
    final hasLocked = widget.nonAvailable > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _walletStat(
                  dotColor: _blue,
                  label: 'Available',
                  value: widget.available,
                  valueColor: _navy,
                ),
              ),
              if (hasLocked)
                Expanded(
                  child: _walletStat(
                    dotColor: _rose,
                    label: 'Non-available',
                    value: widget.nonAvailable,
                    valueColor: _rose,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (_availableShare * 1000).round().clamp(1, 1000),
                    child: const ColoredBox(color: _blue),
                  ),
                  if (hasLocked)
                    Expanded(
                      flex: ((1 - _availableShare) * 1000).round().clamp(
                        1,
                        1000,
                      ),
                      child: ColoredBox(color: _rose.withValues(alpha: .55)),
                    ),
                ],
              ),
            ),
          ),
          if (hasLocked) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.lock, size: 11, color: _muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Non-available funds are deposits not yet confirmed '
                    'by the bank and can\'t be withdrawn yet.',
                    style: TextStyle(fontSize: 11, color: _muted, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _walletStat({
    required Color dotColor,
    required String label,
    required double value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_amountFmt.format(value)} ₭',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _navy,
            letterSpacing: .4,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          const Text(
            'OPTIONAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: .8,
            ),
          ),
        ],
      ],
    );
  }

  /// Minimal underline-style amount field: no boxed border, just a hairline
  /// that turns blue on focus / red on error, plus a live progress meter.
  /// Matches the app's shared input vocabulary (white fill, neutral border,
  /// blue focus border — see InputDecorationTheme in app_theme.dart) rather
  /// than introducing a one-off style, so it stays consistent with every
  /// other field in the app and doesn't fight the theme's own border.
  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ThousandsSeparatorInputFormatter(),
      ],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: _navy,
        letterSpacing: -.5,
      ),
      cursorColor: _blue,
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: _slate200,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16, right: 4),
          child: Center(
            widthFactor: 1,
            child: Text(
              '₭',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
        errorText: _amountError,
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          fontSize: 12,
          color: _rose,
          fontWeight: FontWeight.w600,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _rose, width: 1.6),
        ),
        helper: _amountError == null ? _buildAmountMeter() : null,
      ),
    );
  }

  /// Live "% of available balance" readout shown under the amount field
  /// while it's valid — replaced by the built-in error state when invalid.
  Widget _buildAmountMeter() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: _percent,
                backgroundColor: _slate100,
                valueColor: const AlwaysStoppedAnimation(_blue),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(_percent * 100).round()}% of available',
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    const presets = [.25, .50, .75, 1.0];
    final active = _activePreset;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < presets.length; i++) ...[
            if (i != 0) const SizedBox(width: 4),
            Expanded(
              child: _segment(
                label: presets[i] == 1.0
                    ? 'Max'
                    : '${(presets[i] * 100).round()}%',
                selected: active == i,
                onTap: () => _setPercent(presets[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: .08),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? _blue : _navy,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      minLines: 2,
      maxLines: 4,
      maxLength: 200,
      style: const TextStyle(
        fontSize: 14,
        color: _navy,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Anything the school should know?',
        hintStyle: const TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: _slate50,
        counterStyle: const TextStyle(fontSize: 11, color: _muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                backgroundColor: _slate50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _canContinue
                  ? () => Navigator.of(context).pop((
                      amount: _amount,
                      reasonId: _reason.id,
                      note: _noteController.text.trim(),
                    ))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                disabledBackgroundColor: _blue.withValues(alpha: .3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue'),
                  SizedBox(width: 6),
                  Icon(LucideIcons.arrowRight, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live-formats the amount field with thousand separators (e.g. "10000" →
/// "10,000") while preserving the user's caret position relative to the
/// digits they've typed so the cursor doesn't jump to the end on every key.
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _fmt = NumberFormat('#,##0');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    // Count digits before the caret so we can land the caret on the same
    // logical digit after the commas are reinserted.
    final selectionIndex = newValue.selection.end.clamp(
      0,
      newValue.text.length,
    );
    final digitsBeforeCaret = newValue.text
        .substring(0, selectionIndex)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final formatted = _fmt.format(int.parse(digits));
    int newCaret = 0;
    int seen = 0;
    while (newCaret < formatted.length && seen < digitsBeforeCaret) {
      if (RegExp(r'[0-9]').hasMatch(formatted[newCaret])) seen++;
      newCaret++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCaret),
    );
  }
}
