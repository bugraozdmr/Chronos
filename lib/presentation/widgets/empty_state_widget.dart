import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import '../../utils/toast_utils.dart';
import '../providers/job_provider.dart';
import '../../services/session_manager.dart';
import '../../services/bluetooth_service.dart';

class EmptyStateWidget extends ConsumerWidget {
  const EmptyStateWidget({super.key});

  void _showStartSessionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Session',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a job to start tracking time.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // List of jobs
                    Consumer(
                      builder: (context, ref, child) {
                        final jobsAsync = ref.watch(jobsProvider);
                        return jobsAsync.when(
                          data: (jobs) {
                            if (jobs.isEmpty) {
                              return const Center(
                                child: Text('No jobs available. Create one first in the Jobs tab.'),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: jobs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final job = jobs[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await ref.read(sessionManagerProvider).startSession(job.name);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.work_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 12),
                                        Text(job.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, s) => Center(child: Text('Error: $e')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetooth = ref.watch(bluetoothServiceProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.timer_outlined, 
            size: 48, 
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Ready to Focus',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Start a session manually or trigger it from your device.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[500], height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          height: 48,
          child: FilledButton.icon(
            onPressed: () {
              if (!bluetooth.isConnected) {
                showChronosToast(
                  context: context,
                  type: ToastificationType.warning,
                  title: 'Bluetooth Required',
                  description: 'Please connect to your HC-05 device first.',
                );
                return;
              }
              _showStartSessionSheet(context, ref);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
