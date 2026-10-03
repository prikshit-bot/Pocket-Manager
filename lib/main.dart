import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'screens/main_screen.dart';
import 'services/security_service.dart';
import 'services/category_service.dart';
import 'services/app_setting_service.dart';
import 'utils/currency_formatter.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper().database;
  await CategoryService().seedDefaultCategories();
  CurrencyFormatter.setCurrency(await AppSettingService().getCurrency());
  final savedTheme = await AppSettingService().getTheme();

  runApp(MyApp(initialThemeMode: _themeModeFromSetting(savedTheme)));
}

ThemeMode _themeModeFromSetting(String theme) {
  switch (theme) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MyApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode = widget.initialThemeMode;

  void _setThemeMode(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: _AppGate(onThemeModeChanged: _setThemeMode),
    );
  }
}

class _AppGate extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const _AppGate({required this.onThemeModeChanged});

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> with WidgetsBindingObserver {
  final SecurityService _securityService = SecurityService();
  bool _isLoading = true;
  bool _pinEnabled = false;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLockState();
    } else if (state == AppLifecycleState.paused && _pinEnabled && mounted) {
      setState(() => _isUnlocked = false);
    }
  }

  Future<void> _loadLockState() async {
    try {
      final enabled = await _securityService.isPinEnabled();
      if (!mounted) return;
      setState(() {
        _pinEnabled = enabled;
        _isLoading = false;
        if (!enabled) _isUnlocked = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pinEnabled = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pinEnabled && !_isUnlocked) {
      return _PinUnlockScreen(
        onUnlocked: () => setState(() => _isUnlocked = true),
      );
    }

    return MainScreen(onThemeModeChanged: widget.onThemeModeChanged);
  }
}

class _PinUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const _PinUnlockScreen({required this.onUnlocked});

  @override
  State<_PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<_PinUnlockScreen> {
  final SecurityService _securityService = SecurityService();
  final TextEditingController _pinController = TextEditingController();
  bool _isChecking = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });

    final valid = await _securityService.verifyPin(_pinController.text);
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isChecking = false;
        _error = 'Incorrect PIN.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Manager')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 16),
            const Text('Enter your PIN to continue'),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onSubmitted: (_) => _unlock(),
              decoration: InputDecoration(
                labelText: 'PIN',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isChecking ? null : _unlock,
              child: _isChecking
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
