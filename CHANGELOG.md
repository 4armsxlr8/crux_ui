# Changelog

## 0.3.0

- Added `CruxRadii` (`m` = 14 / `l` = 16 / `pill` = 9999), a fixed
  corner-radius scale used the same way `CruxSpacing` is: as plain
  constants, no theme required. Added `CruxMotion.pressedScaleSubtle`
  (0.98), a gentler press-scale for large surfaces such as `CruxCard`,
  next to the existing `CruxMotion.pressedScale` (0.96) that compact
  pills like `CruxButton` and `CruxChip` keep using.
- Added `CruxChip`, a pill-shaped filter/tag chip with a `selected` flag
  and an optional `onTap` (omit it, or pass `null`, for a disabled chip —
  the same nullable-callback convention `CruxCard`/`CruxListTile` use).
  Pressing shows the same scale + state-layer feedback as `CruxButton`,
  its label truncates with an ellipsis instead of overflowing, and it keeps
  a 44 logical pixel tap target even though its visible pill is 36 tall. Its
  selected-state border (`CruxColors.accentLine`) is now a solid, opaque
  color rather than a translucent tint, so it clears WCAG 1.4.11's 3:1
  non-text contrast floor against the page background in both palettes.
- Added `CruxCard`, a bordered content container (`surface` background, a
  1px `separator` border, no shadow). Unlike `CruxButton`, it does not hug
  its content's width — it is a block-level surface that fills its parent's
  width, the way a list row or form section would. Leave `onTap` unset for a
  purely decorative container with no press feedback at all, or pass a
  callback to make the whole card pressable (state layer + a subtler
  `CruxMotion.pressedScaleSubtle` scale). Clearing `onTap` back to `null`
  while a press is still in progress no longer crashes.
- Added `CruxListTile`, a list row with an optional 44x44 `leading`
  widget, a required `title`, an optional `subtitle`, and an optional
  trailing label. Fills its parent's width like `CruxCard`. Its only press
  feedback is a state layer — unlike `CruxButton` and `CruxCard`, it
  never scales down on tap, since a full-width row visibly shrinking reads
  as an unnatural wobble. Added an optional `padding` parameter, defaulting
  to `CruxSpacing.s16` horizontal / `CruxSpacing.s12` vertical
  (previously vertical-only), giving the tile an iOS-Settings-app-style
  built-in horizontal inset — the pressed-state highlight and content inset
  grow together since both come from the same padded box. Pass
  `EdgeInsets.zero` to restore the previous flush-to-edge look.
- Added `CruxSwitch`, a pill-shaped on/off toggle (52x32 track, 28-diameter
  thumb) whose thumb slides between positions with a spring animation routed
  through `CruxMotion` (a new `CruxMotion.animatedValue` builder, for
  atoms that spring a value other than a scale transform). It is a
  controlled widget, the same convention Flutter's own `Switch` uses: it
  always reflects `value` and calls `onChanged(!value)` on tap rather than
  mutating itself. `onChanged` is optional (omit it, or pass `null`, for a
  disabled switch). Dragging the thumb to slide it is not supported yet.
- Added `CruxDivider`, a 1 logical pixel tall `separator`-colored rule that
  fills the width of its bounded parent, with an optional `indent`.
- The example app's hand-built light/dark toggle and real-world sample
  section (card / chip row / list) are now composed from the atoms above
  instead of bespoke `Container`-based mocks. The example app was then
  slimmed down to just that header + real-world sample screen: the token
  tables (color palette, type scale, spacing scale) and the per-atom state
  showcase were removed from `example/` and moved into a new `widgetbook/`
  dev-catalog app, where every atom (plus `foundations`) now gets a
  Playground / States matrix / Edge cases set of use cases backed by
  light/dark golden tests.

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
