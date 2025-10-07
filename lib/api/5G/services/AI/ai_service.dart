import 'package:get/get.dart';
import 'package:skylink/data/constants/api_path.dart';

import '../../../../data/dio/dio_service.dart';

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
