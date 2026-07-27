// Behavior tests for CruxDivider, per unknowns/atoms-batch-1/spec.md's
// CruxDivider section.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxDivider needs to lay out
/// and paint (a [Directionality]) plus a [Center]: the test binding's root
/// constraints are always *tight* to the surface size, so only something
/// that actually loosens them (like [Center]) lets a childless, unsized
/// [CruxDivider] report its true 1px height instead of being forced to
/// fill the tight incoming height. See the "sizing" test in card_test.dart
/// for the same underlying constraint-tightness note.
Widget _wrap(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('appearance', () {
    testWidgets('renders a 1 logical pixel tall line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CruxDivider()));

      final Size size = tester.getSize(find.byType(CruxDivider));
      expect(size.height, 1);
    });

    testWidgets('fills the width of a bounded parent', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_wrap(const CruxDivider()));

      final Size size = tester.getSize(find.byType(CruxDivider));
      expect(size.width, 240);
    });

    testWidgets('is colored with the theme separator color (light default)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CruxDivider()));

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      expect(container.color, CruxColors.light.separator);
    });

    testWidgets('resolves the separator color from the ambient CruxTheme '
        '(dark)', (WidgetTester tester) async {
      await tester.pumpWidget(
        CruxTheme(
          data: CruxThemeData.dark(),
          child: _wrap(const CruxDivider()),
        ),
      );

      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      expect(container.color, CruxColors.dark.separator);
    });
  });

  group('indent', () {
    testWidgets('defaults to no leading offset', (WidgetTester tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(200, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_wrap(const CruxDivider()));

      final Offset dividerLeft = tester.getTopLeft(find.byType(CruxDivider));
      // ColoredBox (not Container, which resolves to the *outer* margin
      // box and would trivially equal CruxDivider's own geometry) is the
      // innermost render object that Container's `color` actually paints,
      // so its position/size reflect the margin-adjusted visible line.
      final Offset lineLeft = tester.getTopLeft(find.byType(ColoredBox));
      expect(lineLeft.dx, dividerLeft.dx);
    });

    testWidgets('shifts the line start by the given indent, without '
        'changing its total footprint width', (WidgetTester tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(200, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_wrap(const CruxDivider(indent: 24)));

      final Offset dividerLeft = tester.getTopLeft(find.byType(CruxDivider));
      final Offset lineLeft = tester.getTopLeft(find.byType(ColoredBox));
      expect(lineLeft.dx, dividerLeft.dx + 24);

      final Size dividerSize = tester.getSize(find.byType(CruxDivider));
      expect(dividerSize.width, 200);
      final Size lineSize = tester.getSize(find.byType(ColoredBox));
      expect(lineSize.width, 200 - 24);
    });
  });
}
