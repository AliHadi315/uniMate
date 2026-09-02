import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:unimate/app.dart';
import 'package:unimate/core/app_theme.dart';
import 'package:unimate/db/db_provider.dart';
import 'package:unimate/models/course.dart';
import 'package:unimate/models/task.dart';
import 'package:unimate/providers/data_refresh.dart';
import 'package:unimate/widgets/task_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('unimate_widget_test');
    DatabaseProvider.debugDbPathOverride = p.join(tempDir.path, 'test.db');
  });

  tearDown(() async {
    await DatabaseProvider.close();
    DatabaseProvider.debugDbPathOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('a signed-out user lands on the sign-in screen', (tester) async {
    await tester.pumpWidget(const UniMateApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('University ID'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('sign-up is reachable from the sign-in screen', (tester) async {
    await tester.pumpWidget(const UniMateApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('sign-in validates empty fields', (tester) async {
    await tester.pumpWidget(const UniMateApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your university ID'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  group('TaskTile', () {
    Widget wrap(Widget child) => ChangeNotifierProvider(
      create: (_) => DataRefresh(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

    const course = Course(
      id: 1,
      userId: 1,
      name: 'Databases',
      code: 'CS340',
      instructor: 'Dr. Rao',
      semester: 'Fall 2025',
    );

    testWidgets('shows the course code and reminder when asked', (
      tester,
    ) async {
      final task = Task(
        id: 1,
        courseId: 1,
        title: 'Normalisation exercise',
        type: 'Assignment',
        dueDateMillis: DateTime.now()
            .add(const Duration(days: 2))
            .millisecondsSinceEpoch,
        priority: 'High',
        isCompleted: 0,
        reminderMinutesBefore: 60,
      );

      await tester.pumpWidget(
        wrap(TaskTile(task: task, course: course, showCourse: true)),
      );

      expect(find.text('Normalisation exercise'), findsOneWidget);
      expect(find.text('CS340'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('1 hour before'), findsOneWidget);
    });

    testWidgets('lays out inside a scroll view (unbounded height)', (
      tester,
    ) async {
      final tasks = List.generate(
        12,
        (i) => Task(
          id: i + 1,
          courseId: 1,
          title: 'Task $i',
          type: 'Assignment',
          dueDateMillis: DateTime.now()
              .add(Duration(days: i))
              .millisecondsSinceEpoch,
          priority: 'Medium',
          isCompleted: 0,
        ),
      );

      await tester.pumpWidget(
        wrap(
          ListView(
            children: tasks
                .map(
                  (t) => TaskTile(task: t, course: course, showCourse: true),
                )
                .toList(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Task 0'), findsOneWidget);
    });

    testWidgets('swiping right toggles completion', (tester) async {
      bool? toggled;
      final task = Task(
        id: 3,
        courseId: 1,
        title: 'Swipe me',
        type: 'Assignment',
        dueDateMillis: DateTime.now().millisecondsSinceEpoch,
        priority: 'Low',
        isCompleted: 0,
      );

      await tester.pumpWidget(
        wrap(TaskTile(task: task, onToggle: (v) => toggled = v)),
      );

      await tester.drag(find.text('Swipe me'), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });

    testWidgets('swiping left reports deletion without removing the row', (
      tester,
    ) async {
      var deleted = false;
      final task = Task(
        id: 4,
        courseId: 1,
        title: 'Swipe away',
        type: 'Assignment',
        dueDateMillis: DateTime.now().millisecondsSinceEpoch,
        priority: 'Low',
        isCompleted: 0,
      );

      await tester.pumpWidget(
        wrap(
          TaskTile(
            task: task,
            onToggle: (_) {},
            onDelete: () => deleted = true,
          ),
        ),
      );

      await tester.drag(find.text('Swipe away'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      // The list reloads asynchronously, so the tile itself must survive the
      // gesture (a dismissed-but-present Dismissible throws).
      expect(find.text('Swipe away'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ticking the checkbox reports completion', (tester) async {
      bool? reported;
      final task = Task(
        id: 1,
        courseId: 1,
        title: 'Reading',
        type: 'Reading',
        dueDateMillis: DateTime.now().millisecondsSinceEpoch,
        priority: 'Low',
        isCompleted: 0,
      );

      await tester.pumpWidget(
        wrap(TaskTile(task: task, onToggle: (v) => reported = v)),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(reported, isTrue);
    });
  });
}
