// Regression test for a localization gap first found on a physical iPhone: a
// CruxTextFormField's copy/paste selection toolbar showed English
// ("Paste"/"Scan Text") inside this Japanese-language sample app.
//
// IMPORTANT -- what this test does and does NOT prove. This test pumps a
// CruxTextFormField inside `flutter test`'s software test environment,
// which has no real iOS to hand the selection menu to. So the menu it
// exercises is always CupertinoTextField's Flutter-drawn fallback toolbar
// (CupertinoAdaptiveTextSelectionToolbar), which does read its button
// labels from whichever CupertinoLocalizations the ambient widget tree
// supplies. That is a real, separate code path (it is what actually renders
// on older iOS, Android, and desktop) and this test is the right guard for
// it. But on a physical iPhone running iOS 16+, that is NOT the menu the
// user sees: CupertinoTextField._defaultContextMenuBuilder
// (package:flutter/src/cupertino/text_field.dart:820-825 in the local SDK)
// hands the menu to SystemContextMenu whenever
// SystemContextMenu.isSupportedByField(editableTextState) is true
// (package:flutter/src/widgets/system_context_menu.dart:146-148), which iOS
// 16+ satisfies -- and that menu is drawn by iOS itself (UIKit), reading
// the app bundle's declared CFBundleLocalizations from Info.plist, not
// anything this test or CupertinoLocalizations controls. A green run of
// this test is therefore evidence for the Flutter-drawn-fallback path only;
// it is NOT proof that a physical iOS 16+ device is localized. See
// unknowns/textfield-atom/implementation-notes.md's 2026-07-26
// "Post-milestone correction" entry for the full misdiagnosis writeup, and
// lib/src/text_form_field.dart's "Localization" doc note / README.md for
// the corrected, two-source explanation. The actual device-visible fix was
// adding CFBundleLocalizations (ja, en) to example/ios/Runner/Info.plist,
// not anything exercised by this test.
//
// This test lives in example/test/ rather than the package's own test/
// because exercising the fallback-toolbar path requires depending on
// flutter_localizations, and the package (test/../pubspec.yaml) must never
// gain that dependency -- see root CLAUDE.md's "crux_ui package itself
// must NOT depend on flutter_localizations" rule. example/ is the one place
// in this repo that already carries flutter_localizations, and its
// MaterialApp is wired exactly the way this test pumps it, so a regression
// here is also a regression in the real sample app's non-iOS-16+ behavior.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// A minimal in-memory mock of the `Clipboard` platform channel.
///
/// `flutter test`'s default binary messenger answers `Clipboard.getData`
/// with no content unless a handler is installed, and
/// `CupertinoTextSelectionToolbarButton` only renders a Paste button once
/// the field's `ClipboardStatusNotifier` observes non-empty clipboard text
/// (confirmed against the Flutter SDK's own
/// `packages/flutter/test/cupertino/text_field_test.dart`, which installs
/// the same kind of mock for the same reason). Without this, the toolbar
/// would only ever show Copy/Select all, and this test could never observe
/// the Paste button whose English-vs-Japanese wording is the actual bug.
class _MockClipboard {
  String? _text;

  Future<Object?> handleMethodCall(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'Clipboard.getData':
        return _text == null ? null : <String, dynamic>{'text': _text};
      case 'Clipboard.setData':
        final Map<Object?, Object?> args =
            methodCall.arguments! as Map<Object?, Object?>;
        _text = args['text'] as String?;
        return null;
      case 'Clipboard.hasStrings':
        return <String, dynamic>{'value': (_text ?? '').isNotEmpty};
      default:
        return null;
    }
  }
}

void main() {
  final _MockClipboard mockClipboard = _MockClipboard();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          mockClipboard.handleMethodCall,
        );
    // So the toolbar's Paste button has something to be visible for.
    await Clipboard.setData(const ClipboardData(text: 'クリップボードの内容'));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('shows the Japanese paste-button label, not "Paste", inside a '
      'MaterialApp configured the way example/lib/main.dart now is (Japanese '
      'locale plus the three Global*Localizations delegates)', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'メールアドレス',
    );
    addTearDown(controller.dispose);
    final FocusNode focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const <Locale>[Locale('ja'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: CruxTextFormField(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    // Long-pressing the field's text is what a real user does to bring up
    // the selection toolbar; this exercises the same
    // focus/selection/clipboard-status pipeline a device would, rather
    // than reaching into EditableTextState internals.
    await tester.longPress(find.byType(EditableText));
    await tester.pumpAndSettle();

    // Ground truth for what the Japanese label actually is, read from
    // Flutter's own bundled cupertino_ja.arb-backed localizations rather
    // than a hard-coded guess at the translated string.
    final CupertinoLocalizations ja = await GlobalCupertinoLocalizations
        .delegate
        .load(const Locale('ja'));

    expect(find.text(ja.pasteButtonLabel), findsOneWidget);
    expect(find.text('Paste'), findsNothing);
  });
}
