PRD — Valtera Note Android
Versi: 1.0
Status: Draft implementasi
Platform: Android
Framework: Flutter
Backend: Supabase milik pengguna
Frontend web existing: valtera-note

1. Ringkasan Produk
Valtera Note adalah aplikasi catatan Android yang ringan, cepat, dan sederhana seperti Xiaomi Notes atau Google Notes.

Aplikasi ini menjadi frontend mobile dari project web valtera-note. Pengguna memasukkan:

Supabase Project URL
Supabase Anon/Public Key
Setelah konfigurasi berhasil, pengguna dapat login atau mendaftar ke Supabase project miliknya sendiri.

Data catatan dari Android dan website harus dapat digunakan secara bersama-sama dan tersinkronisasi.

Batasan penting
Jangan pernah menggunakan Supabase Service Role Key di aplikasi.
Jangan mengasumsikan nama tabel atau kolom sebelum project web diaudit.
Semua akses data harus mengikuti schema dan RLS dari project existing.
Aplikasi tidak menggunakan backend pusat Valtera untuk menyimpan catatan pengguna.
2. Tujuan Produk
Tujuan utama
Menyediakan aplikasi catatan Android yang ringan.
Menyediakan frontend mobile untuk project web Valtera Note.
Mendukung autentikasi Supabase.
Mendukung CRUD catatan.
Mendukung pencarian catatan.
Mendukung cache lokal dan penggunaan offline.
Menyinkronkan perubahan Android dan web.
Menyimpan data pada Supabase project milik pengguna.
Di luar scope MVP
Fitur berikut tidak dibuat pada versi awal:

Kolaborasi multi-user.
Chat.
Kalender kompleks.
Task management kompleks.
Attachment gambar atau file.
Rich text editor kompleks.
Integrasi Google Drive.
Multi-project aktif secara bersamaan.
Aplikasi iOS.
Backend proxy milik Valtera.
Notifikasi reminder kompleks.
3. Target Pengguna
3.1 Pengguna personal
Pengguna yang ingin memiliki catatan pribadi yang:

Cepat dibuka.
Bisa digunakan offline.
Bisa diakses dari Android dan web.
Datanya tersimpan di Supabase milik sendiri.
3.2 Developer atau pemilik project Supabase
Pengguna yang ingin memakai Valtera Note sebagai frontend siap pakai untuk database Supabase miliknya.

4. Prinsip Produk
Simple by default
Pengguna dapat membuka dan membuat catatan dengan langkah minimal.

Fast first
Aplikasi menampilkan cache lokal terlebih dahulu jika tersedia.

Offline-friendly
Catatan tetap dapat dibaca dan dibuat tanpa koneksi.

Supabase-native
Gunakan Supabase Auth, Database, dan Realtime hanya jika dibutuhkan.

Secure
Hanya anon/public key yang boleh digunakan pada aplikasi.

Contract-first
Struktur data harus mengikuti project web yang sudah ada.

Low visual noise
Tidak menggunakan dashboard atau animasi yang berlebihan.

5. User Journey
5.1 Setup pertama kali
Pengguna membuka aplikasi.
Aplikasi menampilkan halaman konfigurasi Supabase.
Pengguna mengisi Project URL.
Pengguna mengisi Anon Key.
Pengguna menekan Test Connection.
Aplikasi memvalidasi koneksi.
Jika berhasil, konfigurasi disimpan secara aman.
Pengguna diarahkan ke halaman login.
5.2 Login
Pengguna memasukkan email.
Pengguna memasukkan password.
Aplikasi melakukan login ke Supabase Auth.
Session disimpan.
Pengguna masuk ke daftar catatan.
5.3 Registrasi
Pengguna memilih Daftar.
Pengguna mengisi email.
Pengguna mengisi password.
Pengguna mengonfirmasi password.
Aplikasi membuat akun Supabase.
Jika email verification aktif, aplikasi menampilkan instruksi verifikasi.
Jika berhasil, pengguna masuk ke aplikasi.
5.4 Membuat catatan
Pengguna menekan tombol tambah.
Pengguna mengisi judul dan isi.
Catatan disimpan ke cache lokal.
Aplikasi mengirim perubahan ke Supabase.
Status berubah menjadi Synced.
5.5 Penggunaan offline
Pengguna membuka aplikasi tanpa internet.
Aplikasi menampilkan cache terakhir.
Pengguna membuat atau mengedit catatan.
Perubahan masuk ke queue lokal.
Ketika koneksi kembali, perubahan dikirim otomatis.
6. Fitur MVP
6.1 Supabase Setup
Field
supabaseUrl
supabaseAnonKey
Validasi
Field tidak boleh kosong.
URL wajib menggunakan HTTPS.
URL harus memiliki format valid.
Anon key wajib tersedia.
Service role key tidak boleh digunakan.
Connection test harus berhasil sebelum melanjutkan.
Aksi
Test Connection.
Simpan konfigurasi.
Ubah konfigurasi.
Disconnect project.
Error message
Contoh:

