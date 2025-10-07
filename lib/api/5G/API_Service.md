
## API Service Architecture (Flutter + GetX + Dio)

Tài liệu mô tả kiến trúc và cách hoạt động của tầng API trong ứng dụng Flutter này, sử dụng GetX để quản lý dependency/state và Dio làm HTTP client.

### Tổng quan
- **DioService**: Service nền tảng (singleton) cấu hình base URL, timeout, interceptor, và cung cấp các phương thức HTTP (`get`, `post`, `put`, `patch`, `delete`, `download`).
- **AppBinding (GetX Bindings)**: Trung tâm đăng ký dependency bằng `Get.lazyPut`, đảm bảo 1 instance toàn cục và chỉ khởi tạo khi cần (lazy init).
- **DAO Services (ví dụ: AiService, AuthService, FileService, …)**: Các service nghiệp vụ sử dụng lại DioService như một factory (ủy thác việc gọi HTTP), tập trung logic endpoint/params/mapping dữ liệu.
- **Controller**: Inject/resolve các service qua GetX, gọi các phương thức của DAO service để thao tác API và cập nhật state.

### Sơ đồ luồng
```text
        +----------------+
        |   Controller   |
        +--------+-------+
                 |
     Get.find()/inject (GetX)
                 |
        +--------v-------+
        |   DAO Service  |  (AiService/Auth/File/...)
        +--------+-------+
                 | ủy thác HTTP
                 v
        +----------------+
        |   DioService   |  (singleton)
        | - BaseOptions  |
        | - Interceptors |
        +--------+-------+
                 |
                 v
        +-----------------------+
        |  Dio Interceptor      |
        |  - Thêm token header  |
        |  - Xử lý lỗi mạng     |
        +-----------+-----------+
                      |
                      v
            SecureStorageService
           (lấy access/refresh token)
```

Hình minh họa:

![API Service Diagram](assets/images/graph.png)

### Chi tiết hiện trạng trong repo

1) AppBinding đăng ký `DioService` dạng lazy singleton (fenix):
```1:11:lib/core/controller/app_binding.dart
import 'package:get/get.dart';

import 'package:skylink/data/dio/dio_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    //services
    Get.lazyPut(() => DioService(), fenix: true);
  }
}
```

2) Cấu hình `DioService` (base URL, timeout, log, interceptor, HTTP methods, token flags):
```1:47:lib/data/dio/dio_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skylink/data/dio/erros/error_exception_type.dart';
import 'package:skylink/data/dio/interceptors/dio_interceptor.dart';
import 'package:skylink/data/services/secure_storage_service.dart';

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
```

```49:139:lib/data/dio/dio_service.dart
  // GET request
  Future<T> get<T>({
    required String path,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
  }) async { /* ... */ }

  // POST request
  Future<T> post<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? parameters,
    Options? options,
    TokenType tokenType = TokenType.none,
    ProgressCallback? onReceiveProgress,
  }) async { /* ... */ }

  /// PUT / PATCH / DELETE / download tương tự
```

```203:246:lib/data/dio/dio_service.dart
  ///
  /// Add options based on token type
  ///
  Options? _mergeOptionsWithTokenType({
    Options? options,
    required TokenType tokenType,
  }) {
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
```

3) Interceptor thêm token vào header dựa trên `extra` flags, sử dụng `SecureStorageService`:
```1:33:lib/data/dio/interceptors/dio_interceptor.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skylink/data/constants/api_path.dart';
import 'package:skylink/data/dio/dio_service.dart';
import 'package:skylink/data/dio/erros/error_exception_type.dart';
import 'package:skylink/data/dto/auth/token_reponse_dto.dart';
import 'package:skylink/data/services/secure_storage_service.dart';

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
}
```

4) Ví dụ DAO service (`AiService`) sử dụng `DioService` qua GetX:
```1:16:lib/data/services/AI/ai_service.dart
import 'package:get/get.dart';
import 'package:skylink/data/constants/api_path.dart';

import '../../dio/dio_service.dart';

class AiService {
  final DioService _dioService = Get.find<DioService>();

  Future<void> getAiResponse(String prompt) async {
    final response = await _dioService.post(
      path: ApiPath.aiService,
      data: {'prompt': prompt},
    );
    return response['result'];
  }
}
```

### Cách dùng và khuyến nghị

- **Inject/Resolve**: Trong controller hoặc service khác, lấy instance bằng `Get.find<DioService>()` hoặc inject qua constructor. AppBinding đảm bảo 1 instance toàn cục (và `fenix: true` để tự tạo lại khi bị giải phóng).

- **Chọn loại token**: Sử dụng tham số `tokenType` khi gọi HTTP:
```dart
final result = await dioService.get<Map<String, dynamic>>(
  path: '/api/user/profile',
  tokenType: TokenType.access, // hoặc refresh/both/none
);
```

- **Tạo DAO service mới**:
```dart
class AuthService {
  final DioService _dio = Get.find<DioService>();

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _dio.post<Map<String, dynamic>>(
      path: '/api/auth/login',
      data: {'email': email, 'password': password},
      tokenType: TokenType.none,
    );
  }
}
```

- **Best practices**:
  - Khai báo tất cả endpoint trong `ApiPath` để dễ quản lý.
  - Bao bọc response mapping (DTO/model) ở DAO service, tránh rò rỉ JSON thô ra controller/UI.
  - Dùng `TokenType` thay cho tự thêm header thủ công.
  - Tùy biến `BaseURL.dev/prod` qua biến môi trường hoặc build flavor nếu cần.
  - Bổ sung retry/backoff, refresh-token flow trong `DioInterceptor.onError` nếu triển khai xác thực đầy đủ.

### Câu hỏi thường gặp
- Tại sao dùng singleton cho `DioService`?
  - Đảm bảo cấu hình/interceptor đồng nhất, tiết kiệm tài nguyên, dễ quản lý token và logging.

- Có thể thêm service khác ngoài `AiService`?
  - Có. Tạo class mới, `Get.find<DioService>()`, gọi các method HTTP và đóng gói logic của domain đó.
