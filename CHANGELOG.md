# Changelog

## 0.1.0

- Added the Crux design token layer: `CruxColors` (light/dark semantic
  palette), `CruxSpacing` (fixed 4px-based scale), and `CruxTypography`
  (six-step type scale with an overridable font family).
- Added `CruxThemeData` (an immutable bundle of colors, typography, and
  brightness) and `CruxTheme`, a standalone `InheritedWidget` that exposes
  it via `CruxTheme.of(context)` and falls back to `CruxThemeData.light()`
  when no theme has been provided. This does not touch Material's `ThemeData`.
- Added a token showcase `example` app (light/dark toggle, color swatches,
  type scale samples, spacing bars, and a small real-world sample screen)
  demonstrating all of the above.

## 0.0.1

- Initial repository scaffolding for Crux UI.
- No widgets are available yet. `lib/crux_ui.dart` exists as the single public
  entry point and intentionally exports nothing so far.
