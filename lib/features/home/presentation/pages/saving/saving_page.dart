import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/global_alert_service.dart';
import '../../../../../core/widgets/app_page_template.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'saving_model.dart';
import 'saving_service.dart';

class SavingPage extends StatefulWidget {
  const SavingPage({super.key, required this.selectedStudent});

  final StudentCardItem? selectedStudent;

  @override
  State<SavingPage> createState() => _SavingPageState();
}

class _SavingPageState extends State<SavingPage> with TickerProviderStateMixin {
  static const double _maxWidth = 680;

  // ✅ ใช้ bg เดียวกับ template (คุณปรับได้)
  static const String _bgAsset = "assets/images/homepagewall/mainbg.jpeg";

  late final TabController _tab;

  DateTime? _fromDate;
  DateTime? _toDate;

  final _service = SavingService();
  List<_SavingTxn> _personalData = const [];
  List<_SavingTxn> _classData = const [];
  double _personalBalance = 0;
  double _classBalance = 0;
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

  _SavingTxn _toTxn(SavingTransaction item) => _SavingTxn(
    date: item.createdAt,
    inAmount: item.transactionType == 'DEPOSIT' ? item.amount : 0,
    outAmount: item.transactionType == 'WITHDRAW' ? item.amount : 0,
    closingBalance: item.closingBalance,
  );

