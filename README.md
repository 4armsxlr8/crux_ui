# Crux UI

Crux UI likes people who like Crux UI.

## Status

**Under development.** This repository currently contains scaffolding only.
No widgets, themes, or other components have been implemented yet, so there is
nothing useful to install at the moment.

`lib/crux_ui.dart` is the single public entry point. It is deliberately empty
today; every component added later will be exported from that one file, so
apps will only ever need a single import:

```dart
import 'package:crux_ui/crux_ui.dart';
```

## Getting started

This package requires the Dart SDK `^3.12.2` and a Flutter SDK that ships a
Dart version in that range.

```sh
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
```

There are no tests yet, because there is no behavior to test. Tests will be
added together with the first component, written before the implementation.

## Roadmap

The component set has not been decided yet. Once the first widget's appearance
and behavior are specified, it will land here along with its tests and
documentation.

## License

[MIT](LICENSE)
