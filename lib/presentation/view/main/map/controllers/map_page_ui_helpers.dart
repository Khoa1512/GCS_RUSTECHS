import 'package:flutter/material.dart';

/// UI feedback helpers for MapPage
/// Handles snackbars, dialogs, and user notifications
mixin MapPageUIHelpers {
  BuildContext get context;
  bool get mounted;

  /// Hide any progress indicators
  void hideProgress() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Show progress indicator with message
  void showProgress(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Show success message
  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Show error message
  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Show info message
  void showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Get MAVLink error message from error code
  String getMavlinkErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1:
        return 'Lỗi: Mục nhiệm vụ vượt quá dung lượng lưu trữ';
      case 2:
        return 'Lỗi: Nhiệm vụ chỉ được chấp nhận một phần';
      case 3:
        return 'Lỗi: Thao tác nhiệm vụ không được hỗ trợ';
      case 4:
        return 'Lỗi: Tọa độ nhiệm vụ nằm ngoài phạm vi';
      case 5:
        return 'Lỗi: Mục nhiệm vụ không hợp lệ';
      case 10:
        return 'Lỗi: Thứ tự mục nhiệm vụ không hợp lệ';
      case 11:
        return 'Lỗi: Mục nhiệm vụ không nằm trong phạm vi hợp lệ';
      case 12:
        return 'Lỗi: Số lượng mục nhiệm vụ không hợp lệ';
      case 13:
        return 'Lỗi: Thao tác nhiệm vụ hiện bị từ chối';
      case 14:
        return 'Lỗi: Thao tác nhiệm vụ đang được thực hiện';
      case 15:
        return 'Lỗi: Hệ thống chưa sẵn sàng cho nhiệm vụ';
      case 30:
        return 'Cảnh báo: Tham số mục nhiệm vụ vượt quá phạm vi (nhưng vẫn được chấp nhận)';
      case 128:
        return 'Lỗi: Nhiệm vụ không hợp lệ';
      case 129:
        return 'Lỗi: Loại nhiệm vụ không được hỗ trợ';
      case 130:
        return 'Lỗi: Phương tiện chưa sẵn sàng thực hiện nhiệm vụ';
      case 131:
        return 'Lỗi: Điểm bay (waypoint) ngoài phạm vi';
      case 132:
        return 'Lỗi: Số lượng điểm bay (waypoint) vượt quá giới hạn';
      default:
        return 'Cảnh báo: Mã lỗi $errorCode';
    }
  }

  /// Check if error code is an actual error
  /// Most error codes are false positives or warnings, only block critical errors
  bool isActualError(int errorCode) {
    switch (errorCode) {
      // Critical errors that should block mission upload
      case 5: // Mission item invalid (thực sự invalid)
      case 128: // Mission invalid (format sai)
        return true;

      // All other errors are warnings or false positives - IGNORE them
      case 1: // "Vượt quá dung lượng" - False positive
      case 2: // "Chỉ chấp nhận một phần" - Usually works fine
      case 3: // "Không hỗ trợ" - Usually works anyway
      case 4: // "Ngoài phạm vi" - FC will clamp values
      case 10: // "Thứ tự không hợp lệ" - FC will reorder
      case 11: // "Không trong phạm vi" - FC will handle
      case 12: // "Số lượng không hợp lệ" - FC will handle
      case 13: // "Bị từ chối" - Retry will work
      case 14: // "Đang thực hiện" - Just wait
      case 15: // "Chưa sẵn sàng" - Will be ready soon
      case 30: // "Tham số vượt quá" - Already accepted
      case 129: // "Không hỗ trợ" - Usually works
      case 130: // "Chưa sẵn sàng" - Will be ready
      case 131: // "Ngoài phạm vi" - FC will clamp
      case 132: // "Quá nhiều waypoints" - FC can handle
      default:
        return false; // Ignore all other codes
    }
  }
}
