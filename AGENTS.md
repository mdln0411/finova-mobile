# AGENTS.md — Finova

## Project Overview

Finova adalah aplikasi mobile berbasis Flutter untuk mengelola keuangan operasional perusahaan kecil.

Proyek ini dikembangkan untuk mata kuliah Pemrograman Mobile.

Fokus aplikasi adalah pencatatan transaksi, pengelolaan utang-piutang, kas dan bank, persetujuan transaksi, serta laporan keuangan sederhana.

Finova bukan aplikasi ERP penuh.

## Technology Stack

- Framework: Flutter
- Language: Dart
- Target platform: Android
- Authentication: Firebase Authentication
- Database: Cloud Firestore
- State management: Riverpod
- Navigation: GoRouter
- UI: Material 3

Firebase Authentication dan Cloud Firestore merupakan teknologi yang direncanakan. Jangan menganggap keduanya sudah terintegrasi sebelum memeriksa repository.

## Architecture

Gunakan arsitektur feature-first yang sederhana dan modular.

Struktur utama:

- `lib/app/`: Konfigurasi aplikasi, tema, dan navigasi.
- `lib/core/`: Komponen, utilitas, dan konstanta bersama.
- `lib/features/`: Implementasi fitur berdasarkan modul.

Modul utama:

- auth
- dashboard
- transactions
- approvals
- ledger
- receivables
- payables
- accounts
- reports
- settings

Hindari boilerplate berlebihan dan abstraksi yang belum diperlukan.

Pisahkan UI, akses data, dan logika bisnis.

## Business Rules

Finova ditujukan untuk satu perusahaan dengan dua peran:

**Manager**
- Menyetujui atau menolak transaksi.
- Memantau kondisi keuangan.
- Mengakses laporan.

**Finance**
- Mencatat transaksi.
- Mengelola utang dan piutang.
- Mengelola kas dan bank.
- Mengajukan transaksi untuk persetujuan.

Alur utama:

Transaksi → Kategori → Approval → Ledger → Laporan.

Aturan penting:

1. Transaksi yang belum disetujui tidak boleh memengaruhi saldo final.
2. Transaksi yang ditolak tidak boleh masuk ke ledger.
3. Hindari penghitungan ganda terhadap pemasukan dan pengeluaran.
4. Pisahkan konsep arus kas dari laba-rugi.
5. Gunakan representasi nilai uang yang menghindari kesalahan pembulatan floating-point.
6. Validasi nominal, tanggal, kategori, dan status transaksi.
7. Jangan hanya mengandalkan UI untuk membatasi hak akses Manager dan Finance.

## Coding Standards

- Gunakan Dart null safety.
- Ikuti konvensi penamaan Dart dan Flutter.
- Utamakan widget kecil yang dapat digunakan kembali.
- Gunakan `const` jika memungkinkan.
- Hindari business logic yang kompleks di dalam widget.
- Gunakan penamaan file `snake_case`.
- Gunakan nama class `PascalCase`.
- Jangan menambahkan dependensi tanpa alasan yang jelas.
- Jangan melakukan refactoring besar di luar cakupan tugas.
- Pertahankan kompatibilitas dengan versi Flutter proyek.

## UI/UX Guidelines

- Gunakan Material 3.
- Desain modern, minimalis, dan profesional.
- Dominasi putih (#FFFFFF), primary biru (#2563EB), aksen kuning (#FACC15), dan pink (#EC4899).
- Surface #F8FAFC, teks utama #0F172A, dan teks sekunder #64748B.
- Biru untuk navigasi dan interaksi; kuning untuk highlight/statistik; pink untuk grafik atau kategori.
- Gunakan aksen secukupnya, whitespace, sudut membulat, dan card modern dengan kontras serta aksesibilitas yang baik.
- Gunakan format mata uang Rupiah.
- Pastikan tampilan responsif pada layar Android.
- Sediakan indikator loading, empty state, dan error state jika diperlukan.
- Hindari overflow dan navigasi yang membingungkan.

## Firebase Guidelines

- Gunakan Firebase Authentication untuk autentikasi.
- Gunakan Cloud Firestore untuk data aplikasi ketika integrasi database dimulai.
- Jangan menyimpan kredensial rahasia di repository.
- Terapkan Firebase Security Rules sesuai hak akses pengguna.
- Jangan menganggap validasi pada client sebagai perlindungan keamanan yang cukup.
- Gunakan operasi atomik atau transaksi database ketika konsistensi data keuangan diperlukan.
- Jangan mengintegrasikan layanan Firebase sebelum diminta dalam tugas implementasi.

## Git Workflow

Branch:

- `main`: Versi stabil.
- `develop`: Integrasi pengembangan.
- `feature/*`: Pengembangan fitur tertentu.

Aturan:

1. Kerjakan perubahan pada branch aktif yang sesuai.
2. Jangan membuat branch baru tanpa instruksi.
3. Jangan melakukan commit, push, merge, atau rebase tanpa izin pengguna.
4. Jangan mengubah riwayat Git.
5. Jangan menggunakan `git push --force`.
6. Jangan menghapus perubahan pengguna yang tidak terkait dengan tugas.

Gunakan bahasa Indonesia untuk pesan commit dengan format Conventional Commits.

Contoh:

- `feat: menambahkan halaman login`
- `fix: memperbaiki validasi transaksi`
- `refactor: merapikan struktur aplikasi`
- `docs: memperbarui dokumentasi`
- `chore: memperbarui dependensi`

## Testing and Validation

Setelah melakukan perubahan kode:

1. Jalankan `flutter analyze`.
2. Jalankan `flutter test` jika relevan.
3. Jalankan `flutter pub get` jika dependensi berubah.
4. Uji aplikasi pada emulator jika tersedia.
5. Laporkan error yang belum terselesaikan.

Jika menggunakan Android Emulator dan koneksi Dart Development Service bermasalah, pertimbangkan `flutter run --no-dds`.

Jangan mengklaim pengujian berhasil jika belum dijalankan.

## Agent Behavior

Saat menerima tugas:

1. Pahami permintaan pengguna.
2. Periksa kode dan struktur proyek yang relevan.
3. Buat perubahan sekecil mungkin untuk menyelesaikan tugas.
4. Jangan mengimplementasikan fitur tambahan tanpa diminta.
5. Jangan menghapus kode yang sudah berfungsi tanpa alasan.
6. Pastikan perubahan konsisten dengan arsitektur proyek.
7. Jalankan validasi yang sesuai.
8. Laporkan hasil implementasi secara ringkas.

Gunakan bahasa Indonesia untuk komunikasi, penjelasan, dan dokumentasi pengguna.

Gunakan bahasa Inggris untuk nama class, function, variable, dan istilah teknis dalam kode jika sesuai konvensi Dart.

## Completion Report

Setelah menyelesaikan tugas, laporkan:

- Ringkasan perubahan.
- File yang dibuat atau diubah.
- Dependensi baru, jika ada.
- Hasil pengujian.
- Kendala yang belum terselesaikan.
- Saran langkah berikutnya.
