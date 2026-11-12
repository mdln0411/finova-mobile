# Lengkapi Profil Finova

Alur terbaru sesudah profil lengkap memerlukan onboarding/membership perusahaan
sebelum Dashboard. Implementasi profil pada dokumen ini tetap berlaku;
tujuan routing terbaru dijelaskan di `docs/manajemen_perusahaan.md`.

## Perilaku

Halaman `/complete-profile` memakai layout autentikasi Material 3 Finova.
Nama wajib (2–100 karakter setelah trim), email akun read-only, nomor telepon
opsional, dan foto Google ditampilkan jika tersedia. Tidak ada upload gambar.
Jika URL foto tidak tersedia atau gagal dimuat, ikon lokal dipakai.

Nomor telepon menerima 7–15 digit dengan awalan + opsional. Spasi, tanda kurung,
dan tanda hubung dibuang sebelum disimpan. Nomor kosong disimpan sebagai null.

Alur rute:

- Belum login → Login.
- Sesi/profil sedang diperiksa → halaman loading sesi yang sudah tersedia.
- Login dan profil belum lengkap → Lengkapi Profil, termasuk saat membuka deep link modul.
- Profil lengkap → Dashboard; membuka rute pengisian ulang dialihkan ke Dashboard.
- Logout atau sesi berakhir → Login.
- Gagal membaca profil → pemulihan sesi yang sudah tersedia.
- Gagal menyimpan → tetap di form dengan pesan, input dipertahankan, dapat retry/logout.

Nama dari registrasi/Google menjadi nilai awal yang dapat diperiksa pengguna.
Email selalu berasal dari sesi Firebase, bukan parameter yang bisa diedit pada form.
Foto memakai identitas Google yang tersedia atau URL foto profil tersimpan.

## Data dan kompatibilitas

Dokumen tetap tunggal pada `users/{uid}`, dengan tambahan:

| Field | Tipe | Nilai |
|---|---|---|
| profileCompleted | bool | false saat profil dasar dibuat, true sesudah Simpan berhasil |
| phoneNumber | string atau null | nomor yang dinormalisasi, opsional |

Dokumen lama yang belum memiliki status dianggap belum lengkap. Tidak ada migrasi
massal atau penulisan otomatis terhadap profil lama saat login. Pengguna melengkapi
sekali; login selanjutnya membaca true dari Firestore dan langsung ke Dashboard.
Status true hanya dipakai jika nama yang dibaca masih valid.

Penyimpanan memakai transaksi: baca UID yang sama, validasi UID, update hanya field
profil, pertahankan createdAt/UID, atau buat profil jika belum ada. updatedAt memakai
server timestamp. Tidak ada role, company ID, password, atau token yang ditambahkan.
Status kelengkapan hanya kebutuhan onboarding UI, **bukan hak akses perusahaan**.

Controller menunggu penyimpanan server berhasil sebelum membuka Dashboard, menolak
submit bersamaan, dan mengabaikan hasil simpan lama jika sesi berubah.

## File yang dibuat/diubah pada tahap ini

- `lib/features/auth/presentation/complete_profile_page.dart` (baru).
- `lib/features/auth/domain/auth_user.dart`, `auth_repository.dart`,
  `auth_validators.dart`, `auth_failure.dart`.
- `lib/features/auth/data/user_profile_service.dart`, `firebase_auth_repository.dart`.
- `lib/features/auth/application/auth_controller.dart`.
- `lib/app/routes/app_router.dart`.
- `firestore.rules`.
- `test/complete_profile_test.dart` (baru).
- `test/support/fake_auth_repository.dart`, `test/user_profile_service_test.dart`,
  `test/auth_controller_test.dart`, `test/auth_widget_test.dart`.
- Dokumen ini dan catatan di `docs/autentikasi.md`.

Tidak ada dependensi baru atau perubahan konfigurasi Firebase/Android.

## Security Rules — sudah di-deploy setelah persetujuan

Draft `firestore.rules` sekarang menerima dua field tambahan dengan validasi tipe,
format nomor telepon, dan nama ketika status lengkap. Legacy document tanpa kedua
field tetap didukung. Update tidak boleh mengubah UID/createdAt atau membatalkan
status lengkap. Whitelist field tetap menolak role/hak akses/token/password.
Get hanya untuk profil sendiri; list/delete dan collection lain tetap ditolak.

**Rules baru sudah di-deploy setelah persetujuan pengguna.** Release aktif
`projects/finova-8592e/releases/cloud.firestore` menunjuk ruleset
`13499473-a618-47bd-9751-171853ca9126`, diperbarui pada
`2026-11-03T14:42:19.013096Z`. Pemeriksaan baca-saja mengonfirmasi source aktif
persis sesuai file lokal setelah normalisasi line ending (`matchesLocal: true`).
Hanya Firestore Rules yang di-deploy; data profil dan layanan lainnya tidak diubah
oleh perintah deployment.

Deploy Rules **sebelum menjalankan client baru untuk pengujian manual**. Rules lama
akan menolak pembuatan/penyimpanan field baru; ini ditampilkan sebagai error izin,
bukan disembunyikan atau dibypass. Akun Auth yang sudah terbentuk tidak perlu
didaftarkan ulang setelah Rules diperbarui.

Perintah setelah disetujui:

```sh
firebase deploy --only firestore:rules --project finova-8592e
```

## Verifikasi

Hasil validasi tahap ini: `flutter analyze` tanpa temuan dan seluruh **52 tes**
lulus melalui `flutter test --concurrency=1 --reporter expanded`.
`git diff --check` juga bersih. Draft Rules diterima oleh validator Firebase
tanpa membuat release atau melakukan deployment.

Jalankan `flutter analyze` dan `flutter test --concurrency=1 --reporter expanded`.
Tes mencakup validasi nama/nomor, email read-only, simpan atomik, pemulihan dokumen
hilang, UID tidak sesuai, kegagalan simpan/retry, persistensi status setelah login
ulang, guard deep link, logout, respons layar sempit/keyboard, dan regresi autentikasi.

Validasi kompilasi draft Rules melalui endpoint Firebase `projects:test`
berhasil tanpa membuat release atau mengubah data production. Validasi ini bukan
bukti keberhasilan simpan profil ke Firestore production.

Build Android dan pengujian UI manual tidak dijalankan sesuai instruksi pengguna.
Setelah Rules disetujui dan terpasang, lakukan hot restart aplikasi dan uji:

1. Akun lama tanpa status masuk ke Lengkapi Profil dengan data awal.
2. Nama kosong ditolak, email tidak bisa diubah, telepon boleh kosong.
3. Simpan berhasil menuju Dashboard; UID/createdAt tetap dan tidak ada role baru.
4. Logout lalu login ulang tidak meminta pengisian kembali.
5. Akun baru dari register/Google harus melewati pengisian sekali.
6. Gangguan jaringan/izin saat Simpan tetap menyediakan retry dan logout.
