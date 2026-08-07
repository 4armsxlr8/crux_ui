import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A repeating pool of [CruxColors] fields (never a raw color -- this file
/// follows the same "colors come from `CruxTheme`" habit the package
/// itself enforces) used to give [_DemoRow] visually distinct, cycling
/// swatches. Chosen so scrolling past many rows reads as real, varied
/// content rather than a flat wall of one color -- which would make any
/// banding in [CruxTopFade]'s fade/blur band much harder to catch by eye,
/// the whole point of this component's demo content.
List<Color> _demoPalette(CruxColors colors) => <Color>[
  colors.accent,
  colors.success,
  colors.error,
  colors.accentLine,
];

/// One dense demo row: a colored swatch + a label, alternating background
/// tint every other row -- dense enough (fixed 28px height) that several
/// rows' own edges fall inside [CruxTopFade]'s 160px band, so a banding
/// artifact would visibly misalign a row boundary instead of hiding inside
/// a single, taller block of color.
class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final List<Color> palette = _demoPalette(theme.colors);
    final Color swatch = palette[index % palette.length];

    return Container(
      height: 28,
      color: index.isEven ? theme.colors.surface : theme.colors.background,
      padding: const EdgeInsets.symmetric(horizontal: CruxSpacing.s12),
      child: Row(
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
          ),
          const SizedBox(width: CruxSpacing.s8),
          Expanded(
            child: Text(
              '項目 $index',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Continuous demo content for [CruxTopFade] to fade/blur over: a smooth
/// vertical [CruxColors]-built gradient behind a dense stack of
/// [_DemoRow]s, wrapped in a [ListView] so it always lays out safely
/// regardless of how tall its viewport is (never a plain non-scrolling
/// [Column], which would overflow if [rowCount] rows don't fit) -- static
/// content is rendered fine by a [ListView] left at its initial (`0`)
/// scroll offset, so this works equally for a live Playground demo and a
/// non-interactive States matrix/Edge cases frame.
class _DemoContent extends StatelessWidget {
  const _DemoContent({this.rowCount = 60});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final CruxColors colors = CruxTheme.of(context).colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colors.accentTint,
            colors.background,
            colors.accentTint,
            colors.background,
          ],
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: rowCount,
        itemBuilder: (BuildContext context, int index) =>
            _DemoRow(index: index),
      ),
    );
  }
}

/// The `CruxTopFade` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract
/// this file follows.
WidgetbookComponent get topFadeComponent => WidgetbookComponent(
  name: 'TopFade',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const TopFadeStatesMatrix(),
    ),
    WidgetbookUseCase.child(
      name: 'Edge cases',
      child: const _TopFadeEdgeCases(),
    ),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final double blurSigma = context.knobs.double.slider(
    label: 'blurSigma',
    initialValue: 8,
    min: 0,
    max: 16,
  );

  return Center(
    child: SizedBox(
      width: 360,
      height: 480,
      child: CruxTopFade(blurSigma: blurSigma, child: const _DemoContent()),
    ),
  );
}

/// The States matrix widget for `CruxTopFade`: the default blur (`8`)
/// next to blur disabled (`0`), both fading the exact same
/// [_DemoContent] so any difference between the two panes is purely the
/// blur overlay itself.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the golden test (`widgetbook/test/golden_test.dart`) can pump it
/// directly under its own bare [CruxTheme] ancestor without going through
/// Widgetbook at all. [CruxTopFade] itself has no animation
/// (`top_fade.dart`'s class doc), so unlike `SpinnerStatesMatrix` this
/// widget needs no special "never settles" handling in that golden test --
/// it renders its final frame immediately.
class TopFadeStatesMatrix extends StatelessWidget {
  /// Creates the top fade states matrix.
  const TopFadeStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: theme.colors.muted,
    );

    Widget pane(String caption, double blurSigma) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(caption, style: captionStyle),
          const SizedBox(height: CruxSpacing.s8),
          SizedBox(
            width: 220,
            height: 360,
            child: CruxTopFade(
              blurSigma: blurSigma,
              child: const _DemoContent(),
            ),
          ),
        ],
      );
    }

    return ColoredBox(
      color: theme.colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        // `Wrap`, not a fixed-width `Row`: two 220px panes plus their own
        // gap need 464px, which overflows a phone-width `ViewportAddon`
        // selection (for example 375-390px) if forced onto one line -- see
        // this class's own doc for why this widget must still lay out
        // safely there. `Wrap` drops the second pane to its own line
        // instead once the viewport is too narrow for both side by side; at
        // the golden test's fixed 900px canvas both panes still fit on one
        // line, so this is a no-op for that captured baseline.
        child: Wrap(
          spacing: CruxSpacing.s24,
          runSpacing: CruxSpacing.s24,
          children: <Widget>[
            pane('blurSigma: 8 (既定・フェード+ブラー)', 8),
            pane('blurSigma: 0 (フェードのみ)', 0),
          ],
        ),
      ),
    );
  }
}

/// Fixed (no knobs) layouts chosen to stress [CruxTopFade] at its
/// documented edges: content shorter than its own 160px fade band (its
/// class doc's "band clamps down instead of overflowing" contract), inside
/// an ancestor that scrolls a *different* axis, and over the two most
/// extreme possible backgrounds (pure black, pure white) to confirm the
/// alpha fade reads correctly regardless of what it is fading.
class _TopFadeEdgeCases extends StatelessWidget {
  const _TopFadeEdgeCases();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: theme.colors.muted,
    );

    Widget labeled(String caption, Widget content) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(caption, style: captionStyle),
          const SizedBox(height: CruxSpacing.s8),
          content,
        ],
      );
    }

    return ColoredBox(
      color: theme.colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            labeled(
              '160px の帯より低いコンテンツ (高さ 80px)',
              const SizedBox(
                width: 260,
                height: 80,
                child: CruxTopFade(child: _DemoContent(rowCount: 6)),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            labeled(
              '横スクロールの中 (縦の帯は横スクロールと独立)',
              SizedBox(
                height: 220,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 700,
                    child: CruxTopFade(child: const _DemoContent()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            // `Wrap`, not a fixed-width `Row` -- same phone-width
            // `ViewportAddon` overflow this file's `TopFadeStatesMatrix`
            // avoids the same way; see that widget's own comment.
            Wrap(
              spacing: CruxSpacing.s24,
              runSpacing: CruxSpacing.s24,
              children: <Widget>[
                labeled(
                  '真っ黒背景',
                  const SizedBox(
                    width: 220,
                    height: 260,
                    child: CruxTopFade(
                      child: ColoredBox(color: Color(0xFF000000)),
                    ),
                  ),
                ),
                labeled(
                  '真っ白背景',
                  const SizedBox(
                    width: 220,
                    height: 260,
                    child: CruxTopFade(
                      child: ColoredBox(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
