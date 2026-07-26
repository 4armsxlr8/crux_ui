import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';
import 'login_screen.dart';
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
  });

  final String title;
  final String subtitle;
  final WidgetBuilder builder;
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
];

Widget _buildLoginScreen(BuildContext context) => const LoginScreen();

Widget _buildTaskListScreen(BuildContext context) => const TaskListScreen();
