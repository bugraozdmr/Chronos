import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
          'Start a session from your device to begin tracking your time automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[500], height: 1.5),
        ),
      ],
    );
  }
}
