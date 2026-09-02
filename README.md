# UniMate

A Flutter study planner for university students: courses, tasks, resources,
progress statistics, and a Gemini-powered study assistant. Everything is stored
locally in SQLite — nothing leaves the device except the messages you send to
the assistant.

## Features

| Area | What you get |
| --- | --- |
| **Accounts** | Sign up / sign in with a university ID. Passwords are stored as salted SHA-256 hashes, and the session is remembered between launches. Each account only sees its own data. |
| **Dashboard** | Greeting, tappable counters that deep-link into the matching view, overall progress, "needs attention" and upcoming task lists. |
| **Courses** | Add, edit, delete, colour-code. Search by name/code/instructor, filter by semester, sort in either direction, per-course completion bar. |
| **Tasks** | Title, type, priority, **due date *and* time**, notes, and an optional reminder. Filter, search and sort. Swipe right to complete or reopen, swipe left to delete — with Undo. |
| **Agenda** | Every task across every course, grouped by day, with range chips (today, next 7 days, upcoming, overdue, all) and search. |
| **Resources** | Notes, links and files per course. Links open in the browser, files open in their default app, and files can be chosen with a file picker. |
| **Reminders** | Local notifications a chosen interval before a task is due, re-armed on launch and after a reboot. Android/iOS/macOS. |
| **Statistics** | Overall completion, a 7-day "tasks completed" bar chart, a priority donut, and per-course progress. |
| **AI assistant** | Chat that can see your real courses and open tasks, uploads images/PDFs to the model, saves chat history to the database, and offers starter prompts. |
| **Settings** | Profile editing, password change, light/dark/system theme, reminder preferences, sign out. |

## Getting started

```bash
flutter pub get
```

Create the environment file (it is git-ignored, but `pubspec.yaml` declares it
as an asset, so it **must exist** or the build fails):

```bash
cp .env.example .env
```

Then put your [Google AI Studio key](https://aistudio.google.com/app/apikey) in
it:

```
GEMINI_API_KEY=your-key-here
```

Leaving it empty is fine — the app still runs and the AI tab explains that the
key is missing.

Run it:

```bash
flutter run
```

Supported targets: Android, iOS, Windows, macOS, Linux. Desktop builds use
`sqflite_common_ffi`, which is initialised automatically in `main()`.

## Tests

```bash
flutter test
```

Covers password hashing, model serialisation and date helpers, plus database
integration tests (per-user scoping, task counters, cascade deletes and the
v2 → v3 schema migration) and widget tests for the auth gate and task tile.

## Project layout

```
lib/
  core/          design tokens, date helpers, password hashing
  db/            schema, migrations and one storage file per table
  models/        Course, Task, Resource, ChatSession/ChatMessage, FileAttachment
  providers/     AuthProvider, SettingsProvider, DataRefresh, GeminiService
  services/      local notifications, study-context builder for the assistant
  screens/       dashboard, courses, course details, agenda, stats, AI, settings, auth
  widgets/       shared tiles, pills, empty states, charts
```

### Database

SQLite, currently at **version 3**:

| Version | Change |
| --- | --- |
| 1 | `courses`, `tasks`, `resources` |
| 2 | `users` |
| 3 | per-user `courses.userId` + `colorValue`, task `notes` / `reminderMinutesBefore` / `completedAtMillis`, salted `users.salt` (existing clear-text passwords are re-hashed in place, so old logins keep working), `chat_sessions` + `chat_messages`, indexes |

Upgrades run automatically on first launch after an update; the migration is
covered by `test/database_test.dart`.
