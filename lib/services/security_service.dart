import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../services/app_setting_service.dart';

class SecurityService {
  static const String _pinHashKey = 'pin_hash';
  static const String _pinSaltKey = 'pin_salt';

  final AppSettingService _appSettingService = AppSettingService();

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(salt + pin);
    return sha256.convert(bytes).toString();
  }

  bool _isValidPinFormat(String pin) {
    final isNumeric = RegExp(r'^\d+$').hasMatch(pin);
    return isNumeric && (pin.length == 4 || pin.length == 6);
  }

  // Sets a new PIN and enables PIN lock. Overwrites any existing PIN.
  Future<void> setPin(String pin) async {
    if (!_isValidPinFormat(pin)) {
      throw Exception('PIN must be 4 or 6 digits.');
    }

    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _appSettingService.setString(_pinSaltKey, salt);
    await _appSettingService.setString(_pinHashKey, hash);
    await _appSettingService.setPinEnabled(true);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _appSettingService.getString(_pinSaltKey);
    final storedHash = await _appSettingService.getString(_pinHashKey);

    if (salt == null || storedHash == null) {
      return false;
    }

    final attemptHash = _hashPin(pin, salt);
    return attemptHash == storedHash;
  }

  Future<void> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) {
      throw Exception('Current PIN is incorrect.');
    }
    await setPin(newPin);
  }

  // Disables PIN lock. The hash/salt are cleared so a disabled PIN
  // can never be silently reused if re-enabled without setting a new one.
  Future<void> disablePin() async {
    await _appSettingService.setPinEnabled(false);
    await _appSettingService.setString(_pinHashKey, '');
    await _appSettingService.setString(_pinSaltKey, '');
  }

  Future<bool> isPinEnabled() {
    return _appSettingService.isPinEnabled();
  }

  Future<bool> isBiometricEnabled() {
    return _appSettingService.isBiometricEnabled();
  }

  // Enabling biometric requires a PIN to already be set, as a fallback
  // unlock method if biometric fails or is unavailable.
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final pinEnabled = await isPinEnabled();
      if (!pinEnabled) {
        throw Exception('Enable a PIN before enabling biometric unlock.');
      }
    }
    await _appSettingService.setBiometricEnabled(enabled);
  }
}