import 'package:flutter/material.dart';
import '../../data/database/database.dart';

class ActiveSessionWidget extends StatelessWidget {
  final Session session;

  const ActiveSessionWidget({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing Active Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('ACTIVE SESSION', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        
        Text(
          session.categoryName.toUpperCase(),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Text(
            'Started at ${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ),
        
        const SizedBox(height: 32),
        
        TextButton.icon(
          onPressed: () {
            _showNoteDialog(context, session);
          },
          icon: const Icon(Icons.note_add),
          label: const Text('Add Note'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  void _showNoteDialog(BuildContext context, Session session) {
    final controller = TextEditingController(text: session.notes ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Session Notes'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What are you working on?',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        );
      }
    );
  }
}
