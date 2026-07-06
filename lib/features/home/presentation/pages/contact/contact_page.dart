import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../shared/models/student_card_item.dart';
import 'branch_model.dart';
import 'branch_service.dart';

// Same palette as the (already DESIGN.md-aligned) Saving/Appointment pages —
// light surface, royal-blue accent, no gradients/glass/dark backgrounds.
const _kNavy = Color(0xFF082653);
const _kBlue = Color(0xFF0756D1);
const _kBlueSoft = Color(0xFFEAF1FF);
const _kBlueSoftBorder = Color(0xFFD6E4FF);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kFbBlue = Color(0xFF1877F2);
const _kBg = Color(0xFFF5F8FE);
const _kCardBg = Colors.white;
const _kBorder = Color(0xFFE3E9F2);
const _kMuted = Color(0xFF647594);
const _kMutedSoft = Color(0xFF8A98B0);

class ContactPage extends StatefulWidget {
  final StudentCardItem? selectedStudent;

  const ContactPage({super.key, this.selectedStudent});

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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContactHeader(onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 4, 16, 18 + bottomInset),
                child: _body(context),
              ),
            ),
          ],
        ),
      ),
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

class _ContactHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ContactHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
          const SizedBox(width: 12),
          const Text(
            'ຕິດຕໍ່ໂຮງຮຽນ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kNavy,
              letterSpacing: -.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final BranchInfo branch;

  const _Content({required this.branch});

  @override
  Widget build(BuildContext context) {
    // "Get in touch" — direct lines to the branch.
    final reachItems = <_ContactItem>[
      _ContactItem(
        'Phone #1',
        branch.phone,
        LucideIcons.whatsapp,
        iconColor: _kGreen,
      ),
      _ContactItem(
        'Phone #2',
        branch.contact,
        LucideIcons.whatsapp,
        iconColor: _kGreen,
      ),
      _ContactItem(
        'Branch Code',
        branch.code,
        LucideIcons.hashtag,
        iconColor: _kBlue,
      ),
      _ContactItem(
        'Governance Branch ID',
        branch.branchNo,
        LucideIcons.building,
        iconColor: _kBlue,
      ),
      _ContactItem(
        'Location',
        branch.address,
        LucideIcons.mapPin,
        iconColor: _kBlue,
        maxLines: 3,
      ),
    ];

    // "Find us online" — external links, kept in their recognizable brand
    // colors since that's meaningful here (identifies which service each
    // row opens), not decoration.
    final onlineItems = <_ContactItem>[
      _ContactItem(
        'Google Maps',
        branch.mapUrl,
        LucideIcons.mapPinned,
        iconColor: _kRed,
        isLink: true,
        maxLines: 2,
      ),
      _ContactItem(
        'Facebook',
        branch.facebookUrl,
        LucideIcons.facebook,
        iconColor: _kFbBlue,
        isLink: true,
        maxLines: 2,
      ),
      _ContactItem(
        'Website',
        branch.websiteUrl,
        LucideIcons.globe,
        iconColor: _kBlue,
        isLink: true,
        maxLines: 2,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(branch: branch)
            .animate()
            .fadeIn(duration: 180.ms)
            .slideY(
              begin: .05,
              end: 0,
              duration: 220.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 20),
        const _SectionLabel('Get in touch'),
        const SizedBox(height: 8),
        _ContactCard(items: reachItems)
            .animate()
            .fadeIn(delay: 60.ms, duration: 220.ms)
            .slideY(
              begin: .04,
              end: 0,
              duration: 240.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 18),
        const _SectionLabel('Find us online'),
        const SizedBox(height: 8),
        _ContactCard(items: onlineItems)
            .animate()
            .fadeIn(delay: 100.ms, duration: 220.ms)
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kMutedSoft,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final BranchInfo branch;

  const _HeaderCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final logoUrl = BranchService.resolveImageUrl(branch.profilePicPath);
    final subtitle = branch.code.isEmpty ? 'School branch' : branch.code;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _LogoAvatar(imageUrl: logoUrl),
          const SizedBox(height: 12),
          Text(
            branch.name.isEmpty ? '—' : branch.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _kNavy,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kMuted,
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
    const fallback = Center(
      child: Icon(LucideIcons.school, size: 32, color: _kBlue),
    );

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kBlueSoft,
        border: Border.all(color: _kBlueSoftBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? fallback
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
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
  final bool isLink;

  const _ContactItem(
    this.label,
    this.value,
    this.icon, {
    this.maxLines = 1,
    this.isLink = false,
    required this.iconColor,
  });
}

class _ContactCard extends StatelessWidget {
  final List<_ContactItem> items;

  const _ContactCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _ContactRow(
              item: items[i],
              onTap: () => items[i].isLink
                  ? _openLink(context, items[i].value)
                  : _copy(context, items[i].value),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, thickness: 1, color: _kBorder),
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

  static Future<void> _openLink(BuildContext context, String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return;
    final normalized = _normalizeLink(raw);
    final uri = Uri.tryParse(normalized);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this link')));
  }

  static String _normalizeLink(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('wa.me/') || raw.startsWith('api.whatsapp.com/')) {
      return 'https://$raw';
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isNotEmpty && digits.length >= 8 && !raw.contains('.')) {
      final clean = digits.replaceFirst(RegExp(r'^\+'), '');
      return 'https://wa.me/$clean';
    }
    return 'https://$raw';
  }
}

class _ContactRow extends StatelessWidget {
  final _ContactItem item;
  final VoidCallback onTap;

  const _ContactRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasValue = item.value.trim().isNotEmpty;

    return InkWell(
      onTap: hasValue ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: item.maxLines > 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.iconColor.withValues(alpha: .12),
              ),
              child: Center(
                child: Icon(item.icon, color: item.iconColor, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasValue ? item.value : '-',
                    maxLines: item.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: hasValue
                          ? (item.isLink ? _kBlue : _kNavy)
                          : _kMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              item.isLink ? LucideIcons.externalLink : LucideIcons.copy,
              size: 16,
              color: hasValue ? _kMutedSoft : _kBorder,
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
            LucideIcons.cloudOff,
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
            LucideIcons.school,
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
