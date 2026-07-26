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

  // ukuran tabel
  static const double _rowH = 46;
  static const double _colW = 58;
  static const double _labelW = 150;
  static const Color _line = AppColors.border;

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
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Jadwal Dinas Bulanan')),
      body: Column(
        children: [
          // navigasi bulan
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _change(-1),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    monthLabel[0].toUpperCase() + monthLabel.substring(1),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _change(1),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // legenda
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                _legendDot(AppColors.error.withValues(alpha: 0.12), 'Libur'),
                const SizedBox(width: 14),
                _legendDot(
                  AppColors.success.withValues(alpha: 0.16),
                  'Ada Lembur/On-Call',
                ),
                const SizedBox(width: 14),
                _legendDot(
                  AppColors.primary.withValues(alpha: 0.10),
                  'Jadwal Shift',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  )
                : _hari.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada data jadwal.',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== KOLOM LABEL (tetap di kiri) =====
                        Column(
                          children: [
                            _labelCell('Tanggal', header: true),
                            _labelCell('Jam Masuk', sub: '(ikut jadwal)'),
                            _labelCell('Jam Keluar', sub: '(ikut jadwal)'),
                            _labelCell('Lembur/On-Call', sub: 'Masuk'),
                            _labelCell('Lembur/On-Call', sub: 'Keluar'),
                          ],
                        ),
                        // ===== GRID TANGGAL (geser horizontal) =====
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              children: [
                                // baris 0: angka tanggal
                                _buildRow((i) {
                                  final d = _day(i);
                                  final libur = d?['is_libur'] == true;
                                  return _gridCell(
                                    '${d?['tanggal'] ?? (i + 1)}',
                                    bold: true,
                                    bg: libur
                                        ? AppColors.error.withValues(
                                            alpha: 0.06,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                    fg: libur
                                        ? AppColors.textHint
                                        : AppColors.textPrimary,
                                  );
                                }),
                                // baris 1: jam masuk shift / Libur
                                _buildRow((i) {
                                  final d = _day(i);
                                  if (d?['is_libur'] == true)
                                    return _liburCell();
                                  return _gridCell(
                                    (d?['jam_masuk'] ?? '-').toString(),
                                  );
                                }),
                                // baris 2: jam keluar shift / Libur
                                _buildRow((i) {
                                  final d = _day(i);
                                  if (d?['is_libur'] == true)
                                    return _liburCell();
                                  return _gridCell(
                                    (d?['jam_keluar'] ?? '-').toString(),
                                  );
                                }),
                                // baris 3: lembur/oncall masuk
                                _buildRow((i) {
                                  final d = _day(i);
                                  final v = d?['lembur_masuk'];
                                  return _gridCell(
                                    (v ?? '-').toString(),
                                    bg: v != null
                                        ? AppColors.success.withValues(
                                            alpha: 0.14,
                                          )
                                        : null,
                                    fg: v != null
                                        ? AppColors.success
                                        : AppColors.textHint,
                                  );
                                }),
                                // baris 4: lembur/oncall keluar
                                _buildRow((i) {
                                  final d = _day(i);
                                  final v = d?['lembur_keluar'];
                                  return _gridCell(
                                    (v ?? '-').toString(),
                                    bg: v != null
                                        ? AppColors.success.withValues(
                                            alpha: 0.14,
                                          )
                                        : null,
                                    fg: v != null
                                        ? AppColors.success
                                        : AppColors.textHint,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // satu baris grid = N sel tanggal
  Widget _buildRow(Widget Function(int i) cellBuilder) {
    return Row(children: List.generate(_jumlahHari, (i) => cellBuilder(i)));
  }

  Widget _gridCell(String text, {bool bold = false, Color? bg, Color? fg}) {
    return Container(
      width: _colW,
      height: _rowH,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
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

  Widget _liburCell() {
    return Container(
      width: _colW,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: _line, width: 0.5),
      ),
      child: const Text(
        'Libur',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: AppColors.error,
        ),
      ),
    );
  }

  Widget _labelCell(String text, {String? sub, bool header = false}) {
    return Container(
      width: _labelW,
      height: _rowH,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: header
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.white,
        border: Border.all(color: _line, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _legendDot(Color c, String label) {
    return Row(
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
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
