import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Jobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get dailyLimitMinutes => integer().nullable()(); // null means no limit
  TextColumn get colorHex => text().withDefault(const Constant('#FF5252'))();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get categoryName => text()(); // kept for backward compatibility (will store Job name)
  IntColumn get jobId => integer().nullable().references(Jobs, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get status => text()(); // active, completed, paused
  TextColumn get notes => text().nullable()();
}

@DriftDatabase(tables: [Sessions, Jobs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // Bumped version for Jobs rename

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Seed default jobs
        await into(jobs).insert(JobsCompanion(name: const Value('Coding'), colorHex: const Value('#3b82f6'), dailyLimitMinutes: const Value(120)));
        await into(jobs).insert(JobsCompanion(name: const Value('Gaming'), colorHex: const Value('#ef4444'), dailyLimitMinutes: const Value(60)));
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Since we are in active early development, dropping and recreating is easiest for schema rename.
        // In a real prod app, we'd use proper migrations.
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
          await m.createTable(table);
        }
      },
    );
  }

  // Queries
  Future<List<Session>> getAllSessions() => select(sessions).get();
  Stream<List<Session>> watchAllSessions() => select(sessions).watch();
  Future<Session?> getActiveSession() => 
      (select(sessions)..where((t) => t.status.equals('active') | t.status.equals('paused'))).getSingleOrNull();

  void forceRefresh() {
    notifyUpdates({TableUpdate('sessions')});
  }

  Future<int> addSession(SessionsCompanion entry) {
    return into(sessions).insert(entry);
  }
  
  Future<bool> updateSession(Session session) {
    return update(sessions).replace(session);
  }

  Future<List<Job>> getAllJobs() => select(jobs).get();
  
  Future<Job?> getJobByName(String name) => 
      (select(jobs)..where((j) => j.name.equals(name))).getSingleOrNull();

  Future<int> addJob(JobsCompanion entry) => into(jobs).insert(entry);
  Future<bool> updateJob(Job job) => update(jobs).replace(job);
  Future<int> deleteJob(Job job) => delete(jobs).delete(job);
}



LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'chronos_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
