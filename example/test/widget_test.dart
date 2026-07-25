// A basic smoke test for the Crux UI showcase example app.
//
// Per spec.md's "example/ スリム化" section, this app is a single
// real-world sample screen (not a token/atom-state catalog — that lives in
// widgetbook/ now), so this test asserts the sample content renders and
// that the removed token/atom-catalog sections do not reappear.

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  testWidgets('renders the real-world sample and toggles light/dark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    // The app starts in light mode and renders the real-world sample built
    // from Crux atoms used together in context.
    expect(find.text('今日のミモザ'), findsOneWidget); // CruxCard content
    expect(find.text('はじめる'), findsOneWidget); // CruxButton inside the card
    expect(find.text('おすすめ'), findsOneWidget); // CruxChip
    expect(find.text('買い物メモを作成'), findsOneWidget); // CruxListTile row

    // The token/atom-state catalog sections (color table, type scale,
    // spacing scale, per-variant state grids) were moved to widgetbook/ and
    // must not reappear here.
    expect(find.text('カラー'), findsNothing);
    expect(find.text('タイプスケール'), findsNothing);
    expect(find.text('スペーシング'), findsNothing);

    // The light/dark toggle is a self-built widget (not a Material [Switch]),
    // exposed to assistive tech as a togglable control with this label.
    final Finder toggle = find.bySemanticsLabel('ダーク表示の切り替え');
    expect(toggle, findsOneWidget);

    // The header title is painted straight from CruxColors, so its text
    // color is a direct, public signal of which palette is active.
    final Finder title = find.text('Crux UI Sample');
    final Text lightTitle = tester.widget(title);
    expect(lightTitle.style?.color, CruxColors.light.textPrimary);

    // Flipping the toggle swaps to the dark Crux theme without throwing.
    await tester.tap(toggle);
    await tester.pump();

    final Text darkTitle = tester.widget(title);
    expect(darkTitle.style?.color, CruxColors.dark.textPrimary);
  });
}
