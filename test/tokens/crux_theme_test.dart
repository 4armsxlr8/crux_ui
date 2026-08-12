// Theme resolution behavior for CruxTheme / CruxThemeData.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('CruxTheme.of', () {
    testWidgets('returns the CruxThemeData provided by the nearest CruxTheme', (
      WidgetTester tester,
    ) async {
      final CruxThemeData provided = CruxThemeData.dark();
      late CruxThemeData resolved;

      await tester.pumpWidget(
        CruxTheme(
          data: provided,
          child: Builder(
            builder: (BuildContext context) {
              resolved = CruxTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(provided));
    });

    testWidgets(
      'falls back to CruxThemeData.light() when no CruxTheme is an ancestor',
      (WidgetTester tester) async {
        late CruxThemeData resolved;

        await tester.pumpWidget(
          Builder(
            builder: (BuildContext context) {
              resolved = CruxTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        );

        expect(resolved.brightness, Brightness.light);
        expect(resolved.colors.background, CruxColors.light.background);
      },
    );
  });

  group('CruxTheme.updateShouldNotify', () {
    test(
      'does not notify when the same CruxThemeData instance is passed again',
      () {
        final CruxThemeData data = CruxThemeData.light();
        final CruxTheme oldWidget = CruxTheme(
          data: data,
          child: const SizedBox.shrink(),
        );
        final CruxTheme newWidget = CruxTheme(
          data: data,
          child: const SizedBox.shrink(),
        );

        expect(newWidget.updateShouldNotify(oldWidget), isFalse);
      },
    );

    test('does not notify when a different-instance CruxThemeData with '
        'equal values is passed', () {
      // Built without `const` so these are two distinct object instances
      // (not canonicalized to the same one), letting this test actually
      // exercise CruxThemeData's value-based `==` rather than
      // `identical`, unlike the "same instance" case above.
      final CruxThemeData oldData = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
      );
      final CruxThemeData newData = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
      );

      // Guard the premise: if this ever failed, the assertions below
      // would silently collapse into the "same instance" case instead of
      // testing value equality.
      expect(identical(oldData, newData), isFalse);
      expect(oldData, equals(newData));

      final CruxTheme oldWidget = CruxTheme(
        data: oldData,
        child: const SizedBox.shrink(),
      );
      final CruxTheme newWidget = CruxTheme(
        data: newData,
        child: const SizedBox.shrink(),
      );

      expect(newWidget.updateShouldNotify(oldWidget), isFalse);
    });

    test('notifies when replaced with a different-value CruxThemeData', () {
      final CruxTheme oldWidget = CruxTheme(
        data: CruxThemeData.light(),
        child: const SizedBox.shrink(),
      );
      final CruxTheme newWidget = CruxTheme(
        data: CruxThemeData.dark(),
        child: const SizedBox.shrink(),
      );

      expect(newWidget.updateShouldNotify(oldWidget), isTrue);
    });
  });

  group('CruxThemeData equality', () {
    test('two instances differing only in typography.platform are not equal '
        'and have different hashCodes (a theme pinned to one platform resolves '
        'to a different type scale, so a subtree given the other one must '
        'rebuild)', () {
      const CruxThemeData apple = CruxThemeData(
        colors: CruxColors.light,
        typography: CruxTypography(platform: TargetPlatform.iOS),
        brightness: Brightness.light,
      );
      const CruxThemeData material = CruxThemeData(
        colors: CruxColors.light,
        typography: CruxTypography(platform: TargetPlatform.android),
        brightness: Brightness.light,
      );

      expect(apple, isNot(equals(material)));
      expect(apple.hashCode, isNot(equals(material.hashCode)));
    });

    test('two instances differing only in colors.controlFill are not equal '
        'and have different hashCodes (regression: theme.dart hand-writes '
        '== and hashCode by enumerating every CruxColors field, so a new '
        'field is silently ignored by both unless it is added there too)', () {
      final CruxThemeData a = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
      );
      final CruxThemeData b = CruxThemeData(
        colors: CruxColors(
          background: CruxColors.light.background,
          surface: CruxColors.light.surface,
          accent: CruxColors.light.accent,
          accentTint: CruxColors.light.accentTint,
          accentLine: CruxColors.light.accentLine,
          textPrimary: CruxColors.light.textPrimary,
          textSecondary: CruxColors.light.textSecondary,
          muted: CruxColors.light.muted,
          separator: CruxColors.light.separator,
          success: CruxColors.light.success,
          error: CruxColors.light.error,
          controlFill: Color(0xFF000000),
        ),
        typography: const CruxTypography(),
        brightness: Brightness.light,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
