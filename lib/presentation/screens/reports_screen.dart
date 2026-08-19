import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/job_provider.dart';
import '../../data/database/database.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  // Filter sessions based on selected time range
  List<Session> _filterSessions(List<Session> sessions, TimeFilter filter, DateTime? customDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    return sessions.where((s) {
      if (s.durationSeconds == null || s.durationSeconds! <= 0) return false;
      
      final sessionStart = s.startTime;
      final sessionDay = DateTime(sessionStart.year, sessionStart.month, sessionStart.day);

      switch (filter) {
        case TimeFilter.today:
          return sessionDay.isAtSameMomentAs(today);
        case TimeFilter.yesterday:
          return sessionDay.isAtSameMomentAs(yesterday);
        case TimeFilter.thisWeek:
          return sessionDay.isAfter(weekStart.subtract(const Duration(days: 1)));
        case TimeFilter.allTime:
          return true;
        case TimeFilter.custom:
          if (customDate == null) return true;
          final customDay = DateTime(customDate.year, customDate.month, customDate.day);
          return sessionDay.isAtSameMomentAs(customDay);
      }
    }).toList();
  }

  // Format a duration in seconds as e.g. "1h 5m 12s", "20m 15s", "45s"
  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // Parse hex color
  Color _hexToColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionsAsync = ref.watch(sessionsProvider);
    final jobsAsync = ref.watch(jobsProvider);
    final filter = ref.watch(timeFilterProvider);
    final customDate = ref.watch(customDateProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: sessionsAsync.when(
                data: (allSessions) {
                  final filteredSessions = _filterSessions(allSessions, filter, customDate);
                  
                  if (filteredSessions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 16),
                          const Text("No data for this period", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }

                  // Calculate totals
                  final Map<String, int> categoryDurations = {};
                  int totalSeconds = 0;
                  
                  for (var s in filteredSessions) {
                    final duration = s.durationSeconds!;
                    categoryDurations[s.categoryName] = (categoryDurations[s.categoryName] ?? 0) + duration;
                    totalSeconds += duration;
                  }

                  // Format total time
                  final totalTimeStr = _formatDuration(totalSeconds);

                  // Get top category
                  String topCategory = categoryDurations.keys.first;
                  int maxDuration = categoryDurations[topCategory]!;
                  categoryDurations.forEach((k, v) {
                    if (v > maxDuration) {
                      topCategory = k;
                      maxDuration = v;
                    }
                  });

                  return RefreshIndicator(
                    onRefresh: () async {
                      // ignore: unused_result
                      ref.refresh(sessionsProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // ADDED 120 PADDING AT BOTTOM TO CLEAR NAV BAR
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Summary Cards
                            Row(
                              children: [
                                Expanded(child: _buildSummaryCard('Total Time', totalTimeStr, Icons.timer, isDark)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryCard('Top Focus', topCategory, Icons.star_rounded, isDark)),
                              ],
                            ),
                            const SizedBox(height: 32),
                            
                            // Donut Chart Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    height: 200,
                                    child: jobsAsync.when(
                                      data: (jobs) {
                                        final pieData = <PieChartSectionData>[];
                                        final defaultColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
                                        int colorIndex = 0;

                                        categoryDurations.forEach((key, value) {
                                          // Find job color
                                          Color jobColor = defaultColors[colorIndex % defaultColors.length];
                                          try {
                                            final job = jobs.firstWhere((j) => j.name == key);
                                            jobColor = _hexToColor(job.colorHex, jobColor);
                                          } catch (e) {
                                            // Ignore if job not found
                                          }

                                          pieData.add(PieChartSectionData(
                                            color: jobColor,
                                            value: value.toDouble(),
                                            title: '${((value / totalSeconds) * 100).toStringAsFixed(0)}%',
                                            radius: 30,
                                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                            showTitle: true,
                                          ));
                                          colorIndex++;
                                        });

                                        return PieChart(
                                          PieChartData(
                                            pieTouchData: PieTouchData(enabled: false),
                                            sectionsSpace: 4,
                                            centerSpaceRadius: 50,
                                            sections: pieData,
                                          ),
                                        );
                                      },
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (_, __) => const SizedBox(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Daily/Weekly Bar Chart (Only if 'This Week' is selected)
                            if (filter == TimeFilter.thisWeek) ...[
                              const Text("Activity this Week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: _buildBarChart(context, filteredSessions, isDark),
                              ),
                              const SizedBox(height: 32),
                            ],

                            // Legend / Details
                            const Text("Summary Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: categoryDurations.length,
                              separatorBuilder: (context, index) => Divider(color: isDark ? Colors.white10 : Colors.black12),
                              itemBuilder: (context, index) {
                                final key = categoryDurations.keys.elementAt(index);
                                final val = categoryDurations[key]!;
                                final durStr = _formatDuration(val);
                                
                                return jobsAsync.when(
                                  data: (jobs) {
                                    Color jobColor = Colors.blue;
                                    try {
                                      final job = jobs.firstWhere((j) => j.name == key);
                                      jobColor = _hexToColor(job.colorHex, jobColor);
                                    } catch (e) {}

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: jobColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      title: Text(key, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      trailing: Text(durStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    );
                                  },
                                  loading: () => const SizedBox(),
                                  error: (_, __) => const SizedBox(),
                                );
                              },
                            ),

                            // Session History
                            _buildSessionHistory(filteredSessions, jobsAsync, isDark),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text("Error: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<Session> sessions, bool isDark) {
    // Group by weekday
    final Map<int, int> weekdayDurations = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};
    for (var s in sessions) {
      if (s.durationSeconds != null) {
        weekdayDurations[s.startTime.weekday] = weekdayDurations[s.startTime.weekday]! + s.durationSeconds!;
      }
    }

    double maxVal = 1;
    for (var val in weekdayDurations.values) {
      if (val > maxVal) maxVal = val.toDouble();
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    days[value.toInt() - 1],
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: weekdayDurations.entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 16,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxVal * 1.2,
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildSessionHistory(List<Session> sessions, AsyncValue<List<Job>> jobsAsync, bool isDark) {
    if (sessions.isEmpty) return const SizedBox();
    
    // Sort sessions by start time descending
    final sorted = List<Session>.from(sessions)..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text("Session History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final session = sorted[index];
            final duration = session.durationSeconds ?? 0;
            final durationStr = _formatDuration(duration);

            return jobsAsync.when(
              data: (jobs) {
                Color jobColor = Colors.blue;
                try {
                  final job = jobs.firstWhere((j) => j.name == session.categoryName);
                  jobColor = _hexToColor(job.colorHex, jobColor);
                } catch (e) {}

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: jobColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session.categoryName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatTime(session.startTime)} - ${session.endTime != null ? _formatTime(session.endTime!) : "..."}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (session.notes != null && session.notes!.isNotEmpty) ...[
                            _NoteIconButton(note: session.notes!),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            durationStr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            );
          },
        ),
      ],
    );
  }
}

class _NoteIconButton extends StatefulWidget {
  final String note;

  const _NoteIconButton({required this.note});

  @override
  State<_NoteIconButton> createState() => _NoteIconButtonState();
}

class _NoteIconButtonState extends State<_NoteIconButton> {
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _entry;
  bool _isOpen = false;

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _close() {
    if (_isOpen) {
      _entry?.remove();
      _entry = null;
      _isOpen = false;
    }
  }

  void _toggleNote() {
    if (_isOpen) {
      _close();
      return;
    }

    final box = _btnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    _entry = _showNotePopover(anchor, widget.note);
    _isOpen = true;
  }

  OverlayEntry _showNotePopover(Rect anchor, String note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    const popWidth = 240.0;
    final left = (anchor.right - popWidth).clamp(12.0, screenSize.width - popWidth - 12.0).toDouble();
    final top = anchor.bottom + 8.0;

    final entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: AbsorbPointer(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: popWidth,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F24) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Session Note',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(note, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
    return entry;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _toggleNote,
      child: Container(
        key: _btnKey,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.info_outline,
          size: 14,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }
}
