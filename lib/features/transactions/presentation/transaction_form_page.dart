import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/rupiah.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../chart_of_accounts/domain/chart_account.dart';
import '../application/transactions_controller.dart';
import '../domain/finance_transaction.dart';

/// Form tambah/edit transaksi. `existing == null` berarti transaksi baru.
class TransactionFormPage extends StatefulWidget {
  const TransactionFormPage({
    super.key,
    required this.controller,
    required this.accounts,
    required this.bookkeepingStartDate,
    this.existing,
  });
  final TransactionsController controller;
  final List<ChartAccount> accounts;
  final DateTime bookkeepingStartDate;
  final FinanceTransaction? existing;

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  late final _id = widget.existing?.id ?? widget.controller.newTransactionId();
  late TransactionType _type = widget.existing?.type ?? TransactionType.expense;
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.amount.toString(),
  );
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late DateTime _date = widget.existing?.date ?? dateOnly(DateTime.now());
  late String? _cash = widget.existing?.cashAccountId;
  late String? _category = widget.existing?.categoryAccountId;
  String? _error;

  List<ChartAccount> get _cashAccounts =>
      widget.accounts.where((a) => isCashBankAccount(a) && a.isActive).toList();
  List<ChartAccount> get _categories => widget.accounts
      .where((account) => isCategoryAccount(account, _type))
      .toList();

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final first = dateOnly(widget.bookkeepingStartDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first.isAfter(today) ? today : first,
      lastDate: today,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _submit() async {
    final draft = TransactionDraft(
      type: _type,
      amount: int.tryParse(_amount.text) ?? 0,
      date: _date,
      description: _description.text,
      cashAccountId: _cash ?? '',
      categoryAccountId: _category ?? '',
    );
    final error = draft.validate(
      accounts: widget.accounts,
      bookkeepingStartDate: widget.bookkeepingStartDate,
    );
    setState(() => _error = error);
    if (error != null) return;
    final existing = widget.existing;
    final ok = existing == null
        ? await widget.controller.create(_id, draft)
        : await widget.controller.update(existing, draft);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = widget.controller.actionError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = int.tryParse(_amount.text);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Tambah transaksi' : 'Edit transaksi',
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final busy = widget.controller.busy;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null) AuthMessage(message: _error!),
                SegmentedButton<TransactionType>(
                  segments: [
                    for (final type in TransactionType.values)
                      ButtonSegment(value: type, label: Text(type.label)),
                  ],
                  selected: {_type},
                  onSelectionChanged: busy
                      ? null
                      : (value) => setState(() {
                          _type = value.first;
                          _category = null;
                        }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Nominal (Rp)',
                    helperText: amount == null ? null : formatRupiah(amount),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Tanggal: ${formatShortDate(_date)}'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _description,
                  enabled: !busy,
                  maxLength: TransactionLimits.maxDescription,
                  decoration: const InputDecoration(labelText: 'Keterangan'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const ValueKey('cash'),
                  initialValue: _cashAccounts.any((a) => a.code == _cash)
                      ? _cash
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
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _cash = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('category-${_type.name}'),
                  initialValue: _categories.any((a) => a.code == _category)
                      ? _category
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Kategori (${_type.categoryType.label})',
                  ),
                  items: [
                    for (final account in _categories)
                      DropdownMenuItem(
                        value: account.code,
                        child: Text('${account.code} · ${account.name}'),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _category = value),
                ),
                if (_cashAccounts.isEmpty || _categories.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Akun belum tersedia. Minta Manager menyiapkan kategori akun default.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(
                    busy
                        ? 'Menyimpan…'
                        : widget.existing == null
                        ? 'Ajukan transaksi'
                        : 'Simpan perubahan',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Transaksi berstatus Menunggu dan belum memengaruhi saldo sampai disetujui Manager.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
