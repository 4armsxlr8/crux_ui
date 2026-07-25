import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  runApp(const CruxExampleApp());
}

/// Root widget of the showcase app.
///
/// Holds which [CruxThemeData] (light or dark) is currently active and
/// provides it to the whole subtree via [CruxTheme]. Note that this does
/// not create or touch a Material [ThemeData]: [MaterialApp] below is only
/// used as the app shell it must be (for [Scaffold], routing, and so on),
/// its default `ThemeData` is never read or customized, and every visible
/// pixel is painted by widgets that read colors and type styles straight
/// from [CruxTheme.of] so that they follow the toggle.
class CruxExampleApp extends StatefulWidget {
  /// Creates the example app.
  const CruxExampleApp({super.key});

  @override
  State<CruxExampleApp> createState() => _CruxExampleAppState();
}

class _CruxExampleAppState extends State<CruxExampleApp> {
  CruxThemeData _cruxTheme = CruxThemeData.light();

  void _setDark(bool isDark) {
    setState(() {
      _cruxTheme = isDark ? CruxThemeData.dark() : CruxThemeData.light();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CruxTheme(
      data: _cruxTheme,
      child: MaterialApp(
        title: 'Crux UI Sample',
        debugShowCheckedModeBanner: false,
        home: SampleHomePage(
          isDark: _cruxTheme.brightness == Brightness.dark,
          onDarkChanged: _setDark,
        ),
      ),
    );
  }
}

/// The single showcase screen: a header (with the light/dark toggle) and
/// one real-world sample composed only from Crux atoms.
///
/// This app is deliberately a "this is what it looks like in a real
/// screen" demo, not a token or atom-state catalog — those full listings
/// (color/type/spacing tables, per-variant × per-state grids, edge cases)
/// live in `widgetbook/` instead. See root `CLAUDE.md`'s catalog operating
/// rule: every new component gets its widgetbook use-cases + goldens there,
/// while this app only ever grows the one contextual sample below.
class SampleHomePage extends StatelessWidget {
  /// Creates the sample home page.
  const SampleHomePage({
    super.key,
    required this.isDark,
    required this.onDarkChanged,
  });

  /// Whether the dark Crux theme is currently selected.
  final bool isDark;

  /// Called when the light/dark toggle changes.
  final ValueChanged<bool> onDarkChanged;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              colors: colors,
              type: type,
              isDark: isDark,
              onDarkChanged: onDarkChanged,
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: colors.background,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(CruxSpacing.s20),
                  child: _SampleScreen(colors: colors, type: type),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A self-built header band, replacing Material's [AppBar].
///
/// [AppBar] paints itself with the ambient Material `ThemeData` (which this
/// app deliberately never customizes, per K11), so it always shows
/// Material's default purple regardless of the active [CruxThemeData] and
/// never follows the light/dark toggle. This header instead is a plain
/// [Container] painted with [CruxColors.background] and text/icons in
/// Crux tokens, so it repaints with the rest of the page whenever the
/// toggle flips.
class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.type,
    required this.isDark,
    required this.onDarkChanged,
  });

  final CruxColors colors;
  final CruxTypography type;
  final bool isDark;
  final ValueChanged<bool> onDarkChanged;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Text(
              'Crux UI Sample',
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: CruxSpacing.s12),
          Icon(Icons.light_mode, size: 18, color: colors.textSecondary),
          const SizedBox(width: CruxSpacing.s8),
          Semantics(
            label: 'ダーク表示の切り替え',
            child: CruxSwitch(value: isDark, onChanged: onDarkChanged),
          ),
          const SizedBox(width: CruxSpacing.s8),
          Icon(Icons.dark_mode, size: 18, color: colors.textSecondary),
        ],
      ),
    );
  }
}

