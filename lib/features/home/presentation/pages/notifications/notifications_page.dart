// notification_details_page.dart
// ✅ Adaptive theme (Light/Dark) + premium dark-blue glassmorphism
// ✅ View All -> NotificationDetailsPage(items: ...)
// ✅ Tap item -> opens CLEAN glass POPUP (no navigation)
// ✅ Full content (SelectableText) + Copy + Mark read/unread
// ✅ flutter_animate animations
//
// ✅ FIX (per request): "tabbar/segmented" text in DarkMode is now pure white (#FFFFFF)

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// -------------------------
/// Model (match your mapping)
/// -------------------------
class NotificationEntry {
  final String sender;
  final String title;
  final String body;
  final String timeText;
  final bool isUnread;

  NotificationEntry({
    required this.sender,
    required this.title,
    required this.body,
    required this.timeText,
    required this.isUnread,
  });

  /// ✅ Use this when converting from your popup overlay model:
  /// - time can be DateTime (recommended) or String
  factory NotificationEntry.fromPopup({
    required String sender,
    required String title,
    required String body,
    required Object time,
    required bool isUnread,
  }) {
    return NotificationEntry(
      sender: sender,
      title: title,
      body: body,
      timeText: _timeToText(time),
      isUnread: isUnread,
    );
  }

  NotificationEntry copyWith({
    String? sender,
    String? title,
    String? body,
    String? timeText,
    bool? isUnread,
  }) {
    return NotificationEntry(
      sender: sender ?? this.sender,
      title: title ?? this.title,
      body: body ?? this.body,
      timeText: timeText ?? this.timeText,
      isUnread: isUnread ?? this.isUnread,
    );
  }

  static String _timeToText(Object t) {
    if (t is DateTime) {
      String two(int v) => v.toString().padLeft(2, '0');
      return "${t.year}-${two(t.month)}-${two(t.day)}  ${two(t.hour)}:${two(t.minute)}";
    }
    return t.toString();
  }
}

/// -------------------------
/// Premium Adaptive tokens (Light/Dark)
/// -------------------------
class _NTokens {
  final bool isDark;

  final Color bgFallback;
  final Color title;
  final Color text;
  final Color sub;
  final Color line;

  final Color blue;
  final Color green;
  final Color amber;

  final Color sheetA;
  final Color sheetB;
  final Color sheetC;

  final Color blockBg;
  final Color barrier;

  // ✅ premium extras (dark mode)
  final List<Color> overlayGradient;
  final Color glowBlue;
  final Color glowCyan;
  final Color hairline;
  final Color softHighlight;

  const _NTokens({
    required this.isDark,
    required this.bgFallback,
    required this.title,
    required this.text,
    required this.sub,
    required this.line,
    required this.blue,
    required this.green,
    required this.amber,
    required this.sheetA,
    required this.sheetB,
    required this.sheetC,
    required this.blockBg,
    required this.barrier,
    required this.overlayGradient,
    required this.glowBlue,
    required this.glowCyan,
    required this.hairline,
    required this.softHighlight,
  });

  static int _a(double o) => (o * 255).round().clamp(0, 255);
  static Color _o(Color c, double opacity) => c.withAlpha(_a(opacity));

