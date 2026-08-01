import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The demo icon shared by every use case below: a plain (non-emoji) glyph,
/// not a real icon font -- so it inherits [CruxIconButton]'s own resolved
/// foreground color via the ambient `IconTheme`/`DefaultTextStyle` it merges
/// (see `icon_button.dart`'s class doc), the same "a plain glyph shows the
/// color transition, a full-color emoji would hide it" reasoning
/// `usecases/input_bar.dart`'s `_demoSubmit` uses for its own submit icon.
/// A `const` top-level value (not a getter) so it stays usable inside the
/// `const CruxIconButton(...)` literals below.
const Widget _demoIcon = Text('✕');

/// A no-op press handler for the always-enabled buttons in
/// [_IconButtonEdgeCases] (which only needs to demonstrate layout, not real
/// interaction). A top-level function reference so it can be used as a
/// `const` `onPressed` argument.
void _noOpIconButtonPress() {}

/// The `CruxIconButton` entry in the catalog: Playground, States matrix,
/// and Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract
/// this file follows.
WidgetbookComponent get iconButtonComponent => WidgetbookComponent(
  name: 'IconButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final CruxIconButtonTone tone = context.knobs.object
            .segmented<CruxIconButtonTone>(
              label: 'tone',
              options: CruxIconButtonTone.values,
              initialOption: CruxIconButtonTone.neutral,
              labelBuilder: (CruxIconButtonTone tone) => switch (tone) {
                CruxIconButtonTone.neutral => 'neutral',
                CruxIconButtonTone.primary => 'primary',
              },
            );
        final CruxIconButtonSize size = context.knobs.object
            .segmented<CruxIconButtonSize>(
              label: 'size',
              options: CruxIconButtonSize.values,
              initialOption: CruxIconButtonSize.medium,
              labelBuilder: (CruxIconButtonSize size) => switch (size) {
                CruxIconButtonSize.medium => 'medium',
                CruxIconButtonSize.large => 'large',
              },
            );
        final bool enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );

        return Center(
          child: CruxIconButton(
            icon: _demoIcon,
            label: '閉じる',
            tone: tone,
            size: size,
            onPressed: enabled ? _noOpIconButtonPress : null,
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const IconButtonStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _IconButtonEdgeCases(),
    ),
  ],
);

/// The States matrix widget for `CruxIconButton`: every combination of
/// [CruxIconButtonTone] x [CruxIconButtonSize] x enabled/disabled
/// state, laid out in a single screen.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the golden test (`widgetbook/test/golden_test.dart`) can pump it
/// directly under its own bare [CruxTheme] ancestor without going through
/// Widgetbook at all.
///
/// Each tone row lays its two sizes out side by side (rather than stacking
/// every combination in one long column) to stay comfortably inside the
/// golden harness's 900 logical pixel canvas width.
class IconButtonStatesMatrix extends StatelessWidget {
  /// Creates the icon button states matrix.
  const IconButtonStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );
    final TextStyle sizeLabelStyle = theme.typography.caption.copyWith(
      color: colors.textPrimary,
    );
    final TextStyle cellLabelStyle = theme.typography.caption.copyWith(
      color: colors.textSecondary,
    );

    Widget cell(
      CruxIconButtonTone tone,
      CruxIconButtonSize size,
      bool enabled,
    ) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CruxIconButton(
            icon: _demoIcon,
            label: '閉じる',
            tone: tone,
            size: size,
            onPressed: enabled ? _noOpIconButtonPress : null,
          ),
          const SizedBox(height: CruxSpacing.s4),
          Text(enabled ? 'enabled' : 'disabled', style: cellLabelStyle),
        ],
      );
    }

    Widget sizeGroup(
      CruxIconButtonTone tone,
      CruxIconButtonSize size,
      String sizeLabel,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(sizeLabel, style: sizeLabelStyle),
          const SizedBox(height: CruxSpacing.s8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              cell(tone, size, true),
              const SizedBox(width: CruxSpacing.s24),
              cell(tone, size, false),
            ],
          ),
        ],
      );
    }

    Widget row(CruxIconButtonTone tone, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                sizeGroup(tone, CruxIconButtonSize.medium, 'medium (44)'),
                const SizedBox(width: CruxSpacing.s32),
                sizeGroup(tone, CruxIconButtonSize.large, 'large (56)'),
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
            row(CruxIconButtonTone.neutral, 'Neutral'),
            row(CruxIconButtonTone.primary, 'Primary'),
          ],
        ),
      ),
    );
  }
}

/// A fixed (no knobs) set of layouts chosen to stress the part of
/// [CruxIconButton]'s layout most likely to break in a real screen: how
/// closely several 44px-circle buttons can sit together, and whether it
/// lays out safely under both directions of [Directionality] (the circle is
/// symmetric, so there is no mirroring concern the way `CruxSwitch`'s
/// thumb has, but a caller could still constrain it inside an unusually
/// narrow row).
class _IconButtonEdgeCases extends StatelessWidget {
  const _IconButtonEdgeCases();

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
            Text('ゼロ間隔で横に3個 (medium: 可視円=タップ領域=44px)', style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CruxIconButton(
                  icon: _demoIcon,
                  label: '閉じる 1',
                  onPressed: _noOpIconButtonPress,
                ),
                CruxIconButton(
                  icon: _demoIcon,
                  label: '閉じる 2',
                  tone: CruxIconButtonTone.primary,
                  onPressed: _noOpIconButtonPress,
                ),
                CruxIconButton(icon: _demoIcon, label: '閉じる 3'),
              ],
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text('RTL Directionality 下 (円形のためミラーリング影響なし)', style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            const Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CruxIconButton(
                    icon: _demoIcon,
                    label: '閉じる',
                    onPressed: _noOpIconButtonPress,
                  ),
                  SizedBox(width: CruxSpacing.s16),
                  CruxIconButton(
                    icon: _demoIcon,
                    label: '送信',
                    tone: CruxIconButtonTone.primary,
                    onPressed: _noOpIconButtonPress,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
