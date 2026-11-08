import 'chart_account.dart';

// ID dokumen = kode akun agar inisialisasi/retry tidak menggandakan akun.
final defaultChartOfAccounts = List<ChartAccount>.unmodifiable([
  for (final type in AccountType.values)
    ChartAccount(
      code: type.groupCode,
      name: type.label,
      type: type,
      normalBalance: type.normalBalance,
      isPosting: false,
    ),
  ..._postingAccounts(AccountType.asset, {
    '1100': 'Kas',
    '1200': 'Bank',
    '1300': 'Piutang usaha',
    '1400': 'Persediaan',
  }),
  ..._postingAccounts(AccountType.liability, {
    '2100': 'Utang usaha',
    '2200': 'Pinjaman',
  }),
  ..._postingAccounts(AccountType.equity, {
    '3100': 'Modal pemilik',
    '3200': 'Saldo laba',
  }),
  ..._postingAccounts(AccountType.revenue, {
    '4100': 'Penjualan barang',
    '4200': 'Pendapatan jasa',
    '4900': 'Pendapatan lainnya',
  }),
  ..._postingAccounts(AccountType.expense, {
    '5100': 'Harga pokok penjualan',
    '5200': 'Beban gaji',
    '5300': 'Beban sewa',
    '5400': 'Beban utilitas',
    '5500': 'Beban transportasi',
    '5600': 'Beban administrasi bank',
    '5900': 'Beban lainnya',
  }),
]);

Iterable<ChartAccount> _postingAccounts(
  AccountType type,
  Map<String, String> names,
) => names.entries.map(
  (entry) => ChartAccount(
    code: entry.key,
    name: entry.value,
    type: type,
    normalBalance: type.normalBalance,
    isPosting: true,
    parentCode: type.groupCode,
  ),
);
