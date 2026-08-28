import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../providers/settings_provider.dart';
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
                  'UniMate • version 0.2.0',
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

    if (saved != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await auth.updateProfile(
      fullName: nameCtrl.text,
      universityName: uniCtrl.text,
      country: countryCtrl.text,
    );

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Profile updated')),
    );

    nameCtrl.dispose();
    uniCtrl.dispose();
    countryCtrl.dispose();
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

    if (saved != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await auth.updatePassword(
      currentPassword: currentCtrl.text,
      newPassword: newCtrl.text,
    );

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Password updated')),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
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
