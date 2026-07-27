// Golden coverage for every component's States matrix widget.
//
// Per spec.md's "golden テスト" section: each component's States matrix
// widget (see `lib/usecases/CONVENTIONS.md` for what makes it eligible —
// no `CruxTheme` dependency of its own) is pumped directly under a bare
// [CruxTheme] in both light and dark, and compared with a plain
// `matchesGoldenFile`. No extra golden-testing package (e.g. alchemist) is
// used, per spec.
//
// Regenerate baselines after an intentional visual change with:
//   cd widgetbook && flutter test --update-goldens

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook_app/usecases/button.dart';
import 'package:widgetbook_app/usecases/card.dart';
import 'package:widgetbook_app/usecases/chip.dart';
import 'package:widgetbook_app/usecases/foundations.dart';
import 'package:widgetbook_app/usecases/input_bar.dart';
import 'package:widgetbook_app/usecases/list_tile.dart';
import 'package:widgetbook_app/usecases/switch_.dart';
import 'package:widgetbook_app/usecases/text_form_field.dart';

void main() {
  final Map<String, Widget> matrices = <String, Widget>{
    'foundations': const FoundationsStatesMatrix(),
    'button': const ButtonStatesMatrix(),
    'chip': const ChipStatesMatrix(),
    'card': const CardStatesMatrix(),
    'input_bar': const InputBarStatesMatrix(),
    'list_tile': const ListTileStatesMatrix(),
    'switch': const SwitchStatesMatrix(),
    'text_form_field': const TextFormFieldStatesMatrix(),
  };

  final Map<String, CruxThemeData> themes = <String, CruxThemeData>{
    'light': CruxThemeData.light(),
    'dark': CruxThemeData.dark(),
  };

  for (final MapEntry<String, Widget> component in matrices.entries) {
    for (final MapEntry<String, CruxThemeData> theme in themes.entries) {
      testWidgets('${component.key} states matrix (${theme.key})', (
        WidgetTester tester,
      ) async {
        await _expectMatrixGolden(
          tester,
          matrix: component.value,
          theme: theme.value,
          goldenFile: 'goldens/${component.key}_${theme.key}.png',
        );
      });
    }
  }
}

/// Pumps [matrix] directly under a bare [CruxTheme] — matching the
/// golden-test contract in `lib/usecases/CONVENTIONS.md`, which requires
/// every States matrix widget to take no [CruxTheme] of its own — and
/// gives the test surface a loose, generous canvas (900×4000 logical
/// pixels, device pixel ratio 1) so [matrix] lays out at its own natural
/// size instead of being stretched to fill or clipped by a fixed viewport.
/// Because the constraints are loose (not tight), the root [RenderView]
/// sizes itself to the widget's actual content
/// (`RenderView.performLayout`'s `sizedByChild` path), so the captured
/// golden image is cropped to the widget's own bounds with no extra blank
/// canvas around it.
Future<void> _expectMatrixGolden(
  WidgetTester tester, {
  required Widget matrix,
  required CruxThemeData theme,
  required String goldenFile,
}) async {
  tester.view.physicalConstraints = const ui.ViewConstraints(
    maxWidth: 900,
    maxHeight: 4000,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalConstraints);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CruxTheme(data: theme, child: matrix),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(find.byWidget(matrix), matchesGoldenFile(goldenFile));
}
