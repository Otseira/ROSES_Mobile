import 'dart:io';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

/// HANYA kamera. TIDAK ADA akses galeri.
class CameraService {
  CameraController? _controller;
  bool _initialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _initialized;

  Future<void> init({bool frontCamera = true}) async {
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
    } on CameraException catch (e) {
      _initialized = false;
      dispose();
      throw Exception('Gagal inisialisasi kamera: ${e.description}');
    }
  }

  /// Satu-satunya cara mendapat foto: capture dari kamera
  Future<File> capture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Kamera belum siap.');
    }
    if (_controller!.value.isTakingPicture) {
      throw Exception('Sedang mengambil foto...');
    }

    final xFile = await _controller!.takePicture();
    final file = File(xFile.path);

    // ✅ FIX: Proses gambar di background isolate (mencegah ANR di Android 9)
    final processed = await _processInBackground(file);
    return processed;
  }

  /// ✅ BARU: Jalankan image processing di background isolate
  ///    Ini mencegah main thread membeku → mencegah ANR & force close
  Future<File> _processInBackground(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final outPath = p.join(
        tempDir.path,
        'siro_${now.millisecondsSinceEpoch}.jpg',
      );

      final result = await Isolate.run(() {
        return _processImage(file.path, outPath, now);
      });

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

      // Watermark
      final text =
          'SIRO | ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
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
