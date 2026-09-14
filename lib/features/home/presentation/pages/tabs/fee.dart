import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return FeaturePlaceholderPage(
      title: l10n.t('feeTab'),
      subtitle: l10n.t('comingSoon'),
      icon: LucideIcons.walletMinimal,
    );
  }
}
