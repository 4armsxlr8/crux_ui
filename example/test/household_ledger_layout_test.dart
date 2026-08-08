// Regression test, originally written for a real-device bug: an earlier
// version of HouseholdLedgerScreen wrapped its scrolling list
// (CruxTopFade(child: ListView)) in Positioned.fill inside a Stack while
// a since-removed floating-header molecule (a bar-free header of circular
// leading/action buttons plus a centered title) was the Stack's only
// non-positioned child. A Scaffold body gets loose (min 0) constraints, so
// a loose Stack sizes itself to its tallest non-positioned child -- there,
// that compact header (about 46 logical pixels tall) -- and clips
// everything else (including the Positioned.fill list) to that height, per
// Stack's default hardEdge clipBehavior. The screen rendered as a
// near-blank sliver instead of a full-height list.
//
// That header molecule was withdrawn from this screen, and from the
// package entirely, on 2026-08-05 (see `unknowns/navigation-bars/ledger.md`'s
// dated entry) -- the screen's body is now a single
// CruxTopFade(child: ListView) with nothing stacked in front of it, so
// the Stack that could collapse this way no longer exists. This file stays
// as a general smoke test for the same two user-visible symptoms the
// original bug produced (the list not actually filling the screen, and its
// content not actually being reachable by touch), guarding against any
// future layout change that reintroduces either one -- including
// MainShell's own outer Stack (IndexedStack + the floating CruxNavBar),
// this screen's new host as of the 家計簿 tab.

import 'package:example/main.dart';
import 'package:example/screens/main_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Logs in with valid credentials and switches to the 家計簿 tab, the way a
/// user would reach [HouseholdLedgerScreen].
Future<void> _openHouseholdLedgerTab(WidgetTester tester) async {
  await tester.pumpWidget(const CruxExampleApp());
  await tester.enterText(
    find.byType(CruxTextFormField).at(0),
    'taro@example.com',
  );
  await tester.enterText(find.byType(CruxTextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(CruxButton, 'ログイン'));
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(CruxNavBar<AppTab>),
      matching: find.text('家計簿'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the ledger list fills the screen instead of collapsing to a shorter '
    'sibling ancestor',
    (WidgetTester tester) async {
      await _openHouseholdLedgerTab(tester);

      final Size screenSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;

      final RenderBox topFadeBox = tester.renderObject<RenderBox>(
        find.byType(CruxTopFade),
      );

      // The list's own CruxTopFade should span nearly the full screen
      // height, not collapse to some far shorter sibling's height the way
      // it did under the old bug this file guards against (see this file's
      // own top-of-file doc).
      expect(topFadeBox.size.height, greaterThan(screenSize.height * 0.8));
    },
  );

  testWidgets(
    'the monthly total label is actually reachable by touch, not clipped '
    'away by a collapsed ancestor',
    (WidgetTester tester) async {
      await _openHouseholdLedgerTab(tester);

      // `Finder.hitTestable()` walks from the root view down to this exact
      // widget's own paint position: it only matches when every ancestor
      // (including the Stack this bug collapses) actually contains that
      // position within its own laid-out size. A widget can satisfy
      // `findsOneWidget` (it still exists in the tree, still has a size)
      // while being unreachable this way, which is exactly what the
      // collapsed-Stack bug does to this label.
      expect(find.text('8月の支出'), findsOneWidget);
      expect(find.text('8月の支出').hitTestable(), findsOneWidget);
    },
  );
}
