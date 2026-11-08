import 'package:flutter/material.dart';

/// Metadata navigasi bersama; setiap modul tetap memiliki halaman sendiri.
enum AppDestination {
  dashboard(
    '/',
    'Beranda',
    'Ringkasan keuangan perusahaan Anda.',
    Icons.space_dashboard_outlined,
  ),
  transactions(
    '/transactions',
    'Transaksi',
    'Catat dan pantau pemasukan serta pengeluaran perusahaan.',
    Icons.swap_horiz_rounded,
  ),
  approvals(
    '/approvals',
    'Persetujuan',
    'Tinjau pengajuan transaksi sebelum masuk ke ledger.',
    Icons.fact_check_outlined,
  ),
  receivables(
    '/receivables',
    'Piutang',
    'Pantau tagihan pelanggan dan jadwal penerimaannya.',
    Icons.call_received_rounded,
  ),
  payables(
    '/payables',
    'Utang',
    'Kelola kewajiban pembayaran kepada pemasok.',
    Icons.call_made_rounded,
  ),
  accounts(
    '/accounts',
    'Kas & Bank',
    'Lihat rekening dan kas operasional perusahaan.',
    Icons.account_balance_wallet_outlined,
  ),
  categories(
    '/categories',
    'Kategori Akun',
    'Daftar akun pembukuan perusahaan (Chart of Accounts).',
    Icons.account_tree_outlined,
  ),
  reports(
    '/reports',
    'Laporan',
    'Tinjau arus kas dan laporan keuangan sederhana.',
    Icons.insert_chart_outlined_rounded,
  ),
  settings(
    '/settings',
    'Pengaturan',
    'Kelola preferensi aplikasi dan profil perusahaan.',
    Icons.tune_rounded,
  );

  const AppDestination(this.path, this.label, this.description, this.icon);
  final String path;
  final String label;
  final String description;
  final IconData icon;
}
