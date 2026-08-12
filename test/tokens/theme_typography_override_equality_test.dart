// Equality/hashCode coverage for CruxTypography's token overrides, seen
// through CruxThemeData.
//
// This lives in its own file rather than inside crux_theme_test.dart's
// existing "CruxThemeData equality" group, which already holds the equivalent
// test for typography.platform: crux_theme_test.dart is out of scope for the
// change that adds token overrides, so this mirrors that test's shape here
// instead of editing it — the same arrangement
// theme_control_plate_equality_test.dart and theme_muted_fill_equality_test.dart
// already use.
//
// What is at stake: CruxTheme.updateShouldNotify compares two CruxThemeData
// values, so an override difference that == cannot see would leave a subtree
// rendering the old type scale after the theme is swapped.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('CruxThemeData equality with typography overrides', () {
    test('two themes differing only in a typography token override are not '
        'equal and have different hashCodes (regression: theme.dart compares '
        'typography field by field, so an override slot it does not enumerate '
        'is silently invisible to both == and hashCode)', () {
      const CruxThemeData plain = CruxThemeData(
        colors: CruxColors.light,
        typography: CruxTypography(platform: TargetPlatform.iOS),
        brightness: Brightness.light,
      );
      const CruxThemeData overridden = CruxThemeData(
        colors: CruxColors.light,
        typography: CruxTypography(
          platform: TargetPlatform.iOS,
          body: TextStyle(fontSize: 15),
        ),
        brightness: Brightness.light,
      );

      expect(plain, isNot(equals(overridden)));
      expect(plain.hashCode, isNot(equals(overridden.hashCode)));
    });

    test('two themes carrying the same override in separate instances are '
        'equal and share a hashCode', () {
      // Built without `const` throughout — including the overriding TextStyle
      // — so nothing is canonicalised to a shared instance and the assertions
      // below exercise value equality rather than identity.
      final CruxThemeData a = CruxThemeData(
        colors: CruxColors.light,
        typography: CruxTypography(
          platform: TargetPlatform.iOS,
          body: TextStyle(fontSize: 15),
        ),
        brightness: Brightness.light,
      );
      final CruxThemeData b = CruxThemeData(
        colors: CruxColors.light,
        typography: CruxTypography(
          platform: TargetPlatform.iOS,
          body: TextStyle(fontSize: 15),
        ),
        brightness: Brightness.light,
      );

      // Guard the premise: if these were the same instance, the assertions
      // would collapse into an identity check.
      expect(identical(a, b), isFalse);
      expect(identical(a.typography, b.typography), isFalse);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
