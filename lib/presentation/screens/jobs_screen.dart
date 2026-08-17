import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/job_provider.dart';
import '../../services/session_manager.dart';
import '../../data/database/database.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  void _showJobDialog(BuildContext context, WidgetRef ref, [Job? job]) {
    final nameController = TextEditingController(text: job?.name ?? '');
    final limitController = TextEditingController(text: job?.dailyLimitMinutes?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(job == null ? 'Add Job' : 'Edit Job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Job Name'),
              ),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily Limit (Minutes)',
                  hintText: 'e.g. 120 (Leave empty for no limit)',
                ),
              ),
            ],
          ),
          actions: [
            if (job != null)
              TextButton(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  await db.deleteJob(job);
                  ref.invalidate(jobsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final db = ref.read(databaseProvider);
                final limit = int.tryParse(limitController.text);
                
                if (job == null) {
                  await db.addJob(JobsCompanion(
                    name: drift.Value(nameController.text),
                    dailyLimitMinutes: drift.Value(limit),
                  ));
                } else {
                  await db.updateJob(job.copyWith(
                    name: nameController.text,
                    dailyLimitMinutes: drift.Value(limit),
                  ));
                }
                
                ref.invalidate(jobsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs & Limits'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJobDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs added.'));
          }
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.work, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(job.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(job.dailyLimitMinutes != null 
                    ? 'Limit: ${job.dailyLimitMinutes} mins' 
                    : 'No limit'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showJobDialog(context, ref, job),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
