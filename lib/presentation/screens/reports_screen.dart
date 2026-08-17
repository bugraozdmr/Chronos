import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Reports', style: TextStyle(letterSpacing: -0.5)),
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text("No data to display."));
          }

          // Simple grouping by category
          final Map<String, int> categoryDurations = {};
          for (var s in sessions) {
            if (s.durationSeconds != null && s.durationSeconds! > 0) {
              categoryDurations[s.categoryName] = (categoryDurations[s.categoryName] ?? 0) + s.durationSeconds!;
            }
          }

          if (categoryDurations.isEmpty) {
            return const Center(child: Text("No completed sessions."));
          }

          final List<PieChartSectionData> pieData = [];
          final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
          int c = 0;
          
          categoryDurations.forEach((key, value) {
            pieData.add(PieChartSectionData(
              color: colors[c % colors.length],
              value: value.toDouble(),
              title: '${(value/60).toStringAsFixed(0)}m',
              radius: 60,
              titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ));
            c++;
          });

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Total Time Distribution", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: pieData,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text("Legend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: categoryDurations.keys.length,
                    itemBuilder: (context, index) {
                      final key = categoryDurations.keys.elementAt(index);
                      final val = categoryDurations[key]!;
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: colors[index % colors.length], radius: 10),
                        title: Text(key),
                        trailing: Text('${(val/60).toStringAsFixed(0)} mins', style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }
}
