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
