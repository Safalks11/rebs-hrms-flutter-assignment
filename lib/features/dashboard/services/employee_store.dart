import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../models/employee_model.dart';

class EmployeeStore {
  final AppDatabase database;
  EmployeeStore(this.database);

  Future<EmployeeModel?> load() async {
    final rows = await (await database.db).query('employee_cache', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return EmployeeModel(
      id: row['employee_id'] as String,
      name: row['name'] as String,
      department: row['department'] as String,
    );
  }

  Future<void> save(EmployeeModel employee) async {
    await (await database.db).insert('employee_cache', {
      'employee_id': employee.id,
      'name': employee.name,
      'department': employee.department,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
