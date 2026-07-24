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
        title: 'Crux UI Tokens',
        debugShowCheckedModeBanner: false,
        home: TokenShowcasePage(
          isDark: _cruxTheme.brightness == Brightness.dark,
          onDarkChanged: _setDark,
        ),
      ),
    );
  }
}

/// The single showcase screen: color swatches, type scale, spacing scale,
/// and a small real-world sample composed only from Crux tokens.
class TokenShowcasePage extends StatelessWidget {
  /// Creates the showcase page.
  const TokenShowcasePage({
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: CruxSpacing.s20,
                    vertical: CruxSpacing.s24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeading('01', 'カラー', colors: colors, type: type),
                      const SizedBox(height: CruxSpacing.s16),
                      _ColorSwatchGrid(colors: colors, type: type),
                      const SizedBox(height: CruxSpacing.s40),
                      _SectionHeading(
                        '02',
                        'タイプスケール',
                        colors: colors,
                        type: type,
                      ),
                      const SizedBox(height: CruxSpacing.s16),
                      _TypeScaleList(colors: colors, type: type),
                      const SizedBox(height: CruxSpacing.s40),
                      _SectionHeading(
                        '03',
                        'スペーシング',
                        colors: colors,
                        type: type,
                      ),
                      const SizedBox(height: CruxSpacing.s16),
                      _SpacingList(colors: colors, type: type),
                      const SizedBox(height: CruxSpacing.s40),
                      _SectionHeading(
                        '04',
                        '実戦サンプル',
                        colors: colors,
                        type: type,
                      ),
                      const SizedBox(height: CruxSpacing.s16),
                      _SampleScreen(colors: colors, type: type),
                      const SizedBox(height: CruxSpacing.s48),
                    ],
                  ),
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
              'Crux UI Tokens',
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: CruxSpacing.s12),
          Icon(Icons.light_mode, size: 18, color: colors.textSecondary),
          const SizedBox(width: CruxSpacing.s8),
          _ThemeToggle(
            colors: colors,
            isDark: isDark,
            onChanged: onDarkChanged,
          ),
          const SizedBox(width: CruxSpacing.s8),
          Icon(Icons.dark_mode, size: 18, color: colors.textSecondary),
        ],
      ),
    );
  }
}

/// A light/dark toggle built only from plain widgets and [CruxColors]
/// tokens, replacing Material's [Switch].
///
/// [Switch] paints itself with the ambient Material `ThemeData`'s default
/// accent (purple), independent of the active [CruxThemeData]. This
/// widget instead animates a pill-shaped track (accent when on, separator
/// when off) with a surface-colored thumb, so its colors come entirely from
/// the current [CruxColors] and follow the toggle like everything else on
/// the page.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({
    required this.colors,
    required this.isDark,
    required this.onChanged,
  });

  final CruxColors colors;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  static const double _trackWidth = 52;
  static const double _trackHeight = 28;
  static const double _thumbSize = 22;
  static const double _thumbInset = 3;
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: isDark,
      label: 'ダーク表示の切り替え',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!isDark),
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          width: _trackWidth,
          height: _trackHeight,
          padding: const EdgeInsets.symmetric(horizontal: _thumbInset),
          decoration: BoxDecoration(
            color: isDark ? colors.accent : colors.separator,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
          ),
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            width: _thumbSize,
            height: _thumbSize,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A "NN Title" section heading, styled with Crux's label + headline
/// tokens.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(
    this.number,
    this.label, {
    required this.colors,
    required this.type,
  });

  final String number;
  final String label;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(number, style: type.label.copyWith(color: colors.accent)),
        const SizedBox(width: CruxSpacing.s12),
        Text(label, style: type.headline.copyWith(color: colors.textPrimary)),
      ],
    );
  }
}

