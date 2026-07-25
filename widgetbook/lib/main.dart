import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

import 'usecases/button.dart';
import 'usecases/card.dart';
import 'usecases/chip.dart';
import 'usecases/foundations.dart';
import 'usecases/list_tile.dart';
import 'usecases/switch_.dart';

/// Entry point of the Crux UI catalog app.
///
/// This file is intentionally a thin shell: it only wires up addons (theme,
/// text scale, viewport) and the top-level directory list. Individual
/// components live in `lib/usecases/<name>.dart` — see
/// `lib/usecases/CONVENTIONS.md` for the contract each of those files
/// follows.
void main() {
  runApp(const WidgetbookApp());
}

/// The root widget of the catalog app.
class WidgetbookApp extends StatelessWidget {
  /// Creates the catalog app.
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook(
      // crux_ui never touches Material theming (see root CLAUDE.md), so
      // the use-case host uses WidgetsApp rather than Widgetbook.material —
      // keeping the catalog's rendering surface consistent with how
      // consumers actually use the package. Widgetbook's *default*
      // appBuilder (`widgetsAppBuilder`, used automatically if `appBuilder`
      // is left unset) also builds a WidgetsApp, but without a
      // `pageRouteBuilder` — see `_appBuilder`'s doc comment below for why
      // that crashes every use case's preview, and why this app supplies
      // its own appBuilder instead of relying on that default.
      directories: _directories,
      appBuilder: _appBuilder,
      addons: [
        // Injects CruxThemeData.light()/dark() via CruxTheme, mirroring
        // how a real app would provide the theme. Deliberately not
        // MaterialThemeAddon/CupertinoThemeAddon — this package has no
        // Material or Cupertino theme to switch.
        ThemeAddon<CruxThemeData>(
          themes: [
            WidgetbookTheme(name: 'Light', data: CruxThemeData.light()),
            WidgetbookTheme(name: 'Dark', data: CruxThemeData.dark()),
          ],
          themeBuilder: (context, theme, child) {
            return CruxTheme(
              data: theme,
              child: ColoredBox(color: theme.colors.background, child: child),
            );
          },
        ),
        TextScaleAddon(),
        // DeviceFrameAddon is deprecated in widgetbook 3.25 in favor of
        // ViewportAddon (confirmed in
        // ~/.pub-cache/hosted/pub.dev/widgetbook-3.25.0/lib/src/addons/
        // device_frame_addon/device_frame_addon.dart), so this catalog uses
        // the non-deprecated replacement instead of the addon the spec's
        // wording names literally.
        ViewportAddon(Viewports.all),
      ],
    );
  }
}

/// Builds the [WidgetsApp] every use case's preview pane renders inside.
///
/// Widgetbook's own default `appBuilder` (`widgetsAppBuilder` in
/// `widgetbook`'s `lib/src/state/default_app_builders.dart`) builds
/// `WidgetsApp(home: child)` with none of `builder`, `onGenerateRoute`, or
/// `pageRouteBuilder` set. `WidgetsApp`'s constructor unconditionally
/// asserts `builder != null || onGenerateRoute != null || pageRouteBuilder
/// != null` (`package:flutter/src/widgets/app.dart`) — unconditionally
/// meaning this check does not depend on whether `home` is null, so it
/// fails every single time that default builder runs. Because Widgetbook's
/// `Workbench` only calls `appBuilder` once a use case is actually selected
/// (before that it shows a plain welcome page that never reaches this
/// code), the crash is invisible until a visitor opens any component's
/// preview — exactly the "whole preview area goes red" symptom this app
/// hit. Supplying `pageRouteBuilder` here (the fix the assertion's own
/// message names) resolves it without introducing Material theming: this
/// still returns a bare [WidgetsApp], not a [MaterialApp]/[CupertinoApp].
Widget _appBuilder(BuildContext context, Widget child) {
  return WidgetsApp(
    debugShowCheckedModeBanner: false,
    color: const Color(0xFFFFFFFF),
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
      return PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
      );
    },
    home: child,
  );
}

/// Top-level catalog structure: a "Foundations" category for the design
/// token overview and an "Atoms" category for every component, per spec.md's
/// "Foundations / Atoms のカテゴリ分け" instruction. Each `<name>Component`
/// getter is built in its own `lib/usecases/<name>.dart` file (see
/// `lib/usecases/CONVENTIONS.md`); this list just assembles them.
final List<WidgetbookNode> _directories = [
  WidgetbookCategory(name: 'Foundations', children: [foundationsComponent]),
  WidgetbookCategory(
    name: 'Atoms',
    children: [
      buttonComponent,
      chipComponent,
      cardComponent,
      listTileComponent,
      switchComponent,
    ],
  ),
];
