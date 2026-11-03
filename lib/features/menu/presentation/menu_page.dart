import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_destinations.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Ruang kerja Anda',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Semua kebutuhan keuangan, dalam satu tempat.',
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 24),
      FinovaCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final destination in AppDestination.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                leading: Icon(destination.icon, color: AppColors.primary),
                title: Text(
                  destination.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  destination.description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
                onTap: () => context.push(destination.path),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Center(
        child: Text(
          'FINOVA  /  Keuangan lebih tertata',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ],
  );
}
