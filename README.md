
# Finova — Financial Inovation

## 1. Nama Aplikasi

**Finova — Smarter Business Finance**

Finova merupakan aplikasi manajemen keuangan perusahaan berbasis mobile yang dirancang untuk membantu usaha kecil dan menengah (UKM) mengelola aktivitas keuangan secara praktis, terstruktur, dan efisien.

## 2. Deskripsi Singkat

Finova adalah aplikasi *Company Accounting* berbasis mobile yang memudahkan perusahaan dalam mencatat pemasukan dan pengeluaran, mengelola kas dan rekening bank, memantau utang serta piutang, dan menghasilkan laporan keuangan secara otomatis.

Aplikasi ini menyediakan sistem persetujuan (*approval*) transaksi, pencatatan buku besar (*ledger*) otomatis, serta dashboard interaktif untuk membantu pemilik usaha memahami kondisi keuangan perusahaan.

Finova dirancang dengan konsep **multi-company**, sehingga dapat digunakan oleh berbagai perusahaan dengan data keuangan dan pengguna yang terpisah. Aplikasi ini juga mendukung pengelolaan hak akses berdasarkan peran pengguna, seperti Manager, Finance, dan Staff.

## 3. Anggota Tim

| No. | Nama | NIM |
|---|---|---|
| 1 | Cindy Samosir | 241402009 |
| 2 | Dolly Efredi Bukit | 241402021 |
| 3 | Medeleine Rovita Anggraini Aritonang | 241402063 |
| 4 | Earlin Tasia Gulo | 241402089 |
| 5 | Chaterine Eklesia Maryati | 241402123 |

## 4. Rencana Fitur Aplikasi

### 1. Autentikasi dan Manajemen Perusahaan
Pengguna dapat melakukan registrasi, login, dan mengelola profil perusahaan. Aplikasi mendukung beberapa perusahaan dengan pemisahan data serta hak akses berdasarkan peran (Manager, Finance, dan Staff).

### 2. Dashboard Keuangan
Menampilkan ringkasan kondisi keuangan perusahaan, meliputi total saldo, pemasukan, pengeluaran, utang, piutang, dan grafik arus kas berdasarkan periode tertentu.

### 3. Manajemen Transaksi
Memungkinkan pengguna mencatat, melihat, dan mengelola transaksi pemasukan maupun pengeluaran. Setiap transaksi dapat dilengkapi kategori, akun keuangan, pusat biaya (*cost center*), serta foto bukti transaksi.

### 4. Persetujuan Transaksi (Approval)
Menyediakan mekanisme pengajuan dan persetujuan pengeluaran perusahaan. Staff dapat mengajukan transaksi, sedangkan Manager atau Finance yang berwenang dapat menyetujui maupun menolak pengajuan tersebut.

### 5. Manajemen Kas dan Bank
Mengelola berbagai sumber dana perusahaan, seperti kas tunai, rekening bank, dan e-wallet. Aplikasi mencatat perubahan saldo serta riwayat perpindahan dana antar-akun.

### 6. Manajemen Piutang (Accounts Receivable)
Mencatat tagihan atau invoice kepada pelanggan, memantau pembayaran yang belum diselesaikan, mengelola pembayaran sebagian maupun penuh, serta mencatat tanggal jatuh tempo.

### 7. Manajemen Utang (Accounts Payable)
Mencatat kewajiban pembayaran perusahaan kepada supplier atau vendor, termasuk nominal tagihan, tanggal jatuh tempo, status pembayaran, dan riwayat pelunasan.

### 8. Pencatatan Buku Besar Otomatis (Automatic Ledger)
Menghasilkan pencatatan akuntansi berupa debit dan kredit secara otomatis berdasarkan transaksi yang telah diproses, sehingga riwayat keuangan perusahaan tersusun secara sistematis.

### 9. Laporan Keuangan
Menyediakan laporan laba rugi (*Profit & Loss*) dan laporan arus kas (*Cash Flow*) berdasarkan periode tertentu. Laporan dapat ditampilkan melalui aplikasi dan diekspor dalam format PDF.

### 10. Notifikasi dan Pengingat
Memberikan pengingat terhadap tagihan utang atau piutang yang mendekati tanggal jatuh tempo serta pemberitahuan terkait status persetujuan transaksi.

## 5. Fitur Pengembangan Opsional

### AI Receipt Scanner
Memanfaatkan teknologi *Optical Character Recognition* (OCR) untuk mengekstraksi informasi dari foto struk, seperti tanggal transaksi, nominal, dan nama merchant, serta membantu mengklasifikasikan kategori transaksi secara otomatis.

## 6. Teknologi yang Direncanakan

| Komponen | Teknologi |
|---|---|
| Mobile Application | Flutter (Dart) |
| Backend | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth |
| File Storage | Supabase Storage |
| Version Control | Git & GitHub |

## 7. Batasan Pengembangan

Finova berfokus pada pengelolaan keuangan operasional perusahaan skala kecil dan menengah, bukan sistem ERP secara menyeluruh. Pengembangan tidak mencakup integrasi perbankan langsung, pembayaran otomatis, pengelolaan pajak yang kompleks, maupun sistem penggajian lengkap.
