import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/rupiah.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/domain/chart_account.dart';
import '../../transactions/domain/bill.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../application/receivables_controller.dart';
import '../domain/receivable.dart';

class ReceivableFormPage extends StatefulWidget {
  const ReceivableFormPage({
    super.key,
    required this.controller,
    required this.bookkeepingStartDate,
    required this.revenueAccounts,
    this.existing,
  });

  final ReceivablesController controller;
  final DateTime bookkeepingStartDate;
  final List<ChartAccount> revenueAccounts;
  final Receivable? existing;

  @override
  State<ReceivableFormPage> createState() => _ReceivableFormPageState();
}

class _ReceivableFormPageState extends State<ReceivableFormPage> {
  late final _id = widget.existing?.id ?? widget.controller.newReceivableId();
  late final _customer = TextEditingController(
    text: widget.existing?.customerName ?? '',
  );
  late final _number = TextEditingController(
    text: widget.existing?.number ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.existing?.amount.toString() ?? '',
  );
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late String? _revenueAccountId = widget.existing?.revenueAccountId;
  late DateTime _issueDate = widget.existing?.issueDate ?? _defaultDate;
  late DateTime _dueDate = widget.existing?.dueDate ?? _issueDate;
  String? _error;

  @override
  void dispose() {
    _customer.dispose();
    _number.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime get _defaultDate {
    final today = dateOnly(DateTime.now());
    final start = dateOnly(widget.bookkeepingStartDate);
    return today.isBefore(start) ? start : today;
  }

  Future<void> _pickIssueDate() async {
    final first = dateOnly(widget.bookkeepingStartDate);
    final today = dateOnly(DateTime.now());
    final last = today.isBefore(first) ? first : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate.isBefore(first)
          ? first
          : _issueDate.isAfter(last)
          ? last
          : _issueDate,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    setState(() {
      _issueDate = dateOnly(picked);
      if (_dueDate.isBefore(_issueDate)) _dueDate = _issueDate;
    });
  }

  Future<void> _pickDueDate() async {
    final first = dateOnly(_issueDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(first) ? first : _dueDate,
      firstDate: first,
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _dueDate = dateOnly(picked));
  }

  Future<void> _submit() async {
    final existing = widget.existing;
    final receivable = Receivable(
      id: _id,
      customerName: _customer.text.trim(),
      number: _number.text.trim(),
      amount: int.tryParse(_amount.text) ?? 0,
      issueDate: _issueDate,
      dueDate: _dueDate,
      description: _description.text.trim(),
      revenueAccountId: _revenueAccountId ?? '',
      status: existing?.status ?? TransactionStatus.pending,
      createdBy: existing?.createdBy ?? widget.controller.userId ?? '',
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    final error = receivable.validate(
      accounts: widget.revenueAccounts,
      bookkeepingStartDate: widget.bookkeepingStartDate,
    );
    setState(() => _error = error);
    if (error != null) return;
    final ok = existing == null
        ? await widget.controller.create(receivable)
        : await widget.controller.update(existing, receivable);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = widget.controller.actionError);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Tambah piutang' : 'Edit piutang'),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final busy = widget.controller.busy;
          final amount = int.tryParse(_amount.text);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null) AuthMessage(message: _error!),
              TextField(
                controller: _customer,
                enabled: !busy,
                maxLength: BillLimits.maxPartyName,
                decoration: const InputDecoration(labelText: 'Nama customer'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _number,
                enabled: !busy,
                maxLength: BillLimits.maxNumber,
                decoration: const InputDecoration(labelText: 'Nomor piutang'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: InputDecoration(
                  labelText: 'Jumlah (Rp)',
                  helperText: amount == null ? null : formatRupiah(amount),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    widget.revenueAccounts.any(
                      (account) => account.code == _revenueAccountId,
                    )
                    ? _revenueAccountId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Akun Pendapatan'),
                items: [
                  for (final account in widget.revenueAccounts)
                    DropdownMenuItem(
                      value: account.code,
                      child: Text('${account.code} · ${account.name}'),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => _revenueAccountId = value),
              ),
              if (widget.revenueAccounts.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Akun Pendapatan belum tersedia. Minta Manager menyiapkan kategori akun.',
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickIssueDate,
                icon: const Icon(Icons.today_outlined),
                label: Text('Tanggal tagihan: ${formatShortDate(_issueDate)}'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickDueDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('Jatuh tempo: ${formatShortDate(_dueDate)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                enabled: !busy,
                maxLength: TransactionLimits.maxDescription,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: Text(
                  busy
                      ? 'Menyimpan…'
                      : widget.existing == null
                      ? 'Ajukan piutang'
                      : 'Simpan perubahan',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Piutang baru menunggu persetujuan Manager sebelum dapat dibayar.',
                style: TextStyle(height: 1.5),
              ),
            ],
          );
        },
      ),
    ),
  );
}
