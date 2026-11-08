# Autentikasi Finova

Pembaruan onboarding perusahaan: profil lengkap sekarang dilanjutkan ke
**Buat atau Gabung Perusahaan**. Dashboard memerlukan membership aktif yang
diverifikasi server. Rules perusahaan sudah di-deploy pada 4 November 2026 setelah
persetujuan pengguna. Rincian implementasi, verifikasi source production,
pengujian, dan panduan manual ada di `docs/manajemen_perusahaan.md`.
Catatan Dashboard dummy dan deployment pada bagian historis di bawah bukan
perilaku client terbaru.

Tahap terbaru menambahkan alur **Lengkapi Profil** sebelum Dashboard untuk profil
yang belum memiliki `profileCompleted: true`. Rincian skema, migrasi profil lama,
pengujian, dan draft Rules yang memerlukan persetujuan deployment baru ada pada
`docs/lengkapi_profil.md`. Catatan deployment di bawah merujuk versi Rules sebelumnya.

Implementasi pada branch `feature/autentikasi`, untuk Android
`com.finova.finova` dan Firebase project `finova-8592e`.
Konfigurasi Firebase dan dependensi yang sudah ditambahkan pengguna dipertahankan.
Tidak ada project baru, role perusahaan, atau deployment otomatis.

Izin `android.permission.INTERNET` ditambahkan pada manifest utama karena
sebelumnya hanya tersedia pada manifest debug. Ini diperlukan agar Firebase
tetap dapat diakses dalam build release. Application ID tidak diubah.

## Arsitektur dan file

```text
lib/main.dart                              inisialisasi sebelum runApp
android/app/src/main/AndroidManifest.xml    izin internet untuk Firebase, termasuk release
lib/app/bootstrap.dart                     bootstrap Firebase, retry, kepemilikan controller
lib/app/app.dart                            menerima controller, lifecycle GoRouter
lib/app/routes/app_router.dart              guard seluruh rute dan rute autentikasi
lib/app/theme/app_theme.dart                tema input Material 3
lib/features/auth/
  domain/
    auth_user.dart                         identitas sesi dan profil tanpa token/role
    auth_failure.dart                      pesan kegagalan yang aman
    auth_repository.dart                   kontrak akses autentikasi/profil
    auth_validators.dart                   validasi formulir
  data/
    firebase_auth_service.dart              adapter Firebase Authentication
    google_sign_in_service.dart             adapter Google Sign-In 7.x
    user_profile_service.dart              transaksi Firestore users/{uid}
    firebase_auth_repository.dart           orkestrasi adapter dan pemetaan error
    auth_error_message.dart                pesan SDK ke bahasa pengguna
  application/auth_controller.dart          state sesi dan operasi asinkron
  presentation/
    auth_page.dart                         halaman Login/Register/Reset berdasarkan mode
    session_page.dart                      loading dan pemulihan sesi/profil
    widgets/auth_layout.dart               layout responsif dan pesan status
    widgets/password_field.dart            input password, visibility, autofill
lib/features/settings/presentation/settings_page.dart  profil dan logout
lib/features/dashboard/presentation/dashboard_page.dart sapaan dari profil
firestore.rules                            rancangan izin profil
firebase.json                              referensi rules, konfigurasi FlutterFire dipertahankan
test/auth_controller_test.dart             state, race, retry, logout
test/auth_validators_test.dart             validasi dan pesan error
test/auth_services_test.dart               kontrak Google 7.x dan privasi reset
test/auth_widget_test.dart                 formulir, routing, bootstrap, responsivitas
test/support/fake_auth_repository.dart     adapter pengujian lokal
test/widget_test.dart                      regresi fondasi dengan sesi uji
```

State memakai `ChangeNotifier` yang sudah tersedia di Flutter, tanpa dependensi
state management tambahan. Repository dapat diganti dengan fake pada tes;
aplikasi normal selalu memakai Firebase sesungguhnya.

## Bootstrap dan sesi

`main` menunggu Firebase menggunakan `DefaultFirebaseOptions.currentPlatform`.
Jika default app sudah tersedia, app tersebut digunakan kembali. Kegagalan
menampilkan halaman pemulihan dengan tombol retry, bukan menjalankan Dashboard.
Controller dibuat sesudah layanan siap; bootstrap memiliki dan membuang controller.

