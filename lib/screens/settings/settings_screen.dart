import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/app_setting_service.dart';
import '../../services/security_service.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({super.key, required this.onThemeModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettingService _appSettingService = AppSettingService();
  final SecurityService _securityService = SecurityService();
  final BackupService _backupService = BackupService();

  String _currency = 'INR';
  String _theme = 'system';
  bool _pinEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final currency = await _appSettingService.getCurrency();
    final theme = await _appSettingService.getTheme();
    final pinEnabled = await _securityService.isPinEnabled();

    setState(() {
      _currency = currency;
      _theme = theme;
      _pinEnabled = pinEnabled;
      _isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _changeCurrency() async {
    const options = ['INR', 'USD', 'EUR', 'GBP'];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Currency'),
        children: options
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c),
                  child: Text(c),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      await _appSettingService.setCurrency(selected);
      setState(() {
        _currency = selected;
      });
    }
  }

  Future<void> _changeTheme() async {
    const options = {'light': 'Light', 'dark': 'Dark', 'system': 'System Default'};
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme'),
        children: options.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e.key),
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      await _appSettingService.setTheme(selected);
      setState(() {
        _theme = selected;
      });
      final themeMode = switch (selected) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      widget.onThemeModeChanged(themeMode);
    }
  }

  Future<void> _togglePin(bool enable) async {
    if (enable) {
      final pin = await _promptForPin('Set a PIN', confirm: true);
      if (pin == null) return;

      try {
        await _securityService.setPin(pin);
        setState(() {
          _pinEnabled = true;
        });
      } catch (e) {
        _showError(_cleanErrorMessage(e));
      }
    } else {
      final pin = await _promptForPin('Enter current PIN to disable');
      if (pin == null) return;

      final valid = await _securityService.verifyPin(pin);
      if (!valid) {
        _showError('Incorrect PIN.');
        return;
      }

      await _securityService.disablePin();
      setState(() {
        _pinEnabled = false;
      });
    }
  }

  Future<void> _changePin() async {
    final oldPin = await _promptForPin('Enter current PIN');
    if (oldPin == null) return;
    final newPin = await _promptForPin('Set a new PIN', confirm: true);
    if (newPin == null) return;

    try {
      await _securityService.changePin(oldPin, newPin);
      _showError('PIN changed successfully.');
    } catch (e) {
      _showError(_cleanErrorMessage(e));
    }
  }

  Future<String?> _promptForPin(String title, {bool confirm = false}) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN (4 or 6 digits)'),
            ),
            if (confirm)
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (confirm && pinController.text != confirmController.text) {
                _showError('PINs do not match.');
                return;
              }
              Navigator.pop(context, pinController.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    try {
      final directory = await _backupService.getDefaultBackupDirectory();
      final fileName = 'manager_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final path = '$directory/$fileName';
      await _backupService.exportToFile(path);
      _showError('Backup saved to: $path');
    } catch (e) {
      _showError(_cleanErrorMessage(e));
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will replace ALL current data with the backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;

      await _backupService.restoreFromFile(path);
      _showError('Backup restored successfully.');
    } catch (e) {
      _showError(_cleanErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('General', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: Text(_currency),
            onTap: _changeCurrency,
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(_theme == 'system' ? 'System Default' : _theme.toUpperCase()),
            onTap: _changeTheme,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Security', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('PIN Lock'),
            value: _pinEnabled,
            onChanged: _togglePin,
          ),
          if (_pinEnabled)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change PIN'),
              onTap: _changePin,
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export Backup'),
            onTap: _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore Backup'),
            onTap: _restoreBackup,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Pocket Manager'),
            subtitle: Text('Version 1.0.0 (V1)'),
          ),
        ],
      ),
    );
  }
}