# Kategori Akun — Chart of Accounts Finova

## Cakupan dan arsitektur

Kategori Akun adalah daftar akun buku besar per perusahaan, terpisah dari modul
Kas & Bank yang kelak mengelola rekening/kas operasional. Akses melalui
**Menu → Kategori Akun** (`/categories`). Guard autentikasi, profil lengkap, dan
membership aktif tetap menggunakan alur perusahaan yang sudah ada.

```text
lib/features/chart_of_accounts/
  domain/chart_account.dart                    tipe, saldo normal, model/validasi
  domain/default_chart_of_accounts.dart         23 template akun
  domain/chart_of_accounts_repository.dart      kontrak repository
  data/chart_account_codec.dart                parsing/serialisasi Firestore
  data/firebase_chart_of_accounts_repository.dart akses Firestore perusahaan
  application/chart_of_accounts_controller.dart loading, filter, retry, seed
  presentation/chart_of_accounts_page.dart      daftar Material 3
```

UI tidak membaca Firestore langsung. Repository dapat diganti fake pada tes.
Controller dimiliki halaman dan dibuang ketika halaman ditutup/logout. Stream
meneruskan pembatalan langsung ke listener SDK. Tidak ada dependensi baru,
perubahan konfigurasi Android, perubahan Auth/profil, transaksi, atau ledger.

## Struktur Firestore

Path tunggal: `companies/{companyId}/chart_of_accounts/{code}`.
Company ID berasal dari konteks membership aktif; kode menjadi ID deterministik
agar satu kode tidak menghasilkan beberapa dokumen.

| Field | Tipe / aturan |
|---|---|
| code | string 4 digit, sama dengan ID dokumen |
| name | string 2–100 karakter, tanpa spasi luar/baris baru/tab |
| type | asset, liability, equity, revenue, expense |
| normalBalance | debit untuk asset/expense; credit untuk lainnya |
| parentCode | null untuk kelompok, kode kelompok untuk akun posting |
| isPosting | false untuk kelompok, true untuk akun detail |
| isActive | bool; default baru true |
| createdBy | UID Manager dari Firebase Auth |
| createdAt / updatedAt | server timestamp saat dibuat |

Tidak ada field saldo, nominal, role, companyId duplikat, atau token di dokumen.
Parsing menolak kode/tipe/metadata yang salah, saldo normal tidak sesuai,
timestamp rusak, kode duplikat, dan induk yang hilang/tidak sesuai.

## Default dan fondasi double-entry

Versi awal menggunakan dua tingkat: kelompok `x000` tidak dapat diposting;
akun detail berada di bawah kelompok dengan tipe sama. Kode dikelompokkan:

| Kelompok | Akun detail default |
|---|---|
| 1000 Aset (Debit) | 1100 Kas, 1200 Bank, 1300 Piutang usaha, 1400 Persediaan |
| 2000 Liabilitas (Kredit) | 2100 Utang usaha, 2200 Pinjaman |
| 3000 Ekuitas (Kredit) | 3100 Modal pemilik, 3200 Saldo laba |
| 4000 Pendapatan (Kredit) | 4100 Penjualan barang, 4200 Pendapatan jasa, 4900 Pendapatan lainnya |
| 5000 Beban (Debit) | 5100 Harga pokok penjualan, 5200 Beban gaji, 5300 Beban sewa, 5400 Beban utilitas, 5500 Beban transportasi, 5600 Beban administrasi bank, 5900 Beban lainnya |

Total **23 akun**: 5 kelompok dan 18 akun posting. Pendapatan/beban disediakan
bersama akun neraca agar pemasukan/pengeluaran kas kelak tidak disamakan dengan
laba-rugi. Pinjaman adalah liabilitas; setoran modal adalah ekuitas; persediaan
adalah aset. Tidak ada penghitungan atau pencatatan otomatis dari template ini.

