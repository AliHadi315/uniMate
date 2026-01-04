class DbTables {
  static const dbName = 'unimate.db';
  static const dbVersion = 1;
  static const courses = 'courses';
  static const tasks = 'tasks';
  static const resources = 'resources';

  static const createCourses =
      '''
  CREATE TABLE $courses(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    instructor TEXT NOT NULL,
    semester TEXT NOT NULL
  );
  ''';

  static const createTasks =
      '''
  CREATE TABLE $tasks(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    courseId INTEGER NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL,
    dueDateMillis INTEGER NOT NULL,
    priority TEXT NOT NULL,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY(courseId) REFERENCES $courses(id) ON DELETE CASCADE
  );
  ''';

  static const createResources =
      '''
  CREATE TABLE $resources(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    courseId INTEGER NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL,
    value TEXT NOT NULL,
    FOREIGN KEY(courseId) REFERENCES $courses(id) ON DELETE CASCADE
  );
  ''';
}
