# Crux UI

Crux UI likes people who like Crux UI.

## Status

**Under development.** The design token layer is implemented: colors,
spacing, typography, radii, and shadows (elevation shadows, a modal scrim,
and a dark-mode hairline), plus a `CruxTheme` / `CruxThemeData` pair
that makes them available to a widget subtree. Seventeen widget atoms are
also implemented: `CruxButton` (including a `loading` state), `CruxChip`,
`CruxCard`, `CruxListTile`, `CruxSwitch`, `CruxDivider`,
`CruxTextFormField`, `CruxInputBar`, `CruxSpinner`, `CruxIconButton`,
`CruxCheckbox`, `CruxDialog`, `CruxToast`, `CruxSegmentedControl`,
`CruxSlider`, `CruxNavBar` (a floating bottom navigation bar, with its
`CruxNavItem` destination type, and its own backdrop-fade band that melts
scrolling content behind it into the page near the screen's bottom edge),
and `CruxTopFade` (a progressive fade/blur band for the top edge of
scrolling content), plus two molecules
built from them, `CruxComposer` and `CruxConfirmDialog` (the ready-made
confirmation layer over `CruxDialog`) — eighteen components in total,
counting the two dialog layers as one. Other widgets (bottom sheets and so
on) have not been built yet — for now, the rest of a screen is composed
from plain Flutter widgets plus Crux's tokens, as shown in `example/`.

Crux never rewrites Material's `ThemeData`; providing a `CruxTheme` does
not change the look of `Material`, `Scaffold`, or other Material widgets.

`lib/crux_ui.dart` is the single public entry point. Every component this
package ships is exported from that one file, so apps only ever need a
single import:

```dart
import 'package:crux_ui/crux_ui.dart';
```

### Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  runApp(
    CruxTheme(
      data: CruxThemeData.light(),
      child: Builder(
        builder: (context) {
          final theme = CruxTheme.of(context);
          return Container(
            color: theme.colors.background,
            padding: const EdgeInsets.all(CruxSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, Crux', style: theme.typography.headline),
                const SizedBox(height: CruxSpacing.s16),
                CruxButton(label: 'はじめる', onPressed: () {}),
              ],
            ),
          );
        },
      ),
    ),
  );
}
```

`CruxButton` is a pill-shaped button with three variants
(`CruxButtonVariant.filled` / `tonal` / `ghost`) and three sizes
(`CruxButtonSize.small` / `medium` / `large`). Pass `onPressed: null` to
disable it. Its label is a plain `String`, always rendered on a single line
with an ellipsis, so it can never overflow no matter how narrow its
constraints or how long the label is.

`CruxChip` is a pill-shaped filter/tag chip with a `selected` flag. Like
`CruxButton`, it hugs its label's width, truncates with an ellipsis, and
keeps a 44 logical pixel tap target even though its visible pill is 36 tall.
Pass `onTap: null` to disable it.

`CruxCard` is a bordered content container. Unlike `CruxButton`, it does
**not** hug its content's width — it fills its parent's bounded width like a
block element. Leave `onTap` unset for a purely decorative container with no
press feedback, or pass a callback to make the whole card pressable.

`CruxListTile` is a list row with an optional `leading` widget, a required
`title`, and optional `subtitle`/`trailing` text. It fills its parent's
width like `CruxCard`, and its only press feedback is a state layer (no
press-scale, unlike `CruxButton`/`CruxCard` — a full-width row shrinking
on tap reads as an unnatural wobble).

`CruxSwitch` is a pill-shaped on/off toggle. It is a controlled widget,
the same convention Flutter's own `Switch` uses: it always reflects `value`
and calls `onChanged(!value)` on tap rather than mutating itself. Pass
`onChanged: null` to disable it.

`CruxDivider` is a 1 logical pixel tall `separator`-colored rule that
fills the width of its bounded parent, with an optional `indent`.

`CruxTextFormField` is a single-line, `Form`-integrated text input field —
a real `FormField<String>`, so `validator`/`onSaved` and a wrapping `Form`'s
batched validate/save all work. It is built on `CupertinoTextField` rather
than Material's `TextField`, so a host app's Material theme can never leak
into its look. `label` (the field's name) and `placeholder` (a hint at the
expected format) are separate arguments: `label` always renders in a static
row above the box, whether or not the field has a value, and `placeholder`
renders inside the box itself, disappearing once a value is entered. Its
helper/error caption row below the box is always reserved, so nothing shifts
as a validation error appears or clears. Pass `enabled: false` to disable
it, rather than the package's usual null-callback convention — a text field
is commonly used with only a `controller` and no `onChanged` at all. Pass
`obscureToggle` (an `CruxObscureToggle`) to add a password show/hide
button at the box's trailing edge; this package never draws its own
eye/eye-slash glyph, so `CruxObscureToggle` bundles the icons and the
screen-reader labels for both states, both supplied by the caller. Leaving
`obscureToggle` unset renders no toggle at all.

Its selection/copy-paste menu's wording ("Paste", "Copy", ...) has two
sources, and a non-English app needs to cover both. On iOS 16+, the menu is
drawn by iOS itself, not Flutter, so its wording follows the **app
bundle's** declared languages — the `CFBundleLocalizations` array in
`Info.plist` — see `example/ios/Runner/Info.plist` for a working setup.
Everywhere else (older iOS, Android, desktop), Flutter draws the menu
itself and reads its wording from whichever `CupertinoLocalizations` the
host app supplies, falling back to English if unconfigured. Add the
`flutter_localizations` package and its
`GlobalCupertinoLocalizations.delegate` (with the Material/Widgets
equivalents and a matching `supportedLocales`) to your `MaterialApp` to fix
that path — see `example/lib/main.dart` for a working setup. `crux_ui`
itself never depends on `flutter_localizations`, so this is setup a
consuming app adds itself rather than something this package could do for
you.

See `example/` for a gallery of real-world sample screens, one per use
case (a task list, a login form, and so on), reached from a home index and
sharing one header with a light/dark toggle — see `example/lib/main.dart`
for the app shell and `example/lib/screens/` for each sample screen. For
the color palette, type scale, spacing scale, and radii tokens, and for
every atom's full Playground/States matrix/Edge cases catalog, run the dev
catalog app in `widgetbook/` (`cd widgetbook && flutter run -d macos`).

## Getting started

This package requires the Dart SDK `^3.12.2` and a Flutter SDK that ships a
Dart version in that range.

```sh
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

## Roadmap

`CruxButton`, `CruxChip`, `CruxCard`, `CruxListTile`, `CruxSwitch`,
`CruxDivider`, and `CruxTextFormField` are the widget atoms shipped so
far; the rest of the widget set (snackbars and so on) has not been decided
yet. The remaining text-input use cases are deliberately planned as
separate widgets rather than options on `CruxTextFormField`, since their
looks differ too much to share one API: `CruxInputBar` (search and chat,
which share one look) and `CruxComposer` (a post body — no surrounding
box, fills the screen, multi-line by default). Neither is built yet. Each
future component will land here along with its tests and documentation,
following the same tokens introduced in 0.1.0.

## License

[MIT](LICENSE)
