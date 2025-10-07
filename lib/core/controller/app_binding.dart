import 'package:get/get.dart';

import 'package:skylink/data/dio/dio_service.dart';
import 'package:skylink/api/5G/services/mqtt_service.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/connection_manager.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    //services
    Get.lazyPut(() => DioService(), fenix: true);
    Get.lazyPut(() => MqttService(), fenix: true);
    Get.lazyPut(() => TelemetryService(), fenix: true);
    Get.lazyPut(() => ConnectionManager(), fenix: true);
  }
}
