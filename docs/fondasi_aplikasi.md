# Fondasi aplikasi Finova

Implementasi awal memakai Material 3 dengan dominasi putih, primary biru,
highlight kuning, dan aksen pink sesuai palet di `AGENTS.md`.

## Struktur

```text
lib/
  main.dart                          # Entry point
  app/
    app.dart                         # MaterialApp.router dan lifecycle router
    routes/
      app_router.dart                # ShellRoute dan seluruh rute
      app_destinations.dart          # Metadata modul
    theme/
      app_colors.dart                # Palet global
      app_theme.dart                 # Tema Material 3
  core/
    utils/rupiah.dart                # Format integer Rupiah
    widgets/
      app_shell.dart                 # Safe area dan bottom navigation
      finova_card.dart               # Card dan judul bagian reusable
      feature_placeholder.dart       # Tampilan modul yang belum tersedia
  features/
    dashboard/
      data/dashboard_dummy_data.dart # Snapshot, model presentasi, data contoh
      presentation/
        dashboard_page.dart
        widgets/                     # Ringkasan, grafik, transaksi terbaru
    menu/presentation/menu_page.dart
    transactions/presentation/transactions_page.dart
    approvals/presentation/approvals_page.dart
    receivables/presentation/receivables_page.dart
    payables/presentation/payables_page.dart
    accounts/presentation/accounts_page.dart
    reports/presentation/reports_page.dart
    settings/presentation/settings_page.dart
    auth/                            # Folder awal dipertahankan
    ledger/                          # Folder awal dipertahankan
```

Folder `core/constants/` yang sudah tersedia juga dipertahankan. Tidak ada
integrasi Firebase, backend, autentikasi, atau operasi keuangan nyata pada tahap ini.

## Navigasi

Bottom navigation: Beranda (`/`), Transaksi (`/transactions`), Persetujuan
(`/approvals`), dan Menu (`/menu`). Menu memuat seluruh delapan modul utama.
Modul tambahan memakai rute `/receivables`, `/payables`, `/accounts`, `/reports`,
dan `/settings`. Navigasi dari Menu dan akses cepat menggunakan stack agar
tombol kembali Android mengembalikan pengguna ke halaman asal. Pemilihan tab
mengganti lokasi utama. Rute tidak dikenal menyediakan tombol kembali ke Beranda.

Selain Beranda dan Menu, halaman masih berupa placeholder. Tombol dan tautan
yang ditampilkan menuju halaman yang tersedia; belum ada formulir atau aksi
transaksi. Grafik bersifat statis dengan label semantik untuk pembaca layar.

## Data dan pengembangan berikutnya

`DashboardPage` menerima `DashboardSnapshot` melalui constructor. Fixture
`dashboardDummyData` memakai periode Oktober 2026 dan nominal integer Rupiah.
Grafik mingguan berjumlah pemasukan Rp 32.500.000 dan pengeluaran Rp 18.750.000.
Saldo akhir contoh Rp 48.750.000 merepresentasikan saldo awal Rp 35.000.000
ditambah selisih arus kas. Daftar terbaru hanya sebagian transaksi periode ini.
Utang dan piutang terpisah dari arus kas; transaksi menunggu tidak masuk saldo.
Snapshot bersifat contoh, bukan mesin perhitungan ledger atau laba-rugi.

Dependensi langsung baru: `go_router: ^18.1.2`. Grafik memakai widget Flutter
tanpa paket grafik tambahan. Riverpod belum diperlukan untuk snapshot statis.

Tahap berikutnya adalah menetapkan model domain, validasi, serta kontrak akses
data sebelum membangun formulir transaksi dan alur persetujuan. Saat integrasi
Firebase diminta, tambahkan autentikasi dan otorisasi Manager/Finance pada
backend/Security Rules, operasi atomik, dan pemisahan repository dari presentasi.
Riverpod dapat ditambahkan saat ada state asinkron atau state lintas fitur.

## Menjalankan dan memvalidasi

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554 --no-dds
```

`test/widget_test.dart` menguji format Rupiah, isi dashboard, tab utama,
seluruh tujuan Menu, navigasi kembali, deep link, pemulihan rute tidak dikenal,
serta overflow pada layar 320dp dengan skala teks 1,0 / 1,6 / 2,0.

Pada lingkungan Windows sesi implementasi, Gradle sempat gagal dengan
`Unable to establish loopback connection`. Build berhasil dengan properti
Java sementara `-Djdk.net.unixdomain.tmpdir` yang diarahkan ke
`build/java_tmp` di workspace. Properti ini mengatur direktori socket menurut
[implementasi OpenJDK](https://github.com/openjdk/jdk17u/blob/master/src/java.base/windows/classes/sun/nio/ch/UnixDomainSocketsUtil.java).
Tidak ada perubahan konfigurasi Android atau pengaturan Java permanen.
