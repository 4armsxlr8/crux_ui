# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`crux_ui` is a Flutter UI kit **package** (not an app), intended for publication on pub.dev. As of 0.1.0 it ships design tokens only — `CruxColors`, `CruxSpacing`, `CruxTypography`, `CruxThemeData`, and the `CruxTheme` InheritedWidget — plus a token-showcase app in `example/`. No widgets yet.

## Commands

```sh
flutter pub get                                    # install dependencies
flutter analyze                                    # static analysis (strict; see below)
dart format --output=none --set-exit-if-changed .  # check formatting (drop the flags to fix in place)
flutter test                                       # run all tests
flutter test test/<name>_test.dart                 # run a single test file
cd example && flutter build ios --simulator --debug  # build the showcase app
```

Requires Dart SDK `^3.12.2` (i.e. a Flutter SDK shipping a Dart in that range).

`flutter test` binds a local socket (127.0.0.1) for its test runner; in a sandboxed shell that bind is rejected with "Operation not permitted" — run it outside the sandbox.

## Architecture

- **Single public entry point**: `lib/crux_ui.dart` is the only file consumers import (`import 'package:crux_ui/crux_ui.dart';`). Every new component must be `export`ed from it; implementation files belong under `lib/src/` and are never imported directly by consumers.
- **Color names are permanent, values are provisional**: the semantic color names (`accent`, `textPrimary`, …) are the stable API; the current values are a borrowed palette ("Mimir") that will be swapped later. Raw color values may exist **only** in `lib/src/colors.dart` — never hardcode a color anywhere else, or the swap stops being a one-file diff. `test/contrast_test.dart` guards WCAG contrast across swaps.
- **The package never touches Material theming**: no `ThemeData` generation or modification (agreed decision; a Material adapter may come later as a separate opt-in layer). Components resolve tokens via `CruxTheme.of(context)`, which falls back to light when no theme is provided. Dark mode is `CruxThemeData.dark()`.
- Per the README, the first component (and each one after) lands together with its tests — tests are written before the implementation.
- When adding a component, also record it in `CHANGELOG.md`.
- Design decisions and their rationale are recorded in `unknowns/design-tokens-first/` (`ledger.md` for agreed facts, `handoff.md` for the current milestone's spec). Consult the ledger before changing token names or values.

## Analysis rules that will bite you

`analysis_options.yaml` goes beyond `flutter_lints`:

- `public_member_api_docs`: every exported declaration needs a `///` doc comment — the analyzer fails without it.
- `strict-casts`, `strict-inference`, `strict-raw-types` are all enabled.
- `prefer_final_locals` and `unawaited_futures` are enforced.
