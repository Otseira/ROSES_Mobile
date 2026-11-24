import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

/// HANYA kamera. TIDAK ADA akses galeri.
class CameraService {
  CameraController? _controller;
  bool _initialized = false;
  bool _isFront = true;

  CameraController? get controller => _controller;
  bool get isInitialized => _initialized;
  bool get isFrontCamera => _isFront;

  Future<void> init({bool frontCamera = true}) async {
    _isFront = frontCamera;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('Kamera tidak tersedia.');

    final camera = frontCamera
        ? cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          )
        : cameras.first;

    // ✅ FIX: Gunakan resolusi medium (stabil di Android 9 + hemat RAM)
    //    Jika masih crash, ganti ke ResolutionPreset.low
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      _initialized = true;

      // ✅ Pastikan zoom kamera diatur ke nilai minimum (wide FOV)
      //    agar tidak ngezoom saat selfie presensi
      try {
        final minZoom = await _controller!.getMinZoomLevel();
        await _controller!.setZoomLevel(minZoom);
      } catch (_) {}
    } on CameraException catch (e) {
      _initialized = false;
      dispose();
      throw Exception('Gagal inisialisasi kamera: ${e.description}');
    }
  }

  /// Widget preview kamera yang otomatis mengisi kontainer (BoxFit.cover),
  /// mempertahankan aspek rasio native tanpa distorsi/gepeng,
  /// menghilangkan bilah hitam (letterboxing), dan mendukung toggle mirror.
  Widget buildPreview({
    required BoxConstraints constraints,
    bool isMirrored = false,
  }) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(_controller!);
    }

    // Kamera smartphone mengembalikan previewSize dalam orientasi sensor landscape (misal width 1280, height 720).
    // Pada orientasi portrait HP, rasio aspek vertikal adalah height / width.
    final isLandscape = constraints.maxWidth > constraints.maxHeight;
    final previewRatio = isLandscape
        ? previewSize.width / previewSize.height
        : previewSize.height / previewSize.width;

    final containerRatio = constraints.maxWidth / constraints.maxHeight;

    // Skala agar mengisi seluruh area kontainer (object-cover) tanpa distorsi
    double scale;
    if (containerRatio > previewRatio) {
      scale = containerRatio / previewRatio;
    } else {
      scale = previewRatio / containerRatio;
    }

    Widget preview = CameraPreview(_controller!);
    if (isMirrored) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.1415926535897932),
        child: preview,
      );
    }

    return ClipRect(
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: AspectRatio(
            aspectRatio: previewRatio,
            child: preview,
          ),
        ),
      ),
    );
  }

  /// Overlay panduan wajah oval seragam (proporsional & elegan mengikuti UI SIRO)
  static Widget buildFaceGuideOverlay({
    Color? borderColor,
    String text = 'Posisikan Wajah',
  }) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 210,
          height: 275,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(210, 275)),
            border: Border.all(
              color: borderColor ?? const Color(0xFF34D399).withOpacity(0.85), // emerald-400
              width: 2.2,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Satu-satunya cara mendapat foto: capture dari kamera
  Future<File> capture({bool mirror = false}) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Kamera belum siap.');
    }
    if (_controller!.value.isTakingPicture) {
      throw Exception('Sedang mengambil foto...');
    }

    final xFile = await _controller!.takePicture();
    final file = File(xFile.path);

    // ✅ FIX: Proses gambar di background isolate (mencegah ANR di Android 9)
    final processed = await _processInBackground(file, mirror: mirror);
    return processed;
  }

  /// ✅ BARU: Jalankan image processing di background isolate
  ///    Ini mencegah main thread membeku → mencegah ANR & force close
  Future<File> _processInBackground(File file, {bool mirror = false}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final outPath = p.join(
        tempDir.path,
        'roses_${now.millisecondsSinceEpoch}.jpg',
      );

      final result = await Isolate.run(() {
        return _processImage(file.path, outPath, now, mirror);
      });

      // Bersihkan file capture mentah awal setelah berhasil diproses
      try {
        if (file.path != result && await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      return File(result);
    } catch (_) {
      // Jika gagal proses, kembalikan foto asli (tanpa watermark)
      return file;
    }
  }

  /// Processing murni (berjalan di isolate terpisah, aman dari ANR)
  static String _processImage(
    String inputPath,
    String outputPath,
    DateTime now,
    bool mirror,
  ) {
    try {
      final bytes = File(inputPath).readAsBytesSync();
      var image = img.decodeImage(bytes);
      if (image == null) return inputPath;

      // ✅ FIX: Batasi ukuran gambar agar tidak OOM di Android 9
      //    1280px cukup untuk foto absensi selfie
      if (image.width > 1280) {
        image = img.copyResize(image, width: 1280);
      }

      // Flip horizontal hanya jika opsi cermin diaktifkan (default: false agar gerakan searah)
      if (mirror) {
        image = img.flipHorizontal(image);
      }

      // Watermark
      final text =
          'ROSES | ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      img.drawString(
        image,
        text,
        font: img.arial24,
        x: 10,
        y: image.height - 40,
        color: img.ColorRgba8(255, 255, 255, 220),
      );

      // ✅ FIX: Mulai dari quality 70 dan batasi loop agar tidak infinite
      int quality = 70;
      var encoded = img.encodeJpg(image, quality: quality);

      int maxAttempts = 5;
      while (encoded.length > 2 * 1024 * 1024 &&
          quality > 30 &&
          maxAttempts > 0) {
        quality -= 10;
        maxAttempts--;
        encoded = img.encodeJpg(image, quality: quality);
      }

      File(outputPath).writeAsBytesSync(encoded);
      return outputPath;
    } catch (_) {
      return inputPath;
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
