// Contrast ratio safety net for Crux color tokens.
//
// This test implements the WCAG 2.x relative luminance / contrast ratio
// formulas itself (deliberately not imported from lib/), so it stays a
// ground-truth check that is independent of however the package happens to
// compute things. It exists so that swapping the (currently provisional)
// color values for a future palette cannot silently break legibility.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Converts a single 0-255 sRGB channel to linearized (linear-light) form,
/// per the WCAG definition of relative luminance.
double _linearize(double channel255) {
  final double c = channel255 / 255;
  if (c <= 0.03928) {
    return c / 12.92;
  }
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Relative luminance of an opaque sRGB color, per WCAG.
double _relativeLuminance(Color color) {
  final double r = _linearize(color.r * 255);
  final double g = _linearize(color.g * 255);
  final double b = _linearize(color.b * 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// WCAG contrast ratio between two opaque colors (order-independent).
double _contrastRatio(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Alpha-composites [foreground] over the opaque [background], returning
/// the opaque color that would actually be visible on screen. This must
/// happen *before* computing contrast for any semi-transparent (rgba)
/// token, otherwise the contrast math is meaningless.
Color _compositeOver(Color foreground, Color background) {
  final double alpha = foreground.a;
  double mix(double fg, double bg) => fg * alpha + bg * (1 - alpha);
  return Color.from(
    alpha: 1,
    red: mix(foreground.r, background.r),
    green: mix(foreground.g, background.g),
    blue: mix(foreground.b, background.b),
  );
}

void main() {
  group('contrast ratio (WCAG)', () {
    test('light textPrimary vs background/surface is at least 4.5', () {
      const CruxColors c = CruxColors.light;
      expect(
        _contrastRatio(c.textPrimary, c.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(c.textPrimary, c.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark textPrimary vs background/surface is at least 4.5', () {
      const CruxColors c = CruxColors.dark;
      expect(
        _contrastRatio(c.textPrimary, c.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(c.textPrimary, c.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light textSecondary vs background is at least 3.0', () {
      const CruxColors c = CruxColors.light;
      // textSecondary is opaque in light mode, so no compositing is needed.
      expect(
        _contrastRatio(c.textSecondary, c.background),
        greaterThanOrEqualTo(3.0),
      );
    });

    test(
      'dark textSecondary vs background is at least 3.0 after alpha compositing',
      () {
        const CruxColors c = CruxColors.dark;
        // textSecondary is semi-transparent (rgba) in dark mode: composite it
        // over the background first so the ratio reflects what is actually
        // visible on screen, not the raw (misleadingly dim) rgba value.
        final Color effective = _compositeOver(c.textSecondary, c.background);
        expect(
          _contrastRatio(effective, c.background),
          greaterThanOrEqualTo(3.0),
        );
      },
    );

    test('light and dark onAccent vs accent is at least 4.5', () {
      // onAccent is the filled CruxButton's label color: it must stay
      // legible against the accent fill it sits on, in both palettes (it is
      // fixed to the same value in both, but accent could diverge later).
      expect(
        _contrastRatio(CruxColors.light.onAccent, CruxColors.light.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(CruxColors.dark.onAccent, CruxColors.dark.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'filled CruxButton pressed-state background vs onAccent stays at '
      'least 4.5 (light and dark)',
      (WidgetTester tester) async {
        // Composited-state regression guard: CruxButton's pressed-state
        // state layer darkens/lightens the filled variant's background
        // toward CruxColors.textPrimary, but its label color
        // (CruxColors.onAccent) never changes while pressed. Because
        // onAccent and textPrimary happen to be the exact same value in
        // both palettes, an overlay that is too strong pulls the pressed
        // background straight toward the label color and can silently push
        // contrast under the AA floor even though the unpressed state is
        // fine. This reads the actual rendered pressed background off a
        // real CruxButton (not a hardcoded expectation of the overlay
        // opacity), so it fails if a future change to the pressed-state
        // treatment regresses this again.
        Future<double> pressedContrast(CruxThemeData theme) async {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: CruxTheme(
                data: theme,
                child: CruxButton(label: 'Go', onPressed: () {}),
              ),
            ),
          );

          final TestGesture gesture = await tester.startGesture(
            tester.getCenter(find.byType(CruxButton)),
          );
          await tester.pump();

          final Container container = tester.widget<Container>(
            find.byType(Container),
          );
          final BoxDecoration decoration =
              container.decoration! as BoxDecoration;
          final Color pressedBackground = decoration.color!;

          await gesture.up();
          await tester.pumpAndSettle();

          return _contrastRatio(theme.colors.onAccent, pressedBackground);
        }

        expect(
          await pressedContrast(CruxThemeData.light()),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          await pressedContrast(CruxThemeData.dark()),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  });
}
