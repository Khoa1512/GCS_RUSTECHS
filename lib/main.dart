import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skylink/core/controller/app_binding.dart';
import 'package:skylink/core/router/app_navigation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:skylink/core/theme/app_theme.dart';
import 'package:skylink/responsive/responsive_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    // Configure window for desktop

  await dotenv.load(fileName: '.env');
  AppBinding().dependencies();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900), // Initial size
    minimumSize: Size(1200, 800), // Minimum size
    center: true, // Center on screen
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'VTOL Control System',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

void configEasyLoading() {
  EasyLoading.instance
    ..backgroundColor = AppColors.secondaryColor
    ..indicatorColor = AppColors.primaryColor
    ..textColor = Colors.white
    ..loadingStyle = EasyLoadingStyle.custom;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Skylink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: AppNavigation.router,
      builder: (context, child) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 1200, // Minimum app width
            minHeight: 800, // Minimum app height
          ),
          child: SafeSizedContainer(child: child ?? const SizedBox()),
        );

      },
    );
  }
}
