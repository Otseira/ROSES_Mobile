import 'package:flutter/material.dart';
import 'api_service.dart';
import 'storage_service.dart';

class BrandingData {
  final String? logoUrl;
  final String? nama;
  final String? tagline;
  final String? bgUrl;
  final String? bgColor;

  const BrandingData({
    this.logoUrl,
    this.nama,
    this.tagline,
    this.bgUrl,
    this.bgColor,
  });
}

class BrandingService {
  // Kunci cache SAMA dengan InstansiBranding agar tidak dobel penyimpanan
  static const _kLogo = 'branding_logo_url';
  static const _kNama = 'branding_nama';
  static const _kTag = 'branding_tagline';
  static const _kBgUrl = 'branding_bg_url';
  static const _kBgColor = 'branding_bg_color';

  /// Baca cache lokal — instan untuk splash (tanpa flash).
  static Future<BrandingData> cached() async {
    final logo = await StorageService.read(_kLogo);
    final nama = await StorageService.read(_kNama);
    final tag = await StorageService.read(_kTag);
    final bgUrl = await StorageService.read(_kBgUrl);
    final bgColor = await StorageService.read(_kBgColor);

    return BrandingData(
      logoUrl: (logo?.isNotEmpty ?? false) ? logo : null,
      nama: (nama?.isNotEmpty ?? false) ? nama : null,
      tagline: (tag?.isNotEmpty ?? false) ? tag : null,
      bgUrl: (bgUrl?.isNotEmpty ?? false) ? bgUrl : null,
      bgColor: (bgColor?.isNotEmpty ?? false) ? bgColor : null,
    );
  }

  /// Ambil terbaru dari server + perbarui cache (dipakai splash & login).
  static Future<BrandingData> refresh(dynamic api) async {
    try {
      final res = await api.get('/branding');
      if (res['success'] == true && res['data'] is Map) {
        final d = res['data'] as Map;
        final data = BrandingData(
          logoUrl: d['logo_url']?.toString(),
          nama: d['nama_instansi']?.toString(),
          tagline: d['tagline']?.toString(),
          bgUrl: d['splash_bg_url']?.toString(),
          bgColor: d['splash_bg_color']?.toString(),
        );

        await _write(_kLogo, data.logoUrl);
        await _write(_kNama, data.nama);
        await _write(_kTag, data.tagline);
        await _write(_kBgUrl, data.bgUrl);
        await _write(_kBgColor, data.bgColor);

        return data;
      }
    } catch (_) {
      // offline → pakai cache
    }
    return cached();
  }

  static Future<void> _write(String key, String? val) async {
    if (val == null || val.isEmpty) {
      await StorageService.remove(key);
    } else {
      await StorageService.write(key, val);
    }
  }

  /// '#RRGGBB' → Color
  static Color? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}
