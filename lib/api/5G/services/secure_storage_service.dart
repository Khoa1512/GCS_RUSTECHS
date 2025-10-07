import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SecureStorageKey {
  fcmToken(value: 'FCM_TOKEN'),
  accessToken(value: 'ACCESS_TOKEN'),
  refreshToken(value: 'REFRESH_TOKEN'),
  userRole(value: 'USER_ROLE');

  const SecureStorageKey({required this.value});
  final String value;
}

/// Storage service
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();

  late final FlutterSecureStorage _storage;

  factory SecureStorageService() => instance;

  SecureStorageService._internal() {
    _storage = FlutterSecureStorage(
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  /// Android security options
  AndroidOptions _getAndroidOptions() =>
      const AndroidOptions(encryptedSharedPreferences: true);

  /// iOS security options
  IOSOptions _getIOSOptions() => const IOSOptions(
    accessibility:
        KeychainAccessibility.first_unlock, // Accessible after first unlock
  );

  /// Save
  Future<void> save(SecureStorageKey key, String value) async {
    log('Save $key : $value');
    await _storage.write(key: key.value, value: value);
  }

  /// Get
  Future<String?> get(SecureStorageKey key) async {
    final result = await _storage.read(key: key.value);
    log('Get $key : $result');
    return result;
  }

  /// Delete
  Future<void> delete(SecureStorageKey key) async {
    log('Delete $key');
    await _storage.delete(key: key.value);
  }

  /// Delete all
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
