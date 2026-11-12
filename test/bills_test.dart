import 'package:finova/features/chart_of_accounts/domain/chart_account.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/ledger/domain/ledger_calculator.dart';
import 'package:finova/features/payables/domain/payable.dart';
import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/transactions/domain/bill.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

ChartAccount account(String code) =>
    defaultChartOfAccounts.firstWhere((a) => a.code == code);

List<ChartAccount> withInactive(String code) => [
  for (final a in defaultChartOfAccounts)
    a.code == code
        ? ChartAccount(
            code: a.code,
            name: a.name,
            type: a.type,
            normalBalance: a.normalBalance,
            isPosting: a.isPosting,
            parentCode: a.parentCode,
            isActive: false,
          )
        : a,
];

Receivable receivable({
  String id = 'r1',
  String customer = 'PT Pelanggan',
  String number = 'INV-001',
  int amount = 1000000,
  DateTime? issue,
  DateTime? due,
  String description = 'Jasa desain',
  String revenue = '4200',
  TransactionStatus status = TransactionStatus.approved,
}) => Receivable(
  id: id,
  customerName: customer,
  number: number,
  amount: amount,
  issueDate: issue ?? DateTime.utc(2026, 3, 1),
  dueDate: due ?? DateTime.utc(2026, 3, 31),
  description: description,
  revenueAccountId: revenue,
  status: status,
  createdBy: 'finance',
  createdAt: DateTime.utc(2026, 3, 1, 8),
  approvedBy: status == TransactionStatus.pending ? null : 'manager',
);

Payable payable({
  String id = 'p1',
  String supplier = 'CV Pemasok',
  String number = 'BILL-001',
  int amount = 600000,
  DateTime? issue,
  DateTime? due,
  String expense = '5300',
  TransactionStatus status = TransactionStatus.approved,
}) => Payable(
  id: id,
  supplierName: supplier,
  number: number,
  amount: amount,
  issueDate: issue ?? DateTime.utc(2026, 3, 1),
  dueDate: due ?? DateTime.utc(2026, 3, 31),
  description: 'Sewa kantor',
  expenseAccountId: expense,
  status: status,
  createdBy: 'finance',
  createdAt: DateTime.utc(2026, 3, 1, 8),
);

