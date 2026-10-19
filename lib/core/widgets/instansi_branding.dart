import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../services/branding_service.dart';

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

  static const _defaultNama = 'RSKB Ropanasuri';

  @override
  void initState() {
    super.initState();
    _ac.forward();
    _boot();
  }

  Future<void> _boot() async {
    // 1) Tampilkan cache lokal terlebih dahulu (tanpa jeda/flash)
    final cached = await BrandingService.cached();
    if (!mounted) return;
    setState(() {
      _logoUrl = cached.logoUrl;
      _nama = cached.nama;
      _tagline = cached.tagline;
      _loaded = true;
    });

    // 2) Periksa jika provider belum dimuat, muat via brandingProvider
    try {
      final fresh = await ref.read(brandingProvider.future);
      if (!mounted) return;
      setState(() {
        _logoUrl = fresh.logoUrl ?? _logoUrl;
        _nama = fresh.nama ?? _nama;
        _tagline = fresh.tagline ?? _tagline;
      });
    } catch (_) {
      // offline/gagal → tetap gunakan cache lokal
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
                          AppColors.primary.withOpacity(0.22),
                          AppColors.primary.withOpacity(0.0),
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
                style: const TextStyle(
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
            color: AppColors.primary.withOpacity(0.35),
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
            color: Colors.black.withOpacity(0.12),
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
