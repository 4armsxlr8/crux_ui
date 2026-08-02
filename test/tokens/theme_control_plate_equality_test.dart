// Equality/hashCode regression for CruxColors.controlPlate.
//
// This lives in its own file rather than inside crux_theme_test.dart's
// existing "CruxThemeData equality" group, which already has an
// equivalent test for colors.controlFill: crux_theme_test.dart is
// out of scope for the change that added controlPlate (2026-08-02,
// "SegmentedControl のダークモードでのプレート vs ピルのコントラスト不足を、
// 色の変更で改善する"), so this mirrors that same test's shape here instead
// of editing it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  group('CruxThemeData equality', () {
    test('two instances differing only in colors.controlPlate are not equal '
        'and have different hashCodes (regression: theme.dart hand-writes == '
        'and hashCode by enumerating every CruxColors field, so a new '
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
          controlFill: CruxColors.light.controlFill,
          controlPlate: const Color(0xFF000000),
        ),
        typography: const CruxTypography(),
        brightness: Brightness.light,
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
