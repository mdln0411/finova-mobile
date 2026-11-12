import 'package:flutter/material.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/rupiah.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/application/chart_of_accounts_controller.dart';
import '../../chart_of_accounts/domain/chart_of_accounts_repository.dart';
import '../../company/domain/company.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../../transactions/domain/transactions_repository.dart';
import '../application/receivables_controller.dart';
import '../../transactions/domain/bill.dart';
import '../domain/receivable.dart';
import '../domain/receivable_status.dart';
import '../domain/receivables_repository.dart';
import 'receivable_detail_page.dart';
import 'receivable_form_page.dart';

class ReceivablesPage extends StatefulWidget {
  const ReceivablesPage({
    super.key,
    required this.company,
    required this.userId,
    required this.repository,
    required this.transactionsRepository,
    required this.chartRepository,
  });

  final CompanyContext company;
  final String? userId;
  final ReceivablesRepository repository;
  final TransactionsRepository transactionsRepository;
  final ChartOfAccountsRepository chartRepository;

  @override
  State<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends State<ReceivablesPage> {
  late final _controller = ReceivablesController(
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

  BillSettlement _settlement(Receivable receivable) =>
      receivable.settlement(_controller.payments);

  Future<void> _openForm([Receivable? existing]) async {
    _controller.clearMessages();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceivableFormPage(
          controller: _controller,
          bookkeepingStartDate: widget.company.company.bookkeepingStartDate,
          revenueAccounts: _accounts.accounts
              .where(
                (account) => isCategoryAccount(account, TransactionType.income),
              )
              .toList(),
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _openDetail(Receivable receivable) async {
    _controller.clearMessages();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReceivableDetailPage(
          receivable: receivable,
          controller: _controller,
          transactionsRepository: widget.transactionsRepository,
          company: widget.company.company,
          accounts: _accounts.accounts,
        ),
      ),
    );
  }

  Future<void> _delete(Receivable receivable) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus piutang?'),
        content: Text('${receivable.number} · ${receivable.customerName}'),
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
    if (confirmed == true) await _controller.delete(receivable);
  }

  Widget _section(String title, List<Receivable> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const FinovaCard(child: Text('Tidak ada piutang.'))
      else
        for (final receivable in items) ...[
          _receivableCard(receivable),
          const SizedBox(height: 10),
        ],
    ],
  );

  Widget _receivableCard(Receivable receivable) {
    final settlement = _settlement(receivable);
    final canEdit = receivable.canModify(widget.userId);
    return FinovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openDetail(receivable),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        receivable.customerName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRupiah(receivable.amount),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Nomor ${receivable.number}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatusChip(label: receivable.statusLabel(settlement)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Sisa tagihan: ${formatRupiah(settlement.remaining)}'),
                Text('Jatuh tempo: ${formatShortDate(receivable.dueDate)}'),
              ],
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _controller.busy
                      ? null
                      : () => _openForm(receivable),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: _controller.busy
                      ? null
                      : () => _delete(receivable),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _accounts]),
    builder: (context, _) {
      final today = dateOnly(DateTime.now());
      final soon = today.add(const Duration(days: 7));
      final approvedOutstanding = _controller.receivables.where((receivable) {
        return receivable.isApproved && !_settlement(receivable).isPaid;
      }).toList();
      final dueSoon = approvedOutstanding.where((receivable) {
        final due = dateOnly(receivable.dueDate);
        return !due.isBefore(today) && !due.isAfter(soon);
      }).toList();
      final overdue = approvedOutstanding
          .where((receivable) => dateOnly(receivable.dueDate).isBefore(today))
          .toList();
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Piutang',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pantau tagihan customer dan catat pembayaran setelah piutang disetujui.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed:
                _controller.busy ||
                    _accounts.loading ||
                    _accounts.loadError != null
                ? null
                : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah piutang'),
          ),
          if (_accounts.loadError != null) ...[
            const SizedBox(height: 12),
            AuthMessage(message: _accounts.loadError!),
          ],
          const SizedBox(height: 22),
          if (_controller.actionError != null)
            AuthMessage(message: _controller.actionError!),
          if (_controller.notice != null)
            AuthMessage(message: _controller.notice!, isError: false),
          if (_controller.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_controller.loadError != null) ...[
            AuthMessage(message: _controller.loadError!),
            OutlinedButton.icon(
              onPressed: _controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ] else ...[
            _section('Jatuh tempo ≤ 7 hari', dueSoon),
            const SizedBox(height: 16),
            _section('Terlambat', overdue),
            const SizedBox(height: 16),
            Text(
              'Semua piutang',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_controller.receivables.isEmpty)
              const FinovaCard(child: Text('Belum ada piutang.'))
            else
              for (final receivable in _controller.receivables) ...[
                _receivableCard(receivable),
                const SizedBox(height: 10),
              ],
          ],
        ],
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
  );
}