Sumber sesi adalah `FirebaseAuth.authStateChanges()` dan `currentUser` Firebase;
tidak ada flag login lokal atau penyimpanan token sendiri. Sesi SDK yang masih
valid dipulihkan ketika aplikasi dibuka kembali. Selama event awal atau profil
belum siap, pengguna berada pada `/session`. Semua rute aplikasi dilindungi.
Pengguna tanpa sesi diarahkan ke `/login`, dan pengguna dengan sesi siap yang
mengunjungi rute autentikasi diarahkan ke Beranda. Tombol kembali tidak membuka
Dashboard setelah logout. Deep link terlindungi tanpa sesi masuk ke Login,
kemudian ke Beranda setelah login, tanpa menyimpan tujuan awal.

Event sesi ganda tidak memicu sinkronisasi ulang; hasil sinkronisasi lama
diabaikan jika sesi berubah atau controller dibuang. Submit bersamaan ditolak.
Profil gagal disimpan membuat akun tetap login di Firebase, tetapi Dashboard
ditahan pada halaman pemulihan yang menyediakan retry atau logout. Jangan
membuat akun ulang ketika akun Auth sudah terbentuk namun Firestore menolak izin.

## Login, register, dan reset password

Login menggunakan `signInWithEmailAndPassword`. Email dipangkas dari spasi luar,
sedangkan password dikirim persis seperti yang dimasukkan. Pesan kredensial salah
tidak membedakan akun tidak ada dan password keliru. Error SDK mentah tidak
ditampilkan atau dicatat bersama kredensial.

Register memvalidasi nama 2–100 karakter, email, password 8–128 karakter yang
bukan hanya spasi, dan konfirmasi yang sama. Firebase dapat menerapkan kebijakan
password yang lebih ketat; penolakan server tetap ditangani. Setelah
`createUserWithEmailAndPassword`, nama diperbarui di Firebase Auth dan profil
disinkronkan ke Firestore. Pembuatan akun Auth dan dokumen Firestore bukan satu
operasi atomik lintas layanan. Kegagalan update nama dalam sesi yang sama dapat
dicoba ulang saat sinkronisasi; jika aplikasi ditutup sebelum update nama selesai,
pemulihan memakai nama yang tersedia di Auth atau nama pengganti.

Reset memakai `sendPasswordResetEmail`. Respons berhasil berbunyi “Jika email
tersebut terdaftar…” untuk semua alamat valid. Error akun tidak ditemukan atau
dinonaktifkan juga diberi respons netral. Kegagalan koneksi/rate limit tetap
ditampilkan agar pengguna dapat mencoba ulang. Aktifkan email enumeration
protection di project Firebase dan periksa template email reset serta domain
tautan di Console.

## Google Sign-In 7.2.0

Alur memakai `GoogleSignIn.instance`, `initialize()`, `supportsAuthenticate()`,
`authenticate()`, lalu `account.authentication.idToken`. ID token hanya digunakan
sementara untuk `GoogleAuthProvider.credential` dan
`FirebaseAuth.signInWithCredential`; tidak disimpan ke Firestore atau log.

Konfigurasi Android memakai web OAuth client (`client_type: 3`) yang sudah ada
pada `google-services.json`, tanpa client secret atau client ID hardcoded di Dart.
Pembatalan ditampilkan sebagai “Login Google dibatalkan”; kegagalan konfigurasi
dan jaringan ditangani dengan pesan aman. Tidak meminta akses Drive, Contacts,
atau scope bisnis tambahan.

Logout mengakhiri sesi Firebase terlebih dahulu, lalu membersihkan sesi Google
jika digunakan atau sudah diinisialisasi. Cleanup Google yang gagal tidak
mempertahankan sesi Firebase. Logout tidak mencabut persetujuan OAuth pada akun
Google dan tidak keluar dari akun Google perangkat.

