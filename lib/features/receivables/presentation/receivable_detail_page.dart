import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/rupiah.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/domain/chart_account.dart';
import '../../company/domain/company.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../../transactions/domain/transactions_repository.dart';
import '../application/receivables_controller.dart';
import '../domain/bill.dart';
import '../domain/receivable.dart';

class ReceivableDetailPage extends StatelessWidget {
  const ReceivableDetailPage({
    super.key,
    required this.receivable,
    required this.controller,
    required this.transactionsRepository,
    required this.company,
    required this.accounts,
  });

  final Receivable receivable;
  final ReceivablesController controller;
  final TransactionsRepository transactionsRepository;
  final Company company;
  final List<ChartAccount> accounts;

  bool get _hasReceivableAccount => accounts.any(
    (account) =>
        account.code == '1300' &&
        account.type == AccountType.asset &&
        account.isPosting &&
        account.isActive,
  );
  bool get _hasCashAccount =>
      accounts.any((account) => isCashBankAccount(account) && account.isActive);

  Future<void> _reject(
    BuildContext context,
    Receivable currentReceivable,
  ) async {
    final reason = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak piutang?'),
        content: TextField(
          controller: reason,
          maxLength: TransactionLimits.maxRejectReason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Alasan penolakan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reason.text),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (result != null) await controller.reject(currentReceivable, result);
  }

  Future<void> _recordPayment(
    BuildContext context,
    Receivable currentReceivable,
    List<Bill> bills,
    int remaining,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _RecordPaymentDialog(
        receivable: currentReceivable,
        remaining: remaining,
        bills: bills,
        company: company,
        accounts: accounts,
        repository: transactionsRepository,
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran diajukan untuk persetujuan Manager.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail piutang')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final currentReceivable =
              controller.receivables
                  .where((item) => item.id == receivable.id)
                  .firstOrNull ??
              receivable;
          final bills =
              controller.bills
                  .where((bill) => bill.receivableId == currentReceivable.id)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
          final remaining = currentReceivable.remainingAmount(bills);
          final paymentStatus = currentReceivable.paymentStatus(remaining);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (controller.actionError != null)
                AuthMessage(message: controller.actionError!),
              if (controller.notice != null)
                AuthMessage(message: controller.notice!, isError: false),
              Text(
                currentReceivable.customerName,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('Nomor ${currentReceivable.number}'),
              const SizedBox(height: 20),
              _DetailLine(
                'Jumlah piutang',
                formatRupiah(currentReceivable.amount),
              ),
              _DetailLine('Sisa tagihan', formatRupiah(remaining)),
              _DetailLine(
                'Jatuh tempo',
                formatShortDate(currentReceivable.dueDate),
              ),
              _DetailLine('Status tagihan', paymentStatus),
              _DetailLine('Persetujuan', currentReceivable.status.label),
              if (currentReceivable.description.isNotEmpty)
                _DetailLine('Keterangan', currentReceivable.description),
              if (currentReceivable.rejectReason != null)
                _DetailLine('Alasan ditolak', currentReceivable.rejectReason!),
              if (controller.isManager && currentReceivable.isPending) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => controller.approve(currentReceivable),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Setujui'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => _reject(context, currentReceivable),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Tolak'),
                    ),
                  ],
                ),
              ],
              if (currentReceivable.status == ReceivableStatus.approved &&
                  remaining > 0) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _hasReceivableAccount &&
                          _hasCashAccount &&
                          !controller.busy
                      ? () => _recordPayment(
                          context,
                          currentReceivable,
                          bills,
                          remaining,
                        )
                      : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Catat pembayaran'),
                ),
                if (!_hasReceivableAccount)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Akun Piutang (1300) belum tersedia. Minta Manager menyiapkan kategori akun.',
                    ),
                  ),
                if (_hasReceivableAccount && !_hasCashAccount)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Akun Kas/Bank belum tersedia. Minta Manager menyiapkan kategori akun.',
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              Text(
                'Riwayat pembayaran',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (bills.isEmpty)
                const Text('Belum ada pembayaran.')
              else
                for (final bill in bills) _PaymentTile(bill: bill),
            ],
          );
        },
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
    title: Text(formatRupiah(bill.amount)),
    subtitle: Text('${formatShortDate(bill.date)} · ${bill.description}'),
    trailing: Text(
      bill.status.label,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({
    required this.receivable,
    required this.remaining,
    required this.bills,
    required this.company,
    required this.accounts,
    required this.repository,
  });

  final Receivable receivable;
  final int remaining;
  final List<Bill> bills;
  final Company company;
  final List<ChartAccount> accounts;
  final TransactionsRepository repository;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  late final _amount = TextEditingController();
  late final List<ChartAccount> _cashAccounts = widget.accounts
      .where((account) => isCashBankAccount(account) && account.isActive)
      .toList();
  String? _cashAccountId;
  String? _error;
  bool _busy = false;

  int get _available {
    final available =
        widget.remaining -
        widget.bills
            .where((bill) => bill.status == TransactionStatus.pending)
            .fold<int>(0, (total, bill) => total + bill.amount);
    return available > 0 ? available : 0;
  }

  @override
  void initState() {
    super.initState();
    _cashAccountId = _cashAccounts.firstOrNull?.code;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Jumlah harus lebih dari Rp 0.');
      return;
    }
    if (amount > _available) {
      setState(() => _error = 'Pembayaran melebihi sisa yang belum diajukan.');
      return;
    }
    final draft = TransactionDraft(
      type: TransactionType.income,
      amount: amount,
      date: dateOnly(DateTime.now()),
      description:
          'Pembayaran piutang ${widget.receivable.number} · ${widget.receivable.customerName}',
      cashAccountId: _cashAccountId ?? '',
      categoryAccountId: '1300',
      receivableId: widget.receivable.id,
    );
    final error = draft.validate(
      accounts: widget.accounts,
      bookkeepingStartDate: widget.company.bookkeepingStartDate,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final id = widget.repository.newTransactionId(widget.company.id);
      await widget.repository.create(widget.company.id, id, draft);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is TransactionFailure
              ? error.message
              : 'Pembayaran belum dapat dicatat. Silakan coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Catat pembayaran'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sisa yang belum diajukan: ${formatRupiah(_available)}'),
          const SizedBox(height: 12),
          if (_error != null) AuthMessage(message: _error!),
          TextField(
            controller: _amount,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                _cashAccounts.any((account) => account.code == _cashAccountId)
                ? _cashAccountId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Akun Kas/Bank'),
            items: [
              for (final account in _cashAccounts)
                DropdownMenuItem(
                  value: account.code,
                  child: Text('${account.code} · ${account.name}'),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _cashAccountId = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _busy || _available <= 0 ? null : _submit,
        child: Text(_busy ? 'Menyimpan…' : 'Ajukan pembayaran'),
      ),
    ],
  );
}
