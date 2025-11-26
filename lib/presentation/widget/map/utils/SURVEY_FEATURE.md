# 📐 Bounding Box Survey Feature

## Tổng quan

Tính năng vẽ vùng survey tự động tạo waypoints cho nhiệm vụ bay khảo sát trong một khu vực được chọn.

## 🎯 Cách sử dụng

### Bước 1: Kích hoạt chế độ Mission Planning

- Trong Map Page, bật **Mission Planning Mode** từ thanh app bar

### Bước 2: Vẽ vùng Survey

1. Click nút **"Vẽ vùng Survey"** (màu xanh teal) ở góc dưới bên trái
2. Click **lần 1** trên bản đồ → Chọn góc đầu tiên của vùng
3. Di chuyển chuột → Xem preview hình chữ nhật real-time
4. Click **lần 2** trên bản đồ → Chọn góc đối diện

### Bước 3: Cấu hình Survey

Dialog cấu hình sẽ hiện ra với các tùy chọn:

#### 🔹 Kiểu bay (Survey Pattern)

- **Lawnmower (Zigzag)** ⭐ Phổ biến nhất

  - Bay qua lại như cắt cỏ
  - Tối ưu cho chụp ảnh, khảo sát địa hình, mapping 2D
  - Nhanh, hiệu quả, dùng cho 90% trường hợp

- **Grid (Double Grid / Cross-Hatch)**

  - Bay ngang hoàn chỉnh, SAU ĐÓ bay dọc hoàn chỉnh
  - Tạo pattern chéo nhau (cross-hatch)
  - Dùng cho 3D reconstruction, photogrammetry chất lượng cao
  - **Lưu ý:** Tốn thời gian gấp đôi Lawnmower!

- **Perimeter (Viền)**
  - Bay theo viền bounding box
  - Kiểm tra ranh giới, inspection chu vi

#### 🔹 Khoảng cách giữa các đường bay

- **Phạm vi:** 5m - 100m
- **Mặc định:** 20m
- **Ý nghĩa:** Khoảng cách giữa các đường bay song song
- **Lưu ý:** Khoảng cách nhỏ hơn = nhiều waypoints hơn = thời gian bay lâu hơn

#### 🔹 Góc quét

- **Phạm vi:** 0° - 180°
- **Mặc định:** 0° (hướng Bắc)
- **Ý nghĩa:** Xoay hướng bay so với hướng Bắc
- **Tip:** Điều chỉnh theo hướng gió hoặc địa hình

#### 🔹 Độ cao

- **Phạm vi:** 10m - 200m
- **Mặc định:** 50m
- **Ý nghĩa:** Độ cao bay tương đối so với điểm cất cánh

#### 🔹 Độ chồng lấp ảnh

- **Phạm vi:** 50% - 90%
- **Mặc định:** 70%
- **Ý nghĩa:** Dùng cho photogrammetry, tái tạo 3D
- **Lưu ý:** Độ chồng lấp cao hơn = chất lượng 3D tốt hơn

### Bước 4: Tạo Mission

- Click **"Tạo Mission"** → Waypoints được tạo tự động
- Waypoints hiển thị trên bản đồ với đường bay
- Có thể **edit từng waypoint** như bình thường
- Hỗ trợ **Undo/Redo**

### Bước 5: Hủy bỏ (nếu cần)

- Click nút **"Hủy vẽ vùng"** (màu đỏ) để hủy quá trình vẽ
- Hoặc click nút khác để thoát chế độ vẽ

## 🧮 Thuật toán

### Lawnmower Pattern

```
Start ──────────────────────> End
                              ↓
End   <────────────────────── Turn
↓
Start ──────────────────────> End
                              ↓
...
```

**Đặc điểm:**

- Bay zigzag qua lại
- Tối ưu thời gian bay
- Phù hợp cho camera gimbal (luôn hướng xuống)

### Grid Pattern (Double Grid / Cross-Hatch)

```
Pass 1 - Horizontal (bay ngang):
═══════════════════  Line 1
═══════════════════  Line 2
═══════════════════  Line 3

Pass 2 - Vertical (bay dọc, xoay 90°):
║  ║  ║  ║  ║  ║  ║  Line 1
║  ║  ║  ║  ║  ║  ║  Line 2
║  ║  ║  ║  ║  ║  ║  Line 3

Kết quả: Pattern chéo nhau (╬)
```

**Đặc điểm:**

- Bay 2 passes: ngang + dọc (vuông góc nhau)
- Phủ sóng 200% (mỗi điểm được chụp từ 2 góc)
- Chất lượng 3D reconstruction tốt nhất
- Thời gian bay gấp đôi Lawnmower
- Theo chuẩn QGroundControl, Mission Planner

### Perimeter Pattern

```
┌─────────────────┐
│                 │
│                 │
│                 │
└─────────────────┘
```

**Đặc điểm:**

- Bay theo viền
- Nhanh nhất
- Phù hợp kiểm tra chu vi

## 📊 Ví dụ thực tế

### Khảo sát ruộng lúa (100m x 200m)

- **Pattern:** Lawnmower
- **Spacing:** 15m
- **Angle:** 0° (theo chiều dài ruộng)
- **Altitude:** 30m
- **Overlap:** 75%
- **Kết quả:** ~28 waypoints, ~5 phút bay

### Phun thuốc vườn cây (50m x 50m)

- **Pattern:** Grid
- **Spacing:** 5m
- **Angle:** 0°
- **Altitude:** 10m
- **Kết quả:** ~42 waypoints, ~3 phút bay

### Kiểm tra hàng rào (200m perimeter)

- **Pattern:** Perimeter
- **Altitude:** 20m
- **Kết quả:** 5 waypoints, ~1 phút bay

## 🔧 Tính năng nâng cao

### Chỉnh sửa sau khi tạo

- Click vào waypoint để edit
- Kéo thả waypoint để di chuyển
- Xóa waypoint không cần thiết
- Thêm waypoint bổ sung

### Tích hợp với Mission Control

- Export/Import mission
- Gửi lên Flight Controller
- Đọc mission từ drone
- Tính toán thống kê (khoảng cách, thời gian, pin)

## 🐛 Troubleshooting

### Vấn đề: Quá nhiều waypoints

**Giải pháp:** Tăng spacing hoặc chọn pattern đơn giản hơn

### Vấn đề: Waypoints nằm ngoài vùng bay an toàn

**Giải pháp:** Vẽ lại bounding box nhỏ hơn

### Vấn đề: Góc quét không phù hợp

**Giải pháp:** Điều chỉnh angle theo hướng gió hoặc địa hình

## 📝 Code Structure

```
lib/presentation/widget/map/
├── components/
│   ├── bounding_box_drawer.dart       # Widget vẽ hình chữ nhật
│   └── survey_config_dialog.dart      # Dialog cấu hình
└── utils/
    ├── survey_generator.dart          # Thuật toán generate waypoints
    └── SURVEY_FEATURE.md             # Documentation này
```

## 🚀 Future Enhancements

- [ ] Polygon drawing (không chỉ rectangle)
- [ ] Obstacle avoidance
- [ ] Terrain following
- [ ] Multi-altitude survey
- [ ] Camera trigger points
- [ ] Wind compensation
- [ ] Battery optimization

## 📚 Tham khảo

- MAVLink Mission Protocol
- ArduPilot Survey Missions
- QGroundControl Survey Planning
- Photogrammetry Best Practices
