import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

/// Extra breathing room [_TabContent]'s own list appends, on top of the
/// device's own bottom safe-area inset, as its list's end padding.
///
/// This screen previously reserved [CruxNavBar]'s entire floating
/// footprint here (its 64px bar height plus a 24px margin above the safe
/// area, `_navBarClearanceAboveSafeArea`), so every tab's content always
/// stopped comfortably clear of the pill. [CruxNavBar] has since grown
/// its own backdrop-fade band (drawn by default, `backdropFade: true`)
/// specifically so scrolling content *can* pass behind it and visibly melt
/// away near the screen's bottom edge -- reserving that same large gap here
/// would keep every tab's content permanently clear of the band too,
/// defeating the point of this screen demonstrating that effect. This
/// constant is deliberately much smaller: just enough that the very last
/// row does not feel cut off mid-row once scrolled to the end, while still
/// letting a good stretch of rows above it scroll up behind the pill and
/// melt into the band.
const double _listBottomBreathingRoom = CruxSpacing.s24;

/// How many filler rows [_TabContent] appends below each tab's real
/// heading/description card, purely to make the list tall enough to
/// scroll -- generous enough that, even on a tall device or simulator
/// window, scrolling all the way to the end still passes several rows
/// behind [CruxNavBar]'s own backdrop-fade band.
const int _fillerRowCount = 24;

/// The four tabs this screen switches between.
enum _ShellTab {
  /// The ホーム tab.
  home,

  /// The チャット tab.
  chat,

  /// The 投稿 tab.
  post,

  /// The 設定 tab.
  settings,
}

/// Display data for one [_ShellTab]: its [CruxNavBar] icon/label and the
/// heading/body text its dummy content pane shows.
class _ShellTabInfo {
  const _ShellTabInfo({
    required this.icon,
    required this.label,
    required this.heading,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String heading;
  final String description;
}

/// The fixed per-tab content backing [_ShellTabInfo] lookups. A `Map`
/// rather than a `switch` in the build method so [_TabShellScreenState]'s
/// [CruxNavBar] item list and its dummy content pane can both read the
/// same single source per tab.
const Map<_ShellTab, _ShellTabInfo> _shellTabInfo = <_ShellTab, _ShellTabInfo>{
  _ShellTab.home: _ShellTabInfo(
    icon: Icons.home_outlined,
    label: 'ホーム',
    heading: 'ホーム',
    description: 'このタブに切り替わったときに表示されるダミーの本文です。実際のアプリではここにフィードやサマリーが並びます。',
  ),
  _ShellTab.chat: _ShellTabInfo(
    icon: Icons.chat_bubble_outline,
    label: 'チャット',
    heading: 'チャット',
    description: '会話一覧が入る想定のプレースホルダーです。CruxNavBar の実演が主目的のため、本文は最小限にしています。',
  ),
  _ShellTab.post: _ShellTabInfo(
    icon: Icons.add_box_outlined,
    label: '投稿',
    heading: '投稿',
    description: '新規投稿の入り口を想定したダミー本文です。実際の投稿フォームはホーム一覧の「新規投稿」から確認できます。',
  ),
  _ShellTab.settings: _ShellTabInfo(
    icon: Icons.settings_outlined,
    label: '設定',
    heading: '設定',
    description: '設定項目が並ぶ想定のダミー本文です。実際の設定画面はホーム一覧の「設定」から確認できます。',
  ),
};

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a four-tab shell (ホーム / チャット / 投稿 / 設定) demonstrating
/// [CruxNavBar], reached from the home index's "タブ切替" row.
///
/// The shared `AppHeader` (title + back + light/dark toggle, the same
/// header every other screen in this gallery uses) sits at the top,
/// unrelated to which tab is selected. Below it, the body is a [Stack]: a
/// full-bleed dummy content pane for the currently selected [_ShellTab]
/// sits behind, and a floating [CruxNavBar] sits in front at the bottom
/// edge, switching [_selected] through its controlled `selected` /
/// `onChanged` API the same way `settings_screen.dart`'s
/// [CruxSegmentedControl] row is driven. Each tab's content is a real
/// heading/description card (see [_TabContent]) followed by a long run of
/// dummy filler rows -- long enough to scroll, deliberately, so this screen
/// also demonstrates [CruxNavBar]'s own backdrop-fade band: scrolled to
/// the end, the last several rows visibly melt away behind the floating
/// pill instead of stopping short of it (see [_listBottomBreathingRoom]'s
/// own doc for why this screen's end padding is now much smaller than it
/// used to be).
///
/// This screen wraps its header/content column in a [SafeArea] with
/// `bottom: false`, unlike `task_list_screen.dart`/`settings_screen.dart`'s
/// plain [SafeArea]: [CruxNavBar] reads the device's real bottom safe
/// -area inset itself to place its own floating margin (see its own doc),
/// and a [SafeArea] consuming the bottom inset first would leave it reading
/// zero there instead, pulling it flush against the screen edge on devices
/// with a home indicator. Leaving `bottom` unconsumed here is what lets
/// [CruxNavBar]'s own safe-area math see the real value.
class TabShellScreen extends StatefulWidget {
  /// Creates the tab-shell sample screen.
  const TabShellScreen({super.key});

  @override
  State<TabShellScreen> createState() => _TabShellScreenState();
}

class _TabShellScreenState extends State<TabShellScreen> {
  _ShellTab _selected = _ShellTab.home;

  List<CruxNavItem<_ShellTab>> _buildItems() => <CruxNavItem<_ShellTab>>[
    for (final _ShellTab tab in _ShellTab.values)
      CruxNavItem<_ShellTab>(
        value: tab,
        icon: Icon(_shellTabInfo[tab]!.icon, size: 24),
        label: _shellTabInfo[tab]!.label,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(title: 'タブ切替'),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _TabContent(
                      info: _shellTabInfo[_selected]!,
                      colors: colors,
                      type: type,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: CruxNavBar<_ShellTab>(
                      items: _buildItems(),
                      selected: _selected,
                      onChanged: (_ShellTab value) =>
                          setState(() => _selected = value),
                    ),
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

/// The dummy body shown for the currently selected tab: a real heading
/// /description [CruxCard] (index `0`), followed by [_fillerRowCount]
/// dummy [CruxListTile] rows -- purely so the list is tall enough to
/// scroll, letting a caller scroll all the way to the end and see
/// [CruxNavBar]'s own backdrop-fade band at work over real content (see
/// this file's own class doc). A [ListView] rather than the previous
/// [SingleChildScrollView]-wrapped single card, since there is now more
/// than one row and the list needs to lay out safely regardless of how
/// many filler rows [_fillerRowCount] happens to be.
class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.info,
    required this.colors,
    required this.type,
  });

  final _ShellTabInfo info;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final double bottomPadding =
        MediaQuery.paddingOf(context).bottom + _listBottomBreathingRoom;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        CruxSpacing.s20,
        CruxSpacing.s20,
        CruxSpacing.s20,
        bottomPadding,
      ),
      itemCount: 1 + _fillerRowCount,
      separatorBuilder: (context, index) =>
          const SizedBox(height: CruxSpacing.s12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return CruxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.heading,
                  style: type.title.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: CruxSpacing.s8),
                Text(
                  info.description,
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          );
        }
        return CruxListTile(
          title: '${info.label} の項目 $index',
          subtitle: 'CruxNavBar の背後をスクロールして通り過ぎるダミー行です。',
        );
      },
    );
  }
}
