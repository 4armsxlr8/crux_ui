import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'household_ledger_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'task_list_screen.dart';

/// The minimum width/height of the ミモザ tab's unread badge, before its
/// padding grows it for a two-digit count.
const double _navBadgeMinSize = 16;

const double _navBadgeFontSize = 9;

/// The badge's own text color -- fixed white, since it always sits on
/// [CruxColors.error]'s red regardless of theme.
const Color _navBadgeTextColor = Color(0xFFFFFFFF);

/// The four top-level destinations [MainShell] switches between.
enum AppTab {
  /// ホーム: [TaskListScreen].
  home,

  /// ミモザ: [ChatScreen].
  chat,

  /// 家計簿: [HouseholdLedgerScreen].
  ledger,

  /// 設定: [SettingsScreen].
  settings,
}

/// The signed-in app shell: [CruxNavBar]'s four tabs over an
/// [IndexedStack] holding [TaskListScreen], [ChatScreen],
/// [HouseholdLedgerScreen], and [SettingsScreen]. Switching tabs preserves
/// each tab's own scroll position and in-progress state, since none of them
/// is ever rebuilt from scratch.
///
/// The nav bar hides itself while the on-screen keyboard is showing
/// ([MediaQuery.viewInsetsOf]'s bottom inset `> 0`), the same way a native
/// tab bar would, rather than floating over the keyboard.
///
/// **Unread badge.** [CruxNavBar] has no built-in badge concept -- its
/// [CruxNavItem.icon] slot accepts any [Widget], so the ミモザ tab's own
/// icon is a small [Stack] (see [_ChatTabIcon]) that overlays a badge on
/// top of the avatar emoji itself, showing [AppState.chatUnreadCount].
/// Selecting that tab calls [AppState.markChatRead] to clear it. A ミモザ
/// reply that arrives while the チャット tab is already selected still
/// increments the count until the tab is re-selected or that screen calls
/// [AppState.markChatRead] itself.
class MainShell extends StatefulWidget {
  /// Creates the main app shell, starting on the ホーム tab.
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _tab = AppTab.home;

  /// Switches to [tab], calling [markChatRead] (the [AppState] callback
  /// captured in [build], not re-resolved here) when [tab] is the チャット
  /// tab.
  void _selectTab(AppTab tab, VoidCallback markChatRead) {
    setState(() => _tab = tab);
    if (tab == AppTab.chat) {
      markChatRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final AppState appState = AppState.of(context);
    // Read above this widget's own Scaffold: Scaffold consumes the
    // keyboard inset for its body, so reading MediaQuery below it would
    // always report zero.
    final bool keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          IndexedStack(
            index: _tab.index,
            children: const <Widget>[
              TaskListScreen(),
              ChatScreen(),
              HouseholdLedgerScreen(),
              SettingsScreen(),
            ],
          ),
          if (!keyboardVisible)
            CruxNavBar<AppTab>(
              items: <CruxNavItem<AppTab>>[
                const CruxNavItem<AppTab>(
                  value: AppTab.home,
                  icon: Text('🏠', style: TextStyle(fontSize: 22)),
                  label: 'ホーム',
                ),
                CruxNavItem<AppTab>(
                  value: AppTab.chat,
                  icon: _ChatTabIcon(
                    unreadCount: appState.chatUnreadCount,
                    badgeColor: colors.error,
                  ),
                  label: mimosaAppName,
                ),
                const CruxNavItem<AppTab>(
                  value: AppTab.ledger,
                  icon: Text('💰', style: TextStyle(fontSize: 22)),
                  label: '家計簿',
                ),
                const CruxNavItem<AppTab>(
                  value: AppTab.settings,
                  icon: Text('⚙️', style: TextStyle(fontSize: 22)),
                  label: '設定',
                ),
              ],
              selected: _tab,
              onChanged: (AppTab tab) => _selectTab(tab, appState.markChatRead),
            ),
        ],
      ),
    );
  }
}

/// The ミモザ tab's icon: the avatar emoji with [_NavBadge] overlaid in its
/// top-right corner whenever [unreadCount] is positive.
class _ChatTabIcon extends StatelessWidget {
  const _ChatTabIcon({required this.unreadCount, required this.badgeColor});

  final int unreadCount;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The default hardEdge clip would cut off the badge, which
      // deliberately overlaps this Stack's own bounds (the avatar emoji's
      // natural size) at its top-right corner.
      clipBehavior: Clip.none,
      children: <Widget>[
        const Text(mimosaAvatarEmoji, style: TextStyle(fontSize: 22)),
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -6,
            child: _NavBadge(count: unreadCount, color: badgeColor),
          ),
      ],
    );
  }
}

/// A small pill showing [count], capped at `99+` for anything higher.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: _navBadgeMinSize,
        minHeight: _navBadgeMinSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_navBadgeMinSize / 2),
      ),
      // A bare Text here would otherwise pick up CruxNavBar's own
      // IconTheme/DefaultTextStyle merge (which tints text by
      // selected/unselected tab state) -- this badge's text color must
      // stay fixed white regardless of that.
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: _navBadgeTextColor,
          fontSize: _navBadgeFontSize,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Pops back to a fresh [LoginScreen], clearing [MainShell] (and anything
/// pushed on top of it, such as a settings sub-screen) from the navigation
/// stack. Call after the user confirms logging out.
///
/// [AppState]'s task/きろく/chat-log data is left untouched -- this only
/// changes which screen is showing, since nothing in this app persists to
/// disk regardless of which screen is visible. [AppState.chatUnreadCount]
/// is cleared first, though: a fresh [MainShell] always starts on the ホーム
/// tab regardless of which tab was active at logout, so without this a
/// badge for messages already read in the previous session would reappear
/// on the next login.
Future<void> logoutToLoginScreen(BuildContext context) {
  AppState.of(context).markChatRead();
  return Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const LoginScreen(),
    ),
    (Route<dynamic> route) => false,
  );
}
