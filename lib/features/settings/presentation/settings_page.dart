import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../company/domain/company.dart';
import '../../company/presentation/company_form_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.auth, required this.company});
  final AuthController auth;
  final CompanyContext company;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Pengaturan',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Akun yang terhubung dengan Finova.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        FinovaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surface,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                auth.profile?.displayName ?? 'Pengguna Finova',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                auth.profile?.email ?? auth.user?.email ?? '',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              CompanyLogo(url: company.company.logoUrl),
              const SizedBox(height: 12),
              Text(
                '${company.company.name} · ${company.role.label}\n'
                'Mata uang IDR. Data keuangan belum tersedia.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        if (company.role == CompanyRole.manager) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/company/invitations'),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Undang tim Finance'),
          ),
        ],
        const SizedBox(height: 24),
        if (auth.actionMessage != null)
          AuthMessage(message: auth.actionMessage!),
        OutlinedButton.icon(
          onPressed: auth.busy ? null : auth.signOut,
          icon: auth.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Keluar dari akun'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
      ],
    ),
  );
}
