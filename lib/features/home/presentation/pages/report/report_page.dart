import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../common/feature_placeholder_page.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: "Report",
      subtitle: "Coming soon",
      icon: LucideIcons.chartNoAxesColumnIncreasing,
    );
  }
}
