class DbTables {
  static const dbName = 'unimate.db';

  /// v1 courses/tasks/resources
  /// v2 users
  /// v3 per-user courses, salted passwords, task notes + reminders, chat history
  /// v4 class timetable, grades, recurring tasks, attachments, archiving
  static const dbVersion = 4;

  static const courses = 'courses';
  static const tasks = 'tasks';
  static const resources = 'resources';
  static const users = 'users';
  static const chatSessions = 'chat_sessions';
  static const chatMessages = 'chat_messages';
  static const classSessions = 'class_sessions';
  static const grades = 'grades';

  static const createUsers =
      '''
  CREATE TABLE IF NOT EXISTS $users(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fullName TEXT NOT NULL,
    universityName TEXT NOT NULL,
    universityId TEXT NOT NULL UNIQUE,
    country TEXT NOT NULL,
    password TEXT NOT NULL,
    salt TEXT NOT NULL DEFAULT ''
  );
  ''';

  static const createCourses =
      '''
  CREATE TABLE IF NOT EXISTS $courses(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    instructor TEXT NOT NULL,
    semester TEXT NOT NULL,
    colorValue INTEGER NOT NULL DEFAULT 0,
    archived INTEGER NOT NULL DEFAULT 0
  );
  ''';

  static const createTasks =
      '''
  CREATE TABLE IF NOT EXISTS $tasks(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    courseId INTEGER NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL,
    dueDateMillis INTEGER NOT NULL,
    priority TEXT NOT NULL,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    notes TEXT NOT NULL DEFAULT '',
    reminderMinutesBefore INTEGER,
    completedAtMillis INTEGER,
    recurrenceDays INTEGER,
    attachmentPath TEXT,
    FOREIGN KEY(courseId) REFERENCES $courses(id) ON DELETE CASCADE
  );
  ''';

  static const createResources =
      '''
  CREATE TABLE IF NOT EXISTS $resources(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    courseId INTEGER NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL,
    value TEXT NOT NULL,
    FOREIGN KEY(courseId) REFERENCES $courses(id) ON DELETE CASCADE
  );
  ''';

  static const createChatSessions =
      '''
  CREATE TABLE IF NOT EXISTS $chatSessions(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL,
    createdAtMillis INTEGER NOT NULL,
    updatedAtMillis INTEGER NOT NULL
  );
  ''';

  static const createChatMessages =
      '''
  CREATE TABLE IF NOT EXISTS $chatMessages(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionId INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    createdAtMillis INTEGER NOT NULL,
    FOREIGN KEY(sessionId) REFERENCES $chatSessions(id) ON DELETE CASCADE
  );
  ''';

  /// Weekly recurring lectures/labs. weekday follows DateTime: 1=Mon … 7=Sun.
  /// Times are minutes since midnight so no timezone maths is needed.
  static const createClassSessions =
      '''
  CREATE TABLE IF NOT EXISTS $classSessions(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    courseId INTEGER NOT NULL,
    weekday INTEGER NOT NULL,
    startMinutes INTEGER NOT NULL,
    endMinutes INTEGER NOT NULL,
    location TEXT NOT NULL DEFAULT '',
    FOREIGN KEY(courseId) REFERENCES $courses(id) ON DELETE CASCADE
  );
  ''';

  /// Assessment results. weight is the share of the final grade in percent;
  /// weights of 0 fall back to an unweighted average.
  static const createGrades =
      '''
  CREATE TABLE IF NOT EXISTS $grades(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    courseId INTEGER NOT NULL,
    title TEXT NOT NULL,
    score REAL NOT NULL,
    maxScore REAL NOT NULL,
    weight REAL NOT NULL DEFAULT 0,
    createdAtMillis INTEGER NOT NULL,
    FOREIGN KEY(courseId) REFERENCES $courses(id) ON DELETE CASCADE
  );
  ''';

  /// Indexes for the lookups the app performs on every screen.
  static const createIndexes = <String>[
    'CREATE INDEX IF NOT EXISTS idx_courses_user ON $courses(userId);',
    'CREATE INDEX IF NOT EXISTS idx_tasks_course ON $tasks(courseId);',
    'CREATE INDEX IF NOT EXISTS idx_tasks_due ON $tasks(dueDateMillis);',
    'CREATE INDEX IF NOT EXISTS idx_resources_course ON $resources(courseId);',
    'CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON $chatMessages(sessionId);',
    'CREATE INDEX IF NOT EXISTS idx_class_sessions_course ON $classSessions(courseId);',
    'CREATE INDEX IF NOT EXISTS idx_grades_course ON $grades(courseId);',
  ];
}
