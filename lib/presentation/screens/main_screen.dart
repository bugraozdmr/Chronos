import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'jobs_screen.dart';
import 'reports_screen.dart';
import 'devices_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/session_provider.dart';
import '../../services/bluetooth_service.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const _titles = ['Chronos', 'Jobs & Limits', 'Reports'];

  Future<void> _pickCustomDate(BuildContext context, WidgetRef ref) async {
    final currentCustom = ref.read(customDateProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: currentCustom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      ref.read(timeFilterProvider.notifier).state = TimeFilter.custom;
      ref.read(customDateProvider.notifier).state = date;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          _titles[currentIndex],
          style: const TextStyle(letterSpacing: -0.5, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Filter for Reports tab
          if (currentIndex == 2) ...[
            Consumer(builder: (context, ref, _) {
              final filter = ref.watch(timeFilterProvider);
              final customDate = ref.watch(customDateProvider);
              
              return PopupMenuButton<TimeFilter>(
                initialValue: filter,
                onSelected: (selectedFilter) {
                  if (selectedFilter == TimeFilter.custom) {
                    _pickCustomDate(context, ref);
                  } else {
                    ref.read(timeFilterProvider.notifier).state = selectedFilter;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: TimeFilter.today, child: Text('Today')),
                  const PopupMenuItem(value: TimeFilter.yesterday, child: Text('Yesterday')),
                  const PopupMenuItem(value: TimeFilter.thisWeek, child: Text('This Week')),
                  const PopupMenuItem(value: TimeFilter.allTime, child: Text('All Time')),
                  const PopupMenuItem(value: TimeFilter.custom, child: Text('Custom Date')),
                ],
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        filter == TimeFilter.custom && customDate != null
                            ? '${customDate.day}/${customDate.month}/${customDate.year}'
                            : filter.name[0].toUpperCase() + 
                              filter.name.substring(1).replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}'),
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              );
            }),
          ],
          // Bluetooth — only visible on Focus tab when NOT connected
          if (currentIndex == 0 && !ref.watch(bluetoothServiceProvider).isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                );
              },
            ),
          // Theme toggle — always visible, rightmost
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: const [
              HomeScreen(),
              JobsScreen(),
              ReportsScreen(),
            ],
          ),

          // Floating Bottom Navigation Bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavBarItem(
                    icon: Icons.timer_rounded,
                    label: 'Focus',
                    isSelected: currentIndex == 0,
                    onTap: () => ref.read(navigationIndexProvider.notifier).state = 0,
                  ),
                  _NavBarItem(
                    icon: Icons.work_outline_rounded,
                    label: 'Jobs',
                    isSelected: currentIndex == 1,
                    onTap: () => ref.read(navigationIndexProvider.notifier).state = 1,
                  ),
                  _NavBarItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reports',
                    isSelected: currentIndex == 2,
                    onTap: () => ref.read(navigationIndexProvider.notifier).state = 2,
                  ),
                ],
              ),
            ),
          ),

          // Floating Add Job Button (only on Jobs tab)
          if (currentIndex == 1)
            Positioned(
              right: 24,
              bottom: 104, // 24 (nav padding) + 64 (nav height) + 16 (gap)
              child: FloatingActionButton(
                onPressed: () => showJobSheet(context, ref),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 4,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final selectedColor = brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final unselectedColor = brightness == Brightness.dark
        ? Colors.white38
        : Colors.black38;
    final color = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
