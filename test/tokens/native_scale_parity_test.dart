// Guards the provenance of CruxTypography's values.
//
// The two tiers are transcribed, not read at run time: the Apple tier from
// the cupertino_typography package (a dev dependency only), the Material tier
// from Flutter's own Typography.englishLike2021. That transcription can drift
// when either source updates, and nothing else would notice — token_scale_test
// pins crux's own numbers, which is exactly what would silently stop
// matching the platform.
//
// Whole-TextStyle equality cannot be used: crux deliberately drops the
// color, keeps `inherit` at its default, and (on the Apple tier) leaves the
// line height unset. Only the metrics that define the scale are compared.
import 'package:cupertino_typography/cupertino_typography.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/material.dart' show TextTheme, Typography;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('Apple tier matches cupertino_typography', () {
    const CruxTypography typography = CruxTypography(
      platform: TargetPlatform.iOS,
    );

    void expectMatches(TextStyle actual, TextStyle source) {
      expect(actual.fontSize, source.fontSize);
      expect(actual.fontWeight, source.fontWeight);
      expect(actual.letterSpacing, source.letterSpacing);
      expect(actual.fontFamily, source.fontFamily);
    }

    test('heading matches title1Emphasized', () {
      expectMatches(typography.heading, CupertinoTypography.title1Emphasized);
    });

    test('subheading matches title2Emphasized', () {
      expectMatches(
        typography.subheading,
        CupertinoTypography.title2Emphasized,
      );
    });

    test('title matches headline', () {
      expectMatches(typography.title, CupertinoTypography.headline);
    });

    test('body matches body', () {
      expectMatches(typography.body, CupertinoTypography.body);
    });

    test('caption matches caption1', () {
      expectMatches(typography.caption, CupertinoTypography.caption1);
    });

    test('captionStrong matches caption1Emphasized', () {
      expectMatches(
        typography.captionStrong,
        CupertinoTypography.caption1Emphasized,
      );
    });

    test('labelSmall matches footnoteEmphasized', () {
      expectMatches(
        typography.labelSmall,
        CupertinoTypography.footnoteEmphasized,
      );
    });

    test('label matches subheadlineEmphasized', () {
      expectMatches(
        typography.label,
        CupertinoTypography.subheadlineEmphasized,
      );
    });

    test('navLabel matches caption2Emphasized', () {
      expectMatches(
        typography.navLabel,
        CupertinoTypography.caption2Emphasized,
      );
    });
  });

  group('Material tier matches Typography.englishLike2021', () {
    const CruxTypography typography = CruxTypography(
      platform: TargetPlatform.android,
    );
    final TextTheme material = Typography.englishLike2021;

    void expectMatches(TextStyle actual, TextStyle? source) {
      expect(source, isNotNull);
      expect(actual.fontSize, source!.fontSize);
      expect(actual.fontWeight, source.fontWeight);
      expect(actual.letterSpacing, source.letterSpacing);
      expect(actual.height, source.height);
      expect(actual.leadingDistribution, source.leadingDistribution);
    }

    test('heading matches headlineMedium', () {
      expectMatches(typography.heading, material.headlineMedium);
    });

    test('subheading matches titleLarge', () {
      expectMatches(typography.subheading, material.titleLarge);
    });

    test('title matches titleMedium', () {
      expectMatches(typography.title, material.titleMedium);
    });

    test('body matches bodyLarge', () {
      expectMatches(typography.body, material.bodyLarge);
    });

    test('caption matches bodySmall', () {
      expectMatches(typography.caption, material.bodySmall);
    });

    test('captionStrong matches labelMedium', () {
      expectMatches(typography.captionStrong, material.labelMedium);
    });

    test('labelSmall and label both match labelLarge', () {
      expectMatches(typography.labelSmall, material.labelLarge);
      expectMatches(typography.label, material.labelLarge);
    });

    test('navLabel matches labelSmall', () {
      expectMatches(typography.navLabel, material.labelSmall);
    });
  });
}