“Supabase URL wajib diisi.”
“Anon key wajib diisi.”
“Format URL Supabase tidak valid.”
“Project Supabase tidak dapat dihubungi.”
“Kredensial tidak dapat digunakan.”
“Pastikan RLS dan Auth project sudah dikonfigurasi.”
6.2 Authentication
Fitur
Login email/password.
Registrasi email/password.
Konfirmasi password.
Logout.
Session persistence.
Session refresh.
Forgot password.
Email verification bila aktif.
Session expired handling.
Acceptance criteria
Session tetap aktif setelah aplikasi ditutup.
Session invalid mengarahkan pengguna ke login.
Logout menghapus session.
Password tidak disimpan secara plain text.
Error login dan register ditampilkan secara jelas.
6.3 Daftar Catatan
Informasi pada item catatan
Judul.
Cuplikan isi.
Waktu terakhir diperbarui.
Status pin jika tersedia.
Status archive jika tersedia.
Status sinkronisasi.
Aksi
Tap untuk membuka.
Pull-to-refresh.
Search.
Tambah catatan.
Pin/archive jika tersedia.
Hapus catatan.
Sorting default
Catatan pinned terlebih dahulu jika fitur tersedia.
Catatan terbaru berdasarkan updated_at.
State wajib
Loading.
Loaded.
Empty.
Offline.
Error.
Retry.
6.4 Editor Catatan
Field
Judul.
Isi.
Aksi
Save.
Delete.
Back.
Pin jika tersedia.
Archive jika tersedia.
Behavior
Catatan baru dibuat saat judul atau isi tidak kosong.
Catatan disimpan lokal sebelum dikirim ke server.
Auto-save boleh digunakan dengan debounce.
Tombol back tidak boleh membuang perubahan tanpa konfirmasi.
Jika save gagal, draft lokal harus tetap dipertahankan.
6.5 Pencarian
Behavior
Pencarian berdasarkan judul.
Pencarian berdasarkan isi.
Debounce input.
Tombol clear.
Empty state khusus hasil pencarian.
Pencarian lokal dari cache.
Pencarian server jika dataset terlalu besar.
6.6 Sinkronisasi
Status sinkronisasi

Pemicu sinkronisasi
Setelah login.
Saat aplikasi dibuka.
Saat aplikasi kembali dari background.
Saat koneksi kembali.
Pull-to-refresh.
Setelah catatan dibuat.
Setelah catatan diubah.
Setelah catatan dihapus.
Aturan
Jangan melakukan request berulang tanpa alasan.
Simpan perubahan gagal di queue.
Jangan menghapus data lokal ketika sync gagal.
Tampilkan status sync kepada pengguna.
Sediakan retry.
Konflik tidak boleh ditimpa diam-diam.
7. Audit Project Existing
Sebelum implementasi Flutter, AI wajib melakukan audit pada:

Project valtera-note

Audit harus mencakup:

Framework frontend.
Entry point aplikasi.
Inisialisasi Supabase.
Supabase URL yang digunakan.
Auth flow.
Nama tabel notes.
Nama kolom notes.
Tipe data setiap kolom.
Query list notes.
Query detail notes.
Query create notes.
Query update notes.
Query delete notes.
Sorting.
Pagination.
Soft delete.
Archive.
Pin.
Realtime.
RLS policy.
Format tanggal.
Format isi catatan.
State loading dan error.
Perilaku ketika session expired.
Output audit
Buat dokumentasi:


Flutter tidak boleh membuat model final sebelum audit ini selesai.

8. Kontrak Data
Model berikut hanya contoh dan harus disesuaikan dengan schema sebenarnya:

Field	Tipe	Keterangan
id	UUID	ID catatan
user_id	UUID	Pemilik catatan
title	String	Judul
content	String	Isi
is_pinned	Boolean	Status pin
is_archived	Boolean	Status arsip
is_deleted	Boolean	Soft delete
created_at	DateTime	Waktu dibuat
updated_at	DateTime	Waktu diperbarui
Aturan data
user_id harus berasal dari session Auth.
Jangan mempercayai user_id dari input UI.
Query harus mengikuti policy RLS.
updated_at digunakan untuk sorting dan deteksi perubahan.
Penghapusan harus mengikuti behavior existing: hard delete atau soft delete.
9. Arsitektur Flutter

Dependency flow

