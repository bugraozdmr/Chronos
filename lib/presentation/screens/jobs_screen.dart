import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/job_provider.dart';
import '../../services/session_manager.dart';
import '../../data/database/database.dart';

/// Opens a shadcn-style bottom sheet for creating or editing a job.
void showJobSheet(BuildContext context, WidgetRef ref, [Job? job]) {
  final nameController = TextEditingController(text: job?.name ?? '');
  final limitController = TextEditingController(text: job?.dailyLimitMinutes?.toString() ?? '');
  final isEditing = job != null;

  final defaultColors = [
    '#ef4444', // Red
    '#3b82f6', // Blue
    '#22c55e', // Green
    '#a855f7', // Purple
    '#f97316', // Orange
    '#eab308', // Yellow
    '#14b8a6', // Teal
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          // Initialize selected color once
          String selectedColorHex = job?.colorHex ?? defaultColors[0];

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          isEditing ? 'Edit Job' : 'New Job',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEditing
                              ? 'Update the details for this job.'
                              : 'Add a new job to track your time.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Job Name Input
                        Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'e.g. Coding, Gaming...',
                            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Daily Limit Input
                        Text(
                          'Daily Limit (minutes)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: limitController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Leave empty for no limit',
                            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Color Picker
                        Text(
                          'Color',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: defaultColors.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final hex = defaultColors[index];
                              final isSelected = selectedColorHex == hex;
                              final color = Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColorHex = hex;
                                  });
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected 
                                      ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                                      : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Save / Update — full width
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;
                              final db = ref.read(databaseProvider);
                              final limit = int.tryParse(limitController.text);

                              if (job == null) {
                                await db.addJob(JobsCompanion(
                                  name: drift.Value(nameController.text.trim()),
                                  dailyLimitMinutes: drift.Value(limit),
                                  colorHex: drift.Value(selectedColorHex),
                                ));
                              } else {
                                await db.updateJob(job.copyWith(
                                  name: nameController.text.trim(),
                                  dailyLimitMinutes: drift.Value(limit),
                                  colorHex: selectedColorHex,
                                ));
                              }

                              ref.invalidate(jobsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEditing ? 'Update' : 'Create',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Cancel — text only
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ),

                        // Delete — only when editing
                        if (isEditing) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton.icon(
                              onPressed: () async {
                                final db = ref.read(databaseProvider);
                                await db.deleteJob(job);
                                ref.invalidate(jobsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Delete this job', style: TextStyle(fontWeight: FontWeight.w500)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      );
    },
  );
}

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return jobsAsync.when(
      data: (jobs) {
        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.work_outline_rounded,
                  size: 56,
                  color: isDark ? Colors.white24 : Colors.black45,
                ),
                const SizedBox(height: 16),
                Text(
                  'No jobs yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + in the top bar to add one.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final job = jobs[index];
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 22,
                  ),
                ),
                title: Text(
                  job.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  job.dailyLimitMinutes != null
                      ? '${job.dailyLimitMinutes} min / day'
                      : 'No daily limit',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onPressed: () => showJobSheet(context, ref, job),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
