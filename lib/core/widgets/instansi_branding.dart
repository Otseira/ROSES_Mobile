import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Logo + nama instansi dinamis untuk halaman login.
/// Mengambil dari /api/branding (publik), dengan cache lokal & fallback bawaan.
class InstansiBranding extends ConsumerStatefulWidget {
  final double logoSize;
  const InstansiBranding({super.key, this.logoSize = 96});

  @override
  ConsumerState<InstansiBranding> createState() => _InstansiBrandingState();
}

class _InstansiBrandingState extends ConsumerState<InstansiBranding>
    with SingleTickerProviderStateMixin {
  String? _logoUrl;
  String? _nama;
  String? _tagline;
  bool _loaded = false;

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

  static const _kLogo = 'branding_logo_url';
  static const _kNama = 'branding_nama';
  static const _kTag = 'branding_tagline';
  static const _defaultNama = 'RSUD Ropanasuri';

  @override
  void initState() {
    super.initState();
    _ac.forward();
    _boot();
  }

  Future<void> _boot() async {
    // 1) Tampilkan cache dulu (instan, tanpa flash)
    final cLogo = await StorageService.read(_kLogo);
    final cNama = await StorageService.read(_kNama);
    final cTag = await StorageService.read(_kTag);
    if (!mounted) return;
    setState(() {
      _logoUrl = (cLogo != null && cLogo.isNotEmpty) ? cLogo : null;
      _nama = (cNama != null && cNama.isNotEmpty) ? cNama : null;
      _tagline = (cTag != null && cTag.isNotEmpty) ? cTag : null;
      _loaded = true;
    });

    // 2) Fetch terbaru di latar (stale-while-revalidate)
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/branding');
      if (res['success'] == true && res['data'] is Map) {
        final d = res['data'] as Map;
        final url = d['logo_url']?.toString();
        final nama = d['nama_instansi']?.toString();
        final tag = d['tagline']?.toString();
        // cache
        if (url != null && url.isNotEmpty) {
          await StorageService.write(_kLogo, url);
        } else {
          await StorageService.remove(_kLogo);
        }
        if (nama != null && nama.isNotEmpty) {
          await StorageService.write(_kNama, nama);
        } else {
          await StorageService.remove(_kNama);
        }
        if (tag != null && tag.isNotEmpty) {
          await StorageService.write(_kTag, tag);
        } else {
          await StorageService.remove(_kTag);
        }
        if (!mounted) return;
        setState(() {
          _logoUrl = (url != null && url.isNotEmpty) ? url : null;
          _nama = (nama != null && nama.isNotEmpty) ? nama : null;
          _tagline = (tag != null && tag.isNotEmpty) ? tag : null;
        });
      }
    } catch (_) {
      // gagal jaringan → biarkan cache / fallback tampil (graceful)
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.logoSize;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo dengan glow radial samar di belakangnya
            SizedBox(
              width: s + 48,
              height: s + 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ambient glow
                  Container(
                    width: s + 48,
                    height: s + 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.22),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // logo: server → cache → fallback bawaan
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _logoWidget(s),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Nama instansi (display weight) — fallback ke default
            Text(
              (_nama ?? _defaultNama),
              key: ValueKey(_nama ?? _defaultNama),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: AppColors.textPrimary,
              ),
            ),
            if ((_tagline ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _tagline!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _logoWidget(double s) {
    // Fallback bawaan (identitas lama SIRO) — dipakai bila belum ada logo server
    final fallback = Container(
      key: const ValueKey('fallback'),
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(s * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(Icons.fingerprint, color: Colors.white, size: s * 0.5),
    );

    if (!_loaded || _logoUrl == null) return fallback;

    return Container(
      key: ValueKey(_logoUrl),
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * 0.26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s * 0.26),
        child: Image.network(
          _logoUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
