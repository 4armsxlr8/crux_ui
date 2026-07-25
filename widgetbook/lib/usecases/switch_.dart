import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The `CruxSwitch` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get switchComponent => WidgetbookComponent(
  name: 'Switch',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final bool initialValue = context.knobs.boolean(
          label: 'value',
          initialValue: false,
        );
        final bool enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        // Keyed on (initialValue, enabled) so changing either knob starts a
        // fresh interactive demo at that knob's value, while tapping the
        // switch in between knob changes still toggles it locally (handled
        // by _SwitchPlayground's own State) instead of being silently
        // overridden every rebuild.
        return Center(
          child: _SwitchPlayground(
            key: ValueKey<(bool, bool)>((initialValue, enabled)),
            initialValue: initialValue,
            enabled: enabled,
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const SwitchStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _SwitchEdgeCases(),
    ),
  ],
);

/// Backs the Playground use case: renders one [CruxSwitch] the visitor can
/// actually tap, seeded from the `value` knob and gated by the `enabled`
/// knob. A plain [CruxSwitch] wired directly to the knobs would be
/// read-only (the knob only supplies a value on rebuild, and nothing
/// rebuilds the knob when the switch is tapped), so this small
/// [StatefulWidget] owns the live value the same way any real caller of
/// [CruxSwitch] must, per its "controlled widget" contract.
class _SwitchPlayground extends StatefulWidget {
  const _SwitchPlayground({
    super.key,
    required this.initialValue,
    required this.enabled,
  });

  final bool initialValue;
  final bool enabled;

  @override
  State<_SwitchPlayground> createState() => _SwitchPlaygroundState();
}

class _SwitchPlaygroundState extends State<_SwitchPlayground> {
  late bool _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return CruxSwitch(
      value: _value,
      onChanged: widget.enabled
          ? (bool next) => setState(() => _value = next)
          : null,
    );
  }
}

/// The States matrix widget for `CruxSwitch`: every combination of
/// on/off x enabled/disabled, laid out in a single screen.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the future golden test (`widgetbook/test/golden_test.dart`) can pump it
/// directly under its own bare [CruxTheme] ancestor without going through
/// Widgetbook at all.
///
/// There is no size dimension in this matrix (unlike e.g. a button's
/// small/medium/large): [CruxSwitch] has no size parameter, so the two
/// axes here -- value (on/off) and enabled state -- are the complete set.
class SwitchStatesMatrix extends StatelessWidget {
  /// Creates the switch states matrix.
  const SwitchStatesMatrix({super.key});

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

    Widget cell(bool value, bool enabled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CruxSwitch(value: value, onChanged: enabled ? (_) {} : null),
          const SizedBox(height: CruxSpacing.s4),
          Text(enabled ? 'enabled' : 'disabled', style: cellLabelStyle),
        ],
      );
    }

    Widget row(bool value, String label) {
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
                cell(value, true),
                const SizedBox(width: CruxSpacing.s24),
                cell(value, false),
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
          children: <Widget>[row(true, 'On'), row(false, 'Off')],
        ),
      ),
    );
  }
}

/// A no-op change handler for the always-enabled switches in
/// [_SwitchEdgeCases] (which only needs to demonstrate layout, not real
/// interaction). A top-level function reference so it can be used as a
/// `const` `onChanged` argument.
void _noOpSwitchChange(bool _) {}

/// A fixed (no knobs) set of layouts chosen to stress the two parts of
/// [CruxSwitch]'s layout most likely to break in a real screen: the gap
/// between its 32px visible track and its 44px minimum tap target when
/// several switches sit close together, and its unmirrored positioning
/// (the thumb's `Positioned.left` in `lib/src/switch.dart` is an absolute
/// offset, not a `start`/`end` one) under a right-to-left ambient
/// [Directionality].
class _SwitchEdgeCases extends StatelessWidget {
  const _SwitchEdgeCases();

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
            Text('ゼロ間隔で縦に3個 (可視トラック32px vs 最小タップ領域44px)', style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CruxSwitch(value: true, onChanged: _noOpSwitchChange),
                CruxSwitch(value: false, onChanged: _noOpSwitchChange),
                CruxSwitch(value: true, onChanged: null),
              ],
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              'RTL Directionality 下 (left 固定配置のためミラーリングされない)',
              style: captionStyle,
            ),
            const SizedBox(height: CruxSpacing.s8),
            const Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CruxSwitch(value: false, onChanged: _noOpSwitchChange),
                  SizedBox(width: CruxSpacing.s16),
                  CruxSwitch(value: true, onChanged: _noOpSwitchChange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
