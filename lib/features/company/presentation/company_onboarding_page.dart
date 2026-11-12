import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../application/company_controller.dart';

class CompanyOnboardingPage extends StatelessWidget {
  const CompanyOnboardingPage({super.key, required this.controller});
  final CompanyController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final loading = controller.phase == CompanyPhase.loading;
      final error = controller.phase == CompanyPhase.error;
      return AuthLayout(
        title: loading
            ? 'Menyiapkan perusahaan.'
            : error
            ? 'Periksa koneksi perusahaan.'
            : 'Ruang untuk bisnis Anda.',
        subtitle: loading
            ? 'Memverifikasi perusahaan dan keanggotaan Anda melalui server.'
            : error
            ? 'Akses Dashboard menunggu membership yang valid.'
            : 'Profil Anda sudah siap. Buat perusahaan atau bergabung melalui undangan Manager.',
        footer: TextButton.icon(
          onPressed: controller.auth.busy || controller.busy
              ? null
              : controller.auth.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar ke Login'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (controller.message != null)
                AuthMessage(message: controller.message!),
              if (error)
                FilledButton(
                  onPressed: controller.busy ? null : controller.retry,
                  child: const Text('Coba lagi'),
                )
              else ...[
                _Choice(
                  icon: Icons.add_business_rounded,
                  title: 'Buat perusahaan baru',
                  description:
                      'Mulai pembukuan dan kelola perusahaan sebagai Manager.',
                  onTap: () => context.go('/company/create'),
                ),
                const SizedBox(height: 16),
                _Choice(
                  icon: Icons.group_add_outlined,
                  title: 'Gabung perusahaan',
                  description:
                      'Lihat undangan Manager untuk bergabung sebagai Finance.',
                  onTap: () => context.go('/company/join'),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: controller.busy ? null : controller.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Periksa keanggotaan'),
                ),
                const Text(
                  'Satu akun terhubung ke satu perusahaan. Peran mengikuti membership yang sah.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FinovaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 32),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: AppColors.muted, height: 1.6),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(title),
        ),
      ],
    ),
  );
}
