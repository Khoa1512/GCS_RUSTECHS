import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skylink/data/constants/api_path.dart';
import 'package:skylink/data/dio/dio_service.dart';

import 'package:skylink/api/5G/services/secure_storage_service.dart';
import 'package:skylink/data/dio/dto/auth/token_reponse_dto.dart';
import 'package:skylink/data/dio/errors/error_exception_type.dart';

class DioInterceptor extends Interceptor {
  final SecureStorageService storage;

  DioInterceptor({required this.storage});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (options.extra['requiresAccessToken'] == true) {
        final accessToken = await storage.get(SecureStorageKey.accessToken);
        options.headers['authorization'] = 'Bearer $accessToken';
      }

      if (options.extra['requiresRefreshToken'] == true) {
        final refreshToken = await storage.get(SecureStorageKey.refreshToken);
        options.headers['refreshToken'] = refreshToken;
      }

      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: TokenMissingException('액세스 토큰 또는 리프레시 토큰이 없습니다'),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return super.onError(err, handler);
    }

    if (err.requestOptions.path == ApiPath.accessByRefresh) {
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: TokenMissingException('토큰 갱신 중 오류가 발생했습니다.'),
          type: DioExceptionType.unknown,
        ),
      );
    }

    final refreshToken = await storage.get(SecureStorageKey.refreshToken);

    if (refreshToken == null) {
      // Get.offAll(SignInScreen());

      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: TokenMissingException('리프레시 토큰이 없습니다.'),
          type: DioExceptionType.unknown,
        ),
      );
    }

    final dio = Dio();
    dio.interceptors.add(
      LogInterceptor(
        logPrint: (o) => debugPrint(o.toString()),
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ),
    );

    try {
      final response = await dio.post(
        '${BaseURL.prod}${ApiPath.accessByRefresh}',
        data: {'token': refreshToken},
      );

      final responseMap = response.data['result']['accessToken'];
      final responseDTO = TokenResponseDTO.fromJson(responseMap);
      final newAccessToken = responseDTO.value;

      await storage.save(SecureStorageKey.accessToken, newAccessToken);

      final options = err.requestOptions;

      options.headers.addAll({'authorization': 'Bearer $newAccessToken'});

      final retryResponse = await dio.fetch(options);
      return handler.resolve(retryResponse);
    } on DioException catch (_) {
      await deleteToken();
      // Get.offAll(SignInScreen());
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: TokenMissingException('토큰이 만료되었습니다.'),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<void> deleteToken() async {
    await Future.wait([
      storage.delete(SecureStorageKey.accessToken),
      storage.delete(SecureStorageKey.refreshToken),
    ]);
  }
}
