import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';

class OnCallScreen extends ConsumerStatefulWidget {
  const OnCallScreen({super.key});

  @override
  ConsumerState<OnCallScreen> createState() => _OnCallScreenState();
}

class _OnCallScreenState extends ConsumerState<OnCallScreen> {
  final _ketController = TextEditingController();

  bool _loading = false;
  bool _isOnCall = false;
  String? _oncallStart; // waktu mulai (mentah dari server / storage)
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _syncFromStorage(); // ✅ pulihkan state kalau app sempat tertutup
  }

  @override
  void dispose() {
    _ketController.dispose();
    super.dispose();
  }

  // --- helper ---
  bool _containsAny(String haystack, List<String> needles) {
    final h = haystack.toLowerCase();
    return needles.any((n) => h.contains(n.toLowerCase()));
  }

  String _fmtHm(String? s) {
    if (s == null || s.isEmpty) return '-';
    try {
      return DateTime.parse(s).toLocal().toString().substring(11, 16);
    } catch (_) {
      return s;
    }
  }

  // --- pulihkan state dari storage saat halaman dibuka ---
  Future<void> _syncFromStorage() async {
    final active = await StorageService.read('oncall_active');
    final start = await StorageService.read('oncall_start');
    if (!mounted) return;
    if (active == '1') {
      setState(() {
        _isOnCall = true;
        _oncallStart = start;
        _status = 'Sesi On-Call masih aktif (disinkronkan dari perangkat).';
      });
    }
  }

  Future<void> _setActive(String? startRaw) async {
    await StorageService.write('oncall_active', '1');
    if (startRaw != null && startRaw.isNotEmpty) {
      await StorageService.write('oncall_start', startRaw);
    }
    if (!mounted) return;
    setState(() {
      _isOnCall = true;
      _oncallStart = startRaw;
      _error = null;
      _status = 'On-Call dimulai: ${_fmtHm(startRaw)} WIB';
    });
  }

  Future<void> _clearActive() async {
    await StorageService.remove('oncall_active');
    await StorageService.remove('oncall_start');
    if (!mounted) return;
    setState(() {
      _isOnCall = false;
      _oncallStart = null;
    });
  }

  // --- Clock-In ---
  Future<void> _clockIn() async {
    if (_ketController.text.trim().isEmpty) {
      setState(() => _error = 'Keterangan wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post(
        '/lembur/oncall-masuk',
        data: {'keterangan': _ketController.text.trim()},
      );
      if (res['success'] == true) {
        await _setActive(res['data']?['waktu_mulai']?.toString());
      } else {
        final msg = res['message']?.toString() ?? '';
        // ✅ Self-heal: ternyata sudah ada sesi aktif → masuk mode aktif
        if (_containsAny(msg, [
          'masih memiliki sesi',
          'belum diselesaikan',
          'on-call yang belum',
          'sesi on-call',
        ])) {
          await _setActive(null);
          setState(() => _status = 'Anda sudah dalam sesi On-Call aktif.');
        } else {
          setState(() => _error = msg);
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (_containsAny(msg, [
        'masih memiliki sesi',
        'belum diselesaikan',
        'on-call yang belum',
        'sesi on-call',
      ])) {
        await _setActive(null);
        setState(() => _status = 'Anda sudah dalam sesi On-Call aktif.');
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Clock-Out ---
  Future<void> _clockOut() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/lembur/oncall-keluar');
      if (res['success'] == true) {
        await _clearActive();
        if (mounted) {
          setState(
            () => _status =
                'On-Call selesai. Total: ${res['data']?['total_jam'] ?? '-'} jam',
          );
        }
      } else {
        final msg = res['message']?.toString() ?? '';
        // ✅ Self-heal: sesi sudah tidak ada di server → reset UI
        if (_containsAny(msg, [
          'tidak ditemukan',
          'aktif tidak ditemukan',
          'lakukan masuk',
          'terlebih dahulu',
        ])) {
          await _clearActive();
          setState(
            () => _status =
                'Sesi On-Call tidak ditemukan (sudah diakhiri sebelumnya).',
          );
        } else {
          setState(() => _error = msg);
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (_containsAny(msg, [
        'tidak ditemukan',
        'aktif tidak ditemukan',
        'lakukan masuk',
        'terlebih dahulu',
      ])) {
        await _clearActive();
        setState(
          () => _status =
              'Sesi On-Call tidak ditemukan (sudah diakhiri sebelumnya).',
        );
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('On-Call')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status / info
            if (_status != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isOnCall
                      ? AppColors.warning.withValues(alpha: 0.08)
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isOnCall
                          ? Icons.radio_button_checked
                          : Icons.check_circle,
                      color: _isOnCall ? AppColors.warning : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_status!, style: const TextStyle(fontSize: 13)),
                          if (_isOnCall && _oncallStart != null)
                            Text(
                              'Mulai: ${_fmtHm(_oncallStart)} WIB',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (!_isOnCall) ...[
              TextField(
                controller: _ketController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Keterangan / Kasus',
                  hintText: 'Alasan panggilan darurat...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _clockIn,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Mulai On-Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
              const Text(
                '🔁 Status disinkronkan dengan server saat tombol ditekan. Aman jika aplikasi sempat tertutup.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _clockOut,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Selesaikan On-Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