  Future<void> _onWithdrawPressed() async {
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

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    var selectedReason = reasons.first;
    final request = await showDialog<({double amount, String reasonId})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Withdraw money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  helperText:
                      'Available: ${NumberFormat('#,##0.##').format(_personalBalance)}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WithdrawalReason>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: 'Reason'),
                isExpanded: true,
                items: reasons
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedReason = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  amountController.text.replaceAll(',', '').trim(),
                );
                if (value != null && value > 0 && value <= _personalBalance) {
                  Navigator.pop(dialogContext, (
                    amount: value,
                    reasonId: selectedReason.id,
                  ));
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (request == null || !mounted) {
      amountController.dispose();
      noteController.dispose();
      return;
    }
    final confirmed = await GlobalAlert.showConfirmation(
      title: 'Confirm withdrawal',
      message:
          'Request withdrawal of ${NumberFormat('#,##0').format(request.amount)}?',
    );
    if (confirmed != true) {
      amountController.dispose();
      noteController.dispose();
      return;
    }
    GlobalAlert.showLoading(message: 'Submitting withdrawal request...');
    try {
      await _service.requestWithdrawal(
        studentId: widget.selectedStudent!.id!,
        amount: request.amount,
        withdrawReasonId: request.reasonId,
        note: noteController.text,
      );
      GlobalAlert.dismiss();
      GlobalAlert.showSuccess(
        title: 'Request submitted',
        message: 'Your withdrawal is waiting for school approval.',
      );
      await _load();
    } catch (error) {
      GlobalAlert.dismiss();
      GlobalAlert.showError(
        title: 'Withdrawal failed',
        message: error.toString(),
      );
    } finally {
      amountController.dispose();
      noteController.dispose();
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
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

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
              final t = Theme.of(context);
              final isDark = t.brightness == Brightness.dark;

              // ✅ premium dark gradient for panels
              final Gradient premiumPanelGrad = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B2B5B).withOpacity(.78),
                  const Color(0xFF071A33).withOpacity(.88),
                  const Color(0xFF060B16).withOpacity(.92),
                ],
              );

              final border = isDark
                  ? Colors.white.withOpacity(.12)
                  : Colors.black.withOpacity(.06);
              final shadow = Colors.black.withOpacity(isDark ? .45 : .08);

              final textPrimary = isDark
                  ? Colors.white
                  : const Color(0xFF111827);
              final textMuted = isDark
                  ? Colors.white.withOpacity(.70)
                  : const Color(0xFF6B7280);

              return AppPageTemplate(
                title: "ເງິນຝາກປະຫຍັດ",
                backgroundAsset: _bgAsset,
                scrollable: false,
                premiumDark: true,

                // ✅ ให้ back ทำงานเหมือน ContactPage (Template handle pop เอง)
                showBack: true,

                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: SizedBox.expand(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Panel(
                                isDark: isDark,
                                border: border,
                                shadow: shadow,
                                color: isDark ? null : Colors.white,
                                gradient: isDark ? premiumPanelGrad : null,
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
                              .slideY(begin: .08, end: 0),

                          const SizedBox(height: 12),

                          Expanded(
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _error != null
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _error!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: textMuted),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton.icon(
                                          onPressed: _load,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry'),
                                        ),
                                      ],
                                    ),
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
                                        panelGrad: premiumPanelGrad,
                                        dataBuilder: () => _buildView(
                                          _dataForTab(0),
                                          _personalBalance,
                                        ),
                                        onWithdraw: _onWithdrawPressed,
                                        typeLabel: "ສ່ວນບຸກຄົນ",
                                      ),
                                      _SavingTabBody(
                                        isDark: isDark,
                                        border: border,
                                        shadow: shadow,
                                        textPrimary: textPrimary,
                                        textMuted: textMuted,
                                        panelGrad: premiumPanelGrad,
                                        dataBuilder: () => _buildView(
                                          _dataForTab(1),
                                          _classBalance,
                                        ),
                                        onWithdraw: null,
                                        typeLabel: "ຫ້ອງຮຽນ",
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
    final locale = Localizations.localeOf(context).toString();
    final df = _safeDateFmt('dd MMM yyyy', locale);

    final fromText = from == null ? "Any" : df.format(from!);
    final toText = to == null ? "Any" : df.format(to!);

    final bg = isDark
        ? const Color(0xFF071A33).withOpacity(.45)
        : const Color(0xFFF3F4F6);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.sliders, color: textPrimary, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$fromText  →  $toText",
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
            ),
            Text(
              "ຄົ້ນຫາ",
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            FaIcon(FontAwesomeIcons.chevronRight, color: textMuted, size: 14),
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
    final bg = isDark
        ? const Color(0xFF071A33).withOpacity(.45)
        : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(14),
        indicator: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        labelColor: textPrimary,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
        tabs: const [
          Tab(text: "ສ່ວນບຸກຄົນ"),
          Tab(text: "ຫ້ອງຮຽນ"),
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

  final Gradient panelGrad;
  final _SavingView Function() dataBuilder;

  /// ✅ Personal มีปุ่ม / Class ส่ง null เพื่อซ่อนปุ่ม
  final VoidCallback? onWithdraw;

  /// ✅ เพิ่ม: type label
  final String typeLabel;

  const _SavingTabBody({
    required this.isDark,
    required this.border,
    required this.shadow,
    required this.textPrimary,
    required this.textMuted,
    required this.panelGrad,
    required this.dataBuilder,
    required this.onWithdraw,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final view = dataBuilder();
    final rows = view.rows;

    return _Panel(
          isDark: isDark,
          border: border,
          shadow: shadow,
          color: isDark ? null : Colors.white,
          gradient: isDark ? panelGrad : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
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
                      ? Center(
                          child: Text(
                            "No data in selected range",
                            style: TextStyle(
                              color: textMuted,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 10),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark
                                ? Colors.white.withOpacity(.08)
                                : Colors.black.withOpacity(.06),
                          ),
                          itemBuilder: (context, i) {
                            return _TableRowItem(
                                  isDark: isDark,
                                  row: rows[i],
                                  textPrimary: textPrimary,
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
    final bg = isDark
        ? const Color(0xFF071A33).withOpacity(.35)
        : const Color(0xFFF7F8FA);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: Text(
              "ວັນທີ",
              style: TextStyle(
                color: textMuted,
                fontWeight: FontWeight.w900,
                letterSpacing: .2,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.center,
              child: Text(
                "ຝາກ / ຖອນ",
                style: TextStyle(
                  color: textMuted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "ຍອດເຫຼືອ",
                style: TextStyle(
                  color: textMuted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _TableRowItem extends StatelessWidget {
  final bool isDark;
  final _SavingRow row;
  final Color textPrimary;

  const _TableRowItem({
    required this.isDark,
    required this.row,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final df = _safeDateFmt('yyyy/MM/dd', locale);
    final nf = _safeNumFmt(locale);

    final dateText = df.format(row.txn.date);

    final net = row.txn.inAmount > 0 ? row.txn.inAmount : -row.txn.outAmount;
    final netText = net == 0
        ? ""
        : (net > 0 ? "+${nf.format(net)}" : "−${nf.format(net.abs())}");

    final netColor = net > 0
        ? const Color(0xFF22C55E)
        : (net < 0 ? const Color(0xFFEF4444) : Colors.black.withOpacity(.25));

    final balText = nf.format(row.balance.abs());
    final balPrefix = row.balance >= 0 ? "" : "−";
    final balColor = isDark ? Colors.white : const Color(0xFF111827);

    final rowBg = isDark
        ? const Color(0xFF071A33).withOpacity(.28)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(color: rowBg),
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: Text(
              dateText,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13.2,
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.center,
              child: Text(
                netText,
                style: TextStyle(
                  color: netColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "$balPrefix$balText",
                style: TextStyle(
                  color: balColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// SAVING DETAIL (ซ่อนปุ่มได้ด้วย onWithdraw == null)
// ======================================================
class _SavingDetailPremium extends StatelessWidget {
  final _SavingView view;
  final Color border;

  /// ✅ null = ไม่มีปุ่ม (ใช้กับ Class)
  final VoidCallback? onWithdraw;

  /// ✅ เพิ่ม: type label
  final String typeLabel;

  const _SavingDetailPremium({
    required this.view,
    required this.border,
    required this.onWithdraw,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final nf = _safeNumFmt(locale);

    final totalInText = nf.format(view.totalIn);
    final totalOutText = nf.format(view.totalOut);

    final latest = view.latestIn;
    final latestText = latest == null ? "-" : nf.format(latest.inAmount);

    final bal = view.totalBalance;
    final balText = nf.format(bal);

    const grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B2B5B), Color(0xFF071A33), Color(0xFF060B16)],
    );

    final titleC = Colors.white.withOpacity(.82);
    final labelC = Colors.white.withOpacity(.72);
    final lineC = Colors.white.withOpacity(.14);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: grad,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                "ລາຍລະອຽດ ",
                style: TextStyle(
                  color: titleC,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              FaIcon(
                FontAwesomeIcons.circleInfo,
                size: 14,
                color: Colors.white.withOpacity(.70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.14)),
            ),
            child: Column(
              children: [
                _DetailLine(
                  label: "ປະເພດ :",
                  value: typeLabel,
                  labelColor: labelC,
                  valueColor: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 1, color: lineC),
                ),
                _DetailLine(
                  label: "ຍອດຍົກມາ :",
                  value: latestText,
                  labelColor: labelC,
                  valueColor: const Color(0xFF22C55E),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 1, color: lineC),
                ),
                _DetailLine(
                  label: "ຍອດເຄື່ອນໄຫວຝາກ :",
                  value: totalInText,
                  labelColor: labelC,
                  valueColor: const Color(0xFF22C55E),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 1, color: lineC),
                ),
                _DetailLine(
                  label: "ຍອດເຄື່ອນໄຫວຖອນ :",
                  value: totalOutText,
                  labelColor: labelC,
                  valueColor: const Color(0xFFEF4444),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 1, color: lineC),
                ),
                Row(
                  children: [
                    Text(
                      "ຍອດເຫຼືອທ້າຍ :",
                      style: TextStyle(
                        color: labelC,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                        fontSize: 12.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      balText,
                      style: const TextStyle(
                        color: Colors.white,
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
          if (onWithdraw != null) ...[
            const SizedBox(height: 12),
            _BigWithdrawButton(onTap: onWithdraw!),
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
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
            fontSize: 12.8,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
            fontSize: 15.8,
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
    const btnColor = Color(0xFF3B5FD9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: btnColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(.30),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              FaIcon(
                FontAwesomeIcons.handHoldingDollar,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                "Withdraw money",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                  fontSize: 15.5,
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

  const _SavingTxn({
    required this.date,
    required this.inAmount,
    required this.outAmount,
    required this.closingBalance,
  });
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
DateFormat _safeDateFmt(String pattern, String localeTag) {
  try {
    return DateFormat(pattern, localeTag);
  } catch (_) {
    return DateFormat(pattern, 'en');
  }
}

NumberFormat _safeNumFmt(String localeTag) {
  try {
    return NumberFormat.decimalPattern(localeTag);
  } catch (_) {
    return NumberFormat.decimalPattern('en');
  }
}
