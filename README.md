# Aplikasi Terpadu KDMP Pasirmulya

PWA responsif untuk browser Windows dan HP. Kerangka awal menyediakan dashboard, navigasi modul, pencatatan kas/penjualan lokal, daftar anggota sederhana, dan cache offline.

## Menjalankan
Gunakan server web statis (misalnya VS Code Live Server atau hosting HTTPS). Service worker membutuhkan HTTPS atau localhost. Buka URL melalui Chrome/Edge; browser yang mendukung instalasi PWA akan menampilkan opsi **Pasang Aplikasi**.

## Fitur prototipe
- Kerangka PWA responsif.
- Cache file aplikasi agar shell dapat dibuka offline setelah kunjungan pertama.
- Pencatatan transaksi dan anggota pada penyimpanan lokal browser (localStorage).
- Draft skema PostgreSQL di `supabase/schema.sql`.

## Belum siap untuk operasional
- Autentikasi multiuser dan pembatasan hak akses.
- Backend API, database pusat aktif, dan sinkronisasi offline dua arah.
- Migrasi penyimpanan lokal ke IndexedDB dan mekanisme konflik sinkronisasi.
- Modul lengkap kas, LPG, usaha mandiri, invoice, anggota, SHU, surat, dan laporan.
- Audit log, backup, uji keamanan, serta deployment.
- Integrasi SISKOP melalui API resmi PINBUK.

**Peringatan:** Ini prototipe awal, bukan sistem produksi. Data transaksi yang dimasukkan sekarang hanya tersimpan pada browser/perangkat masing-masing dan belum tersinkron ke database pusat. Jangan gunakan untuk pembukuan resmi atau menyimpan data sensitif. Skema SQL masih draft dan perlu kebijakan RLS/permission yang diuji sebelum digunakan.

SISKOP PINBUK: https://siskop-beta.pinbuk.id/


## Memasang database Supabase dan hak akses

1. Masuk ke dashboard proyek Supabase: https://supabase.com/dashboard/project/fngumlzcvlbpozcfxfxx
2. Buka **SQL Editor** → **New query**.
3. Buka file [supabase/schema.sql](./supabase/schema.sql), salin seluruh isinya, tempel ke SQL Editor, lalu tekan **Run**.
4. Pastikan query selesai tanpa error. Script membuat tabel, indeks, trigger audit, dan kebijakan RLS untuk lima peran.
5. Buka **Authentication → Users** dan buat akun untuk setiap petugas. Pendaftaran publik sebaiknya tetap nonaktif.
6. Untuk setiap akun yang dibuat, catat UUID pengguna dari Authentication → Users. Jalankan perintah berikut di SQL Editor dengan UUID dan nama yang sesuai:

Gunakan UID yang disalin dari **Authentication → Users**. Jangan jalankan contoh UUID. Untuk menghindari error duplikasi primary key, gunakan pola berikut dan ganti setiap nilai contoh dengan UID asli:

```sql
INSERT INTO public.profiles (id, full_name, role, active)
VALUES
  ('UID-ASLI-ADMIN', 'Admin', 'admin', true)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  active = EXCLUDED.active;
```

Ulangi untuk setiap petugas. Pastikan UID adalah UUID akun Auth yang bersangkutan.

### Matriks hak akses

| Modul/data | Admin | Bendahara | Sekretaris | Bidang Anggota | Bidang Usaha |
|---|---|---|---|---|---|
| Profil pengguna | Kelola | Profil sendiri | Profil sendiri | Profil sendiri | Profil sendiri |
| Anggota | Kelola | Baca | — | Kelola | Baca |
| Simpanan anggota | Kelola | Kelola | — | Kelola | — |
| Kas | Kelola | Kelola | — | — | — |
| Produk, stok, penjualan | Kelola | Baca | — | — | Kelola |
| Invoice | Kelola | Baca | — | — | Kelola |
| Pengurus/karyawan | Kelola | — | Kelola | — | — |
| SHU | Kelola | Kelola | — | — | — |
| Surat dan surat jalan | Kelola | — | Kelola | — | Baca/kelola surat jalan |
| Audit log | Baca | Baca | — | — | — |

RLS juga membatasi akses langsung ke tabel melalui API. Pengaturan menu aplikasi saja tidak cukup untuk keamanan.

### Catatan penting

- Nilai awal referensi SHU yang disimpan: Jasa Pengurus 30%, Dana Cadangan 20%, Dana Pendidikan & Dana Sosial 5%. Nilai ini hanya referensi awal dan dapat diubah sesuai RAT; sisa 45% sengaja tidak dialokasikan otomatis.
- Pembagian SHU anggota disimpan secara manual; skema tidak menghitung atau membayarkan SHU otomatis.
- Jangan menaruh `service_role` key, secret key, atau password database di aplikasi browser atau GitHub.
- Skema SQL sudah disiapkan di repositori, tetapi belum dieksekusi pada proyek Supabase dari koneksi ini. Setelah menjalankan SQL, lakukan pengujian akun masing-masing peran sebelum memasukkan data operasional.


## Login aplikasi (rilis awal)

- Aplikasi memakai Supabase Auth email/password melalui publishable key di browser.
- Profil petugas dibaca dari `public.profiles` berdasarkan UID sesi; profil harus ada, aktif, dan memiliki salah satu role yang dikenal.
- Menu aplikasi difilter berdasarkan role. Keamanan data tetap ditentukan oleh RLS di database, bukan oleh penyembunyian menu.
- Data kas dan anggota pada prototipe ini masih tersimpan lokal per akun/perangkat. Modul-modul lain juga belum seluruhnya dihubungkan ke tabel Supabase.
- Jika login ditolak karena profil tidak ditemukan, periksa bahwa `profiles.id` sama persis dengan UID pada Authentication → Users.
- Jangan memasukkan password atau service-role key ke GitHub. Buat password sementara dan sampaikan kepada petugas melalui jalur aman.
