import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'jobs_screen.dart';
import 'reports_screen.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    final screens = [
      const HomeScreen(),
      const JobsScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // The current screen
          IndexedStack(
            index: currentIndex,
            children: screens,
          ),
          
          // Floating Bottom Navigation Bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 32, // Floating slightly above the bottom
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavBarItem(
                    icon: Icons.timer,
                    label: 'Focus',
                    isSelected: currentIndex == 0,
                    onTap: () => ref.read(navigationIndexProvider.notifier).state = 0,
                  ),
                  _NavBarItem(
                    icon: Icons.work,
                    label: 'Jobs',
                    isSelected: currentIndex == 1,
                    onTap: () => ref.read(navigationIndexProvider.notifier).state = 1,
                  ),
                  _NavBarItem(
                    icon: Icons.bar_chart,
                    label: 'Reports',
                    isSelected: currentIndex == 2,
                    onTap: () => ref.read(navigationIndexProvider.notifier).state = 2,
                  ),
                ],
              ),
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
    final color = isSelected 
        ? Theme.of(context).colorScheme.primary 
        : Colors.grey;
        
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
