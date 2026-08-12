// One-off diagnostic (per plans/atoms-batch-3.md's widgetbook step: "widgetbook
// の素の WidgetsApp 構成でオーバーレイが動くかを最初に検証") verifying that
// `CruxDialog.show` and `CruxToastHost`/`showCruxToast` actually work
// when pumped under the exact same shell `lib/main.dart`'s private
// `_appBuilder` wraps every use case's preview pane in: a bare [WidgetsApp]
// with no Material/Cupertino app around it, supplying only a custom
// `pageRouteBuilder` (required — see `_appBuilder`'s own doc for why a bare
// [WidgetsApp] otherwise asserts) and the same localization delegates.
// `_appBuilder` itself is a private top-level function in `lib/main.dart` and
// cannot be imported directly, so this file reconstructs the identical shape
// rather than reusing it — see `_wrapInWidgetbookShell` below.
//
// This exists purely to answer one question ahead of writing the Playground
// use cases for `CruxDialog`/`CruxConfirmDialog`/`CruxToastHost`:
// does `Overlay.of(context)` (which `CruxDialog.show` calls) resolve
// correctly, and does `showCruxToast`'s `CruxToastHost` ancestor lookup
// work, inside this shell? It is not part of either component's regular
// coverage (that lives in the package's own `test/`, out of scope for this
// milestone) and is not wired into any CI-relevant suite beyond `flutter
// test` picking it up like any other test file in this directory.

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Reproduces `lib/main.dart`'s private `_appBuilder` shape: a bare
/// [WidgetsApp] with a `pageRouteBuilder` that returns a plain
/// [PageRouteBuilder] (the fix `_appBuilder`'s own doc names for the
/// "unconditional assertion" crash) and the same localization delegates that
/// file supplies, wrapping [home] — which is itself wrapped in a
/// [CruxTheme], mirroring how the catalog's `ThemeAddon` supplies one to
/// every use case's preview.
Widget _wrapInWidgetbookShell(Widget home, {CruxThemeData? theme}) {
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
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const <Locale>[Locale('ja'), Locale('en')],
    home: CruxTheme(data: theme ?? CruxThemeData.light(), child: home),
  );
}

void main() {
  testWidgets(
    'CruxDialog.show opens above and closes under the widgetbook shell',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapInWidgetbookShell(
          Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () => CruxDialog.show(
                  context,
                  builder: (BuildContext dialogContext, VoidCallback close) {
                    return Text('dialog content');
                  },
                ),
                child: const Text('open dialog'),
              );
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      expect(find.text('dialog content'), findsNothing);
      await tester.tap(find.text('open dialog'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('dialog content'), findsOneWidget);

      // Tapping the scrim (anywhere outside the card) should close it, per
      // CruxDialog.show's default barrierDismissible: true.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('dialog content'), findsNothing);
    },
  );

  testWidgets("CruxDialog content inherits the CruxTheme around WidgetsApp's "
      '`home` -- even though Overlay.of(context) resolves to WidgetsApp\'s '
      'own internal Navigator/Overlay, which sits *outside* (above) `home` '
      'in the tree, CruxDialog.show captures the calling context\'s theme '
      'at show time and re-provides it inside the overlay entry, so the '
      "catalog Playground's dialog follows the light/dark toggle (the shape "
      "widgetbook's real ThemeAddon + appBuilder wrapping produces: "
      "`Workbench.build` in widgetbook 3.25.0's own source passes the "
      "ThemeAddon-wrapped use-case content as `appBuilder`'s `child`, which "
      "becomes `_appBuilder`'s `home`). This test pins that capture: without "
      'it the dialog would fall back to the light default.', (
    WidgetTester tester,
  ) async {
    late Brightness dialogBrightness;
    await tester.pumpWidget(
      _wrapInWidgetbookShell(
        Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () => CruxDialog.show(
                context,
                builder: (BuildContext dialogContext, VoidCallback close) {
                  dialogBrightness = CruxTheme.of(dialogContext).brightness;
                  return const Text('probe');
                },
              ),
              child: const Text('open dialog'),
            );
          },
        ),
        theme: CruxThemeData.dark(),
      ),
    );

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('probe'), findsOneWidget);
    expect(dialogBrightness, Brightness.dark);
  });

  testWidgets('CruxConfirmDialog.show opens above the widgetbook shell and its '
      'actions close it', (WidgetTester tester) async {
    bool confirmed = false;
    await tester.pumpWidget(
      _wrapInWidgetbookShell(
        Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () => CruxConfirmDialog.show(
                context,
                title: '確認',
                message: '実行しますか？',
                cancelLabel: 'キャンセル',
                confirmLabel: '実行',
                onConfirm: () => confirmed = true,
              ),
              child: const Text('open confirm dialog'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open confirm dialog'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('確認'), findsOneWidget);
    expect(find.text('実行しますか？'), findsOneWidget);

    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(confirmed, isTrue);
    expect(find.text('確認'), findsNothing);
  });

  testWidgets('showCruxToast shows a toast above the widgetbook shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapInWidgetbookShell(
        CruxToastHost(
          child: Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () => showCruxToast(context, message: 'toast message'),
                child: const Text('show toast'),
              );
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('toast message'), findsNothing);
    await tester.tap(find.text('show toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('toast message'), findsOneWidget);
  });

  testWidgets(
    'showCruxToast: a duplicate message shakes instead of stacking, and '
    'swiping dismisses, above the widgetbook shell',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapInWidgetbookShell(
          CruxToastHost(
            child: Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  onTap: () => showCruxToast(context, message: 'duplicate me'),
                  child: const Text('show toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('show toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('show toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      // Still exactly one card, not two.
      expect(find.text('duplicate me'), findsOneWidget);

      // Swipe it away.
      await tester.drag(find.text('duplicate me'), const Offset(400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('duplicate me'), findsNothing);
    },
  );
}
