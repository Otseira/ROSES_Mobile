#!/usr/bin/env python3
import os
import sys

# Import our PSReport engine
from generate_docs import PSReport

def build_mobile_manual():
    print("Membangun Dokumen 1: Panduan Aplikasi Mobile SIROM...")
    doc = PSReport(
        filename="docs/Panduan_Aplikasi_Mobile_SIROM",
        title="Panduan Penggunaan Aplikasi Mobile SIROM",
        subtitle="Petunjuk Presensi Wajah, Roster Dinas, Lembur & Bank Jam Mandiri RSKB Ropanasuri",
        doc_type="MODUL PANDUAN PENGGUNA MOBILE"
    )
    doc.add_cover()
    doc._start_content_page()
    
    # BAB 1
    doc.add_section_header("1", "Persiapan & Masuk Aplikasi (Login)")
    doc.add_paragraph(
        "Aplikasi SIROM dirancang sangat praktis dan intuitif agar dapat digunakan dengan mudah "
        "oleh seluruh tenaga medis, perawat, dan staf umum RSKB Ropanasuri melalui smartphone Android/iOS."
    )
    doc.add_step_card(
        "1", 
        "Buka Aplikasi & Masukkan Akun", 
        "Buka aplikasi SIROM di ponsel Anda. Masukkan NIK / Username dan Password resmi yang diberikan oleh bagian SDM atau IT SIMRS RSKB Ropanasuri."
    )
    doc.add_step_card(
        "2", 
        "Izinkan Akses GPS Lokasi & Kamera Depan", 
        "Saat aplikasi meminta izin akses: pilih 'Izinkan Saat Aplikasi Digunakan' (Allow while using app). GPS lokasi diperlukan untuk mendeteksi radius gedung rumah sakit dan kamera digunakan untuk mengambil foto selfie kehadiran."
    )
    doc.add_callout(
        "warn",
        "PERHATIAN PENTING TENTANG GPS LOKASI",
        "Pastikan pengaturan Lokasi (GPS) pada smartphone Anda selalu aktif dengan mode akurasi tinggi sebelum menekan tombol absensi."
    )
    
    # BAB 2
    doc.add_section_header("2", "Mengenal Halaman Utama (Beranda)")
    doc.add_paragraph(
        "Halaman beranda adalah pusat navigasi harian Anda yang menyajikan informasi secara real-time:"
    )
    doc.add_bullet(
        "Jam Digital Instansi:", 
        "Penunjuk waktu resmi yang tersinkronisasi langsung dengan server pusat RSKB Ropanasuri dalam zona waktu WIB."
    )
    doc.add_bullet(
        "Status Absensi Hari Ini:", 
        "Kotak penanda otomatis yang menampilkan status apakah Anda sudah melakukan absen Masuk dan absen Pulang lengkap dengan catatan jamnya."
    )
    doc.add_bullet(
        "Kartu Total Saldo Bank Jam:", 
        "Kartu berwarna ungu-indigo khusus untuk pegawai unit kerja dengan sistem Ganti Jam Kerja. Menampilkan total menit kompensasi jam lembur yang siap digunakan kapan saja."
    )
    doc.add_callout(
        "info",
        "CATATAN KEBIJAKAN UNIT",
        "Bagi staf yang bekerja pada unit dengan kebijakan lembur dibayar uang (payroll cash), kartu Saldo Bank Jam otomatis disembunyikan oleh sistem."
    )
    
    # BAB 3
    doc.add_section_header("3", "Tata Cara Presensi (Absen Datang & Pulang)")
    doc.add_paragraph(
        "Melakukan pencatatan kehadiran dinas harian hanya membutuhkan waktu kurang dari 5 detik:"
    )
    doc.add_step_card(
        "1", 
        "Tekan Tombol Presensi", 
        "Tekan tombol hijau besar 'ABSEN MASUK' saat Anda baru tiba untuk memulai jam dinas, atau tombol oranye 'ABSEN PULANG' saat jam dinas Anda telah berakhir."
    )
    doc.add_step_card(
        "2", 
        "Ambil Foto Selfie Wajah", 
        "Arahkan kamera depan ke wajah Anda secara jelas di tempat dengan pencahayaan memadai, lalu tekan tombol lingkaran untuk membidik foto."
    )
    doc.add_step_card(
        "3", 
        "Verifikasi Otomatis & Notifikasi", 
        "Sistem secara otomatis mengukur jarak koordinat Anda terhadap titik pusat RSKB Ropanasuri. Jika berada di dalam radius resmi, layar akan menampilkan konfirmasi centang hijau 'Presensi Berhasil Dicatat'."
    )
    doc.add_callout(
        "tip",
        "TIPS JIKA SINYAL GPS LEMAH DI DALAM RUANGAN",
        "Jika Anda berada di ruangan tertutup dan GPS memerlukan waktu untuk terkunci, Anda cukup mendekat sejenak ke arah jendela atau koridor terbuka."
    )

    # BAB 4
    doc.add_section_header("4", "Jadwal Dinas Kerja (Menu Roster)")
    doc.add_paragraph(
        "Melalui tab menu Roster, Anda dapat memantau seluruh jadwal dinas harian maupun bulanan:"
    )
    doc.add_bullet("Jadwal Shift Harian:", "Melihat nama shift (Pagi, Siang, Malam) serta rentang jam masuk dan jam pulang yang telah ditetapkan kepala unit.")
    doc.add_bullet("Toleransi Waktu:", "Setiap shift memiliki batas waktu toleransi keterlambatan (standar 15 menit) yang diatur oleh manajemen rumah sakit.")
    doc.add_bullet("Kalender Bulanan:", "Memeriksa tanggal dinas aktif, hari libur nasional, dan hari lepas dinas/libur mingguan Anda.")

    # BAB 5
    doc.add_section_header("5", "Pengajuan Lembur & Panggilan On-Call")
    doc.add_paragraph(
        "Jika Anda mendapatkan tugas dinas tambahan di luar jam kerja reguler, gunakan menu Lembur:"
    )
    doc.add_sub_header("A. Lembur Lanjut Dinas (Ekstensi Shift)")
    doc.add_step_card(
        "1", 
        "Isi Formulir Lembur", 
        "Pilih tanggal dinas, tentukan jam mulai dan jam selesai lembur, serta tuliskan alasan tugas lembur (misalnya: penanganan tindakan pasien darurat)."
    )
    doc.add_step_card(
        "2", 
        "Menunggu Persetujuan Atasan", 
        "Pengajuan akan diteruskan kepada Kepala Unit atau Penanggung Jawab untuk diverifikasi dan disetujui."
    )
    doc.add_sub_header("B. Panggilan Darurat Medis (On-Call)")
    doc.add_paragraph(
        "Bagi dokter spesialis, perawat bedah, atau tenaga medis yang dipanggil bertugas secara mendadak:"
    )
    doc.add_bullet("Mulai On-Call:", "Tekan tombol 'Mulai Tugas On-Call' saat Anda tiba di RS untuk mengaktifkan status tugas darurat.")
    doc.add_bullet("Selesai On-Call:", "Tekan tombol 'Selesai Tugas On-Call' begitu tindakan selesai. Durasi jam bertugas otomatis dihitung presisi.")

    # BAB 6
    doc.add_section_header("6", "Prosedur Pengambilan Waktu Lembur (Bank Jam)")
    doc.add_paragraph(
        "Bagi pegawai unit kerja non-bayar, seluruh jam lembur yang disetujui dikumpulkan menjadi tabungan waktu (Bank Jam) "
        "yang dapat Anda manfaatkan sebagai kompensasi istirahat kerja:"
    )
    doc.add_callout(
        "info",
        "2 PILIHAN KOMPENSASI JAM KERJA",
        "1. Masuk Diperlambat : Datang dinas lebih lambat dari jam shift normal tanpa dianggap terlambat.\n"
        "2. Pulang Dipercepat : Pulang dinas lebih awal dari jam shift normal tanpa potongan gaji/poin."
    )
    doc.add_step_card(
        "1", 
        "Buka Tab Bank Jam", 
        "Periksa saldo menit yang Anda miliki di halaman Beranda atau menu Lembur, lalu klik tombol 'Ambil Waktu Lembur'."
    )
    doc.add_step_card(
        "2", 
        "Isi Formulir Pengambilan Jam", 
        "Pilih tanggal dinas yang ingin Anda gunakan, pilih jenis kompensasi (Masuk Lambat / Pulang Cepat), masukkan durasi yang ingin diambil dalam satuan MENIT (misal 60 atau 120 menit), dan tuliskan alasan singkat."
    )
    doc.add_step_card(
        "3", 
        "Verifikasi Atasan & Efek Otomatis", 
        "Setelah disetujui atasan, sistem absensi otomatis memperpanjang toleransi kedatangan Anda. Jika jadwal masuk jam 08:00 dan Anda mengambil 60 menit, Anda dapat tap masuk hingga jam 09:00 dan status absensi tetap 'TEPAT WAKTU'."
    )

    # BAB 7
    doc.add_section_header("7", "Khusus Atasan: Panduan Menu Validasi Mobile")
    doc.add_paragraph(
        "Kepala Instalasi, Penanggung Jawab, dan Manajer memiliki menu 'Validasi' pada bilah bawah aplikasi:"
    )
    doc.add_bullet("Tab 1 - Validasi Lembur:", "Memeriksa dan menyetujui pengajuan lembur dinas biasa dari staf unit.")
    doc.add_bullet("Tab 2 - Validasi On-Call:", "Memverifikasi pelaksanaan tugas panggilan darurat nakes.")
    doc.add_bullet("Tab 3 - Validasi Pengambilan Jam:", "Menyetujui klaim staf yang ingin datang lambat atau pulang cepat dengan Bank Jam.")
    doc.add_paragraph(
        "Cara Validasi Cepat: Tekan tombol centang hijau untuk 'Setujui', atau tombol silang merah untuk 'Tolak' disertai catatan penolakan.",
        indent=10, font="Helvetica-Bold", size=9
    )

    # BAB 8
    doc.add_section_header("8", "Pertanyaan Sering Diajukan (FAQ)")
    headers = ["Pertanyaan", "Penjelasan & Solusi Praktis"]
    rows = [
        ["Kenapa muncul notifikasi di luar radius?", "Pastikan Anda sudah berada di area RS dan GPS ponsel Anda menyala dengan akurasi tinggi."],
        ["Apakah saldo Bank Jam hangus di akhir bulan?", "Tidak. Saldo Bank Jam bersifat kumulatif sepanjang masa (all-time) sampai Anda gunakan."],
        ["Bagaimana jika lupa absen karena darurat?", "Laporkan segera kepada Kepala Unit atau HRD agar dilakukan penyesuaian pada sistem web."],
        ["Berapa maksimal durasi kompensasi yang bisa diambil?", "Durasi maksimal disesuaikan dengan sisa total saldo menit Bank Jam aktif yang Anda miliki."]
    ]
    doc.add_table(headers, rows, [195, 300])

    doc.compile()


