import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Helper terpusat untuk kompresi foto sebelum diunggah ke server.
/// Mencegah OOM, menghemat kuota internet pengguna, dan mempercepat transmisi data.
class ImageCompressor {
  ImageCompressor._();

  /// Kompresi file foto menjadi format JPEG dengan dimensi dan kualitas yang optimal.
  static Future<File> compressFile(
    File file, {
    int minWidth = 1024,
    int minHeight = 1024,
    int quality = 70,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }
      return file;
    } catch (_) {
      // Fallback: kembalikan file asli jika proses kompresi gagal
      return file;
    }
  }
}

