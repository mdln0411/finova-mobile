import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/finova_card.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/application/chart_of_accounts_controller.dart';
import '../../chart_of_accounts/domain/chart_of_accounts_repository.dart';
import '../../company/domain/company.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../../transactions/domain/transactions_repository.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';

/// Daftar transaksi `pending`. Tombol keputusan hanya untuk Manager;
/// Rules tetap menolak keputusan dari Finance.
class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({
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
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
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

  Future<void> _reject(FinanceTransaction tx) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason != null) await _controller.reject(tx, reason);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _accounts]),
    builder: (context, _) {
      final controller = _controller;
      final pending = controller.pendingTransactions;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Persetujuan',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            controller.isManager
                ? 'Transaksi yang disetujui atau ditolak tidak dapat diubah lagi.'
                : 'Hanya Manager yang dapat menyetujui atau menolak transaksi.',
            style: const TextStyle(color: AppColors.muted, height: 1.5),
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
          ] else if (pending.isEmpty)
            const FinovaCard(
              child: Text('Tidak ada transaksi yang menunggu persetujuan.'),
            )
          else ...[
            Text(
              '${pending.length} transaksi menunggu',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final tx in pending) ...[
              TransactionTile(
                transaction: tx,
                accountName: _accountName,
                footer: controller.isManager
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => controller.approve(tx),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Setujui'),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => _reject(tx),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Tolak'),
                          ),
                        ],
                      )
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      );
    },
  );
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validateRejectReason(_reason.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _reason.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tolak transaksi'),
    content: TextField(
      controller: _reason,
      autofocus: true,
      maxLines: 3,
      maxLength: TransactionLimits.maxRejectReason,
      decoration: InputDecoration(
        labelText: 'Alasan penolakan',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Tolak')),
    ],
  );
}
