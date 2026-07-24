# Crux UI

Crux UI likes people who like Crux UI.

## Status

**Under development.** The design token layer is implemented: colors,
spacing, and typography, plus a `CruxTheme` / `CruxThemeData` pair that
makes them available to a widget subtree. Higher-level widgets (buttons,
cards, chips, and so on) have not been built yet — for now, screens are
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
            child: Text('Hello, Crux', style: theme.typography.headline),
          );
        },
      ),
    ),
  );
}
```

See `example/lib/main.dart` for a full showcase of the color palette, type
scale, spacing scale, and a light/dark toggle.

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

The widget set has not been decided yet. Once the first widget's appearance
and behavior are specified, it will land here along with its tests and
documentation, following the same tokens introduced in this release.

## License

[MIT](LICENSE)
