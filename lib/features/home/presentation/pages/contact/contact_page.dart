import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_page_template.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'branch_model.dart';
import 'branch_service.dart';

class ContactPage extends StatefulWidget {
  final StudentCardItem? selectedStudent;
  final String backgroundAsset;

  const ContactPage({
    super.key,
    this.selectedStudent,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  Future<BranchInfo?>? _future;

  @override
  void initState() {
    super.initState();
    final branchId = widget.selectedStudent?.branchId;
    if (branchId != null && branchId.isNotEmpty) {
      _future = BranchService().fetchBranch(branchId);
    }
  }

  Future<void> _reload() async {
    final branchId = widget.selectedStudent?.branchId;
    if (branchId == null || branchId.isEmpty) return;
    setState(() {
      _future = BranchService().fetchBranch(branchId);
    });
    await _future;
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AppPageTemplate(
            title: 'ຕິດຕໍ່ໂຮງຮຽນ',
            backgroundAsset: widget.backgroundAsset,
            animate: true,
            showBack: true,
            scrollable: true,
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            premiumDark: true,
            child: _body(context),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (_future == null) {
      return const _NoBranchState();
    }

    return FutureBuilder<BranchInfo?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _LoadingState();
        }
        if (snap.hasError) {
          return _ErrorState(message: snap.error.toString(), onRetry: _reload);
        }
        final branch = snap.data;
        if (branch == null) {
          return const _NoBranchState();
        }
        return _Content(branch: branch);
      },
    );
  }
}

class _Content extends StatelessWidget {
  final BranchInfo branch;

  const _Content({required this.branch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: .06)
        : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: .10)
        : Colors.black.withValues(alpha: .06);
    final shadow = Colors.black.withValues(alpha: isDark ? .45 : .10);

    final items = <_ContactItem>[
      _ContactItem(
        'Phone #1',
        branch.phone,
        FontAwesomeIcons.phone,
        iconColor: const Color(0xFF22C55E),
      ),
      _ContactItem(
        'Phone #2',
        branch.contact,
        FontAwesomeIcons.idCard,
        iconColor: const Color(0xFF3B82F6),
      ),
      _ContactItem(
        'Branch Code',
        branch.code,
        FontAwesomeIcons.hashtag,
        iconColor: const Color(0xFF6366F1),
      ),
      _ContactItem(
        'Governance Branch ID',
        branch.branchNo,
        FontAwesomeIcons.building,
        iconColor: const Color(0xFF0EA5E9),
      ),
      _ContactItem(
        'Location',
        branch.address,
        FontAwesomeIcons.locationDot,
        iconColor: const Color(0xFFF59E0B),
        maxLines: 3,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(branch: branch, shadow: shadow)
            .animate()
            .fadeIn(duration: 180.ms)
            .slideY(
              begin: .05,
              end: 0,
              duration: 220.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 14),
        _ContactCard(
              items: items,
              cardColor: cardColor,
              border: border,
              shadow: shadow,
            )
            .animate()
            .fadeIn(delay: 60.ms, duration: 220.ms)
            .slideY(
              begin: .04,
              end: 0,
              duration: 240.ms,
              curve: Curves.easeOut,
            ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final BranchInfo branch;
  final Color shadow;

  const _HeaderCard({required this.branch, required this.shadow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final logoUrl = BranchService.resolveImageUrl(branch.profilePicPath);

    const headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF071A33), Color(0xFF0B2B5B), Color(0xFF123B7A)],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: headerGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: Column(
        children: [
          _LogoAvatar(imageUrl: logoUrl),
          const SizedBox(height: 12),
          Text(
            branch.name.isEmpty ? '—' : branch.name,
            textAlign: TextAlign.center,
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Phone • Contact • Branch • Location',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: .85),
                  Colors.white.withValues(alpha: .35),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  final String? imageUrl;

  const _LogoAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Center(
      child: FaIcon(FontAwesomeIcons.school, size: 44, color: cs.primary),
    );

    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .10),
        border: Border.all(
          color: Colors.white.withValues(alpha: .22),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: .22),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: ClipOval(
          child: imageUrl == null
              ? fallback
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}

class _ContactItem {
  final String label;
  final String value;
  final IconData icon;
  final int maxLines;
  final Color iconColor;

  const _ContactItem(
    this.label,
    this.value,
    this.icon, {
    this.maxLines = 1,
    required this.iconColor,
  });
}

class _ContactCard extends StatelessWidget {
  final List<_ContactItem> items;
  final Color cardColor;
  final Color border;
  final Color shadow;

  const _ContactCard({
    required this.items,
    required this.cardColor,
    required this.border,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: .10)
        : Colors.black.withValues(alpha: .06);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _ContactRow(
              item: items[i],
              onCopy: () => _copy(context, items[i].value),
            ),
            if (i != items.length - 1)
              Divider(height: 1, thickness: 1, color: dividerColor),
          ],
        ],
      ),
    );
  }

  static Future<void> _copy(BuildContext context, String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: cleaned));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final _ContactItem item;
  final VoidCallback onCopy;

  const _ContactRow({required this.item, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;
    final labelColor = cs.onSurface.withValues(alpha: .62);
    final valueColor = cs.onSurface;
    final hasValue = item.value.trim().isNotEmpty;
    final bubbleBg = isDark
        ? Colors.white.withValues(alpha: .10)
        : const Color(0xFFF3F4F6);
    final bubbleBorder = isDark
        ? Colors.white.withValues(alpha: .12)
        : Colors.black.withValues(alpha: .06);

    return InkWell(
      onTap: hasValue ? onCopy : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: item.maxLines > 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bubbleBg,
                border: Border.all(color: bubbleBorder),
              ),
              child: Center(
                child: FaIcon(item.icon, color: item.iconColor, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: t.textTheme.labelLarge?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasValue ? item.value : '-',
                    maxLines: item.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodyLarge?.copyWith(
                      color: hasValue ? valueColor : labelColor,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FaIcon(
              FontAwesomeIcons.copy,
              size: 18,
              color: hasValue
                  ? (isDark
                        ? Colors.white.withValues(alpha: .70)
                        : Colors.black.withValues(alpha: .45))
                  : cs.onSurface.withValues(alpha: .25),
            ),
          ],
        ),
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: cs.onSurface.withValues(alpha: .55),
          ),
          const SizedBox(height: 10),
          Text(
            "Couldn't load school info",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: .60),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _NoBranchState extends StatelessWidget {
  const _NoBranchState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 48,
            color: cs.onSurface.withValues(alpha: .55),
          ),
          const SizedBox(height: 12),
          Text(
            'No school info available',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No branch is linked to the selected student.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: .60),
            ),
          ),
        ],
      ),
    );
  }
}
