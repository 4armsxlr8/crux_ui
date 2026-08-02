import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The `CruxSlider` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get sliderComponent => WidgetbookComponent(
  name: 'Slider',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const SliderStatesMatrix(),
    ),
    WidgetbookUseCase.child(
      name: 'Edge cases',
      child: const _SliderEdgeCases(),
    ),
  ],
);

/// A small, finite set of [CruxSlider.divisions] choices for the
/// Playground's `divisions` knob -- a plain enum (rather than a nullable
/// `int` knob) since none of the knob helpers in
/// `usecases/CONVENTIONS.md` offer a nullable `int` picker, mirroring
/// `spinner.dart`'s `_sizeLabel`-style "enum knob translated to the real
/// parameter" pattern.
enum _SliderDivisionsOption {
  /// No snapping -- [CruxSlider.divisions] left `null`.
  continuous,

  /// Snaps to 5 evenly-spaced steps.
  five,

  /// Snaps to 10 evenly-spaced steps.
  ten,
}

int? _divisionsValue(_SliderDivisionsOption option) => switch (option) {
  _SliderDivisionsOption.continuous => null,
  _SliderDivisionsOption.five => 5,
  _SliderDivisionsOption.ten => 10,
};

String _divisionsLabel(_SliderDivisionsOption option) => switch (option) {
  _SliderDivisionsOption.continuous => 'continuous',
  _SliderDivisionsOption.five => '5',
  _SliderDivisionsOption.ten => '10',
};

Widget _buildPlayground(BuildContext context) {
  final bool enabled = context.knobs.boolean(
    label: 'enabled',
    initialValue: true,
  );
  final _SliderDivisionsOption divisionsOption = context.knobs.object
      .segmented<_SliderDivisionsOption>(
        label: 'divisions',
        options: _SliderDivisionsOption.values,
        initialOption: _SliderDivisionsOption.continuous,
        labelBuilder: _divisionsLabel,
      );
  final int? divisions = _divisionsValue(divisionsOption);

  // Keyed on (enabled, divisions) so changing either knob starts a fresh
  // interactive demo (value reset to the middle of the range), while
  // dragging in between knob changes is still handled by
  // _SliderPlayground's own State -- the same "controlled widget needs a
  // State-owning wrapper for a live Playground demo" pattern checkbox.dart's/
  // switch_.dart's own Playgrounds use.
  return Center(
    child: SizedBox(
      width: 280,
      child: _SliderPlayground(
        key: ValueKey<(bool, int?)>((enabled, divisions)),
        enabled: enabled,
        divisions: divisions,
      ),
    ),
  );
}

class _SliderPlayground extends StatefulWidget {
  const _SliderPlayground({
    super.key,
    required this.enabled,
    required this.divisions,
  });

  final bool enabled;
  final int? divisions;

  @override
  State<_SliderPlayground> createState() => _SliderPlaygroundState();
}

class _SliderPlaygroundState extends State<_SliderPlayground> {
  double _value = 50;

  @override
  Widget build(BuildContext context) {
    return CruxSlider(
      value: _value,
      min: 0,
      max: 100,
      divisions: widget.divisions,
      onChanged: widget.enabled
          ? (double next) => setState(() => _value = next)
          : null,
    );
  }
}

/// The States matrix widget for `CruxSlider`: every value shown at three
/// resting positions (min / middle / max), plus a divisions row (showing the
/// tick marks) and a disabled row -- all visible at once.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the golden test (`widgetbook/test/golden_test.dart`) can pump it directly
/// under its own bare [CruxTheme] ancestor without going through
/// Widgetbook.
///
/// Every row renders at rest (no drag in progress), so the value bubble --
/// only ever shown while [CruxSlider] is actively being dragged, per that
/// widget's own doc -- never appears here; that is covered by the
/// Playground use case instead, which a visitor can actually drag.
class SliderStatesMatrix extends StatelessWidget {
  /// Creates the slider states matrix.
  const SliderStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );

    Widget row(
      String label, {
      required double value,
      int? divisions,
      bool enabled = true,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            SizedBox(
              width: 280,
              child: CruxSlider(
                value: value,
                min: 0,
                max: 100,
                divisions: divisions,
                onChanged: enabled ? (_) {} : null,
              ),
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
            row('最小値 (0)', value: 0),
            row('中間値 (50)', value: 50),
            row('最大値 (100)', value: 100),
            row('divisions = 5 (目盛り表示)', value: 40, divisions: 5),
            row('disabled', value: 50, enabled: false),
          ],
        ),
      ),
    );
  }
}

/// Fixed (no knobs) layouts chosen to stress [CruxSlider]'s narrow-width
/// and label-formatting handling: a slider squeezed into a 60px-wide
/// container (leaving almost no travel for the thumb), a slider with many
/// tightly packed division ticks, and sliders with a custom
/// [CruxSlider.valueLabelBuilder] over an unusual range (negative values,
/// and a six-digit range) -- draggable, so a visitor can actually pull the
/// thumb to see the bubble render each custom label.
class _SliderEdgeCases extends StatelessWidget {
  const _SliderEdgeCases();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: theme.colors.muted,
    );

    Widget labeled(String caption, Widget slider) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(caption, style: captionStyle),
          const SizedBox(height: CruxSpacing.s8),
          slider,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          labeled(
            '幅 60px (キャップの可動域がほぼ無い)',
            SizedBox(
              width: 60,
              child: CruxSlider(value: 50, onChanged: (_) {}, max: 100),
            ),
          ),
          const SizedBox(height: CruxSpacing.s24),
          labeled(
            'divisions = 20 (目盛りが密集)',
            SizedBox(
              width: 280,
              child: CruxSlider(
                value: 60,
                onChanged: (_) {},
                max: 100,
                divisions: 20,
              ),
            ),
          ),
          const SizedBox(height: CruxSpacing.s24),
          labeled(
            '負の範囲 + カスタムラベル (ドラッグでバブルを確認)',
            SizedBox(
              width: 280,
              child: CruxSlider(
                value: 0,
                onChanged: (_) {},
                min: -50,
                max: 50,
                valueLabelBuilder: (double v) =>
                    v >= 0 ? '+${v.round()}' : '${v.round()}',
              ),
            ),
          ),
          const SizedBox(height: CruxSpacing.s24),
          labeled(
            '6 桁レンジ + カスタムラベル (ドラッグでバブルを確認)',
            SizedBox(
              width: 280,
              child: CruxSlider(
                value: 500000,
                onChanged: (_) {},
                max: 1000000,
                valueLabelBuilder: (double v) => '¥${v.round()}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
