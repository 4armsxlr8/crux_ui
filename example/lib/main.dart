import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:crux_ui/crux_ui.dart';

import 'screens/home_index_page.dart';
import 'theme_mode_scope.dart';

void main() {
  runApp(const CruxExampleApp());
}

/// Root widget of the gallery app.
///
/// Holds which [CruxThemeData] (light or dark) is currently active and
/// provides it to the whole subtree via [CruxTheme]. Note that this does
/// not create or touch a Material [ThemeData]: [MaterialApp] below is only
/// used as the app shell it must be (for [Scaffold], routing, and so on),
/// its default `ThemeData` is never read or customized, and every visible
/// pixel is painted by widgets that read colors and type styles straight
/// from [CruxTheme.of] so that they follow the toggle.
///
/// **Screens.** [MaterialApp.home] is [HomeIndexPage]: a gallery index that
/// lists one sample screen per component use case and pushes to whichever
/// one is tapped (see that class's own doc comment, and root `CLAUDE.md`'s
/// catalog operating rule). The current light/dark flag and its setter are
/// exposed to every pushed screen through [ThemeModeScope] rather than
/// threaded through each screen's constructor, so [HomeIndexPage] and every
/// screen under `screens/` stay free of that plumbing.
///
/// **Localization.** Every visible string in this app is hard-coded
/// Japanese, so [MaterialApp] is pinned to `Locale('ja')` rather than left
/// to resolve from the device/simulator's own locale. Without the three
/// `Global*Localizations.delegate`s below, `CruxTextFormField`'s
/// selection/copy-paste menu (built on [CupertinoTextField], see its own
/// "Localization" doc note) would fall back to Flutter's English-only
/// `DefaultCupertinoLocalizations` and show "Paste" instead of「ペースト」
/// even on a Japanese device — this app supplies the `flutter_localizations`
/// delegates so it reads correctly. `crux_ui` itself never depends on
/// `flutter_localizations`; that dependency lives only here, in the
/// consuming app.
class CruxExampleApp extends StatefulWidget {
  /// Creates the example app.
  const CruxExampleApp({super.key});

  @override
  State<CruxExampleApp> createState() => _CruxExampleAppState();
}

class _CruxExampleAppState extends State<CruxExampleApp> {
  CruxThemeData _cruxTheme = CruxThemeData.light();

  void _setDark(bool isDark) {
    setState(() {
      _cruxTheme = isDark ? CruxThemeData.dark() : CruxThemeData.light();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CruxTheme(
      data: _cruxTheme,
      child: ThemeModeScope(
        isDark: _cruxTheme.brightness == Brightness.dark,
        onDarkChanged: _setDark,
        child: MaterialApp(
          title: 'Crux UI Sample',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ja'),
          supportedLocales: const <Locale>[Locale('ja'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const HomeIndexPage(),
        ),
      ),
    );
  }
}
