import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/rupiah.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/application/chart_of_accounts_controller.dart';
import '../../chart_of_accounts/domain/chart_account.dart';
import '../../chart_of_accounts/domain/chart_of_accounts_repository.dart';
import '../../company/domain/company.dart';
import '../../ledger/application/ledger_controller.dart';
import '../../ledger/domain/ledger_calculator.dart';
import '../../ledger/domain/ledger_repository.dart';

/// Saldo akun Kas & Bank dari transaksi yang sudah disetujui.
class AccountsPage extends StatefulWidget {
  const AccountsPage({
    super.key,
    required this.company,
    required this.repository,
    required this.chartRepository,
  });
  final CompanyContext company;
  final LedgerRepository repository;
  final ChartOfAccountsRepository chartRepository;
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late final _ledger = LedgerController(
    widget.repository,
    companyId: widget.company.company.id,
  );
  late final _accounts = ChartOfAccountsController(
    widget.chartRepository,
    companyId: widget.company.company.id,
    canInitialize: false,
  );

  @override
  void dispose() {
    _ledger.dispose();
    _accounts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_ledger, _accounts]),
    builder: (context, _) {
      final cashAccounts = cashBankAccounts(_accounts.accounts);
      final balances = _ledger.balancesFor(cashAccounts);
      final total = balances.values.fold(0, (sum, value) => sum + value);
      final error = _accounts.loadError ?? _ledger.loadError;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Kas & Bank',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saldo dihitung dari transaksi yang sudah disetujui Manager.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (_ledger.loading || _accounts.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null) ...[
            AuthMessage(message: error),
            OutlinedButton.icon(
              onPressed: () {
                if (_accounts.loadError != null) _accounts.retry();
                if (_ledger.loadError != null) _ledger.retry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ] else if (cashAccounts.isEmpty)
            const FinovaCard(
              child: Text(
                'Akun Kas/Bank belum tersedia. Minta Manager menyiapkan kategori akun.',
              ),
            )
          else ...[
            FinovaCard(
              color: AppColors.yellow.withValues(alpha: 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Kas & Bank',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(total),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final account in cashAccounts) ...[
              _CashAccountTile(
                account: account,
                balance: balances[account.code] ?? 0,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      );
    },
  );
}

class _CashAccountTile extends StatelessWidget {
  const _CashAccountTile({required this.account, required this.balance});
  final ChartAccount account;
  final int balance;

  @override
  Widget build(BuildContext context) => FinovaCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFEFF6FF),
          foregroundColor: AppColors.primary,
          child: Icon(Icons.account_balance_wallet_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                account.isActive ? account.code : '${account.code} · Nonaktif',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                formatRupiah(balance),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: balance < 0 ? Colors.red.shade700 : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
