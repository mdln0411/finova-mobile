import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import 'finova_card.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 32),
        FinovaCard(
          color: AppColors.surface,
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Ruang untuk langkah berikutnya',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Modul ini sedang disiapkan. Saat ini Anda dapat '
                'menjelajahi ringkasan keuangan dengan data contoh di Beranda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ke Beranda'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    ),
  );
}
