import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ──
const _kDarkMode = 'settings_dark_mode';
const _kNotifications = 'settings_notifications';

// ── SharedPreferences provider ──
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// ── Settings state ──
class SettingsState {
  const SettingsState({
    this.darkMode = false,
    this.notificationsEnabled = true,
  });

  final bool darkMode;
  final bool notificationsEnabled;

  SettingsState copyWith({bool? darkMode, bool? notificationsEnabled}) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

// ── Settings notifier ──
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    state = SettingsState(
      darkMode: _prefs.getBool(_kDarkMode) ?? false,
      notificationsEnabled: _prefs.getBool(_kNotifications) ?? true,
    );
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_kDarkMode, value);
    state = state.copyWith(darkMode: value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_kNotifications, value);
    state = state.copyWith(notificationsEnabled: value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
