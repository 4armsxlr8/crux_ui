// Pins the fixed values of CruxSpacing and CruxTypography so accidental
// changes to the design tokens are caught by CI rather than discovered in a
// shipped app. Height ratios are written as the same integer-division
// expression used in lib/ (e.g. `36 / 28`) rather than a hand-computed
// decimal literal, so rounding never causes a spurious mismatch.
import 'package:flutter/foundation.dart' show TargetPlatform;
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

  group('CruxTypography on Apple platforms', () {
    const CruxTypography typography = CruxTypography(
      platform: TargetPlatform.iOS,
    );

    void expectApple(
      TextStyle style, {
      required double fontSize,
      required FontWeight weight,
      required double letterSpacing,
      required String family,
    }) {
      expect(style.fontSize, fontSize);
      expect(style.fontWeight, weight);
      expect(style.letterSpacing, letterSpacing);
      expect(style.fontFamily, family);
      expect(
        style.height,
        isNull,
        reason: 'HIG leaves line height to the font metrics',
      );
    }

    test('heading is HIG Title 1 Emphasized', () {
      expectApple(
        typography.heading,
        fontSize: 28,
        weight: FontWeight.w700,
        letterSpacing: 0.36,
        family: 'CupertinoSystemDisplay',
      );
    });

    test('subheading is HIG Title 2 Emphasized', () {
      expectApple(
        typography.subheading,
        fontSize: 22,
        weight: FontWeight.w700,
        letterSpacing: 0.35,
        family: 'CupertinoSystemDisplay',
      );
    });

    test('title is HIG Headline', () {
      expectApple(
        typography.title,
        fontSize: 17,
        weight: FontWeight.w600,
        letterSpacing: -0.41,
        family: 'CupertinoSystemText',
      );
    });

    test('body is HIG Body', () {
      expectApple(
        typography.body,
        fontSize: 17,
        weight: FontWeight.w400,
        letterSpacing: -0.41,
        family: 'CupertinoSystemText',
      );
    });

    test('caption is HIG Caption 1', () {
      expectApple(
        typography.caption,
        fontSize: 12,
        weight: FontWeight.w400,
        letterSpacing: 0,
        family: 'CupertinoSystemText',
      );
    });

    test('captionStrong is HIG Caption 1 Emphasized', () {
      expectApple(
        typography.captionStrong,
        fontSize: 12,
        weight: FontWeight.w600,
        letterSpacing: 0,
        family: 'CupertinoSystemText',
      );
    });

    test('labelSmall is HIG Footnote Emphasized', () {
      expectApple(
        typography.labelSmall,
        fontSize: 13,
        weight: FontWeight.w600,
        letterSpacing: -0.08,
        family: 'CupertinoSystemText',
      );
    });

    test('label is HIG Subheadline Emphasized', () {
      expectApple(
        typography.label,
        fontSize: 15,
        weight: FontWeight.w600,
        letterSpacing: -0.24,
        family: 'CupertinoSystemText',
      );
    });

    test('navLabel is HIG Caption 2 Emphasized', () {
      expectApple(
        typography.navLabel,
        fontSize: 11,
        weight: FontWeight.w600,
        letterSpacing: 0.07,
        family: 'CupertinoSystemText',
      );
    });

    test('macOS resolves to the same tier as iOS', () {
      const CruxTypography mac = CruxTypography(platform: TargetPlatform.macOS);
      expect(mac.body.fontSize, typography.body.fontSize);
      expect(mac.body.fontFamily, typography.body.fontFamily);
    });
  });

  group('CruxTypography on non-Apple platforms', () {
    const CruxTypography typography = CruxTypography(
      platform: TargetPlatform.android,
    );

    void expectMaterial(
      TextStyle style, {
      required double fontSize,
      required FontWeight weight,
      required double letterSpacing,
      required double height,
    }) {
      expect(style.fontSize, fontSize);
      expect(style.fontWeight, weight);
      expect(style.letterSpacing, letterSpacing);
      expect(style.height, height);
      expect(
        style.fontFamily,
        isNull,
        reason: 'the Material tier leaves the family to the platform default',
      );
      expect(
        style.leadingDistribution,
        TextLeadingDistribution.even,
        reason: 'dropping it shifts text inside fixed-height controls',
      );
    }

    test('heading is Material headlineMedium', () {
      expectMaterial(
        typography.heading,
        fontSize: 28,
        weight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
      );
    });

    test('subheading is Material titleLarge', () {
      expectMaterial(
        typography.subheading,
        fontSize: 22,
        weight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.27,
      );
    });

    test('title is Material titleMedium', () {
      expectMaterial(
        typography.title,
        fontSize: 16,
        weight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.50,
      );
    });

    test('body is Material bodyLarge', () {
      expectMaterial(
        typography.body,
        fontSize: 16,
        weight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.50,
      );
    });

    test('caption is Material bodySmall', () {
      expectMaterial(
        typography.caption,
        fontSize: 12,
        weight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      );
    });

    test('captionStrong is Material labelMedium', () {
      expectMaterial(
        typography.captionStrong,
        fontSize: 12,
        weight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      );
    });

    test('labelSmall and label both resolve to Material labelLarge', () {
      expectMaterial(
        typography.labelSmall,
        fontSize: 14,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      );
      expectMaterial(
        typography.label,
        fontSize: 14,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      );
    });

    test('navLabel is Material labelSmall', () {
      expectMaterial(
        typography.navLabel,
        fontSize: 11,
        weight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
      );
    });
  });

  group('CruxTypography.fontFamily', () {
    test('overrides the family on both tiers', () {
      const CruxTypography apple = CruxTypography(
        platform: TargetPlatform.iOS,
        fontFamily: 'Custom',
      );
      const CruxTypography material = CruxTypography(
        platform: TargetPlatform.android,
        fontFamily: 'Custom',
      );
      expect(apple.body.fontFamily, 'Custom');
      expect(apple.heading.fontFamily, 'Custom');
      expect(material.body.fontFamily, 'Custom');
      expect(material.heading.fontFamily, 'Custom');
    });
  });

  group('CruxRadii', () {
    test('matches the fixed corner-radius scale', () {
      expect(CruxRadii.m, 14.0);
      expect(CruxRadii.l, 16.0);
      expect(CruxRadii.pill, 9999.0);
    });
  });

  group('CruxMotion', () {
    test('pressedScaleSubtle is 0.98, distinct from pressedScale', () {
      expect(CruxMotion.pressedScaleSubtle, 0.98);
      expect(CruxMotion.pressedScale, 0.96);
    });
  });
}
