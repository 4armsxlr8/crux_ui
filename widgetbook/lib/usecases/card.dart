import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// Use cases for [CruxCard] and [CruxDivider].
///
/// [CruxDivider] has no use-case file of its own (per
/// `usecases/CONVENTIONS.md`, the milestone's component list folds it into
/// `card`), so it is exercised here: embedded inside every States matrix
/// cell and used between rows in the Edge cases' list-row layout.
WidgetbookComponent get cardComponent => WidgetbookComponent(
  name: 'Card',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (BuildContext context) => const CardStatesMatrix(),
    ),
    WidgetbookUseCase(name: 'Edge cases', builder: _buildEdgeCases),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final CruxThemeData theme = CruxTheme.of(context);

  final String content = context.knobs.string(
    label: 'Content text',
    description: 'The text rendered inside the card.',
    initialValue: 'カードの中身のテキストです。タップするとアクションが実行されます。',
  );
  final double padding = context.knobs.double.slider(
    label: 'Padding',
    description: 'Applied to all four sides via EdgeInsets.all.',
    initialValue: CruxSpacing.s16,
    min: 0,
    max: CruxSpacing.s32,
    divisions: 8,
  );
  final double radius = context.knobs.object.segmented<double>(
    label: 'Radius',
    options: const <double>[CruxRadii.m, CruxRadii.l],
    initialOption: CruxRadii.l,
    labelBuilder: (double value) =>
        value == CruxRadii.m ? 'm (14)' : 'l (16)',
  );
  final bool interactive = context.knobs.boolean(
    label: 'Interactive (onTap)',
    description: 'Leaving this off renders a purely decorative card.',
    initialValue: true,
  );

  return Padding(
    padding: const EdgeInsets.all(CruxSpacing.s24),
    child: CruxCard(
      padding: EdgeInsets.all(padding),
      radius: radius,
      onTap: interactive ? () {} : null,
      child: Text(
        content,
        style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
      ),
    ),
  );
}

/// The States matrix body: every combination of tappable / non-tappable ×
/// radius m / l, laid out in a single [Wrap] so all cells are visible at
/// once regardless of viewport width.
///
/// Reads colors and typography only through [CruxTheme.of], so — per
/// `usecases/CONVENTIONS.md` — it renders correctly with nothing but a
/// [CruxTheme] (or a bare [Directionality], exercising `CruxTheme.of`'s
/// light-theme fallback) above it. This is the widget the future
/// `widgetbook/test/golden_test.dart` pumps directly.
///
/// Each cell also embeds a [CruxDivider] between its two lines of text, so
/// this same matrix exercises [CruxDivider] rendered on both the light and
/// dark palettes without a separate use case.
class CardStatesMatrix extends StatelessWidget {
  /// Creates the card states matrix.
  const CardStatesMatrix({super.key});

  static const List<bool> _tappableOptions = <bool>[false, true];
  static const List<double> _radiusOptions = <double>[
    CruxRadii.m,
    CruxRadii.l,
  ];

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      child: Wrap(
        spacing: CruxSpacing.s16,
        runSpacing: CruxSpacing.s16,
        children: <Widget>[
          for (final bool tappable in _tappableOptions)
            for (final double radius in _radiusOptions)
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${tappable ? 'Tappable' : 'Non-tappable'} · radius '
                      '${radius.toStringAsFixed(0)}',
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CruxSpacing.s8),
                    _matrixCell(theme, tappable: tappable, radius: radius),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static Widget _matrixCell(
    CruxThemeData theme, {
    required bool tappable,
    required double radius,
  }) {
    return CruxCard(
      radius: radius,
      onTap: tappable ? () {} : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '見出し',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: CruxSpacing.s8),
          const CruxDivider(),
          const SizedBox(height: CruxSpacing.s8),
          Text(
            tappable ? 'タップできるカード' : 'タップできないカード',
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildEdgeCases(BuildContext context) {
  final CruxThemeData theme = CruxTheme.of(context);

  Widget sectionLabel(String text) {
    return Text(
      text,
      style: theme.typography.label.copyWith(color: theme.colors.textSecondary),
    );
  }

  return Padding(
    padding: const EdgeInsets.all(CruxSpacing.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Nested card inside a zero-padding outer card: the outer card's
        // border/rounded corners sit flush against its own edge (no
        // breathing room), and the inner card's own border+radius must
        // still render cleanly right up against that boundary.
        sectionLabel('入れ子カード + ゼロパディング'),
        const SizedBox(height: CruxSpacing.s8),
        SizedBox(
          width: 320,
          child: CruxCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(CruxSpacing.s12),
              child: CruxCard(
                radius: CruxRadii.m,
                child: Text(
                  '外側カードはゼロパディング。内側カードの角丸と枠線がそのまま見える。',
                  style: theme.typography.body.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CruxSpacing.s24),

        // A full-bleed, edge-to-edge colored child with zero padding: the
        // one case where the card's own clip is the only thing keeping the
        // child's square corners from poking out past the rounded border.
        sectionLabel('全面塗りつぶしの子 + ゼロパディングで角丸クリップを確認'),
        const SizedBox(height: CruxSpacing.s8),
        SizedBox(
          width: 320,
          height: 96,
          child: CruxCard(
            padding: EdgeInsets.zero,
            radius: CruxRadii.l,
            child: ColoredBox(color: theme.colors.accentTint),
          ),
        ),
        const SizedBox(height: CruxSpacing.s24),

        // A settings-style list row inside a zero-padding card: the top and
        // bottom CruxListTile rows must still get clipped to the card's
        // rounded corners, and CruxDivider must read correctly sandwiched
        // between full-bleed rows.
        sectionLabel('リスト行で角丸クリップを見せる'),
        const SizedBox(height: CruxSpacing.s8),
        SizedBox(
          width: 320,
          child: CruxCard(
            padding: EdgeInsets.zero,
            radius: CruxRadii.l,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CruxSpacing.s16,
                  ),
                  child: const CruxListTile(title: '通知', trailing: 'ON'),
                ),
                const CruxDivider(indent: CruxSpacing.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CruxSpacing.s16,
                  ),
                  child: const CruxListTile(
                    title: 'プライバシー',
                    subtitle: '公開範囲を管理',
                  ),
                ),
                const CruxDivider(indent: CruxSpacing.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CruxSpacing.s16,
                  ),
                  child: CruxListTile(title: 'アカウントを削除する', onTap: () {}),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
