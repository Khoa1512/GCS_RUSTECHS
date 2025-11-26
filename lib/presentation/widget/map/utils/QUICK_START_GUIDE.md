# 🚀 Quick Start Guide - Polygon Survey

## 📱 How to Use

### Step 1: Open Map Page

Mở trang Map trong ứng dụng.

### Step 2: Tap "Survey Polygon" Button

Nhấn nút **"Survey Polygon"** (màu tím, icon polyline) trong `FloatingMissionActions`.

### Step 3: Draw Polygon

Tap trên map để tạo các điểm polygon:

```
Tap 1 → Tap 2 → Tap 3 → ... → Tap "Finish"
```

**Controls:**

- **Finish** - Hoàn thành polygon và generate waypoints
- **Undo** - Xóa điểm cuối cùng
- **Cancel** - Hủy bỏ và xóa toàn bộ polygon

### Step 4: Configure Survey

Một dialog sẽ hiện ra với các tùy chọn:

- **Spacing** (m) - Khoảng cách giữa các đường bay
- **Angle** (°) - Góc quét (0° = ngang, 90° = dọc)
- **Altitude** (m) - Độ cao bay
- **Overlap** (%) - Độ chồng lấp ảnh

**Note:** Pattern selection bị ẩn vì hệ thống tự động chọn thuật toán tối ưu.

### Step 5: Generate

Nhấn **"Generate"** và hệ thống sẽ:

1. ✅ Phân tích độ phức tạp của polygon
2. ✅ Tự động chọn thuật toán tối ưu
3. ✅ Generate waypoints
4. ✅ Hiển thị trên map

---

## 🎯 What to Expect

### Simple Polygon (Rectangle, Triangle)

```
Console output:
  ⚡ Using LINE SWEEP algorithm

Result:
  - Fast generation (5-15ms)
  - Zigzag pattern
  - 100% coverage
```

### Complex Polygon (L-shape, U-shape)

```
Console output:
  🚀 Using DECOMPOSITION algorithm

Result:
  - Optimal generation (25-50ms)
  - Multi-part optimized pattern
  - 30-50% shorter distance
  - 100% coverage
```

---

## 💡 Tips

### 1. Spacing

```
Recommended spacing:
  - High-res photos: 5-10m
  - Medium-res: 10-20m
  - Low-res/overview: 20-50m

Too small → Too many waypoints, long flight
Too large → Gaps in coverage
```

### 2. Angle

```
Best angle:
  - 0° for horizontal fields
  - 90° for vertical fields
  - Auto-optimized for complex shapes
```

### 3. Polygon Shape

```
✅ Good polygons:
  - Closed shape (last point connects to first)
  - No self-intersections
  - Counter-clockwise order

❌ Avoid:
  - Self-intersecting polygons
  - Very thin/narrow shapes
  - Too many vertices (> 20)
```

### 4. Complex Shapes

```
For L/U shapes:
  → System automatically uses Decomposition
  → 30-50% shorter distance
  → No configuration needed!
```

---

## 🔍 Troubleshooting

### No Waypoints Generated

**Problem:** Dialog shows "Cannot generate survey"

**Solutions:**

1. Check polygon has at least 3 points
2. Check spacing is not too large (should be < 1/10 of polygon size)
3. Check polygon is not self-intersecting
4. Check console for error messages

### Too Many Waypoints

**Problem:** 500+ waypoints generated

**Solutions:**

1. Increase spacing (e.g., 10m → 20m)
2. Reduce polygon area
3. Check if polygon is correct

### Waypoints Outside Polygon

**Problem:** Some waypoints appear outside polygon boundary

**Solutions:**

1. This should NOT happen with current algorithm
2. If it does, check console for errors
3. Report as bug with polygon coordinates

---

## 📊 Performance Guide

### Small Area (< 1 hectare)

```
Spacing: 5-10m
Expected waypoints: 50-150
Flight time: 5-15 minutes
Algorithm: Line Sweep (fast)
```

### Medium Area (1-5 hectares)

```
Spacing: 10-20m
Expected waypoints: 150-500
Flight time: 15-40 minutes
Algorithm: Auto-selected
```

### Large Area (> 5 hectares)

```
Spacing: 20-50m
Expected waypoints: 500-1000
Flight time: 40-80 minutes
Algorithm: Decomposition (if complex)
Recommendation: Split into multiple missions
```

