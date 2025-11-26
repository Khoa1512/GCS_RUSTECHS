# 🔷 Polygon Survey Generator

## 📁 File Structure

```
lib/presentation/widget/map/utils/
├── survey_generator.dart              # Bounding box survey (existing)
├── polygon_survey_generator.dart      # Polygon survey (NEW!)
└── POLYGON_SURVEY_GENERATOR_README.md
```

## 🎯 Tách biệt rõ ràng:

### **survey_generator.dart**

- ✅ Xử lý survey cho **Bounding Box** (hình chữ nhật)
- ✅ Generate Lawnmower, Grid, Perimeter cho area vuông
- ✅ Không phụ thuộc polygon

### **polygon_survey_generator.dart** (NEW)

- ✅ Xử lý survey cho **Polygon** (đa giác)
- ✅ Filter waypoints inside polygon
- ✅ Better debug info với polygon area, coverage %
- ✅ Recommended spacing calculation

## 🔧 API

### PolygonSurveyGenerator.generateForPolygon()

```dart
final waypoints = PolygonSurveyGenerator.generateForPolygon(
  polygon: [LatLng(...), LatLng(...), ...],
  config: SurveyConfig(
    pattern: SurveyPattern.lawnmower,
    spacing: 10.0,
    altitude: 50.0,
    angle: 0.0,
    overlap: 70.0,
  ),
);
```

## 📊 Enhanced Debug Output

```
🔍 Polygon Survey Generation:
   Polygon vertices: 12
   Polygon area: 28500m²
   Bounding box: 200m x 150m
   Total waypoints: 168
   Inside polygon: 42
   Pattern: SurveyPattern.lawnmower
   Spacing: 5.0m
   Coverage: 25.0%
```

### Nếu không có waypoints:

```
⚠️  No waypoints inside polygon!
   Recommendations:
   - Try spacing: 15.0m (current: 5.0m)
   - Your spacing is TOO LARGE for this polygon!
   - Polygon is small (2500m²), draw larger area
```

## 🚀 Key Features

### 1. **Smart Spacing Recommendations**

```dart
// Auto-calculate recommended spacing
final recommendedSpacing = min(width, height) / 10;

// For 200m x 150m polygon:
// Recommended: 15m
```

### 2. **Area Calculation**

```dart
final polygonArea = bounds.width * bounds.height;
// Returns approximate area in m²
```

### 3. **Coverage Percentage**

```dart
final coverage = (filteredWaypoints.length / totalWaypoints * 100);
// Shows how much of bounding box is actually used
```

### 4. **Ray Casting Algorithm**

```dart
static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  // Vẽ tia từ point ra phải
  // Đếm số lần cắt viền
  // Lẻ = inside, Chẵn = outside
}
```

## 🎨 Usage Example

### Từ map_page_handlers.dart:

```dart
void showSurveyConfigDialogForPolygon() {
  showDialog(
    context: context,
    builder: (context) => SurveyConfigDialog(
      onConfirm: (config) {
        // Use PolygonSurveyGenerator instead of SurveyGenerator
        final waypoints = PolygonSurveyGenerator.generateForPolygon(
          polygon: state.polygonPoints,
          config: config,
        );

        if (waypoints.isEmpty) {
          showInfo('Không thể tạo survey với cấu hình này');
          return;
        }

        // Add waypoints to mission
        state.routePoints.addAll(waypoints);
        state.reorderWaypoints();
      },
    ),
  );
}
```

## 📈 Workflow

```
1. User vẽ polygon
   └─> polygonPoints: [LatLng, LatLng, ...]

2. User chọn "Hoàn thành"
   └─> showSurveyConfigDialogForPolygon()

3. User chọn pattern + config
   └─> PolygonSurveyGenerator.generateForPolygon()
       ├─> Calculate bounding box
       ├─> Generate waypoints in bounding box
       ├─> Filter waypoints inside polygon
       └─> Return filtered waypoints

4. Add waypoints to mission
   └─> state.routePoints.addAll(waypoints)
```

## 🔍 Debug Tips

### Check console log:

```bash
flutter run | grep "Polygon Survey"
```

### Look for:

- **Polygon area:** Nếu < 5000m² = quá nhỏ
- **Inside polygon: 0** = spacing quá lớn
- **Coverage < 10%** = polygon hình dạng kỳ lạ

## ⚠️ Common Issues

### Issue 1: "No waypoints inside polygon"

```
Cause: Spacing > polygon size / 10
Fix: Reduce spacing or draw larger polygon
```

### Issue 2: "Coverage very low (< 20%)"

```
Cause: Polygon shape very irregular
Fix: Draw simpler polygon (rectangular, convex)
```

### Issue 3: "Too many waypoints"

```
Cause: Spacing too small
Fix: Increase spacing to 10-20m
```

## 💾 Benefits of Separation

### Before (survey_generator.dart):

- ❌ 460 lines
- ❌ Mix bounding box + polygon logic
- ❌ Hard to debug
- ❌ Poor error messages

### After:

- ✅ survey_generator.dart: 340 lines (bounding box only)
- ✅ polygon_survey_generator.dart: 240 lines (polygon only)
- ✅ Clear separation of concerns
- ✅ Better debug output
- ✅ Helpful recommendations

## 🎯 Recommended Settings per Polygon Size

### Small (< 5,000m²)

```dart
SurveyConfig(
  spacing: 3-5m,
  pattern: SurveyPattern.lawnmower,
)
```

### Medium (5,000 - 50,000m²)

```dart
SurveyConfig(
  spacing: 10-15m,
  pattern: SurveyPattern.lawnmower,
)
```

### Large (> 50,000m²)

```dart
SurveyConfig(
  spacing: 20-30m,
  pattern: SurveyPattern.lawnmower, // Grid tốn thời gian!
)
```

## 🧪 Test Cases

### Test 1: Simple Rectangle

```dart
polygon = [
  LatLng(21.0, 105.0),
  LatLng(21.0, 105.002),
  LatLng(20.998, 105.002),
  LatLng(20.998, 105.0),
];
spacing = 10m
→ Expect: 20-30 waypoints
```

### Test 2: L-Shape

```dart
polygon = 7 points forming L shape
spacing = 15m
→ Expect: 10-20 waypoints
→ Coverage: 40-60%
```

### Test 3: Small Area

```dart
polygon = 50m x 50m (2500m²)
spacing = 5m
→ Expect: 5-10 waypoints
→ Warning if spacing > 5m
```
