import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A fixed pool of labels the Playground and States matrix below draw from,
/// long enough to build up to five segments without repeating a label.
const List<String> _segmentLabelPool = <String>[
  'おすすめ',
  '今日中',
  '下書き',
  'アーカイブ',
  '全て',
];

/// The `CruxSegmentedControl` entry in the catalog: Playground, States
/// matrix, and Edge cases use cases. See `usecases/CONVENTIONS.md` for the
/// contract this file follows.
WidgetbookComponent get segmentedControlComponent => WidgetbookComponent(
  name: 'SegmentedControl',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const SegmentedControlStatesMatrix(),
    ),
    WidgetbookUseCase.child(
      name: 'Edge cases',
      child: const _SegmentedControlEdgeCases(),
    ),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final bool enabled = context.knobs.boolean(
    label: 'enabled',
    initialValue: true,
  );
  final int segmentCount = context.knobs.int.slider(
    label: 'segments',
    initialValue: 3,
    min: 2,
    max: _segmentLabelPool.length,
  );

  // Keyed on (enabled, segmentCount) so changing either knob starts a fresh
  // interactive demo (selection reset to the first segment), while tapping
  // between segments in between knob changes is still handled by
  // _SegmentedControlPlayground's own State -- the same "controlled widget
  // needs a State-owning wrapper for a live Playground demo" pattern
  // checkbox.dart's/switch_.dart's own Playgrounds use.
  return Center(
    child: SizedBox(
      width: 320,
      child: _SegmentedControlPlayground(
        key: ValueKey<(bool, int)>((enabled, segmentCount)),
        enabled: enabled,
        segmentCount: segmentCount,
      ),
    ),
  );
}

class _SegmentedControlPlayground extends StatefulWidget {
  const _SegmentedControlPlayground({
    super.key,
    required this.enabled,
    required this.segmentCount,
  });

  final bool enabled;
  final int segmentCount;

  @override
  State<_SegmentedControlPlayground> createState() =>
      _SegmentedControlPlaygroundState();
}

class _SegmentedControlPlaygroundState
    extends State<_SegmentedControlPlayground> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final List<CruxSegment<int>> segments = <CruxSegment<int>>[
      for (int i = 0; i < widget.segmentCount; i++)
        CruxSegment<int>(value: i, label: _segmentLabelPool[i]),
    ];
    return CruxSegmentedControl<int>(
      segments: segments,
      selected: _selected,
      onChanged: widget.enabled
          ? (int next) => setState(() => _selected = next)
          : null,
    );
  }
}

/// The States matrix widget for `CruxSegmentedControl`: every selection
/// position (first / middle / last selected) crossed with enabled/disabled,
/// all visible at once.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the golden test (`widgetbook/test/golden_test.dart`) can pump it directly
/// under its own bare [CruxTheme] ancestor without going through
/// Widgetbook.
///
/// No selection-change animation plays here: every row is built already
/// sitting at its target [CruxSegmentedControl.selected] on first build
/// (the plate/kira sheen only ever animate in response to a *change*, per
/// `segmented_control.dart`'s own `didUpdateWidget`-gated design -- see that
/// file's class doc), so this matrix captures a stable, non-animating rest
/// frame for every position regardless of which one it shows.
class SegmentedControlStatesMatrix extends StatelessWidget {
  /// Creates the segmented control states matrix.
  const SegmentedControlStatesMatrix({super.key});

  static const List<CruxSegment<int>> _threeSegments = <CruxSegment<int>>[
    CruxSegment<int>(value: 0, label: 'おすすめ'),
    CruxSegment<int>(value: 1, label: '今日中'),
    CruxSegment<int>(value: 2, label: '下書き'),
  ];

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );

    Widget row(String label, int selected, {bool enabled = true}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            SizedBox(
              width: 320,
              child: CruxSegmentedControl<int>(
                segments: _threeSegments,
                selected: selected,
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
            row('先頭を選択 (enabled)', 0),
            row('中央を選択 (enabled)', 1),
            row('末尾を選択 (enabled)', 2),
            row('中央を選択 (disabled)', 1, enabled: false),
          ],
        ),
      ),
    );
  }
}

/// Fixed (no knobs) layouts chosen to stress [CruxSegmentedControl]'s
/// label-ellipsis and per-segment minimum tap target: the full five-label
/// pool at once (each segment gets a narrow share of the 320px control), the
/// same three segments squeezed into a 160px control, and one segment with a
/// label much longer than its neighbors.
class _SegmentedControlEdgeCases extends StatelessWidget {
  const _SegmentedControlEdgeCases();

  static List<CruxSegment<int>> get _fiveSegments => <CruxSegment<int>>[
    for (int i = 0; i < _segmentLabelPool.length; i++)
      CruxSegment<int>(value: i, label: _segmentLabelPool[i]),
  ];

  static const List<CruxSegment<int>> _threeSegments = <CruxSegment<int>>[
    CruxSegment<int>(value: 0, label: 'おすすめ'),
    CruxSegment<int>(value: 1, label: '今日中'),
    CruxSegment<int>(value: 2, label: '下書き'),
  ];

  static const List<CruxSegment<int>> _unevenSegments = <CruxSegment<int>>[
    CruxSegment<int>(value: 0, label: '短い'),
    CruxSegment<int>(value: 1, label: 'これはとても長いラベルテキストです'),
    CruxSegment<int>(value: 2, label: '中'),
  ];

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: theme.colors.muted,
    );

    Widget labeled(String caption, Widget control) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(caption, style: captionStyle),
          const SizedBox(height: CruxSpacing.s8),
          control,
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
            '5 セグメント (幅 320px)',
            SizedBox(
              width: 320,
              child: CruxSegmentedControl<int>(
                segments: _fiveSegments,
                selected: 0,
                onChanged: (_) {},
              ),
            ),
          ),
          const SizedBox(height: CruxSpacing.s24),
          labeled(
            '3 セグメントを幅 160px に圧縮',
            SizedBox(
              width: 160,
              child: CruxSegmentedControl<int>(
                segments: _threeSegments,
                selected: 1,
                onChanged: (_) {},
              ),
            ),
          ),
          const SizedBox(height: CruxSpacing.s24),
          labeled(
            '1 セグメントだけ極端に長いラベル',
            SizedBox(
              width: 320,
              child: CruxSegmentedControl<int>(
                segments: _unevenSegments,
                selected: 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