---

## 🎓 Understanding Console Output

### Example 1: Simple Rectangle

```
🎯 Analyzing polygon complexity...
   Polygon vertices: 4
   Polygon area: ~30000m²
   Complexity score: 0.00
   Is complex: NO
   Reason: Simple convex shape, Line Sweep is optimal.

   ⚡ Using LINE SWEEP algorithm (optimal for simple shapes)

🚁 Generating Lawnmower for Polygon...
   Polygon vertices: 4
   Bounding box: 200m x 150m
   Number of lines: 15
   Spacing: 10.0m
   ✅ Generated 120 waypoints
```

**What it means:**

- ✅ Simple shape detected
- ✅ Using fast Line Sweep
- ✅ 120 waypoints for 200x150m area
- ✅ 10m spacing = 15 lines

### Example 2: L-Shaped Field

```
🎯 Analyzing polygon complexity...
   Polygon vertices: 6
   Polygon area: ~45000m²
   Complexity score: 3.50
   Is complex: YES
   Reason: Some concave angles (2). Low area efficiency (55%).

   🚀 Using DECOMPOSITION algorithm (optimal for complex shapes)

🔧 Decomposing polygon into convex parts...
   ✅ Decomposed into 2 convex parts

   📍 Processing part 1/2...
🚁 Generating Lawnmower for Polygon...
      Generated 60 waypoints

   📍 Processing part 2/2...
🚁 Generating Lawnmower for Polygon...
      Generated 45 waypoints

   🔗 Connecting parts with optimal path...
   ✅ Total waypoints: 105
```

**What it means:**

- ✅ Complex shape detected (L-shape)
- ✅ Using optimal Decomposition
- ✅ Split into 2 parts
- ✅ 105 waypoints total (35% less than Line Sweep would generate!)
- ✅ Parts connected optimally

---

## 🎯 Best Practices

### 1. Draw Accurate Polygons

```
✅ Good:
  - Follow field boundaries
  - Avoid obstacles
  - Keep it simple

❌ Bad:
  - Too many unnecessary points
  - Self-intersecting
  - Includes obstacles
```

### 2. Choose Appropriate Spacing

```
Rule of thumb:
  Spacing = Camera FOV × (1 - Overlap)

Example:
  Camera FOV at 50m: 40m
  Overlap: 70%
  Spacing: 40m × (1 - 0.7) = 12m
```

### 3. Check Generated Mission

```
Before uploading to drone:
  ✅ Verify waypoint count is reasonable
  ✅ Check all waypoints are inside polygon
  ✅ Check flight time is within battery limit
  ✅ Check altitude is safe
```

### 4. Test First

```
For new areas:
  1. Draw small test polygon
  2. Generate and verify
  3. If good, draw full area
  4. Generate full mission
```

---

## 📚 Additional Resources

- **`POLYGON_DECOMPOSITION_ALGORITHM.md`** - Detailed algorithm explanation
- **`SURVEY_ALGORITHMS_COMPARISON.md`** - Algorithm comparison
- **`IMPLEMENTATION_SUMMARY.md`** - Technical implementation details
- **`POLYGON_ALGORITHM_EXPLAINED.md`** - Line Sweep algorithm details

---

## 🆘 Need Help?

### Check Console Output

Always check the console for detailed information about what the system is doing.

### Common Issues

1. **No waypoints** → Check spacing and polygon size
2. **Too many waypoints** → Increase spacing
3. **Waypoints outside polygon** → Report as bug
4. **Slow generation** → Normal for complex polygons (25-50ms)

### Report Bugs

If you encounter issues:

1. Note the polygon coordinates
2. Note the config (spacing, angle, altitude)
3. Copy console output
4. Report with details

---

## ✅ Summary

### Simple Workflow

```
1. Tap "Survey Polygon"
2. Draw polygon on map
3. Tap "Finish"
4. Configure (spacing, angle, altitude)
5. Tap "Generate"
6. Review waypoints
7. Upload to drone
```

### Key Points

- ✅ System auto-selects optimal algorithm
- ✅ No need to choose pattern
- ✅ 30-50% shorter distance for complex shapes
- ✅ 100% coverage guaranteed
- ✅ Professional quality results

🎉 **Happy surveying!**
