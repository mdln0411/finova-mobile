# Onboarding dan manajemen perusahaan Finova

Tahap berikutnya menambahkan [Kategori Akun](kategori_akun.md) per perusahaan.
Rules Chart of Accounts sudah di-deploy setelah persetujuan pengguna pada
4 November 2026; metadata verifikasi ada pada dokumen Kategori Akun. Catatan
deployment di bawah merujuk Rules perusahaan sebelum COA.

## Audit awal

Branch tetap `feature/autentikasi`; seluruh perubahan autentikasi yang belum
di-commit dipertahankan. Firebase Auth, Google Sign-In, profil transaksional
`users/{uid}`, status `profileCompleted`, dan guard GoRouter sudah tersedia.
Belum ada perusahaan/membership. Guard lama menganggap profil lengkap cukup untuk
Dashboard, yang masih memakai fixture keuangan. Tidak ditemukan alasan untuk
mengubah project Firebase, Android application ID, atau struktur profil.

Autentikasi dan penyelesaian profil tetap menggunakan repository/controller lama.
Status perusahaan dikelola terpisah oleh `CompanyController` yang mengamati sesi
Auth dan membuang konteks perusahaan ketika sesi berubah. Hasil asinkron dari sesi
lama diabaikan. `FinovaApp` memiliki lifecycle controller perusahaan dan router.

## Struktur dan penyimpanan

```text
lib/features/company/
  domain/company.dart                       model, role, draft, validator, failure
  domain/company_repository.dart            kontrak yang dapat di-fake
  data/firebase_company_repository.dart      transaksi dan listener Firestore
  application/company_controller.dart       state onboarding dan operasi
  presentation/company_onboarding_page.dart  pilihan buat/gabung, loading/retry
  presentation/company_form_page.dart        form perusahaan dan logo
  presentation/company_invitations_page.dart daftar dan pengelolaan undangan

users/{uid}                                 profil lama, tidak diubah skemanya
companies/{creatorUid}                       perusahaan (ID deterministik)
companies/{companyId}/members/{uid}          membership aktif
company_access/{uid}                         referensi tunggal perusahaan akun
company_invitations/{id}                     undangan Finance
```

Perusahaan menyimpan `name`, `businessType`, `bookkeepingStartDate` (Timestamp
tanggal UTC), `address`, `phoneNumber`, `email`, `logoUrl` (HTTPS/null),
`currency: IDR`, `createdBy`, `status: active`, `createdAt`, `updatedAt`.
Timestamp pembuatan/perubahan memakai server time. Telepon dinormalisasi.

Membership menyimpan `uid`, `role: manager|finance`, `status: active`, `joinedAt`.
Finance juga menyimpan `invitationId`. Role tidak disimpan pada profil pribadi
dan tidak dapat dipilih dari formulir. Access link menyimpan `uid`, `companyId`,
`createdAt`; client tidak dapat memperbarui/menghapus atau memindahkan link.

Undangan menyimpan `companyId`, `companyName`, `email` lowercase, `role: finance`,
`status: pending|accepted|rejected|cancelled`, `createdBy`, `createdAt`,
`updatedAt`, `acceptedBy` (null sebelum diterima). ID undangan deterministik dari
perusahaan dan email (URI encoded), sehingga retry tidak menggandakan undangan.
Tidak ada token/secret invitation atau email undangan otomatis.

## Alur onboarding

1. Tanpa sesi → Login; sesi/profil belum siap → pemulihan sesi.
2. Profil belum lengkap → Lengkapi Profil, termasuk deep link modul.
3. Profil lengkap → pemeriksaan access link dan membership server.
4. Tanpa link → pilihan Buat atau Gabung Perusahaan. Dashboard dan semua modul
   terlindungi sampai membership aktif; route undangan Manager juga terlindungi.
5. Company/member harus valid dan aktif → Dashboard dengan nama perusahaan/role.
6. Gagal baca/format/izin → pemulihan perusahaan (retry/logout); bukan dianggap
   otomatis belum punya perusahaan. Snapshot cache/pending write tidak membuka
   Dashboard sebelum konfirmasi server. Listener mengamati membership/perusahaan.
