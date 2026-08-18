import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import '../../services/session_manager.dart';

class ActiveSessionWidget extends ConsumerStatefulWidget {
  final Session session;

  const ActiveSessionWidget({super.key, required this.session});

  @override
  ConsumerState<ActiveSessionWidget> createState() => _ActiveSessionWidgetState();
}

class _ActiveSessionWidgetState extends ConsumerState<ActiveSessionWidget> {
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    final sm = ref.read(sessionManagerProvider);
    _isPaused = sm.isPaused;
    sm.pauseStream.listen((paused) {
      if (mounted) setState(() => _isPaused = paused);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final sessionManager = ref.watch(sessionManagerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status Badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isPaused
                ? Colors.orange.withOpacity(0.1)
                : Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPaused
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.redAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isPaused ? Colors.orange : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isPaused ? 'PAUSED' : 'ACTIVE SESSION',
                style: TextStyle(
                  color: _isPaused ? Colors.orange : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Job Name
        Text(
          widget.session.categoryName.toUpperCase(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),

        // Live Timer
        StreamBuilder<Duration>(
          stream: sessionManager.durationStream,
          initialData: DateTime.now().difference(widget.session.startTime),
          builder: (context, snapshot) {
            final duration = snapshot.data ?? Duration.zero;
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                color: _isPaused
                    ? Colors.orange.withOpacity(0.7)
                    : Theme.of(context).colorScheme.primary,
              ),
              child: Text(_formatDuration(duration)),
            );
          },
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.grey.withOpacity(isDark ? 0.2 : 0.1)),
          ),
          child: Text(
            'Started at ${widget.session.startTime.hour.toString().padLeft(2, '0')}:${widget.session.startTime.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 16, color: Colors.grey[isDark ? 400 : 600], fontWeight: FontWeight.w500),
          ),
        ),

        const SizedBox(height: 40),

        // Pause / Resume + Stop Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pause / Resume
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  if (_isPaused) {
                    sessionManager.resumeSession();
                  } else {
                    sessionManager.pauseSession();
                  }
                },
                icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                label: Text(
                  _isPaused ? 'Continue' : 'Pause',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _isPaused
                      ? (isDark ? Colors.green.shade700 : Colors.green.shade600)
                      : (isDark ? Colors.orange.shade700 : Colors.orange.shade600),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Stop
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => sessionManager.stopActiveSession(),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        TextButton.icon(
          onPressed: () => _showNoteDialog(context, widget.session),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: SingleChildScrollView(
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
                        'Session Notes',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a note to your current session.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'What are you working on?',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
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
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            // TODO: save note to DB
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save Note', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                      ),
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
  }
}
