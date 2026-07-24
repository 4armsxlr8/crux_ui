# Changelog

## 0.2.0

- Added `CruxButton`, Crux UI's first interactive atom: a pill-shaped
  button with three variants (`filled` / `tonal` / `ghost`, via
  `CruxButtonVariant`) and three sizes (`small` / `medium` / `large`, via
  `CruxButtonSize`). Every size keeps at least a 44 logical pixel tap
  target even when its visible pill is shorter than that, and its label is
  always single-line with an ellipsis so a `CruxButton` can never overflow
  its layout regardless of width or label length.
- Pressing a `CruxButton` scales it down to 0.96 and springs back with a
  slight bounce on release, combined with a translucent state-layer tint
  (darkens in light mode, lightens in dark mode). This is powered by the new
  `CruxMotion` token, which wraps the `motor` package internally without
  exposing any of its types in Crux UI's public API — a future engine
  swap stays non-breaking, the same guarantee `CruxColors` gives for color
  values.
- Added `CruxColors.onAccent` (`#26251E`, fixed in both palettes; ~4.89:1
  contrast against `accent`): the text/icon color for content placed on top
  of an `accent` fill, such as a filled `CruxButton`'s label. Added as an
  optional, defaulted constructor parameter, so existing manual
  `CruxColors(...)` construction keeps compiling unchanged.
- Added `motor` (^1.1.0) as the package's first external dependency, used
  only inside `lib/src/motion.dart`.
- The example app's "はじめる" pill (previously a bespoke `_AccentPillButton`
  prototype) is now a real `CruxButton(variant: tonal)`, and a new "04
  ボタン" showcase section demonstrates every variant/size combination plus
  a disabled state.

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
