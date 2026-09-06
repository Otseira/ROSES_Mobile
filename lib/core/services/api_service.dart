import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../utils/api_error_mapper.dart';
import 'storage_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await StorageService.clearAll();
          }
          handler.next(error);
        },
      ),
    );
  }

  // GET
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: query);
      return _extractData(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT JSON
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _extractData(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST JSON
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return _extractData(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST Multipart (untuk upload foto)
  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    Map<String, String>? fields,
    required Map<String, File> files,
  }) async {
    try {
      final formData = FormData.fromMap(fields ?? {});

      for (final entry in files.entries) {
        formData.files.add(
          MapEntry(
            entry.key,
            await MultipartFile.fromFile(
              entry.value.path,
              filename: entry.value.path.split('/').last,
            ),
          ),
        );
      }

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _extractData(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ekstrak data dari response (handle berbagai format)
  Map<String, dynamic> _extractData(Response response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is List) {
      return {'data': response.data};
    }
    return {'data': response.data};
  }

  /// Handle error DioException → pesan ramah user
  Exception _handleError(DioException e) {
    final message = ApiErrorMapper.mapToMessage(e);
    return Exception(message);
  }
}
