// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LanguagePreferences {
  Future<String?> read();
  Future<void> write(String value);
}

final class SharedLanguagePreferences implements LanguagePreferences {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const key = 'ui.language';

  @override
  Future<String?> read() => _preferences.getString(key);

  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}
