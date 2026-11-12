import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/application/chart_of_accounts_controller.dart';
import '../../chart_of_accounts/domain/chart_of_accounts_repository.dart';
import '../../company/domain/company.dart';
import '../application/transactions_controller.dart';
import '../domain/finance_transaction.dart';
import '../domain/transactions_repository.dart';
import 'transaction_form_page.dart';
import 'widgets/transaction_tile.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    required this.company,
    required this.userId,
    required this.repository,
    required this.chartRepository,
  });
  final CompanyContext company;
  final String? userId;
  final TransactionsRepository repository;
  final ChartOfAccountsRepository chartRepository;
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final _controller = TransactionsController(
    widget.repository,
    companyId: widget.company.company.id,
    userId: widget.userId,
    role: widget.company.role,
  );
  late final _accounts = ChartOfAccountsController(
    widget.chartRepository,
    companyId: widget.company.company.id,
    canInitialize: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    _accounts.dispose();
    super.dispose();
  }

  String _accountName(String code) {
    final account = _accounts.accounts.where((a) => a.code == code).firstOrNull;
    return account == null ? code : '${account.code} · ${account.name}';
  }

  Future<void> _openForm([FinanceTransaction? existing]) {
    _controller.clearMessages();
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionFormPage(
          controller: _controller,
          accounts: _accounts.accounts,
          bookkeepingStartDate: widget.company.company.bookkeepingStartDate,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(FinanceTransaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text(tx.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) await _controller.delete(tx);
  }

  Widget? _ownerActions(FinanceTransaction tx) {
    if (!tx.canModify(widget.userId)) return null;
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _controller.busy || _accounts.loading
              ? null
              : () => _openForm(tx),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        TextButton.icon(
          onPressed: _controller.busy ? null : () => _confirmDelete(tx),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Hapus'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _accounts]),
    builder: (context, _) {
      final controller = _controller;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Transaksi',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pemasukan dan pengeluaran baru berstatus Menunggu sampai disetujui Manager.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                controller.busy ||
                    _accounts.loading ||
                    _accounts.loadError != null
                ? null
                : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah transaksi'),
          ),
          if (_accounts.loadError != null) ...[
            const SizedBox(height: 12),
            AuthMessage(message: _accounts.loadError!),
          ],
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
              for (final status in TransactionStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: controller.filter == status,
                  onSelected: (_) => controller.setFilter(status),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (controller.actionError != null)
            AuthMessage(message: controller.actionError!),
          if (controller.notice != null)
            AuthMessage(message: controller.notice!, isError: false),
          if (controller.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.loadError != null) ...[
            AuthMessage(message: controller.loadError!),
            OutlinedButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ] else if (controller.visibleTransactions.isEmpty)
            FinovaCard(
              child: Text(
                controller.transactions.isEmpty
                    ? 'Belum ada transaksi.'
                    : 'Tidak ada transaksi dengan status ini.',
              ),
            )
          else
            for (final tx in controller.visibleTransactions) ...[
              TransactionTile(
                transaction: tx,
                accountName: _accountName,
                footer: _ownerActions(tx),
              ),
              const SizedBox(height: 12),
            ],
        ],
      );
    },
  );
}
