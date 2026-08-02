# Changelog

## 0.8.0

- Added `CruxShadows`, the package's first elevation token set, wired
  into `CruxThemeData` as `shadows` (a non-breaking optional field that
  defaults to the light preset). Semantic names are permanent, values are
  provisional — the same contract `CruxColors` follows: `sm`/`md`/`lg`
  are two-layer soft shadow stacks whose ink is a translucent wash of the
  text-primary hue in light and black in dark; `scrim` is the modal
  backdrop tint; `hairline` is a 1px edge color for dark mode (fully
  transparent in light, so callers can always draw the border without
  branching on brightness); `ink` is the opaque shadow-ink base other
  components derive tinted lines and shades from; `thumb`/
  `thumbLifted` are the outline-hugging resting/dragging shadows for a
  small draggable control cap (introduced for `CruxSlider`); and `xs`
  is the smallest tier — a single faint, close layer for a surface that
  should read as only barely lifted, like a segmented control's
  selected plate. The "raw
  color values live only in colors.dart" rule is now generalized: raw
  token values live only in their defining file under `lib/src/tokens/`.
- Added `CruxColors.controlPlate`, the fill for a filled control's own
  selected/lifted inner plate (introduced for `CruxSegmentedControl`'s
  selection plate). `surface` cannot play that role in the dark palette:
  it measures only ~1.05:1 against `controlFill` there, so a
  surface-filled plate inside a filled control is nearly invisible.
  `controlPlate` is `surface`-white in light and a brighter warm gray in
  dark (~1.43:1 against `controlFill`, floors guarded in
  `test/tokens/contrast_test.dart`); the selected state's 3:1
  requirement is still carried by the label color change.
