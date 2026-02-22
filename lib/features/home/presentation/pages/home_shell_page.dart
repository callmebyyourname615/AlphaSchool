import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../shared/models/student_card_item.dart';

// Tab pages list at homepage
import 'tabs/mainhomepage.dart';
import 'tabs/classroom.dart';
import 'tabs/score.dart';
import 'tabs/fee.dart';
import 'tabs/setting_page.dart';

class HomeShellPage extends StatefulWidget {
  /// ✅ nullable กันเคสเข้า route นี้โดยไม่ได้ส่ง student
  final StudentCardItem? selectedStudent;

  /// ✅ สามารถกำหนดแท็บเริ่มต้นได้ (0=Explore)
  final int initialIndex;

  const HomeShellPage({super.key, this.selectedStudent, this.initialIndex = 0});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage>
    with SingleTickerProviderStateMixin {
  // ---- Helpers (avoid withOpacity deprecated style you use) ----
  int _alpha(double o) => (o * 255).round().clamp(0, 255);
  Color _o(Color c, double opacity) => c.withAlpha(_alpha(opacity));

  int _index = 0;
  bool _didInitFromArgs = false;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ รองรับ route arguments: {'tab': 0}
    if (_didInitFromArgs) return;
    _didInitFromArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final tab = args['tab'];
      if (tab is int) _index = tab.clamp(0, 4);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPlus() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final card = isDark ? AppColors.dark : Colors.white;
        final border = isDark
            ? _o(Colors.white, .10)
            : _o(AppColors.slate, .12);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                    color: _o(Colors.black, isDark ? .35 : .12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _o(isDark ? Colors.white : Colors.black, .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SheetAction(
                    icon: Icons.add_task_rounded,
                    title: "Create task",
                    onTap: () => Navigator.pop(ctx),
                  ),
                  _SheetAction(
                    icon: Icons.payments_rounded,
                    title: "Quick payment",
                    onTap: () => Navigator.pop(ctx),
                  ),
                  _SheetAction(
                    icon: Icons.event_available_rounded,
                    title: "New appointment",
                    onTap: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ Android back / iOS gesture:
  // - ถ้าไม่ได้อยู่แท็บ Explore -> สลับกลับ Explore ก่อน
  // - ถ้าอยู่ Explore แล้ว -> ให้ระบบทำงานปกติ
  Future<bool> _onWillPop() async {
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.dark : Colors.white;

    final pages = <Widget>[
      const ExplorePage(),
      const ClassroomPage(),
      const StudyPlanPage(),
      const FeePage(),
      const SettingsPage(),
    ];

    final navItems = const [
      AppBottomNavItem(icon: FontAwesomeIcons.house, label: "ໜ້າຫຼັກ"),
      AppBottomNavItem(icon: FontAwesomeIcons.chalkboardUser, label: "ຫ້ອງຮຽນ"),
      AppBottomNavItem(icon: FontAwesomeIcons.chartLine, label: "ຜົນການຮຽນ"),
      AppBottomNavItem(icon: FontAwesomeIcons.sackXmark, label: "ຄ່າທຳນຽມ"),
      AppBottomNavItem(icon: FontAwesomeIcons.gear, label: "ຕັ້ງຄ່າ"),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: bg,
        extendBody: true,
        bottomNavigationBar: AppBottomNav(
          currentIndex: _index,
          onChanged: (i) => setState(() => _index = i),
          items: navItems,
          onPlusPressed: _onPlus,
        ),
        body: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: pages[_index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  int _alpha(double o) => (o * 255).round().clamp(0, 255);
  Color _o(Color c, double opacity) => c.withAlpha(_alpha(opacity));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? _o(Colors.white, .10) : _o(AppColors.slate, .12);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          color: isDark ? _o(Colors.white, .06) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue500),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.blue500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _o(isDark ? Colors.white : Colors.black, .35),
            ),
          ],
        ),
      ),
    );
  }
}
