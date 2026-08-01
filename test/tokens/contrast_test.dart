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

    test('light error vs background/surface is at least 4.5', () {
      const CruxColors c = CruxColors.light;
      // error is opaque in both palettes, so no compositing is needed.
      expect(_contrastRatio(c.error, c.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(c.error, c.surface), greaterThanOrEqualTo(4.5));
    });

    test('dark error vs background/surface is at least 4.5', () {
      const CruxColors c = CruxColors.dark;
      expect(_contrastRatio(c.error, c.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(c.error, c.surface), greaterThanOrEqualTo(4.5));
    });

    test('light textPrimary vs controlFill is at least 4.5', () {
      const CruxColors c = CruxColors.light;
      // controlFill is opaque in the light palette, so no compositing is
      // needed. Measured with this test's own WCAG math: ~12.52:1, far
      // above the 4.5:1 floor, leaving generous headroom for a future
      // palette swap (per colors.dart's "values are provisional" rule).
      expect(
        _contrastRatio(c.textPrimary, c.controlFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark textPrimary vs controlFill is at least 4.5', () {
      const CruxColors c = CruxColors.dark;
      // controlFill is opaque in the dark palette too. Measured: ~14.38:1.
      expect(
        _contrastRatio(c.textPrimary, c.controlFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light textSecondary vs controlFill is at least 4.5', () {
      const CruxColors c = CruxColors.light;
      // textSecondary is opaque in the light palette, so no compositing is
      // needed. This is CruxTextFormField's resting, in-box label color
      // (2026-07-25: switched from muted, whose ~3.36:1 fell short of the
      // 4.5:1 normal-text floor — see unknowns/textfield-atom/ledger.md).
      // Measured ratio: ~5.79:1.
      expect(
        _contrastRatio(c.textSecondary, c.controlFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark textSecondary vs controlFill is at least 4.5 after alpha '
        'compositing', () {
      const CruxColors c = CruxColors.dark;
      // textSecondary is semi-transparent (rgba) in dark mode, and it
      // renders on top of controlFill (the field's own fill) rather than
      // background, so composite over controlFill first — the same
      // reasoning the existing dark textSecondary-vs-background test above
      // applies to background. Measured ratio: ~5.88:1.
      final Color effective = _compositeOver(c.textSecondary, c.controlFill);
      expect(
        _contrastRatio(effective, c.controlFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light CruxChip selected-state border (accentLine) has at least '
        '3.0 non-text contrast (WCAG 1.4.11) against background/surface', () {
      const CruxColors c = CruxColors.light;
      final Color onBackground = _compositeOver(c.accentLine, c.background);
      final Color onSurface = _compositeOver(c.accentLine, c.surface);
      expect(
        _contrastRatio(onBackground, c.background),
        greaterThanOrEqualTo(3.0),
      );
      expect(_contrastRatio(onSurface, c.surface), greaterThanOrEqualTo(3.0));
    });

    test('dark CruxChip selected-state border (accentLine) has at least '
        '3.0 non-text contrast (WCAG 1.4.11) against background/surface', () {
      const CruxColors c = CruxColors.dark;
      final Color onBackground = _compositeOver(c.accentLine, c.background);
      final Color onSurface = _compositeOver(c.accentLine, c.surface);
      expect(
        _contrastRatio(onBackground, c.background),
        greaterThanOrEqualTo(3.0),
      );
      expect(_contrastRatio(onSurface, c.surface), greaterThanOrEqualTo(3.0));
    });

    test('light disabled CruxButton label (muted) vs its fill (separator) '
        'has at least 3.0 non-text contrast (WCAG 1.4.11)', () {
      const CruxColors c = CruxColors.light;
      // CruxButton's disabled state: a muted label on a separator-filled
      // pill, sitting on the page background. A disabled control is not
      // itself a WCAG target (1.4.11 explicitly excludes inactive user
      // interface components), so this is not an accessibility requirement —
      // it is a regression guard, so a future palette swap (colors.dart's
      // "values are provisional" rule) cannot quietly let this pairing
      // drift below usable contrast unnoticed. Both colors are opaque in
      // the light palette, so no compositing is needed. Measured: ~3.27:1.
      expect(_contrastRatio(c.muted, c.separator), greaterThanOrEqualTo(3.0));
    });

    test('dark disabled CruxButton label (muted) vs its fill (separator) '
        'has at least 3.0 non-text contrast (WCAG 1.4.11) after alpha '
        'compositing', () {
      const CruxColors c = CruxColors.dark;
      // Both muted and separator are semi-transparent (rgba) in the dark
      // palette, so both are composited before measuring, in the order they
      // are actually painted: the separator pill over the page background,
      // then the muted label over the pill. Measured: ~3.29:1. See the
      // light test above for why this guard exists despite disabled
      // controls being outside WCAG 1.4.11's own scope.
      final Color pill = _compositeOver(c.separator, c.background);
      final Color label = _compositeOver(c.muted, pill);
      expect(_contrastRatio(label, pill), greaterThanOrEqualTo(3.0));
    });

    test('disabled CruxInputBar submit circle (mutedFill) is actually '
        'visible against the controlFill box it sits in (light and dark)', () {
      // The regression this guards is not low contrast but *invisibility*:
      // this circle originally reused `separator`, which is nearly the same
      // color as `controlFill` (~1.03:1), so inside the bar's
      // controlFill-filled box the circle vanished entirely and only a faint
      // floating arrow remained — caught by the user reviewing the running
      // app, and the reason the `mutedFill` token exists at all (see its doc
      // in colors.dart). The 1.1 floor is deliberately below the shipped
      // values (~1.16 light / ~1.43 dark, user-approved on 2026-07-27) but
      // comfortably above the ~1.03 failure this replaces: it trips on a
      // palette swap that re-introduces the vanishing, without forbidding a
      // future palette from choosing a slightly subtler wash.
      for (final CruxColors c in <CruxColors>[
        CruxColors.light,
        CruxColors.dark,
      ]) {
        final Color circle = _compositeOver(c.mutedFill, c.controlFill);
        expect(
          _contrastRatio(circle, c.controlFill),
          greaterThanOrEqualTo(1.1),
          reason: 'the disabled submit circle must not vanish into the box',
        );
      }
    });

    test('disabled CruxInputBar submit icon (muted) vs the mutedFill '
        'circle it sits on keeps at least 2.5 contrast (light and dark)', () {
      // Painted stack: controlFill (the box) → mutedFill (the circle) →
      // muted (the icon), so both translucent layers are composited in that
      // order before measuring. Disabled controls are exempt from WCAG's
      // own contrast minima (1.4.11 excludes inactive components), and the
      // user-approved look (2026-07-27, tuned live on the simulator)
      // measures ~2.90:1 light / ~3.20:1 dark — the light value sits below
      // the 3.0 floor the non-text checks above use, deliberately: making
      // the circle visible necessarily darkens the surface the icon sits
      // on, and the icon only needs to read as "a button that is off". The
      // 2.5 floor is a drift guard for that approved look, not an
      // accessibility claim.
      for (final CruxColors c in <CruxColors>[
        CruxColors.light,
        CruxColors.dark,
      ]) {
        final Color circle = _compositeOver(c.mutedFill, c.controlFill);
        final Color icon = _compositeOver(c.muted, circle);
        expect(
          _contrastRatio(icon, circle),
          greaterThanOrEqualTo(2.5),
          reason: 'the disabled submit icon must stay legible on its circle',
        );
      }
    });

    test('light and dark CruxCheckbox unchecked outline (muted) has at '
        'least 3.0 non-text contrast (WCAG 1.4.11) against background and '
        'controlFill', () {
      // checkbox.dart's `_resolveFillColor` doc records why this outline
      // uses CruxColors.muted rather than the plan's first-candidate
      // CruxColors.accentLine: accentLine measures only ~2.90:1 against
      // controlFill in the light palette, below this 3.0 floor, while muted
      // clears it in both palettes against both backdrops it can appear on
      // (a bare checkbox on the page background, or one sitting inside a
      // controlFill-filled surface such as a form). Measured with this
      // test's own WCAG math: light ~3.84:1 (background) / ~3.36:1
      // (controlFill); dark ~3.95:1 (background) / ~3.79:1 (controlFill),
      // the dark values composited first since CruxColors.muted is
      // semi-transparent (rgba) in the dark palette.
      for (final CruxColors c in <CruxColors>[
        CruxColors.light,
        CruxColors.dark,
      ]) {
        final Color onBackground = _compositeOver(c.muted, c.background);
        final Color onControlFill = _compositeOver(c.muted, c.controlFill);
        expect(
          _contrastRatio(onBackground, c.background),
          greaterThanOrEqualTo(3.0),
        );
        expect(
          _contrastRatio(onControlFill, c.controlFill),
          greaterThanOrEqualTo(3.0),
        );
      }
    });

    test('CruxSpinner default color (accent) vs controlFill: dark clears '
        'the 3.0 non-text contrast guideline, light falls short', () {
      // CruxSpinner defaults to CruxColors.accent (plans/atoms-batch-2.md
      // "色は accent"). Measured with this test's own WCAG math: dark
      // ~4.99:1, comfortably above WCAG 1.4.11's 3.0 non-text floor. Light
      // measures only ~2.56:1 -- below that floor -- which is not a new
      // problem this spinner introduces: colors.dart's own accentTint doc
      // already records that accent's hue sits too close to background's
      // luminance to clear 3:1 even fully opaque in the light palette. This
      // is flagged as an issue for user judgment (a spinner rendered
      // standalone against controlFill in light mode is harder to make out
      // than the plan's wording implies) rather than silently forced green;
      // see this task's structured-output notes for the recorded issue.
      expect(
        _contrastRatio(
          CruxColors.light.accent,
          CruxColors.light.controlFill,
        ),
        greaterThanOrEqualTo(2.5),
      );
      expect(
        _contrastRatio(CruxColors.dark.accent, CruxColors.dark.controlFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('CruxIconButton neutral-tone mutedFill circle is actually '
        'visible against the page background (light and dark)', () {
      // Mirrors the existing "disabled CruxInputBar submit circle" guard
      // above: the regression this catches is invisibility, not merely low
      // contrast, so it uses the same 1.1 floor rather than the 3.0 WCAG
      // non-text guideline (mutedFill is a deliberately subtle wash, not a
      // state-identifying border -- see its own doc in colors.dart).
      // Measured with this test's own WCAG math: light ~1.16:1, dark
      // ~1.37:1, both comfortably above the 1.1 floor.
      for (final CruxColors c in <CruxColors>[
        CruxColors.light,
        CruxColors.dark,
      ]) {
        final Color circle = _compositeOver(c.mutedFill, c.background);
        expect(
          _contrastRatio(circle, c.background),
          greaterThanOrEqualTo(1.1),
          reason:
              'the neutral icon button circle must not vanish into the '
              'page background',
        );
      }
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
          final ShapeDecoration decoration =
              container.decoration! as ShapeDecoration;
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
