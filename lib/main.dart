import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/core/router/app_navigation.dart';
import 'package:skylink/core/theme/app_theme.dart';
import 'package:skylink/responsive/responsive_scaffold.dart';

void main() {
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
        return SafeSizedContainer(child: child ?? const SizedBox());
      },
    );
  }
}
