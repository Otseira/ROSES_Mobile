import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class PeriodeKerja {
  final DateTime start;
  final DateTime end;
  final String label;
  final String namaBulan;
  final bool isCurrent;

  PeriodeKerja({
    required this.start,
    required this.end,
    required this.label,
    required this.namaBulan,
    required this.isCurrent,
  });

  static PeriodeKerja dariOffset(int offsetBulan) {
    final now = DateTime.now();
    int baseYear = now.year;
    int baseMonth = now.month;

    // Jika hari ini sebelum tanggal 24, periode berjalan dimulai dari tanggal 24 bulan lalu
    if (now.day < 24) {
      baseMonth -= 1;
      if (baseMonth < 1) {
        baseMonth = 12;
        baseYear -= 1;
      }
    }

    // Terapkan offset bulan
    int targetMonth = baseMonth + offsetBulan;
    int targetYear = baseYear;
    while (targetMonth < 1) {
      targetMonth += 12;
      targetYear -= 1;
    }
    while (targetMonth > 12) {
      targetMonth -= 12;
      targetYear += 1;
    }

    final start = DateTime(targetYear, targetMonth, 24);

    int nextMonth = targetMonth + 1;
    int nextYear = targetYear;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    }
    final end = DateTime(nextYear, nextMonth, 23, 23, 59, 59);

    final fMulai = DateFormat('d MMM yyyy', 'id_ID').format(start);
    final fSelesai = DateFormat('d MMM yyyy', 'id_ID').format(end);
    final namaBulan = DateFormat('MMMM yyyy', 'id_ID').format(end);

    return PeriodeKerja(
      start: start,
      end: end,
      label: '$fMulai – $fSelesai',
      namaBulan: namaBulan,
      isCurrent: offsetBulan == 0,
    );
  }
}

class RiwayatLemburScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? bankJam;
  final List<dynamic>? riwayatLemburAwal;
  final List<dynamic>? riwayatAmbilJamAwal;

  const RiwayatLemburScreen({
    super.key,
    this.bankJam,
    this.riwayatLemburAwal,
    this.riwayatAmbilJamAwal,
  });

  @override
  ConsumerState<RiwayatLemburScreen> createState() =>
      _RiwayatLemburScreenState();
}

class _RiwayatLemburScreenState extends ConsumerState<RiwayatLemburScreen> {
  int _offsetBulan = 0; // 0 = periode saat ini (24 s/d 23), -1 = periode lalu
  int _tabRiwayat = 0; // 0 = Lembur & On-Call, 1 = Pengambilan Jam
  String _filterStatus = 'Semua';