/// Section (a): every [CruxColors] semantic token as a swatch + name +
/// hex/rgba value.
class _ColorSwatchGrid extends StatelessWidget {
  const _ColorSwatchGrid({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String, Color)> entries = <(String, Color)>[
      ('background', colors.background),
      ('surface', colors.surface),
      ('accent', colors.accent),
      ('accentTint', colors.accentTint),
      ('accentLine', colors.accentLine),
      ('textPrimary', colors.textPrimary),
      ('textSecondary', colors.textSecondary),
      ('muted', colors.muted),
      ('separator', colors.separator),
      ('success', colors.success),
      ('error', colors.error),
    ];

    return Wrap(
      spacing: CruxSpacing.s12,
      runSpacing: CruxSpacing.s12,
      children: [
        for (final (name, color) in entries)
          _ColorSwatchTile(
            name: name,
            color: color,
            colors: colors,
            type: type,
          ),
      ],
    );
  }
}

class _ColorSwatchTile extends StatelessWidget {
  const _ColorSwatchTile({
    required this.name,
    required this.color,
    required this.colors,
    required this.type,
  });

  final String name;
  final Color color;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.separator),
            ),
          ),
          const SizedBox(height: CruxSpacing.s8),
          Text(name, style: type.label.copyWith(color: colors.textPrimary)),
          Text(
            _swatchValueLabel(color),
            style: type.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Formats [color] as it is documented in the design token ledger: an
/// opaque color as `#RRGGBB`, a semi-transparent one as `rgba(r, g, b, a)`.
/// Derived from the [Color]'s own channel values so the ledger's raw
/// numbers never need to be duplicated here.
String _swatchValueLabel(Color color) {
  final int alpha255 = (color.a * 255).round();
  final int r = (color.r * 255).round();
  final int g = (color.g * 255).round();
  final int b = (color.b * 255).round();
  if (alpha255 >= 255) {
    return '#${_hex2(r)}${_hex2(g)}${_hex2(b)}';
  }
  return 'rgba($r, $g, $b, ${color.a.toStringAsFixed(2)})';
}

String _hex2(int value) =>
    value.toRadixString(16).padLeft(2, '0').toUpperCase();

/// Section (b): the six [CruxTypography] styles, each rendered with a
/// Japanese sample sentence.
class _TypeScaleList extends StatelessWidget {
  const _TypeScaleList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String, TextStyle, String)> entries =
        <(String, TextStyle, String)>[
          ('display', type.display, 'はじめまして、ミモザです'),
          ('headline', type.headline, 'マイページ'),
          ('title', type.title, '今週のハイライト'),
          (
            'body',
            type.body,
            '通知の設定はあとからいつでも変更できます。まずは気になるトピックだけをオンにして、様子を見ながら調整していきましょう。',
          ),
          ('label', type.label, 'はじめる'),
          ('caption', type.caption, '3分前に更新'),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style, sample) in entries) ...[
          Text(name, style: type.caption.copyWith(color: colors.muted)),
          const SizedBox(height: CruxSpacing.s4),
          Text(sample, style: style.copyWith(color: colors.textPrimary)),
          const SizedBox(height: CruxSpacing.s20),
        ],
      ],
    );
  }
}

/// Section (c): the ten [CruxSpacing] steps, each shown as a name, its
/// pixel value, and a bar whose width is proportional to that value.
class _SpacingList extends StatelessWidget {
  const _SpacingList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  // A fixed multiplier applied to every step, purely so the smallest steps
  // (2px, 4px) still render as a visible bar; the widths stay proportional
  // to each other either way.
  static const double _barScale = 3;

