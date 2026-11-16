import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class JadwalDinasScreen extends ConsumerStatefulWidget {
  const JadwalDinasScreen({super.key});

  @override
  ConsumerState<JadwalDinasScreen> createState() => _JadwalDinasScreenState();
}

class _JadwalDinasScreenState extends ConsumerState<JadwalDinasScreen> {
  List<dynamic> _hari = [];
  int _jumlahHari = 0;
  bool _loading = true;
  String? _error;
  late DateTime _sel = DateTime(DateTime.now().year, DateTime.now().month);

  // 0 = Tampilan Kalender Bulanan (Identik SIRO Web), 1 = Matriks Tabel Detail
  int _viewMode = 0;

  // Tinggi baris & lebar kolom untuk grid jadwal
  static const double _rowH = 58;
  static const double _colW = 64;
  static const double _labelW = 148;

  Color get _cJadwal => AppColors.primary.withOpacity(0.10);
  Color get _cLibur => AppColors.textHint.withOpacity(0.12);
  Color get _cTepat => AppColors.success.withOpacity(0.16);
  Color get _cTelat => AppColors.error.withOpacity(0.14);
  Color get _cLembur => AppColors.info.withOpacity(0.16);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get(
        '/jadwal-dinas',
        query: {'bulan': _sel.month, 'tahun': _sel.year},
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final d = res['data'] as Map;
        setState(() {
          _hari = (d['hari'] as List?) ?? [];
          _jumlahHari = (d['jumlah_hari'] as int?) ?? 0;
        });
      } else {
        setState(() => _error = res['message']?.toString());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _change(int delta) {
    setState(() => _sel = DateTime(_sel.year, _sel.month + delta));
    _fetch();
  }

  Map? _day(int i) => (i >= 0 && i < _hari.length) ? (_hari[i] as Map) : null;

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == _sel.year && now.month == _sel.month && now.day == day;
  }

  int _getLeadingBlanks() {
    final firstDayOfMonth = DateTime(_sel.year, _sel.month, 1);
    // In Dart: weekday 1 = Monday, 7 = Sunday. In SIRO: 0 = Sunday (Min), 1 = Monday (Sen), etc.
    return firstDayOfMonth.weekday % 7;
  }

