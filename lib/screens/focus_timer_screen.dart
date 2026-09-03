import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../db/course_storage.dart';
import '../db/study_session_storage.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import 'phone_frame.dart';

/// Pomodoro-style focus timer. Completed (or abandoned-after-a-minute)
/// sessions are recorded per course and feed the "study time" statistics.
///
/// The timer only runs while the app is in the foreground — leaving the
/// screen banks whatever full minutes were focused so far.
class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

enum _Phase { idle, running, paused, done }

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  static const _durations = [15, 25, 45, 60];

  List<Course> _courses = [];
  int? _courseId;

  int _plannedMinutes = 25;
  _Phase _phase = _Phase.idle;
  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsedSeconds = 0;
  bool _isBreak = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Bank whatever was focused if the user leaves mid-session.
    _recordIfWorthwhile(fireAndForget: true);
    super.dispose();
  }

  Future<void> _loadCourses() async {
    final userId = context.read<AuthProvider>().userId;
    final courses = await loadCourses(userId);
    if (!mounted) return;
    setState(() => _courses = courses);
  }

  int get _totalSeconds => _plannedMinutes * 60;

  int get _remainingSeconds =>
      (_totalSeconds - _elapsedSeconds).clamp(0, _totalSeconds);

  void _start({bool isBreak = false}) {
    HapticFeedback.selectionClick();
    _ticker?.cancel();
    setState(() {
      _isBreak = isBreak;
      if (isBreak) _plannedMinutes = 5;
      _phase = _Phase.running;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_phase != _Phase.running) return;
    setState(() => _elapsedSeconds++);
    if (_elapsedSeconds >= _totalSeconds) _finish();
  }

  void _pause() {
    setState(() => _phase = _Phase.paused);
  }

  void _resume() {
    setState(() => _phase = _Phase.running);
  }

  Future<void> _stopEarly() async {
    _ticker?.cancel();
    final banked = await _recordIfWorthwhile();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _elapsedSeconds = 0;
      _isBreak = false;
    });
    if (banked > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session ended — $banked minute${banked == 1 ? '' : 's'} recorded.',
          ),
        ),
      );
    }
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    HapticFeedback.heavyImpact();
    await _recordIfWorthwhile();
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
  }

  /// Records full focused minutes (never breaks, never < 1 minute).
  /// Returns how many minutes were banked.
  Future<int> _recordIfWorthwhile({bool fireAndForget = false}) async {
    final startedAt = _startedAt;
    if (_isBreak || startedAt == null) return 0;
    if (_phase != _Phase.running && _phase != _Phase.paused) return 0;

    final minutes = _elapsedSeconds ~/ 60;
    if (minutes < 1) return 0;

    // Read the ids before any await: in the dispose path the context is
    // about to go away.
    final userId = context.read<AuthProvider>().userId;
    final refresh = context.read<DataRefresh>();
    _startedAt = null;

    final future = insertStudySession(
      userId: userId,
      courseId: _courseId,
      startedAt: startedAt,
      minutes: minutes,
    ).then((_) => refresh.bump());

    if (!fireAndForget) await future;
    return minutes;
  }

  String get _clock {
    final r = _remainingSeconds;
    return '${(r ~/ 60).toString().padLeft(2, '0')}:'
        '${(r % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = _phase == _Phase.running || _phase == _Phase.paused;
    final accent = _isBreak ? AppTheme.low : scheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus timer')),
      body: SafeArea(
        child: PhoneFrame(
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Course picker — locked while a session is running so the
              // recorded minutes go where the session started.
              DropdownButtonFormField<int?>(
                initialValue: _courseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Studying for',
                  prefixIcon: Icon(Icons.school_outlined, size: 20),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('General study'),
                  ),
                  ..._courses.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(
                        '${c.code} — ${c.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: running
                    ? null
                    : (v) => setState(() => _courseId = v),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Center(
                  child: SizedBox(
                    height: 240,
                    width: 240,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: _totalSeconds == 0
                                ? 0
                                : _elapsedSeconds / _totalSeconds,
                          ),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, value, _) =>
                              CircularProgressIndicator(
                            value: _phase == _Phase.idle ? 0 : value,
                            strokeWidth: 10,
                            color: accent,
                            backgroundColor:
                                scheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _phase == _Phase.done ? '🎉' : _clock,
                                style: TextStyle(
                                  fontSize:
                                      _phase == _Phase.done ? 44 : 48,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                switch (_phase) {
                                  _Phase.idle => 'Ready to focus',
                                  _Phase.running =>
                                    _isBreak ? 'Break' : 'Focusing…',
                                  _Phase.paused => 'Paused',
                                  _Phase.done => _isBreak
                                      ? 'Break over'
                                      : '$_plannedMinutes min focused!',
                                },
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_phase == _Phase.idle) ...[
                Wrap(
                  spacing: 8,
                  children: _durations
                      .map(
                        (m) => ChoiceChip(
                          label: Text('$m min'),
                          selected: _plannedMinutes == m,
                          onSelected: (_) =>
                              setState(() => _plannedMinutes = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _start(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start focusing'),
                  ),
                ),
              ] else if (running) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _stopEarly,
                        icon: const Icon(Icons.stop),
                        label: const Text('End'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _phase == _Phase.running ? _pause : _resume,
                        icon: Icon(
                          _phase == _Phase.running
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          _phase == _Phase.running ? 'Pause' : 'Resume',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep the app open — the timer runs in the foreground.',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                // done
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _phase = _Phase.idle;
                          _elapsedSeconds = 0;
                          _isBreak = false;
                          _plannedMinutes = 25;
                        }),
                        icon: const Icon(Icons.replay),
                        label: const Text('New session'),
                      ),
                    ),
                    if (!_isBreak) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.low,
                          ),
                          onPressed: () => _start(isBreak: true),
                          icon: const Icon(Icons.free_breakfast),
                          label: const Text('5 min break'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
