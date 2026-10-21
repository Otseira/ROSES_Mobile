# BUKU PANDUAN OPERASIONAL DASHBOARD WEB SIRO
**RSKB Ropanasuri &bull; Edisi Pembaruan Oktober 2026 (Versi 2.0)**  
*Sistem Informasi Roster, Monitoring Presensi & Payroll Terpadu*

---

## 1. Akses Portal & Hak Akses Manajerial
- **Alamat URL Portal**: `https://absensi.ropanasuri.com`
- **Tingkatan Hak Akses**:
  - **Superadmin & HRD**: Akses penuh global seluruh unit kerja, master data, pengaturan payroll, dan rekap instansi.
  - **Direktur**: Pemantauan eksekutif menyeluruh terhadap seluruh kehadiran nakes dan staf RS.
  - **Kepala Instalasi / Penanggung Jawab Unit**: Mengelola, menyusun roster, dan memvalidasi unit kerja binaannya (*Multi-Unit Scoping*).
  - **Manajer Bidang**: Mengawasi beberapa unit kerja sekaligus di bawah departemennya.

---

## 2. Halaman Live Monitoring Kehadiran Real-Time
1. **Jam Digital & Auto-Refresh (30 Detik)**:
   - Data kehadiran diperbarui secara otomatis setiap 30 detik tanpa perlu merefresh browser.
2. **8 Kartu Metrik Harian**:
   - Total Jadwal, Tepat Waktu, Terlambat, Belum Hadir, Pulang Cepat, Izin/Cuti, Sedang Lembur, dan Bank Jam Terpakai.
3. **Banner Darurat On-Call Aktif**:
   - Peringatan di atas tabel yang langsung menyala jika ada dokter atau nakes yang sedang bertugas darurat medis.
4. **Pratinjau Foto Absensi Selfie & Radius GPS**:
   - Klik thumbnail foto selfie masuk atau pulang untuk menampilkan jendela preview foto besar (*modal zoom-in*).
5. **Indikator Sah Kompensasi Bank Jam**:
   - Pegawai yang datang melewati jam shift namun memiliki pengajuan *Masuk Diperlambat* yang disetujui akan ditandai dengan badge khusus dan statusnya tetap diakui sah.

---

## 3. Manajemen Roster Jadwal Dinas
1. Pilih unit kerja yang dikelola serta bulan dan tahun jadwal yang ingin disusun.
2. Tentukan shift dinas (Pagi, Siang, Malam, Lepas Dinas, atau Libur) untuk setiap staf.
3. Klik **Simpan**. Jadwal otomatis tersinkronisasi ke aplikasi mobile masing-masing staf.

---

## 4. Rekapitulasi Absensi & Laporan Payroll
1. **Filter Periode & Unit Kerja**: Tentukan tanggal mulai dan selesai, lalu klik **Terapkan**.
2. **Pemeriksaan Foto Absensi**:
   - Badge hijau **IN** untuk foto absensi masuk.
   - Badge oranye **OUT** untuk foto absensi pulang.
   - Klik foto untuk memperbesar pratinjau.
3. **Ekspor Laporan**:
   - Tombol hijau **Excel**: Menghasilkan rekap spreadsheet multi-sheet per karyawan.
   - Tombol merah **Cetak PDF**: Menghasilkan dokumen laporan resmi siap cetak.

---

## 5. Rekapitulasi Lembur, On-Call, & Saldo Bank Jam
Halaman Rekap Lembur terbagi menjadi 3 tab utama yang menggunakan format standar satuan **MENIT**:

### Tab 1: Lembur Berbayar (Payroll)
- Menampilkan pengajuan lembur dari unit kerja berbayar uang (*cash*).
- Durasi disajikan dalam satuan **Menit** (contoh: `120 menit`).
- Atasan dapat melakukan persetujuan (*Setujui*) atau penolakan (*Tolak*) langsung pada kolom **Aksi Web**.

### Tab 2: Saldo Bank Jam Pegawai (Kompensasi Jam Kerja)
- Menampilkan tabungan menit lembur karyawan unit non-bayar.
- **Kumulatif Sepanjang Masa (*All-Time*)**: Saldo tidak terpotong oleh pergantian bulan atau tahun.
- Rumus: $\text{Saldo Tersedia} = (\text{Saldo Awal Manual} + \text{Lembur Aplikasi}) - \text{Total Diambil}$.

> ### Tutorial Atasan: Cara Input / Penyesuaian Saldo Jam Lembur
> Jika staf memiliki saldo lembur lama dari tahun lalu atau kompensasi manual yang belum tercatat:
> 1. Buka Tab 2: *Saldo Bank Jam Pegawai*.
> 2. Cari nama pegawai, lalu klik tombol **"Set Saldo"**.
> 3. Masukkan jumlah **Menit** (contoh: `180` untuk 3 jam) dan tuliskan alasan penyesuaian.
> 4. Periksa kalkulator preview total saldo akhir pada modal pop-up.
> 5. Klik **Simpan Saldo Lembur**. Saldo di ponsel pegawai langsung bertambah saat itu juga.

### Tab 3: Riwayat Pengambilan Jam (Kompensasi)
- Meninjau pengajuan staf yang mengambil kompensasi (Masuk Diperlambat atau Pulang Dipercepat).
- Atasan memeriksa tanggal dinas dan alasan sebelum menekan tombol **Setujui**.

---

## 6. Pengaturan Kebijakan Lembur Unit Kerja
1. Buka menu **Master Data ➔ Master Unit**.
2. Klik tombol **Edit** pada unit kerja yang diinginkan.
3. Pada opsi **Kebijakan Lembur Unit**, tentukan:
   - **Lembur Dibayar**: Dikonversi menjadi uang payroll.
   - **Ganti Jam Kerja**: Dikonversi menjadi tabungan waktu (Bank Jam) untuk kompensasi jam dinas staf.
4. Klik **Simpan Perubahan**.

---

## 7. Catatan Pemeliharaan Server
- **Migrasi Database**: Jalankan `php artisan migrate` saat memperbarui sistem.
- **Symlink Foto**: Pastikan symlink aktif dengan perintah `php artisan storage:link` agar foto absensi pegawai tampil sempurna di browser.

