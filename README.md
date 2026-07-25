# Crux UI

Crux UI likes people who like Crux UI.

## Status

**Under development.** The design token layer is implemented: colors,
spacing, typography, and radii, plus a `CruxTheme` / `CruxThemeData` pair
that makes them available to a widget subtree. Six widget atoms are also
implemented: `CruxButton`, `CruxChip`, `CruxCard`, `CruxListTile`,
`CruxSwitch`, and `CruxDivider`. Other widgets (text fields, snackbars,
and so on) have not been built yet — for now, the rest of a screen is
composed from plain Flutter widgets plus Crux's tokens, as shown in
`example/`.

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

See `example/lib/main.dart` for a real-world sample screen using every
widget atom together, plus a light/dark toggle. For the color palette, type
scale, spacing scale, and radii tokens, and for every atom's full
Playground/States matrix/Edge cases catalog, run the dev catalog app in
`widgetbook/` (`cd widgetbook && flutter run -d macos`).

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
and `CruxDivider` are the widget atoms shipped so far; the rest of the
widget set (text fields, snackbars, and so on) has not been decided yet.
Each future component will land here along with its tests and
documentation, following the same tokens introduced in 0.1.0.

## License

[MIT](LICENSE)
