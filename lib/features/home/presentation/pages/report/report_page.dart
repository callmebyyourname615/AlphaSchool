import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_icons.dart';
import '../common/feature_placeholder_page.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FeaturePlaceholderPage(
      title: l10n.t('reports'),
      subtitle: l10n.t('comingSoon'),
      icon: LucideIcons.chartNoAxesColumnIncreasing,
    );
  }
}
