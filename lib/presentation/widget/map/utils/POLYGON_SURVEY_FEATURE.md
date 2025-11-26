# 🔷 Polygon Survey Feature

## 📋 Tổng quan

Chức năng vẽ **Polygon** (đa giác) để chọn vùng khảo sát chính xác hơn so với Bounding Box vuông.

## ✨ Tính năng

### 1. **Vẽ Polygon**

- Click nhiều lần trên bản đồ để tạo các đỉnh của đa giác
- Tối thiểu 3 điểm để tạo polygon hợp lệ
- Visualize real-time khi đang vẽ:
  - Các đỉnh được đánh số thứ tự (1, 2, 3, ...)
  - Đường viền nối các đỉnh
  - Fill màu khi đủ 3 điểm

### 2. **UI Controls**

- **Undo:** Xóa điểm cuối cùng vừa vẽ
- **Hoàn thành:** Kết thúc vẽ và mở dialog cấu hình survey
- **Hủy:** Hủy bỏ polygon đang vẽ

### 3. **Survey Generation**

Sau khi vẽ polygon, chọn pattern survey:

#### **Lawnmower (Zigzag)**

- Tạo bounding box của polygon
- Generate lawnmower pattern trong box
- **Lọc** chỉ giữ waypoints **bên trong** polygon
- ✅ Tối ưu cho khảo sát vùng không đều

#### **Grid (Cross-Hatch)**

- Tạo bounding box của polygon
- Generate grid pattern (ngang + dọc) trong box
- **Lọc** chỉ giữ waypoints **bên trong** polygon
- ✅ Tốt cho 3D mapping vùng phức tạp

#### **Perimeter (Viền)**

- Bay theo viền polygon
- Sử dụng trực tiếp các đỉnh của polygon
- Tự động đóng vòng (quay về điểm đầu)
- ✅ Kiểm tra chu vi, ranh giới

## 🎯 Cách sử dụng

### Bước 1: Bật Polygon Mode

1. Click nút **"Survey Polygon"** (icon: polyline, màu tím)
2. Thông báo: "Nhấp nhiều lần để tạo đa giác, tối thiểu 3 điểm"

### Bước 2: Vẽ Polygon

1. Click trên bản đồ để thêm điểm
2. Mỗi click tạo 1 đỉnh mới
3. Các đỉnh được đánh số và nối với nhau

### Bước 3: Hoàn thiện

1. Sau khi vẽ đủ ≥3 điểm, click **"Hoàn thành"**
2. Dialog cấu hình survey hiện ra
3. Chọn pattern, spacing, altitude, angle
4. Click **"Tạo Survey"**

### Bước 4: Kết quả

- Waypoints được tạo tự động
- Chỉ các waypoints **trong polygon** được giữ lại
- Có thể edit, reorder, delete như bình thường

## 🔧 Thuật toán

### Point-in-Polygon Check

Sử dụng **Ray Casting Algorithm**:

```dart
bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
  int intersections = 0;

  for (int i = 0; i < polygon.length; i++) {
    final p1 = polygon[i];
    final p2 = polygon[(i + 1) % polygon.length];

    // Check if ray from point to right intersects edge
    if ((p1.latitude > point.latitude) != (p2.latitude > point.latitude)) {
      final intersectLng = (p2.longitude - p1.longitude) *
              (point.latitude - p1.latitude) /
              (p2.latitude - p1.latitude) +
          p1.longitude;

      if (point.longitude < intersectLng) {
        intersections++;
      }
    }
  }

  // Point is inside if number of intersections is odd
  return intersections % 2 == 1;
}
```

**Logic:**

- Vẽ tia từ điểm ra phải vô cùng
- Đếm số lần tia cắt viền polygon
- Nếu số lần cắt **lẻ** → điểm **trong** polygon
- Nếu số lần cắt **chẵn** → điểm **ngoài** polygon

## 📁 Files liên quan

### 1. **State Management**

