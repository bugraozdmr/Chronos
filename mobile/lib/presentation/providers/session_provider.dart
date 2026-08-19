import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/session_manager.dart';

enum TimeFilter { today, yesterday, thisWeek, allTime, custom }

final timeFilterProvider = StateProvider<TimeFilter>((ref) => TimeFilter.today);
final customDateProvider = StateProvider<DateTime?>((ref) => null);

final activeSessionStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.sessions).watch().map((sessions) {
    try {
      return sessions.firstWhere((s) => s.status == 'active' || s.status == 'paused');
    } catch (e) {
      return null;
    }
  });
});

final sessionsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllSessions();
});
