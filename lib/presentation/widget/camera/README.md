# Camera Stream Integration

## Tổng quan

Tính năng này cho phép nhúng camera stream từ web bên thứ 3 vào ứng dụng Flutter thông qua WebView.

## Tính năng

- **Live Stream**: Hiển thị camera stream trực tiếp từ URL
- **Toggle Mode**: Chuyển đổi giữa live stream và ảnh tĩnh
- **Settings**: Cấu hình URL camera stream
- **Error Handling**: Xử lý lỗi khi không thể tải stream
- **Loading State**: Hiển thị trạng thái đang tải

## Cách sử dụng

### 1. Cấu hình URL Camera Stream

- Nhấn nút ⚙️ (settings) ở góc phải trên cùng
- Nhập URL của camera stream
- Chọn từ danh sách URL mẫu hoặc nhập URL tùy chỉnh
- Nhấn "Lưu"

### 2. Chuyển đổi giữa các chế độ

- Nhấn nút 📹/🖼️ để chuyển đổi giữa:
  - Live stream (📹): Hiển thị camera trực tiếp
  - Static image (🖼️): Hiển thị ảnh tĩnh

### 3. Các định dạng URL được hỗ trợ

- **HTTP Stream**: `http://192.168.1.100:8080/stream`
- **HTTPS Stream**: `https://example.com/camera/feed`
- **RTMP**: `rtmp://example.com/live/stream`
- **WebRTC**: URLs từ các service WebRTC

## Cấu hình kỹ thuật

### Android

- Đã thêm permissions trong `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  ```

### iOS

- Đã cấu hình `NSAppTransportSecurity` trong `ios/Runner/Info.plist` để cho phép HTTP requests

### Dependencies

- `webview_flutter: ^4.10.0` - WebView component

## Troubleshooting

### Stream không tải được

1. Kiểm tra URL có chính xác không
2. Đảm bảo camera stream đang hoạt động
3. Kiểm tra kết nối mạng
4. Thử nhấn nút "Thử lại"

### Performance

- WebView có thể tốn nhiều tài nguyên, hãy theo dõi hiệu suất
- Có thể tắt live stream khi không cần thiết để tiết kiệm pin

### CORS Issues

- Một số camera streams có thể có vấn đề CORS
- Liên hệ với nhà cung cấp camera để được hỗ trợ

## Ví dụ URLs

```
# Local camera streams
http://192.168.1.100:8080/stream
http://localhost:8080/video

# RTMP streams
rtmp://example.com/live/stream

# Web-based streams
https://example.com/camera/feed
```

## Files liên quan

- `lib/presentation/widget/camera/camera_main_view.dart` - Component chính
- `lib/presentation/widget/camera/camera_webview.dart` - WebView wrapper
- `lib/presentation/widget/camera/camera_stream_settings.dart` - Settings UI
