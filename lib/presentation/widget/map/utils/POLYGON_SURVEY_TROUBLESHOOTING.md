# 🔧 Polygon Survey Troubleshooting

## ❓ Vấn đề: Lawnmower/Grid không tạo waypoints trong polygon

### 🔍 Nguyên nhân phổ biến:

#### 1. **Spacing quá lớn so với polygon**

```
Polygon nhỏ: 50m x 50m
Spacing: 20m
→ Chỉ có ~3-4 lines → Rất ít waypoints trong polygon
```

**Giải pháp:**

- ✅ Giảm spacing xuống 5-10m
- ✅ Hoặc vẽ polygon lớn hơn

#### 2. **Polygon quá nhỏ**

```
Polygon: 20m x 20m
Spacing: 20m
→ Không có waypoint nào nằm hoàn toàn trong polygon!
```

**Giải pháp:**

- ✅ Vẽ polygon lớn hơn (tối thiểu 100m x 100m)
- ✅ Hoặc giảm spacing

#### 3. **Polygon hình dạng kỳ lạ**

```
Polygon: Hình chữ L, hình sao, tự cắt
→ Ray casting algorithm có thể cho kết quả sai
```

**Giải pháp:**

- ✅ Vẽ polygon đơn giản (hình chữ nhật, đa giác lồi)
- ✅ Tránh polygon tự cắt

## 🧪 Cách test:

### Test 1: Polygon lớn + Spacing nhỏ

```
1. Vẽ polygon: ~200m x 200m (khoảng 10-12 clicks)
2. Chọn Lawnmower
3. Spacing: 10m
4. Altitude: 50m
5. Angle: 0°
→ Kỳ vọng: 20-40 waypoints
```

### Test 2: Grid pattern

```
1. Vẽ polygon: ~150m x 150m
2. Chọn Grid
3. Spacing: 15m
4. Altitude: 50m
5. Angle: 0°
→ Kỳ vọng: 40-80 waypoints (gấp đôi Lawnmower)
```

### Test 3: Perimeter (luôn hoạt động)

```
1. Vẽ polygon bất kỳ
2. Chọn Perimeter
3. Altitude: 50m
→ Kỳ vọng: Số waypoints = số đỉnh polygon + 1
```

## 📊 Debug Output

Khi generate survey, check console log:

```
🔍 Survey Generation Debug:
   Total waypoints generated: 120
   Waypoints inside polygon: 45
   Pattern: SurveyPattern.lawnmower
   Spacing: 10.0m
```

### Phân tích:

- **Total waypoints:** Số waypoints trong bounding box
- **Inside polygon:** Số waypoints sau khi filter
- **Nếu inside = 0:** Spacing quá lớn hoặc polygon quá nhỏ!

## ⚠️ Warning Messages

### "No waypoints inside polygon!"

```
⚠️  No waypoints inside polygon! Try:
   - Reduce spacing (current: 20.0m)
   - Draw larger polygon
```

**Hành động:**

1. Giảm spacing xuống 50%
2. Hoặc vẽ lại polygon lớn hơn gấp đôi

## 💡 Best Practices

### 1. **Tỷ lệ Polygon : Spacing**

```
Polygon size: 200m x 200m
Spacing tốt: 10-20m
→ Ratio: 10:1 đến 20:1
```

### 2. **Số waypoints hợp lý**

```
Lawnmower: 20-100 waypoints
Grid: 40-200 waypoints
Perimeter: 4-20 waypoints
```

### 3. **Hình dạng polygon**

```
✅ Tốt: Hình chữ nhật, hình vuông, đa giác lồi
⚠️  Cẩn thận: Hình chữ L, hình chữ U
❌ Tránh: Polygon tự cắt, hình sao
```

## 🔬 Advanced: Ray Casting Algorithm

### Cách hoạt động:

```dart
bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
  // Vẽ tia từ point ra phải vô cùng
  // Đếm số lần tia cắt viền polygon
  // Nếu số lần cắt LẺ → điểm TRONG polygon
  // Nếu số lần cắt CHẴN → điểm NGOÀI polygon
}
```

### Edge cases:

1. **Point trên viền:** Có thể cho kết quả sai
2. **Polygon tự cắt:** Không đảm bảo đúng
3. **Polygon có holes:** Không support

## 🚀 Recommended Settings

### Small Area (< 100m x 100m)

```
Pattern: Lawnmower
Spacing: 5m
Altitude: 30m
Angle: 0° or 45°
```

### Medium Area (100-500m)

```
Pattern: Lawnmower or Grid
Spacing: 10-15m
Altitude: 50m
Angle: 0°
```

### Large Area (> 500m)

```
Pattern: Lawnmower (Grid quá lâu!)
Spacing: 20-30m
Altitude: 80-100m
Angle: 0°
```

## 📞 Support

Nếu vẫn gặp vấn đề:

1. Check console log
2. Screenshot polygon + settings
3. Report số waypoints generated vs inside polygon
