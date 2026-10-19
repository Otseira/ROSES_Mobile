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

  // Tinggi baris & lebar kolom untuk grid jadwal
  static const double _rowH = 58;
  static const double _colW = 64;
  static const double _labelW = 148;
  static const Color _line = AppColors.border;

  Color get _cJadwal => AppColors.primary.withOpacity(0.10);
  Color get _cLibur => AppColors.textHint.withOpacity(0.12);
  Color get _cTepat => AppColors.success.withOpacity(0.16);
  Color get _cTelat => AppColors.error.withOpacity(0.14);
  Color get _cLembur => AppColors.info.withOpacity(0.16);
  Color get _cS2 => const Color(0xFF5E35B1).withOpacity(0.14);

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

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_sel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Jadwal Dinas Bulanan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetch,
        child: Column(
          children: [
            // === 1. NAVIGASI BULAN MODERN ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                child: Row(
                  children: [
                    Material(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _change(-1),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            monthLabel[0].toUpperCase() + monthLabel.substring(1),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _change(1),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === 2. TABEL GRID JADWAL DINAS ===
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
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
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
                                      // BARIS TANGGAL
                                      _buildRow((i) {
                                        final d = _day(i);
                                        final libur =
                                            d?['is_libur'] == true &&
                                            d?['sesi2'] == null;
                                        return _gridCell(
                                          '${d?['tanggal'] ?? (i + 1)}',
                                          bold: true,
                                          bg: libur ? _cLibur : _cJadwal,
                                          fg: libur
                                              ? AppColors.textHint
                                              : AppColors.textPrimary,
                                        );
                                      }),
                                      // JAM MASUK (jadwal)
                                      _buildRow(
                                        (i) => _jadwalCell(_day(i), 'jam_masuk'),
                                      ),
                                      // JAM KELUAR (jadwal)
                                      _buildRow(
                                        (i) => _jadwalCell(_day(i), 'jam_keluar'),
                                      ),
                                      // ABSEN MASUK (aktual)
                                      _buildRow((i) => _absenMasukCell(_day(i))),
                                      // ABSEN PULANG (aktual)
                                      _buildRow((i) => _absenPulangCell(_day(i))),
                                      // LEMBUR MASUK
                                      _buildRow(
                                        (i) =>
                                            _lemburCell(_day(i), 'lembur_masuk'),
                                      ),
                                      // LEMBUR KELUAR
                                      _buildRow(
                                        (i) =>
                                            _lemburCell(_day(i), 'lembur_keluar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // === 3. KETERANGAN / LEGENDA DI BAGIAN BAWAH ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 88), // ruang ekstra untuk floating navbar
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Keterangan Warna Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _legendDot(
                          AppColors.success,
                          'Hijau: Sudah Absen / Tepat Waktu',
                          bold: true,
                        ),
                        _legendDot(
                          AppColors.error,
                          'Merah: Belum Absen / Terlambat',
                          bold: true,
                        ),
                        _legendDot(_cJadwal, 'Jadwal Shift'),
                        _legendDot(_cLibur, 'Libur'),
                        _legendDot(_cLembur, 'Lembur / On-Call'),
                        _legendDot(_cS2, 'Sesi 2 (②)'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SEL JADWAL (jam_masuk / jam_keluar)
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
        subFg: const Color(0xFF5E35B1),
        subBold: true,
      );
    }
    return _gridCell(v1);
  }

  // ABSEN MASUK — dengan dukungan sesi 2
  Widget _absenMasukCell(Map? d) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    if (d['is_libur'] == true && d['sesi2'] == null) {
      return _gridCell('-', fg: AppColors.textHint);
    }

    final s2 = d['sesi2'] as Map?;
    final v1 = d['absen_masuk'];
    final t1 = (d['terlambat_menit'] as int?) ?? 0;

    Widget sesi1() {
      if (v1 == null) {
        return const Text(
          '-',
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        );
      }
      final late = t1 > 0;
      return Text(
        late ? '$v1 +$t1 m' : v1.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: late ? AppColors.error : AppColors.success,
        ),
      );
    }

    Widget? sesi2() {
      if (s2 == null) return null;
      final v2 = s2['absen_masuk'];
      final t2 = (s2['terlambat_menit'] as int?) ?? 0;
      if (v2 == null) {
        return const Text(
          '②-',
          style: TextStyle(fontSize: 10, color: AppColors.textHint),
        );
      }
      final late = t2 > 0;
      return Text(
        late ? '②$v2 +$t2 m' : '②$v2',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: late ? AppColors.error : AppColors.success,
        ),
      );
    }

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

    return Container(
      width: _colW,
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: bg1 ?? Colors.white,
        border: Border.all(color: _line, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [sesi1(), const SizedBox(height: 2), sesi2()!],
      ),
    );
  }

  // ABSEN PULANG — dengan dukungan sesi 2
  Widget _absenPulangCell(Map? d) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);
    if (d['is_libur'] == true && d['sesi2'] == null) {
      return _gridCell('-', fg: AppColors.textHint);
    }

    final s2 = d['sesi2'] as Map?;
    final v1 = d['absen_pulang'];
    final v2 = s2?['absen_pulang']?.toString();

    if (v2 != null) {
      return _twoLineCell(
        (v1 ?? '-').toString(),
        '②$v2',
        bg: v1 != null ? _cTepat : null,
        fg: v1 != null ? AppColors.success : AppColors.textHint,
        subFg: const Color(0xFF5E35B1),
        subBold: true,
      );
    }

    if (v1 == null) return _gridCell('-', fg: AppColors.textHint);
    return _gridCell(
      v1.toString(),
      bold: true,
      bg: _cTepat,
      fg: AppColors.success,
    );
  }

  // LEMBUR MASUK / KELUAR
  Widget _lemburCell(Map? d, String key) {
    if (d == null) return _gridCell('-', fg: AppColors.textHint);

    final s2 = d['sesi2'] as Map?;
    final v1 = d[key];
    final v2 = s2?[key]?.toString();

    if (v2 != null) {
      return _twoLineCell(
        (v1 ?? '-').toString(),
        '②$v2',
        bg: _cLembur,
        fg: AppColors.textPrimary,
        subFg: const Color(0xFF5E35B1),
        subBold: true,
      );
    }

    if (v1 == null) return _gridCell('-', fg: AppColors.textHint);
    return _gridCell(
      v1.toString(),
      bold: true,
      bg: _cLembur,
      fg: AppColors.info,
    );
  }

  Widget _liburCell() {
    return Container(
      width: _colW,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cLibur,
        border: Border.all(color: _line, width: 0.5),
      ),
      child: const Text(
        'Libur',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Widget _twoLineCell(
    String line1,
    String line2, {
    Color? bg,
    Color? fg,
    Color? subFg,
    bool subBold = false,
  }) {
    return Container(
      width: _colW,
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: Border.all(color: _line, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            line1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: subBold ? FontWeight.w700 : FontWeight.w500,
              color: subFg ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Widget Function(int index) cellBuilder) {
    final count = _jumlahHari > 0 ? _jumlahHari : _hari.length;
    return Row(
      children: List.generate(count, (i) => cellBuilder(i)),
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
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: Border.all(color: _line, width: 0.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: fg ?? AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _labelCell(String text, {String? sub, bool header = false}) {
    return Container(
      width: _labelW,
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: header ? AppColors.primarySoft : Colors.white,
        border: Border.all(color: _line, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: header ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label, {bool bold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _line, width: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