FinanceTransaction payment(
  String id, {
  TransactionType type = TransactionType.income,
  int amount = 400000,
  String? receivableId,
  String? payableId,
  String? category,
  TransactionStatus status = TransactionStatus.approved,
  DateTime? date,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  date: date ?? DateTime.utc(2026, 3, 10),
  description: 'Pembayaran $id',
  cashAccountId: '1100',
  categoryAccountId:
      category ??
      (type == TransactionType.income
          ? receivableAccountCode
          : payableAccountCode),
  status: status,
  createdBy: 'finance',
  createdAt: DateTime.utc(2026, 3, 10, 9),
  receivableId: receivableId,
  payableId: payableId,
);

String? checkBill(Bill bill, {List<ChartAccount>? accounts}) => bill.validate(
  accounts: accounts ?? defaultChartOfAccounts,
  bookkeepingStartDate: DateTime.utc(2026, 1, 1),
  now: DateTime.utc(2026, 6, 1),
);

TransactionDraft draft({
  TransactionType type = TransactionType.income,
  String category = receivableAccountCode,
  String? receivableId = 'r1',
  String? payableId,
}) => TransactionDraft(
  type: type,
  amount: 400000,
  date: DateTime.utc(2026, 3, 10),
  description: 'Pelunasan',
  cashAccountId: '1100',
  categoryAccountId: category,
  receivableId: receivableId,
  payableId: payableId,
);

String? checkDraft(TransactionDraft value, {List<ChartAccount>? accounts}) =>
    value.validate(
      accounts: accounts ?? defaultChartOfAccounts,
      bookkeepingStartDate: DateTime.utc(2026, 1, 1),
      now: DateTime.utc(2026, 6, 1),
    );

void main() {
  test(
    'Default COA: Piutang usaha 1300 (aset), Utang usaha 2100 (liabilitas)',
    () {
      expect(account(receivableAccountCode).name, 'Piutang usaha');
      expect(account(receivableAccountCode).type, AccountType.asset);
      expect(account(payableAccountCode).name, 'Utang usaha');
      expect(account(payableAccountCode).type, AccountType.liability);
    },
  );

  group('Validasi tagihan', () {
    test('Piutang dan utang valid', () {
      expect(checkBill(receivable()), isNull);
      expect(checkBill(payable()), isNull);
      expect(checkBill(receivable(due: DateTime.utc(2026, 3, 1))), isNull);
    });

    test('Nama, nomor, nominal, dan keterangan', () {
      expect(checkBill(receivable(customer: '  ')), contains('pelanggan'));
      expect(checkBill(payable(supplier: '')), contains('pemasok'));
      expect(checkBill(receivable(customer: 'a' * 101)), contains('maksimal'));
      expect(checkBill(receivable(number: ' ')), contains('Nomor'));
      expect(checkBill(receivable(number: 'N' * 51)), contains('maksimal'));
      expect(checkBill(receivable(amount: 0)), contains('Nominal'));
      expect(checkBill(payable(amount: -1)), contains('Nominal'));
      expect(
        checkBill(receivable(amount: TransactionLimits.maxAmount + 1)),
        contains('terlalu besar'),
      );
      expect(checkBill(receivable(description: ' ')), contains('Keterangan'));
      expect(
        checkBill(receivable(description: 'a' * 201)),
        contains('maksimal'),
      );
    });

    test('Tanggal tagihan dan jatuh tempo', () {
      expect(
        checkBill(receivable(issue: DateTime.utc(2025, 12, 31))),
        contains('awal pembukuan'),
      );
      expect(
        checkBill(
          receivable(
            issue: DateTime.utc(2026, 6, 2),
            due: DateTime.utc(2026, 7, 1),
          ),
        ),
        contains('masa depan'),
      );
      expect(
        checkBill(
          payable(
            issue: DateTime.utc(2026, 3, 10),
            due: DateTime.utc(2026, 3, 9),
          ),
        ),
        contains('Jatuh tempo'),
      );
      // Jatuh tempo boleh di masa depan.
      expect(checkBill(payable(due: DateTime.utc(2027, 1, 1))), isNull);
    });

    test('Akun lawan wajib Pendapatan/Beban posting aktif', () {
      expect(checkBill(receivable(revenue: '5200')), contains('Pendapatan'));
      expect(checkBill(receivable(revenue: '4000')), contains('Pendapatan'));
      expect(checkBill(receivable(revenue: '9999')), contains('Pendapatan'));
      expect(
        checkBill(receivable(), accounts: withInactive('4200')),
        contains('Pendapatan'),
      );
      expect(checkBill(payable(expense: '4100')), contains('Beban'));
      expect(checkBill(payable(expense: '2100')), contains('Beban'));
    });
  });

  group('Sisa tagihan dan status lunas', () {
    test('Belum dibayar, sebagian, lalu lunas', () {
      final bill = receivable();
      var s = bill.settlement([]);
      expect(s.status, SettlementStatus.unpaid);
      expect(s.remaining, 1000000);
      s = bill.settlement([payment('a', receivableId: 'r1')]);
      expect(s.status, SettlementStatus.partial);
      expect(s.paid, 400000);
      expect(s.remaining, 600000);
      expect(s.isPaid, isFalse);
      s = bill.settlement([
        payment('a', receivableId: 'r1'),
        payment('b', receivableId: 'r1', amount: 600000),
      ]);
      expect(s.status, SettlementStatus.paid);
      expect(s.remaining, 0);
      expect(s.overpaid, 0);
      expect(s.isPaid, isTrue);
    });

    test('Hanya pembayaran approved, jenis sesuai, dan ID sesuai', () {
      final bill = receivable();
      final s = bill.settlement([
        payment('ok', receivableId: 'r1'),
        payment(
          'pending',
          receivableId: 'r1',
          status: TransactionStatus.pending,
        ),
        payment(
          'rejected',
          receivableId: 'r1',
          status: TransactionStatus.rejected,
        ),
        payment('other', receivableId: 'r2'),
        payment('none'),
        // ID sama tetapi tertaut sebagai utang: bukan pembayaran piutang.
        payment('asPayable', type: TransactionType.expense, payableId: 'r1'),
        payment('wrongType', type: TransactionType.expense, receivableId: 'r1'),
      ]);
      expect(s.paid, 400000);
      expect(s.status, SettlementStatus.partial);
    });

    test('Utang memakai payableId dan transaksi expense', () {
      final bill = payable();
      final s = bill.settlement([
        payment('a', type: TransactionType.expense, payableId: 'p1'),
        payment(
          'b',
          type: TransactionType.expense,
          payableId: 'p1',
          amount: 200000,
        ),
        payment('c', receivableId: 'p1'),
      ]);
      expect(s.paid, 600000);
      expect(s.status, SettlementStatus.paid);
    });

    test('Kelebihan bayar tercatat, sisa tidak negatif', () {
      final s = receivable(amount: 500000).settlement([
        payment('a', receivableId: 'r1'),
        payment('b', receivableId: 'r1'),
      ]);
      expect(s.status, SettlementStatus.paid);
      expect(s.remaining, 0);
      expect(s.overpaid, 300000);
    });

    test('Jatuh tempo terlewati hanya bila belum lunas', () {
      final bill = receivable();
      final unpaid = bill.settlement([]);
      expect(bill.isOverdue(DateTime.utc(2026, 3, 31), unpaid), isFalse);
      expect(bill.isOverdue(DateTime.utc(2026, 4, 1), unpaid), isTrue);
      final paid = bill.settlement([
        payment('a', receivableId: 'r1', amount: 1000000),
      ]);
      expect(bill.isOverdue(DateTime.utc(2026, 4, 1), paid), isFalse);
    });
  });

  group('Transaksi pembayaran tagihan', () {
    test('Pembayaran piutang/utang valid memakai akun kontrol', () {
      expect(checkDraft(draft()), isNull);
      expect(
        checkDraft(
          draft(
            type: TransactionType.expense,
            category: payableAccountCode,
            receivableId: null,
            payableId: 'p1',
          ),
        ),
        isNull,
      );
    });

    test('Tanpa tagihan, akun Piutang/Utang tidak boleh jadi kategori', () {
      expect(checkDraft(draft(receivableId: null)), contains('Pendapatan'));
      expect(
        checkDraft(
          draft(
            type: TransactionType.expense,
            category: payableAccountCode,
            receivableId: null,
          ),
        ),
        contains('Beban'),
      );
    });

    test('Kategori wajib akun kontrol yang sesuai', () {
      expect(checkDraft(draft(category: '4100')), contains('Piutang'));
      expect(checkDraft(draft(category: '1400')), contains('Piutang'));
      expect(
        checkDraft(
          draft(
            type: TransactionType.expense,
            category: '5300',
            receivableId: null,
            payableId: 'p1',
          ),
        ),
        contains('Utang'),
      );
      expect(
        checkDraft(
          draft(
            type: TransactionType.expense,
            category: receivableAccountCode,
            receivableId: null,
            payableId: 'p1',
          ),
        ),
        contains('Utang'),
      );
    });

    test('Jenis transaksi harus sesuai jenis tagihan', () {
      expect(
        checkDraft(draft(type: TransactionType.expense)),
        contains('Pemasukan'),
      );
      expect(
        checkDraft(
          draft(
            category: payableAccountCode,
            receivableId: null,
            payableId: 'p1',
          ),
        ),
        contains('Pengeluaran'),
      );
    });

    test('Satu tagihan saja, ID tidak kosong, akun kontrol aktif', () {
      expect(checkDraft(draft(payableId: 'p1')), contains('satu tagihan'));
      expect(checkDraft(draft(receivableId: '  ')), contains('tidak valid'));
      expect(
        checkDraft(draft(), accounts: withInactive(receivableAccountCode)),
        contains('Piutang'),
      );
    });

    test('Validasi umum tetap berlaku untuk pembayaran tagihan', () {
      final bad = TransactionDraft(
        type: TransactionType.income,
        amount: 0,
        date: DateTime.utc(2026, 3, 10),
        description: 'x',
        cashAccountId: '1100',
        categoryAccountId: receivableAccountCode,
        receivableId: 'r1',
      );
      expect(checkDraft(bad), contains('Nominal'));
    });

    test('toDraft mempertahankan tautan tagihan', () {
      final tx = payment('a', receivableId: 'r1');
      expect(tx.toDraft().receivableId, 'r1');
      expect(tx.toDraft().payableId, isNull);
    });
  });

  group('Ledger dengan piutang/utang', () {
    test('Piutang approved: debit Piutang, kredit Pendapatan', () {
      final r = receivable();
      final piutang = LedgerCalculator.forAccount(
        account(receivableAccountCode),
        const [],
        receivables: [r],
      );
      expect(piutang.entries.single.debit, 1000000);
      expect(piutang.entries.single.source, JournalSource.receivable);
      expect(piutang.entries.single.sourceId, 'r1');
      expect(piutang.entries.single.description, contains('INV-001'));
      final pendapatan = LedgerCalculator.forAccount(
        account('4200'),
        const [],
        receivables: [r],
      );
      expect(pendapatan.entries.single.credit, 1000000);
      expect(pendapatan.closingBalance, 1000000);
    });

    test('Utang approved: debit Beban, kredit Utang', () {
      final p = payable();
      final beban = LedgerCalculator.forAccount(
        account('5300'),
        const [],
        payables: [p],
      );
      expect(beban.entries.single.debit, 600000);
      expect(beban.closingBalance, 600000);
      final utang = LedgerCalculator.forAccount(
        account(payableAccountCode),
        const [],
        payables: [p],
      );
      expect(utang.entries.single.credit, 600000);
      expect(utang.closingBalance, 600000);
    });

    test('Tagihan pending/rejected tidak masuk ledger', () {
      final balances = LedgerCalculator.balances(
        defaultChartOfAccounts,
        const [],
        receivables: [
          receivable(status: TransactionStatus.pending),
          receivable(id: 'r2', status: TransactionStatus.rejected),
        ],
        payables: [payable(status: TransactionStatus.pending)],
      );
      expect(balances.values.every((v) => v == 0), isTrue);
    });

    test('Siklus piutang lengkap tanpa pendapatan ganda', () {
      final r = receivable();
      final txs = [
        payment('a', receivableId: 'r1'),
        payment(
          'b',
          receivableId: 'r1',
          amount: 600000,
          date: DateTime.utc(2026, 3, 20),
        ),
      ];
      final b = LedgerCalculator.balances(
        defaultChartOfAccounts,
        txs,
        receivables: [r],
      );
      expect(b['4200'], 1000000);
      expect(b[receivableAccountCode], 0);
      expect(b['1100'], 1000000);
      final ledger = LedgerCalculator.forAccount(
        account(receivableAccountCode),
        txs,
        receivables: [r],
      );
      expect(ledger.entries.map((e) => e.balance), [1000000, 600000, 0]);
      expect(ledger.closingBalance, r.settlement(txs).remaining);
    });

    test('Siklus utang sebagian: sisa utang = saldo akun Utang', () {
      final p = payable();
      final txs = [
        payment('a', type: TransactionType.expense, payableId: 'p1'),
      ];
      final b = LedgerCalculator.balances(
        defaultChartOfAccounts,
        txs,
        payables: [p],
      );
      expect(b['5300'], 600000);
      expect(b[payableAccountCode], 200000);
      expect(b['1100'], -400000);
      expect(b[payableAccountCode], p.settlement(txs).remaining);
    });

    test('Jurnal gabungan seimbang dan urutan deterministik', () {
      final txs = [
        payment('t1', receivableId: 'r1', date: DateTime.utc(2026, 3, 1)),
        FinanceTransaction(
          id: 't2',
          type: TransactionType.expense,
          amount: 50000,
          date: DateTime.utc(2026, 3, 1),
          description: 'ATK',
          cashAccountId: '1200',
          categoryAccountId: '5900',
          status: TransactionStatus.approved,
          createdBy: 'finance',
          createdAt: DateTime.utc(2026, 3, 1, 8),
        ),
      ];
      final lines = LedgerCalculator.journal(
        txs,
        receivables: [receivable()],
        payables: [payable()],
      );
      // Tanggal & createdAt sama → urut jenis sumber, lalu ID.
      expect(lines.map((l) => '${l.source.name}:${l.sourceId}'), [
        'transaction:t2',
        'receivable:r1',
        'payable:p1',
        'transaction:t1',
      ]);
      final b = LedgerCalculator.balances(
        defaultChartOfAccounts,
        txs,
        receivables: [receivable()],
        payables: [payable()],
      );
      var debit = 0;
      var credit = 0;
      for (final a in defaultChartOfAccounts) {
        a.normalBalance == BalanceSide.debit
            ? debit += b[a.code]!
            : credit += b[a.code]!;
      }
      expect(debit, credit);
    });

    test('Filter tanggal memakai tanggal tagihan sebagai saldo awal', () {
      final ledger = LedgerCalculator.forAccount(
        account(receivableAccountCode),
        [payment('a', receivableId: 'r1')],
        receivables: [receivable()],
        from: DateTime.utc(2026, 3, 5),
      );
      expect(ledger.openingBalance, 1000000);
      expect(ledger.entries.single.credit, 400000);
      expect(ledger.closingBalance, 600000);
    });
  });
}
