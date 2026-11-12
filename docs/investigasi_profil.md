# Investigasi kegagalan profil Finova

## Diagnosis terverifikasi

Pada sesi investigasi 3 November 2026, aplikasi aktif di emulator adalah
`com.finova.finova/.MainActivity`. Halaman pemulihan profil sesuai pesan pengguna
terlihat pada emulator. Source pesan lama hanya dipilih untuk
`cloud_firestore / permission-denied`.

- Log Firebase Authentication menunjukkan pembuatan akun Email/Password berhasil
  dan event sesi terautentikasi terkirim. Kasus yang diamati bukan login Google.
- `firebase_options.dart`, konfigurasi Android, dan konfigurasi FlutterFire sama-sama
  menunjuk project `finova-8592e`.
- Akun CLI dapat mengakses project tersebut. Repository sebelumnya tidak memiliki
  project aktif; `.firebaserc` kini menunjuk default ke project yang benar.
  Alias CLI tidak menentukan project yang digunakan SDK aplikasi.
- Release production `projects/finova-8592e/releases/cloud.firestore` menunjuk
  ruleset `df9f23f4-ff3e-427e-88b5-ef208e88dc7e`, diperbarui
  `2026-11-03T06:13:03.840518Z`. Isinya masih menolak semua akses:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- Pemeriksaan administratif **baca-saja**, terbatas pada field UID dokumen
  `users/{uid}` untuk sesi aplikasi aktif, mengembalikan dokumen tidak ditemukan.
  UID, email, token, dan isi dokumen tidak dimasukkan ke laporan.
- Service selalu membaca `users/{FirebaseAuth.currentUser.uid}` dalam transaksi
  sebelum membuat profil. Rules deny-all menolak pembacaan ini, termasuk jika
  dokumennya belum ada. Akibatnya callback belum bisa melakukan pembuatan profil.

Jadi akun Auth sudah terbentuk, tetapi profil belum tercipta karena Rules aktif
belum mengizinkan akses profil. Tidak ada bukti salah project atau path UID pada
alur kode. Penolakan ini bukan bukti kegagalan jaringan dan tidak diperbaiki
dengan registrasi ulang, refresh token berulang, atau membuka seluruh database.

## Perbaikan kode

- `user_profile_service.dart`: dokumen yang belum ada dibuat secara atomik pada
  UID yang sama. Profil lama dibaca tanpa update atau perubahan `createdAt` dan
  `updatedAt`. UID tidak sesuai dan profil rusak tidak ditimpa diam-diam.
- `auth_failure.dart`: kegagalan sinkronisasi mempertahankan kode dan tahap
  `read` / `create`; pesan membedakan penolakan izin dari gangguan koneksi.
- `firebase_auth_repository.dart`: kegagalan profil bertipe dipertahankan.
- `auth_controller.dart`: retry bersamaan dibatasi; hasil sesi lama tetap diabaikan.
  Guard routing tidak dilonggarkan dan logout tetap tersedia.
- `.firebaserc`: alias default lokal ke `finova-8592e`.
- Tes baru: `test/user_profile_service_test.dart` dan tambahan tes controller.
  Tidak ada dependensi, role, perusahaan, atau konfigurasi Android baru.

## Draft Rules siap ditinjau

File `firestore.rules` sebelumnya sudah memenuhi pembatasan profil; tidak perlu
dilonggarkan. Whitelist field menolak role, company ID, password, dan token.
Profil hanya bisa dibaca pemiliknya. UID dan createdAt immutable. Email harus
cocok dengan klaim Auth dan penulisan timestamp memakai server time.
Collection lain tetap ditolak.

