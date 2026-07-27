import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

/// One message in [ChatScreen]'s conversation: who sent it, what it says,
/// and a fixed, canned relative-time label (this sample has no backend
/// clock to format a real timestamp against, the same "no server" honesty
/// [LoginScreen] documents for its own success view).
class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });

  final String text;
  final bool isMe;
  final String time;
}

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a chat conversation reached from the home index's "チャット" row.
///
/// This demonstrates [CruxInputBar] in its two documented uses (IB-D13):
/// a single-line search bar that filters the conversation as the user
/// types, and a multi-line ([maxLines]: 5) composer pinned to the bottom of
/// the screen that grows and morphs into its two-row shape once a typed
/// message needs more than one line. Sending a message appends it to the
/// list below; the bubble list itself is built from [CruxCard], the same
/// general-purpose surface atom [TaskListScreen] uses for its own card.
///
/// This screen is deliberately a "this is what it looks like in a real
/// screen" demo, not a token or atom-state catalog — those full listings
/// live in `widgetbook/` instead. See root `CLAUDE.md`'s catalog operating
/// rule.
class ChatScreen extends StatefulWidget {
  /// Creates the chat sample screen.
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(text: 'こんにちは。今日の予定を教えてください。', isMe: false, time: '10分前'),
    const _ChatMessage(text: '午後2時から歯医者の予約があります。', isMe: true, time: '9分前'),
    const _ChatMessage(
      text: '了解しました。他に確認しておくことはありますか?',
      isMe: false,
      time: '8分前',
    ),
  ];

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _handleSend(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      // CruxInputBar's own submit button already refuses to fire this
      // callback while its text is empty (IB-D08's disabled tone), but the
      // return key path (IB-A03) still reaches onSubmit with whatever text
      // is present -- guarding here keeps a message of only whitespace from
      // ever being appended.
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isMe: true, time: 'たった今'));
    });
    _composerController.clear();
    // Scrolls to the newest message once the list has re-laid-out with it
    // -- addPostFrameCallback (not an immediate jumpTo) is what lets
    // maxScrollExtent already reflect the just-appended bubble's height.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    final List<_ChatMessage> visibleMessages = _searchQuery.isEmpty
        ? _messages
        : _messages
              .where(
                (_ChatMessage message) => message.text.contains(_searchQuery),
              )
              .toList();

    return Scaffold(
      backgroundColor: colors.background,
      // Scaffold's own default (true) already resizes this body to avoid
      // the on-screen keyboard, which is what keeps the composer pinned
      // just above it instead of hidden underneath -- named explicitly here
      // since that behavior is exactly what this screen relies on.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'チャット'),
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
              child: visibleMessages.isEmpty
                  ? Center(
                      child: Text(
                        '一致するメッセージが見つかりません',
                        style: type.body.copyWith(color: colors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CruxSpacing.s20,
                        vertical: CruxSpacing.s12,
                      ),
                      itemCount: visibleMessages.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _MessageBubble(
                          message: visibleMessages[index],
                          colors: colors,
                          type: type,
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CruxSpacing.s20,
                CruxSpacing.s8,
                CruxSpacing.s20,
                CruxSpacing.s12,
              ),
              child: CruxInputBar(
                controller: _composerController,
                placeholder: 'メッセージを入力',
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

/// One chat bubble in [ChatScreen]'s conversation list: a [CruxCard]
/// aligned to the trailing edge for the current user's own messages, the
/// leading edge for the other party's.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.colors,
    required this.type,
  });

  final _ChatMessage message;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final double maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Padding(
      padding: const EdgeInsets.only(bottom: CruxSpacing.s12),
      child: Align(
        alignment: message.isMe
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: CruxCard(
            radius: CruxRadii.l,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isMe) ...[
                  Text(
                    'ミモザ',
                    style: type.caption.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: CruxSpacing.s4),
                ],
                Text(
                  message.text,
                  style: type.body.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: CruxSpacing.s4),
                Text(
                  message.time,
                  style: type.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
