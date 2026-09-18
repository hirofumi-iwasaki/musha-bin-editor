// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

import '../infrastructure/settings/language_preferences.dart';

enum AppLanguage { system, en, ja }

enum LanguagePreferenceFailure { load, save }

/// Only the primary UI language counts, not a secondary fallback or region.
Locale resolveAppLocale(AppLanguage selection, List<Locale>? systemLocales) {
  if (selection != AppLanguage.system) return Locale(selection.name);
  return Locale(
    systemLocales != null &&
            systemLocales.isNotEmpty &&
            systemLocales.first.languageCode.toLowerCase() == 'ja'
        ? 'ja'
        : 'en',
  );
}

final class LanguageController extends ChangeNotifier {
  LanguageController({this.preferences});

  final LanguagePreferences? preferences;
  AppLanguage _selection = AppLanguage.system;
  AppLanguage get selection => _selection;
  LanguagePreferenceFailure? failure;
  Future<void> _pending = Future<void>.value();
  bool _disposed = false;
  int _revision = 0;

  Future<void> load() async {
    final revision = _revision;
    try {
      final saved = await preferences?.read();
      if (_disposed || revision != _revision) return;
      _selection =
          AppLanguage.values
              .where((value) => value.name == saved)
              .firstOrNull ??
          AppLanguage.system;
      failure = null;
    } catch (_) {
      if (_disposed || revision != _revision) return;
      _selection = AppLanguage.system;
      failure = LanguagePreferenceFailure.load;
    }
    notifyListeners();
  }

  Future<void> select(AppLanguage value) {
    if (_disposed) return Future<void>.value();
    final revision = ++_revision;
    _selection = value;
    failure = null;
    notifyListeners();
    // A slow earlier save must not overwrite the most recent user choice.
    return _pending = _pending.then((_) async {
      try {
        await preferences?.write(value.name);
      } catch (_) {
        if (!_disposed && revision == _revision) {
          failure = LanguagePreferenceFailure.save;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
