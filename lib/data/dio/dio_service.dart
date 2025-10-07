import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:skylink/api/5G/services/secure_storage_service.dart';
import 'package:skylink/data/dio/errors/error_exception_type.dart';
import 'package:skylink/data/dio/interceptor/dio_interceptor.dart';

/// Token type (determines whether to include in headers)
enum TokenType { none, access, refresh, both }

/// Base URL
abstract class BaseURL {
  static const String dev = "http://34.47.125.196:3000/";
  static const String prod = "https://rustech.dev/api/";
}

/// Network service
class DioService {
  static final DioService _instance = DioService._internal();
  factory DioService() => _instance;

  late final Dio _dio;
  final String _baseUrl = BaseURL.prod;
  final SecureStorageService _storage = SecureStorageService();

  // Constructor (cannot create instance from outside)
  DioService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        logPrint: (o) => debugPrint(o.toString()),
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ),
    );

    // Token interceptor
    _dio.interceptors.add(DioInterceptor(storage: _storage));
  }

  // GET request
  Future<T> get<T>({
    required String path,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
  }) async {
    try {
      // Add options based on token type
      final Options? mergedOptions = _mergeOptionsWithTokenType(
        options: options,
        tokenType: tokenType,
      );

      final response = await _dio.get(
        path,
        queryParameters: parameters,
        options: mergedOptions,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<T> post<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      // Add options based on token type
      final Options? mergedOptions = _mergeOptionsWithTokenType(
        options: options,
        tokenType: tokenType,
      );

      final response = await _dio.post(
        path,
        data: data,
        queryParameters: parameters,
        options: mergedOptions,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<T> put<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
  }) async {
    try {
      // Add options based on token type
      final Options? mergedOptions = _mergeOptionsWithTokenType(
        options: options,
        tokenType: tokenType,
      );

      final response = await _dio.put(
        path,
        data: data,
        queryParameters: parameters,
        options: mergedOptions,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<T> patch<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
  }) async {
    try {
      // Add options based on token type
      final Options? mergedOptions = _mergeOptionsWithTokenType(
        options: options,
        tokenType: tokenType,
      );

      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: parameters,
        options: mergedOptions,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<T> delete<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
  }) async {
    try {
      // Add options based on token type
      final Options? mergedOptions = _mergeOptionsWithTokenType(
        options: options,
        tokenType: tokenType,
      );

      final response = await _dio.delete(
        path,
        queryParameters: parameters,
        data: data,
        options: mergedOptions,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// File download
  Future<void> download({
    required String url,
    required String savePath,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ///
  /// Add options based on token type
  ///
  Options? _mergeOptionsWithTokenType({
    Options? options,
    required TokenType tokenType,
  }) {
    // Create new options if none exists
    final extra = Map<String, dynamic>.from(options?.extra ?? {});

    switch (tokenType) {
      case TokenType.access:
        extra['requiresAccessToken'] = true;
        break;
      case TokenType.refresh:
        extra['requiresRefreshToken'] = true;
        break;
      case TokenType.both:
        extra['requiresAccessToken'] = true;
        extra['requiresRefreshToken'] = true;
        break;
      case TokenType.none:
        return options;
    }

    return Options(
      method: options?.method,
      sendTimeout: options?.sendTimeout,
      receiveTimeout: options?.receiveTimeout,
      extra: extra,
      headers: options?.headers,
      responseType: options?.responseType,
      contentType: options?.contentType,
      validateStatus: options?.validateStatus,
      receiveDataWhenStatusError: options?.receiveDataWhenStatusError,
      followRedirects: options?.followRedirects,
      maxRedirects: options?.maxRedirects,
      requestEncoder: options?.requestEncoder,
      responseDecoder: options?.responseDecoder,
    );
  }

  // Error handling
  Exception _handleError(DioException error) {
    // Handle token missing error
    if (error.error is TokenMissingException) {
      return error.error as TokenMissingException;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException('Request timed out. (Please try again later)');

      case DioExceptionType.badResponse: // When status code is not 200-299
        // Extract message from server response
        String responseMessage = '';

        try {
          final response = error.response?.data;
          if (response is Map<String, dynamic> && response['message'] != null) {
            responseMessage = response['message'].toString();
          }
        } catch (e) {
          responseMessage = 'Server error occurred. (Please try again later)';
        }

        return ServerException(
          responseMessage,
          statusCode: error.response?.statusCode,
        );
      default:
        return NetworkException(
          'Network error occurred. (Please try again later)',
        );
    }
  }
}
