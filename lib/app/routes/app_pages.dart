import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/features/dashboard/bindings/dashboard_binding.dart';
import 'package:rebs_hrms_assignment/features/dashboard/views/dashboard_view.dart';

class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.dashboard,
      page: () => DashboardScreen(),
      binding: DashboardBinding(),
    ),
  ];
}
