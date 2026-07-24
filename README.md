# Crux UI

Crux UI likes people who like Crux UI.

## Status

**Under development.** The design token layer is implemented: colors,
spacing, and typography, plus a `CruxTheme` / `CruxThemeData` pair that
makes them available to a widget subtree. The first widget atom,
`CruxButton`, is also implemented (pill-shaped, three variants, three
sizes, spring press feedback). Other widgets (cards, chips, and so on) have
not been built yet — for now, the rest of a screen is composed from plain
Flutter widgets plus Crux's tokens, as shown in `example/`.

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

See `example/lib/main.dart` for a full showcase of the color palette, type
scale, spacing scale, button variants/sizes, and a light/dark toggle.

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

`CruxButton` is the first widget atom; the rest of the widget set has not
been decided yet. Each future component will land here along with its tests
and documentation, following the same tokens introduced in 0.1.0.

## License

[MIT](LICENSE)
