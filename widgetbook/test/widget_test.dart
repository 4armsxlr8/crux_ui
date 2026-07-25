// A smoke test for the Crux UI catalog shell.
//
// This boots WidgetbookApp *and* opens a use case's preview pane — not just
// the default "Welcome to Widgetbook" landing screen — because Widgetbook's
// `Workbench` only calls `appBuilder` (the code path that wraps every use
// case's preview) once a use case is actually selected; before that it just
// shows `state.home` (see `Workbench.build` in
// `~/.pub-cache/hosted/pub.dev/widgetbook-3.25.0/lib/src/workbench/
// workbench.dart`). A test that never selects a use case can never exercise
// `appBuilder`, so it can't catch a bug living there.
//
// It then asserts two things a passing boot must satisfy:
//  1. no exception was thrown while building/rendering any pumped frame
//     (`tester.takeException()` is null);
//  2. the selected use case's own content rendered in the preview pane
//     (a specific piece of its text), not a red error screen standing in
//     for it.
//
// See `unknowns/catalog/implementation-notes.md`, "Boot crash fix
// (2026-07-25)" for why the previous version of this test — which only
// pumped `WidgetbookApp` at its default route and asserted
// `find.byType(WidgetbookApp), findsOneWidget` — missed a real boot crash
// in the preview pane. Per-component behavior beyond this is covered by
// each use-case's own tests/goldens, not here.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook_app/main.dart';

void main() {
  testWidgets(
    'WidgetbookApp boots and renders a use case preview without error',
    (WidgetTester tester) async {
      // A desktop-sized viewport so the catalog's sidebar navigation (used
      // below to open a use case) is actually laid out, matching how the
      // real macOS app renders at launch — Widgetbook's responsive layout
      // hides/collapses the sidebar at the default 800x600 test viewport.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const WidgetbookApp());
      await tester.pumpAndSettle();

      // Open the first component's Playground use case (Foundations >
      // Playground, per main.dart's `_directories` order) — this is what
      // actually exercises `appBuilder`.
      final Finder playground = find.text('Playground').first;
      expect(playground, findsOneWidget);
      await tester.tap(playground);
      await tester.pumpAndSettle();

      // No exception should have been thrown while building/rendering the
      // preview pane.
      expect(tester.takeException(), isNull);

      // The preview pane should show the use case's own content — the
      // Foundations Playground's default color-token line — rather than a
      // red error screen standing in for it.
      expect(find.text('カラー: accent'), findsOneWidget);
    },
  );
}