Aturan arsitektur
Widget tidak boleh menjalankan query Supabase.
Query Supabase hanya boleh berada di data source.
Repository bertanggung jawab terhadap sumber data.
Entity domain tidak boleh bergantung pada package Supabase.
Semua error harus dipetakan ke error type yang jelas.
Gunakan dependency injection.
Gunakan null safety.
10. Rekomendasi Teknologi
Gunakan dependency yang sudah tersedia jika ada. Jika belum ada standar proyek, pertimbangkan:

supabase_flutter
flutter_secure_storage
Riverpod atau state management yang konsisten
Drift atau Isar untuk local database
connectivity_plus
go_router untuk routing
Aturan dependency
Jangan menambahkan package yang tumpang tindih.
Jangan menggunakan banyak local database.
Jangan menambahkan package hanya karena populer.
Setiap dependency harus memiliki alasan.
Setelah menambah dependency, jalankan formatter, analyzer, dan test.
11. Local Storage
Secure storage
Simpan:

Supabase URL.
Supabase Anon Key.
Project identifier jika diperlukan.
Jangan simpan:

Password.
Service role key.
Access token secara manual jika Supabase SDK sudah menangani session.
Local database
Simpan:

Cache catatan.
Last sync timestamp.
Queue perubahan.
Status sinkronisasi.
Error terakhir.
Versi data lokal.
Queue perubahan
Minimal field:

Field	Keterangan
id	ID queue
operation	create/update/delete
entityId	ID catatan
payload	Isi perubahan
createdAt	Waktu dibuat
attemptCount	Jumlah percobaan
lastError	Error terakhir
status	pending/processing/failed
12. Konflik Data
MVP menggunakan:

Optimistic update.
Server timestamp.
updated_at atau version field jika tersedia.
Jika konflik terjadi:

Jangan menghapus versi lokal.
Tandai sebagai conflict.
Tampilkan pesan kepada pengguna.
Sediakan pilihan:
Gunakan versi perangkat.
Gunakan versi server.
Salin isi untuk penggabungan manual.
Jika backend belum mendukung conflict detection, minimal:

Pertahankan draft lokal.
Tampilkan error.
Jangan menimpa data tanpa pemberitahuan.
13. Keamanan
Hanya anon/public key yang boleh digunakan.
Jangan memasukkan Service Role Key ke Flutter.
Jangan mencetak key atau token ke log.
Wajib menggunakan HTTPS.
Pastikan RLS aktif.
Setiap operasi dibatasi berdasarkan auth.uid().
Jangan percaya user_id dari UI.
Hapus konfigurasi saat disconnect.
Hapus cache sesuai pilihan pengguna.
Jangan mengirim credential ke server lain.
Jangan menampilkan stack trace ke pengguna.
14. UI/UX
Gaya visual
Minimalis.
Bersih.
Fokus pada teks.
Warna netral.
Satu warna aksen.
Spacing lapang.
Tidak banyak card dekoratif.
Animasi minimal.
Dark mode mengikuti sistem.
Halaman
Splash/loading.
Setup Supabase.
Test connection.
Login.
Register.
Verify email.
Forgot password.
Notes list.
Search.
Note editor.
Settings.
Account.
Sync error.
Disconnect confirmation.
Komponen reusable
ValteraButton
ValteraTextField
NoteCard
NoteEditor
SyncStatusIndicator
EmptyState
ErrorState
LoadingState
OfflineBanner
ConfirmDialog
Aksesibilitas
Touch target minimal 44–48 dp.
Semua tombol icon memiliki label.
Mendukung font scaling.
Kontras memadai.
Status tidak hanya menggunakan warna.
Keyboard tidak menutupi editor.
15. Error Handling
Kategori error:


Setiap error wajib:

Memiliki pesan yang mudah dipahami.
Memiliki tombol retry jika memungkinkan.
Dicatat pada debug log secara aman.
Tidak menghasilkan status sukses palsu.
Tidak menampilkan detail teknis kepada pengguna.
16. Non-Functional Requirements
Performance
Gunakan lazy loading.
Jangan rebuild seluruh list saat satu item berubah.
Gunakan debounce untuk search dan auto-save.
Gunakan pagination.
Gunakan cache lokal.
Hindari request berulang.
Pantau ukuran APK/AAB.
Reliability
Tidak crash saat offline.
Draft tidak hilang saat request gagal.
Queue dapat diproses ulang.
Session dipulihkan.
Aplikasi dapat digunakan pada perangkat Android kelas rendah.
Maintainability
Gunakan Dart null safety.
Gunakan feature-based architecture.
Tidak ada query Supabase dalam widget.
Repository dapat di-mock untuk test.
Error memiliki tipe yang jelas.
Dokumentasi setup diperbarui.
17. Acceptance Criteria
Setup
 Pengguna dapat memasukkan Supabase URL.
 Pengguna dapat memasukkan anon key.
 Input divalidasi.
 Test connection tersedia.
 Error koneksi jelas.
 Konfigurasi tersimpan dengan aman.
 Konfigurasi dapat dihapus.