Transaksi/ledger berikutnya dapat mereferensikan kode akun dan companyId pada
baris jurnal debit/kredit. Sebelum posting harus diperiksa lagi membership,
akun aktif/induk aktif, isPosting, nominal integer Rupiah, keseimbangan total
debit-kredit, approval, dan idempotensi. Semua aturan posting tersebut **belum
diimplementasikan**. Saldo normal hanya metadata pengelompokan, bukan pembatasan
bahwa akun hanya boleh menerima satu sisi jurnal.

## Inisialisasi yang aman

- Membuka halaman hanya membaca; tidak otomatis menulis akun default.
- Manager menekan **Siapkan kategori default**. Finance hanya dapat membaca dan
  melihat pesan untuk menghubungi Manager jika daftar kosong.
- Transaksi membaca profil, access link, perusahaan, membership server, dan
  seluruh kode default sebelum menulis akun yang belum ada.
- Akun yang sudah ada tidak diubah: nama, status nonaktif, UID pembuat, dan waktu
  pembuatan dipertahankan. Data dengan format/struktur bentrok menghentikan
  inisialisasi; tidak diganti atau dihapus secara diam-diam.
- Write dilakukan atomik. Tombol/controller menolak double submit. Transaksi
  Firestore dan ID kode deterministik membuat retry, timeout, serta dua perangkat
  yang melakukan inisialisasi bersamaan tetap idempoten.
- Snapshot cache/pending write tidak dianggap konfirmasi server. Loading memiliki
  batas tunggu, error izin/jaringan ditampilkan, dan tersedia retry. Gagal baca
  tidak ditampilkan seolah-olah daftar kosong. Log hanya berisi kode kegagalan.

## Security Rules — sudah di-deploy setelah persetujuan

`firestore.rules` ditambahkan match khusus `companies/{companyId}/chart_of_accounts`.
Manager dan Finance memerlukan profil lengkap, access link cocok, membership
aktif, dan perusahaan aktif untuk membaca. Create hanya Manager pada perusahaan
tersebut. Whitelist menolak saldo, field otorisasi, UID pembuat palsu, tipe/saldo
normal/kode tidak sesuai, timestamp client, dan kelompok yang dipakai posting.
`getAfter()` memvalidasi induk aktif dengan tipe sama, termasuk saat induk dan
anak dibuat dalam commit yang sama. Pola dua tingkat mencegah siklus induk.

Update dan delete akun ditolak untuk kedua role pada tahap ini. Rules tidak
menggunakan izin rekursif untuk collection keuangan. Semua aturan autentikasi,
profil, bootstrap perusahaan, dan undangan yang sudah ada dipertahankan;
transaksi/ledger tetap tertutup.

Implementasi awal tidak melakukan deployment. Pada tugas deployment terpisah,
pengguna menyetujui penerapan Rules COA. Diff diperiksa terhadap source production:
hanya match/validasi COA dan komentar penutup yang berubah; aturan profil,
perusahaan, membership, dan undangan tetap. Seluruh 23 tes Rules diulang dan lulus.
Source Rules tidak perlu diubah pada audit ini.

Perintah berikut berhasil (exit code 0), hanya men-deploy Firestore Rules:

```powershell
firebase deploy --only firestore:rules --project finova-8592e --non-interactive
```

Verifikasi baca-saja release `projects/finova-8592e/releases/cloud.firestore`:

- Ruleset: `a4c8e240-b601-452e-9a11-0fa7b400116e`.
- Update time: `2026-11-04T04:43:31.919886Z` (4 November 2026, 11.43 WIB).
- Source production sesuai file lokal dan source yang diaudit:
  `matchesLocal: true`, `matchesReviewed: true`.
- SHA-256 setelah normalisasi line ending/whitespace luar:
  `8111b40c031b96777809bbaa3d9e47607ce7cf83fd4ed1bc64496d4fd098952b`.

Tidak ada deployment layanan Firebase lain atau perubahan data pengguna/perusahaan
melalui Admin API. Source cocok bukan bukti pengujian UI/penyimpanan production.

