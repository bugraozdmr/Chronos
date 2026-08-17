import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/session_manager.dart';

final activeSessionStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.sessions).watch().map((sessions) {
    try {
      return sessions.firstWhere((s) => s.status == 'active');
    } catch (e) {
      return null;
    }
  });
});

final sessionsProvider = FutureProvider((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllSessions();
});