def build_web_manual():
    print("Membangun Dokumen 2: Panduan Dashboard Web SIRO...")
    doc = PSReport(
        filename="docs/Panduan_Dashboard_Web_SIRO",
        title="Panduan Operasional Dashboard Web SIRO",
        subtitle="Petunjuk Live Monitoring, Roster, Rekap Payroll & Saldo Bank Jam RSKB Ropanasuri",
        doc_type="MODUL PANDUAN ADMINISTRATOR & MANAJEMEN"
    )
    doc.add_cover()
    doc._start_content_page()

    # BAB 1
    doc.add_section_header("1", "Akses Portal & Hak Akses Manajerial")
    doc.add_paragraph(
        "Dashboard web SIRO merupakan sistem komprehensif berbasis web yang dapat diakses melalui browser komputer, "
        "laptop, atau tablet pada tautan resmi: https://absensi.ropanasuri.com"
    )
    headers = ["Peran (Role)", "Cakupan Hak Akses & Wewenang"]
    rows = [
        ["Superadmin & HRD", "Akses penuh global seluruh unit kerja, master data, konfigurasi, dan export payroll."],
        ["Direktur", "Akses monitoring eksekutif menyeluruh terhadap seluruh kehadiran nakes dan staf RS."],
        ["Kepala Instalasi / PJ", "Dibatasi mengelola dan memvalidasi unit kerja binaannya masing-masing (Multi-Unit Scoping)."],
        ["Manajer Bidang", "Mengawasi beberapa unit kerja sekaligus yang berada di bawah departemennya."]
    ]
    doc.add_table(headers, rows, [155, 340])

    # BAB 2
    doc.add_section_header("2", "Halaman Live Monitoring Kehadiran Real-Time")
    doc.add_paragraph(
        "Halaman Live Monitoring dirancang khusus untuk memantau kelancaran operasional rumah sakit hari ini secara detik-per-detik:"
    )
    doc.add_bullet("Jam Digital & Auto-Refresh 30 Detik:", "Layar memperbarui data kehadiran secara otomatis setiap 30 detik tanpa perlu reload browser manual.")
    doc.add_bullet("8 Kartu Metrik Harian:", "Total Jadwal, Tepat Waktu, Terlambat, Belum Hadir, Pulang Cepat, Izin/Cuti, Lembur Aktif, dan Pemakaian Bank Jam.")
    doc.add_bullet("Banner Darurat On-Call Aktif:", "Banner peringatan di bagian atas tabel yang otomatis menyala jika ada dokter/nakes yang sedang bertugas darurat.")
    doc.add_bullet("Pratinjau Foto Absensi Selfie:", "Klik pada thumbnail foto absensi masuk atau pulang untuk menampilkan jendela preview foto ukuran besar.")
    doc.add_bullet("Indikator Kompensasi Bank Jam:", "Pegawai yang hadir melewati jam shift namun memiliki pengajuan 'Masuk Diperlambat' yang disetujui akan diberi penanda khusus dan statusnya tetap diakui sah.")

    # BAB 3
    doc.add_section_header("3", "Manajemen Roster Jadwal Dinas")
    doc.add_paragraph(
        "Melalui menu Roster Jadwal, manajemen dapat mengatur rotasi jadwal dinas harian dan bulanan per unit:"
    )
    doc.add_step_card(
        "1", 
        "Pilih Unit & Periode Bulan", 
        "Pilih unit kerja yang dikelola serta bulan dan tahun jadwal yang ingin disusun."
    )
    doc.add_step_card(
        "2", 
        "Alokasi Shift Kerja Pegawai", 
        "Tentukan penugasan shift (Pagi, Siang, Malam, Lepas Dinas, atau Libur) untuk setiap staf pada tanggal yang bersangkutan."
    )
    doc.add_step_card(
        "3", 
        "Simpan & Sinkronisasi Mobile", 
        "Setelah disimpan, jadwal dinas tersebut seketika muncul pada aplikasi smartphone masing-masing pegawai bersangkutan."
    )

    # BAB 4
    doc.add_section_header("4", "Rekapitulasi Absensi & Laporan Payroll")
    doc.add_paragraph(
        "Menu Rekap Absensi menyajikan rekapitulasi kehadiran lengkap sebagai dokumen dasar perhitungan payroll bulanan:"
    )
    doc.add_bullet("Filter Periode & Unit:", "Membatasi data berdasarkan rentang tanggal dinas dan unit kerja yang diinginkan.")
    doc.add_bullet("Pemeriksaan Foto Absensi (IN & OUT):", "Kolom foto dilengkapi badge hijau IN untuk absensi masuk dan badge oranye OUT untuk absensi pulang.")
    doc.add_bullet("Kalkulasi Keterlambatan Presisi:", "Mencatat selisih menit keterlambatan pegawai terhadap toleransi shift yang berlaku.")
    doc.add_bullet("Ekspor Laporan (Excel & PDF):", "Unduh berkas Excel multi-sheet per karyawan atau dokumen PDF resmi siap cetak.")

    # BAB 5
    doc.add_section_header("5", "Rekapitulasi Lembur, On-Call, & Saldo Bank Jam")
    doc.add_paragraph(
        "Halaman Rekap Lembur terbagi menjadi 3 tab utama yang seluruhnya menggunakan format standar satuan MENIT:"
    )
    doc.add_sub_header("Tab 1: Lembur Berbayar (Payroll)")
    doc.add_paragraph(
        "Menampilkan seluruh pengajuan lembur dari unit dengan kebijakan lembur dibayar uang. Durasi disajikan dalam satuan menit "
        "(contoh: 120 menit). Atasan dapat menyetujui atau menolak pengajuan langsung melalui kolom Aksi Web."
    )
    doc.add_sub_header("Tab 2: Saldo Bank Jam Pegawai (Kompensasi Jam Kerja)")
    doc.add_paragraph(
        "Menampilkan tabungan menit lembur karyawan unit non-bayar yang berlaku kumulatif sepanjang masa (all-time tanpa batas bulan):"
    )
    doc.add_callout(
        "tip",
        "TUTORIAL ATASAN: CARA INPUT / PENYESUAIAN SALDO JAM LEMBUR",
        "Jika pegawai memiliki saldo lembur lama dari tahun lalu atau kompensasi khusus yang belum tercatat:\n"
        "1. Buka Tab 2: Saldo Bank Jam Pegawai.\n"
        "2. Cari nama pegawai, lalu klik tombol 'Set Saldo'.\n"
        "3. Masukkan jumlah Menit (contoh: 180 untuk 3 jam) dan tuliskan alasan penyesuaian.\n"
        "4. Periksa kalkulator preview total saldo akhir pada modal.\n"
        "5. Klik 'Simpan Saldo Lembur'. Saldo di ponsel pegawai langsung bertambah detik itu juga."
    )
    doc.add_sub_header("Tab 3: Riwayat Pengambilan Jam Kompensasi")
    doc.add_paragraph(
        "Meninjau permohonan staf yang ingin datang terlambat atau pulang cepat menggunakan tabungan Bank Jam. "
        "Atasan cukup memeriksa tanggal dinas dan alasan sebelum menekan tombol Setujui."
    )

    # BAB 6
    doc.add_section_header("6", "Pengaturan Master Unit Kerja (Kebijakan Lembur)")
    doc.add_paragraph(
        "Admin atau SDM dapat menentukan status pembayaran lembur untuk setiap unit kerja rumah sakit:"
    )
    doc.add_step_card(
        "1", 
        "Buka Menu Master Unit", 
        "Masuk ke menu Master Data > Master Unit, lalu klik tombol Edit pada unit kerja yang ingin disesuaikan."
    )
    doc.add_step_card(
        "2", 
        "Pilih Kebijakan Lembur", 
        "Pilih opsi 'Lembur Dibayar' jika lembur unit tersebut diberikan kompensasi uang, atau 'Ganti Jam Kerja' jika lembur dikonversi menjadi tabungan waktu Bank Jam."
    )
    doc.add_step_card(
        "3", 
        "Simpan Kebijakan", 
        "Klik Simpan. Seluruh staf yang terdaftar pada unit tersebut akan otomatis mengikuti aturan yang baru dipilih."
    )

    # BAB 7
    doc.add_section_header("7", "Panduan Pemeliharaan Server & Hosting")
    doc.add_paragraph(
        "Bagi administrator server saat memperbarui kode sistem pada domain https://absensi.ropanasuri.com:"
    )
    doc.add_bullet("Migrasi Database:", "Jalankan 'php artisan migrate' melalui SSH untuk memperbarui struktur tabel saldo bank jam.")
    doc.add_bullet("Symlink Storage Foto:", "Pastikan symlink storage aktif dengan perintah 'php artisan storage:link' agar foto absensi pegawai dapat tampil pada browser.")

    doc.compile()

if __name__ == "__main__":
    build_mobile_manual()
    build_web_manual()
    print("SELURUH DOKUMEN PDF BERHASIL DIBUAT DENGAN SEMPURNA!")

