import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A human-readable label for a [CruxSpinnerSize], for the `size` knob and
/// the States matrix row labels below.
String _sizeLabel(CruxSpinnerSize size) => switch (size) {
  CruxSpinnerSize.small => 'small',
  CruxSpinnerSize.medium => 'medium',
  CruxSpinnerSize.large => 'large',
};

/// The `CruxSpinner` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get spinnerComponent => WidgetbookComponent(
  name: 'Spinner',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final CruxSpinnerSize size = context.knobs.object
            .segmented<CruxSpinnerSize>(
              label: 'size',
              options: CruxSpinnerSize.values,
              initialOption: CruxSpinnerSize.medium,
              labelBuilder: _sizeLabel,
            );
        // CruxSpinner's own doc recommends passing CruxColors.onAccent
        // explicitly when painting on an accent-filled surface (e.g. inside
        // a CruxButton while it loads); this knob previews both of that
        // widget's two real-world contexts side by side.
        final bool onAccentSurface = context.knobs.boolean(
          label: 'on accent surface',
          initialValue: false,
        );

        final CruxThemeData theme = CruxTheme.of(context);
        final CruxColors colors = theme.colors;
        final Widget spinner = CruxSpinner(
          size: size,
          color: onAccentSurface ? colors.onAccent : null,
        );

        return Center(
          child: onAccentSurface
              ? ColoredBox(
                  color: colors.accent,
                  child: Padding(
                    padding: const EdgeInsets.all(CruxSpacing.s24),
                    child: spinner,
                  ),
                )
              : spinner,
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const SpinnerStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _SpinnerEdgeCases(),
    ),
  ],
);

/// The States matrix widget for `CruxSpinner`: every combination of
/// [CruxSpinnerSize] x surface (on [CruxColors.background], on an
/// [CruxColors.accent] swatch) that this atom's dartdoc documents as its
/// two real-world contexts, laid out in a single screen.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the future golden test (`widgetbook/test/golden_test.dart`) can pump it
/// directly under its own bare [CruxTheme] ancestor without going through
/// Widgetbook at all. `CruxSpinner` animates continuously and never
/// settles, so that golden test is expected to pump it a fixed amount of
/// time rather than `pumpAndSettle()` before capturing it -- this widget
/// renders correctly at any such fixed moment, not only once "finished"
/// (it never finishes).
class SpinnerStatesMatrix extends StatelessWidget {
  /// Creates the spinner states matrix.
  const SpinnerStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );
    final TextStyle cellLabelStyle = theme.typography.caption.copyWith(
      color: colors.textSecondary,
    );

    Widget cell(CruxSpinnerSize size, bool onAccentSurface) {
      final Widget spinner = CruxSpinner(
        size: size,
        color: onAccentSurface ? colors.onAccent : null,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          onAccentSurface
              ? ColoredBox(
                  color: colors.accent,
                  child: Padding(
                    padding: const EdgeInsets.all(CruxSpacing.s8),
                    child: spinner,
                  ),
                )
              : spinner,
          const SizedBox(height: CruxSpacing.s4),
          Text(
            onAccentSurface ? 'on accent' : 'on background',
            style: cellLabelStyle,
          ),
        ],
      );
    }

    Widget row(CruxSpinnerSize size) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_sizeLabel(size), style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                cell(size, false),
                const SizedBox(width: CruxSpacing.s24),
                cell(size, true),
              ],
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            row(CruxSpinnerSize.small),
            row(CruxSpinnerSize.medium),
            row(CruxSpinnerSize.large),
          ],
        ),
      ),
    );
  }
}

/// A fixed (no knobs) set of layouts chosen to stress the two parts of
/// [CruxSpinner]'s layout most likely to break in a real screen: a
/// container narrower than the spinner's own fixed size (it has no
/// "shrink to fit" behavior -- it always renders at its
/// [CruxSpinnerSize]'s side length, per its widget doc), and whether its
/// symmetric, absolute-offset dot geometry looks any different under a
/// right-to-left [Directionality] (it shouldn't -- unlike e.g.
/// `CruxSwitch`'s thumb, nothing here is written in terms of `start`/`end`
/// or otherwise direction-aware).
class _SpinnerEdgeCases extends StatelessWidget {
  const _SpinnerEdgeCases();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '12px 幅の箱に large (36px) を収める (固定サイズのため収まらない)',
              style: captionStyle,
            ),
            const SizedBox(height: CruxSpacing.s8),
            const SizedBox(
              width: 12,
              height: 12,
              child: ClipRect(
                child: CruxSpinner(size: CruxSpinnerSize.large),
              ),
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              'RTL Directionality 下 (対称ジオメトリのためミラーリング影響なし)',
              style: captionStyle,
            ),
            const SizedBox(height: CruxSpacing.s8),
            const Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CruxSpinner(),
                  SizedBox(width: CruxSpacing.s16),
                  CruxSpinner(size: CruxSpinnerSize.large),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
