import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../company/domain/company.dart';
import '../application/chart_of_accounts_controller.dart';
import '../domain/chart_account.dart';
import '../domain/chart_of_accounts_repository.dart';

class ChartOfAccountsPage extends StatefulWidget {
  const ChartOfAccountsPage({
    super.key,
    required this.company,
    required this.repository,
  });
  final CompanyContext company;
  final ChartOfAccountsRepository repository;
  @override
  State<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends State<ChartOfAccountsPage> {
  late final _controller = ChartOfAccountsController(
    widget.repository,
    companyId: widget.company.company.id,
    canInitialize: widget.company.role == CompanyRole.manager,
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final controller = _controller;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Kategori Akun',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.company.company.name} · ${widget.company.role.label}',
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          const FinovaCard(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_tree_outlined, color: AppColors.primary),
                SizedBox(height: 12),
                Text(
                  'Fondasi pembukuan bisnis',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Pendapatan dan beban dipisahkan dari aset, liabilitas, dan ekuitas. '
                  'Pinjaman, modal, serta transfer bukan otomatis pendapatan atau beban.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: controller.filter == null,
                onSelected: (_) => controller.setFilter(null),
              ),
              for (final type in AccountType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: controller.filter == type,
                  onSelected: (_) => controller.setFilter(type),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (controller.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.loadError != null) ...[
            AuthMessage(message: controller.loadError!),
            OutlinedButton.icon(
              onPressed: controller.busy ? null : controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ] else ...[
            if (controller.actionError != null)
              AuthMessage(message: controller.actionError!),
            if (controller.notice != null)
              AuthMessage(message: controller.notice!, isError: false),
            if (controller.canInitialize) ...[
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : controller.initializeDefaults,
                icon: controller.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_rounded),
                label: Text(
                  controller.busy
                      ? 'Menyiapkan kategori…'
                      : 'Siapkan kategori default',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun yang sudah ada tidak diubah. Tombol ini juga dapat melengkapi akun default yang belum tersedia.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (controller.accounts.isEmpty)
              FinovaCard(
                child: Text(
                  controller.canInitialize
                      ? 'Belum ada kategori akun. Siapkan daftar default untuk perusahaan Anda.'
                      : 'Belum ada kategori akun. Minta Manager menyiapkan daftar default.',
                ),
              )
            else if (controller.visibleAccounts.isEmpty)
              const FinovaCard(child: Text('Belum ada akun pada kelompok ini.'))
            else ...[
              Text(
                '${controller.visibleAccounts.length} akun · Saldo normal debit/kredit',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final account in controller.visibleAccounts) ...[
                _AccountCard(account: account),
                const SizedBox(height: 12),
              ],
            ],
          ],
          const SizedBox(height: 20),
          const Text(
            'Kelompok akun tidak dapat dipakai untuk posting. '
            'Pencatatan transaksi dan jurnal berpasangan belum tersedia.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
          ),
        ],
      );
    },
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});
  final ChartAccount account;
  @override
  Widget build(BuildContext context) => FinovaCard(
    color: account.isPosting ? Colors.white : AppColors.surface,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account.code,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          account.name,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(account.type.label),
            Text(
              'Normal ${account.normalBalance.label}',
              style: const TextStyle(color: AppColors.muted),
            ),
            Text(
              account.isPosting ? 'Akun posting' : 'Kelompok',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (!account.isActive)
              const Text('Nonaktif', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ],
    ),
  );
}
