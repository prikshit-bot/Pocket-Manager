import '../database/app_setting_dao.dart';
import '../models/app_setting_model.dart';
import '../utils/currency_formatter.dart';

class SettingKeys {
  static const String currency = 'currency';
  static const String theme = 'theme';
  static const String pinEnabled = 'pin_enabled';
  static const String biometricEnabled = 'biometric_enabled';
}

class AppSettingService {
  final AppSettingDao _appSettingDao = AppSettingDao();

  Future<String?> getString(String key) async {
    final setting = await _appSettingDao.getSettingByKey(key);
    return setting?.value;
  }

  // Updates the key if it exists, otherwise inserts it.
  Future<void> setString(String key, String value) async {
    final existing = await _appSettingDao.getSettingByKey(key);
    final now = DateTime.now();

    if (existing == null) {
      await _appSettingDao.insertSetting(
        AppSetting(key: key, value: value, updatedAt: now),
      );
    } else {
      await _appSettingDao.updateSetting(
        AppSetting(
          settingId: existing.settingId,
          key: key,
          value: value,
          updatedAt: now,
        ),
      );
    }
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await getString(key);
    if (value == null) {
      return defaultValue;
    }
    return value == 'true';
  }

  Future<void> setBool(String key, bool value) {
    return setString(key, value ? 'true' : 'false');
  }

  Future<String> getCurrency() async {
    return (await getString(SettingKeys.currency)) ?? 'INR';
  }

  Future<void> setCurrency(String currency) {
    CurrencyFormatter.setCurrency(currency);
    return setString(SettingKeys.currency, currency);
  }

  // Expected values: 'light', 'dark', 'system'
  Future<String> getTheme() async {
    return (await getString(SettingKeys.theme)) ?? 'system';
  }

  Future<void> setTheme(String theme) {
    return setString(SettingKeys.theme, theme);
  }

  Future<bool> isPinEnabled() {
    return getBool(SettingKeys.pinEnabled);
  }

  Future<void> setPinEnabled(bool enabled) {
    return setBool(SettingKeys.pinEnabled, enabled);
  }

  Future<bool> isBiometricEnabled() {
    return getBool(SettingKeys.biometricEnabled);
  }

  Future<void> setBiometricEnabled(bool enabled) {
    return setBool(SettingKeys.biometricEnabled, enabled);
  }

  Future<List<AppSetting>> getAllSettings() {
    return _appSettingDao.getAllSettings();
  }
}