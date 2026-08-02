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
flutter test test/components/atoms/button_test.dart  # run a single test file
cd example && flutter build ios --simulator --debug  # build the showcase app
cd widgetbook && flutter run -d macos               # launch the dev catalog app
cd widgetbook && flutter test --update-goldens      # regenerate golden baselines after an intentional visual change
```

Requires Dart SDK `^3.12.2` (i.e. a Flutter SDK shipping a Dart in that range).

`flutter test` binds a local socket (127.0.0.1) for its test runner; in a sandboxed shell that bind is rejected with "Operation not permitted" — run it outside the sandbox.

## Opening HTML

When opening an HTML file (reports, previews, etc.), open it in Orca's built-in browser instead of `open`: `orca goto --url "file:///abs/path" --json` (use `orca tab create --url ...` to keep existing tabs). Fall back to `open` only if the `orca` CLI is unavailable or Orca is not running.

## Architecture

- **Single public entry point**: `lib/crux_ui.dart` is the only file consumers import (`import 'package:crux_ui/crux_ui.dart';`). Every new component must be `export`ed from it; implementation files belong under `lib/src/` (organized into `tokens/`, `components/atoms/`, `components/molecules/`, and `internal/` — see below) and are never imported directly by consumers.
- **Color names are permanent, values are provisional**: the semantic color names (`accent`, `textPrimary`, …) are the stable API; the current values are a borrowed palette ("Mimir") that will be swapped later. Raw token values may exist **only** in their defining file under `lib/src/tokens/` (for example, raw color values only in `lib/src/tokens/colors.dart`, raw shadow/scrim values only in `lib/src/tokens/shadows.dart`) — never hardcode a color or shadow recipe anywhere else, or the swap stops being a one-file diff. `test/tokens/contrast_test.dart` guards WCAG contrast across swaps.
- **The package never touches Material theming**: no `ThemeData` generation or modification (agreed decision; a Material adapter may come later as a separate opt-in layer). Components resolve tokens via `CruxTheme.of(context)`, which falls back to light when no theme is provided. Dark mode is `CruxThemeData.dark()`.
- Per the README, the first component (and each one after) lands together with its tests — tests are written before the implementation.
- When adding a component, also record it in `CHANGELOG.md`.
- Design decisions and their rationale are recorded per milestone under `unknowns/` — `unknowns/design-tokens-first/` for the token layer, `unknowns/button-atom/` for `CruxButton`/`CruxMotion` — each with a `ledger.md` for agreed facts and a `handoff.md` for that milestone's spec. Consult the relevant ledger before changing token names/values or existing component behavior.
- **Atom vs. molecule**: under `lib/src/components/`, a component that builds itself from tokens and `internal/` helpers alone is an atom (`atoms/`); one that imports another public Crux component to assemble itself (e.g. `CruxComposer` importing `CruxButton`) is a molecule (`molecules/`). A component built from a molecule would be an organism, in an `organisms/` directory created once the first one exists.
- **`internal/` is never exported**: files under `lib/src/internal/` (currently `PressFeedbackController` and `CruxTextFieldCore`) may be imported by other files under `lib/src/`, but must never be `export`ed from `lib/crux_ui.dart` — they are implementation detail shared between components, not part of the public API.
- **Components stop at organisms**: `lib/src/components/` holds atoms, molecules, and — once one exists — organisms. Full-screen templates or pages are never added to the package; assembling real screens is `example/`'s job.
- **Catalog operating rule**: `widgetbook/` (repo root, sibling to `example/`) is the dev catalog app — `widgetbook: ^3.25.0` is a dependency of that app only, never of the package itself. **Every new component must land with a widgetbook use-case set (Playground / States matrix / Edge cases, in `widgetbook/lib/usecases/<name>.dart`) plus a golden test pair (light + dark) in `widgetbook/test/golden_test.dart`**, following the contract in `widgetbook/lib/usecases/CONVENTIONS.md`. `example/` is a gallery of real screens: a home list that navigates to one sample screen per use case (task list, login form, and so on), sharing a header with the light/dark toggle. When a component's use case is not yet represented, add a screen for it. It still never grows a token table or a per-variant state grid — those belong in widgetbook.

## Analysis rules that will bite you

`analysis_options.yaml` goes beyond `flutter_lints`:

- `public_member_api_docs`: every exported declaration needs a `///` doc comment — the analyzer fails without it.
- `strict-casts`, `strict-inference`, `strict-raw-types` are all enabled.
- `prefer_final_locals` and `unawaited_futures` are enforced.
