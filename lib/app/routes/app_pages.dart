import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/features/attendance/presentation/bindings/dashboard_binding.dart';
import 'package:rebs_hrms_assignment/features/attendance/presentation/screens/dashboard_screen.dart';

class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.dashboard,
      page: () => DashboardScreen(),
      binding: DashboardBinding(),
    ),
  ];
}
