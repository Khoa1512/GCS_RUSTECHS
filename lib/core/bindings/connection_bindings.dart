import 'package:get/get.dart';
import 'package:skylink/services/connection_manager.dart';
import 'package:skylink/services/telemetry_service.dart';

/// Dependency injection bindings for connection management
class ConnectionBindings extends Bindings {
  @override
  void dependencies() {
    // Register TelemetryService first (dependency)
    Get.lazyPut<TelemetryService>(() => TelemetryService(), fenix: true);

    // Register ConnectionManager
    Get.lazyPut<ConnectionManager>(() => ConnectionManager(), fenix: true);
  }
}

/// Initialize connection system
class ConnectionInitializer {
  static Future<void> init() async {
    // Ensure dependencies are registered
    ConnectionBindings().dependencies();

    // Initialize connection manager (will auto-start in onInit())
    Get.find<ConnectionManager>();
  }
}
