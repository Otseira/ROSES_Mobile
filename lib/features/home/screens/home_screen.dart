import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../absensi/screens/absensi_screen.dart';
import '../../lembur/screens/oncall_screen.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/branding_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;
  const HomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool _isMasukDone = false;
  String? _masukTime;
  bool _isPulangDone = false;
  String? _pulangTime;

  String? _shiftNama;
  String? _jamMasukJadwal;
  String? _jamPulangJadwal;
  String? _statusKehadiran;
  Map<String, dynamic>? _onCallAktif;

  int? _saldoBankJamMenit;
  String? _saldoBankJamTeks;
  bool _isLoadingBankJam = false;

  @override
  void initState() {
    super.initState();
    // Live digital clock ticker (1 detik)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });

    _fetchTodayStatus();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTodayStatus() async {
    try {
      final api = ref.read(apiServiceProvider);

      // 1. Coba endpoint terintegrasi /absensi/today-status
      try {
        final res = await api.get('/absensi/today-status');
        if (mounted && res['success'] == true && res['data'] is Map) {
          final d = res['data'] as Map;
          setState(() {
            _isMasukDone = d['is_masuk_done'] == true;
            _masukTime = d['waktu_masuk']?.toString();
            _isPulangDone = d['is_pulang_done'] == true;
            _pulangTime = d['waktu_pulang']?.toString();
            _shiftNama = d['shift_nama']?.toString();
            _jamMasukJadwal = d['jam_masuk_jadwal']?.toString();
            _jamPulangJadwal = d['jam_pulang_jadwal']?.toString();
            _statusKehadiran = d['status_kehadiran']?.toString();

            if (d['on_call_aktif'] is Map) {
              _onCallAktif = Map<String, dynamic>.from(d['on_call_aktif'] as Map);
            } else {
              _onCallAktif = null;
            }

            if (d['bank_jam'] is Map) {
              final bj = d['bank_jam'] as Map;
              _saldoBankJamMenit = bj['saldo_menit_tersedia'] is int
                  ? bj['saldo_menit_tersedia'] as int
                  : int.tryParse(bj['saldo_menit_tersedia']?.toString() ?? '') ?? 0;
              _saldoBankJamTeks = bj['saldo_tersedia_teks']?.toString();
            }
          });
          return;
        }
      } catch (_) {}

      // 2. Fallback: ambil jadwal dinas & bank jam secara terpisah
      final now = DateTime.now();
      final resJadwal = await api.get(
        '/jadwal-dinas',
        query: {'bulan': now.month, 'tahun': now.year},
      );
      if (mounted && resJadwal['success'] == true && resJadwal['data'] is Map) {
        final d = resJadwal['data'] as Map;
        final list = (d['hari'] as List?) ?? [];
        final todayEntry = list.firstWhere(
          (h) => (h as Map)['tanggal'] == now.day,
          orElse: () => null,
        ) as Map?;

        if (todayEntry != null) {
          final m = todayEntry['absen_masuk']?.toString().trim();
          final p = todayEntry['absen_pulang']?.toString().trim();
          final shift = todayEntry['shift_nama']?.toString().trim();

          setState(() {
            _isMasukDone = m != null && m.isNotEmpty && m != '-' && m != 'null';
            _masukTime = _isMasukDone ? m : null;

            _isPulangDone = p != null && p.isNotEmpty && p != '-' && p != 'null';
            _pulangTime = _isPulangDone ? p : null;

            _shiftNama = (shift != null && shift.isNotEmpty && shift != '-') ? shift : _shiftNama;
            _statusKehadiran = todayEntry['status_kehadiran']?.toString();
          });
        }
      }

      _fetchBankJamFallback();
    } catch (_) {}
  }

  Future<void> _fetchBankJamFallback() async {
    try {
      final storedUser = ref.read(authStateProvider).value;
      final freshUser = ref.read(freshProfileProvider).value;
      final user = freshUser ?? storedUser;
      if (user != null && !user.isGantiJam) return;

      if (mounted) setState(() => _isLoadingBankJam = true);
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/lembur/bank-jam');
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final d = res['data'] as Map;
        final saldo = d['saldo_menit_tersedia'] is int
            ? d['saldo_menit_tersedia'] as int
            : int.tryParse(d['saldo_menit_tersedia']?.toString() ?? '') ?? 0;
        final teks = d['saldo_tersedia_teks']?.toString() ?? '$saldo menit';
        setState(() {
          _saldoBankJamMenit = saldo;
          _saldoBankJamTeks = teks;
          _isLoadingBankJam = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingBankJam = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBankJam = false);
    }
  }

  String _getGreeting() {
    final hour = _now.hour;
    if (hour >= 4 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _openProfile() {
    if (widget.onNavigateTab != null) {
      final user = ref.read(freshProfileProvider).value ?? ref.read(authStateProvider).value;
      final canValidasi = user?.canValidasi == true;
      widget.onNavigateTab!(canValidasi ? 4 : 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authNotifierProvider).user;
    final storedUser = ref.watch(authStateProvider).value;
    final freshUser = ref.watch(freshProfileProvider).value;
    final user = freshUser ?? storedUser ?? authUser;
    final branding = ref.watch(brandingProvider).value;

    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH:mm:ss');
    final namaInstansi = branding?.nama ?? user?.unitKerja ?? 'RSKB Ropanasuri';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ===================================================================
            // TOP APP BAR (IDENTIK DENGAN HEADER STICKY DI SIRO)
            // ===================================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Logo RS Square (w-10 h-10 rounded-2xl bg-emerald-50 border border-emerald-100)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD1FAE5), width: 1),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: (branding?.logoUrl != null && branding!.logoUrl!.isNotEmpty)
                        ? Image.network(
                            branding.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_hospital_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.local_hospital_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Subtitle ("ROSES Mobile")
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          namaInstansi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'ROSES Mobile',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Profile Avatar Button (Right)
                  GestureDetector(
                    onTap: _openProfile,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: ProfileAvatar(
                        url: user?.fotoProfil,
                        name: user?.nama ?? 'U',
                        radius: 17,
                        onDark: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===================================================================
            // SCROLLABLE CONTENT (KARTU-KARTU UTAMA IDENTIK DENGAN SIRO)
            // ===================================================================
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(authStateProvider);
                  ref.invalidate(freshProfileProvider);
                  ref.invalidate(brandingProvider);
                  await _fetchTodayStatus();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: Column(
                    children: [
                      // 1. KARTU SAPAAN & JAM DIGITAL REAL-TIME (GRADIENT EMERALD TEAL)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF059669), // emerald-600
                              Color(0xFF10B981), // emerald-500
                              Color(0xFF0D9488), // teal-600
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row Atas: Sapaan, Nama, Unit & Badge WIB
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGreeting().toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.nama ?? 'Karyawan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.business_rounded,
                                            size: 13,
                                            color: Colors.white.withOpacity(0.85),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              user?.unitKerja ?? 'Unit Kerja RS',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Badge WIB
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.access_time_filled,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'WIB',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Garis Pembatas Halus
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),

                            // Row Bawah: Jam Digital Besar & Info Jadwal Shift
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      timeFormat.format(_now),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      dateFormat.format(_now),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.88),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Jadwal Shift:',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (_shiftNama != null && _shiftNama!.isNotEmpty)
                                          ? _shiftNama!.toUpperCase()
                                          : 'MEMUAT...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
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

                      // 2. BANNER ON-CALL AKTIF (BILA SEDANG ON-CALL)
                      if (_onCallAktif != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.3),
                                blurRadius: 12,
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
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mulai: ${_onCallAktif!['waktu_mulai'] ?? '-'}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const OnCallScreen(),
                                    ),
                                  );
                                  if (mounted) _fetchTodayStatus();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFEA580C),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Akhiri On-Call',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 3. KARTU STATUS PRESENSI HARI INI (WHITE CARD DENGAN BOX MASUK & PULANG)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
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
                            // Header: Status Presensi + Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                      color: Color(0xFF059669),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'STATUS PRESENSI HARI INI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (_isMasukDone || _statusKehadiran != null)
                                        ? (_statusKehadiran == 'Terlambat'
                                            ? const Color(0xFFFFE4E6)
                                            : const Color(0xFFD1FAE5))
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusKehadiran ??
                                        (_isMasukDone
                                            ? 'Tepat Waktu'
                                            : 'Belum Absen'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (_isMasukDone || _statusKehadiran != null)
                                          ? (_statusKehadiran == 'Terlambat'
                                              ? const Color(0xFFBE123C)
                                              : const Color(0xFF047857))
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Grid 2 Kolom: Box Masuk & Box Pulang
                            Row(
                              children: [
                                // Box Masuk
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isMasukDone
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _isMasukDone
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Absen Masuk',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            Icon(
                                              Icons.login_rounded,
                                              size: 14,
                                              color: _isMasukDone
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isMasukDone
                                              ? '${_masukTime ?? "--:--"} WIB'
                                              : '--:--',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: _isMasukDone
                                                ? const Color(0xFF047857)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Jadwal: ${_jamMasukJadwal ?? "-"}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Box Pulang
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isPulangDone
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _isPulangDone
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Absen Pulang',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 14,
                                              color: _isPulangDone
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isPulangDone
                                              ? '${_pulangTime ?? "--:--"} WIB'
                                              : '--:--',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: _isPulangDone
                                                ? const Color(0xFF047857)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Jadwal: ${_jamPulangJadwal ?? "-"}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. KARTU BANK JAM LEMBUR (BILA UNIT KERJA BERJENIS GANTI JAM)
                      if (user != null && user.isGantiJam) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SALDO BANK JAM LEMBUR',
                                      style: TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (_isLoadingBankJam)
                                      const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFD97706),
                                        ),
                                      )
                                    else
                                      Text(
                                        _saldoBankJamTeks ??
                                            '${_saldoBankJamMenit ?? 0} Menit',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Kompensasi waktu istirahat / cuti',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  widget.onNavigateTab?.call(2); // Tab Lembur
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFB45309),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: Color(0xFFFDE68A),
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Klaim Jam',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 5. TOMBOL AKSI UTAMA PRESENSI (GRID 2 KOLOM IDENTIK DENGAN SIRO)
                      Row(
                        children: [
                          // Tombol Absen Masuk (Emerald Gradient)
                          Expanded(
                            child: _ActionCardButton(
                              title: 'ABSEN MASUK',
                              subtitle: 'Selfie & Lokasi RS',
                              icon: Icons.camera_alt_rounded,
                              gradientColors: const [
                                Color(0xFF10B981), // emerald-500
                                Color(0xFF059669), // emerald-600
                              ],
                              shadowColor: const Color(0xFF10B981).withOpacity(0.3),
                              isDisabled: _isMasukDone && !_isPulangDone,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AbsensiScreen(type: 'masuk'),
                                  ),
                                );
                                if (mounted) _fetchTodayStatus();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Tombol Absen Pulang (Rose Gradient)
                          Expanded(
                            child: _ActionCardButton(
                              title: 'ABSEN PULANG',
                              subtitle: 'Selfie & Lokasi RS',
                              icon: Icons.logout_rounded,
                              gradientColors: const [
                                Color(0xFFF43F5E), // rose-500
                                Color(0xFFE11D48), // rose-600
                              ],
                              shadowColor: const Color(0xFFF43F5E).withOpacity(0.3),
                              isDisabled: !_isMasukDone || _isPulangDone,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AbsensiScreen(type: 'pulang'),
                                  ),
                                );
                                if (mounted) _fetchTodayStatus();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 6. TOMBOL TAMBAHAN: ON-CALL DARURAT & JADWAL ROSTER (GRID 2 KOLOM)
                      Row(
                        children: [
                          // On-Call Darurat
                          Expanded(
                            child: _SecondaryActionCard(
                              title: 'On-Call Darurat',
                              subtitle: 'Panggilan tugas RS',
                              icon: Icons.phone_in_talk_rounded,
                              iconColor: const Color(0xFF2563EB),
                              iconBgColor: const Color(0xFFEFF6FF),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OnCallScreen(),
                                  ),
                                );
                                if (mounted) _fetchTodayStatus();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Jadwal Roster
                          Expanded(
                            child: _SecondaryActionCard(
                              title: 'Jadwal Roster',
                              subtitle: 'Lihat kalender dinas',
                              icon: Icons.calendar_month_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              iconBgColor: const Color(0xFFFAF5FF),
                              onTap: () {
                                widget.onNavigateTab?.call(1); // Switch ke tab Jadwal
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget Tombol Aksi Utama Presensi (Besar, Bold, Gradient, Shadow Halus)
class _ActionCardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ActionCardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.45 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
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
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget Tombol Tambahan Menu (On-Call & Jadwal Roster)
class _SecondaryActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
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
}