  List<dynamic> _riwayatLembur = [];
  List<dynamic> _riwayatAmbilJam = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.riwayatLemburAwal != null) {
      _riwayatLembur = List.from(widget.riwayatLemburAwal!);
    }
    if (widget.riwayatAmbilJamAwal != null) {
      _riwayatAmbilJam = List.from(widget.riwayatAmbilJamAwal!);
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    final periode = PeriodeKerja.dariOffset(_offsetBulan);
    final startStr = DateFormat('yyyy-MM-dd').format(periode.start);
    final endStr = DateFormat('yyyy-MM-dd').format(periode.end);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final futures = <Future>[
        api.get('/lembur/riwayat', query: {
          'start_date': startStr,
          'end_date': endStr,
        }),
      ];

      final isGantiJam = widget.bankJam?['is_ganti_jam'] == true;
      if (isGantiJam) {
        futures.add(
          api.get('/lembur/riwayat-ambil-jam', query: {
            'start_date': startStr,
            'end_date': endStr,
          }),
        );
      }

      final results = await Future.wait(futures);

      if (!mounted) return;

      final resLembur = results[0];
      if (resLembur['success'] == true) {
        _riwayatLembur = (resLembur['data'] as List?) ?? [];
      }

      if (isGantiJam && results.length > 1) {
        final resAmbil = results[1];
        if (resAmbil['success'] == true) {
          _riwayatAmbilJam = (resAmbil['data'] as List?) ?? [];
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat riwayat lembur: $e';
        });
      }
    }
  }

  DateTime? _parseTanggal(dynamic item) {
    final str = item['waktu_mulai_lembur'] ??
        item['waktu_mulai'] ??
        item['tanggal_dinas'] ??
        item['tanggal'];
    if (str == null) return null;
    try {
      return DateTime.parse(str.toString());
    } catch (_) {
      try {
        return DateFormat('d/M/yyyy').parse(str.toString());
      } catch (_) {
        return null;
      }
    }
  }

  List<dynamic> _filterList(List<dynamic> list, PeriodeKerja periode) {
    return list.where((item) {
      // 1. Filter Periode Tanggal 24 s/d 23
      final tgl = _parseTanggal(item);
      if (tgl != null) {
        if (tgl.isBefore(periode.start.subtract(const Duration(seconds: 1))) ||
            tgl.isAfter(periode.end.add(const Duration(seconds: 1)))) {
          return false;
        }
      }

      // 2. Filter Status
      if (_filterStatus != 'Semua') {
        final s = (item['status']?.toString() ??
                item['status_validasi']?.toString() ??
                '')
            .toLowerCase();
        if (s != _filterStatus.toLowerCase()) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final periode = PeriodeKerja.dariOffset(_offsetBulan);
    final isGantiJam = widget.bankJam?['is_ganti_jam'] == true;

    final filteredLembur = _filterList(_riwayatLembur, periode);
    final filteredAmbil = _filterList(_riwayatAmbilJam, periode);
    final activeList = _tabRiwayat == 0 ? filteredLembur : filteredAmbil;

    // Kalkulasi total menit periode ini
    int totalMenitLembur = 0;
    int disetujuiCount = 0;
    int pendingCount = 0;

    for (final item in filteredLembur) {
      final s = (item['status']?.toString() ?? '').toLowerCase();
      if (s == 'disetujui') disetujuiCount++;
      if (s == 'pending' || s == 'menunggu') pendingCount++;

      final menit = item['durasi_menit'] ??
          ((double.tryParse(item['total_jam']?.toString() ?? '') ?? 0) * 60)
              .round();
      if (s == 'disetujui') {
        totalMenitLembur += (menit is int ? menit : (menit as num).toInt());
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Lembur',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== 1. SELECTOR PERIODE BULAN KERJA (CUT-OFF 24 - 23) =====
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() => _offsetBulan -= 1);
                            _fetchData();
                          },
                          icon: const Icon(Icons.chevron_left_rounded, size: 28),
                          color: AppColors.primary,
                          tooltip: 'Periode Sebelumnya',
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.date_range_rounded,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Periode Cut-Off (24 – 23)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (periode.isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.successSoft,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Berjalan',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                periode.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => _offsetBulan += 1);
                            _fetchData();
                          },
                          icon: const Icon(Icons.chevron_right_rounded, size: 28),
                          color: AppColors.primary,
                          tooltip: 'Periode Berikutnya',
                        ),
                      ],
                    ),

                    const Divider(height: 18),

                    // Ringkasan Periode Ini dalam Menit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Total Disetujui',
                              style: TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalMenitLembur Menit',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (totalMenitLembur >= 60)
                              Text(
                                '${totalMenitLembur ~/ 60} jam ${totalMenitLembur % 60 > 0 ? '${totalMenitLembur % 60} m' : ''}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textHint,
                                ),
                              ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: AppColors.border),
                        Column(
                          children: [
                            const Text(
                              'Pengajuan',
                              style: TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${filteredLembur.length} Total',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '$disetujuiCount acc • $pendingCount pending',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ===== 2. TAB LEMBUR VS PENGAMBILAN JAM (JIKA UNIT GANTI JAM) =====
              if (isGantiJam) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tabRiwayat = 0),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _tabRiwayat == 0
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tabRiwayat == 0
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Lembur & On-Call (${filteredLembur.length})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _tabRiwayat == 0
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tabRiwayat = 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _tabRiwayat == 1
                                ? const Color(0xFF4F46E5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tabRiwayat == 1
                                  ? const Color(0xFF4F46E5)
                                  : AppColors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pengambilan Jam (${filteredAmbil.length})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _tabRiwayat == 1
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ===== 3. FILTER STATUS CHIPS =====
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Pending', 'Disetujui', 'Ditolak'].map((s) {
                    final isSelected = _filterStatus == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        onSelected: (_) => setState(() => _filterStatus = s),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // ===== 4. DAFTAR KARTU RIWAYAT =====
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _fetchData,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )
              else if (activeList.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 48,
                        color: AppColors.textHint.withOpacity(0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _filterStatus == 'Semua'
                            ? 'Tidak ada riwayat pada periode kerja ini\n(${periode.label}).'
                            : 'Tidak ada pengajuan berstatus "$_filterStatus" pada periode ini.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...activeList.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _tabRiwayat == 0
                        ? _buildLemburCard(item)
                        : _buildPengambilanCard(item),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtWaktu(String? t) {
    if (t == null || t.isEmpty) return '-';
    try {
      final dt = DateTime.parse(t);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return t;
    }
  }

  Widget _buildLemburCard(Map item) {
    final status = (item['status']?.toString() ?? 'Pending');
    final isDisetujui = status.toLowerCase() == 'disetujui';
    final isDitolak = status.toLowerCase() == 'ditolak';

    final Color statusColor = isDisetujui
        ? AppColors.success
        : (isDitolak ? AppColors.error : AppColors.warning);

    final Color statusBg = isDisetujui
        ? AppColors.successSoft
        : (isDitolak ? AppColors.errorSoft : AppColors.warningSoft);

    final IconData statusIcon = isDisetujui
        ? Icons.check_circle_rounded
        : (isDitolak ? Icons.cancel_rounded : Icons.access_time_filled_rounded);

    final jenis = item['jenis_lembur']?.toString() ?? 'Lembur';
    final bool isOnCall = jenis.toLowerCase().contains('on-call') ||
        jenis.toLowerCase().contains('oncall');

    final String mulai = _fmtWaktu(item['waktu_mulai']?.toString());
    final String selesai = _fmtWaktu(item['waktu_selesai']?.toString());

    // Selalu hitung durasi dalam menit
    final int durasiMenit = item['durasi_menit'] ??
        ((double.tryParse(item['total_jam']?.toString() ?? '') ?? 0) * 60)
            .round();
    final String durasiTeks = '$durasiMenit Menit';

    final String keterangan = item['keterangan']?.toString() ?? '-';
    final String? catatan = item['catatan_validasi']?.toString();
    final String? fotoMasuk = item['foto_masuk_url']?.toString();
    final String? fotoKeluar = item['foto_keluar_url']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Jenis & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnCall ? AppColors.infoSoft : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnCall
                          ? Icons.phone_callback_rounded
                          : Icons.timer_outlined,
                      size: 14,
                      color: isOnCall ? AppColors.info : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      jenis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOnCall ? AppColors.info : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tanggal & Waktu
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item['tanggal']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$mulai – $selesai WIB',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Durasi dalam Menit
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Durasi',
                      style: TextStyle(fontSize: 10, color: AppColors.textHint),
                    ),
                    Text(
                      durasiTeks,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Keterangan / Alasan
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keterangan,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Catatan Validasi bila ada
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan Atasan: $catatan',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDitolak ? AppColors.error : AppColors.textHint,
              ),
            ),
          ],

          // Thumbnail Foto
          if (fotoMasuk != null || fotoKeluar != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (fotoMasuk != null)
                  _buildThumb(fotoMasuk, isOnCall ? 'Foto Masuk' : 'Foto Bukti'),
                if (fotoKeluar != null) ...[
                  const SizedBox(width: 8),
                  _buildThumb(fotoKeluar, 'Foto Selesai'),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPengambilanCard(Map item) {
    final status = (item['status']?.toString() ?? 'Pending');
    final isDisetujui = status.toLowerCase() == 'disetujui';
    final isDitolak = status.toLowerCase() == 'ditolak';

    final Color statusColor = isDisetujui
        ? AppColors.success
        : (isDitolak ? AppColors.error : AppColors.warning);

    final Color statusBg = isDisetujui
        ? AppColors.successSoft
        : (isDitolak ? AppColors.errorSoft : AppColors.warningSoft);

    final IconData statusIcon = isDisetujui
        ? Icons.check_circle_rounded
        : (isDitolak ? Icons.cancel_rounded : Icons.access_time_filled_rounded);

    final bool isMasukLambat = item['tipe_pengambilan'] == 'masuk_diperlambat';
    final String tanggal = item['tanggal']?.toString() ?? '-';
    final int durasiMenit = item['durasi_menit'] ?? 0;
    final String durasiTeks = '$durasiMenit Menit';
    final String keterangan = item['keterangan']?.toString() ?? '-';
    final String? catatan = item['catatan_validasi']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMasukLambat
                      ? const Color(0xFF4F46E5).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMasukLambat ? 'Masuk Diperlambat' : 'Pulang Dipercepat',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMasukLambat
                        ? const Color(0xFF4F46E5)
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tanggal: $tanggal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Kompensasi: $durasiTeks',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Alasan: $keterangan',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Catatan: $catatan',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumb(String url, String label) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.white,
                      child: const Text('Gagal memuat gambar'),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
