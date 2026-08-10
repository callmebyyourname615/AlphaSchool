import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/widgets/app_page_template.dart';
import '../../../../../core/widgets/app_modern_count_tabbar.dart';

enum TaskStatus { backlog, success }

enum TaskMediaType { image, video }

class TaskModel {
  final String id;
  final String headerTask; // header task
  final String titleTask; // title task
  final String createdBy;
  final DateTime createdAt;
  final DateTime deadline;
  final TaskStatus status;
  final TaskMediaType mediaType;
  final String mediaUrl; // online image url (unsplash)

  const TaskModel({
    required this.id,
    required this.headerTask,
    required this.titleTask,
    required this.createdBy,
    required this.createdAt,
    required this.deadline,
    required this.status,
    required this.mediaType,
    required this.mediaUrl,
  });
}

// ================= PAGE: TASK LIST =================

class TaskPage extends StatefulWidget {
  final String backgroundAsset;

  const TaskPage({
    super.key,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final List<TaskModel> _all;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    final now = DateTime.now();
    _all = [
      TaskModel(
        id: 't1',
        headerTask: 'Content Production',
        titleTask: 'Shoot short intro video for school app',
        createdBy: 'Admin',
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
        deadline: now.add(const Duration(days: 2)),
        status: TaskStatus.backlog,
        mediaType: TaskMediaType.video,
        mediaUrl:
            'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?auto=format&fit=crop&w=1400&q=80',
      ),
      TaskModel(
        id: 't2',
        headerTask: 'Design',
        titleTask: 'Create banner for registration week',
        createdBy: 'Design Team',
        createdAt: now.subtract(const Duration(days: 4, hours: 6)),
        deadline: now.add(const Duration(days: 5)),
        status: TaskStatus.backlog,
        mediaType: TaskMediaType.image,
        mediaUrl:
            'https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&w=1400&q=80',
      ),
      TaskModel(
        id: 't3',
        headerTask: 'Operations',
        titleTask: 'Prepare welcome kit inventory',
        createdBy: 'Front Office',
        createdAt: now.subtract(const Duration(days: 6)),
        deadline: now.add(const Duration(days: 1)),
        status: TaskStatus.backlog,
        mediaType: TaskMediaType.image,
        mediaUrl:
            'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1400&q=80',
      ),
      TaskModel(
        id: 't4',
        headerTask: 'IT',
        titleTask: 'Deploy latest build to Firebase Hosting',
        createdBy: 'Developer',
        createdAt: now.subtract(const Duration(days: 8)),
        deadline: now.subtract(const Duration(days: 1)),
        status: TaskStatus.success,
        mediaType: TaskMediaType.image,
        mediaUrl:
            'https://images.unsplash.com/photo-1518779578993-ec3579fee39f?auto=format&fit=crop&w=1400&q=80',
      ),
      TaskModel(
        id: 't5',
        headerTask: 'Academics',
        titleTask: 'Confirm parent meeting schedule',
        createdBy: 'Teacher',
        createdAt: now.subtract(const Duration(days: 9, hours: 2)),
        deadline: now.subtract(const Duration(hours: 6)),
        status: TaskStatus.success,
        mediaType: TaskMediaType.image,
        mediaUrl:
            'https://images.unsplash.com/photo-1523580846011-d3a5bc25702b?auto=format&fit=crop&w=1400&q=80',
      ),
    ];
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ✅ counts
  int get _totalCount => _all.length;
  int get _backlogCount =>
      _all.where((e) => e.status == TaskStatus.backlog).length;
  int get _successCount =>
      _all.where((e) => e.status == TaskStatus.success).length;

  List<TaskModel> _filteredForTab(int index) {
    if (index == 0) return _all;
    if (index == 1) {
      return _all.where((e) => e.status == TaskStatus.backlog).toList();
    }
    return _all.where((e) => e.status == TaskStatus.success).toList();
  }

  void _openDetail(TaskModel task) {
    Navigator.of(context).pushNamed('/tasks/speech-exercise', arguments: task);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final tabs = AppModernCountTabBar(
      controller: _tab,
      items: [
        AppTabItem(label: 'ທັງໝົດ', icon: LucideIcons.list, count: _totalCount),
        AppTabItem(
          label: 'ວຽກຄ້າງ',
          icon: LucideIcons.clock3,
          count: _backlogCount,
        ),
        AppTabItem(
          label: 'ສຳເລັດ',
          icon: LucideIcons.badgeCheck,
          count: _successCount,
        ),
      ],
    );

    return AppPageTemplate(
      title: 'Tasks',
      backgroundAsset: widget.backgroundAsset,
      animate: true,
      premiumDark: true,

      // ✅ FIX: ให้มีลูกศร back และกดแล้ว pop เหมือนหน้า ContactPage
      showBack: true,

      scrollable: false,
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: tabs,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(), // ✅ no swipe
              children: [
                _TaskListView(
                  items: _filteredForTab(0),
                  isDark: isDark,
                  onTapTask: _openDetail,
                ),
                _TaskListView(
                  items: _filteredForTab(1),
                  isDark: isDark,
                  onTapTask: _openDetail,
                ),
                _TaskListView(
                  items: _filteredForTab(2),
                  isDark: isDark,
                  onTapTask: _openDetail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= UI: Modern Tabs =================

class _ModernTaskTabs extends StatelessWidget {
  final TabController controller;
  final int totalCount;
  final int backlogCount;
  final int successCount;

  const _ModernTaskTabs({
    required this.controller,
    required this.totalCount,
    required this.backlogCount,
    required this.successCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    // ✅ Responsive tuning to prevent overflow on iPhone 14 (and smaller)
    final w = MediaQuery.sizeOf(context).width;
    final bool compact = w < 390;
    final bool iPhone14Like = w <= 390;

    final double tabH = (compact ? 40 : (iPhone14Like ? 42 : 44)).toDouble();
    final double iconSize = compact ? 16 : 18;

    // ✅ ลด spacing ระหว่าง icon / title / number ลงอีกนิด
    final double gap = compact ? 5 : 7;

    final double outerPad = compact ? 5 : 6;

    final outerBg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.white.withOpacity(.92);
    final outerBorder = isDark
        ? Colors.white.withOpacity(.14)
        : Colors.black.withOpacity(.06);
    final outerShadow = isDark
        ? Colors.black.withOpacity(.35)
        : Colors.black.withOpacity(.08);
    final unselected = isDark
        ? Colors.white.withOpacity(.70)
        : Colors.black.withOpacity(.55);

    final labelStyle = t.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: .1,
      fontSize: compact ? 12.6 : 13.2,
      height: 1.0,
    );

    final unselectedStyle = t.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: .1,
      fontSize: compact ? 12.6 : 13.2,
      height: 1.0,
    );

    return Container(
      padding: EdgeInsets.all(outerPad),
      decoration: BoxDecoration(
        color: outerBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: outerBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 12),
            color: outerShadow,
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        splashBorderRadius: BorderRadius.circular(18),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,

        // ✅ important: make tab width share evenly (prevents row overflow)
        isScrollable: false,

        labelStyle: labelStyle,
        unselectedLabelStyle: unselectedStyle,
        labelColor: Colors.white,
        unselectedLabelColor: unselected,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF2563EB)],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: const Color(0xFF3B82F6).withOpacity(.28),
            ),
          ],
        ),
        tabs: [
          _TabPill(
            height: tabH,
            text: 'ທັງໝົດ',
            icon: LucideIcons.list,
            count: totalCount,
            iconSize: iconSize,
            gap: gap,
            compact: compact,
          ),
          _TabPill(
            height: tabH,
            text: 'ວຽກຄ້າງ',
            icon: LucideIcons.clock3,
            count: backlogCount,
            iconSize: iconSize,
            gap: gap,
            compact: compact,
          ),
          _TabPill(
            height: tabH,
            text: 'ສຳເລັດ',
            icon: LucideIcons.badgeCheck,
            count: successCount,
            iconSize: iconSize,
            gap: gap,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final int count;

  // ✅ responsive params
  final double height;
  final double iconSize;
  final double gap;
  final bool compact;

  const _TabPill({
    required this.text,
    required this.icon,
    required this.count,
    required this.height,
    required this.iconSize,
    required this.gap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeBg = isDark
        ? Colors.white.withOpacity(.18)
        : Colors.white.withOpacity(.22);
    final badgeBorder = Colors.white.withOpacity(.28);

    return SizedBox(
      height: height,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize),
              SizedBox(width: gap),
              ConstrainedBox(
                // ✅ ลด maxWidth ลงนิดให้บาลานซ์ (ไม่ดัน badge)
                constraints: BoxConstraints(maxWidth: compact ? 78 : 92),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              SizedBox(width: gap),
              _CountBadge(
                    count: count,
                    bg: badgeBg,
                    border: badgeBorder,
                    compact: compact,
                  )
                  .animate()
                  .fadeIn(duration: 180.ms)
                  .scale(
                    begin: const Offset(.96, .96),
                    end: const Offset(1, 1),
                    duration: 220.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color bg;
  final Color border;
  final bool compact;

  const _CountBadge({
    required this.count,
    required this.bg,
    required this.border,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: BoxConstraints(minWidth: compact ? 22 : 24),
      height: compact ? 18 : 20,

      // ✅ ลด padding ใน badge ลงนิด (ทำให้ spacing ดูแน่นขึ้น)
      padding: EdgeInsets.symmetric(horizontal: compact ? 5.5 : 6.5),

      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: compact ? 10.8 : 11.5,
          letterSpacing: .15,
        ),
      ),
    );
  }
}

// ================= UI: List =================

class _TaskListView extends StatelessWidget {
  final List<TaskModel> items;
  final bool isDark;
  final ValueChanged<TaskModel> onTapTask;

  const _TaskListView({
    required this.items,
    required this.isDark,
    required this.onTapTask,
  });

  @override
  Widget build(BuildContext context) {
    final safeB = MediaQuery.of(context).padding.bottom;
    final bottomBarH = kBottomNavigationBarHeight + 18;

    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: safeB + bottomBarH),
        child: _EmptyTasks(isDark: isDark)
            .animate()
            .fadeIn(duration: 220.ms)
            .slideY(
              begin: .05,
              end: 0,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 16 + safeB + bottomBarH),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final task = items[i];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ClickableTaskCard(task: task, onTap: () => onTapTask(task))
              .animate()
              .fadeIn(delay: (80 + i * 60).ms, duration: 240.ms)
              .slideY(
                begin: .06,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
        );
      },
    );
  }
}

class _ClickableTaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const _ClickableTaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(child: _TaskCard(task: task)),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  final bool isDark;

  const _EmptyTasks({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    return Center(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: shadow,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleCheck,
              size: 44,
              color: isDark ? Colors.white.withOpacity(.85) : Colors.black54,
            ),
            const SizedBox(height: 10),
            Text(
              'No tasks here',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another tab or add new tasks later.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: t.colorScheme.onSurface.withOpacity(.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= UI: Task Card (Reusable) =================

class _TaskCard extends StatelessWidget {
  final TaskModel task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    final headerColor = isDark ? Colors.white : Colors.black.withOpacity(.90);

    final statusColor = task.status == TaskStatus.success
        ? const Color(0xFF22C55E)
        : const Color(0xFFF59E0B);
    final statusText = task.status == TaskStatus.success
        ? 'Success'
        : 'Backlog';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  task.mediaUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: isDark
                          ? Colors.white.withOpacity(.06)
                          : const Color(0xFFF3F4F6),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? Colors.white.withOpacity(.85)
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark
                        ? Colors.white.withOpacity(.06)
                        : const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(LucideIcons.imageOff, size: 28),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(.05),
                          Colors.black.withOpacity(.35),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Chip(
                    icon: task.mediaType == TaskMediaType.video
                        ? LucideIcons.video
                        : LucideIcons.image,
                    label: task.mediaType == TaskMediaType.video
                        ? 'Video'
                        : 'Image',
                    bg: Colors.black.withOpacity(.45),
                    fg: Colors.white,
                    border: Colors.white.withOpacity(.18),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _Chip(
                    icon: LucideIcons.timer,
                    label: 'Deadline • ${_fmtDate(task.deadline)}',
                    bg: Colors.black.withOpacity(.45),
                    fg: Colors.white,
                    border: Colors.white.withOpacity(.18),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.headerTask,
                        style: t.textTheme.titleMedium?.copyWith(
                          color: headerColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Chip(
                      icon: task.status == TaskStatus.success
                          ? LucideIcons.badgeCheck
                          : LucideIcons.clock3,
                      label: 'Status • $statusText',
                      bg: isDark
                          ? Colors.white.withOpacity(.10)
                          : statusColor.withOpacity(.10),
                      fg: isDark ? Colors.white.withOpacity(.92) : statusColor,
                      border: isDark
                          ? Colors.white.withOpacity(.12)
                          : statusColor.withOpacity(.22),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.titleTask,
                  style: t.textTheme.bodyLarge?.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaPill(
                      icon: LucideIcons.calendarDays,
                      label: 'Created • ${_fmtDateTime(task.createdAt)}',
                      isDark: isDark,
                    ),
                    _MetaPill(
                      icon: LucideIcons.user,
                      label: 'By • ${task.createdBy}',
                      isDark: isDark,
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

// ================= PAGE: TASK DETAIL (CARD + CHATROOM) =================

class TaskDetailPage extends StatefulWidget {
  final TaskModel task;
  final String backgroundAsset;

  const TaskDetailPage({
    super.key,
    required this.task,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  late final List<_ChatMessage> _messages;

  @override
  void initState() {
    super.initState();

    // ✅ demo conversation
    _messages = [
      _ChatMessage(
        id: 'm1',
        sender: widget.task.createdBy,
        text: 'Please update the progress when ready 🙏',
        at: DateTime.now().subtract(const Duration(hours: 3, minutes: 12)),
        isMe: false,
      ),
      _ChatMessage(
        id: 'm2',
        sender: 'Me',
        text: 'Got it! I will start today.',
        at: DateTime.now().subtract(const Duration(hours: 2, minutes: 55)),
        isMe: true,
      ),
      _ChatMessage(
        id: 'm3',
        sender: widget.task.createdBy,
        text: 'Thanks! Deadline is important.',
        at: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
        isMe: false,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'Me',
          text: text,
          at: DateTime.now(),
          isMe: true,
        ),
      );
    });

    _controller.clear();

    // auto reply demo
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}_r',
            sender: widget.task.createdBy,
            text: 'Received 👍',
            at: DateTime.now(),
            isMe: false,
          ),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    return AppPageTemplate(
      title: 'Task Detail',
      backgroundAsset: widget.backgroundAsset,
      animate: true,
      premiumDark: true,
      showBack: true,
      scrollable: false, // ✅ manage scroll ourselves
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: _TaskCard(task: widget.task)
                .animate()
                .fadeIn(duration: 220.ms)
                .slideY(
                  begin: .06,
                  end: 0,
                  duration: 420.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
          Expanded(
            child:
                _ChatRoom(
                      messages: _messages,
                      scrollController: _scrollCtrl,
                      isDark: isDark,
                    )
                    .animate()
                    .fadeIn(delay: 60.ms, duration: 240.ms)
                    .slideY(
                      begin: .05,
                      end: 0,
                      duration: 420.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
          SafeArea(
            top: false,
            child:
                _Composer(
                      controller: _controller,
                      isDark: isDark,
                      onSend: _send,
                    )
                    .animate()
                    .fadeIn(delay: 120.ms, duration: 220.ms)
                    .slideY(
                      begin: .08,
                      end: 0,
                      duration: 420.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime at;
  final bool isMe;

  _ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.at,
    required this.isMe,
  });
}

class _ChatRoom extends StatelessWidget {
  final List<_ChatMessage> messages;
  final ScrollController scrollController;
  final bool isDark;

  const _ChatRoom({
    required this.messages,
    required this.scrollController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final bg = isDark
        ? Colors.white.withOpacity(.06)
        : Colors.white.withOpacity(.92);
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .35 : .08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: shadow,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            return _Bubble(message: m, isDark: isDark, textTheme: t.textTheme)
                .animate()
                .fadeIn(delay: (20 + i * 35).ms, duration: 200.ms)
                .slideY(
                  begin: .06,
                  end: 0,
                  duration: 360.ms,
                  curve: Curves.easeOutCubic,
                );
          },
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  final bool isDark;
  final TextTheme textTheme;

  const _Bubble({
    required this.message,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final me = message.isMe;

    final bubbleBg = me
        ? const Color(0xFF3B82F6).withOpacity(isDark ? .35 : .18)
        : (isDark ? Colors.white.withOpacity(.10) : const Color(0xFFF3F4F6));

    final bubbleBorder = me
        ? const Color(0xFF3B82F6).withOpacity(isDark ? .55 : .35)
        : (isDark
              ? Colors.white.withOpacity(.12)
              : Colors.black.withOpacity(.06));

    final nameColor = isDark
        ? Colors.white.withOpacity(.80)
        : Colors.black.withOpacity(.65);
    final textColor = isDark
        ? Colors.white.withOpacity(.92)
        : Colors.black.withOpacity(.88);

    final align = me ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowAlign = me ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: rowAlign,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: align,
              children: [
                Text(
                  me ? 'You' : message.sender,
                  style: textTheme.bodySmall?.copyWith(
                    color: nameColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bubbleBorder),
                  ),
                  child: Text(
                    message.text,
                    style: textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);
    final bg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.white.withOpacity(.92);
    final shadow = Colors.black.withOpacity(isDark ? .35 : .08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: shadow,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white.withOpacity(.55)
                        : Colors.black.withOpacity(.40),
                  ),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withOpacity(.92)
                      : Colors.black.withOpacity(.88),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(isDark: isDark, onTap: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _SendButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);

    final bg = accent.withOpacity(isDark ? .35 : .16);
    final border = accent.withOpacity(isDark ? .55 : .30);
    final fg = isDark ? Colors.white.withOpacity(.92) : accent;

    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.send, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    'Send',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 160.ms)
        .scale(
          begin: const Offset(.98, .98),
          end: const Offset(1, 1),
          duration: 220.ms,
        );
  }
}

// ================= Small UI Pieces =================

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  const _Chip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .15,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? Colors.white.withOpacity(.88)
        : Colors.black.withOpacity(.75);
    final bg = isDark ? Colors.white.withOpacity(.08) : const Color(0xFFF3F4F6);
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Helpers =================

String _two(int n) => n.toString().padLeft(2, '0');
String _fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _fmtDateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} • ${_two(d.hour)}:${_two(d.minute)}';
