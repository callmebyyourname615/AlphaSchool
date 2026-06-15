import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton placeholder for the home page. Mirrors the rough layout
/// (top bar, hero card, two mini cards, menu grid) so the transition to
/// the loaded UI feels stable rather than a content jump.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  static const _kBg = Color(0xFF001E51);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final isSmallPhone = w < 360;
    final isTablet = w >= 600 && w < 1024;
    final hPad = isTablet ? 22.0 : 18.0;

    final base = Colors.white.withValues(alpha: 0.08);
    final highlight = Colors.white.withValues(alpha: 0.22);

    final crossAxisCount = isTablet ? 5 : 4;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF001E51), Color(0xFF002A6E)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              period: const Duration(milliseconds: 1400),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topbarRow(isSmallPhone),
                    const SizedBox(height: 14),
                    _heroCard(isSmallPhone),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _miniCard()),
                        const SizedBox(width: 12),
                        Expanded(child: _miniCard()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(),
                    const SizedBox(height: 14),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: isSmallPhone ? 14 : 18,
                          crossAxisSpacing: isSmallPhone ? 14 : 18,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: crossAxisCount * 2,
                        itemBuilder: (_, __) => _menuTile(isSmallPhone, isTablet),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({
    double? width,
    double height = 16,
    double radius = 10,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _topbarRow(bool isSmallPhone) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width: 130, height: 14),
              const SizedBox(height: 6),
              _box(width: 80, height: 11),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(bool isSmallPhone) {
    return Container(
      height: isSmallPhone ? 170 : 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }

  Widget _miniCard() {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _sectionTitle() {
    return Row(
      children: [
        _box(width: 140, height: 18, radius: 6),
      ],
    );
  }

  Widget _menuTile(bool isSmallPhone, bool isTablet) {
    final circle = isTablet ? 72.0 : (isSmallPhone ? 56.0 : 66.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: circle,
          height: circle,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 10),
        _box(width: 48, height: 10, radius: 4),
      ],
    );
  }
}
