import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import 'phone_frame.dart';

/// Profile and preferences: account details, theme, reminders, sign out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: SafeArea(
        child: PhoneFrame(
          child: ListView(
            children: [
              if (user != null) _profileCard(context, user, scheme),
              const SizedBox(height: 18),

              const SectionHeader(title: 'Appearance'),
              AppTile(
                child: Column(
                  children: [
                    _themeOption(
                      context,
                      settings,
                      ThemeMode.system,
                      'System default',
                      Icons.brightness_auto,
                    ),
                    _themeOption(
                      context,
                      settings,
                      ThemeMode.light,
                      'Light',
                      Icons.light_mode,
                    ),
                    _themeOption(
                      context,
                      settings,
                      ThemeMode.dark,
                      'Dark',
                      Icons.dark_mode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const SectionHeader(title: 'Reminders'),
              AppTile(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.remindersEnabled,
                      title: const Text('Task reminders'),
                      subtitle: Text(
                        NotificationService.instance.isSupported
                            ? 'Get a local notification before a task is due'
                            : 'Not supported on this platform',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: NotificationService.instance.isSupported
                          ? (v) => _toggleReminders(context, v)
                          : null,
                    ),
                    if (settings.remindersEnabled) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Default reminder'),
                        subtitle: const Text(
                          'Pre-filled when you create a task',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: DropdownButton<int>(
                          value: settings.defaultReminderMinutes,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('At due')),
                            DropdownMenuItem(value: 30, child: Text('30 min')),
                            DropdownMenuItem(value: 60, child: Text('1 hour')),
                            DropdownMenuItem(
                              value: 180,
                              child: Text('3 hours'),
                            ),
                            DropdownMenuItem(
                              value: 1440,
                              child: Text('1 day'),
                            ),
                          ],
                          onChanged: (v) => v == null
                              ? null
                              : settings.setDefaultReminderMinutes(v),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const SectionHeader(title: 'Daily check-in'),
              AppTile(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.dailySummaryEnabled,
                      title: const Text('Daily agenda reminder'),
                      subtitle: const Text(
                        'One notification each day to open your agenda',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: NotificationService.instance.isSupported
                          ? (v) => _toggleDailySummary(context, v)
                          : null,
                    ),
                    if (settings.dailySummaryEnabled) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Time'),
                        trailing: TextButton.icon(
                          onPressed: () => _pickDailySummaryTime(context),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(
                            settings.dailySummaryTime.format(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const SectionHeader(title: 'Backup'),
              AppTile(
                onTap: () => _exportBackup(context),
                child: const Row(
                  children: [
                    Icon(Icons.upload_file_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Export data'),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
              AppTile(
                onTap: () => _importBackup(context),
                child: const Row(
                  children: [
                    Icon(Icons.download_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Import backup'),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const SectionHeader(title: 'Account'),
              AppTile(
                onTap: () => _editProfile(context),
                child: const Row(
                  children: [
                    Icon(Icons.badge_outlined),
                    SizedBox(width: 12),
                    Expanded(child: Text('Edit profile')),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
              AppTile(
                onTap: () => _changePassword(context),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 12),
                    Expanded(child: Text('Change password')),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
              AppTile(
                onTap: () => _confirmLogout(context),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.high),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          color: AppTheme.high,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'UniMate • version 0.3.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    AuthUser user,
    ColorScheme scheme,
  ) {
    final surfaces = AppSurfaces.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            child: Text(
              user.initials,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.universityName,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'ID ${user.universityId} • ${user.country}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    SettingsProvider settings,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final selected = settings.themeMode == mode;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => settings.setThemeMode(mode),
      leading: Icon(
        icon,
        size: 20,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, size: 20, color: scheme.primary)
          : null,
    );
  }

  Future<void> _toggleReminders(BuildContext context, bool enabled) async {
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission was denied — reminders stay off.',
            ),
          ),
        );
        return;
      }
      await settings.setRemindersEnabled(true);
      await NotificationService.instance.rescheduleAllForUser(auth.userId);
    } else {
      await settings.setRemindersEnabled(false);
      await NotificationService.instance.cancelAll();
    }
  }

  Future<void> _toggleDailySummary(BuildContext context, bool enabled) async {
    final settings = context.read<SettingsProvider>();

    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission was denied.'),
            ),
          );
        }
        return;
      }
      await settings.setDailySummaryEnabled(true);
      await NotificationService.instance.scheduleDailySummary(
        hour: settings.dailySummaryMinutes ~/ 60,
        minute: settings.dailySummaryMinutes % 60,
      );
    } else {
      await settings.setDailySummaryEnabled(false);
      await NotificationService.instance.cancelDailySummary();
    }
  }

  Future<void> _pickDailySummaryTime(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.dailySummaryTime,
    );
    if (picked == null) return;

    final minutes = picked.hour * 60 + picked.minute;
    await settings.setDailySummaryMinutes(minutes);
    if (settings.dailySummaryEnabled) {
      await NotificationService.instance.scheduleDailySummary(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final json = await BackupService.exportJson(auth.userId);
      final stamp = DateTime.now();
      final name =
          'unimate-backup-${stamp.year}'
          '${stamp.month.toString().padLeft(2, '0')}'
          '${stamp.day.toString().padLeft(2, '0')}.json';

      // On Android/iOS the picker writes the provided bytes itself; on
      // desktop it returns a path for us to write.
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save UniMate backup',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (savedPath == null) return; // cancelled

      final file = File(savedPath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsString(json);
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Backup saved to $savedPath')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: $e')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final refresh = context.read<DataRefresh>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;

      final json = await File(path).readAsString();
      final imported = await BackupService.importJson(auth.userId, json);

      refresh.bump();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported $imported course${imported == 1 ? '' : 's'} with their '
            'tasks, grades, classes and resources.',
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import: $e')),
      );
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.fullName);
    final uniCtrl = TextEditingController(text: user.universityName);
    final countryCtrl = TextEditingController(text: user.country);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: uniCtrl,
                decoration: const InputDecoration(labelText: 'University'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: countryCtrl,
                decoration: const InputDecoration(labelText: 'Country'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Read before disposing; the controllers must be released on every path,
    // including cancel (early returns used to leak them).
    final fullName = nameCtrl.text;
    final universityName = uniCtrl.text;
    final country = countryCtrl.text;
    nameCtrl.dispose();
    uniCtrl.dispose();
    countryCtrl.dispose();

    if (saved != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await auth.updateProfile(
      fullName: fullName,
      universityName: universityName,
      country: country,
    );

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Profile updated')),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 6 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    // Same pattern as _editProfile: release the controllers on every path.
    final currentPassword = currentCtrl.text;
    final newPassword = newCtrl.text;
    currentCtrl.dispose();
    newCtrl.dispose();

    if (saved != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await auth.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Password updated')),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'Your courses and tasks stay on this device and will be here when '
          'you sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.high),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    await NotificationService.instance.cancelAll();
    if (!context.mounted) return;

    context.read<DataRefresh>().bump();
    await context.read<AuthProvider>().logout();

    // The auth gate takes over from here.
    navigator.popUntil((route) => route.isFirst);
  }
}
