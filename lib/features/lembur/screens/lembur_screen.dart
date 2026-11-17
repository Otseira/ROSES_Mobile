import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/image_compressor.dart';
import '../../auth/providers/auth_provider.dart';
import 'validasi_lembur_screen.dart';
import 'riwayat_lembur_screen.dart';

class LemburScreen extends ConsumerStatefulWidget {
  const LemburScreen({super.key});
  @override
  ConsumerState<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends ConsumerState<LemburScreen> {
  final _locationService = LocationService();
  bool _processing = false;
  bool _loading = true;
  Map<String, dynamic>? _onCallAktif;

  // 0 = Lembur & On-Call, 1 = Bank Jam Lembur (Identik SIRO Web)
  int _subTab = 0;

  // Riwayat Pengajuan Lembur / On-Call
  List<dynamic> _riwayatLembur = [];
  bool _loadingRiwayat = true;
  String? _errorRiwayat;
  String _filterStatus = 'Semua'; // 'Semua', 'Pending', 'Disetujui', 'Ditolak'

  // ===== BANK JAM LEMBUR & PENGAMBILAN JAM =====
  Map<String, dynamic>? _bankJam;
  List<dynamic> _riwayatAmbilJam = [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _cekOnCallAktif(),
      _fetchRiwayatLembur(),
      _fetchBankJam(),
      _fetchRiwayatAmbilJam(),
    ]);
  }

  Future<void> _fetchBankJam() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/lembur/bank-jam');
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _bankJam = res['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchRiwayatAmbilJam() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/lembur/riwayat-ambil-jam');
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _riwayatAmbilJam = (res['data'] as List?) ?? []);
      }
    } catch (_) {}
  }

  Future<void> _cekOnCallAktif() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/lembur/oncall-aktif');
      if (!mounted) return;
      setState(() {
        _onCallAktif = (res['success'] == true) ? res['data'] : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchRiwayatLembur() async {
    if (!mounted) return;
    setState(() {
      _loadingRiwayat = true;
      _errorRiwayat = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/lembur/riwayat');
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _riwayatLembur = (res['data'] as List?) ?? [];
        });
      } else {
        setState(() {
          _errorRiwayat =
              res['message']?.toString() ?? 'Gagal memuat riwayat pengajuan.';
        });
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '').trim();
        setState(() {
          _errorRiwayat =
              errText.isNotEmpty ? errText : 'Gagal memuat riwayat pengajuan.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRiwayat = false);
      }
    }
  }

  Future<dynamic> _ambilLokasi() async {
    final loc = await _locationService.getFastLocation();
    if (!loc.success) {
      if (mounted) {
        if (loc.isMocked) {
          _showMockDialog(loc.mockDetails, loc.error);
        } else {
          _snack(loc.error ?? 'Lokasi gagal diambil.');
        }
      }
      return null;
    }
    return loc;
  }

  void _showMockDialog(Map<String, bool>? details, [String? message]) {
    final labels = {
      'mock_enabled': 'Fitur Mock Location aktif',
      'mock_apps': 'Aplikasi Fake GPS terpasang',
      'geolocator': 'Lokasi dilaporkan tiruan (Mock)',
      'device_rooted': 'Perangkat di-root / Jailbreak',
      'emulator': 'Aplikasi di emulator/PC',
      'developer_mode': 'Opsi Pengembang (Developer) aktif',
      'consistency': 'Lonjakan koordinat tidak wajar',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.gps_off, color: AppColors.error, size: 48),
        title: const Text(
          'Lokasi Palsu Terdeteksi',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ??
                  'Sistem mendeteksi penggunaan Fake GPS.\nPengajuan lembur tidak dapat dilanjutkan.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              ...details.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        e.value
                            ? Icons.warning_rounded
                            : Icons.check_circle_rounded,
                        size: 16,
                        color: e.value ? AppColors.error : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          labels[e.key] ?? e.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                e.value ? FontWeight.w600 : FontWeight.normal,
                            color: e.value
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        e.value ? "Terdeteksi" : "Aman",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: e.value ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ================= EKSTENSI SHIFT =================
  Future<void> _alurEkstensi() async {
    if (_processing) return;

    Map<String, dynamic>? shiftInfo;
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/absensi/info-shift');
      if (res['success'] == true) shiftInfo = res['data'];
    } catch (_) {}

    if (shiftInfo == null) {
      _snack('Anda tidak memiliki jadwal shift hari ini. Gunakan On-Call.');
      return;
    }
    final int maxMenit = (shiftInfo['max_menit'] as int?) ?? 0;
    if (maxMenit < 30) {
      _snack(
        'Ekstensi shift baru dapat diajukan minimal 30 menit setelah jam pulang (${shiftInfo['jam_pulang']}).',
      );
      return;
    }

    final form = await _showFormEkstensi(shiftInfo);
    if (form == null || !mounted) return;

    final loc = await _ambilLokasi();
    if (loc == null || !mounted) return;

    final foto = await Navigator.of(context, rootNavigator: true).push<File>(
      MaterialPageRoute(
        builder: (_) => const _CameraPage(label: 'Foto Bukti Lembur'),
      ),
    );
    if (foto == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final compressedFoto = await ImageCompressor.compressFile(foto);
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/lembur/ekstensi',
        fields: {
          'keterangan': form['keterangan'],
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
          'durasi_menit': form['durasi'].toString(),
          'accuracy': loc.accuracy?.toString() ?? '',
          'is_mock': loc.isMocked ? '1' : '0',
        },
        files: {'foto_masuk': compressedFoto},
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(authStateProvider);
        _fetchRiwayatLembur();
        await _showSuksesDialog(
          'Ekstensi Shift',
          res['data'],
          form['keterangan'],
        );
      } else {
        _snack(res['message'] ?? 'Gagal menyimpan lembur.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ================= ON-CALL MASUK =================
  Future<void> _alurOnCallMasuk() async {
    if (_processing) return;

    final ket = await _showKeteranganDialog();
    if (ket == null || !mounted) return;

    final loc = await _ambilLokasi();
    if (loc == null || !mounted) return;

    final foto = await Navigator.of(context, rootNavigator: true).push<File>(
      MaterialPageRoute(
        builder: (_) => const _CameraPage(label: 'Foto On-Call Masuk'),
      ),
    );
    if (foto == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final compressedFoto = await ImageCompressor.compressFile(foto);
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/lembur/oncall-masuk',
        fields: {
          'keterangan': ket,
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
          'accuracy': loc.accuracy?.toString() ?? '',
          'is_mock': loc.isMocked ? '1' : '0',
        },
        files: {'foto_masuk': compressedFoto},
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _fetchRiwayatLembur();
        await _showPesanDialog(
          'On-Call Masuk Tercatat ✓',
          'Mulai On-Call: ${res['data']['waktu_mulai']}\nKasus: $ket\n\nJangan lupa lakukan On-Call Keluar saat tugas selesai.',
        );
        _cekOnCallAktif();
      } else {
        _snack(res['message'] ?? 'Gagal memulai On-Call.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ================= ON-CALL KELUAR =================
  Future<void> _alurOnCallKeluar() async {
    if (_processing || _onCallAktif == null) return;

    final mulai = DateFormat(
      'HH:mm',
    ).format(DateTime.parse(_onCallAktif!['waktu_mulai_lembur']));

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.phone_callback_outlined,
          color: Color(0xFF2563EB),
          size: 44,
        ),
        title: const Text('Selesaikan On-Call?'),
        content: Text(
          'Sesi On-Call Anda dimulai pukul $mulai WIB.\n\nDurasi akan dihitung otomatis sampai sekarang, dan jam dinas Anda akan diakhiri otomatis jika belum absen pulang.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final loc = await _ambilLokasi();
    if (loc == null || !mounted) return;

    final foto = await Navigator.of(context, rootNavigator: true).push<File>(
      MaterialPageRoute(
        builder: (_) => const _CameraPage(label: 'Foto On-Call Keluar'),
      ),
    );
    if (foto == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final compressedFoto = await ImageCompressor.compressFile(foto);
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/lembur/oncall-keluar',
        fields: {
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
          'accuracy': loc.accuracy?.toString() ?? '',
          'is_mock': loc.isMocked ? '1' : '0',
        },
        files: {'foto_keluar': compressedFoto},
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(authStateProvider);
        _fetchRiwayatLembur();
        await _showSuksesDialog(
          'On-Call',
          res['data'],
          _onCallAktif?['keterangan'] ?? '',
        );
        _cekOnCallAktif();
      } else {
        _snack(res['message'] ?? 'Gagal menyelesaikan On-Call.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ================= DIALOGS =================
  Future<Map<String, dynamic>?> _showFormEkstensi(
    Map<String, dynamic> shiftInfo,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EkstensiFormDialog(shiftInfo: shiftInfo),
    );
  }

  Future<String?> _showKeteranganDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _KeteranganDialog(
        title: 'On-Call Masuk',
        hintText: 'Kasus / alasan on-call…',
        themeColor: Color(0xFF2563EB),
      ),
    );
  }

  Future<void> _showSuksesDialog(
    String jenis,
    Map<String, dynamic> data,
    String keterangan,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.verified, color: AppColors.success, size: 52),
        title: const Text('Selesai Tercatat!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data['auto_clock_out'] == true) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Absen pulang otomatis tercatat',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Pengajuan $jenis Anda berhasil dicatat dan menunggu verifikasi atasan.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPesanDialog(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 48),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  List<dynamic> get _filteredRiwayat {
    if (_filterStatus == 'Semua') return _riwayatLembur;
    return _riwayatLembur.where((item) {
      final s = (item['status_validasi'] ?? item['status'] ?? '').toString().toLowerCase();
      return s == _filterStatus.toLowerCase();
    }).toList();
  }

  Future<void> _showFormPengambilanJam() async {
    final saldoTersedia =
        (_bankJam?['saldo_menit_tersedia'] as num?)?.toInt() ?? 0;
    if (saldoTersedia < 15) {
      _snack('Saldo bank jam Anda tidak mencukupi (minimal 15 menit).');
      return;
    }

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PengambilanJamDialog(
        saldoTersediaMenit: saldoTersedia,
        saldoTersediaTeks: '$saldoTersedia Menit',
      ),
    );

    if (res == true && mounted) {
      _refreshAll();
      _snack('Pengajuan pengambilan waktu lembur berhasil dikirim.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authNotifierProvider).user;
    final storedUser = ref.watch(authStateProvider).value;
    final freshUser = ref.watch(freshProfileProvider).value;
    final user = freshUser ?? storedUser ?? authUser;
    final canValidasi = user?.canValidasi == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lembur & Bank Jam',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          if (canValidasi)
            IconButton(
              icon: const Icon(Icons.fact_check_rounded, color: AppColors.primary),
              tooltip: 'Validasi Lembur',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ValidasiLemburScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _loading || _processing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===================================================================
                    // SEGMENTED TAB HEADER (IDENTIK DENGAN SIRO WEB)
                    // ===================================================================
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _subTab = 0),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _subTab == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _subTab == 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  'Lembur & On-Call',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _subTab == 0
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _subTab = 1),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _subTab == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _subTab == 1
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  'Bank Jam Lembur',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _subTab == 1
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ===================================================================
                    // SUB-TAB 0: LEMBUR & ON-CALL
                    // ===================================================================
                    if (_subTab == 0) ...[
                      // Banner On-Call Aktif
                      if (_onCallAktif != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ON-CALL SEDANG BERJALAN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Mulai: ${DateFormat('HH:mm').format(DateTime.parse(_onCallAktif!['waktu_mulai_lembur']))} WIB',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _alurOnCallKeluar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFEA580C),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Akhiri On-Call',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Grid 2 Tombol Aksi Utama (Ajukan Ekstensi & Mulai On-Call)
                      Row(
                        children: [
                          Expanded(
                            child: _LemburActionCard(
                              title: 'Ajukan Ekstensi',
                              subtitle: 'Lanjutan dinas shift',
                              icon: Icons.add_circle_outline_rounded,
                              gradientColors: const [
                                Color(0xFF6366F1), // indigo-500
                                Color(0xFF10B981), // emerald-500
                              ],
                              shadowColor: const Color(0xFF6366F1).withOpacity(0.25),
                              onTap: _alurEkstensi,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LemburActionCard(
                              title: 'Mulai On-Call',
                              subtitle: 'Panggilan darurat RS',
                              icon: Icons.phone_in_talk_rounded,
                              gradientColors: const [
                                Color(0xFF3B82F6), // blue-500
                                Color(0xFF06B6D4), // cyan-500
                              ],
                              shadowColor: const Color(0xFF3B82F6).withOpacity(0.25),
                              onTap: _onCallAktif != null ? _alurOnCallKeluar : _alurOnCallMasuk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Kartu Riwayat Pengajuan Lembur
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'RIWAYAT PENGAJUAN LEMBUR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  color: AppColors.primary,
                                  onPressed: _fetchRiwayatLembur,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Filter Status Chip
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['Semua', 'Pending', 'Disetujui', 'Ditolak'].map((st) {
                                  final isSel = _filterStatus == st;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(st, style: const TextStyle(fontSize: 11)),
                                      selected: isSel,
                                      selectedColor: const Color(0xFFECFDF5),
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      labelStyle: TextStyle(
                                        color: isSel ? const Color(0xFF047857) : const Color(0xFF64748B),
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isSel ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      onSelected: (_) => setState(() => _filterStatus = st),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // List Data
                            if (_loadingRiwayat)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_filteredRiwayat.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Belum ada riwayat pengajuan lembur.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredRiwayat.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final it = _filteredRiwayat[i] as Map;
                                  final jenis = it['jenis_lembur']?.toString() ?? 'Lembur';
                                  final status = it['status_validasi'] ?? it['status'] ?? 'Pending';
                                  final alasan = it['alasan_lembur'] ?? it['keterangan'] ?? '-';
                                  final tgl = it['tanggal_lembur'] ?? it['tanggal'] ?? '-';
                                  final mulai = it['waktu_mulai'] ?? '-';
                                  final selesai = it['waktu_selesai'] ?? 'Aktif';

                                  Color statusBg = const Color(0xFFFEF3C7);
                                  Color statusFg = const Color(0xFFB45309);
                                  if (status == 'Disetujui') {
                                    statusBg = const Color(0xFFD1FAE5);
                                    statusFg = const Color(0xFF047857);
                                  } else if (status == 'Ditolak') {
                                    statusBg = const Color(0xFFFFE4E6);
                                    statusFg = const Color(0xFFBE123C);
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              jenis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                status.toString(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusFg,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          alasan.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              tgl.toString(),
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                            ),
                                            Text(
                                              '$mulai - $selesai',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],

                    // ===================================================================
                    // SUB-TAB 1: BANK JAM LEMBUR
                    // ===================================================================
                    if (_subTab == 1) ...[
                      // Hero Card Saldo Bank Jam Detail
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SALDO BANK JAM ANDA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFFFEF3C7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _bankJam != null
                                  ? (_bankJam!['saldo_jam_teks'] ?? '${_bankJam!['saldo_menit_tersedia'] ?? 0} Menit')
                                  : '0 Jam 0 Menit',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Diperoleh',
                                        style: TextStyle(fontSize: 10, color: Color(0xFFFEF3C7)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _bankJam != null
                                            ? (_bankJam!['total_lembur_disetujui_teks'] ?? '0 Jam')
                                            : '0 Jam',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Telah Digunakan',
                                        style: TextStyle(fontSize: 10, color: Color(0xFFFEF3C7)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _bankJam != null
                                            ? (_bankJam!['total_pengambilan_teks'] ?? '0 Jam')
                                            : '0 Jam',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tombol Ajukan Pengambilan Saldo Jam
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showFormPengambilanJam,
                          icon: const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFFB45309)),
                          label: const Text(
                            'Ajukan Pengambilan Saldo Jam (Time-Off)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Kartu Riwayat Pengambilan Saldo Jam
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RIWAYAT PENGAMBILAN SALDO JAM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_riwayatAmbilJam.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Belum ada riwayat pengambilan saldo jam.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _riwayatAmbilJam.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final it = _riwayatAmbilJam[i] as Map;
                                  final durasi = it['durasi_teks'] ?? '${it["durasi_menit"]} Menit';
                                  final status = it['status_validasi'] ?? it['status'] ?? 'Pending';
                                  final alasan = it['alasan'] ?? '-';
                                  final tgl = it['tanggal_rencana'] ?? '-';

                                  Color statusBg = const Color(0xFFFEF3C7);
                                  Color statusFg = const Color(0xFFB45309);
                                  if (status == 'Disetujui') {
                                    statusBg = const Color(0xFFD1FAE5);
                                    statusFg = const Color(0xFF047857);
                                  } else if (status == 'Ditolak') {
                                    statusBg = const Color(0xFFFFE4E6);
                                    statusFg = const Color(0xFFBE123C);
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              durasi.toString(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                status.toString(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusFg,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          alasan.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rencana: $tgl',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Tombol Riwayat Lengkap Periode Cut-Off (24 – 23)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiwayatLemburScreen(
                              bankJam: _bankJam,
                              riwayatLemburAwal: _riwayatLembur,
                              riwayatAmbilJamAwal: _riwayatAmbilJam,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text(
                        'Riwayat Lembur (Periode Cut-Off 24 – 23)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Widget Card Aksi Lembur (Besar, Gradien, Shadow)
class _LemburActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _LemburActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===================================================================
/// HELPER DIALOGS & CAMERA PAGE
/// ===================================================================
class _CameraPage extends StatefulWidget {
  final String label;
  const _CameraPage({required this.label});
  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> {
  final _camera = CameraService();
  bool _ready = false;
  bool _isMirrored = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _camera.init(frontCamera: true);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal mengakses kamera.');
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ready && _camera.controller != null)
                    _isMirrored
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(3.1415926535897932),
                            child: CameraPreview(_camera.controller!),
                          )
                        : CameraPreview(_camera.controller!)
                  else if (_error != null)
                    Center(
                      child: Text(_error!, style: const TextStyle(color: Colors.white)),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() => _isMirrored = !_isMirrored);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isMirrored ? Icons.flip_camera_android : Icons.sync_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isMirrored ? 'Cermin: Aktif' : 'Cermin: Nonaktif',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black,
              child: Center(
                child: FloatingActionButton.large(
                  backgroundColor: AppColors.primary,
                  onPressed: !_ready
                      ? null
                      : () async {
                          try {
                            final f = await _camera.capture(mirror: _isMirrored);
                            if (mounted) Navigator.pop(context, f);
                          } catch (_) {}
                        },
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EkstensiFormDialog extends StatefulWidget {
  final Map<String, dynamic> shiftInfo;
  const _EkstensiFormDialog({required this.shiftInfo});
  @override
  State<_EkstensiFormDialog> createState() => _EkstensiFormDialogState();
}

class _EkstensiFormDialogState extends State<_EkstensiFormDialog> {
  final _ctrl = TextEditingController();
  int _durasi = 60;

  @override
  Widget build(BuildContext context) {
    final maxMenit = (widget.shiftInfo['max_menit'] as int?) ?? 180;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Ajukan Ekstensi Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Durasi Lembur:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [30, 60, 90, 120, 180].where((d) => d <= maxMenit).map((d) {
                final isSel = _durasi == d;
                return ChoiceChip(
                  label: Text('$d Menit', style: const TextStyle(fontSize: 11)),
                  selected: isSel,
                  selectedColor: AppColors.primarySoft,
                  onSelected: (_) => setState(() => _durasi = d),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Alasan / Uraian Pekerjaan',
                hintText: 'Contoh: Melanjutkan tindakan pasien darurat',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, {'durasi': _durasi, 'keterangan': _ctrl.text.trim()});
          },
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}

class _KeteranganDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final Color themeColor;
  const _KeteranganDialog({required this.title, required this.hintText, required this.themeColor});
  @override
  State<_KeteranganDialog> createState() => _KeteranganDialogState();
}

class _KeteranganDialogState extends State<_KeteranganDialog> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: TextField(
        controller: _ctrl,
        decoration: InputDecoration(hintText: widget.hintText),
        maxLines: 2,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, _ctrl.text.trim());
          },
          style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor),
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}

class _PengambilanJamDialog extends StatefulWidget {
  final int saldoTersediaMenit;
  final String saldoTersediaTeks;
  const _PengambilanJamDialog({required this.saldoTersediaMenit, required this.saldoTersediaTeks});
  @override
  State<_PengambilanJamDialog> createState() => _PengambilanJamDialogState();
}

class _PengambilanJamDialogState extends State<_PengambilanJamDialog> {
  final _alasanCtrl = TextEditingController();
  int _menit = 60;
  DateTime _tgl = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Pengambilan Saldo Jam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo Tersedia: ${widget.saldoTersediaTeks}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            TextField(
              controller: _alasanCtrl,
              decoration: const InputDecoration(labelText: 'Keperluan / Alasan'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () async {
            if (_alasanCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, true);
          },
          child: const Text('Kirim Pengajuan'),
        ),
      ],
    );
  }
}