- `lib/presentation/view/main/map/controllers/map_page_state.dart`
  - `isDrawingPolygon`: Flag vẽ polygon
  - `polygonPoints`: Danh sách các đỉnh

### 2. **Event Handlers**

- `lib/presentation/view/main/map/controllers/map_page_handlers.dart`
  - `handlePolygonSurvey()`: Bật polygon mode
  - `finishPolygonDrawing()`: Hoàn thành vẽ
  - `undoLastPolygonPoint()`: Xóa điểm cuối
  - `cancelPolygonDrawing()`: Hủy vẽ
  - `showSurveyConfigDialogForPolygon()`: Hiện dialog config

### 3. **UI Components**

- `lib/presentation/widget/map/components/polygon_drawer.dart`

  - Visualize polygon đang vẽ
  - Hiển thị đỉnh, đường viền, fill

- `lib/presentation/widget/map/components/floating_mission_actions.dart`

  - Nút "Survey Polygon"

- `lib/presentation/view/main/map/map_page.dart`
  - Polygon drawing controls (Undo, Finish, Cancel)

### 4. **Survey Generation**

- `lib/presentation/widget/map/utils/survey_generator.dart`
  - `generateSurveyForPolygon()`: Generate waypoints cho polygon
  - `_generatePolygonPerimeter()`: Bay theo viền
  - `_isPointInPolygon()`: Check điểm trong polygon

### 5. **Map Rendering**

- `lib/presentation/widget/map/main_map.dart`
  - Render `PolygonDrawer` layer

## 🆚 So sánh: Bounding Box vs Polygon

| Tiêu chí          | Bounding Box         | Polygon                |
| ----------------- | -------------------- | ---------------------- |
| **Độ chính xác**  | Vuông góc, cố định   | Tùy chỉnh, linh hoạt   |
| **Số click**      | 2 clicks             | ≥3 clicks              |
| **Vùng phức tạp** | ❌ Không phù hợp     | ✅ Rất phù hợp         |
| **Tốc độ vẽ**     | ⚡ Nhanh             | 🐌 Chậm hơn            |
| **Use case**      | Vùng vuông, chữ nhật | Vùng bất kỳ, không đều |

## 💡 Tips

1. **Vẽ polygon đơn giản trước:**

   - Bắt đầu với 3-4 điểm
   - Test xem survey có đúng không
   - Sau đó mới vẽ polygon phức tạp hơn

2. **Tránh polygon tự cắt:**

   - Không vẽ polygon có các cạnh cắt nhau
   - Sẽ gây lỗi trong point-in-polygon check

3. **Chọn spacing phù hợp:**

   - Spacing nhỏ → nhiều waypoints → chính xác hơn
   - Spacing lớn → ít waypoints → nhanh hơn

4. **Perimeter pattern:**
   - Dùng cho inspection chu vi
   - Không cần filter waypoints
   - Nhanh nhất

## 🐛 Known Issues

1. **Polygon tự cắt:**

   - Ray casting algorithm có thể cho kết quả sai
   - Workaround: Vẽ polygon đơn giản, không tự cắt

2. **Performance với polygon lớn:**
   - Nhiều đỉnh + nhiều waypoints = chậm
   - Workaround: Giới hạn số đỉnh hoặc tăng spacing

## 🚀 Future Enhancements

- [ ] Edit polygon sau khi vẽ (drag đỉnh)
- [ ] Snap to grid khi vẽ
- [ ] Import polygon từ file (GeoJSON, KML)
- [ ] Export polygon
- [ ] Polygon với holes (đa giác có lỗ)
- [ ] Smooth polygon edges
- [ ] Auto-simplify polygon (giảm số đỉnh)

## 📚 References

- [Ray Casting Algorithm](https://en.wikipedia.org/wiki/Point_in_polygon)
- [Flutter Map Polygon Layer](https://pub.dev/packages/flutter_map)
- [Mission Planner Survey](https://ardupilot.org/planner/docs/mission-planner-survey-grid.html)
