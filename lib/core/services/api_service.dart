import 'package:dio/dio.dart';

class ApiService {
  final Dio dio;
  ApiService({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8080',
              ),
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 12),
            ),
          );

  String message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (error.response != null) {
        return 'Server error (${error.response!.statusCode}). Please try again.';
      }
      return 'Could not reach the server. Check your connection and retry.';
    }
    return 'Could not update data. Please try again.';
  }
}
