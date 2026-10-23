import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio 네트워크 클라이언트 팩토리 (인터셉터 로깅 포함)
class DioClient {
  DioClient._();

  static Dio create({
    required String baseUrl,
    String? bearerToken,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (bearerToken != null && bearerToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${bearerToken.trim()}',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint(
            '[DIO REQ] ${options.method} ${options.uri}',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '[DIO RES] ${response.statusCode} ${response.requestOptions.uri}',
          );
          handler.next(response);
        },
        onError: (DioException e, handler) {
          debugPrint(
            '[DIO ERR] ${e.response?.statusCode ?? e.type} ${e.requestOptions.uri} -> ${e.message}',
          );
          handler.next(e);
        },
      ),
    );

    return dio;
  }
}
