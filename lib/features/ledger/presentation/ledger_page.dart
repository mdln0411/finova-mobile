import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/rupiah.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/application/chart_of_accounts_controller.dart';
import '../../chart_of_accounts/domain/chart_of_accounts_repository.dart';
import '../../company/domain/company.dart';
import '../application/ledger_controller.dart';
import '../domain/ledger_calculator.dart';
import '../domain/ledger_repository.dart';

/// Buku besar per akun, dihitung dari transaksi yang sudah disetujui.
class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    required this.company,
    required this.repository,
    required this.chartRepository,
  });
  final CompanyContext company;
  final LedgerRepository repository;
  final ChartOfAccountsRepository chartRepository;
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
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

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final start = widget.company.company.bookkeepingStartDate;
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(now.year, now.month, now.day);
    final current = _ledger.from != null && _ledger.to != null
        ? DateTimeRange(
            start: DateTime(
              _ledger.from!.year,
              _ledger.from!.month,
              _ledger.from!.day,
            ),
            end: DateTime(_ledger.to!.year, _ledger.to!.month, _ledger.to!.day),
          )
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first.isAfter(last) ? last : first,
      lastDate: last,
      initialDateRange: current,
      helpText: 'Pilih rentang tanggal',
    );
    if (picked != null) _ledger.setRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_ledger, _accounts]),
    builder: (context, _) {
      final postingAccounts =
          _accounts.accounts.where((a) => a.isPosting).toList()
            ..sort((a, b) => a.code.compareTo(b.code));
      final ledger = _ledger.ledgerFor(postingAccounts);
      final hasRange = _ledger.from != null && _ledger.to != null;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Buku Besar',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mutasi per akun dari transaksi yang sudah disetujui Manager.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (_accounts.loadError != null) ...[
            AuthMessage(message: _accounts.loadError!),
            OutlinedButton.icon(
              onPressed: _accounts.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang akun'),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            key: const ValueKey('ledger-account'),
            initialValue: ledger?.account.code,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Akun'),
            items: [
              for (final account in postingAccounts)
                DropdownMenuItem(
                  value: account.code,
                  child: Text(
                    '${account.code} · ${account.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _accounts.loading ? null : _ledger.selectAccount,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  hasRange
                      ? '${formatShortDate(_ledger.from!)} – ${formatShortDate(_ledger.to!)}'
                      : 'Semua tanggal',
                ),
              ),
              if (hasRange)
                TextButton(
                  onPressed: () => _ledger.setRange(null, null),
                  child: const Text('Hapus filter'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_ledger.loading || _accounts.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_ledger.loadError != null) ...[
            AuthMessage(message: _ledger.loadError!),
            OutlinedButton.icon(
              onPressed: _ledger.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ] else if (postingAccounts.isEmpty)
            const FinovaCard(
              child: Text(
                'Kategori akun belum tersedia. Minta Manager menyiapkannya.',
              ),
            )
          else if (ledger == null)
            const FinovaCard(
              child: Text('Pilih akun untuk melihat buku besar.'),
            )
          else ...[
            _LedgerSummary(ledger: ledger, showOpening: _ledger.from != null),
            const SizedBox(height: 16),
            if (ledger.entries.isEmpty)
              const FinovaCard(
                child: Text('Belum ada mutasi pada akun dan periode ini.'),
              )
            else
              for (final entry in ledger.entries) ...[
                _LedgerEntryTile(entry: entry),
                const SizedBox(height: 12),
              ],
          ],
        ],
      );
    },
  );
}

class _LedgerSummary extends StatelessWidget {
  const _LedgerSummary({required this.ledger, required this.showOpening});
  final AccountLedger ledger;
  final bool showOpening;

  @override
  Widget build(BuildContext context) => FinovaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${ledger.account.code} · ${ledger.account.name}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          'Saldo normal ${ledger.account.normalBalance.label}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (showOpening)
          _AmountRow(label: 'Saldo awal', amount: ledger.openingBalance),
        _AmountRow(label: 'Total debit', amount: ledger.totalDebit),
        _AmountRow(label: 'Total kredit', amount: ledger.totalCredit),
        const Divider(height: 20),
        _AmountRow(
          label: 'Saldo akhir',
          amount: ledger.closingBalance,
          emphasize: true,
        ),
      ],
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });
  final String label;
  final int amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasize ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(label, style: style),
          Text(formatRupiah(amount), style: style),
        ],
      ),
    );
  }
}

class _LedgerEntryTile extends StatelessWidget {
  const _LedgerEntryTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.debit > 0;
    return FinovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatShortDate(entry.date),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            entry.description,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${isDebit ? 'Debit' : 'Kredit'} '
                '${formatRupiah(isDebit ? entry.debit : entry.credit)}',
                style: TextStyle(
                  color: isDebit ? AppColors.primary : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Saldo ${formatRupiah(entry.balance)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