Aturan lengkap yang akan digunakan:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    function validProfile(uid) {
      let data = request.resource.data;
      return data.keys().hasAll([
          'uid', 'displayName', 'email', 'photoUrl', 'createdAt', 'updatedAt'
        ])
        && data.keys().hasOnly([
          'uid', 'displayName', 'email', 'photoUrl', 'createdAt', 'updatedAt'
        ])
        && data.uid is string && data.uid == uid
        && data.displayName is string
        && data.displayName.size() >= 1 && data.displayName.size() <= 100
        && data.email is string && data.email.size() <= 320
        && data.email == request.auth.token.email
        && (data.photoUrl == null || (
          data.photoUrl is string && data.photoUrl.size() <= 2048
          && data.photoUrl.matches('https://.*')
        ))
        && data.createdAt is timestamp
        && data.updatedAt is timestamp
        && data.updatedAt == request.time;
    }

    match /users/{uid} {
      // Profil sendiri dapat dibaca langsung; listing collection ditolak.
      allow get: if isOwner(uid);
      allow list: if false;
      allow create: if isOwner(uid) && validProfile(uid)
        && request.resource.data.createdAt == request.time;
      allow update: if isOwner(uid) && validProfile(uid)
        && request.resource.data.uid == resource.data.uid
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['displayName', 'email', 'photoUrl', 'updatedAt']);
      allow delete: if false;
    }

    // Modul perusahaan/keuangan belum memiliki izin pada tahap ini.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Pengujian dan batas verifikasi

- `flutter analyze`: tanpa temuan.
- `flutter test --concurrency=1 --reporter expanded`: 41 tes lulus.
- Tes service mencakup profil hilang, server timestamp tanpa role, login ulang
  tanpa write/duplikasi, penolakan baca, penolakan commit pembuatan, pemulihan,
  UID tidak sesuai, dan gangguan jaringan. Tes controller mencakup retry ganda.
- Endpoint Firebase Rules `projects/finova-8592e:test` menerima draft tanpa isu
  sintaks. Lima simulasi berhasil: owner get diizinkan; other-user get,
  anonymous get, list, dan delete ditolak. Simulasi tidak menulis data production
  atau menerapkan Rules. Create/update Rules belum diuji terhadap data production.
- Emulator aktif dan halaman error lama terkonfirmasi. Dashboard production
  **belum** berhasil diverifikasi karena deployment belum diizinkan.
- Build APK tidak diulang pada investigasi ini: perubahan hanya Dart, tes,
  dokumentasi, dan alias CLI. Tidak ada perubahan plugin atau Android native.
  Build tidak dapat memperbaiki Rules production yang menolak semua akses.

## Tindakan berikutnya — menunggu persetujuan

Deployment **belum dilakukan**. Setelah pengguna meninjau aturan lengkap di atas
  dan memberikan persetujuan, jalankan dari root repository:

```sh
firebase deploy --only firestore:rules --project finova-8592e
```

Ini mengganti Rules Firestore yang terpasang, bukan menghapus atau mengubah isi
profil pengguna. Semua collection selain profil tetap ditolak pada tahap ini.

Setelah release baru terverifikasi, lakukan hot restart untuk memuat perbaikan
Dart pada emulator, lalu tekan **Coba lagi**. Akun Auth tidak perlu dibuat ulang.
Profil yang belum ada akan dibuat pada UID yang sama; profil yang sudah ada
cukup dibaca. Kemudian verifikasi Dashboard dan tepat satu dokumen profil tanpa
role perusahaan. Jika masih gagal, periksa log `finova.auth` dengan kode dan
operasi tanpa mencatat UID, email, password, atau token.

Referensi API baca release:
https://firebase.google.com/docs/reference/rules/rest/v1/projects.releases/get

## Deployment setelah persetujuan pengguna

Pengguna menyetujui deployment. Perintah berikut berhasil (exit code 0):

```sh
firebase deploy --only firestore:rules --project finova-8592e --non-interactive
```

Release `projects/finova-8592e/releases/cloud.firestore` diperiksa kembali secara
baca-saja dan kini menunjuk ruleset
`7e90b3d2-ba16-4e15-9cee-0e7cf7494fa8`, update time
`2026-11-03T12:00:37.655467Z` (3 November 2026, 19.00 WIB).
Source aktif sesuai `firestore.rules` yang disetujui: profil sendiri dibatasi,
field hak akses ditolak, dan collection lainnya tetap tertutup.

Verifikasi Dashboard dan pembuatan profil dari aplikasi **belum selesai** pada
sesi deployment ini karena emulator menampilkan `Pixel Launcher isn't responding`.
Deployment Rules yang berhasil bukan bukti bahwa aplikasi sudah masuk Dashboard.
Setelah emulator pulih, buka **Finova**, lakukan hot restart bila memuat kode baru,
lalu tekan **Coba lagi**. Tidak perlu mendaftar ulang. Jika launcher tetap macet,
mulai ulang emulator tanpa wipe data. Tidak ada commit, push, merge, deployment
layanan lain, atau perubahan data profil melalui Admin API pada sesi ini.
