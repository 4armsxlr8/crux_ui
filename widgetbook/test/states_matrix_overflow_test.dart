// Cross-check for the "self-wrap in a SingleChildScrollView" convention
// documented at `lib/usecases/button.dart:75-99` (`ButtonStatesMatrix`):
// any States matrix widget taller than the catalog's preview pane must wrap
// itself so it scrolls instead of overflowing with Flutter's yellow-and-
// black stripes. This file pumps every `*StatesMatrix` widget that
// `test/golden_test.dart` also pumps (see that file for the full list and
// for the pump conventions this test borrows) inside a viewport far
// shorter than the golden test's generous canvas, to catch matrices that
// forgot the wrap.
//
// This does not go through Widgetbook at all, matching
// `lib/usecases/CONVENTIONS.md`'s requirement that a States matrix widget
// render correctly under nothing but a [CruxTheme]/[Directionality]
// ancestor.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook_app/usecases/button.dart';
import 'package:widgetbook_app/usecases/card.dart';
import 'package:widgetbook_app/usecases/checkbox.dart';
import 'package:widgetbook_app/usecases/chip.dart';
import 'package:widgetbook_app/usecases/composer.dart';
import 'package:widgetbook_app/usecases/dialog.dart';
import 'package:widgetbook_app/usecases/foundations.dart';
import 'package:widgetbook_app/usecases/icon_button.dart';
import 'package:widgetbook_app/usecases/input_bar.dart';
import 'package:widgetbook_app/usecases/list_tile.dart';
import 'package:widgetbook_app/usecases/nav_bar.dart';
import 'package:widgetbook_app/usecases/segmented_control.dart';
import 'package:widgetbook_app/usecases/slider.dart';
import 'package:widgetbook_app/usecases/spinner.dart';
import 'package:widgetbook_app/usecases/switch_.dart';
import 'package:widgetbook_app/usecases/text_form_field.dart';
import 'package:widgetbook_app/usecases/toast.dart';
import 'package:widgetbook_app/usecases/top_fade.dart';

void main() {
  final Map<String, Widget> matrices = <String, Widget>{
    'foundations': const FoundationsStatesMatrix(),
    'button': const ButtonStatesMatrix(),
    'chip': const ChipStatesMatrix(),
    'card': const CardStatesMatrix(),
    'composer': const ComposerStatesMatrix(),
    'input_bar': const InputBarStatesMatrix(),
    'list_tile': const ListTileStatesMatrix(),
    'switch': const SwitchStatesMatrix(),
    'text_form_field': const TextFormFieldStatesMatrix(),
    'spinner': const SpinnerStatesMatrix(),
    'icon_button': const IconButtonStatesMatrix(),
    'checkbox': const CheckboxStatesMatrix(),
    'dialog': const DialogStatesMatrix(),
    'segmented_control': const SegmentedControlStatesMatrix(),
    'slider': const SliderStatesMatrix(),
    'toast': const ToastStatesMatrix(),
    'nav_bar': const NavBarStatesMatrix(),
    'top_fade': const TopFadeStatesMatrix(),
  };

  // Same two matrices `golden_test.dart` singles out: SpinnerStatesMatrix
  // and ButtonStatesMatrix (via its loading CruxButton) run a continuous
  // CruxMotion.repeat animation and never settle, so `pumpAndSettle`
  // would hang forever waiting for a frame with no pending animation.
  const Set<String> neverSettles = <String>{'spinner', 'button'};

  for (final MapEntry<String, Widget> component in matrices.entries) {
    testWidgets(
      '${component.key} states matrix does not overflow a short viewport',
      (WidgetTester tester) async {
        // 900×500: as wide as the golden canvas but far shorter than any
        // matrix's natural content height -- the same shape as the real
        // catalog's preview pane, which is what reproduces the
        // "BOTTOM OVERFLOWED BY n PIXELS" stripes this test guards against.
        tester.view.physicalConstraints = const ui.ViewConstraints(
          maxWidth: 900,
          maxHeight: 500,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalConstraints);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CruxTheme(
              data: CruxThemeData.light(),
              child: component.value,
            ),
          ),
        );
        if (neverSettles.contains(component.key)) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        } else {
          await tester.pumpAndSettle();
        }

        // A RenderFlex (or similar) overflow does not throw synchronously;
        // it is reported to FlutterError.onError during paint, which
        // WidgetTester surfaces through takeException(). No wrap needed
        // means no overflow means this is null.
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${component.key} states matrix overflowed a 900×500 '
              'viewport -- wrap it in a SingleChildScrollView like '
              'ButtonStatesMatrix (lib/usecases/button.dart:75-99).',
        );
      },
    );
  }
}