  void _showDetailModal(Map item) {
    final tgl = item['tanggal'] ?? '-';
    final hari = item['hari_nama'] ?? '';
    final isLibur = item['is_libur'] == true && item['sesi2'] == null;
    final shiftNama = item['nama_shift'] ?? (isLibur ? 'Libur (OFF)' : '-');
    final jamMasuk = item['jam_masuk'] ?? '-';
    final jamPulang = item['jam_pulang'] ?? '-';
    final absenMasuk = item['absen_masuk'];
    final absenPulang = item['absen_pulang'];
    final terlambatMenit = (item['terlambat_menit'] as int?) ?? 0;
    final lemburMasuk = item['lembur_masuk'];
    final lemburPulang = item['lembur_pulang'];
    final sesi2 = item['sesi2'] as Map?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$hari, $tgl ${DateFormat('MMMM yyyy', 'id_ID').format(_sel)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Detail Jadwal Dinas & Presensi',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Shift
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isLibur ? const Color(0xFFF8FAFC) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLibur ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isLibur ? Colors.grey.shade300 : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLibur ? Icons.beach_access_rounded : Icons.schedule_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shiftNama,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isLibur ? Colors.grey.shade700 : const Color(0xFF047857),
                          ),
                        ),
                        if (!isLibur) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Jadwal: $jamMasuk - $jamPulang',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (absenMasuk != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: terlambatMenit > 0 ? const Color(0xFFFFE4E6) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        terlambatMenit > 0 ? 'Terlambat +$terlambatMenit m' : 'Tepat Waktu',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: terlambatMenit > 0 ? const Color(0xFFBE123C) : const Color(0xFF047857),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Realisasi Presensi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Absen Masuk Aktual',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        absenMasuk != null ? '$absenMasuk WIB' : '--:--',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: absenMasuk != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Absen Pulang Aktual',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        absenPulang != null ? '$absenPulang WIB' : '--:--',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: absenPulang != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  if (lemburMasuk != null || lemburPulang != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lembur / On-Call',
                          style: TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                        ),
                        Text(
                          '${lemburMasuk ?? "-"} s/d ${lemburPulang ?? "-"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (sesi2 != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Shift 2: ${sesi2["nama_shift"] ?? ""}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED)),
                        ),
                        Text(
                          '${sesi2["absen_masuk"] ?? "-"} - ${sesi2["absen_pulang"] ?? "-"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_sel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Jadwal Dinas',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _viewMode == 0 ? 'Lihat Matriks Tabel' : 'Lihat Kalender Bulanan',
            icon: Icon(
              _viewMode == 0 ? Icons.table_chart_outlined : Icons.calendar_month_outlined,
              color: AppColors.primary,
            ),
            onPressed: () {
              setState(() => _viewMode = _viewMode == 0 ? 1 : 0);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetch,
        child: Column(
          children: [
            // === 1. NAVIGASI BULAN (IDENTIK DENGAN SIRO WEB) ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _change(-1),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF475569),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          monthLabel[0].toUpperCase() + monthLabel.substring(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Kalender Shift Pribadi',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _change(1),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF475569),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === 2. LEGEND INDIKATOR SHIFT (IDENTIK DENGAN SIRO WEB) ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _legendItem(const Color(0xFF10B981), 'Tepat'),
                    _legendItem(const Color(0xFFF43F5E), 'Terlambat'),
                    _legendItem(const Color(0xFF3B82F6), 'Lembur'),
                    _legendItem(const Color(0xFF8B5CF6), 'Shift 2'),
                    _legendItem(const Color(0xFFCBD5E1), 'Libur'),
                  ],
                ),
              ),
            ),

            // === 3. BODY VIEW: KALENDER 7-KOLOM (MODE 0) ATAU MATRIKS TABEL (MODE 1) ===
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 40,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetch,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _hari.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada data jadwal untuk bulan ini.',
                                style: TextStyle(color: AppColors.textHint),
                              ),
                            )
                          : (_viewMode == 0 ? _buildCalendarGridView() : _buildMatrixTableView()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ================= VIEW 1: KALENDER GRID 7 KOLOM (IDENTIK SIRO WEB) =================
  Widget _buildCalendarGridView() {
    const daysHeader = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final leadingBlanks = _getLeadingBlanks();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Hari (Min, Sen, Sel, ...)
            Row(
              children: daysHeader.asMap().entries.map((entry) {
                final isSunday = entry.key == 0;
                return Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSunday ? const Color(0xFFF43F5E) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Grid Tanggal
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 0.82,
              ),
              itemCount: leadingBlanks + _hari.length,
              itemBuilder: (ctx, idx) {
                if (idx < leadingBlanks) {
                  return const SizedBox.shrink();
                }

                final dayIndex = idx - leadingBlanks;
                final item = _hari[dayIndex] as Map;
                final tgl = item['tanggal'] ?? (dayIndex + 1);
                final isSunday = (idx % 7) == 0;
                final isLibur = item['is_libur'] == true && item['sesi2'] == null;
                final namaShift = item['nama_shift']?.toString() ?? '-';
                final isPresent = item['absen_masuk'] != null;
                final isLate = ((item['terlambat_menit'] as int?) ?? 0) > 0;
                final hasLembur = item['lembur_masuk'] != null;
                final hasSesi2 = item['sesi2'] != null;
                final isToday = _isToday(tgl is int ? tgl : int.tryParse('$tgl') ?? 0);

                Color bgColor = Colors.white;
                Color borderColor = const Color(0xFFE2E8F0);
                Color textColor = isSunday && !isPresent ? const Color(0xFFF43F5E) : const Color(0xFF0F172A);

                if (isLibur) {
                  bgColor = const Color(0xFFF8FAFC);
                  borderColor = const Color(0xFFE2E8F0);
                  textColor = const Color(0xFF94A3B8);
                } else if (isPresent) {
                  if (isLate) {
                    bgColor = const Color(0xFFFFF1F2);
                    borderColor = const Color(0xFFFECDD3);
                  } else {
                    bgColor = const Color(0xFFECFDF5);
                    borderColor = const Color(0xFFA7F3D0);
                  }
                }

                return InkWell(
                  onTap: () => _showDetailModal(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? const Color(0xFF10B981) : borderColor,
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Angka Tanggal
                        Text(
                          '$tgl',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),

                        // Nama Shift
                        Text(
                          isLibur ? 'OFF' : (namaShift.isNotEmpty ? namaShift : '-'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isLibur
                                ? const Color(0xFF94A3B8)
                                : (isPresent
                                    ? (isLate ? const Color(0xFFBE123C) : const Color(0xFF047857))
                                    : const Color(0xFF475569)),
                          ),
                        ),

                        // Dots Indikator (Tepat/Telat, Lembur, Sesi 2)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isPresent)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                decoration: BoxDecoration(
                                  color: isLate ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasLembur)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasSesi2)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= VIEW 2: MATRIKS TABEL DETAIL (HORIZONTAL SCROLL) =================
  Widget _buildMatrixTableView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _labelCell('Tanggal', header: true),
                  _labelCell('Jam Masuk', sub: '(jadwal)'),
                  _labelCell('Jam Keluar', sub: '(jadwal)'),
                  _labelCell('Absen Masuk', sub: '(aktual)'),
                  _labelCell('Absen Pulang', sub: '(aktual)'),
                  _labelCell('Lembur/On-Call', sub: 'Masuk'),
                  _labelCell('Lembur/On-Call', sub: 'Keluar'),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      // BARIS TANGGAL & HARI
                      _buildRow((i) {
                        final d = _day(i);
                        final libur = d?['is_libur'] == true && d?['sesi2'] == null;
                        final tgl = '${d?['tanggal'] ?? (i + 1)}';
                        final hariNama = d?['hari_nama']?.toString() ?? '';
                        if (hariNama.isNotEmpty) {
                          return _twoLineCell(
                            tgl,
                            hariNama,
                            bg: libur ? _cLibur : _cJadwal,
                            fg: libur ? AppColors.textHint : AppColors.textPrimary,
                            subFg: libur ? AppColors.textHint : AppColors.primary,
                            subBold: true,
                          );
                        }
                        return _gridCell(
                          tgl,
                          bold: true,
                          bg: libur ? _cLibur : _cJadwal,
                          fg: libur ? AppColors.textHint : AppColors.textPrimary,
                        );
                      }),
                      _buildRow((i) => _jadwalCell(_day(i), 'jam_masuk')),
                      _buildRow((i) => _jadwalCell(_day(i), 'jam_pulang')),
                      _buildRow((i) => _absenMasukCell(_day(i))),
                      _buildRow((i) => _absenPulangCell(_day(i))),
                      _buildRow((i) => _lemburMasukCell(_day(i))),
                      _buildRow((i) => _lemburPulangCell(_day(i))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Widget Function(int index) cellBuilder) {
    return Row(
      children: List.generate(
        _jumlahHari,
        (i) => cellBuilder(i),
      ),
    );
  }

  Widget _jadwalCell(Map? d, String key) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    if (d['is_libur'] == true && d['sesi2'] == null) return _liburCell();

    final s2 = d['sesi2'] as Map?;
    final v1 = (d[key] ?? '-').toString();
    final v2 = s2?[key]?.toString();

    if (v2 != null) {
      return _twoLineCell(
        v1,
        '②$v2',
        bg: _cJadwal,
        fg: AppColors.textPrimary,
        subFg: const Color(0xFF7C3AED),
        subBold: true,
      );
    }
    return _gridCell(v1);
  }

  Widget _absenMasukCell(Map? d) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    if (d['is_libur'] == true && d['sesi2'] == null) {
      return _gridCell('-', fg: AppColors.textHint);
    }

    final s2 = d['sesi2'] as Map?;
    final v1 = d['absen_masuk'];
    final t1 = (d['terlambat_menit'] as int?) ?? 0;

    Color? bg1;
    if (v1 != null) bg1 = t1 > 0 ? _cTelat : _cTepat;

    if (s2 == null) {
      if (v1 == null) return _gridCell('-', fg: AppColors.textHint);
      return _gridCell(
        t1 > 0 ? '$v1 +$t1 m' : v1.toString(),
        bold: true,
        bg: bg1,
        fg: t1 > 0 ? AppColors.error : AppColors.success,
      );
    }

    final v2 = s2['absen_masuk'];
    final t2 = (s2['terlambat_menit'] as int?) ?? 0;
    return _twoLineCell(
      v1 == null ? '-' : (t1 > 0 ? '$v1 +$t1 m' : v1.toString()),
      v2 == null ? '②-' : (t2 > 0 ? '②$v2 +$t2 m' : '②$v2'),
      bg: bg1,
      fg: v1 == null ? AppColors.textHint : (t1 > 0 ? AppColors.error : AppColors.success),
      subFg: v2 == null ? AppColors.textHint : (t2 > 0 ? AppColors.error : AppColors.success),
      bold: true,
      subBold: true,
    );
  }

  Widget _absenPulangCell(Map? d) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    if (d['is_libur'] == true && d['sesi2'] == null) {
      return _gridCell('-', fg: AppColors.textHint);
    }

    final s2 = d['sesi2'] as Map?;
    final v1 = d['absen_pulang'];
    final s1 = d['pulang_cepat_menit'] as int? ?? 0;

    Color? bg1;
    if (v1 != null) bg1 = s1 > 0 ? _cTelat : _cTepat;

    if (s2 == null) {
      if (v1 == null) return _gridCell('-', fg: AppColors.textHint);
      return _gridCell(
        v1.toString(),
        bold: true,
        bg: bg1,
        fg: s1 > 0 ? AppColors.error : AppColors.success,
      );
    }

    final v2 = s2['absen_pulang'];
    return _twoLineCell(
      v1 == null ? '-' : v1.toString(),
      v2 == null ? '②-' : '②$v2',
      bg: bg1,
      fg: v1 == null ? AppColors.textHint : AppColors.success,
      subFg: v2 == null ? AppColors.textHint : AppColors.success,
      bold: true,
      subBold: true,
    );
  }

  Widget _lemburMasukCell(Map? d) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    final lm = d['lembur_masuk'];
    if (lm == null) return _gridCell('-', fg: AppColors.textHint);
    return _gridCell(lm.toString(), bg: _cLembur, fg: const Color(0xFF2563EB), bold: true);
  }

  Widget _lemburPulangCell(Map? d) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    final lp = d['lembur_pulang'];
    if (lp == null) return _gridCell('-', fg: AppColors.textHint);
    return _gridCell(lp.toString(), bg: _cLembur, fg: const Color(0xFF2563EB), bold: true);
  }

  Widget _liburCell() {
    return Container(
      width: _colW,
      height: _rowH,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: const Text('Libur', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
    );
  }

  Widget _gridCell(
    String text, {
    bool bold = false,
    Color? bg,
    Color? fg,
  }) {
    return Container(
      width: _colW,
      height: _rowH,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: fg ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _twoLineCell(
    String top,
    String bot, {
    Color? bg,
    Color? fg,
    Color? subFg,
    bool bold = false,
    bool subBold = false,
  }) {
    return Container(
      width: _colW,
      height: _rowH,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            top,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: fg ?? const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            bot,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: subBold ? FontWeight.w700 : FontWeight.normal,
              color: subFg ?? const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelCell(String label, {String? sub, bool header = false}) {
    return Container(
      width: _labelW,
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF8FAFC) : Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: header ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }
}