  @override
  Widget build(BuildContext context) {
    final List<(String, double)> entries = <(String, double)>[
      ('s2', CruxSpacing.s2),
      ('s4', CruxSpacing.s4),
      ('s8', CruxSpacing.s8),
      ('s12', CruxSpacing.s12),
      ('s16', CruxSpacing.s16),
      ('s20', CruxSpacing.s20),
      ('s24', CruxSpacing.s24),
      ('s32', CruxSpacing.s32),
      ('s40', CruxSpacing.s40),
      ('s48', CruxSpacing.s48),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, value) in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: CruxSpacing.s8),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    '$name · ${value.toInt()}px',
                    style: type.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                Container(
                  height: 12,
                  width: value * _barScale,
                  color: colors.accent,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Section (d): a small real-world sample screen (card, chips, list) built
/// only from plain widgets and Crux tokens.
class _SampleScreen extends StatelessWidget {
  const _SampleScreen({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DemoCard(colors: colors, type: type),
          const SizedBox(height: CruxSpacing.s24),
          _ChipRow(colors: colors, type: type),
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
    return Container(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.separator),
      ),
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
            child: _AccentPillButton(label: 'はじめる', colors: colors, type: type),
          ),
        ],
      ),
    );
  }
}

/// A button-look element styled the same way the reference mock styles its
/// pill-shaped affordances (accent-tinted fill, accent-line border) rather
/// than a solid accent fill, so it only ever needs the officially defined
/// [CruxColors] tokens (no extra "on-accent" color).
///
/// The label uses [CruxColors.textPrimary] rather than [CruxColors.accent]
/// for the text: over the low-opacity [CruxColors.accentTint] fill, accent
/// text only reaches about 2.53:1 in light mode (fails WCAG AA's 4.5:1 for
/// normal text), while textPrimary reaches well over 12:1 in both light and
/// dark. See implementation-notes.md for the measured contrast values.
class _AccentPillButton extends StatelessWidget {
  const _AccentPillButton({
    required this.label,
    required this.colors,
    required this.type,
  });

  final String label;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CruxSpacing.s16,
        vertical: CruxSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: colors.accentTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accentLine),
      ),
      child: Text(label, style: type.label.copyWith(color: colors.textPrimary)),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CruxSpacing.s8,
      runSpacing: CruxSpacing.s8,
      children: [
        _Chip(label: 'おすすめ', colors: colors, type: type, muted: false),
        _Chip(label: '今日中', colors: colors, type: type, muted: false),
        _Chip(label: '下書き', colors: colors, type: type, muted: true),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.colors,
    required this.type,
    required this.muted,
  });

  final String label;
  final CruxColors colors;
  final CruxTypography type;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color background = muted ? colors.surface : colors.accentTint;
    final Color border = muted ? colors.separator : colors.accentLine;
    // Non-muted chips use textPrimary (not accent) for the label, for the
    // same WCAG AA contrast reason as _AccentPillButton above.
    final Color textColor = muted ? colors.textSecondary : colors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CruxSpacing.s12,
        vertical: CruxSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(label, style: type.label.copyWith(color: textColor)),
    );
  }
}

class _DemoList extends StatelessWidget {
  const _DemoList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, String, String)> rows =
        <(String, String, String, String)>[
          ('📝', '買い物メモを作成', '週末の買い出し用', '10分前'),
          ('📅', '歯医者の予約確認', '来週火曜 14:00', '1時間前'),
          ('💬', '友達からのメッセージ', '週末どこ行く?', '昨日'),
        ];

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _DemoListRow(
            icon: rows[i].$1,
            title: rows[i].$2,
            subtitle: rows[i].$3,
            time: rows[i].$4,
            colors: colors,
            type: type,
          ),
          if (i != rows.length - 1)
            Divider(
              height: CruxSpacing.s24,
              thickness: 1,
              color: colors.separator,
            ),
        ],
      ],
    );
  }
}

class _DemoListRow extends StatelessWidget {
  const _DemoListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.colors,
    required this.type,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String time;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accentTint,
            shape: BoxShape.circle,
          ),
          child: Text(icon),
        ),
        const SizedBox(width: CruxSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: type.title.copyWith(color: colors.textPrimary),
              ),
              Text(
                subtitle,
                style: type.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: CruxSpacing.s12),
        Text(time, style: type.caption.copyWith(color: colors.muted)),
      ],
    );
  }
}