## Pengujian dan batas verifikasi

```powershell
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
# Environment Java sementara untuk emulator Windows sesuai docs/manajemen_perusahaan.md
firebase emulators:exec --config firebase.emulators.json --project demo-finova-onboarding --only firestore "npm --prefix test/security_rules test"
```

Tes mencakup default/validasi/parsing, transaksi repository, preservasi akun lama,
retry jaringan, pembatasan Finance, scope perusahaan, cache/pending write,
pembatalan listener, UI daftar/filter/error, logout, navigasi menu dan layar 320dp.
Tes Rules memakai project demo lokal, menguji transaksi bersamaan, akses kedua
role, penolakan lintas perusahaan, schema/induk, dan collection ledger/transaksi
yang tetap tertutup. Hasil validasi final:

- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --concurrency=1 --reporter expanded`: **83 tes lulus**.
- Firebase Emulator Suite: **23 tes Rules lulus** (17 regresi perusahaan/profil/
  undangan dan 6 kasus Chart of Accounts, termasuk transaksi konkuren).
- `git diff --check`: bersih. Tidak ada dependensi baru sehingga pub get tidak
  diperlukan pada tahap ini.

Tes menemukan dan memverifikasi perbaikan pembatalan listener ketika stream
sedang diam, serta pembaruan halaman ketika role berubah dari Manager ke Finance.
Halaman mendengarkan konteks perusahaan dan membuat controller baru sesuai role,
sehingga tombol inisialisasi hilang tanpa menunggu logout. Rules dan pemeriksaan
repository tetap menjadi pembatas write yang sebenarnya.

Tes lokal tidak membuktikan pembacaan/penulisan Firebase production. UI native
Android dan penyimpanan production belum diuji; tidak ada build Android ulang.

## Verifikasi manual berikutnya

Rules sudah diterapkan setelah persetujuan. Untuk verifikasi aplikasi:

1. Hot restart kode terbaru, login Manager perusahaan, lalu Menu → Kategori Akun.
2. Daftar baru harus kosong tanpa write otomatis. Tekan Siapkan kategori default.
3. Periksa 23 dokumen di path perusahaan, lima kelompok, saldo normal dan induk.
4. Tekan lagi: jumlah tetap 23 dan metadata akun lama tidak berubah.
5. Filter Pendapatan/Beban; periksa kategori yang sesuai, lalu kembali ke Semua.
6. Login Finance perusahaan yang sama: akun terlihat, tombol inisialisasi tidak ada.
7. Login perusahaan lain: tidak ada akun perusahaan sebelumnya yang terlihat.
8. Ganggu koneksi saat membaca/menyimpan, lakukan retry, dan periksa tidak ada
   akun duplikat. Logout tidak boleh meninggalkan halaman kategori terlindungi.

Belum tersedia UI penambahan/edit/nonaktif/hapus akun, akun kontra, hierarki lebih
dari dua tingkat, saldo awal, transaksi, approval posting, jurnal, atau ledger.
Semua itu perlu aturan perubahan akun dan validasi referensi ketika mulai dibuat.

## File tahap ini

Baru: tujuh file `lib/features/chart_of_accounts/`, `test/chart_of_accounts_test.dart`,
`test/chart_of_accounts_repository_test.dart`,
`test/support/fake_chart_of_accounts_repository.dart`, dan dokumen ini.
Diubah: `lib/app/app.dart`, `lib/app/routes/app_router.dart`,
`lib/app/routes/app_destinations.dart`, `firestore.rules`,
`test/security_rules/company.rules.test.mjs`, `test/widget_test.dart`,
`test/support/fake_auth_repository.dart`, serta tautan pada dokumentasi perusahaan.
Branch tetap `feature/autentikasi`; perubahan lama dipertahankan tanpa commit,
push, merge, atau reset. Deployment hanya Firestore Rules dilakukan pada tugas
terpisah setelah persetujuan seperti catatan di atas.
