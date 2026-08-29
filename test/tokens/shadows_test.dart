// Pins the fixed values of CruxShadows (the shadow/scrim token layer) so
// accidental changes are caught by CI rather than discovered in a shipped
// app. Expected values are literals, not recomputed from lib/'s own
// formulas, so this stays a ground-truth check independent of however the
// package happens to compute things.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('CruxShadows.light', () {
    test('contact is the two-layer contact-shadow stack', () {
      expect(CruxShadows.light.contact, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.04),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
        BoxShadow(color: Color.fromRGBO(38, 37, 30, 0.05), spreadRadius: 1),
      ]);
    });

    test('scrim is the mock light --scrim-color (ink at 0.32 opacity)', () {
      expect(CruxShadows.light.scrim, const Color.fromRGBO(38, 37, 30, 0.32));
    });

    test('hairline is fully transparent (mock light --toast-border: none)', () {
      expect(CruxShadows.light.hairline.a, 0.0);
    });

    test('ink is the opaque shadow-ink base color (rgb 38, 37, 30)', () {
      expect(CruxShadows.light.ink, const Color(0xFF26251E));
    });
  });

  group('CruxShadows.dark', () {
    test('contact is the two-layer contact-shadow stack', () {
      expect(CruxShadows.dark.contact, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.14),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), spreadRadius: 1),
      ]);
    });

    test('scrim is the mock dark --scrim-color (opaque black at 0.55)', () {
      expect(CruxShadows.dark.scrim, const Color.fromRGBO(0, 0, 0, 0.55));
    });

    test('hairline is the mock dark --toast-border '
        '(textPrimary at 0.10 opacity)', () {
      expect(
        CruxShadows.dark.hairline,
        const Color.fromRGBO(246, 245, 239, 0.10),
      );
    });

    test('ink is opaque black (rgb 0, 0, 0)', () {
      expect(CruxShadows.dark.ink, const Color(0xFF000000));
    });

    test('differs from light in every field', () {
      expect(
        CruxShadows.dark.contact,
        isNot(equals(CruxShadows.light.contact)),
      );
      expect(CruxShadows.dark.scrim, isNot(equals(CruxShadows.light.scrim)));
      expect(
        CruxShadows.dark.hairline,
        isNot(equals(CruxShadows.light.hairline)),
      );
      expect(CruxShadows.dark.ink, isNot(equals(CruxShadows.light.ink)));
    });
  });

  group('single top-down light source', () {
    for (final CruxShadows palette in <CruxShadows>[
      CruxShadows.light,
      CruxShadows.dark,
    ]) {
      final String label = identical(palette, CruxShadows.light)
          ? 'light'
          : 'dark';

      test('$label: every contact layer throws straight down, never '
          'sideways or upward', () {
        for (final BoxShadow layer in palette.contact) {
          expect(layer.offset.dx, 0);
          expect(layer.offset.dy, greaterThanOrEqualTo(0));
        }
      });
    }
  });

  group('CruxThemeData integration', () {
    test('light() resolves shadows to CruxShadows.light', () {
      expect(CruxThemeData.light().shadows, CruxShadows.light);
    });

    test('dark() resolves shadows to CruxShadows.dark', () {
      expect(CruxThemeData.dark().shadows, CruxShadows.dark);
    });

    test('two CruxThemeData with identical fields including shadows are '
        'equal (value equality, not just identity)', () {
      final CruxThemeData a = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
        shadows: CruxShadows.light,
      );
      final CruxThemeData b = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
        shadows: CruxShadows.light,
      );

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two CruxThemeData differing only in shadows are not equal and '
        'have different hashCodes (regression: theme.dart hand-writes == '
        'and hashCode by enumerating every field, so a new field is '
        'silently ignored by both unless it is added there too)', () {
      final CruxThemeData a = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
        shadows: CruxShadows.light,
      );
      final CruxThemeData b = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
        shadows: CruxShadows.dark,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test(
      'CruxTheme.updateShouldNotify reacts to a shadows-only difference',
      () {
        final CruxTheme oldWidget = CruxTheme(
          data: CruxThemeData(
            colors: CruxColors.light,
            typography: const CruxTypography(),
            brightness: Brightness.light,
            shadows: CruxShadows.light,
          ),
          child: const SizedBox.shrink(),
        );
        final CruxTheme newWidget = CruxTheme(
          data: CruxThemeData(
            colors: CruxColors.light,
            typography: const CruxTypography(),
            brightness: Brightness.light,
            shadows: CruxShadows.dark,
          ),
          child: const SizedBox.shrink(),
        );

        expect(newWidget.updateShouldNotify(oldWidget), isTrue);
      },
    );

    test('two CruxThemeData differing only in shadows.contact are not equal '
        'and have different hashCodes (regression: confirms contact is '
        'actually enumerated by theme.dart\'s == and hashCode, not '
        'silently ignored the way an unlisted field would be)', () {
      final CruxShadows lightWithDifferentContact = CruxShadows(
        contact: CruxShadows.dark.contact,
        scrim: CruxShadows.light.scrim,
        hairline: CruxShadows.light.hairline,
        ink: CruxShadows.light.ink,
      );
      final CruxThemeData a = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
        shadows: CruxShadows.light,
      );
      final CruxThemeData b = CruxThemeData(
        colors: CruxColors.light,
        typography: const CruxTypography(),
        brightness: Brightness.light,
        shadows: lightWithDifferentContact,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
