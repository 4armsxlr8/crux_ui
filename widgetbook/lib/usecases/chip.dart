import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// Widgetbook registration for [CruxChip].
///
/// See `CONVENTIONS.md` in this directory for the Playground / States
/// matrix / Edge cases contract every `usecases/<name>.dart` file follows.
WidgetbookComponent get chipComponent => WidgetbookComponent(
  name: 'Chip',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const ChipStatesMatrix(),
    ),
    WidgetbookUseCase(name: 'Edge cases', builder: _buildEdgeCases),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final String label = context.knobs.string(
    label: 'Label',
    initialValue: 'すべて',
  );
  final bool selected = context.knobs.boolean(
    label: 'Selected',
    initialValue: false,
  );
  final bool enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );

  return Center(
    child: CruxChip(
      label: label,
      selected: selected,
      // CruxChip has no separate `enabled` flag: passing `null` for
      // onTap is the widget's own disabled convention (see chip.dart's
      // class doc), so the "Enabled" knob maps onto that here.
      onTap: enabled ? () {} : null,
    ),
  );
}

/// The selected × enabled states matrix for [CruxChip], as a standalone
/// widget with no [CruxTheme] dependency of its own (per
/// `CONVENTIONS.md`'s States matrix contract) — it only reads colors and
/// spacing through whatever [CruxTheme.of] resolves to from its
/// surrounding context, so the future golden test can pump it directly
/// under its own bare [CruxTheme] ancestor.
///
/// [CruxChip] has no size variant to cross with state (unlike, say,
/// [CruxButton]), so the matrix is exactly the 2×2 grid the task
/// describes: selected × enabled, normal state only (no simulated press,
/// per the States matrix contract).
class ChipStatesMatrix extends StatelessWidget {
  /// Creates the chip states matrix.
  const ChipStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipStatesMatrixRow(
            rowLabel: 'Enabled',
            theme: theme,
            enabled: true,
          ),
          const SizedBox(height: CruxSpacing.s16),
          _ChipStatesMatrixRow(
            rowLabel: 'Disabled',
            theme: theme,
            enabled: false,
          ),
        ],
      ),
    );
  }
}

/// One row of the states matrix: a row label followed by the
/// not-selected/selected pair for a fixed [enabled] value.
class _ChipStatesMatrixRow extends StatelessWidget {
  const _ChipStatesMatrixRow({
    required this.rowLabel,
    required this.theme,
    required this.enabled,
  });

  final String rowLabel;
  final CruxThemeData theme;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // This row's label + two chips already shrink-wraps to its own content
    // width (mainAxisSize.min), which used to overflow with Flutter's
    // yellow-and-black stripes once the pane got narrower than that
    // content. Wrapping it in a horizontal SingleChildScrollView keeps the
    // row label and chips grouped on one line (unlike a Wrap, which could
    // push the label onto its own line, separating it from the chips it
    // labels) and makes the row scrollable instead of overflowing. Because
    // the row already shrink-wraps to content, and a SingleChildScrollView
    // shrink-wraps the same way once its content fits within the available
    // space, this is a no-op at the golden test's generous 900×4000 canvas.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              rowLabel,
              style: theme.typography.caption.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: CruxSpacing.s16),
          CruxChip(label: 'Not selected', onTap: enabled ? () {} : null),
          const SizedBox(width: CruxSpacing.s16),
          CruxChip(
            label: 'Selected',
            selected: true,
            onTap: enabled ? () {} : null,
          ),
        ],
      ),
    );
  }
}

Widget _buildEdgeCases(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(CruxSpacing.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A chip is width-hugging (IntrinsicWidth, per chip.dart's doc), so
        // this constrains the *parent* to 80px to exercise how a long label
        // squeezes against that constraint — it must ellipsize the label
        // rather than overflow the 80px box.
        SizedBox(
          width: 80,
          child: CruxChip(label: 'とても長いラベルのチップです。折り返さず省略されるはず', onTap: () {}),
        ),
        const SizedBox(height: CruxSpacing.s24),
        // Many chips of varying label length wrapped together, mixing
        // selected/unselected/disabled — checks that Wrap lays out each
        // chip's hugged width correctly line to line without any chip
        // stretching or overlapping its neighbors.
        Wrap(
          spacing: CruxSpacing.s8,
          runSpacing: CruxSpacing.s8,
          children: [
            CruxChip(label: 'すべて', selected: true, onTap: () {}),
            CruxChip(label: '和食', onTap: () {}),
            CruxChip(label: '洋食', onTap: () {}),
            CruxChip(label: '中華', onTap: () {}),
            CruxChip(label: 'イタリアン', onTap: () {}),
            CruxChip(label: 'フレンチ', onTap: () {}),
            const CruxChip(label: '無効なチップ'),
            CruxChip(label: 'カフェ・喫茶店', selected: true, onTap: () {}),
            CruxChip(label: '深夜営業', onTap: () {}),
            CruxChip(label: '予約可能な店舗のみ表示', onTap: () {}),
          ],
        ),
      ],
    ),
  );
}
