import 'package:dio/dio.dart';

/// Penerjemah error Dio → pesan Bahasa Indonesia yang jelas untuk user.
class ApiErrorMapper {
  static String mapToMessage(DioException e) {
    final res = e.response;

    // 1) Server membalas JSON → pakai pesan asli dari server
    if (res != null && res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;

      // Pesan utama dari server
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg;

      // Error validasi Laravel (422): ambil pesan pertama
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }

    // 2) Berdasarkan kode status HTTP
    if (res != null) {
      switch (res.statusCode) {
        case 401:
          return 'Sesi Anda berakhir. Silakan login ulang.';
        case 403:
          return 'Akses ditolak oleh server.';
        case 404:
          return 'Layanan tidak ditemukan. Perbarui aplikasi ke versi terbaru.';
        case 408:
          return 'Waktu koneksi habis. Silakan coba lagi.';
        case 413:
          return 'Ukuran file terlalu besar untuk dikirim.';
        case 422:
          return 'Data tidak lengkap atau tidak valid. Periksa kembali isian Anda.';
        case 429:
          return 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.';
        case 500:
          return 'Server sedang bermasalah. Coba beberapa saat lagi.';
        case 502:
          return 'Server sedang dalam perbaikan. Coba lagi sebentar lagi.';
        case 503:
          return 'Server sibuk. Coba lagi sebentar lagi.';
        case 504:
          return 'Server tidak merespons. Coba lagi sebentar lagi.';
        default:
          return 'Terjadi kesalahan pada server (kode ${res.statusCode}).';
      }
    }

    // 3) Error jaringan / timeout
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Koneksi lambat. Periksa sinyal internet Anda.';
      case DioExceptionType.sendTimeout:
        return 'Gagal mengirim data. Periksa koneksi internet Anda.';
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi internet Anda.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Pastikan internet aktif.';
      case DioExceptionType.badCertificate:
        return 'Koneksi tidak aman. Hubungi administrator.';
      case DioExceptionType.badResponse:
        return 'Server mengembalikan respons tidak valid.';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.unknown:
      default:
        if (e.message?.contains('SocketException') == true) {
          return 'Tidak ada koneksi internet. Periksa WiFi atau data seluler Anda.';
        }
        return 'Terjadi kesalahan jaringan. Silakan coba lagi.';
    }
  }
}
