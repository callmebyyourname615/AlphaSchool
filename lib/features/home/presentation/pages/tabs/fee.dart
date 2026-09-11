import 'package:flutter/material.dart';

import '../../../../../core/theme/app_icons.dart';
import '../common/feature_placeholder_page.dart';

class FeePage extends StatelessWidget {
  const FeePage({
    super.key,
    this.backgroundAsset = _kDefaultBg,
    this.showBack = true,
  });

  final String backgroundAsset;
  final bool showBack;

  static const String _kDefaultBg = 'assets/images/homepagewall/mainbg.jpeg';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'ຄ່າທຳນຽມ',
      subtitle: 'Coming soon',
      icon: LucideIcons.walletMinimal,
    );
  }
}
