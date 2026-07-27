# usecases/ conventions

This directory holds one file per cataloged component. It is worked on by
several agents in parallel, so the rules below exist to keep files
independent and mergeable without conflicts.

## File ownership

- Each agent owns exactly one file: `usecases/<name>.dart`.
- Names in scope for this milestone: `foundations`, `button`, `chip`, `card`
  (includes `CruxDivider`), `list_tile`, `switch`, `text_form_field`,
  `input_bar`, `composer`.
- Do not edit any other file in `widgetbook/` (including `main.dart` and
  other agents' `usecases/*.dart` files). The integration owner collects
  every `<name>Component` into `main.dart`'s `_directories` list after all
  files land — that step is out of scope for the per-component work.
- Do not add dependencies to `widgetbook/pubspec.yaml`.

## Required shape of `usecases/<name>.dart`

Each file must expose exactly one top-level getter:

```dart
WidgetbookComponent get <name>Component => WidgetbookComponent(
  name: '<Name>',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: (context) => ...),
    WidgetbookUseCase(name: 'States matrix', builder: (context) => ...),
    WidgetbookUseCase(name: 'Edge cases', builder: (context) => ...),
  ],
);
```

`<name>` is the file's basename (e.g. `buttonComponent` in `button.dart`).
`WidgetbookComponent` and `WidgetbookUseCase` come from `package:widgetbook/widgetbook.dart` — see the API list below for their exact constructors.

### 1. Playground

One widget, driven entirely by knobs (label text, variant/size, `selected`,
`disabled`, etc. — whichever apply to that component). Read the theme with
`CruxTheme.of(context)` as any normal consumer would; the catalog's
`ThemeAddon` (wired in `main.dart`) supplies it, so do not build your own
`CruxTheme` here.

### 2. States matrix

A grid of every variant × state (normal / disabled only — no simulated
press) × size, all visible at once in a single screen.

**This must be split into two pieces in the same file:**

1. A standalone widget (e.g. `ButtonStatesMatrix`) that takes **no
   `CruxTheme` dependency of its own** — it must read colors/spacing only
   through whatever `CruxTheme.of(context)` resolves to from its
   surrounding context, and must not assume a specific theme, `MediaQuery`,
   or app shell. This is the widget the future golden test
   (`widgetbook/test/golden_test.dart`) will pump directly inside its own
   `CruxTheme` ancestor, without going through Widgetbook at all — so it
   must render correctly as a bare widget with just a `CruxTheme` (or
   `Directionality`, if `CruxTheme.of`'s light fallback is being
   exercised) above it.
2. The `WidgetbookUseCase(name: 'States matrix', ...)` entry, whose builder
   just returns that widget.

### 3. Edge cases

A fixed (no knobs) set of layouts chosen to break the component: e.g. an
80px-wide container with a long label, the longest realistic `ListTile`
content, back-to-back `CruxDivider`s, etc. Pick the cases that are
plausible for that specific component; they don't have to match this list
literally.

## Allowed widgetbook API (confirmed against the pinned 3.25.0 source in
`~/.pub-cache/hosted/pub.dev/widgetbook-3.25.0/lib/`)

Import everything from `package:widgetbook/widgetbook.dart`.

### Navigation nodes

- `WidgetbookComponent({required String name, required List<WidgetbookUseCase> useCases, bool isInitiallyExpanded = false})`
- `WidgetbookUseCase({required String name, required WidgetBuilder builder, String? designLink})`
  - `builder` is `Widget Function(BuildContext)`.
  - There's also `WidgetbookUseCase.child({required name, required Widget child, String? designLink})` for a static widget with no `BuildContext` dependency — fine to use for Edge cases entries that need no context.

Do not use `WidgetbookFolder` / `WidgetbookCategory` here — grouping above
component level is the integration owner's job in `main.dart`.

### Knobs (`context.knobs.*`, from `BuildContext`'s `KnobsExtension`)

Only use knobs inside `WidgetbookUseCase.builder` (they read
`WidgetbookState.of(context)`, which only exists inside a use case).

- `context.knobs.string({required String label, String? description, String initialValue = '', int? maxLines = 1}) → String`
- `context.knobs.boolean({required String label, String? description, bool initialValue = false}) → bool`
- `context.knobs.object.dropdown<T>({required String label, required List<T> options, T? initialOption, String? description, String Function(T)? labelBuilder}) → T`
- `context.knobs.object.segmented<T>({required String label, required List<T> options, T? initialOption, String? description, String Function(T)? labelBuilder}) → T`
  (use this for a small enum like `CruxButtonVariant`/`CruxButtonSize`; use `.dropdown` if the option list is long)
- `context.knobs.int.slider({required String label, String? description, int initialValue = 0, int min = 0, int max = 20, int? divisions}) → int`
- `context.knobs.int.input({required String label, String? description, int initialValue = 0}) → int`
- `context.knobs.double.slider({required String label, String? description, double initialValue = 0, double min = 0, double max = 20, int? divisions, int? precision = 1}) → double`

There are also `*OrNull` variants (`context.knobs.booleanOrNull`,
`context.knobs.object.dropdown`'s `OrNull` counterpart on
`context.knobs.objectOrNull`, etc.) if a knob genuinely needs to represent
"unset" — none of this milestone's components need that.

Do not use the deprecated `context.knobs.list` / `context.knobs.listOrNull`
— use `context.knobs.object.dropdown` instead (the source marks `list` as
`@Deprecated('Use knobs.object.dropdown instead.')`).

### Theme access

Do not construct or reference any widgetbook `ThemeAddon`/`WidgetbookTheme`
inside a use-case file — that's configured once in `main.dart`. Inside a
use case, just call `CruxTheme.of(context)` like any normal widget would;
Playground and Edge cases automatically render under whichever theme is
selected in the catalog's addon bar. The States matrix widget (per the rule
above) must work correctly no matter what supplies its `CruxTheme`
ancestor, since the golden test will supply its own.

### What not to use

- No `MaterialThemeAddon` / `CupertinoThemeAddon` / `ThemeData` /
  `CupertinoThemeData` anywhere — this package never touches Material or
  Cupertino theming (see root `CLAUDE.md`).
- No `DeviceFrameAddon` — it's deprecated in 3.25 in favor of
  `ViewportAddon` (already wired in `main.dart`); nothing to do in a
  use-case file either way, device framing is addon-level, not per-file.
- No `widgetbook_generator` / `@UseCase` / `@WidgetbookApp` annotations —
  this catalog is hand-registered, not code-generated (see spec.md).
