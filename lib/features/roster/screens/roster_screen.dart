import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'jadwal_dinas_screen.dart';

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  // Item yang sudah DINORMALISASI (key seragam, aman di-render)
  List<Map<String, String>> _rosters = [];
  bool _loading = true;
  String? _error;

  // Dump JSON mentah — hanya ditampilkan bila parsing gagal total (mode debug)
  String? _rawDump;

  late DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _fetchRoster();
  }

  Future<void> _fetchRoster() async {
    setState(() {
      _loading = true;
      _error = null;
      _rawDump = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get(
        '/roster/unit',
        query: {'bulan': _selected.month, 'tahun': _selected.year},
      );

      // Cetak FULL JSON ke console (untuk diagnosa via terminal)
      debugPrint('[ROSTER] RESPONSE = ${jsonEncode(res)}');

      if (res['success'] == true) {
        final items = _extractAndNormalize(res['data']);

        // Bila ada item tapi SEMUA field-nya kosong → struktur tak dikenal:
        // tampilkan JSON mentah di layar agar terlihat di screenshot.
        final allEmpty =
            items.isNotEmpty &&
            items.every(
              (m) =>
                  m['tanggal'] == '-' &&
                  m['namaShift'] == '-' &&
                  m['jamMasuk'] == '-' &&
                  m['jamPulang'] == '-',
            );

        setState(() {
          _rosters = items;
          if (allEmpty) {
            _rawDump = const JsonEncoder.withIndent('  ').convert(res['data']);
          }
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

  /// Menerima `data` bentuk apa pun (List / Map-bungkus / Map-tergroup-per-tanggal)
  /// lalu menormalisasi tiap item ke key seragam.
  List<Map<String, String>> _extractAndNormalize(dynamic data) {
    final out = <Map<String, String>>[];

    void addFromMap(Map m, [String? groupKey]) {
      out.add(_normalize(m, groupKey));
    }

    void addFromList(List list, [String? groupKey]) {
      for (final e in list) {
        if (e is Map) {
          addFromMap(e, groupKey);
        }
      }
    }

    if (data is List) {
      addFromList(data);
    } else if (data is Map) {
      // 1) Pembungkus eksplisit berisi List
      const wrapKeys = [
        'rosters',
        'jadwal',
        'jadwals',
        'data',
        'items',
        'list',
        'schedules',
        'rows',
        'result',
      ];
      bool handled = false;
      for (final k in wrapKeys) {
        if (data[k] is List) {
          addFromList(data[k] as List);
          handled = true;
          break;
        }
      }

      if (!handled) {
        // 2) Group per tanggal: { "2026-07-23": {...} } atau { "2026-07-23": [ {...} ] }
        //    → key luar dipakai sebagai tanggal bila item tak punya tanggal sendiri.
        for (final entry in data.entries) {
          final v = entry.value;
          final keyStr = entry.key.toString();
          if (v is List) {
            addFromList(v, keyStr);
          } else if (v is Map) {
            addFromMap(v, keyStr);
          }
        }
      }
    }

    return out;
  }

  /// Seragamkan nama field dari berbagai kemungkinan struktur backend.
  Map<String, String> _normalize(Map r, [String? groupKey]) {
    final shiftObj = (r['shift'] is Map)
        ? r['shift'] as Map
        : (r['master_shift'] is Map)
        ? r['master_shift'] as Map
        : (r['shift_data'] is Map)
        ? r['shift_data'] as Map
        : null;

    String pick(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c != null && c.toString().isNotEmpty) return c.toString();
      }
      return '-';
    }

    final tanggal = pick([
      r['tanggal_dinas'],
      r['tanggal'],
      r['date'],
      r['tgl'],
      r['tanggal_roster'],
      groupKey,
    ]);

    final namaShift = pick([
      r['nama_shift'],
      r['shift_nama'],
      r['shift_name'],
      r['namaShift'],
      shiftObj?['nama_shift'],
      shiftObj?['nama'],
      shiftObj?['name'],
      shiftObj?['namaShift'],
    ]);

    final jamMasuk = pick([
      r['jam_masuk'],
      r['waktu_masuk'],
      r['jamMasuk'],
      shiftObj?['jam_masuk'],
      shiftObj?['waktu_masuk'],
      shiftObj?['jamMasuk'],
    ]);

    final jamPulang = pick([
      r['jam_pulang'],
      r['waktu_pulang'],
      r['jamPulang'],
      shiftObj?['jam_pulang'],
      shiftObj?['waktu_pulang'],
      shiftObj?['jamPulang'],
    ]);

    return {
      'tanggal': tanggal,
      'namaShift': namaShift,
      'jamMasuk': jamMasuk,
      'jamPulang': jamPulang,
    };
  }

  String _formatTanggal(String raw) {
    if (raw == '-') return '-';
    try {
      final d = DateTime.parse(raw);
      final s = DateFormat('EEE, d MMM', 'id_ID').format(d);
      return s[0].toUpperCase() + s.substring(1);
    } catch (_) {
      return raw; // bila format tak standar, tampilkan apa adanya
    }
  }

  void _changeMonth(int delta) {
    setState(
      () => _selected = DateTime(_selected.year, _selected.month + delta),
    );
    _fetchRoster();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selected);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Jadwal Roster'),
        actions: [
          IconButton(
            tooltip: 'Tabel Jadwal Bulanan',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JadwalDinasScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigasi bulan
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
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
                // === MODE DEBUG: tampilkan JSON mentah bila parse gagal total ===
                : _rawDump != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'Struktur API belum dikenali. Kirim screenshot ini:\n\n$_rawDump',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : _rosters.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada jadwal untuk bulan ini.',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchRoster,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rosters.length,
                      itemBuilder: (ctx, i) {
                        final r = _rosters[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatTanggal(r['tanggal']!),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r['namaShift']} • ${r['jamMasuk']} - ${r['jamPulang']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
