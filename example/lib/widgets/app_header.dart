import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../theme_mode_scope.dart';

/// The header band shared by every screen in this gallery: a title, a back
/// affordance on any screen reached by pushing (every screen but the home
/// index), and the light/dark toggle.
///
/// The toggle's state and callback come from the ambient [ThemeModeScope]
/// rather than a constructor parameter, so adding a new screen for a future
/// component's use case never means threading `isDark`/`onDarkChanged`
/// through it — it only needs to include this widget.
///
/// This is a plain [Container], not Material's [AppBar]: [AppBar] paints
/// itself from the ambient Material `ThemeData`, which this app deliberately
/// never customizes (see root `CLAUDE.md`), so it would always show
/// Material's default look regardless of the active [CruxThemeData] and
/// never follow the light/dark toggle. The back control is likewise a plain
/// [GestureDetector] over a Crux-colored icon, the same "no Material
/// dependency for anything that must follow the toggle" approach
/// [CruxListTile] and friends already take, rather than a Material
/// [IconButton].
class AppHeader extends StatelessWidget {
  /// Creates the shared header, labeled [title].
  const AppHeader({super.key, required this.title});

  /// The text shown in the header.
  final String title;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final ThemeModeScope themeMode = ThemeModeScope.of(context);
    final bool canPop = Navigator.of(context).canPop();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: CruxSpacing.s20,
        vertical: CruxSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.separator)),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            Semantics(
              button: true,
              label: '戻る',
              child: GestureDetector(
                onTap: Navigator.of(context).pop,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: CruxSpacing.s4),
          ],
          Expanded(
            child: Text(
              title,
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: CruxSpacing.s12),
          Icon(Icons.light_mode, size: 18, color: colors.textSecondary),
          const SizedBox(width: CruxSpacing.s8),
          Semantics(
            label: 'ダーク表示の切り替え',
            child: CruxSwitch(
              value: themeMode.isDark,
              onChanged: themeMode.onDarkChanged,
            ),
          ),
          const SizedBox(width: CruxSpacing.s8),
          Icon(Icons.dark_mode, size: 18, color: colors.textSecondary),
        ],
      ),
    );
  }
}
