import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';
import '../../company/domain/company.dart';
import '../../company/presentation/company_form_page.dart';
import 'widgets/activity_chart.dart';
import 'widgets/summary_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.company, this.userName});
  final CompanyContext company;
  final String? userName;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('dashboard'),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(company: company),
        const SizedBox(height: 30),
        Text(
          'Halo, ${userName ?? 'Pengguna Finova'} 👋',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.6),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mari lihat kabar keuangan bisnis Anda.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Pembukuan IDR',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${company.role.label} · Anggota aktif',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _BalanceCard(),
        const SizedBox(height: 24),
        const SectionHeading(title: 'Ringkasan keuangan'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620
                ? 4
                : (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.4
                      ? 1
                      : 2);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: SummaryCard(
                    label: 'Pemasukan',
                    amount: null,
                    caption: 'Data belum tersedia',
                    icon: Icons.south_west_rounded,
                    accent: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryCard(
                    label: 'Pengeluaran',
                    amount: null,
                    caption: 'Data belum tersedia',
                    icon: Icons.north_east_rounded,
                    accent: AppColors.pink,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryCard(
                    label: 'Piutang',
                    amount: null,
                    caption: 'Data belum tersedia',
                    icon: Icons.call_received_rounded,
                    accent: const Color(0xFF926A00),
                    onTap: () => context.push('/receivables'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryCard(
                    label: 'Utang',
                    amount: null,
                    caption: 'Data belum tersedia',
                    icon: Icons.call_made_rounded,
                    accent: AppColors.muted,
                    onTap: () => context.push('/payables'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        SectionHeading(
          title: 'Aktivitas keuangan',
          action: 'Laporan',
          onTap: () => context.push('/reports'),
        ),
        const SizedBox(height: 8),
        const ActivityChart(activity: []),
        const SizedBox(height: 24),
        const SectionHeading(title: 'Akses cepat'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
              label: 'Kas & Bank',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => context.push('/accounts'),
            ),
            _QuickAction(
              label: 'Piutang',
              icon: Icons.call_received_rounded,
              onTap: () => context.push('/receivables'),
            ),
            _QuickAction(
              label: 'Utang',
              icon: Icons.call_made_rounded,
              onTap: () => context.push('/payables'),
            ),
            _QuickAction(
              label: 'Semua menu',
              icon: Icons.grid_view_rounded,
              onTap: () => context.go('/menu'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeading(
          title: 'Transaksi terbaru',
          action: 'Lihat semua',
          onTap: () => context.go('/transactions'),
        ),
        const SizedBox(height: 8),
        const FinovaCard(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Belum ada transaksi. Modul pencatatan belum tersedia.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ringkasan keuangan belum terhubung ke data transaksi. '
          'Tanda — berarti data belum tersedia, bukan saldo nol.',
          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.company});
  final CompanyContext company;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CompanyLogo(url: company.company.logoUrl, size: 38),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'finova',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            Text(
              company.company.name,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Pengaturan',
        style: IconButton.styleFrom(backgroundColor: AppColors.surface),
        onPressed: () => context.push('/settings'),
        icon: const Icon(Icons.tune_rounded, size: 21),
      ),
    ],
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .16),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Total saldo kas & bank',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '—',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Belum ada data saldo kas & bank',
          style: TextStyle(color: Colors.white, fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kelola hari ini, tumbuh esok hari.',
          style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 11),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
