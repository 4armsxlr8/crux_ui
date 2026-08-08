import 'package:flutter/widgets.dart';

/// Makes the app's current dark-mode flag and the callback to flip it
/// available to any screen in the widget tree.
///
/// The 設定 tab's ダークモード `CruxSwitch` row is the only control that
/// reads and writes this scope; every other screen reads [isDark] only to
/// resolve which `CruxThemeData` is active. Threading `isDark`/
/// `onDarkChanged` through every screen's constructor instead would mean
/// each one carries theme plumbing it has nothing to do with, just to pass
/// it further down. Reading both off this ambient scope means a screen with
/// no theme UI of its own never has to know this flag exists.
class ThemeModeScope extends InheritedWidget {
  /// Creates a scope carrying the current [isDark] flag and the
  /// [onDarkChanged] callback to invoke when the toggle changes.
  const ThemeModeScope({
    super.key,
    required this.isDark,
    required this.onDarkChanged,
    required super.child,
  });

  /// Whether the dark Crux theme is currently active.
  final bool isDark;

  /// Called with the new value when the light/dark toggle changes.
  final ValueChanged<bool> onDarkChanged;

  /// Finds the nearest [ThemeModeScope] above [context].
  static ThemeModeScope of(BuildContext context) {
    final ThemeModeScope? scope = context
        .dependOnInheritedWidgetOfExactType<ThemeModeScope>();
    assert(scope != null, 'No ThemeModeScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) =>
      isDark != oldWidget.isDark;
}