Lihat [panduan paket Google Sign-In](https://pub.dev/packages/google_sign_in)
dan [konfigurasi Android](https://pub.dev/packages/google_sign_in_android).

## Profil Firestore

Dokumen tunggal `users/{uid}` memiliki:

| Field | Isi |
|---|---|
| uid | UID Firebase Authentication, sama dengan ID dokumen |
| displayName | Nama dasar, maksimal 100 karakter |
| email | Email dari Firebase Auth |
| photoUrl | URL HTTPS foto provider atau null |
| createdAt | Server timestamp saat dibuat, tidak berubah |
| updatedAt | Server timestamp saat profil dibuat; login ulang tidak mengubahnya |

Repository memakai transaksi Firestore untuk membaca dan membuat profil jika belum ada, tanpa
menulis ulang dokumen yang sudah ada berdasarkan UID. Login berulang memakai dokumen yang sama,
mempertahankan nama profil yang sudah ada dan `createdAt`. Password, access token,
refresh token, company ID, dan role tidak ditulis. Foto disimpan sebagai URL;
UI profil saat ini menggunakan ikon lokal.

Sinkronisasi memerlukan koneksi server; batas tunggu UI profil 20 detik.
Transaksi yang timeout mungkin selesai kemudian; retry tetap menggunakan UID
yang sama. Tidak menyediakan mode offline untuk melewati sinkronisasi profil.

## Security Rules dan penerapan

`firestore.rules` hanya mengizinkan pengguna terautentikasi melakukan
`get`, `create`, dan `update` pada profil sendiri. Listing collection dan delete
ditolak. UID dan `createdAt` tidak dapat diubah. Email harus sesuai klaim email
Auth. Timestamp penulisan harus memakai waktu server. Whitelist field menolak
role, company ID, token, password, dan field tambahan lain. Semua collection
lain ditolak pada tahap ini.

Aturan profil tidak memberikan izin perusahaan. Nama dan URL foto tetap data
masukan pengguna, sehingga jangan dipakai sebagai bukti kewenangan. Validasi
client hanya untuk UX; pembatasan akses bergantung pada Rules yang sudah terpasang.
Admin SDK melewati Rules dan harus dilindungi di lingkungan tepercaya.

**Rules belum dideploy otomatis.** Production mode bawaan biasanya menolak
penulisan profil, sehingga login dapat berhasil tetapi pengguna tertahan pada
halaman sinkronisasi sampai rules yang sesuai diterapkan.

Setelah meninjau file dan menyetujui deployment, pengguna dapat menjalankan:

```sh
firebase login
firebase deploy --only firestore:rules --project finova-8592e
```

Jalankan dari root repository. Perintah memakai referensi rules di `firebase.json`
dan secara eksplisit memilih project yang sudah ada. Review rules production
yang sudah terpasang sebelum deployment: file lokal ini menolak modul lain.
Tidak perlu menjalankan `firebase init` atau membuat project baru.

Referensi: [pembatasan field Firestore](https://firebase.google.com/docs/firestore/security/rules-fields).

## Konfigurasi Firebase yang perlu diverifikasi pengguna

1. Email/Password dan Google aktif di Authentication.
2. SHA-1 dan SHA-256 sertifikat debug/release yang dipakai terdaftar pada aplikasi
   Android `com.finova.finova`. Gunakan Gradle `signingReport` untuk memeriksanya.
3. Setelah mengubah konfigurasi OAuth/SHA, unduh ulang `google-services.json`
   jika Console meminta, kemudian build ulang aplikasi. Pastikan web OAuth
   client tetap tersedia dan konfigurasi OAuth consent/test user sesuai.
4. Review dan deploy Security Rules profil ke database `(default)`.
5. Periksa kebijakan password, email enumeration protection, template email
   reset, dan domain tautan reset di Console.

Repository hanya membuktikan keberadaan konfigurasi lokal. Status provider,
fingerprint server, Rules production, dan pengiriman email perlu diuji pada akun
Firebase pengguna; tidak diubah melalui implementasi ini.

## Pengujian otomatis

```sh
flutter pub get
flutter analyze
flutter test --concurrency=1 --reporter expanded
flutter build apk --debug
flutter run -d emulator-5554 --no-dds
```

Tes Dart/Flutter memakai fake repository dan tidak menghubungi Firebase production.
Cakupan meliputi validasi, login/register, pembatalan Google, reset netral,
guard rute, logout, race sinkronisasi, retry profil, bootstrap gagal, keyboard,
layar 320dp, skala teks besar, serta regresi dashboard/menu.

Pada lingkungan Windows sesi pengembangan, bila Gradle mengalami kegagalan
loopback Java, gunakan direktori socket sementara seperti catatan di
`docs/fondasi_aplikasi.md`; tidak perlu mengubah application ID atau
konfigurasi Android.

Pada mesin dengan memori terbatas, proses Gradle/Kotlin sempat mengalami
kehabisan memori dan kegagalan menutup incremental cache. Pengulangan build
dapat memakai argumen sementara berikut dari folder `android/`, setelah
`flutter pub get` dijalankan:

```powershell
.\gradlew.bat app:assembleDebug --no-daemon --max-workers=1 '-Dorg.gradle.jvmargs=-Xmx1536m' '-Pkotlin.compiler.execution.strategy=in-process' '-Pkotlin.incremental=false'
```

Jika juga mengalami kendala loopback, set properti direktori socket Java seperti
catatan fondasi terlebih dahulu. Tidak ada perubahan heap atau incremental build
yang ditulis permanen ke `android/gradle.properties`.

## Pengujian manual Firebase

Gunakan akun uji yang Anda kuasai. Terapkan rules terlebih dahulu agar profil
dapat disimpan. Jangan gunakan password produksi pada laporan atau screenshot.

1. **Register:** masukkan nama, email uji, password, dan konfirmasinya.
   Verifikasi akun muncul di Firebase Authentication dan tepat satu dokumen
   `users/{uid}` tercipta, tanpa role/password/token. Periksa timestamp server.
2. **Login:** keluar, lalu masuk dengan email/password tadi. Verifikasi Beranda,
   nama pengguna, Pengaturan, dan navigasi modul. Uji kredensial salah dan
   email tidak valid. Buka ulang aplikasi untuk menguji pemulihan sesi.
3. **Google:** pilih Continue with Google pada Android, selesaikan pemilihan akun
   sendiri, dan verifikasi sesi Firebase serta dokumen UID. Ulangi login dan
   pastikan `createdAt` tetap serta tidak ada dokumen duplikat. Uji pembatalan.
   Konflik provider tidak ditautkan secara otomatis oleh kode aplikasi.
4. **Reset:** gunakan email terdaftar dan email uji yang tidak terdaftar;
   pesan sukses harus sama. Periksa inbox/spam akun yang terdaftar,
   buka tautan dan uji login memakai password baru.
5. **Logout:** buka Pengaturan → Keluar dari akun. Pastikan kembali ke Login,
   tombol kembali tidak membuka Dashboard, dan buka ulang aplikasi tetap logout.
6. **Gangguan:** matikan jaringan ketika login/sinkronisasi. Uji retry tanpa
   mendaftar ulang. Rules yang menolak profil harus menampilkan pemulihan dan
   tetap menyediakan logout.
7. **Rules:** lewat Emulator Suite/Rules Playground, pastikan anonim dan pengguna
   lain ditolak, profil sendiri diizinkan, listing/delete ditolak, serta upaya
   menambahkan role, mengubah UID/createdAt, memalsukan email, atau menulis
   collection transaksi ditolak.

Jangan menandai alur provider, pengiriman email, atau penulisan Firestore
production berhasil hanya berdasarkan tes fake atau build Android.

## Batasan

Hasil validasi sesi implementasi awal, sebelum pemindahan cache Gradle:

- `flutter pub get`: berhasil.
- `flutter analyze`: tanpa temuan.
- `flutter test --concurrency=1 --reporter expanded`: seluruh 33 tes lulus.
- XML manifest utama dan `git diff --check`: valid.
- Emulator Android `emulator-5554` tersedia, tetapi APK autentikasi belum berhasil
  dibuat atau dijalankan di sana. Setelah kendala memori dan incremental cache
  dilewati, build berhenti pada `:app:mergeDebugNativeLibs` dengan
  `There is not enough space on the disk`; pemeriksaan menunjukkan `C:` tersisa
  0 byte. Cache Gradle berada pada drive tersebut. APK lama dari fondasi bukan
  hasil build autentikasi ini.
- Tidak ada tes terhadap akun Firebase production, pengiriman email nyata,
  pemilihan akun Google nyata, atau evaluasi Security Rules pada emulator/server.
  Rules belum dideploy.

Sediakan ruang pada `C:` atau atur lokasi cache Gradle pada drive yang cukup,
kemudian ulangi build dan pengujian Android. Tidak ada penghapusan file pengguna
atau pemindahan cache global otomatis untuk mengatasi keterbatasan penyimpanan.

### Validasi lanjutan dengan cache D:

Implementasi dan seluruh berkas autentikasi sebelumnya diperiksa dan tetap lengkap
di branch `feature/autentikasi`. Tidak ada implementasi ulang atau dependensi baru.

- `flutter analyze`: tanpa temuan.
- `flutter test --concurrency=1 --reporter expanded`: seluruh **33 tes lulus** kembali,
  termasuk formulir Login/Register/Reset, guard sesi, logout, dan regresi Dashboard.
- Cache pengguna `GRADLE_USER_HOME=D:\DevCache\Gradle` digunakan pada proses build.
  Terminal lama belum mewarisi variabel ini, sehingga nilai diterapkan pada proses
  validasi saja, tanpa perubahan konfigurasi Android permanen.
- Percobaan `flutter build apk --debug` terhalang lock `android/.gradle/noVersion/buildLogic.lock`
  dari daemon ekstensi VS Code. Build ulang memakai cache proyek sementara terpisah
  dan **berhasil** melalui `app:assembleDebug`.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, 169.051.783 byte.
  Metadata APK memuat application ID `com.finova.finova` dan launcher activity
  `com.finova.finova.MainActivity`.
- APK berhasil dipasang pada `emulator-5554`. Pemeriksaan UI manual belum dapat
  diselesaikan karena emulator menampilkan **System UI isn't responding** dan belum
  pulih setelah memilih Wait. Aplikasi praktik lain yang ada di launcher bukan
  bukti tampilan Finova; pengujian visual Login/Register/Forgot Password native
  tetap perlu diulang setelah emulator pulih atau dimulai ulang tanpa wipe data.
- Login Firebase nyata, penulisan profil production, Google account picker,
  pengiriman email reset, dan evaluasi Rules server tetap belum diverifikasi.
  Tidak ada deployment Rules, commit, push, merge, atau penghapusan perubahan.

Perintah build yang berhasil dari folder `android/` (semua opsi bersifat sementara):

```powershell
$env:GRADLE_USER_HOME = 'D:\DevCache\Gradle'
$env:JAVA_HOME = 'D:\tin\pemob\android studio\jbr'
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=D:\tin\pemob\finova-mobile\build\java_tmp'
.\gradlew.bat app:assembleDebug --no-daemon --project-cache-dir D:/tin/pemob/finova-mobile/build/gradle_auth_validation --max-workers=1 '-Dorg.gradle.jvmargs=-Xmx1536m' '-Pkotlin.compiler.execution.strategy=in-process' '-Pkotlin.incremental=false'
```

Setelah emulator pulih, jalankan APK yang sama dari root repository:

```powershell
flutter run -d emulator-5554 --no-dds --no-resident --use-application-binary build/app/outputs/flutter-apk/app-debug.apk
```

Pastikan aplikasi yang dibuka bernama Finova; ikon Flutter milik aplikasi praktik
lain pada launcher emulator mengarah ke paket berbeda.

Belum mencakup verifikasi email, MFA, linking provider manual, perubahan profil,
penghapusan akun, perusahaan, undangan, role, transaksi, approval, ledger, maupun
laporan. Dashboard tetap memakai data finansial dummy. Sesi akun yang
dinonaktifkan/dihapus secara administratif dapat bertahan di SDK sampai token
diperbarui atau operasi server menolaknya; Rules server tetap wajib menjadi
batas keamanan. Mode offline, App Check, rate limiting tambahan, dan audit
backend perlu dipertimbangkan saat fitur data perusahaan dimulai.


## Status Rules setelah persetujuan

Pada 3 November 2026 pukul 19.00 WIB, Firestore Rules telah berhasil di-deploy
ke `finova-8592e` setelah persetujuan pengguna. Release aktif diverifikasi lewat
API baca-saja; ruleset `7e90b3d2-ba16-4e15-9cee-0e7cf7494fa8` memuat aturan profil
lokal yang ditinjau. Pernyataan "belum dideploy" pada catatan validasi sebelumnya
merupakan keadaan sebelum persetujuan tersebut. Detail ada di `docs/investigasi_profil.md`.
Verifikasi akses production dari aplikasi masih menunggu pemulihan launcher emulator.
