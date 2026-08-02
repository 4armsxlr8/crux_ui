// Pins the fixed values of CruxShadows (the shadow/scrim token layer) so
// accidental changes are caught by CI rather than discovered in a shipped
// app. Expected values are literals transcribed from
// unknowns/atoms-batch-3/mock-b-shadow.html's `--shadow-*` / `--scrim-color` /
// `--toast-border` CSS variables (mock case B, "soft shadow"), not
// recomputed from lib/'s own formulas, so this stays a ground-truth check
// independent of however the package happens to compute things.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('CruxShadows.light', () {
    test('sm is the mock light --shadow-sm two-layer stack', () {
      expect(CruxShadows.light.sm, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.16),
          offset: Offset(0, 6),
          blurRadius: 14,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.10),
          offset: Offset(0, 2),
          blurRadius: 5,
          spreadRadius: -1,
        ),
      ]);
    });

    test('md is the mock light --shadow-md two-layer stack', () {
      expect(CruxShadows.light.md, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.18),
          offset: Offset(0, 14),
          blurRadius: 30,
          spreadRadius: -10,
        ),
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.10),
          offset: Offset(0, 4),
          blurRadius: 10,
          spreadRadius: -4,
        ),
      ]);
    });

    test('lg is the mock light --shadow-lg two-layer stack', () {
      expect(CruxShadows.light.lg, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.22),
          offset: Offset(0, 24),
          blurRadius: 48,
          spreadRadius: -14,
        ),
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.12),
          offset: Offset(0, 10),
          blurRadius: 20,
          spreadRadius: -10,
        ),
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

    test('thumb is the mock light .slider-thumb box-shadow three-layer '
        'stack', () {
      expect(CruxShadows.light.thumb, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.28),
          offset: Offset(0, 3),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.20),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
        BoxShadow(color: Color.fromRGBO(38, 37, 30, 0.05), spreadRadius: 1),
      ]);
    });

    test('thumbLifted is the mock light .slider-thumb.is-dragging '
        'box-shadow three-layer stack', () {
      expect(CruxShadows.light.thumbLifted, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.30),
          offset: Offset(0, 6),
          blurRadius: 16,
        ),
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.22),
          offset: Offset(0, 2),
          blurRadius: 6,
        ),
        BoxShadow(color: Color.fromRGBO(38, 37, 30, 0.05), spreadRadius: 1),
      ]);
    });
  });

  group('CruxShadows.dark', () {
    test('sm is the mock dark --shadow-sm two-layer stack', () {
      expect(CruxShadows.dark.sm, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.5),
          offset: Offset(0, 6),
          blurRadius: 14,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.35),
          offset: Offset(0, 2),
          blurRadius: 6,
          spreadRadius: -1,
        ),
      ]);
    });

    test('md is the mock dark --shadow-md two-layer stack', () {
      expect(CruxShadows.dark.md, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.5),
          offset: Offset(0, 14),
          blurRadius: 30,
          spreadRadius: -10,
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.35),
          offset: Offset(0, 4),
          blurRadius: 12,
          spreadRadius: -4,
        ),
      ]);
    });

    test('lg is the mock dark --shadow-lg two-layer stack', () {
      expect(CruxShadows.dark.lg, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.55),
          offset: Offset(0, 24),
          blurRadius: 48,
          spreadRadius: -14,
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.4),
          offset: Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -10,
        ),
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

    test('thumb is the mock dark .slider-thumb box-shadow three-layer '
        'stack (--shadow-ink substituted for dark)', () {
      expect(CruxShadows.dark.thumb, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.28),
          offset: Offset(0, 3),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.20),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), spreadRadius: 1),
      ]);
    });

    test('thumbLifted is the mock dark .slider-thumb.is-dragging '
        'box-shadow three-layer stack (--shadow-ink substituted for dark)', () {
      expect(CruxShadows.dark.thumbLifted, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.30),
          offset: Offset(0, 6),
          blurRadius: 16,
        ),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.22),
          offset: Offset(0, 2),
          blurRadius: 6,
        ),
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), spreadRadius: 1),
      ]);
    });

    test('differs from light in every field', () {
      expect(CruxShadows.dark.sm, isNot(equals(CruxShadows.light.sm)));
      expect(CruxShadows.dark.md, isNot(equals(CruxShadows.light.md)));
      expect(CruxShadows.dark.lg, isNot(equals(CruxShadows.light.lg)));
      expect(
        CruxShadows.dark.scrim,
        isNot(equals(CruxShadows.light.scrim)),
      );
      expect(
        CruxShadows.dark.hairline,
        isNot(equals(CruxShadows.light.hairline)),
      );
      expect(CruxShadows.dark.ink, isNot(equals(CruxShadows.light.ink)));
    });
  });

  group('shadow depth ordering', () {
    for (final CruxShadows palette in <CruxShadows>[
      CruxShadows.light,
      CruxShadows.dark,
    ]) {
      final String label = identical(palette, CruxShadows.light)
          ? 'light'
          : 'dark';

      test('$label: blurRadius increases sm -> md -> lg in both layers', () {
        expect(palette.sm[0].blurRadius, lessThan(palette.md[0].blurRadius));
        expect(palette.md[0].blurRadius, lessThan(palette.lg[0].blurRadius));
        expect(palette.sm[1].blurRadius, lessThan(palette.md[1].blurRadius));
        expect(palette.md[1].blurRadius, lessThan(palette.lg[1].blurRadius));
      });
    }
  });

  group('CruxShadows.thumb / thumbLifted', () {
    for (final CruxShadows palette in <CruxShadows>[
      CruxShadows.light,
      CruxShadows.dark,
    ]) {
      final String label = identical(palette, CruxShadows.light)
          ? 'light'
          : 'dark';

      test('$label: thumbLifted reads as further off the surface than thumb '
          '-- larger offset and blur on both non-outline layers, per the '
          'confirmed spec\'s "ドラッグ中はさらに浮く"', () {
        expect(
          palette.thumb[0].blurRadius,
          lessThan(palette.thumbLifted[0].blurRadius),
        );
        expect(
          palette.thumb[0].offset.dy,
          lessThan(palette.thumbLifted[0].offset.dy),
        );
        expect(
          palette.thumb[1].blurRadius,
          lessThan(palette.thumbLifted[1].blurRadius),
        );
        expect(
          palette.thumb[1].offset.dy,
          lessThan(palette.thumbLifted[1].offset.dy),
        );
      });

      test('$label: thumb and thumbLifted share the same 1px ambient-outline '
          'third layer (zero offset, zero blur, 1px spread)', () {
        for (final List<BoxShadow> stack in <List<BoxShadow>>[
          palette.thumb,
          palette.thumbLifted,
        ]) {
          expect(stack[2].offset, Offset.zero);
          expect(stack[2].blurRadius, 0);
          expect(stack[2].spreadRadius, 1);
        }
      });
    }

    test('dark.thumb differs from light.thumb', () {
      expect(
        CruxShadows.dark.thumb,
        isNot(equals(CruxShadows.light.thumb)),
      );
    });

    test('dark.thumbLifted differs from light.thumbLifted', () {
      expect(
        CruxShadows.dark.thumbLifted,
        isNot(equals(CruxShadows.light.thumbLifted)),
      );
    });
  });

  group('CruxShadows.xs', () {
    test('light is the confirmed 2026-08-02 single-layer near shadow '
        '(offset (0,1), blur 3, no spread, ink at 0.10 alpha)', () {
      expect(CruxShadows.light.xs, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(38, 37, 30, 0.10),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ]);
    });

    test('dark is the same single-layer recipe washed in black at 0.30 '
        'alpha (stronger than light, per the light->dark contrast rule '
        'sm/md/lg already follow)', () {
      expect(CruxShadows.dark.xs, const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.30),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ]);
    });

    test('dark.xs differs from light.xs', () {
      expect(CruxShadows.dark.xs, isNot(equals(CruxShadows.light.xs)));
    });

    for (final CruxShadows palette in <CruxShadows>[
      CruxShadows.light,
      CruxShadows.dark,
    ]) {
      final String label = identical(palette, CruxShadows.light)
          ? 'light'
          : 'dark';

      test('$label: xs reads more subdued than sm -- a smaller offset, '
          'blur, and alpha than sm\'s dominant (thrown, index-0) layer, for '
          'a plate that should barely lift off its surface', () {
        expect(
          palette.xs[0].offset.dy,
          lessThan(palette.sm[0].offset.dy),
          reason: 'xs offset should be nearer than sm\'s dominant layer',
        );
        expect(
          palette.xs[0].blurRadius,
          lessThan(palette.sm[0].blurRadius),
          reason: 'xs blur should be tighter than sm\'s dominant layer',
        );
        expect(
          palette.xs[0].color.a,
          lessThan(palette.sm[0].color.a),
          reason: 'xs alpha should be lower than sm\'s dominant layer',
        );
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

    test('two CruxThemeData differing only in shadows.thumb are not equal '
        'and have different hashCodes (regression: confirms thumb -- added '
        'for the CruxSlider thumb-shadow fix -- is actually enumerated by '
        'theme.dart\'s == and hashCode, not silently ignored the way an '
        'unlisted field would be)', () {
      final CruxShadows lightWithDifferentThumb = CruxShadows(
        sm: CruxShadows.light.sm,
        md: CruxShadows.light.md,
        lg: CruxShadows.light.lg,
        scrim: CruxShadows.light.scrim,
        hairline: CruxShadows.light.hairline,
        ink: CruxShadows.light.ink,
        thumb: CruxShadows.dark.thumb,
        thumbLifted: CruxShadows.light.thumbLifted,
        xs: CruxShadows.light.xs,
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
        shadows: lightWithDifferentThumb,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('two CruxThemeData differing only in shadows.thumbLifted are not '
        'equal and have different hashCodes (same regression as thumb '
        'above, for the second new field)', () {
      final CruxShadows lightWithDifferentThumbLifted = CruxShadows(
        sm: CruxShadows.light.sm,
        md: CruxShadows.light.md,
        lg: CruxShadows.light.lg,
        scrim: CruxShadows.light.scrim,
        hairline: CruxShadows.light.hairline,
        ink: CruxShadows.light.ink,
        thumb: CruxShadows.light.thumb,
        thumbLifted: CruxShadows.dark.thumbLifted,
        xs: CruxShadows.light.xs,
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
        shadows: lightWithDifferentThumbLifted,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('two CruxThemeData differing only in shadows.xs are not equal '
        'and have different hashCodes (same regression as thumb/thumbLifted '
        'above, for the segmented-control-plate shadow)', () {
      final CruxShadows lightWithDifferentXs = CruxShadows(
        sm: CruxShadows.light.sm,
        md: CruxShadows.light.md,
        lg: CruxShadows.light.lg,
        scrim: CruxShadows.light.scrim,
        hairline: CruxShadows.light.hairline,
        ink: CruxShadows.light.ink,
        thumb: CruxShadows.light.thumb,
        thumbLifted: CruxShadows.light.thumbLifted,
        xs: CruxShadows.dark.xs,
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
        shadows: lightWithDifferentXs,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
