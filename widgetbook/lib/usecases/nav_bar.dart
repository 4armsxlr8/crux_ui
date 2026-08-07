import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A fixed pool of (icon, label) destinations the Playground and States
/// matrix below draw from, long enough to build up to five items without
/// repeating one -- matches `unknowns/navigation-bars/mock-bottomnav.html`'s own
/// `TAB_LIBRARY` (ホーム/チャット/投稿/通知/設定), reusing its emoji icons so
/// this catalog entry stays visually comparable to the mock it was reacted
/// against. Emoji [Text] rather than a real icon font, matching
/// `usecases/list_tile.dart`'s own `_ListTileLeadingIcon` -- no
/// `cupertino_icons` dependency needed for a demo icon.
const List<(String icon, String label)> _navItemPool = <(String, String)>[
  ('🏠', 'ホーム'),
  ('💬', 'チャット'),
  ('✏️', '投稿'),
  ('🔔', '通知'),
  ('⚙️', '設定'),
];

List<CruxNavItem<int>> _navItems(int count) => <CruxNavItem<int>>[
  for (int i = 0; i < count; i++)
    CruxNavItem<int>(
      value: i,
      icon: Text(_navItemPool[i].$1),
      label: _navItemPool[i].$2,
    ),
];

/// A repeating pool of [CruxColors] fields used to give [_DemoContent]'s
/// rows visually distinct, cycling swatches -- the same technique
/// `usecases/top_fade.dart`'s own `_demoPalette` uses, kept as this file's
/// own independent copy rather than importing that one (this catalog's
/// per-file ownership rule in `usecases/CONVENTIONS.md` keeps every
/// `usecases/<name>.dart` self-contained).
List<Color> _demoPalette(CruxColors colors) => <Color>[
  colors.accent,
  colors.success,
  colors.error,
  colors.accentLine,
];

/// A dense, colorful, scrolling demo list for [_phoneFrame]'s content pane
/// and [NavBarStatesMatrix]'s backdrop-fade row: a flat, single-color
/// background reads identically whether [CruxNavBar]'s backdrop-fade band
/// is drawn or not (the scrim is a [CruxColors.background] wash, with
/// nothing to visibly melt into), so this content exists purely to make
/// that band's own scrim/blur visible for both interactive experimentation
/// (the Playground's new `backdropFade`/`backdropBlurSigma` knobs) and
/// golden-test scrutiny (banding would misalign a row boundary instead of
/// hiding inside one flat block of color) -- the same reasoning
/// `usecases/top_fade.dart`'s own `_DemoContent` documents for
/// [CruxTopFade]'s fade band.
class _DemoContent extends StatelessWidget {
  const _DemoContent({this.rowCount = 40});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final List<Color> palette = _demoPalette(theme.colors);

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: rowCount,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          height: 28,
          color: index.isEven ? theme.colors.surface : theme.colors.background,
          padding: const EdgeInsets.symmetric(horizontal: CruxSpacing.s12),
          child: Row(
            children: <Widget>[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: palette[index % palette.length],
                  shape: BoxShape.circle,
                ),
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
      },
    );
  }
}

/// The `CruxNavBar` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get navBarComponent => WidgetbookComponent(
  name: 'NavBar',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const NavBarStatesMatrix(),
    ),
    WidgetbookUseCase.child(
      name: 'Edge cases',
      child: const _NavBarEdgeCases(),
    ),
  ],
);

