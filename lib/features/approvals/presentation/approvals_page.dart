import 'package:flutter/material.dart';

import '../../../app/routes/app_destinations.dart';
import '../../../core/widgets/feature_placeholder.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});
  @override
  Widget build(BuildContext context) {
    const destination = AppDestination.approvals;
    return FeaturePlaceholder(
      title: destination.label,
      description: destination.description,
      icon: destination.icon,
    );
  }
}
