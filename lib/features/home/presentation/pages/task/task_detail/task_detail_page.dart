import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../../core/widgets/app_page_template.dart';

// ================= MODELS =================

enum TaskStatus { backlog, success }

enum TaskMediaType { image, video }

class TaskModel {
  final String id;
  final String headerTask;
  final String titleTask;
  final String createdBy;
  final DateTime createdAt;
  final DateTime deadline;
  final TaskStatus status;
  final TaskMediaType mediaType;
  final String mediaUrl;

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

class TaskCommentModel {
  final String id;
  final String senderName;
  final String message;
  final DateTime sentAt;

  /// if true => bubble on right (me)
  final bool isMe;

  const TaskCommentModel({
    required this.id,
    required this.senderName,
    required this.message,
    required this.sentAt,
    required this.isMe,
  });
}

// ================= PAGE =================

class TaskDetailPage extends StatefulWidget {
  final String backgroundAsset;
  final TaskModel task;

  const TaskDetailPage({
    super.key,
    required this.task,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _focus = FocusNode();

  late List<TaskCommentModel> _comments;

  @override
  void initState() {
    super.initState();
    _comments = _demoComments();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (!animated) {
        _scrollCtrl.jumpTo(target);
      } else {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.add(
        TaskCommentModel(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          senderName: 'Me',
          message: text,
          sentAt: DateTime.now(),
          isMe: true,
        ),
      );
    });

    _inputCtrl.clear();
    _focus.requestFocus();
    _scrollToBottom();

    // (optional demo) auto reply
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() {
          _comments.add(
            TaskCommentModel(
              id: 'c_${DateTime.now().millisecondsSinceEpoch}_bot',
              senderName: widget.task.createdBy,
              message: 'Received ✅ I will update this task.',
              sentAt: DateTime.now(),
              isMe: false,
            ),
          );
        });
        _scrollToBottom();
      });
    });
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
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  sliver: SliverToBoxAdapter(
                    child: _TaskCard(task: widget.task)
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideY(
                          begin: .05,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  sliver: SliverToBoxAdapter(
                    child: _ChatHeader()
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 220.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  sliver: SliverList.separated(
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = _comments[i];
                      return _MessageBubble(comment: c, isDark: isDark)
                          .animate()
                          .fadeIn(delay: (80 + i * 22).ms, duration: 220.ms)
                          .slideY(
                            begin: .06,
                            end: 0,
                            duration: 380.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                ),
                // bottom padding for composer
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),

          // composer
          _ComposerBar(controller: _inputCtrl, focusNode: _focus, onSend: _send)
              .animate()
              .fadeIn(delay: 120.ms, duration: 220.ms)
              .slideY(
                begin: .12,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }

  List<TaskCommentModel> _demoComments() {
    final now = DateTime.now();
    return [
      TaskCommentModel(
        id: 'c1',
        senderName: widget.task.createdBy,
        message: 'Please confirm the progress on this task.',
        sentAt: now.subtract(const Duration(hours: 6, minutes: 10)),
        isMe: false,
      ),
      TaskCommentModel(
        id: 'c2',
        senderName: 'Me',
        message: 'Ok, I will handle it today and update you.',
        sentAt: now.subtract(const Duration(hours: 6, minutes: 4)),
        isMe: true,
      ),
      TaskCommentModel(
        id: 'c3',
        senderName: widget.task.createdBy,
        message: 'Thanks! Deadline is close, please prioritize 🙏',
        sentAt: now.subtract(const Duration(hours: 5, minutes: 58)),
        isMe: false,
      ),
    ];
  }
}

// ================= TOP: TASK CARD (same style as Task page) =================

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
    final muted = isDark ? Colors.white.withOpacity(.70) : Colors.black54;

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
                    _MetaPill(
                      icon: LucideIcons.flag,
                      label: 'Deadline • ${_fmtDate(task.deadline)}',
                      isDark: isDark,
                    ),
                    _MetaPill(
                      icon: LucideIcons.info,
                      label: 'Status • $statusText',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Conversation below ↓',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _fmtDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';
  static String _fmtDateTime(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year} • ${_two(d.hour)}:${_two(d.minute)}';
}

// ================= CHAT UI =================

class _ChatHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final fg = isDark ? Colors.white.withOpacity(.92) : Colors.black87;
    final muted = isDark ? Colors.white.withOpacity(.70) : Colors.black54;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withOpacity(.10)
                : const Color(0xFFF3F4F6),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(.12)
                  : Colors.black.withOpacity(.06),
            ),
          ),
          child: Icon(LucideIcons.messagesSquare, color: fg, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conversation',
                style: t.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Send comment & track updates like a chatroom',
                style: t.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final TaskCommentModel comment;
  final bool isDark;

  const _MessageBubble({required this.comment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final maxW = MediaQuery.of(context).size.width * 0.78;

    final meBg = const Color(0xFF3B82F6).withOpacity(isDark ? .22 : .14);
    final meBorder = const Color(0xFF3B82F6).withOpacity(isDark ? .55 : .30);
    final otherBg = isDark ? Colors.white.withOpacity(.08) : Colors.white;
    final otherBorder = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);

    final fg = isDark ? Colors.white.withOpacity(.92) : Colors.black87;
    final muted = isDark ? Colors.white.withOpacity(.65) : Colors.black54;

    final align = comment.isMe ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: comment.isMe ? meBg : otherBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: comment.isMe ? meBorder : otherBorder),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(isDark ? .25 : .06),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // name + time
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmtTime(comment.sentAt),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment.message,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final bg = isDark
        ? Colors.black.withOpacity(.25)
        : Colors.white.withOpacity(.92);
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .45 : .10);

    final fieldBg = isDark
        ? Colors.white.withOpacity(.08)
        : const Color(0xFFF3F4F6);
    final fieldBorder = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);

    final hint = isDark
        ? Colors.white.withOpacity(.55)
        : Colors.black.withOpacity(.45);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border)),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, -10),
              color: shadow,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: fieldBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.messageCircle,
                      size: 18,
                      color: isDark
                          ? Colors.white.withOpacity(.75)
                          : Colors.black.withOpacity(.55),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white.withOpacity(.92)
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a comment...',
                          hintStyle: TextStyle(
                            color: hint,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(onTap: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const accent = Color(0xFF3B82F6);

    final bg = accent.withOpacity(isDark ? .28 : .16);
    final border = accent.withOpacity(isDark ? .55 : .30);
    final fg = isDark ? Colors.white.withOpacity(.92) : accent;

    return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 56,
              height: 52,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Icon(LucideIcons.send, color: fg, size: 20),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(.98, .98),
          end: const Offset(1, 1),
          duration: 220.ms,
          curve: Curves.easeOutCubic,
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