  factory _NTokens.of(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final cs = t.colorScheme;

    if (!isDark) {
      // Light (keep your original look)
      return _NTokens(
        isDark: false,
        bgFallback: const Color(0xFFF6F7FB),
        title: const Color(0xFF111827),
        text: const Color(0xFF374151),
        sub: const Color(0xFF6B7280),
        line: const Color(0xFFE5E7EB),
        blue: const Color(0xFF2563EB),
        green: const Color(0xFF16A34A),
        amber: const Color(0xFFF59E0B),
        sheetA: _o(Colors.white, 0.86),
        sheetB: _o(Colors.white, 0.74),
        sheetC: _o(Colors.white, 0.66),
        blockBg: _o(Colors.white, 0.70),
        barrier: _o(Colors.black, 0.30),
        overlayGradient: [
          Colors.white.withOpacity(0.78),
          Colors.white.withOpacity(0.74),
          Colors.white.withOpacity(0.70),
        ],
        glowBlue: const Color(0xFF2563EB).withOpacity(0.16),
        glowCyan: const Color(0xFF22D3EE).withOpacity(0.10),
        hairline: const Color(0xFFE5E7EB),
        softHighlight: Colors.white.withOpacity(0.70),
      );
    }

    // ✅ Dark (premium dark-blue glass)
    final onSurface = cs.onSurface;
    const base = Color(0xFF050A14); // deep navy
    const surfaceA = Color(0xFF071226); // glass base
    const surfaceB = Color(0xFF0A1A36); // richer blue
    const surfaceC = Color(0xFF071024); // darker

    final primary = cs.primary; // your theme primary
    final blue = _o(primary, 0.92);
    final cyan = const Color(0xFF22D3EE);

    return _NTokens(
      isDark: true,
      bgFallback: base,
      title: _o(onSurface, 0.96),
      text: _o(onSurface, 0.82),
      sub: _o(onSurface, 0.62),
      line: Colors.white.withOpacity(0.12),
      blue: blue,
      green: const Color(0xFF22C55E),
      amber: const Color(0xFFFBBF24),
      sheetA: _o(surfaceA, 0.78),
      sheetB: _o(surfaceB, 0.62),
      sheetC: _o(surfaceC, 0.55),
      blockBg: _o(const Color(0xFF0B1630), 0.46),
      barrier: _o(Colors.black, 0.56),
      overlayGradient: [
        const Color(0xFF030612).withOpacity(0.25),
        const Color(0xFF050A14).withOpacity(0.62),
        const Color(0xFF050A14).withOpacity(0.78),
      ],
      glowBlue: blue.withOpacity(0.18),
      glowCyan: cyan.withOpacity(0.12),
      hairline: Colors.white.withOpacity(0.08),
      softHighlight: Colors.white.withOpacity(0.06),
    );
  }
}

/// -------------------------
/// View All Page (your push target)
/// -------------------------
class NotificationDetailsPage extends StatefulWidget {
  const NotificationDetailsPage({
    super.key,
    required this.items,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
    this.title = 'Notifications',
  });

  final List<NotificationEntry> items;
  final String backgroundAsset;
  final String title;

  @override
  State<NotificationDetailsPage> createState() =>
      _NotificationDetailsPageState();
}

enum _NotifFilter { all, unread, read }

class _NotificationDetailsPageState extends State<NotificationDetailsPage> {
  _NotifFilter _filter = _NotifFilter.all;
  late List<NotificationEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  int get _unreadCount => _items.where((e) => e.isUnread).length;
  int get _readCount => _items.length - _unreadCount;

  List<NotificationEntry> get _filtered {
    return _items.where((e) {
      return switch (_filter) {
        _NotifFilter.all => true,
        _NotifFilter.unread => e.isUnread,
        _NotifFilter.read => !e.isUnread,
      };
    }).toList();
  }

  void _markAllRead() {
    setState(() {
      _items = _items.map((e) => e.copyWith(isUnread: false)).toList();
    });
  }

  Future<void> _openPopup(NotificationEntry entry) async {
    final realIndex = _items.indexOf(entry);
    if (realIndex < 0) return;

    final tok = _NTokens.of(context);

    final updated = await showModalBottomSheet<NotificationEntry?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: tok.barrier,
      builder: (_) => _NotificationDetailPopup(entry: entry),
    );

