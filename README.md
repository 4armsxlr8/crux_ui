# Crux UI

Design tokens, a theme layer, and eighteen springy components — the crux
of a warm, friendly Flutter app.

![status: under development](https://img.shields.io/badge/status-under%20development-orange)

> **Under development.** Not yet published to pub.dev; APIs may change
> until 1.0. Details in [Status](#status).

![Screens from the example app, built entirely from Crux components](https://raw.githubusercontent.com/4armsxlr8/crux_ui/main/doc/mimosa-screens.png)

*Screens from `example/` — 「ミモザ」, a mock life-organizing app with an AI
companion: login, home, chat, and dark mode. Every visible pixel is painted
from Crux tokens and components.*

## Why

Flutter apps default to Material's look, and giving an app a brand of its
own usually means fighting `ThemeData` overrides widget by widget. Crux
takes the opposite route: it is a self-contained kit — its own
color/spacing/typography/radius/shadow tokens, its own `CruxTheme` layer,
its own widgets — and it **never reads or rewrites Material's `ThemeData`
at all**. Providing a `CruxTheme` does not change the look of `Material`,
`Scaffold`, or any other Material widget, and no Material theme can leak
into a Crux component.

One decision runs through the whole kit: **typography resolves to the host
platform's own type scale** — Apple's Human Interface Guidelines sizes on
iOS and macOS, Material 3 elsewhere — so text-bearing components change
size across platforms by design.

## Status

**Under development.** Not yet published to pub.dev. The token layer and
the eighteen components below are implemented; the rest of a screen
(bottom sheets and so on) is composed from plain Flutter widgets plus
Crux's tokens, as `example/` shows.

**Tokens** — colors, spacing, typography (platform-resolved), radii, and
shadows (elevation shadows, a modal scrim, a dark-mode hairline), provided
to a subtree by the `CruxTheme` / `CruxThemeData` pair.

**Components** — seventeen atoms plus two molecules built from them,
eighteen in total counting the two dialog layers as one:

| Component | What it is |
|---|---|
| `CruxButton` | Pill button. `filled` / `tonal` / `ghost` × `small` / `medium` / `large`, with a `loading` state |
| `CruxChip` | Filter/tag pill with a `selected` flag |
| `CruxCard` | Bordered content container; decorative by default, pressable when given `onTap` |
| `CruxListTile` | List row with `leading` / `title` / `subtitle` / `trailing` |
| `CruxSwitch` | Pill on/off toggle |
| `CruxCheckbox` | Checkbox |
| `CruxDivider` | 1 px separator rule with optional `indent` |
| `CruxTextFormField` | Single-line, `Form`-integrated text input (a real `FormField<String>`), with an optional password show/hide toggle |
| `CruxInputBar` | Search / chat input bar |
| `CruxComposer` | Post-body composer: no surrounding box, fills the screen, multi-line (molecule) |
| `CruxSpinner` | Loading indicator |
| `CruxIconButton` | Icon button |
| `CruxDialog` / `CruxConfirmDialog` | Dialog, and the ready-made confirmation layer over it (molecule) |
| `CruxToast` | Toast, shown through one app-root `CruxToastHost` |
| `CruxSegmentedControl` | Segmented control |
| `CruxSlider` | Slider |
| `CruxNavBar` | Floating bottom navigation bar with a backdrop-fade band that melts scrolling content into the page edge |
| `CruxTopFade` | Progressive fade/blur band for the top edge of scrolling content |

## Design decisions

- **One import.** `lib/crux_ui.dart` is the single public entry point;
  every component is exported from that one file.
- **Never touches Material.** Crux components read every color and text
  style from `CruxTheme.of`, and the kit neither reads nor customizes
  `ThemeData`. `CruxTextFormField` is built on `CupertinoTextField` rather
  than Material's `TextField` for the same reason — a host app's Material
  theme has no path into its look.
- **Platform-resolved type scale.** Nine typography tokens resolve to HIG
  sizes on iOS/macOS and Material 3 sizes elsewhere, with per-token
  overrides (merge semantics) and `copyWith` for app-specific tuning.
- **Controlled widgets.** `CruxSwitch`, `CruxCheckbox`, and friends follow
  Flutter's own convention: they always reflect `value` and call
  `onChanged(!value)` rather than mutating themselves. Passing a null
  callback disables a component.
- **Press feedback fits the shape.** Width-hugging components
  (`CruxButton`, `CruxCard`) get a press-spring scale; full-width rows
  (`CruxListTile`) get a state layer only — a full-width row shrinking on
  tap reads as an unnatural wobble.
- **Labels cannot overflow.** Text labels render on a single line with an
  ellipsis, so no constraint or label length breaks a component.
- **Tap targets stay 44 px.** `CruxChip`'s visible pill is 36 px tall, but
  its hit area keeps the 44 logical-pixel minimum.
- **Nothing shifts on validation.** `CruxTextFormField` always reserves its
  helper/error caption row, so an error appearing or clearing never moves
  the layout.

## Usage

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
                Text('Hello, Crux', style: theme.typography.subheading),
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

<details>
<summary>Localizing the text selection menu (Paste / Copy) in non-English apps</summary>

`CruxTextFormField`'s selection/copy-paste menu wording has two sources,
and a non-English app needs to cover both. On iOS 16+, the menu is drawn by
iOS itself, so its wording follows the **app bundle's** declared languages —
the `CFBundleLocalizations` array in `Info.plist`; see
`example/ios/Runner/Info.plist` for a working setup. Everywhere else
(older iOS, Android, desktop), Flutter draws the menu and reads its wording
from whichever `CupertinoLocalizations` the host app supplies, falling back
to English if unconfigured — add `flutter_localizations` and its
`GlobalCupertinoLocalizations.delegate` (with the Material/Widgets
equivalents and matching `supportedLocales`) to your app; see
`example/lib/main.dart`. `crux_ui` itself never depends on
`flutter_localizations`; this setup belongs to the consuming app.

</details>

## Example app and component catalog

- **`example/`** — 「ミモザとの暮らし」, a single mock app: a login screen
  into a 4-tab shell (home/tasks, chat, household ledger, settings) plus a
  journal post modal. See `example/lib/screens/` for each screen, all built
  from Crux components in the context of one app.
- **`widgetbook/`** — the dev catalog: every token scale and every atom's
  full Playground / States matrix / Edge cases pages. Run it with
  `cd widgetbook && flutter run -d macos`.

## Getting started (development)

Requires the Dart SDK `^3.12.2` and a Flutter SDK shipping a Dart version
in that range.

```sh
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

## Roadmap

The eighteen components above are shipped. The rest of the widget set —
bottom sheets, snackbars, and whatever else earns its place — has not been
designed yet; each future component lands with its tests and documentation,
on the same tokens.

## License

[MIT](LICENSE)