- Added `CruxDialog`, a two-layer confirmation dialog. The blank layer
  is `CruxDialogCard` (a statically renderable floating card: surface
  fill, superellipse corners, the `lg` shadow, no border in either theme)
  plus `CruxDialog.show`, which floats that card over a scrim with a
  springy entrance (scale 0.9 → a slight overshoot → 1.0) and a fade-out
  exit, closing on scrim tap (`barrierDismissible: false` opts out). It is
  built on a hand-rolled `OverlayEntry` — not Material's `showDialog` — so
  it works under a bare `WidgetsApp` and never reads `ThemeData`. The
  modal subtree scopes its own accessibility route, carries
  `SemanticsRole.dialog`, and blocks the background from the semantics
  tree (`scopesRoute` + `BlockSemantics`, the same structure Flutter's
  own dialog route uses); an optional `routeSemanticLabel` names the
  route for assistive technology, and the scrim's spoken dismiss label
  is caller-supplied via `barrierSemanticLabel`, hidden from semantics
  entirely when omitted. The calling context's `CruxTheme` is captured
  at `show` time and re-provided inside the overlay entry, so a locally
  scoped theme reaches the floating dialog (a theme change made while
  the dialog is already open is not picked up — documented trade-off,
  the same one Material's `showDialog` makes). While the exit fade
  plays, the whole dialog ignores pointers, so a rapid second tap can
  never re-fire an action.
- Added `CruxConfirmDialog`, the ready-made confirmation layer over
  `CruxDialog` and the package's second molecule: pass `title`,
  `message`, and cancel/confirm labels plus callbacks and the dialog is
  complete, with the action row laid out space-between (cancel on the far
  left, confirm on the far right) using `CruxButton`s. Its `show`
  convenience method closes the dialog after either action's callback.
- Added `CruxToast`, a notification toast system with no Material
  dependency (`ScaffoldMessenger`/`SnackBar` are not involved): wrap a
  screen in `CruxToastHost`, then call `showCruxToast` with a
  `message`, an optional caller-supplied `leading` icon, and at most one
  `CruxToastAction` (label + callback, for example an "undo"). Toasts
  stack from the bottom, at most three at a time (a fourth dismisses the
  oldest), and auto-dismiss after ~3 seconds — 6 seconds when an action is
  attached, so there is time to tap it. A duplicate `message` is never
  stacked twice: the existing toast shakes (the same decaying wobble
  `CruxMotion.shake` drives elsewhere, suppressed under reduce-motion),
  and if it was buried under newer toasts it moves back to the front and
  restarts its timer so the message can be re-read; a duplicate that is
  already frontmost only shakes, without extending its life. Toasts can
  also be swiped away horizontally (touching a toast pauses its dismiss
  timer, and releasing without dismissing re-grants the full grace
  period), and each card exposes the equivalent `dismiss` semantics
  action for assistive technology, which cannot swipe. While the
  platform's accessible-navigation mode (a screen reader) is active, an
  actioned toast is held open instead of timing out, following
  `SnackBar`'s precedent. Each toast is a live region for screen
  readers, inherits the `CruxTheme` of the context that showed it
  (captured at show time), and the card draws a hairline border that is
  visible in dark mode only (where the shadow alone cannot separate it
  from the background). The static card is exposed as `CruxToastCard`.
- Added `CruxSegmentedControl`, a single-selection, mutually exclusive
  segmented control (`CruxSegmentedControl<T>` over a list of
  `CruxSegment<T>` values with caller-supplied labels). Where
  `CruxChip` is a non-exclusive multi-select filter, this control owns
  exclusivity — both dartdocs spell out the split. Selection never slides:
  the selected plate (surface fill + small shadow) springs in place
  (fade + scale 0.8 → slight overshoot → 1.0) while the outgoing plate
  fades, the label layer never moves, and ~90ms after the plate lands a
  diagonal light band sweeps across it once — tilted 4°, peaking at 0.24
  opacity, blurred 8px, travelling for 300ms, flanked by faint shades in
  light mode so it reads on white. The sweep's direction and tilt mirror
  the direction of travel (moving to a righter segment sweeps left→right
  at +4°; moving back sweeps right→left at −4°), and it never plays on
  first build or when re-tapping the already-selected segment. Each
  segment exposes selected/mutually-exclusive semantics, and the whole
  effect collapses to an instant state change under reduce-motion.
- Added `CruxMotion.playOnce`, the generalized "play a one-shot effect
  each time a trigger counter increments" primitive `CruxMotion.shake`
  established, now exposing the raw 0→1 progress to its builder so future
  one-shot effects (like the segmented control's light sweep) don't
  re-derive the trigger arithmetic. Unlike `shake`'s formula — which is
  zero at both ends of a leg, hiding this — `playOnce` also corrects the
  first-build edge case where a freshly mounted widget would read as
  "already finished" rather than "at rest."
- Added `CruxSlider`, the package's first horizontally draggable
  control: `value`/`onChanged` plus `min`/`max`, optional
  `onChangeStart`/`onChangeEnd`, an optional `valueLabelBuilder`, and
  optional `divisions` for discrete values. The thumb is a flat
  fader-style cap (30×20, radius 6, surface-colored) with a center accent
  grip line and two flanking grip lines (shadow-ink-tinted in light, the
  dark hairline color in dark), sitting on a flat 6px track
  (`controlFill` with an accent progress fill). While dragging, the cap
  tracks the finger directly, scales up 1.1×, shows a value bubble above
  itself, and swaps its outline-hugging shadow from
  `CruxShadows.thumb` to the more lifted `thumbLifted`; released or
  programmatic changes settle through the shared spring. With
  `divisions`, values snap continuously *during* the drag (matching
  Flutter's own slider behavior) and small tick dots mark each division
  on the track. Tapping the track jumps straight to that position, and
  the whole control mirrors under right-to-left text direction. Exposes
  adjustable semantics with increase/decrease actions (one division per
  step, or 10% of the range when continuous), announcing the same text
  the value bubble shows — by default a percentage of the range (the
  same format Material's slider announces), overridable with
  `valueLabelBuilder`.

## 0.7.0

- Added `CruxSpinner`, Crux UI's branded loading indicator: three
  columns of dots that fall in an endless "rain," fading in at the top of
  each lap and out at the bottom, columns offset by a third of a lap so
  they never fall in lockstep. Comes in three sizes (`small`/`medium`/
  `large`, 16/24/36 logical pixels) and defaults to `CruxColors.accent`,
  overridable (for example to `onAccent` when painted on a filled accent
  surface). Its dartdoc is explicit that this is a branding choice, not a
  general-purpose loading affordance -- consuming apps should still reach
  for `CircularProgressIndicator.adaptive()` for a generic loading state
  that follows the host platform, and `CruxSpinner` is reserved for
  places where the loading state is itself part of Crux's own visual
  identity, including inside other Crux components (see `CruxButton`'s
  `loading` state below). Takes an optional `semanticsLabel`: `null` (the
  default) keeps the spinner purely decorative for hosts that already
  supply their own accessible name (like `CruxButton`'s `loading`
  state), while a non-null label announces that text once for callers
  using `CruxSpinner` as a stand-alone loading indicator.
- Added `CruxMotion.repeat`, a continuous, seamlessly-looping animation
  builder (`LoopMode.seamless` under the hood) that `CruxSpinner`'s fall
  is built on. Like every other `CruxMotion` entry point, the `motor`
  package types it wraps never appear in its public signature.
- Added `CruxIconButton`, a circular, spring-pressable icon-only atom for
  a single tappable glyph that needs no visible text (for example a
  composer's close button or a chat bar's attachment button). `icon`
  (a caller-supplied `Widget`) and `label` (the screen-reader
  announcement) are both required, the same value-class shape
  `CruxObscureToggle` already established for icon-plus-label controls.
  `tone` selects `neutral` (a `mutedFill`-filled circle, the default, for
  secondary actions) or `primary` (an `accent`-filled circle with an
  `onAccent` icon, for a screen's primary icon action); disabled renders a
  muted circle regardless of tone. Comes in two sizes via `size`
  (`CruxIconButtonSize`, defaulting to `medium`): `medium` is a 44
  logical pixel visible circle that is itself the 44 logical pixel tap
  target (no separate invisible padding around a smaller circle), and
  `large` is a 56 logical pixel circle, already above the minimum tap
  target on its own -- pair it with `tone: primary` for a floating action
  button (FAB). No shadow is drawn at either size; a shadow token is a
  separate, still-undecided topic. Pressing scales the circle down to
  `CruxMotion.pressedScale` with the same minimum press-feedback
  duration `CruxButton` guarantees.
- Added `CruxCheckbox`, a bare (label-less, non-tristate) checkbox atom:
  a controlled widget following `CruxSwitch`'s `checked`/`onChanged`
  convention, exposing Flutter's *checked* semantics trait rather than the
  *toggled* trait a switch uses. The checkmark springs in from a zero
  scale with a slight overshoot before settling, and the box itself pulses
  a few logical pixels larger at the same overshoot peak, both driven off
  the same shared spring rather than two independent animations. The
  unchecked outline uses `CruxColors.muted` rather than `accentLine` (the
  token this package otherwise reserves for a state-identifying, 3:1-
  contrast outline): `accentLine` measures only ~2.90:1 against
  `controlFill` in the light palette, below WCAG 1.4.11's 3:1 non-text
  floor, while `muted` clears 3:1 against both `background` and
  `controlFill` in both palettes (see `test/tokens/contrast_test.dart`).
  Checked-and-disabled fills with `muted` too, rather than collapsing into
  the same look as unchecked-and-disabled.
- Added an optional `loading` argument to `CruxButton` (`bool`, defaults
  to `false`, fully backward compatible with every existing call site).
  While `loading` is `true`, the label is replaced with a small
  `CruxSpinner` (colored to match whatever foreground color that variant
  already uses for its label -- `onAccent` for the filled variant,
  `textPrimary` for tonal/ghost), the button stops responding to taps, and
  its press-spring animation no longer triggers, while its background,
  border, and overall size stay exactly as they are when not loading. A
  screen reader keeps announcing the button's label throughout -- the label
  `Text` stays in the semantics tree via `alwaysIncludeSemantics: true`
  even though it is visually hidden behind the spinner -- while the
  button's semantics report `enabled: false`, so a submitting button is
  conveyed as a still-named control that cannot currently be activated,
  never as a nameless one.
- Reorganized `lib/src/` into `tokens/`, `components/atoms/`,
  `components/molecules/`, and `internal/` directories (mirrored under
  `test/`). This is an internal refactor only -- the set of symbols exported
  from `lib/crux_ui.dart` is unchanged, and nothing under `internal/` was
  ever exported.
- Reclassified `CruxComposer` as this package's first molecule: unlike the
  other components, it imports another public Crux component
  (`CruxButton`) to assemble itself rather than building from tokens
  alone, so it now lives in `lib/src/components/molecules/` instead of
  alongside the atoms.

## 0.6.0

- Added `CruxComposer`, a borderless, height-filling text area for
  composing a post -- Crux UI's third and last text-input atom, completing
  the split alongside `CruxTextFormField` and `CruxInputBar`. It is the
  first atom that draws no box of its own at all: no fill, no border, no
  corner radius, no focus-triggered appearance change -- it is meant to sit
  directly on whatever surface the caller already has (typically
  `CruxColors.background`), so none of this package's usual
  `controlFill`-plus-superellipse-corner conventions apply to it.
- Everything below the text itself is optional. `CruxComposer` can be
  given zero, one, two, or all three of `actions` (a list of caller-defined
  buttons, e.g. an attachment or camera button), `submit` (a post button),
  and `maxLength` (which turns on a character counter). Passing none of the
  three renders a bare text area with no action row at all -- the row does
  not exist and is not merely empty in that case -- and the row appears the
  moment any one of them is supplied. The three earlier candidate designs
  (a plain text area only, a text area with a built-in counter, or a full
  fixed action row) were rejected in favor of this all-optional shape so
  that the same widget can serve both the simplest case and the full
  post-composer case without a caller ever paying for parts they did not
  ask for.
- Going over `maxLength` is accepted, never truncated -- the X ("Twitter")
  style of over-limit behavior rather than stopping input at the limit.
  Typing or pasting past the limit keeps every character: the counter turns
  from `CruxColors.textSecondary` to `CruxColors.error` (only these two
  states -- there is no intermediate "running low" warning color, since the
  palette has no dedicated warning token and adding one would also touch
  `theme.dart`'s hand-written `==`/`hashCode`), the text beyond the limit
  renders in `CruxColors.error` too, and only the submit button disables.
  Stopping input at the limit, or letting the caller choose the behavior,
  were both considered and rejected: the agreed spec is that a post
  composer should let someone finish their thought and see exactly how much
  they are over, the same experience X's own composer gives.
- The character count is measured in grapheme clusters via Flutter's
  `characters` package (re-exported through `widgets.dart`, so no new
  dependency was needed) rather than raw UTF-16 code units: an emoji or
  other combined character counts as one, matching how a person actually
  perceives "one character" rather than how many code units it happens to
  take up in memory.
- The `controller` argument takes a `CruxComposerController?`, a new
  public `TextEditingController` subclass, rather than a plain
  `TextEditingController`. This is a hard technical requirement, not a
  style choice: the over-limit highlight is painted by overriding
  `buildTextSpan`, a method the Flutter SDK's `EditableTextState` calls
  virtually on whatever controller it is handed -- a plain
  `TextEditingController` has no way to inject that override from outside.
  Leaving `controller` unset (the default) creates and owns a
  `CruxComposerController` internally. Used on its own, disconnected from
  a `CruxComposer`, the class behaves exactly like an ordinary
  `TextEditingController` (including the default composing-underline
  rendering during IME conversion), so it stays safe to reuse elsewhere.
- The submit button is enabled only when the field is enabled, the text is
  non-empty, the text is not over `maxLength`, and `onSubmit` is actually
  supplied (a `submit` bundle with no `onSubmit` stays disabled rather than
  looking tappable and silently doing nothing); tapping it calls `onSubmit`
  with the controller's current text and never clears the text itself on
  its own. It reuses `CruxButton` (filled, small) internally rather than
  a bespoke button, the same "disabled just means `onPressed: null`"
  convention every other Crux control already follows.
- `CruxComposer` fills exactly the height it is given and scrolls its own
  text internally once the content outgrows that height, instead of
  growing line-by-line the way `CruxInputBar` does -- place it inside an
  `Expanded` (or any other box handing it a bounded height). Keyboard
  avoidance is deliberately left to the surrounding screen (for example
  `Scaffold.resizeToAvoidBottomInset`, the same pattern the example app's
  chat screen already used), not handled inside the widget itself, so it
  drops into any screen layout without assuming how that screen manages the
  keyboard.
- The shared text-input core, `CruxTextFieldCore`, gained a new `expands`
  parameter to support this. Passing it straight through to
  `CupertinoTextField.expands` alongside the `minLines: 1` this core always
  used to send unconditionally would crash immediately: the Flutter SDK
  asserts `!expands || (maxLines == null && minLines == null)`, so `build`
  now branches on `expands` -- `true` sends `minLines: null, maxLines: null`
  to the SDK, `false` keeps the exact `minLines: 1, maxLines: maxLines`
  behavior this core always had, leaving `CruxTextFormField` and
  `CruxInputBar` byte-for-byte unaffected. The core's own constructor
  assert was also strengthened from `!obscureText || maxLines == 1` to
  `!obscureText || (!expands && maxLines == 1)`, closing a gap where an
  obscured field paired with `expands: true` could still pass this class's
  own check only to fail later, deeper inside the SDK.
- Added `CruxComposerAction` (an icon, a screen-reader label, and its own
  `onPressed`, all three caller-supplied) and `CruxComposerSubmit` (a
  caller-supplied label for the post button) as the two new value types
  describing the action row's optional slots, and a "新規投稿" screen in
  `example/`, reachable from the home list, showing `CruxComposer` wired
  up with actions, a counter, and a submit button.
- A hairline top border, drawn in `CruxColors.separator`, now separates the
  text area from the action row. It is painted as decoration on the action
  row's own container (adding zero layout height) rather than as a
  standalone divider widget, and appears if and only if the action row
  itself renders, so a bare `CruxComposer` (no `actions`, no `submit`, no
  `maxLength`) still stays completely bare.

## 0.5.0

- Added `CruxInputBar`, a compact, pill-shaped input bar for search boxes
  and chat composers — Crux UI's second text-input atom, sharing the same
  underlying `CupertinoTextField` core `CruxTextFormField` uses, but a
  plain `StatefulWidget` rather than a `Form`-integrated `FormField`: no
  label, no helper/error caption row, no validation concept at all. Three
  new caller-supplied value types describe its optional slots —
  `CruxInputBarLeading` (a decorative, non-tappable icon, e.g. a
  magnifying glass), `CruxInputBarClear` (a clear button shown only while
  the field has text), and `CruxInputBarSubmit` (a submit button, icon
  over an accent-filled circle) — kept as three separate types rather than
  reusing `CruxObscureToggle` or folding all three into one shared shape:
  `CruxObscureToggle` was designed for exactly one job, a two-state
  obscured/revealed toggle, and a leading decoration, a clear button, and a
  submit button behave differently enough from that and from each other
  (tappable or not, when each one appears at all, whether it has an
  enabled/disabled color) that squeezing all of them into one type would
  hide which fields matter in which slot.
- `maxLines` defaults to `1`: the bar never grows and stays a pill (corner
  radius always exactly half its own height) no matter how much text is
  entered. Setting `maxLines` to `2` or higher lets the bar grow, one line
  at a time up to that cap, and smoothly morph from the one-line pill into
  a two-row shape once the text needs more than one line — text on top
  (using the box's full width), a compact action row underneath (leading on
  the start edge, clear/submit on the end edge) — settling at a fixed 16px
  corner radius instead of continuing to track the box's growing height.
  The morph is driven by a single animated progress value, not by
  interpolating between a pill-radius and a 16px `RoundedSuperellipseBorder`
  directly: a pill's radius is effectively unbounded (half the box's own
  height, which keeps growing), and Flutter clamps a corner radius to fit
  its rect at paint time regardless of the requested value, so a linear
  blend from that unbounded radius down to 16 stays clamped back to the
  full pill shape for almost the entire animation and only visibly changes
  in the last instant. Instead, a new private `ShapeBorder` computes its
  effective radius fresh at paint time from the box's actual height and the
  current progress, so every intermediate frame has a genuinely different,
  uncapped radius and the shape changes continuously throughout.
- The return key's meaning switches automatically by platform once
  `maxLines` is `2` or higher (not overridable by a caller): on macOS,
  Windows, Linux, and Fuchsia, the return key submits (Shift+Return enters a
  literal newline); on iOS and Android, the return key always inserts a
  newline, and submitting only ever happens through the on-screen submit
  button. A single-line bar's return key always submits, matching an
  ordinary search field, with no platform-dependent behavior. The judgment
  is Flutter's own `defaultTargetPlatform`, not a live check for an attached
  physical keyboard — Flutter has no reliable way to tell the two apart, and
  neither Android nor Flutter Web can reliably tell a soft keyboard's input
  apart from a hardware one either (flutter/flutter#148375, #80505, #58171)
  — so a phone's mobile browser opening a desktop-shaped web build, or a
  phone with a physical keyboard attached, are known, accepted edge cases
  where this approximation gets the return key's behavior backwards.
- The submit button's visible circle is 32 logical pixels across inside a
  44x44 logical pixel tap target (the difference is transparent padding,
  not a smaller hit area). It renders disabled while the field's text is
  empty, and switches to enabled (`CruxColors.accent` fill,
  `CruxColors.onAccent` icon) the moment any text is entered; both colors
  animate smoothly between the two states rather than snapping. Added
  `CruxMotion.animatedColor`, a new motion primitive for this:
  interpolates a `Color` toward a target using the same shared spring
  `CruxMotion.scale`/`animatedValue` already use, via `motor`'s
  `ColorRgbMotionConverter` (alpha included, so a translucent target fades
  in step with its hue). This closes a gap left open since the
  `CruxTextFormField` milestone: `CruxMotion` had no way at all to
  animate a color (tracked there as the unresolved TF-U03), so an
  accent-on-empty-vs-filled treatment like this one could previously only
  snap between its two colors.
- Added `CruxColors.mutedFill` (a translucent wash of `textPrimary`'s
  hue: 8% in light, 12% in dark), the fill for an inactive affordance that
  sits on top of another filled surface — and used it for the disabled
  submit circle above. The first cut reused `CruxColors.separator` there,
  matching `CruxButton`'s disabled treatment, but that convention assumes
  the control sits on the page background: inside the bar's own
  `controlFill`-filled box, `separator` is nearly the same color (~1.03:1)
  and the disabled circle vanished entirely, leaving a lone floating arrow
  — caught reviewing the running app, not by any test, because the
  contrast guard measured the icon (which was fine) and nothing measured
  the circle. Being translucent, the token reads correctly over
  `controlFill`, `background`, or `surface` alike, and it was added with a
  constructor default (the `onAccent` precedent) so existing manual
  `CruxColors(...)` call sites keep compiling. `test/contrast_test.dart`
  now guards the actual painted stack: the circle must not vanish into the
  box (≥1.1:1; shipped ~1.16 light / ~1.43 dark) and the icon must stay
  legible on the circle (≥2.5:1; shipped ~2.90 light / ~3.20 dark —
  disabled controls are exempt from WCAG's own minima, so both floors are
  drift guards for the approved look, not accessibility claims).
  `CruxButton`'s own disabled state still uses separator-on-background
  (visible enough thanks to its text label); aligning it to `mutedFill` is
  a deliberate open item, not an oversight.
- Like `CruxTextFormField`, `CruxInputBar` never lets the ambient
  Material theme of a consuming app leak into its own look (sealed cursor/
  selection colors, no stray disabled-state fill, keyboard brightness
  follows the Crux theme rather than the OS).

## 0.4.0

- Added `CruxTextFormField`, a single-line, `Form`-integrated text input
  field: it is a real `FormField<String>`, so wrapping several of them (and
  other `FormField`s) in a Flutter `Form` gets batched `FormState.validate`
  and `FormState.save`, and `validator`/`onSaved` work as usual.
- Built on `CupertinoTextField` rather than Material's `TextField`: Material's
  `TextField` asserts a `Material` ancestor and resolves roughly a dozen of
  its defaults (fill color, border, error color, text style, and so on) from
  the ambient `ThemeData`, which would let a consuming app's Material theme
  leak into Crux's look. `CupertinoTextField` imports no Material code and
  takes every visual property explicitly, so its decoration can be fully
  replaced with Crux tokens instead.
- `label` and `placeholder` are two separate arguments: `label` (the field's
  name, e.g. `メールアドレス`) always renders in a static row above the box,
  whether the value is empty or not — it never moves. `placeholder` (a hint
  at the expected format, e.g. `you@example.com`) renders inside the box
  itself and disappears once the value is non-empty, passed straight through
  to `CupertinoTextField.placeholder`/`placeholderStyle`. The label row is
  reserved only when `label` is non-`null`; the helper/error caption row
  below the box is always reserved regardless, so a validation error
  appearing or clearing never shifts anything else in the layout. Both the
  label and the placeholder render in `CruxColors.textSecondary` (measured
  against `controlFill`: ~5.79:1 light, ~5.88:1 dark, both comfortably above
  the 4.5:1 AA floor for normal text).
- 2026-07-26: `label` and `placeholder` were originally one argument — the
  label doubled as the placeholder, resting inside the box while the value
  was empty and animating up into the reserved row above the box once a
  value existed (an early version of this changelog entry described that
  design). The label's movement was a 200ms spring driven by
  `CruxMotion.animatedValue`. Revised because the field's name and its
  hint text were always meant to be two separate things; the label-as-
  placeholder scheme and the animation it required are gone entirely.
- The box's border is `CruxColors.separator` at rest and turns
  `CruxColors.error` — matching the caption row below it — while a
  validation error is showing, reverting the moment the error clears.
  Focus deliberately changes nothing about the field's appearance on top of
  that: same border color, same width, no highlight ring, not even while
  typing, whether or not an error is currently showing — since the agreed
  spec calls for a field whose only appearance change is driven by the
  error state, never by keyboard focus.
- Added `CruxColors.controlFill` (light `#E9E8E2`, dark `#262319`) — the
  fill painted behind an interactive control such as a text input — and
  used it to fill `CruxTextFormField`'s box, which previously had no fill
  at all (only its 1px border and the page's own background made it
  visible). The name is deliberately generic rather than field-specific:
  the planned `CruxInputBar` and `CruxComposer` are expected to reuse
  it. Chosen over reusing `separator` (would make the fill and the 1px
  border the same color, erasing the border) or `surface` (would make a
  filled field indistinguishable from a card in dark mode, where `surface`
  and `background` sit close together). `test/contrast_test.dart` verifies
  `textPrimary`/`textSecondary` against it: light ~12.52:1 / ~5.79:1, dark
  ~14.38:1 / ~5.88:1 (the dark `textSecondary` figure composites it over
  `controlFill` first, since `textSecondary` is translucent in the dark
  palette) — both comfortably above the 4.5:1 floor for normal text.
- Text selection handles and the copy/paste menu use the iOS ("Cupertino")
  style on every platform, `CupertinoTextField`'s own default behavior. The
  text cursor and selection highlight are repainted in `CruxColors.accent`
  instead of iOS's default blue — or, inside a consuming app's Material
  `MaterialApp`/`Theme`, that app's own primary color — via an internal
  `DefaultSelectionStyle` wrapper scoped to the field's own subtree, since
  `CupertinoTextField` consults an ambient `DefaultSelectionStyle` before its
  own `CupertinoTheme` fallback. A second, narrower `CupertinoTheme` wrapper
  colors the selection drag handles and the text-magnifier ring, the two
  lookups `DefaultSelectionStyle` doesn't cover. Neither wrapper touches any
  ambient `CupertinoTheme`, `DefaultSelectionStyle`, or Material theming
  outside this widget.
- Fixed three further cases of the same ambient-leak class found in the same
  audit: a disabled field no longer paints a stray gray background fill of
  its own underneath the box (the inner `CupertinoTextField`'s own
  decoration stays empty even while disabled, so the outer box's own
  `controlFill` is the only fill ever visible), the selection drag handles
  use `CruxColors.accent` instead of iOS's default system blue, and the
  on-screen keyboard's light/dark appearance now follows
  `CruxThemeData.brightness` instead of the device's platform brightness.
- Unlike every other Crux component, a `CruxTextFormField`'s text does
  not ellipsize when it overflows — it scrolls horizontally to follow the
  cursor, the ordinary behavior of a single-line text field, since
  ellipsizing text while it is actively being edited would hide what the
  user just typed.
- Disabled is expressed with a plain `enabled: false` rather than the
  package's usual "pass `null` to a callback" convention: a text field is
  commonly used with only a `controller` and no `onChanged` callback at all,
  so a nullable-callback convention would have no way to tell "enabled, with
  no callback" apart from "disabled."
- Every rounded corner Crux UI draws — `CruxButton`, `CruxChip`,
  `CruxCard`, `CruxSwitch`'s track and thumb, and
  `CruxTextFormField`'s box — is now a superellipse ("squircle", the same
  continuous-curvature corner iOS uses) instead of a plain circular-arc
  rounded rectangle, via Flutter's `RoundedSuperellipseBorder` in place of
  `RoundedRectangleBorder`/`BoxDecoration.borderRadius`. Wherever a
  component paints both a fill and a border, both now come from the same
  `ShapeDecoration(shape: RoundedSuperellipseBorder(...))` so the two can
  never visually disagree — the shape-only `ClipRSuperellipse` widget would
  have clipped a child to the new curve while leaving a separately-drawn
  border on the old circular one. `CruxRadii`'s values (`m` = 14, `l` =
  16, `pill` = 9999) are unchanged; only the curve a given radius draws
  changed. The effect is visible at `CruxCard`'s 16px and
  `CruxTextFormField`'s 14px radii (confirmed against regenerated
  `widgetbook` goldens: only the corner pixels of each shifted). At the
  `pill` radius (`CruxButton`/`CruxChip`/`CruxSwitch`), the change is
  nil to negligible: once a corner's radius reaches half its shortest side,
  no straight edge segment remains for a superellipse to flatten against,
  so it degenerates to the exact same semicircle a circular rounded rect
  already drew (goldens confirm this — fill-only rows produced zero pixel
  diff, and bordered rows produced only a sub-2% diff from stroke
  anti-aliasing, imperceptible at actual size). `CruxListTile` and
  `CruxDivider` draw no rounded corners of their own and are unaffected.
- Fixed a crash in `CruxListTile`, present since it shipped in 0.3.0: a
  tile squeezed narrower than its fixed content (`leading`'s frame plus its
  gaps) would throw "was given an infinite size during layout" if the
  surrounding height constraint was also unbounded — the case a `Column`,
  `ListView`, or `SingleChildScrollView` hands a plain (non-`Expanded`)
  child along its main/scroll axis. The narrow-width fallback's internal
  `OverflowBox` now sizes itself to its child's actual measured size
  (`OverflowBoxFit.deferToChild`) instead of defaulting to the full ambient
  size, which also fixes a quieter sibling bug: with a bounded but tall
  ambient height, the same narrow tile used to silently stretch to fill it
  instead of hugging its normal, short content height.
- 2026-07-26: `CruxTextFormField` now shakes — a brief horizontal wobble,
  the familiar "wrong password" reaction — whenever a validation error
  appears. Only the box shakes; the label above it and the caption/error
  row below it stay perfectly still (revised the same day from an initial
  version where the whole field moved as one piece — see
  `unknowns/textfield-atom/implementation-notes.md`'s dated reversal entry
  for why). It shakes again on a repeated failed submit even when the error
  message is identical (the common real case: the user presses the button
  again) — `errorText` alone does not change between the two calls, so this
  field's `FormFieldState.validate` override is what actually notices the
  second failure. An error already showing the very first time the field is
  ever built (for example an `AutovalidateMode.always` field whose initial
  value is already invalid) does not shake on mount: only a transition
  *during* the field's lifetime counts as "an error appearing". The shake
  is a paint-time transform only — it never changes the field's own size or
  moves anything around it — and is fully suppressed, not merely
  shortened, when the OS "reduce motion" accessibility setting
  (`MediaQuery.disableAnimationsOf`) is on.
- 2026-07-26: `CruxTextFormField`'s validation-error caption now renders at
  `FontWeight.w600` instead of the caption style's normal `w400`, so an error
  message reads as bolder and more noticeable than plain helper text (user
  request: 「エラー文言を太くして目立たせたい」). Plain helper text (no
  error showing) is unaffected and stays at `w400`. The size stays at the
  caption style's own 12px rather than switching to the `label` token's 14px
  — a size change would grow the reserved caption row and break the
  guarantee that showing an error never shifts anything else in the layout.
  Implemented as a component-level `copyWith(fontWeight:)` rather than a new
  `CruxTypography` token, since `caption` itself is meant to stay a fixed
  12px/w400 pair usable elsewhere (timestamps, metadata) without an emphasis
  rule that only makes sense for an error.
- Added `CruxMotion.shake`, a new motion primitive: a decaying horizontal
  oscillation that plays once each time its `trigger` count changes, for
  one-shot effects that must be replayable from a standing start (unlike
  `CruxMotion.scale`/`animatedValue`, which spring a value toward a
  persisted target and stay there). Driven internally by `motor`'s
  duration-based `Motion.curved` rather than a spring: a spring only
  settles asymptotically near its target, never bit-exactly at it, which
  cannot guarantee the shake returns to *exactly* zero displacement once it
  finishes. Also added `CruxMotion.shakeDuration` (400ms) and
  `CruxMotion.shakeAmplitude` (8 logical pixels) as the new tunable
  constants — both are starting values only, not yet checked against a
  running app on a device, and should be revisited there.
- 2026-07-26: Added `CruxTextFormField.obscureToggle` (type
  `CruxObscureToggle?`), a password show/hide button rendered at the
  box's trailing edge (mirrored under RTL). This package never draws its
  own eye/eye-slash glyph for it: different products ship different icon
  sets, so `CruxObscureToggle` bundles the icons (`obscuredIcon`/
  `revealedIcon`, plain `Widget`s — an `Icon`, an `Image`, even a `Text`
  glyph all work) and the screen-reader labels (`obscuredLabel`/
  `revealedLabel`, `required` `String`s) a caller supplies for both states.
  Both labels are `required` rather than nullable: an icon-only button has
  no descendant text to fall back to, so a nullable label would force this
  package to choose between announcing nothing (an accessibility failure)
  or inventing English wording (exactly what this feature exists to avoid).
  Leaving `obscureToggle` unset (the default) renders no toggle at all —
  `obscureText` is then this field's fixed, unchanging obscured state, the
  same as before this feature existed. Passing `obscureToggle` together
  with `obscureText: false` is not treated as a contradiction that
  suppresses the toggle: `obscureText` becomes the field's *starting*
  obscured state, and the toggle still renders and works from there — the
  least surprising reading once a caller has gone to the trouble of
  supplying a whole `CruxObscureToggle`. Tapping the toggle never steals
  focus from the field or dismisses the keyboard (wrapped in a
  `TextFieldTapRegion`, the same mechanism `CupertinoTextField`'s own
  selection toolbar uses to be treated as "inside" the field), reserves a
  fixed 44x44 logical pixel slot in the field's own content padding so
  entered text is never drawn underneath it, and never moves the box, the
  label row, or the helper/error caption row regardless of which state is
  showing. `enabled: false` dims and disables the toggle along with the
  rest of the field.

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
