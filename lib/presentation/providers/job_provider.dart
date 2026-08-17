import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/session_manager.dart';
import '../../data/database/database.dart';

final jobsProvider = FutureProvider<List<Job>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllJobs();
});
