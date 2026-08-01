import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';
import 'chat_screen.dart';
import 'compose_screen.dart';
import 'login_screen.dart';
import 'sync_screen.dart';
import 'task_list_screen.dart';

/// The app's home screen: an index of the sample screens in this gallery,
/// one per component use case, built from [CruxListTile] and
/// [CruxDivider] — which makes this index itself a real use of those two
/// atoms, not just a menu to reach the others.
///
/// Per root `CLAUDE.md`'s catalog operating rule, this gallery never grows a
/// token table or a per-variant state grid (that is what `widgetbook/` is
/// for); it only ever grows one more row here plus one more screen file
/// under `screens/` when a use case is not yet represented.
class HomeIndexPage extends StatelessWidget {
  /// Creates the home index page.
  const HomeIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Crux UI Sample'),
            Expanded(
              child: ListView(
                children: [
                  for (int i = 0; i < _sampleScreens.length; i++) ...[
                    CruxListTile(
                      title: _sampleScreens[i].title,
                      subtitle: _sampleScreens[i].subtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: _sampleScreens[i].builder,
                          fullscreenDialog: _sampleScreens[i].fullscreenDialog,
                        ),
                      ),
                    ),
                    if (i != _sampleScreens.length - 1)
                      const CruxDivider(indent: CruxSpacing.s16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of [HomeIndexPage]'s index: a title, a subtitle describing what
/// the screen demonstrates, and the screen itself.
class _SampleScreenEntry {
  const _SampleScreenEntry({
    required this.title,
    required this.subtitle,
    required this.builder,
    this.fullscreenDialog = false,
  });

  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  /// Whether this entry's screen is pushed as a modal
  /// (`MaterialPageRoute.fullscreenDialog`) rather than a regular push. Used
  /// by the "新規投稿" row: composing a post is a transient, cancel-or
  /// -commit task, the kind of thing conventionally presented as a sheet
  /// over the current screen rather than another push in the same stack.
  final bool fullscreenDialog;
}

/// The gallery's sample screens. Add one entry here alongside a new file
/// under `screens/` whenever a component's use case is not yet represented.
final List<_SampleScreenEntry> _sampleScreens = <_SampleScreenEntry>[
  _SampleScreenEntry(
    title: 'ログイン',
    subtitle: 'CruxTextFormField と Form によるバリデーション付きログインフォーム',
    builder: _buildLoginScreen,
  ),
  _SampleScreenEntry(
    title: 'タスク一覧',
    subtitle: 'カード・チップ・リストなど複数の atom を組み合わせたタスク管理画面',
    builder: _buildTaskListScreen,
  ),
  _SampleScreenEntry(
    title: 'チャット',
    subtitle: 'CruxInputBar による検索欄とチャット入力欄、送信で増える吹き出しリスト',
    builder: _buildChatScreen,
  ),
  _SampleScreenEntry(
    title: '新規投稿',
    subtitle: 'CruxComposer による投稿本文の入力、文字数上限と画像添付ボタン付き（フルスクリーンダイアログで開く）',
    builder: _buildComposeScreen,
    fullscreenDialog: true,
  ),
  _SampleScreenEntry(
    title: '同期',
    subtitle: 'CruxSpinner による同期中表示と、完了後の同期済みリスト・再同期ボタン',
    builder: _buildSyncScreen,
  ),
];

Widget _buildLoginScreen(BuildContext context) => const LoginScreen();

Widget _buildTaskListScreen(BuildContext context) => const TaskListScreen();

Widget _buildChatScreen(BuildContext context) => const ChatScreen();

Widget _buildComposeScreen(BuildContext context) => const ComposeScreen();

Widget _buildSyncScreen(BuildContext context) => const SyncScreen();