7. Logout membersihkan konteks; login berikutnya membaca membership kembali.

Form perusahaan memerlukan nama 2–100 karakter, jenis usaha dari empat pilihan,
dan tanggal 1900–2100. Alamat/email/telepon/logo opsional. Tombol menyimpan memiliki
loading dan guard double submit. Gagal simpan mempertahankan input.

Logo saat ini dimasukkan sebagai **URL gambar HTTPS**, dengan tombol pratinjau
dan fallback ikon. Tidak ada pemilih file, upload, dependensi gambar, atau Firebase
Storage. Upload file memerlukan rancangan Storage Rules dan lifecycle file terpisah.
URL eksternal harus tetap dapat diakses; pemuatan gambar menggunakan jaringan.

## Bootstrap Manager yang atomik

Satu transaksi membaca profil lengkap dan access link sendiri, lalu membuat
perusahaan dengan ID UID pembuat, member Manager pertama, dan access link.
Jika link sudah ada, retry memakai perusahaan yang sudah terhubung. ID tetap
serta link immutable mencegah perusahaan ganda akibat double submit, retry setelah
timeout, dan balapan antarperangkat. Tidak ada partial write bila commit ditolak.

Rules mengharuskan profil lengkap, tidak ada link sebelumnya, perusahaan benar-
benar baru, `createdBy == auth.uid`, dan ID perusahaan == UID pembuat. `getAfter()`
memastikan seluruh dokumen pasangan tercipta bersama. Menulis member Manager di
perusahaan lama ditolak, termasuk oleh Finance atau calon pengguna baru.

## Undangan Finance

Manager membuka Pengaturan → Undang tim Finance, memasukkan email, dan melihat
undangan pending. Manager hanya dapat membuat undangan perusahaan sendiri, role
selalu Finance, dan membatalkan undangan pending. Pengguna baru membuka Gabung
Perusahaan untuk memuat undangan bagi email akun sendiri.

Email penerima wajib terverifikasi pada Firebase Authentication. Halaman menyediakan
kirim tautan verifikasi dan muat ulang. Repository melakukan reload user dan
refresh ID token; Rules memeriksa `email_verified` dan klaim email, bukan email
form/profil yang bisa ditulis sendiri. Google biasanya sudah memiliki email
terverifikasi, tetapi keputusan tetap berdasarkan klaim server.

Menerima undangan menggunakan transaksi: pending → accepted, member Finance, dan
access link ditulis bersama. Rules menghubungkan `invitationId`, UID penerima,
email terverifikasi, companyId, dan status sebelum/sesudah commit. Penerimaan
parsial, role Manager, pengguna lain, undangan dibatalkan/dipakai ulang, dan akun
yang sudah punya perusahaan ditolak. Menolak undangan tidak membuat membership.

## Batas keamanan dan deployment

Profil tetap owner-only. Company hanya dapat dibaca anggota aktif dengan access
link yang cocok. Listing seluruh perusahaan ditolak. Field data menggunakan
whitelist. Company/member/access link tidak dapat diubah atau dihapus client
pada tahap ini. Undangan hanya dapat diubah pada field status, updatedAt, dan
acceptedBy dengan transisi yang diizinkan. Collection keuangan tetap ditolak.

`firestore.rules` perusahaan **sudah di-deploy pada 4 November 2026 setelah
persetujuan eksplisit pengguna**, setelah audit diff terhadap production dan
17 tes Security Rules lulus di emulator lokal. Source Rules tidak perlu diubah
pada audit deployment ini. Konfigurasi aplikasi tetap `finova-8592e`;
file `firebase.json` dan Firebase options production tidak diganti.
Perintah yang berhasil (exit code 0):

```powershell
firebase deploy --only firestore:rules --project finova-8592e --non-interactive
```

Audit baca-saja sebelum deployment mengonfirmasi Rules sebelumnya adalah ruleset
`13499473-a618-47bd-9751-171853ca9126`, yang hanya mengizinkan profil sendiri.
Seluruh aturan profil tersebut dipertahankan. Audit tambahan menguji whitelist
member/access link, penolakan Finance tanpa undangan, field undangan immutable,
dan akses Manager lintas perusahaan. Tidak ditemukan akses luas seluruh database
atau jalur self-assignment role di luar bootstrap perusahaan baru sendiri.

