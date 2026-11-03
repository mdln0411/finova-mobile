import 'package:flutter/material.dart';

import '../../../app/routes/app_destinations.dart';
import '../../../core/widgets/feature_placeholder.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    const destination = AppDestination.transactions;
    return FeaturePlaceholder(
      title: destination.label,
      description: destination.description,
      icon: destination.icon,
    );
  }
}
