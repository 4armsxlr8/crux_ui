// A basic smoke test for the Crux UI token showcase example app.

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  testWidgets('renders the showcase and toggles light/dark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CruxExampleApp());

    // The app starts in light mode and renders its section headings.
    expect(find.text('カラー'), findsOneWidget);
    expect(find.text('タイプスケール'), findsOneWidget);
    expect(find.text('スペーシング'), findsOneWidget);
    expect(find.text('実戦サンプル'), findsOneWidget);

    // The light/dark toggle is a self-built widget (not a Material [Switch]),
    // exposed to assistive tech as a togglable control with this label.
    final Finder toggle = find.bySemanticsLabel('ダーク表示の切り替え');
    expect(toggle, findsOneWidget);

    // The header title is painted straight from CruxColors, so its text
    // color is a direct, public signal of which palette is active.
    final Finder title = find.text('Crux UI Tokens');
    final Text lightTitle = tester.widget(title);
    expect(lightTitle.style?.color, CruxColors.light.textPrimary);

    // Flipping the toggle swaps to the dark Crux theme without throwing.
    await tester.tap(toggle);
    await tester.pump();

    final Text darkTitle = tester.widget(title);
    expect(darkTitle.style?.color, CruxColors.dark.textPrimary);
  });
}
