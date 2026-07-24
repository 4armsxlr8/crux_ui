# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`crux_ui` is a Flutter UI kit **package** (not an app), intended for publication on pub.dev. As of 0.2.0 it ships the design token layer — `CruxColors`, `CruxSpacing`, `CruxTypography`, `CruxThemeData`, and the `CruxTheme` InheritedWidget — plus `CruxButton`, its first widget atom (with the `CruxMotion` press-spring token it uses), and a showcase app in `example/`.

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

## Opening HTML

When opening an HTML file (reports, previews, etc.), open it in Orca's built-in browser instead of `open`: `orca goto --url "file:///abs/path" --json` (use `orca tab create --url ...` to keep existing tabs). Fall back to `open` only if the `orca` CLI is unavailable or Orca is not running.

## Architecture

- **Single public entry point**: `lib/crux_ui.dart` is the only file consumers import (`import 'package:crux_ui/crux_ui.dart';`). Every new component must be `export`ed from it; implementation files belong under `lib/src/` and are never imported directly by consumers.
- **Color names are permanent, values are provisional**: the semantic color names (`accent`, `textPrimary`, …) are the stable API; the current values are a borrowed palette ("Mimir") that will be swapped later. Raw color values may exist **only** in `lib/src/colors.dart` — never hardcode a color anywhere else, or the swap stops being a one-file diff. `test/contrast_test.dart` guards WCAG contrast across swaps.
- **The package never touches Material theming**: no `ThemeData` generation or modification (agreed decision; a Material adapter may come later as a separate opt-in layer). Components resolve tokens via `CruxTheme.of(context)`, which falls back to light when no theme is provided. Dark mode is `CruxThemeData.dark()`.
- Per the README, the first component (and each one after) lands together with its tests — tests are written before the implementation.
- When adding a component, also record it in `CHANGELOG.md`.
- Design decisions and their rationale are recorded per milestone under `unknowns/` — `unknowns/design-tokens-first/` for the token layer, `unknowns/button-atom/` for `CruxButton`/`CruxMotion` — each with a `ledger.md` for agreed facts and a `handoff.md` for that milestone's spec. Consult the relevant ledger before changing token names/values or existing component behavior.

## Analysis rules that will bite you

`analysis_options.yaml` goes beyond `flutter_lints`:

- `public_member_api_docs`: every exported declaration needs a `///` doc comment — the analyzer fails without it.
- `strict-casts`, `strict-inference`, `strict-raw-types` are all enabled.
- `prefer_final_locals` and `unawaited_futures` are enforced.
