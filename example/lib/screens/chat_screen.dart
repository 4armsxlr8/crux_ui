import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';
import '../state/app_state.dart';
import 'main_shell.dart';

/// Extra bottom padding the composer reserves on top of the safe-area
/// bottom inset [SafeArea] already consumes, so it clears [MainShell]'s
/// floating [CruxNavBar] pill instead of sitting behind it. Matches
/// `settings_screen.dart`'s own `_navBarClearance`: the pill's rendered
/// height is private to the package, so this is a fixed generous clearance
/// rather than a value read from it. Applied only while the keyboard is
/// hidden -- see [_ChatScreenState._keyboardVisible]'s own doc for why the
/// composer must drop this padding once the keyboard (and with it,
/// [MainShell]'s nav bar) is showing.
const double _navBarClearance = 96;

/// The ミモザ (chat) tab of [MainShell]: the shared chat log backed by
/// [AppState.chatMessages], a search field that filters it live, and a
/// bottom-pinned composer that sends a message via
/// [AppState.sendUserMessage].
///
/// Clears [AppState.chatUnreadCount] itself whenever a new ミモザ message
/// arrives while this tab is the one [MainShell] currently has selected --
/// [MainShell] only clears the badge on tab switch, so a reply that lands
/// while this screen is already showing would otherwise leave a stale
/// badge until the next switch. [MainShell] keeps every tab mounted inside
/// an [IndexedStack], so this screen also rebuilds while a different tab is
/// selected; it only clears the badge when the ambient [IndexedStack]'s own
/// `index` matches [AppTab.chat], never unconditionally on every rebuild.
class ChatScreen extends StatefulWidget {
  /// Creates the ミモザ chat tab.
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();

  String _searchQuery = '';

