import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class OnCallScreen extends ConsumerStatefulWidget {
  const OnCallScreen({super.key});

  @override
  ConsumerState<OnCallScreen> createState() => _OnCallScreenState();
}

class _OnCallScreenState extends ConsumerState<OnCallScreen> {
  final _ketController = TextEditingController();
  bool _loading = false;
  bool _isOnCall = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _ketController.dispose();
    super.dispose();
  }

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
        setState(() {
          _isOnCall = true;
          _status = 'On-Call dimulai: ${res['data']?['waktu_mulai']}';
        });
      } else {
        setState(() => _error = res['message']);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _clockOut() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/lembur/oncall-keluar');
      if (res['success'] == true) {
        setState(() {
          _isOnCall = false;
          _status = 'On-Call selesai. Total: ${res['data']?['total_jam']} jam';
        });
      } else {
        setState(() => _error = res['message']);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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
            // Status
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
                      child: Text(
                        _status!,
                        style: const TextStyle(fontSize: 13),
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
                  icon: const Icon(Icons.login),
                  label: const Text('Mulai On-Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _clockOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Selesaikan On-Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
