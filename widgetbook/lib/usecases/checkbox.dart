import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The `CruxCheckbox` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get checkboxComponent => WidgetbookComponent(
  name: 'Checkbox',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final bool initialChecked = context.knobs.boolean(
          label: 'checked',
          initialValue: false,
        );
        final bool enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        // Keyed on (initialChecked, enabled) so changing either knob starts
        // a fresh interactive demo at that knob's value, while tapping the
        // checkbox in between knob changes still toggles it locally
        // (handled by _CheckboxPlayground's own State) instead of being
        // silently overridden every rebuild.
        return Center(
          child: _CheckboxPlayground(
            key: ValueKey<(bool, bool)>((initialChecked, enabled)),
            initialChecked: initialChecked,
            enabled: enabled,
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const CheckboxStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _CheckboxEdgeCases(),
    ),
  ],
);

/// Backs the Playground use case: renders one [CruxCheckbox] the visitor
/// can actually tap, seeded from the `checked` knob and gated by the
/// `enabled` knob. A plain [CruxCheckbox] wired directly to the knobs
/// would be read-only (the knob only supplies a value on rebuild, and
/// nothing rebuilds the knob when the checkbox is tapped), so this small
/// [StatefulWidget] owns the live value the same way any real caller of
/// [CruxCheckbox] must, per its "controlled widget" contract.
class _CheckboxPlayground extends StatefulWidget {
  const _CheckboxPlayground({
    super.key,
    required this.initialChecked,
    required this.enabled,
  });

  final bool initialChecked;
  final bool enabled;

  @override
  State<_CheckboxPlayground> createState() => _CheckboxPlaygroundState();
}

class _CheckboxPlaygroundState extends State<_CheckboxPlayground> {
  late bool _checked = widget.initialChecked;

  @override
  Widget build(BuildContext context) {
    return CruxCheckbox(
      checked: _checked,
      onChanged: widget.enabled
          ? (bool next) => setState(() => _checked = next)
          : null,
    );
  }
}

/// The States matrix widget for `CruxCheckbox`: every combination of
/// checked/unchecked x enabled/disabled, laid out in a single screen.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the future golden test (`widgetbook/test/golden_test.dart`) can pump it
/// directly under its own bare [CruxTheme] ancestor without going through
/// Widgetbook at all.
///
/// There is no size dimension in this matrix (unlike e.g. a button's
/// small/medium/large): [CruxCheckbox] has no size parameter, so the two
/// axes here -- checked state and enabled state -- are the complete set.
class CheckboxStatesMatrix extends StatelessWidget {
  /// Creates the checkbox states matrix.
  const CheckboxStatesMatrix({super.key});

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

    Widget cell(bool checked, bool enabled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CruxCheckbox(checked: checked, onChanged: enabled ? (_) {} : null),
          const SizedBox(height: CruxSpacing.s4),
          Text(enabled ? 'enabled' : 'disabled', style: cellLabelStyle),
        ],
      );
    }

    Widget row(bool checked, String label) {
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
                cell(checked, true),
                const SizedBox(width: CruxSpacing.s24),
                cell(checked, false),
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
          children: <Widget>[row(true, 'Checked'), row(false, 'Unchecked')],
        ),
      ),
    );
  }
}

/// A no-op change handler for the always-enabled checkboxes in
/// [_CheckboxEdgeCases] (which only needs to demonstrate layout, not real
/// interaction). A top-level function reference so it can be used as a
/// `const` `onChanged` argument.
void _noOpCheckboxChange(bool _) {}

/// A fixed (no knobs) set of layouts chosen to stress the two parts of
/// [CruxCheckbox]'s layout most likely to break in a real screen: the gap
/// between its small visible box and its 44px minimum tap target when
/// several checkboxes sit close together, and a checklist-style column
/// (its most common real use) mixing checked/unchecked/disabled rows.
class _CheckboxEdgeCases extends StatelessWidget {
  const _CheckboxEdgeCases();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );
    final TextStyle rowTextStyle = theme.typography.body.copyWith(
      color: colors.textPrimary,
    );

    Widget checklistRow(String label, bool checked, {bool enabled = true}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: CruxSpacing.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CruxCheckbox(
              checked: checked,
              onChanged: enabled ? _noOpCheckboxChange : null,
            ),
            const SizedBox(width: CruxSpacing.s8),
            Text(label, style: rowTextStyle),
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ゼロ間隔で横に3個 (可視ボックス vs 最小タップ領域44px)', style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CruxCheckbox(checked: true, onChanged: _noOpCheckboxChange),
                CruxCheckbox(checked: false, onChanged: _noOpCheckboxChange),
                CruxCheckbox(checked: true, onChanged: null),
              ],
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text('チェックリスト風の縦並び (実際の使われ方)', style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            checklistRow('牛乳を買う', true),
            checklistRow('ゴミを出す', false),
            checklistRow('提出済み (無効化)', true, enabled: false),
            checklistRow('未提出 (無効化)', false, enabled: false),
          ],
        ),
      ),
    );
  }
}