/// The real-world sample: a small screen (card, chips, list) built from
/// real Crux atoms ([CruxCard], [CruxButton], [CruxChip],
/// [CruxListTile], [CruxDivider]) used together the way a consuming app
/// actually would, rather than as an isolated per-variant grid.
class _SampleScreen extends StatelessWidget {
  const _SampleScreen({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Only vertical padding here: the list section (_DemoList) must sit
      // flush against this container's own left/right edges, so its
      // CruxListTile rows' own default horizontal padding is what
      // produces the visual inset — and so a pressed row's state-layer
      // highlight runs edge-to-edge of this rounded container, iOS
      // Settings-app style, instead of stopping short at some extra gutter.
      // _DemoCard and _DemoChipRow are not full-bleed, so each wraps itself
      // in its own horizontal Padding below to keep the same inset they had
      // before.
      padding: const EdgeInsets.symmetric(vertical: CruxSpacing.s16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CruxSpacing.s16),
            child: _DemoCard(colors: colors, type: type),
          ),
          const SizedBox(height: CruxSpacing.s24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: CruxSpacing.s16),
            child: _DemoChipRow(),
          ),
          const SizedBox(height: CruxSpacing.s24),
          _DemoList(colors: colors, type: type),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日のミモザ', style: type.title.copyWith(color: colors.textPrimary)),
          const SizedBox(height: CruxSpacing.s8),
          Text(
            'おすすめのタスクを3件見つけました。空いた時間に少しずつ進めましょう。',
            style: type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: CruxSpacing.s16),
          Align(
            alignment: Alignment.centerLeft,
            child: CruxButton(
              label: 'はじめる',
              variant: CruxButtonVariant.tonal,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of [CruxChip]s: two toggle their own [CruxChip.selected] state
/// on tap, and the third is a fixed disabled example (mirroring the
/// previous mock's "muted" chip).
class _DemoChipRow extends StatefulWidget {
  const _DemoChipRow();

  @override
  State<_DemoChipRow> createState() => _DemoChipRowState();
}

class _DemoChipRowState extends State<_DemoChipRow> {
  bool _recommendedSelected = true;
  bool _dueTodaySelected = false;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CruxSpacing.s8,
      runSpacing: CruxSpacing.s8,
      children: [
        CruxChip(
          label: 'おすすめ',
          selected: _recommendedSelected,
          onTap: () =>
              setState(() => _recommendedSelected = !_recommendedSelected),
        ),
        CruxChip(
          label: '今日中',
          selected: _dueTodaySelected,
          onTap: () => setState(() => _dueTodaySelected = !_dueTodaySelected),
        ),
        const CruxChip(label: '下書き', onTap: null),
      ],
    );
  }
}

/// The [CruxDivider.indent] that aligns a divider's start with where each
/// row's title text starts: [CruxListTile]'s own default horizontal
/// padding ([CruxSpacing.s16]) + its 44 logical pixel `leading` frame +
/// the [CruxSpacing.s12] gap between `leading` and the title. Now that
/// `_SampleScreen`'s list section is full-bleed (no horizontal padding of
/// its own) and each row supplies its own inset instead, this indent must
/// grow by that same [CruxSpacing.s16] to keep lining up with the title.
const double _demoListDividerIndent =
    CruxSpacing.s16 + 44 + CruxSpacing.s12;

class _DemoList extends StatelessWidget {
  const _DemoList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String?, String, String?, String?)> rows =
        <(String?, String, String?, String?)>[
          ('📝', '買い物メモを作成', '週末の買い出し用', '10分前'),
          ('📅', '歯医者の予約確認', '来週火曜 14:00', '1時間前'),
          ('💬', '友達からのメッセージ', '週末どこ行く?', '昨日'),
          // Title-only row: no subtitle, showing the single-line variant.
          ('☕', 'コーヒー豆を注文', null, '3日前'),
          // Most compact form: title only, no leading/subtitle/trailing.
          (null, 'アーカイブをすべて見る', null, null),
        ];

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          CruxListTile(
            leading: rows[i].$1 == null
                ? null
                : _DemoListIcon(icon: rows[i].$1!, colors: colors),
            title: rows[i].$2,
            subtitle: rows[i].$3,
            trailing: rows[i].$4,
            onTap: () {},
          ),
          if (i != rows.length - 1)
            const CruxDivider(indent: _demoListDividerIndent),
        ],
      ],
    );
  }
}

/// The small emoji-in-a-circle leading widget for each [_DemoList] row.
class _DemoListIcon extends StatelessWidget {
  const _DemoListIcon({required this.icon, required this.colors});

  final String icon;
  final CruxColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accentTint,
        shape: BoxShape.circle,
      ),
      child: Text(icon),
    );
  }
}
