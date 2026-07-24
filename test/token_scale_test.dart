// Pins the fixed values of CruxSpacing and CruxTypography so accidental
// changes to the design tokens are caught by CI rather than discovered in a
// shipped app. Height ratios are written as the same integer-division
// expression used in lib/ (e.g. `36 / 28`) rather than a hand-computed
// decimal literal, so rounding never causes a spurious mismatch.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('CruxSpacing', () {
    test('matches the fixed 4px-based scale', () {
      expect(CruxSpacing.s2, 2.0);
      expect(CruxSpacing.s4, 4.0);
      expect(CruxSpacing.s8, 8.0);
      expect(CruxSpacing.s12, 12.0);
      expect(CruxSpacing.s16, 16.0);
      expect(CruxSpacing.s20, 20.0);
      expect(CruxSpacing.s24, 24.0);
      expect(CruxSpacing.s32, 32.0);
      expect(CruxSpacing.s40, 40.0);
      expect(CruxSpacing.s48, 48.0);
    });
  });

  group('CruxTypography', () {
    const CruxTypography typography = CruxTypography();

    void expectStyle(
      TextStyle style, {
      required double fontSize,
      required double height,
      required FontWeight weight,
    }) {
      expect(style.fontSize, fontSize);
      expect(style.height, height);
      expect(style.fontWeight, weight);
    }

    test('display is 28/36, weight 700', () {
      expectStyle(
        typography.display,
        fontSize: 28,
        height: 36 / 28,
        weight: FontWeight.w700,
      );
    });

    test('headline is 22/30, weight 700', () {
      expectStyle(
        typography.headline,
        fontSize: 22,
        height: 30 / 22,
        weight: FontWeight.w700,
      );
    });

    test('title is 17/24, weight 600', () {
      expectStyle(
        typography.title,
        fontSize: 17,
        height: 24 / 17,
        weight: FontWeight.w600,
      );
    });

    test('body is 16/25, weight 400', () {
      expectStyle(
        typography.body,
        fontSize: 16,
        height: 25 / 16,
        weight: FontWeight.w400,
      );
    });

    test('label is 14/20, weight 600', () {
      expectStyle(
        typography.label,
        fontSize: 14,
        height: 20 / 14,
        weight: FontWeight.w600,
      );
    });

    test('caption is 12/17, weight 400', () {
      expectStyle(
        typography.caption,
        fontSize: 12,
        height: 17 / 12,
        weight: FontWeight.w400,
      );
    });
  });
}
