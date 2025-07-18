# Responsive Design System for Skylink Flutter App

This directory contains a comprehensive responsive design system that adapts your Flutter app to different screen sizes - mobile, tablet, and desktop.

## 🏗️ Architecture

```
responsive/
├── demension.dart          # Breakpoints, spacing, and responsive utilities
├── responsive_layout.dart  # Main responsive layout widgets
├── mobile_body.dart        # Mobile-specific layout components
├── tablet_body.dart        # Tablet-specific layout components
├── desktop_body.dart       # Desktop-specific layout components
├── responsive_widgets.dart # Additional utility widgets
└── README.md              # This documentation
```

## 📱 Breakpoints

- **Mobile**: < 600px width
- **Tablet**: 600px - 1200px width  
- **Desktop**: > 1200px width

## 🚀 Quick Start

### 1. Basic Responsive Layout

```dart
import 'package:skylink/responsive/responsive_widgets.dart';

ResponsiveLayout(
  mobile: MobileBody(child: YourMobileWidget()),
  tablet: TabletBody(child: YourTabletWidget()),  // Optional
  desktop: DesktopBody(child: YourDesktopWidget()),
)
```

### 2. Using Context Extensions

```dart
// Check device type
if (context.isMobile) {
  // Mobile-specific code
} else if (context.isTablet) {
  // Tablet-specific code
} else if (context.isDesktop) {
  // Desktop-specific code
}

// Responsive spacing
SizedBox(height: context.responsiveSpacing())

// Responsive padding
Container(
  padding: context.responsivePadding(),
  child: child,
)

// Grid columns
GridView.count(
  crossAxisCount: context.gridColumns(mobile: 1, tablet: 2, desktop: 3),
  children: items,
)
```

### 3. Responsive Builder Pattern

```dart
ResponsiveBuilder(
  builder: (context, deviceType) {
    switch (deviceType) {
      case DeviceType.mobile:
        return MobileSpecificWidget();
      case DeviceType.tablet:
        return TabletSpecificWidget();
      case DeviceType.desktop:
        return DesktopSpecificWidget();
    }
  },
)
```

## 🧩 Available Components

### Layout Bodies

#### MobileBody
```dart
MobileBody(
  child: YourWidget(),
  hasScrollbar: true,  // Default: true
  padding: EdgeInsets.all(16),
  safeArea: true,      // Default: true
)
```

#### TabletBody
```dart
TabletBody(
  child: YourWidget(),
  hasScrollbar: true,
  maxWidth: 800,       // Default: 800
  padding: EdgeInsets.all(24),
)
```

#### DesktopBody
```dart
DesktopBody(
  child: YourWidget(),
  hasScrollbar: true,
  maxWidth: 1200,      // Default: 1200
  padding: EdgeInsets.all(48),
)
```

### Grid Components

#### Mobile/Tablet/Desktop Grids
```dart
MobileGrid(
  crossAxisCount: 2,
  children: [Widget1(), Widget2(), Widget3()],
)

TabletGrid(
  crossAxisCount: 3,
  children: items,
)

DesktopGrid(
  crossAxisCount: 4,
  children: items,
)
```

### Layout Helpers

#### Two-Column Layouts
```dart
DesktopTwoColumnLayout(
  leftChild: Sidebar(),
  rightChild: MainContent(),
  leftFlex: 1,
  rightFlex: 2,
)

TabletTwoColumnLayout(
  leftChild: Navigation(),
  rightChild: Content(),
)
```

### Cards

#### Responsive Cards
```dart
MobileCard(child: content)
TabletCard(child: content)
DesktopCard(child: content)
```

### Utility Widgets

#### ResponsiveContainer
```dart
ResponsiveContainer(
  child: YourWidget(),
  mobilePadding: EdgeInsets.all(16),
  tabletPadding: EdgeInsets.all(24),
  desktopPadding: EdgeInsets.all(32),
  mobileMaxWidth: null,
  tabletMaxWidth: 800,
  desktopMaxWidth: 1200,
)
```

#### ResponsiveGap
```dart
ResponsiveGap() // Vertical gap
ResponsiveGap.horizontal() // Horizontal gap

// Custom sizes
ResponsiveGap(
  mobileSize: 16,
  tabletSize: 24,
  desktopSize: 32,
)
```

#### ResponsiveFlex
```dart
ResponsiveFlex(
  forceVerticalOnMobile: true, // Column on mobile, Row on larger screens
  children: [Widget1(), Widget2()],
)
```

## 📏 Spacing System

```dart
class ResponsiveDimensions {
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;   // Default mobile
  static const double spacingL = 24.0;   // Default tablet
  static const double spacingXL = 32.0;  // Default desktop
  static const double spacingXXL = 48.0;
}
```

## 🎨 Best Practices

### 1. Start with Mobile-First Design
```dart
ResponsiveLayout(
  mobile: MyMobileLayout(),
  // tablet: falls back to mobile if not provided
  desktop: MyDesktopLayout(),
)
```

### 2. Use Consistent Spacing
```dart
// Good
SizedBox(height: context.responsiveSpacing())

// Avoid
SizedBox(height: context.isMobile ? 16 : 32)
```

### 3. Leverage Grid Systems
```dart
ResponsiveGridView(
  mobileColumns: 1,
  tabletColumns: 2,
  desktopColumns: 3,
  children: items,
)
```

### 4. Responsive Navigation
The app automatically uses:
- **Mobile**: Bottom navigation bar
- **Tablet**: Navigation rail with labels
- **Desktop**: Extended navigation rail with app branding

## 🔧 Customization

### Custom Breakpoints
Modify `ResponsiveDimensions` in `demension.dart`:

```dart
static const double mobileBreakpoint = 480;    // Custom mobile breakpoint
static const double tabletBreakpoint = 1024;   // Custom tablet breakpoint
```

### Custom Spacing
Add your own spacing constants:

```dart
static const double spacingCustom = 20.0;
```

### Custom Responsive Values
```dart
ResponsiveValue<int>(
  mobile: 1,
  tablet: 2,
  desktop: 3,
).getValue(context)
```

## 📊 Example: Complete Responsive Page

```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Page'),
        centerTitle: !context.isDesktop,
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return MobileBody(
      child: Column(
        children: [
          _buildHeader(),
          ResponsiveGap(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return TabletBody(
      child: Column(
        children: [
          _buildHeader(),
          ResponsiveGap(),
          TabletTwoColumnLayout(
            leftChild: _buildSidebar(),
            rightChild: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return DesktopBody(
      child: Column(
        children: [
          _buildHeader(),
          ResponsiveGap(),
          DesktopTwoColumnLayout(
            leftFlex: 1,
            rightFlex: 3,
            leftChild: _buildSidebar(),
            rightChild: _buildContent(),
          ),
        ],
      ),
    );
  }
}
```

## 🚀 Getting Started in Your Project

1. Import the responsive widgets:
```dart
import 'package:skylink/responsive/responsive_widgets.dart';
```

2. Wrap your content in responsive layouts:
```dart
ResponsiveLayout(
  mobile: YourMobileWidget(),
  desktop: YourDesktopWidget(),
)
```

3. Use context extensions for responsive values:
```dart
context.isMobile
context.responsiveSpacing()
context.responsivePadding()
```

Happy coding! 🎉 