Auth
 Login berfungsi.
 Registrasi berfungsi.
 Password confirmation berfungsi.
 Session tersimpan.
 Session dapat dipulihkan.
 Logout berfungsi.
 Forgot password tersedia jika didukung.
 Email verification ditangani.
Notes
 List notes sesuai schema existing.
 Create berfungsi.
 Read berfungsi.
 Update berfungsi.
 Delete berfungsi.
 Search berfungsi.
 Pull-to-refresh berfungsi.
 Empty state tersedia.
 Error state tersedia.
 Offline state tersedia.
Sync
 Perubahan Android muncul di web.
 Perubahan web muncul di Android.
 Cache dapat dibaca offline.
 Perubahan offline masuk queue.
 Queue diproses saat online.
 Retry tersedia.
 Kegagalan sync tidak menghapus data lokal.
 Konflik tidak ditimpa diam-diam.
18. Roadmap Implementasi
Fase 0 — Audit existing system
Audit project web.
Audit schema Supabase.
Audit Auth.
Audit RLS.
Audit query dan mutation.
Audit behavior sinkronisasi.
Buat kontrak data.
Fase 1 — Flutter foundation
Buat Flutter project.
Buat app shell.
Buat theme.
Buat routing.
Buat error model.
Buat secure storage.
Buat dependency injection.
Fase 2 — Supabase setup dan Auth
Input URL.
Input anon key.
Test connection.
Login.
Register.
Session restore.
Logout.
Forgot password.
Fase 3 — Notes read-only
Model.
Entity.
Repository.
Fetch data.
List UI.
Loading.
Empty state.
Error state.
Pull-to-refresh.
Fase 4 — CRUD notes
Create.
Edit.
Delete.
Save state.
Optimistic update.
Confirmation dialog.
Fase 5 — Offline dan sync
Local database.
Connectivity listener.
Queue perubahan.
Retry.
Conflict handling.
Sync indicator.
Fase 6 — Quality dan release
Unit test.
Widget test.
Integration test.
Performance profiling.
Accessibility.
App icon.
Splash screen.
APK/AAB signing.
QA perangkat nyata.
19. Test Plan
Unit test
URL validator.
Supabase configuration storage.
Auth repository.
Notes mapper.
Notes repository.
Local cache.
Mutation queue.
Retry policy.
Conflict detector.
Widget test
Setup form.
Login form.
Register form.
Notes list.
Empty state.
Error state.
Offline banner.
Editor.
Delete confirmation.
Integration test
Setup → login → notes.
Register → verification.
Create → refresh → detail.
Edit → validasi di web.
Delete → list update.
Offline create → reconnect → sync.
Logout → login ulang.
Manual QA
Android emulator.
Perangkat kelas rendah.
Light mode.
Dark mode.
Font besar.
Keyboard terbuka.
Internet lambat.
Internet terputus saat menyimpan.
Aplikasi ditutup saat sync.
Session expired.
Project Supabase salah.
RLS permission denied.
20. Definition of Done
Fitur dianggap selesai jika:

Mengikuti schema Supabase aktual.
Tidak memakai Service Role Key.
Berjalan di Android emulator atau perangkat nyata.
flutter analyze berhasil.
Formatter berhasil.
Test terkait berhasil.
Loading, empty, offline, error, dan retry tersedia.
Data Android dan web dapat diverifikasi dua arah.
Tidak ada query Supabase pada widget.
Draft tidak hilang saat sync gagal.
Dokumentasi diperbarui.
Tidak merusak fitur existing.
21. Instruksi Utama untuk AI Developer

22. Keputusan Default Jika Belum Ditentukan
Jika belum ada keputusan bisnis atau teknis, gunakan default berikut:

Area	Keputusan default
Project aktif	Satu project Supabase per perangkat
Auth	Email/password
Isi catatan	Plain text
Attachment	Tidak ada pada MVP
Rich text	Tidak ada pada MVP
Offline	Cache dan queue mutation
Sorting	updated_at terbaru
Delete	Ikuti behavior project web
Theme	Light/dark mengikuti sistem
Realtime	Ditambahkan setelah CRUD stabil
Android	Fokus Android terlebih dahulu
Sync conflict	Deteksi menggunakan updated_at jika tersedia
Database lokal	Satu database lokal saja
Service role key	Dilarang keras
Prioritas implementasi yang benar adalah:

Audit project web.
Pastikan schema dan RLS Supabase.
Buat kontrak data.
Buat Flutter foundation.
Buat onboarding Supabase.
Buat Auth.
Buat Notes CRUD.
Buat offline cache.
Buat sync queue.
Uji sinkronisasi dua arah dengan frontend web.