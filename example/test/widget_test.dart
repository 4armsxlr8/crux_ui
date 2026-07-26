// A basic smoke test for the Crux UI gallery example app.
//
// The app's home screen is now HomeIndexPage, a gallery index listing one
// sample screen per component use case (see home_index_page_test.dart for
// a test of the index itself). This file exercises the "タスク一覧" screen
// reached from that index, and asserts that the token/atom-catalog
// sections removed from this app during its earlier "スリム化" (see
// unknowns/) still do not reappear here -- that full catalog lives in
// widgetbook/ instead.

import 'package:example/main.dart';
import 'package:example/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  testWidgets('navigates to the task list screen and toggles light/dark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    await tester.tap(find.text('タスク一覧'));
    await tester.pumpAndSettle();

    // The task-list screen renders the real-world sample built from Crux
    // atoms used together in context.
    expect(find.text('今日のミモザ'), findsOneWidget); // CruxCard content
    expect(find.text('はじめる'), findsOneWidget); // CruxButton inside the card
    expect(find.text('おすすめ'), findsOneWidget); // CruxChip
    expect(find.text('買い物メモを作成'), findsOneWidget); // CruxListTile row

    // The token/atom-state catalog sections (color table, type scale,
    // spacing scale, per-variant state grids) live in widgetbook/ and must
    // not reappear here.
    expect(find.text('カラー'), findsNothing);
    expect(find.text('タイプスケール'), findsNothing);
    expect(find.text('スペーシング'), findsNothing);

    // The light/dark toggle is a self-built widget (not a Material [Switch]),
    // exposed to assistive tech as a togglable control with this label, and
    // is shared across every screen via the app's header.
    final Finder toggle = find.bySemanticsLabel('ダーク表示の切り替え');
    expect(toggle, findsOneWidget);

    // The header title is painted straight from CruxColors, so its text
    // color is a direct, public signal of which palette is active. Scoped
    // to a descendant of AppHeader since "タスク一覧" is also this screen's
    // index-row label back on HomeIndexPage.
    final Finder title = find.descendant(
      of: find.byType(AppHeader),
      matching: find.text('タスク一覧'),
    );
    final Text lightTitle = tester.widget(title);
    expect(lightTitle.style?.color, CruxColors.light.textPrimary);

    // Flipping the toggle swaps to the dark Crux theme without throwing.
    await tester.tap(toggle);
    await tester.pump();

    final Text darkTitle = tester.widget(title);
    expect(darkTitle.style?.color, CruxColors.dark.textPrimary);
  });
}