  /// Whether the on-screen keyboard is currently showing, read from the raw
  /// view metrics rather than [MediaQuery.viewInsetsOf]: [MainShell]'s own
  /// [Scaffold] already strips the bottom view inset for everything below
  /// it (the standard `resizeToAvoidBottomInset` behavior), so that
  /// ambient [MediaQuery] always reports zero here. [MainShell] hides its
  /// nav bar from this same raw signal, so tracking it independently here
  /// keeps the composer's own [_navBarClearance] in sync with whether the
  /// pill is actually showing.
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bool visible = View.of(context).viewInsets.bottom > 0;
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible);
    }
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  /// Unfocuses whichever field currently has the keyboard. [MainShell]
  /// hides its nav bar while the keyboard is showing, and the composer's
  /// multi-line field has no platform "done" key to close it (iOS gives its
  /// return key a "newline" action here, not "done") -- this is the only
  /// way to get the nav bar back once that keyboard is up.
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleSend(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      // CruxInputBar's own submit button already refuses to fire this
      // callback while its text is empty (IB-D08's disabled tone), but the
      // return key path (IB-A03) still reaches onSubmit with whatever text
      // is present -- guarding here keeps a message of only whitespace from
      // ever being sent.
      return;
    }
    AppState.of(context).sendUserMessage(trimmed);
    _composerController.clear();
  }

  /// Clears [AppState.chatUnreadCount] after this frame if [appState]
  /// currently has unread messages **and** this screen is the tab
  /// [MainShell]'s [IndexedStack] is actually showing. Scheduled via
  /// [WidgetsBinding.addPostFrameCallback] rather than called directly: this
  /// runs from inside [build], and [AppState.markChatRead] triggers a
  /// [State.setState] on an ancestor, which build must not do synchronously.
  void _clearUnreadIfShowing(AppState appState) {
    if (appState.chatUnreadCount == 0) {
      return;
    }
    final IndexedStack? stack = context
        .findAncestorWidgetOfExactType<IndexedStack>();
    if (stack?.index != AppTab.chat.index) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        AppState.of(context).markChatRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final AppState appState = AppState.of(context);

    _clearUnreadIfShowing(appState);

    final List<MimosaChatMessage> visibleMessages = _searchQuery.isEmpty
        ? appState.chatMessages
        : appState.chatMessages
              .where(
                (MimosaChatMessage message) =>
                    message.text.contains(_searchQuery),
              )
              .toList();
    // Newest-first, for the reversed ListView below: with reverse: true,
    // index 0 renders at the visual bottom, so the newest message has to be
    // first in this list for the view to open already scrolled to it.
    final List<MimosaChatMessage> newestFirst = visibleMessages.reversed
        .toList();

    final double composerBottomPadding =
        CruxSpacing.s12 + (_keyboardVisible ? 0 : _navBarClearance);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CruxSpacing.s20,
                CruxSpacing.s16,
                CruxSpacing.s20,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  mimosaAppName,
                  style: type.headline.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CruxSpacing.s20,
                CruxSpacing.s12,
                CruxSpacing.s20,
                0,
              ),
              child: CruxInputBar(
                controller: _searchController,
                placeholder: '会話を検索',
                leading: CruxInputBarLeading(
                  icon: Icon(
                    Icons.search,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
                clear: CruxInputBarClear(
                  icon: Icon(
                    Icons.cancel,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  label: '検索を消去',
                ),
                onChanged: _handleSearchChanged,
                // A search bar's return key always means "run the search"
                // (IB-A04); this box already filters live on every
                // keystroke, so the return key repeats the same, already
                // -applied filter rather than doing nothing.
                onSubmit: _handleSearchChanged,
              ),
            ),
            Expanded(
              // Translucent so this never steals a gesture the list or a
              // bubble underneath would otherwise handle -- it only adds a
              // tap-to-dismiss on top of them.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissKeyboard,
                child: newestFirst.isEmpty
                    ? Center(
                        child: Text(
                          '一致するメッセージが見つかりません',
                          style: type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(
                          horizontal: CruxSpacing.s20,
                          vertical: CruxSpacing.s12,
                        ),
                        itemCount: newestFirst.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _MessageBubble(
                            message: newestFirst[index],
                            colors: colors,
                            type: type,
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                CruxSpacing.s20,
                CruxSpacing.s8,
                CruxSpacing.s20,
                composerBottomPadding,
              ),
              child: CruxInputBar(
                controller: _composerController,
                placeholder: 'ミモザに話しかける…',
                maxLines: 5,
                clear: CruxInputBarClear(
                  icon: Icon(
                    Icons.cancel,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  label: '入力を消去',
                ),
                submit: CruxInputBarSubmit(
                  // No explicit `color` here: CruxInputBar recolors this
                  // icon itself (accent-on-enabled, muted-on-disabled,
                  // animated between the two per IB-D08) by wrapping it in
                  // its own IconTheme -- hardcoding a color here would
                  // override that and freeze the icon at one tone.
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: '送信',
                ),
                onSubmit: _handleSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One chat bubble: accent-filled and aligned to the trailing edge for the
/// user's own messages (see [_AccentBubble]), a plain [CruxCard] aligned
/// to the leading edge (with ミモザ's avatar emoji beside it) for ミモザ's --
/// the same accent-vs-surface distinction the design mock draws between the
/// two senders.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.colors,
    required this.type,
  });

  final MimosaChatMessage message;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final bool isMe = message.sender == MimosaChatSender.user;
    final double maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;

    final Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      child: isMe
          ? _AccentBubble(message: message, colors: colors, type: type)
          : CruxCard(
              radius: CruxRadii.l,
              child: _BubbleText(
                message: message,
                type: type,
                textColor: colors.textPrimary,
                timeColor: colors.muted,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: CruxSpacing.s12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe
            ? <Widget>[bubble]
            : <Widget>[
                const Text(mimosaAvatarEmoji, style: TextStyle(fontSize: 20)),
                const SizedBox(width: CruxSpacing.s8),
                bubble,
              ],
      ),
    );
  }
}

/// The user's own chat bubble: accent-filled with [CruxColors.onAccent]
/// text, in place of [CruxCard] -- [CruxCard] has no background-color
/// parameter, so this is a small standalone container built from the same
/// semantic accent tokens instead.
class _AccentBubble extends StatelessWidget {
  const _AccentBubble({
    required this.message,
    required this.colors,
    required this.type,
  });

  final MimosaChatMessage message;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      decoration: ShapeDecoration(
        color: colors.accent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(CruxRadii.l),
        ),
      ),
      child: _BubbleText(
        message: message,
        type: type,
        textColor: colors.onAccent,
        timeColor: colors.onAccent.withValues(alpha: 0.55),
      ),
    );
  }
}

/// A bubble's shared content: [MimosaChatMessage.text] above
/// [MimosaChatMessage.timeLabel], both recolored per caller -- [textColor]
/// for the body and [timeColor] for the time label -- so the same layout
/// serves both [CruxCard]'s surface tone and [_AccentBubble]'s accent
/// tone.
class _BubbleText extends StatelessWidget {
  const _BubbleText({
    required this.message,
    required this.type,
    required this.textColor,
    required this.timeColor,
  });

  final MimosaChatMessage message;
  final CruxTypography type;
  final Color textColor;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message.text, style: type.body.copyWith(color: textColor)),
        const SizedBox(height: CruxSpacing.s4),
        Text(message.timeLabel, style: type.caption.copyWith(color: timeColor)),
      ],
    );
  }
}
