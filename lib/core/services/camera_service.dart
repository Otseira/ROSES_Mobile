import 'dart:io';
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

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    _initialized = true;
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

    // Watermark + Compress
    final processed = await _process(file);
    return processed;
  }

  Future<File> _process(File file) async {
    try {
      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return file;

      // Resize if too large
      if (image.width > 1920) {
        image = img.copyResize(image, width: 1920);
      }

      // Watermark
      final now = DateTime.now();
      final text =
          'SIRO | ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}:${now.second}';
      img.drawString(
        image,
        text,
        font: img.arial24,
        x: 10,
        y: image.height - 40,
        color: img.ColorRgba8(255, 255, 255, 220),
      );

      // Encode with compression
      final dir = await getTemporaryDirectory();
      final outPath = p.join(
        dir.path,
        'siro_${now.millisecondsSinceEpoch}.jpg',
      );
      final outFile = File(outPath);

      int quality = 80;
      var encoded = img.encodeJpg(image, quality: quality);
      while (encoded.length > 2 * 1024 * 1024 && quality > 30) {
        quality -= 10;
        encoded = img.encodeJpg(image, quality: quality);
      }

      await outFile.writeAsBytes(encoded);
      return outFile;
    } catch (_) {
      return file;
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