Verifikasi baca-saja setelah deployment pada release
`projects/finova-8592e/releases/cloud.firestore`:

- Ruleset: `9430cd86-9fca-4d30-a0d2-8b7ed7777911`.
- Update time: `2026-11-04T03:58:35.644360Z` (4 November 2026, 10.58 WIB).
- `matchesLocal: true`, `matchesReviewed: true`.
- SHA-256 source lokal/production (normalisasi CRLF/LF dan whitespace luar):
  `867d0814a1c675152d93b941749c00926416d23e861e0fad27ed9eb024ff792f`.

Hanya Firestore Rules yang di-deploy. Tidak ada deployment index, Functions,
Storage, Hosting, atau perubahan data pengguna/perusahaan melalui Admin API.
Hasil ini membuktikan source Rules production sesuai source yang diuji,
**bukan** bukti bahwa pengujian UI Android atau transaksi production sudah lulus.

Rancangan memakai transaksi/Rules Firestore; tidak menambah Cloud Functions,
Storage, atau mengaktifkan paket berbayar. Operasi nyata tetap memakai kuota
baca/tulis Firestore project. Data keuangan berikutnya harus ditempatkan di
`companies/{companyId}/...` dengan Rules khusus; tidak ada izin generik untuknya.

## Pengujian

Tes Flutter menggunakan fake repository dan test doubles SDK; bukan bukti akses
production. Tes Rules menggunakan Firebase Emulator Suite dan project demo lokal.
Dependensi JavaScript khusus pengujian berada di `test/security_rules`, terpisah
dari dependensi Flutter. `firebase.emulators.json` hanya konfigurasi emulator;
tidak mengubah koneksi SDK aplikasi ke production.

```powershell
flutter analyze
flutter test --concurrency=1 --reporter expanded
npm --prefix test/security_rules ci
# Gunakan Java 21+ yang tersedia, misalnya JBR Android Studio.
firebase emulators:exec --config firebase.emulators.json --project demo-finova-onboarding --only firestore "npm --prefix test/security_rules test"
```

Pengujian Security Rules lokal terbaru: **17 tes lulus**, termasuk operasi valid bootstrap
dan undangan, query sesuai email/perusahaan, penolakan partial write, penyisipan
field, akses perusahaan lain, self-assignment Manager, perubahan role Finance,
email belum diverifikasi/salah, undangan cancelled/rejected/reused.
Pesan `PERMISSION_DENIED` pada kasus negatif merupakan hasil yang diharapkan.

Pada Windows sesi ini, emulator awalnya gagal karena `Unable to establish
loopback connection`. Pengujian berhasil setelah mengatur Java hanya untuk proses
tes, tanpa perubahan Android permanen:

```powershell
$env:JAVA_HOME = 'D:\tin\pemob\android studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
New-Item -ItemType Directory -Path build/java_tmp -Force | Out-Null
$env:JAVA_TOOL_OPTIONS = '-Xmx768m -XX:ActiveProcessorCount=2 -Djdk.net.unixdomain.tmpdir=D:\tin\pemob\finova-mobile\build\java_tmp'
```

Tes Rules menggunakan library `@firebase/rules-unit-testing` dan Firebase JS SDK
sebagai dev dependencies, dengan package lock. Tidak ada dependensi Flutter baru.
Tidak ada build Android atau pengujian write Firebase production pada tahap ini.
Hasil validasi final: `flutter analyze --no-pub` **No issues found**;
`flutter test --no-pub --concurrency=1 --reporter expanded` **67 tes lulus**.
SDK/dependensi Flutter tidak berubah sehingga tidak perlu pub get ulang.
Emulator Android `emulator-5554` terdeteksi aktif, tetapi UI Android terbaru dan
alur Firestore production belum diuji pada sesi implementasi/deployment ini.
Rules perusahaan sudah diterapkan seperti catatan di atas. Tidak ada build Android berulang. `git diff --check`
bersih, branch tetap `feature/autentikasi`, dan tidak ada file tracked yang dihapus.

## File perubahan tahap ini

