import 'package:flutter/material.dart';

import '../../../app/routes/app_destinations.dart';
import '../../../core/widgets/feature_placeholder.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    const destination = AppDestination.reports;
    return FeaturePlaceholder(
      title: destination.label,
      description: destination.description,
      icon: destination.icon,
    );
  }
}
