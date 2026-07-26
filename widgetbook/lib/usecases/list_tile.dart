import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The catalog entry for [CruxListTile]: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract
/// every file in this directory follows.
WidgetbookComponent get listTileComponent => WidgetbookComponent(
  name: 'CruxListTile',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const ListTileStatesMatrix(),
    ),
    WidgetbookUseCase(name: 'Edge cases', builder: _buildEdgeCases),
  ],
);

/// A small circular emoji badge used as [CruxListTile.leading] throughout
/// this file. Reads its background color from the ambient [CruxTheme]
/// like any normal descendant widget — it holds no theme of its own.
class _ListTileLeadingIcon extends StatelessWidget {
  const _ListTileLeadingIcon();

  @override
  Widget build(BuildContext context) {
    final CruxColors colors = CruxTheme.of(context).colors;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accentTint,
        shape: BoxShape.circle,
      ),
      child: const Text('🔔'),
    );
  }
}

// ---------------------------------------------------------------------------
// Playground
// ---------------------------------------------------------------------------

Widget _buildPlayground(BuildContext context) {
  final String title = context.knobs.string(label: 'Title', initialValue: '通知');
  final bool hasSubtitle = context.knobs.boolean(
    label: 'Has subtitle',
    initialValue: true,
  );
  final String subtitle = context.knobs.string(
    label: 'Subtitle',
    initialValue: 'すべての通知を受け取る',
  );
  final bool hasTrailing = context.knobs.boolean(
    label: 'Has trailing',
    initialValue: true,
  );
  final String trailing = context.knobs.string(
    label: 'Trailing',
    initialValue: 'ON',
  );
  final bool hasLeading = context.knobs.boolean(
    label: 'Has leading',
    initialValue: true,
  );
  final bool tappable = context.knobs.boolean(
    label: 'Tappable (onTap set)',
    initialValue: true,
  );

  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: CruxListTile(
        leading: hasLeading ? const _ListTileLeadingIcon() : null,
        title: title,
        subtitle: hasSubtitle ? subtitle : null,
        trailing: hasTrailing ? trailing : null,
        onTap: tappable ? () {} : null,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// States matrix
// ---------------------------------------------------------------------------

/// Every combination of `(leading, subtitle, trailing)` presence, in a
/// fixed, readable order.
const List<(bool, bool, bool)> _elementCombos = [
  (true, true, true),
  (true, true, false),
  (true, false, true),
  (true, false, false),
  (false, true, true),
  (false, true, false),
  (false, false, true),
  (false, false, false),
];

/// The width each row in the matrix is constrained to, so the grid reads
/// like a real settings-style list rather than stretching to whatever
/// viewport happens to host it.
const double _matrixRowWidth = 360;

/// All of [CruxListTile]'s element-presence combinations × tappable
/// (`onTap` set) vs. non-interactive (`onTap: null`), laid out on one
/// screen.
///
/// Takes no [CruxTheme] of its own — like every consumer, it only reads
/// colors/spacing/typography through whatever [CruxTheme.of] resolves to
/// from its surrounding context — so it renders correctly with just a
/// [CruxTheme] (or bare [Directionality], exercising the light fallback)
/// above it. This is the widget `widgetbook/test/golden_test.dart` pumps
/// directly, without going through Widgetbook.
class ListTileStatesMatrix extends StatelessWidget {
  /// Creates the states matrix widget.
  const ListTileStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return ColoredBox(
      color: theme.colors.background,
      // Two tappability groups of 8 element-combination rows each (16 rows
      // total) add up to more height than a small preview pane offers,
      // which used to overflow with Flutter's yellow-and-black stripes
      // instead of just scrolling past the fold. SingleChildScrollView
      // keeps every row reachable regardless of the surrounding viewport's
      // height; at the golden test's generous 900×4000 canvas the content
      // already fits, so this is a no-op there. This is unrelated to (and
      // does not touch) this file's Edge cases builder, whose separate
      // "infinite size during layout" issue is being investigated
      // elsewhere.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final bool tappable in const [true, false])
              Padding(
                padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
                child: _TappabilityGroup(tappable: tappable),
              ),
          ],
        ),
      ),
    );
  }
}

/// One block of the matrix: a header naming the `onTap` state, followed by
/// a [CruxListTile] for every entry in [_elementCombos].
class _TappabilityGroup extends StatelessWidget {
  const _TappabilityGroup({required this.tappable});

  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tappable ? 'Tappable (onTap set)' : 'Non-interactive (onTap: null)',
          style: theme.typography.caption.copyWith(color: theme.colors.muted),
        ),
        const SizedBox(height: CruxSpacing.s8),
        for (final (bool, bool, bool) combo in _elementCombos)
          Padding(
            padding: const EdgeInsets.only(bottom: CruxSpacing.s4),
            child: SizedBox(
              width: _matrixRowWidth,
              child: CruxListTile(
                leading: combo.$1 ? const _ListTileLeadingIcon() : null,
                title: _comboTitle(combo),
                subtitle: combo.$2 ? 'サブタイトル' : null,
                trailing: combo.$3 ? 'ON' : null,
                onTap: tappable ? () {} : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders a combo as its own row title, e.g. `L:○ S:× T:○`, so each row
/// in the matrix names the element combination it demonstrates.
String _comboTitle((bool, bool, bool) combo) {
  String mark(bool present) => present ? '○' : '×';
  return 'L:${mark(combo.$1)} S:${mark(combo.$2)} T:${mark(combo.$3)}';
}

// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

const String _longTitle = '来週の会議までに全員分の資料を確認し修正点をまとめて共有すること';
const String _longSubtitle = '担当者からの返信を待ってから最終版を印刷し関係者全員に配布する予定です';
const String _longTrailing = '2026/07/25 23:59';

Widget _buildEdgeCases(BuildContext context) {
  final CruxThemeData theme = CruxTheme.of(context);

  Widget labeled(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.typography.caption.copyWith(color: theme.colors.muted),
          ),
          const SizedBox(height: CruxSpacing.s8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colors.separator),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          labeled(
            '最長文の title / subtitle + leading + trailing（通常幅）',
            const CruxListTile(
              leading: _ListTileLeadingIcon(),
              title: _longTitle,
              subtitle: _longSubtitle,
              trailing: _longTrailing,
            ),
          ),
          labeled(
            '幅 80px + 全要素あり + 最長文（極端に狭いコンテナ）',
            SizedBox(
              width: 80,
              child: CruxListTile(
                leading: const _ListTileLeadingIcon(),
                title: _longTitle,
                subtitle: _longSubtitle,
                trailing: _longTrailing,
                onTap: () {},
              ),
            ),
          ),
          labeled(
            'leading なし + 最長文 title のみ（trailing/subtitle なし）',
            const CruxListTile(title: _longTitle),
          ),
          labeled(
            '幅 44px（最小タップ領域と同じ）+ tappable',
            SizedBox(
              width: 44,
              child: CruxListTile(
                leading: const _ListTileLeadingIcon(),
                title: _longTitle,
                trailing: _longTrailing,
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