Baru: tujuh file pada `lib/features/company/` yang dicantumkan di atas,
`test/company_test.dart`, `test/company_repository_test.dart`,
`test/support/fake_company_repository.dart`,
`test/security_rules/company.rules.test.mjs`, `package.json`, `package-lock.json`,
`firebase.emulators.json`, dan dokumen ini.

Diubah: `lib/app/app.dart`, `lib/app/routes/app_router.dart`,
`lib/features/dashboard/presentation/dashboard_page.dart`,
`lib/features/dashboard/presentation/widgets/summary_card.dart`,
`lib/features/settings/presentation/settings_page.dart`, `firestore.rules`,
`test/support/fake_auth_repository.dart`, `test/auth_widget_test.dart`,
`test/complete_profile_test.dart`, `test/widget_test.dart`, `analysis_options.yaml`
(kecualikan dependensi JavaScript dari Dart analyzer), `.gitignore`
(dependensi/log emulator), `docs/autentikasi.md`, dan `docs/lengkapi_profil.md`.
Perubahan Android/Firebase Auth/dependensi Flutter dari tahap sebelumnya
dipertahankan. Tidak ada commit, branch baru, push, merge, atau reset.
Deployment terbatas pada Firestore Rules setelah persetujuan.

## Verifikasi manual dan keterbatasan

Rules sudah diterapkan. Hot restart aplikasi dari kode terbaru (tombol `R` pada
terminal Flutter yang masih tersambung), atau jalankan `flutter run --no-dds`
dari root repository. Jangan menggunakan APK lama dari sebelum fitur perusahaan.

1. Registrasi/login Google/email; profil belum lengkap tetap harus diselesaikan.
2. Selesai profil masuk pilihan perusahaan, bukan Dashboard. Deep link laporan
   tidak boleh melewati tahap ini. Logout harus selalu kembali ke Login.
3. Buat perusahaan, coba nama/email/telepon invalid, tanggal, dan URL logo. Uji
   keyboard, tombol kembali, loading, serta double tap. Periksa tiga dokumen
   Firestore tercipta bersama dan hanya satu perusahaan setelah retry.
4. Verifikasi nama perusahaan, role Manager, logo/fallback dan empty state
   Dashboard. Logout/login ulang harus memakai perusahaan yang sama.
5. Manager undang email akun kedua. Akun kedua menyelesaikan profil, verifikasi
   email jika diminta, muat undangan lalu terima sebagai Finance. Uji penolakan,
   pembatalan, akun email salah, dan login ulang. Finance tidak memiliki menu
   pengelolaan undangan atau pilihan role.
6. Matikan jaringan saat menyimpan/memuat; uji retry dan periksa tidak ada duplikasi.
   Uji akses lintas perusahaan lewat Emulator Suite, bukan melonggarkan Rules.

Gunakan akun B yang belum memiliki perusahaan untuk penerimaan undangan pertama.
Jangan memilih Buat Perusahaan pada akun B; pilih Gabung Perusahaan. Akun A dan B
dapat diuji bergantian pada emulator Android yang sama melalui Logout/Login.
Tidak ada email undangan otomatis; daftar undangan dibuka dari dalam aplikasi.
Email verifikasi Firebase Authentication berbeda dari email undangan.
Untuk menguji pembatalan atau penolakan, gunakan email akun uji tambahan karena
pengundangan ulang email yang undangannya sudah diproses belum tersedia.

Belum tersedia penggantian perusahaan, multi-company switcher, pengelolaan role,
penghapusan/perubahan membership, edit perusahaan, expiry undangan, pengundangan
ulang email yang undangannya sudah diproses, atau email undangan otomatis. Operasi
administratif memerlukan rancangan otorisasi tersendiri. Form logo belum upload
file. Transaksi/laporan tetap placeholder; Dashboard menampilkan tanda — dan
empty state, bukan nominal dummy atau klaim saldo nol.

Referensi desain keamanan:
[kondisi Rules dan getAfter](https://firebase.google.com/docs/firestore/security/rules-conditions),
[transaksi atomik](https://firebase.google.com/docs/firestore/manage-data/transactions),
[pengujian Rules](https://firebase.google.com/docs/rules/unit-tests).