    if (updated != null) {
      setState(() => _items[realIndex] = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);
    final list = _filtered;

    return Scaffold(
      backgroundColor: tok.bgFallback,
      body: Stack(
        children: [
          // background image
          Positioned.fill(
            child: Image.asset(widget.backgroundAsset, fit: BoxFit.cover),
          ),

          // ✅ premium glow (dark only)
          if (tok.isDark) ...[const Positioned.fill(child: _GlowLayer())],

          // overlay for readability (adaptive)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: tok.overlayGradient,
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          children: [
                            _RoundIconButton(
                              icon: LucideIcons.arrowLeft,
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      color: tok.title,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _unreadCount > 0
                                        ? '$_unreadCount unread'
                                        : 'All caught up',
                                    style: TextStyle(
                                      color: tok.sub,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _RoundIconButton(
                              icon: LucideIcons.checkCheck,
                              onTap: _unreadCount == 0 ? null : _markAllRead,
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 220.ms)
                      .slideY(
                        begin: -0.05,
                        end: 0,
                        duration: 520.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  // Segmented filter (acts like TabBar)
                  Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: _GlassBlock(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SegmentButton(
                                  label: 'All',
                                  count: _items.length,
                                  selected: _filter == _NotifFilter.all,
                                  onTap: () => setState(
                                    () => _filter = _NotifFilter.all,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _SegmentButton(
                                  label: 'Unread',
                                  count: _unreadCount,
                                  selected: _filter == _NotifFilter.unread,
                                  onTap: () => setState(
                                    () => _filter = _NotifFilter.unread,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _SegmentButton(
                                  label: 'Read',
                                  count: _readCount,
                                  selected: _filter == _NotifFilter.read,
                                  onTap: () => setState(
                                    () => _filter = _NotifFilter.read,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 220.ms)
                      .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 520.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  // List sheet
                  Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: _GlassSheet(
                            child: list.isEmpty
                                ? const _EmptyState(
                                        title: 'No notifications',
                                        subtitle: 'Try switching the filter.',
                                      )
                                      .animate()
                                      .fadeIn(duration: 220.ms)
                                      .scale(
                                        begin: const Offset(0.98, 0.98),
                                        end: const Offset(1, 1),
                                      )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      16,
                                    ),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final e = list[i];
                                      return _NotificationTile(
                                            entry: e,
                                            onTap: () => _openPopup(e),
                                          )
                                          .animate()
                                          .fadeIn(
                                            delay: (28 * i).ms,
                                            duration: 200.ms,
                                          )
                                          .slideY(
                                            begin: 0.05,
                                            end: 0,
                                            delay: (28 * i).ms,
                                            duration: 520.ms,
                                            curve: Curves.easeOutCubic,
                                          );
                                    },
                                  ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 240.ms)
                      .slideY(
                        begin: 0.07,
                        end: 0,
                        duration: 560.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------------
/// POPUP (premium glass + full content) - ADAPTIVE
/// -------------------------
class _NotificationDetailPopup extends StatefulWidget {
  const _NotificationDetailPopup({required this.entry});
  final NotificationEntry entry;

  @override
  State<_NotificationDetailPopup> createState() =>
      _NotificationDetailPopupState();
}

class _NotificationDetailPopupState extends State<_NotificationDetailPopup> {
  late NotificationEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  void _close([NotificationEntry? updated]) {
    Navigator.of(context).pop<NotificationEntry?>(updated);
  }

  void _toggleReadAndClose() {
    final updated = _entry.copyWith(isUnread: !_entry.isUnread);
    _close(updated);
  }

  Future<void> _copyBody() async {
    await Clipboard.setData(ClipboardData(text: _entry.body));
    if (!mounted) return;

    final tok = _NTokens.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: tok.isDark
            ? const Color(0xFF0B1630)
            : const Color(0xFF111827),
        duration: 1200.ms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final media = MediaQuery.of(context);
    final height = (media.size.height * 0.82).clamp(
      520.0,
      media.size.height - 40,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: 14 + media.viewInsets.bottom,
          top: 14,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: height,
            child:
                _GlassSheet(
                      child: Stack(
                        children: [
                          // ✅ extra inner glow for popup (dark only)
                          if (tok.isDark)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: const Alignment(0.9, -0.7),
                                      radius: 1.2,
                                      colors: [
                                        tok.glowCyan.withOpacity(0.16),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Column(
                                children: [
                                  // drag handle
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 6,
                                    ),
                                    child: Container(
                                      width: 44,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: tok.line.withOpacity(
                                          tok.isDark ? 0.40 : 0.90,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // header row
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      6,
                                      12,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Notification',
                                            style: TextStyle(
                                              color: tok.title,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16.5,
                                            ),
                                          ),
                                        ),
                                        _MiniIconButton(
                                          icon: LucideIcons.x,
                                          onTap: () => _close(),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // body
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          Text(
                                                _entry.title,
                                                style: TextStyle(
                                                  color: tok.title,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 20.0,
                                                  height: 1.22,
                                                ),
                                              )
                                              .animate()
                                              .fadeIn(duration: 200.ms)
                                              .slideY(
                                                begin: 0.05,
                                                end: 0,
                                                duration: 520.ms,
                                                curve: Curves.easeOutCubic,
                                              ),

                                          const SizedBox(height: 12),

                                          // Meta
                                          _GlassBlock(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      12,
                                                      12,
                                                      12,
                                                      12,
                                                    ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const _MetaIcon(
                                                          icon: Icons
                                                              .person_rounded,
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _entry.sender,
                                                            style: TextStyle(
                                                              color: tok.title,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize: 13.2,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        _StatusPill(
                                                          isUnread:
                                                              _entry.isUnread,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      children: [
                                                        const _MetaIcon(
                                                          icon: Icons
                                                              .schedule_rounded,
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _entry.timeText,
                                                            style: TextStyle(
                                                              color: tok.sub,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 12.8,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        _MiniGhostButton(
                                                          icon: Icons
                                                              .copy_rounded,
                                                          label: 'Copy',
                                                          onTap: _copyBody,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 70.ms,
                                                duration: 200.ms,
                                              )
                                              .slideY(
                                                begin: 0.05,
                                                end: 0,
                                                duration: 520.ms,
                                                curve: Curves.easeOutCubic,
                                              ),

                                          const SizedBox(height: 14),

                                          Text(
                                            'Details',
                                            style: TextStyle(
                                              color: tok.title,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Full content
                                          _GlassBlock(
                                                child: SelectableText(
                                                  _entry.body,
                                                  style: TextStyle(
                                                    color: tok.text,
                                                    fontSize: 14.6,
                                                    height: 1.62,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 110.ms,
                                                duration: 220.ms,
                                              )
                                              .slideY(
                                                begin: 0.05,
                                                end: 0,
                                                duration: 520.ms,
                                                curve: Curves.easeOutCubic,
                                              ),

                                          const SizedBox(height: 16),

                                          // Action
                                          SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed:
                                                      _toggleReadAndClose,
                                                  icon: Icon(
                                                    _entry.isUnread
                                                        ? LucideIcons.checkCheck
                                                        : LucideIcons.undo2,
                                                  ),
                                                  label: Text(
                                                    _entry.isUnread
                                                        ? 'Mark as Read'
                                                        : 'Mark as Unread',
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: tok.blue
                                                        .withOpacity(
                                                          tok.isDark
                                                              ? 0.18
                                                              : 0.12,
                                                        ),
                                                    foregroundColor: tok.blue,
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 150.ms,
                                                duration: 220.ms,
                                              )
                                              .slideY(
                                                begin: 0.06,
                                                end: 0,
                                                duration: 520.ms,
                                                curve: Curves.easeOutCubic,
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 160.ms)
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 420.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ),
      ),
    );
  }
}

/// -------------------------
/// Premium Glow Layer (dark mode only)
/// -------------------------
class _GlowLayer extends StatelessWidget {
  const _GlowLayer();

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);
    if (!tok.isDark) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -140,
            top: -120,
            child: _GlowBlob(size: 340, color: tok.glowBlue.withOpacity(0.20)),
          ),
          Positioned(
            right: -160,
            top: 120,
            child: _GlowBlob(size: 380, color: tok.glowCyan.withOpacity(0.18)),
          ),
          Positioned(
            left: 40,
            bottom: -160,
            child: _GlowBlob(size: 420, color: tok.glowBlue.withOpacity(0.16)),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, Colors.transparent],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// -------------------------
/// UI primitives (premium glass)
/// -------------------------
class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tok.isDark ? 22 : 18,
          sigmaY: tok.isDark ? 22 : 18,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.85),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tok.sheetA, tok.sheetB, tok.sheetC],
            ),
            boxShadow: [
              BoxShadow(
                color: (tok.isDark ? Colors.black : const Color(0xFF111827))
                    .withOpacity(tok.isDark ? 0.55 : 0.10),
                blurRadius: tok.isDark ? 28 : 22,
                offset: const Offset(0, 14),
              ),
              if (tok.isDark)
                BoxShadow(
                  color: tok.blue.withOpacity(0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Stack(
            children: [
              if (tok.isDark)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassBlock extends StatelessWidget {
  const _GlassBlock({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tok.blockBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.90),
        ),
        boxShadow: [
          if (tok.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    // ✅ Text color in DarkMode = #FFFFFF (clear & readable)
    const white = Color(0xFFFFFFFF);
    final labelFg = tok.isDark ? white : (selected ? tok.blue : tok.sub);
    final countFg = tok.isDark ? white : (selected ? tok.blue : tok.sub);

    // small contrast bump for dark when using white text
    final bg = selected
        ? tok.blue.withOpacity(tok.isDark ? 0.28 : 0.12)
        : (tok.isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.white.withOpacity(0.55));

    final bd = selected
        ? tok.blue.withOpacity(tok.isDark ? 0.50 : 0.30)
        : (tok.isDark ? tok.hairline : tok.line.withOpacity(0.90));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelFg,
                fontWeight: FontWeight.w900,
                fontSize: 12.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? tok.blue.withOpacity(tok.isDark ? 0.22 : 0.12)
                    : (tok.isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.65)),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? tok.blue.withOpacity(tok.isDark ? 0.44 : 0.24)
                      : (tok.isDark
                            ? tok.hairline
                            : tok.line.withOpacity(0.90)),
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: countFg,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.entry, required this.onTap});
  final NotificationEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final bg = entry.isUnread
        ? tok.blue.withOpacity(tok.isDark ? 0.16 : 0.06)
        : (tok.isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.white.withOpacity(0.55));

    final bd = entry.isUnread
        ? tok.blue.withOpacity(tok.isDark ? 0.34 : 0.22)
        : (tok.isDark ? tok.hairline : tok.line.withOpacity(0.90));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: bd),
            boxShadow: [
              if (tok.isDark && entry.isUnread)
                BoxShadow(
                  color: tok.blue.withOpacity(0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleBadge(
                icon: entry.isUnread ? LucideIcons.bellRing : LucideIcons.bell,
                dot: entry.isUnread,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.sender,
                            style: TextStyle(
                              color: tok.title,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.timeText,
                          style: TextStyle(
                            color: tok.sub,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: tok.title,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.body,
                      style: TextStyle(
                        color: tok.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.8,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, color: tok.sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);
    final enabled = onTap != null;

    final bg = tok.isDark
        ? Colors.white.withOpacity(enabled ? 0.06 : 0.04)
        : Colors.white.withOpacity(enabled ? 0.70 : 0.50);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.95),
            ),
            boxShadow: [
              if (tok.isDark && enabled)
                BoxShadow(
                  color: tok.blue.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Icon(icon, color: enabled ? tok.title : tok.sub, size: 20),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final bg = tok.isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.70);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.95),
            ),
          ),
          child: Icon(icon, color: tok.title, size: 20),
        ),
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.icon, this.dot = false});
  final IconData icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final bg = tok.isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.72);

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(
              color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.95),
            ),
          ),
          child: Icon(icon, color: tok.blue, size: 20),
        ),
        if (dot)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: tok.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: tok.isDark ? const Color(0xFF0B1630) : Colors.white,
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final bg = tok.isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.72);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.95),
        ),
      ),
      child: Icon(icon, color: tok.sub, size: 18),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isUnread});
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final fg = isUnread ? tok.amber : tok.green;
    final bg = fg.withOpacity(tok.isDark ? 0.18 : 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(tok.isDark ? 0.34 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUnread ? LucideIcons.mailOpen : LucideIcons.checkCheck,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            isUnread ? 'Unread' : 'Read',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 12.2,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGhostButton extends StatelessWidget {
  const _MiniGhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    final bg = tok.isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.72);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tok.isDark ? tok.hairline : tok.line.withOpacity(0.95),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tok.blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: tok.blue,
                fontWeight: FontWeight.w900,
                fontSize: 12.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tok = _NTokens.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.bellOff, color: tok.sub, size: 44),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: tok.title,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tok.sub,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
