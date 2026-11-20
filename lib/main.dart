import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/app_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RebsHrmsApp());
}

class RebsHrmsApp extends StatelessWidget {
  const RebsHrmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'REBS HRMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.dashboard,
      getPages: AppPages.pages,
    );
  }
}