/// A fixed-size "phone screen" frame the Playground and Edge cases below
/// stack [CruxNavBar] inside of: [CruxNavBar] bakes its own floating
/// margins (safe area + this widget's own confirmed 0px bottom offset,
/// 16px each side -- see `nav_bar.dart`'s class doc) into its own layout,
/// so it needs a bounded [Stack] to float inside, the same way it would sit
/// above a real screen's content. The content pane behind [navBar] is
/// [_DemoContent] (not this file's earlier plain centered placeholder
/// text) so a caller experimenting with the Playground's `backdropFade`
/// /`backdropBlurSigma` knobs can actually see the backdrop-fade band's own
/// scrim/blur at work against something other than a flat background.
Widget _phoneFrame({required BuildContext context, required Widget navBar}) {
  final CruxThemeData theme = CruxTheme.of(context);

  return Center(
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(CruxRadii.l)),
      child: SizedBox(
        width: 360,
        height: 520,
        child: ColoredBox(
          color: theme.colors.background,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              const Positioned.fill(child: _DemoContent()),
              navBar,
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildPlayground(BuildContext context) {
  final int itemCount = context.knobs.int.slider(
    label: 'items',
    initialValue: 4,
    min: 2,
    max: _navItemPool.length,
  );
  final bool enabled = context.knobs.boolean(
    label: 'enabled',
    initialValue: true,
  );
  final bool backdropFade = context.knobs.boolean(
    label: 'backdropFade',
    initialValue: true,
  );
  final double backdropBlurSigma = context.knobs.double.slider(
    label: 'backdropBlurSigma',
    initialValue: 8,
    min: 0,
    max: 16,
  );

  // Keyed on (enabled, itemCount) so changing either knob starts a fresh
  // interactive demo (selection reset to the first item) -- the same
  // "controlled widget needs a State-owning wrapper for a live Playground
  // demo" pattern `usecases/segmented_control.dart`'s own Playground uses.
  // backdropFade/backdropBlurSigma are deliberately *not* part of this key:
  // neither one affects [CruxNavBar]'s own selection state, so toggling
  // either should keep whichever tab is currently selected rather than
  // resetting it.
  return _phoneFrame(
    context: context,
    navBar: _NavBarPlayground(
      key: ValueKey<(bool, int)>((enabled, itemCount)),
      enabled: enabled,
      itemCount: itemCount,
      backdropFade: backdropFade,
      backdropBlurSigma: backdropBlurSigma,
    ),
  );
}

class _NavBarPlayground extends StatefulWidget {
  const _NavBarPlayground({
    super.key,
    required this.enabled,
    required this.itemCount,
    required this.backdropFade,
    required this.backdropBlurSigma,
  });

  final bool enabled;
  final int itemCount;
  final bool backdropFade;
  final double backdropBlurSigma;

  @override
  State<_NavBarPlayground> createState() => _NavBarPlaygroundState();
}

class _NavBarPlaygroundState extends State<_NavBarPlayground> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return CruxNavBar<int>(
      items: _navItems(widget.itemCount),
      selected: _selected,
      onChanged: widget.enabled
          ? (int next) => setState(() => _selected = next)
          : null,
      backdropFade: widget.backdropFade,
      backdropBlurSigma: widget.backdropBlurSigma,
    );
  }
}

/// The States matrix widget for `CruxNavBar`: every selection position
/// (first / middle / last selected) crossed with enabled/disabled, all
/// visible at once.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context, and
/// reads [MediaQuery] only through the same `maybe`-family fallbacks
/// `nav_bar.dart` itself uses -- so the golden test
/// (`widgetbook/test/golden_test.dart`) can pump it directly under its own
/// bare [CruxTheme] ancestor (with no [MediaQuery] at all) without going
/// through Widgetbook.
///
/// No selection-change animation plays here: every row is built already
/// sitting at its target [CruxNavBar.selected] on first build (the
/// plate/kira sheen only ever animate in response to a *change*, per
/// `nav_bar.dart`'s own `didUpdateWidget`-gated design -- see that file's
/// class doc), so this matrix captures a stable, non-animating rest frame
/// for every position regardless of which one it shows.
class NavBarStatesMatrix extends StatelessWidget {
  /// Creates the nav bar states matrix.
  const NavBarStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );

    Widget row(String label, int selected, {bool enabled = true}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            // A fixed-width ColoredBox rather than the full _phoneFrame:
            // this matrix stacks several bars in one column, so each row
            // only needs enough width to show the bar's own shadow clearly,
            // not a full phone-sized stage.
            ColoredBox(
              color: colors.background,
              child: Padding(
                padding: const EdgeInsets.all(CruxSpacing.s12),
                child: SizedBox(
                  width: 360,
                  child: CruxNavBar<int>(
                    items: _navItems(4),
                    selected: selected,
                    onChanged: enabled ? (int _) {} : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      // Four rows, each a full-width floating CruxNavBar plus its own
      // shadow margin, add up to more height than a small preview pane
      // offers -- wrapped in SingleChildScrollView per the convention
      // ButtonStatesMatrix documents (`usecases/button.dart:75-99`), so
      // every row stays reachable regardless of the surrounding viewport's
      // height instead of overflowing with Flutter's yellow-and-black
      // stripes. At the golden test's generous 900×4000 canvas the content
      // already fits, so this is a no-op there.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            row('先頭を選択 (enabled)', 0),
            row('中央を選択 (enabled)', 1),
            row('末尾を選択 (enabled)', 3),
            row('中央を選択 (disabled)', 1, enabled: false),
            // A 2026-08-06 addition, refined 2026-08-07 when the pill's own
            // width changed from "widest tab's own content" to a fixed
            // per-tab value (`_tabWidth` in `nav_bar.dart` -- initially
            // 102, re-tuned the same day to the shipped 88 after a
            // real-device comparison; see that constant's own doc): every
            // row above fixes item count at 4 (`_navItems(4)`), so none of
            // them shows the pill's own tab-count-driven width -- it now
            // sizes to `88 * itemCount + 8` regardless of any label's own
            // length (see `nav_bar.dart`'s own "Compact width" class doc),
            // so a 2-item bar floats visibly narrower than a 5-item one.
            // This section's own host is 600px wide, not the 360px every
            // other row in this matrix uses: a 5-item bar's own natural
            // width (`88 * 5 + 8 = 448px`) needs more than
            // `360 - 32 = 328px` of clamp room to render at its true,
            // unclamped width -- at 360 both the 4-item (`360px` natural)
            // and 5-item (`448px` natural) rows would clamp down to the
            // identical 328px, defeating the whole point of this
            // side-by-side comparison. `600 - 32 = 568px` comfortably
            // clears even the 5-item row's own 448px natural width, so
            // every row below renders at its true, label-independent
            // fixed width with no clamp at all.
            // Stacked here at a shared left edge (rather than one bar per
            // `row()` call, which would each get its own [ColoredBox]/
            // [Padding] shell) so every width is directly comparable in one
            // glance. `backdropFade: false` on each: this block exists to
            // compare pill widths, not to re-demonstrate the backdrop band
            // already covered by the row below.
            Text('項目数によるコンパクト幅の比較 (2/3/4/5 項目)', style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            ColoredBox(
              color: colors.background,
              child: Padding(
                padding: const EdgeInsets.all(CruxSpacing.s12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final int count in <int>[2, 3, 4, 5])
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: CruxSpacing.s12,
                        ),
                        child: SizedBox(
                          width: 600,
                          child: CruxNavBar<int>(
                            items: _navItems(count),
                            selected: 0,
                            onChanged: (int _) {},
                            backdropFade: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            Text('backdropFade (既定 true)', style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            // A colorful, densely-striped [_DemoContent] pane rather than
            // this matrix's own flat [colors.background] rows above: a
            // flat single-color backdrop reads identically whether the
            // backdrop-fade band is drawn or not (its scrim is a
            // [CruxColors.background] wash, with nothing to visibly melt
            // into), so this row exists specifically to let this golden
            // catch a banding regression -- a striped background makes any
            // seam in the scrim/blur band's own gradient stops visible as
            // a misaligned row boundary instead of hiding inside one
            // uniform block of color.
            SizedBox(
              width: 360,
              height: 260,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  const Positioned.fill(child: _DemoContent(rowCount: 20)),
                  CruxNavBar<int>(
                    items: _navItems(4),
                    selected: 1,
                    onChanged: (int _) {},
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

/// Fixed (no knobs) layouts chosen to stress [CruxNavBar]'s item count
/// range, label-ellipsis, and layout inside a narrow host: the minimum two
/// items, the maximum five, one item with a label much longer than its
/// neighbors, and the whole bar squeezed into a narrow 220px-wide host.
class _NavBarEdgeCases extends StatelessWidget {
  const _NavBarEdgeCases();

  static final List<CruxNavItem<int>> _longLabelItems = <CruxNavItem<int>>[
    CruxNavItem<int>(value: 0, icon: const Text('🏠'), label: 'ホーム'),
    CruxNavItem<int>(value: 1, icon: const Text('💬'), label: 'とても長いラベルのタブ'),
    CruxNavItem<int>(value: 2, icon: const Text('⚙️'), label: '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );

    Widget labeled(String caption, Widget bar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(caption, style: captionStyle),
          const SizedBox(height: CruxSpacing.s8),
          ColoredBox(
            color: colors.background,
            child: Padding(
              padding: const EdgeInsets.all(CruxSpacing.s12),
              child: bar,
            ),
          ),
        ],
      );
    }

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            labeled(
              '最小 2 項目',
              SizedBox(
                width: 360,
                child: CruxNavBar<int>(
                  items: _navItems(2),
                  selected: 0,
                  onChanged: (int _) {},
                ),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            labeled(
              '最大 5 項目',
              SizedBox(
                width: 360,
                child: CruxNavBar<int>(
                  items: _navItems(5),
                  selected: 2,
                  onChanged: (int _) {},
                ),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            labeled(
              '1 項目だけ極端に長いラベル（タブ幅は変わらず、ラベルだけが省略される）',
              SizedBox(
                width: 360,
                child: CruxNavBar<int>(
                  items: _longLabelItems,
                  selected: 1,
                  onChanged: (int _) {},
                ),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            labeled(
              '幅 220px に圧縮 (4 項目)',
              SizedBox(
                width: 220,
                child: CruxNavBar<int>(
                  items: _navItems(4),
                  selected: 0,
                  onChanged: (int _) {},
                ),
              ),
            ),
            const SizedBox(height: CruxSpacing.s24),
            labeled(
              'backdropFade: false (帯なし。バーの高さがピル自身の分だけに戻る)',
              SizedBox(
                width: 360,
                child: CruxNavBar<int>(
                  items: _navItems(4),
                  selected: 0,
                  onChanged: (int _) {},
                  backdropFade: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
