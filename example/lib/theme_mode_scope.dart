import 'package:flutter/widgets.dart';

/// Makes the app's current dark-mode flag and the callback to flip it
/// available to any screen in the widget tree.
///
/// This gallery pushes a new screen per component use case (see
/// `screens/home_index_page.dart`), and every one of them shares one header
/// (`widgets/app_header.dart`) with the light/dark toggle. Threading
/// `isDark`/`onDarkChanged` through each pushed screen's constructor would
/// mean every future screen has to carry theme plumbing it has nothing to
/// do with, just to pass it down to its header. Reading both off this
/// ambient scope instead means a new screen only needs to include
/// `AppHeader` — nothing about the toggle touches that screen's own
/// constructor or state.
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
