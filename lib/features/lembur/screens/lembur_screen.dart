import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/image_compressor.dart';
import '../../auth/providers/auth_provider.dart';

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

  // Riwayat Pengajuan Lembur / On-Call
  List<dynamic> _riwayatLembur = [];
  bool _loadingRiwayat = true;
  String? _errorRiwayat;
  String _filterStatus = 'Semua'; // 'Semua', 'Pending', 'Disetujui', 'Ditolak'

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _cekOnCallAktif(),
      _fetchRiwayatLembur(),
    ]);
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
      if (mounted) _snack(loc.error ?? 'Lokasi gagal diambil.');
      return null;
    }
    return loc;
  }

  // ================= EKSTENSI SHIFT (1x tekan, durasi default otomatis) =================
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
    if ((shiftInfo['max_menit'] ?? 0) < 1) {
      _snack(
        'Ekstensi shift baru bisa setelah jam pulang (${shiftInfo['jam_pulang']}).',
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

  // ================= ON-CALL MASUK (mirip absen masuk) =================
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

  // ================= ON-CALL KELUAR (menyerupai lembur) =================
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
          color: AppColors.info,
          size: 44,
        ),
        title: const Text('Selesaikan On-Call?'),
        content: Text(
          'Sesi On-Call Anda dimulai pukul $mulai.\n\nDurasi akan dihitung otomatis sampai sekarang, dan jam dinas Anda akan diakhiri otomatis jika belum absen pulang.',
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
              backgroundColor: AppColors.info,
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

  // ================= DIALOG & WIDGET =================
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
        themeColor: AppColors.info,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _InfoRow(label: 'Jenis', value: jenis),
            _InfoRow(label: 'Mulai', value: '${data['waktu_mulai']}'),
            _InfoRow(label: 'Selesai', value: '${data['waktu_selesai']}'),
            _InfoRow(
              label: 'Durasi',
              value: '${data['total_menit']} menit',
              highlight: true,
            ),
            if (keterangan.isNotEmpty)
              _InfoRow(label: 'Keterangan', value: keterangan),
            const SizedBox(height: 12),
            const Text(
              'Status: Menunggu validasi atasan',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
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
        icon: const Icon(Icons.check_circle, color: AppColors.info, size: 48),
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
      final s = (item['status']?.toString() ?? '').toLowerCase();
      return s == _filterStatus.toLowerCase();
    }).toList();
  }

  String _fmtWaktu(String? t) {
    if (t == null || t.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRiwayat;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lembur & On-Call',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 95), // ekstra padding untuk floating navbar
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== 1. HERO STATUS AKTIF =====
                    if (_onCallAktif != null) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.infoSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.info.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.phone_in_talk_rounded,
                                    color: AppColors.info,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Text(
                                            'On-Call Sedang Berjalan',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Mulai pukul ${DateFormat('HH:mm').format(DateTime.parse(_onCallAktif!['waktu_mulai_lembur']))} WIB',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.info,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _alurOnCallKeluar,
                                icon: const Icon(Icons.call_end_rounded, size: 20),
                                label: const Text(
                                  'Selesaikan Tugas On-Call',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.info,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ===== 2. KARTU MENU AKSI LEMBUR =====
                    const Text(
                      'Pilih Jenis Penugasan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Kartu 1: Ekstensi Shift
                    _MenuLemburCard(
                      icon: Icons.add_task_rounded,
                      title: 'Ekstensi Shift',
                      subtitle:
                          'Melanjutkan tugas setelah jam kerja shift reguler berakhir.',
                      color: AppColors.warning,
                      bgColor: AppColors.warningSoft,
                      onTap: _alurEkstensi,
                    ),
                    const SizedBox(height: 12),

                    // Kartu 2: On-Call Masuk (bila belum aktif)
                    if (_onCallAktif == null) ...[
                      _MenuLemburCard(
                        icon: Icons.phone_callback_rounded,
                        title: 'On-Call Masuk',
                        subtitle:
                            'Panggilan darurat / tugas khusus di luar jadwal kerja.',
                        color: AppColors.info,
                        bgColor: AppColors.infoSoft,
                        onTap: _alurOnCallMasuk,
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 14),

                    // ===== 3. RIWAYAT PENGAJUAN LEMBUR & ON-CALL =====
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Riwayat Pengajuan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_riwayatLembur.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_riwayatLembur.length} total',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Filter Status Chips: Semua, Pending, Disetujui, Ditolak
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Semua', 'Pending', 'Disetujui', 'Ditolak']
                            .map((s) {
                          final isSelected = _filterStatus == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              onSelected: (_) {
                                setState(() => _filterStatus = s);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Riwayat Content
                    if (_loadingRiwayat)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_errorRiwayat != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorRiwayat!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _fetchRiwayatLembur,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text(
                                'Coba Lagi',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 44,
                              color: AppColors.textHint.withOpacity(0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _filterStatus == 'Semua'
                                  ? 'Belum ada pengajuan lembur atau on-call.'
                                  : 'Tidak ada pengajuan dengan status "$_filterStatus".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final item = filtered[index] as Map;
                          return _buildRiwayatCard(item);
                        },
                      ),

                    const SizedBox(height: 20),

                    // ===== 4. KETERANGAN / LEGENDA DI BAGIAN BAWAH =====
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Keterangan Status Tugas',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Hijau
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Hijau',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  ': Sudah selesai / disetujui atasan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Kuning
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Kuning',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  ': Sedang aktif / menunggu verifikasi atasan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Merah
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Merah',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  ': Belum absen keluar / pengajuan ditolak',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRiwayatCard(Map item) {
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
    final bool isOnCall =
        jenis.toLowerCase().contains('on-call') || jenis.toLowerCase().contains('oncall');

    final String mulai = _fmtWaktu(item['waktu_mulai']?.toString());
    final String selesai = _fmtWaktu(item['waktu_selesai']?.toString());
    final String durasi = item['total_jam'] != null
        ? '${item['total_jam']} jam'
        : (item['durasi_menit'] != null ? '${item['durasi_menit']} mnt' : '-');

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
          // Header: Jenis Lembur & Status Badge
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
                    const SizedBox(width: 5),
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
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
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

          // Jadwal Waktu & Durasi
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Mulai: ',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    Expanded(
                      child: Text(
                        mulai,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Selesai: ',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    Expanded(
                      child: Text(
                        selesai,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Durasi: ',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    Expanded(
                      child: Text(
                        durasi,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Keterangan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  keterangan,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          // Catatan Validasi (bila ada)
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDitolak ? AppColors.errorSoft : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 14,
                    color: isDitolak ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Catatan Atasan: $catatan',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDitolak ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bukti Foto (jika ada URL foto)
          if (fotoMasuk != null || fotoKeluar != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (fotoMasuk != null)
                  _buildFotoThumb(fotoMasuk, 'Foto Masuk'),
                if (fotoKeluar != null) ...[
                  const SizedBox(width: 8),
                  _buildFotoThumb(fotoKeluar, 'Foto Selesai'),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFotoThumb(String url, String label) {
    return GestureDetector(
      onTap: () {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 50,
              height: 50,
              cacheWidth: 150,
              cacheHeight: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: AppColors.border,
                child: const Icon(
                  Icons.broken_image,
                  size: 20,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _MenuLemburCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _MenuLemburCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: highlight ? 14 : 12,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
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
  late final TextEditingController _durasiC;
  late final TextEditingController _ketC;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final maxMenit = (widget.shiftInfo['max_menit'] as int?) ?? 0;
    _durasiC = TextEditingController(text: maxMenit.toString());
    _ketC = TextEditingController();
  }

  @override
  void dispose() {
    _durasiC.dispose();
    _ketC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int maxMenit = (widget.shiftInfo['max_menit'] as int?) ?? 0;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.timer_outlined, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ekstensi Shift',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '⏱ Terisi otomatis: ${widget.shiftInfo['jam_pulang']} s/d sekarang ($maxMenit menit). Boleh diubah, rentang 1 – $maxMenit menit. Jam dinas Anda akan diakhiri otomatis.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Durasi Lembur (1 – $maxMenit menit)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _durasiC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.timer_outlined),
                  suffixText: 'menit',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null) return 'Wajib diisi angka';
                  if (n < 1) return 'Minimal 1 menit';
                  if (n > maxMenit) return 'Maksimal $maxMenit menit';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Keterangan Lembur',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ketC,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Menyelesaikan laporan stok obat…',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'durasi': int.parse(_durasiC.text),
                'keterangan': _ketC.text.trim(),
              });
            }
          },
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Lanjut Foto'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _KeteranganDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final Color themeColor;

  const _KeteranganDialog({
    required this.title,
    required this.hintText,
    required this.themeColor,
  });

  @override
  State<_KeteranganDialog> createState() => _KeteranganDialogState();
}

class _KeteranganDialogState extends State<_KeteranganDialog> {
  late final TextEditingController _ketC;

  @override
  void initState() {
    super.initState();
    _ketC = TextEditingController();
  }

  @override
  void dispose() {
    _ketC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.phone_callback_outlined, color: widget.themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _ketC,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.edit_note),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final t = _ketC.text.trim();
            if (t.isNotEmpty) {
              Navigator.pop(context, t);
            }
          },
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Lanjut Foto'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.themeColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _CameraPage extends StatefulWidget {
  final String label;
  const _CameraPage({required this.label});
  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> {
  final _cam = CameraService();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _cam.init(frontCamera: true).then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal inisialisasi kamera: $err')),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      final photo = await _cam.capture();
      if (mounted) Navigator.pop(context, File(photo.path));
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          (_ready && _cam.controller != null && _cam.controller!.value.isInitialized)
              ? CameraPreview(_cam.controller!)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '📸 ${widget.label}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _ready ? _capture : null,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Ambil Foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
