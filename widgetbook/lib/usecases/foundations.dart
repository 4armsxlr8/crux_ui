import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The `Foundations` entry in the catalog: a static overview of the design
/// tokens ([CruxColors], [CruxTypography], [CruxSpacing],
/// [CruxRadii]).
///
/// Foundations have no variant/size/selected/disabled axis the way an atom
/// does, so [_FoundationsPlayground] instead lets a visitor pick *which*
/// token of each of the four families to preview (a color name, a type
/// style + sample text, a spacing step, a radius step) and renders all four
/// selections live — the closest equivalent of "one widget driven entirely
/// by knobs" this component has. [FoundationsStatesMatrix] is the "every
/// token visible at once" overview and the golden-test target, matching the
/// role the States matrix use case plays for atoms.
WidgetbookComponent get foundationsComponent => WidgetbookComponent(
  name: 'Foundations',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) => const _FoundationsPlayground(),
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const FoundationsStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _FoundationsEdgeCases(),
    ),
  ],
);

/// The names of every [CruxColors] field, in the same order
/// [_ColorSwatchGrid] lists them.
const List<String> _colorTokenNames = <String>[
  'background',
  'surface',
  'accent',
  'accentTint',
  'accentLine',
  'textPrimary',
  'textSecondary',
  'muted',
  'separator',
  'success',
  'error',
  'controlFill',
  'onAccent',
];

Color _colorForToken(String name, CruxColors colors) {
  switch (name) {
    case 'background':
      return colors.background;
    case 'surface':
      return colors.surface;
    case 'accent':
      return colors.accent;
    case 'accentTint':
      return colors.accentTint;
    case 'accentLine':
      return colors.accentLine;
    case 'textPrimary':
      return colors.textPrimary;
    case 'textSecondary':
      return colors.textSecondary;
    case 'muted':
      return colors.muted;
    case 'separator':
      return colors.separator;
    case 'success':
      return colors.success;
    case 'error':
      return colors.error;
    case 'controlFill':
      return colors.controlFill;
    case 'onAccent':
    default:
      return colors.onAccent;
  }
}

/// The names of every [CruxTypography] style, in the same order
/// [_TypeScaleList] lists them.
const List<String> _typeStyleNames = <String>[
  'heading',
  'subheading',
  'title',
  'body',
  'labelSmall',
  'label',
  'navLabel',
  'caption',
  'captionStrong',
];

TextStyle _typeStyleForToken(String name, CruxTypography type) {
  switch (name) {
    case 'heading':
      return type.heading;
    case 'subheading':
      return type.subheading;
    case 'title':
      return type.title;
    case 'labelSmall':
      return type.labelSmall;
    case 'label':
      return type.label;
    case 'navLabel':
      return type.navLabel;
    case 'caption':
      return type.caption;
    case 'captionStrong':
      return type.captionStrong;
    case 'body':
    default:
      return type.body;
  }
}

/// The names of every [CruxSpacing] step, in the same order
/// [_SpacingList] lists them.
const List<String> _spacingTokenNames = <String>[
  's2',
  's4',
  's8',
  's12',
  's16',
  's20',
  's24',
  's32',
  's40',
  's48',
];

double _spacingForToken(String name) {
  switch (name) {
    case 's2':
      return CruxSpacing.s2;
    case 's4':
      return CruxSpacing.s4;
    case 's8':
      return CruxSpacing.s8;
    case 's12':
      return CruxSpacing.s12;
    case 's16':
      return CruxSpacing.s16;
    case 's20':
      return CruxSpacing.s20;
    case 's24':
      return CruxSpacing.s24;
    case 's32':
      return CruxSpacing.s32;
    case 's40':
      return CruxSpacing.s40;
    case 's48':
    default:
      return CruxSpacing.s48;
  }
}

/// The names of every [CruxRadii] step, in the same order [_RadiiList]
/// lists them.
const List<String> _radiusTokenNames = <String>['m', 'l', 'pill'];

double _radiusForToken(String name) {
  switch (name) {
    case 'm':
      return CruxRadii.m;
    case 'pill':
      return CruxRadii.pill;
    case 'l':
    default:
      return CruxRadii.l;
  }
}

/// Backs the Playground use case: four independently knob-driven previews,
/// one per token family, stacked in a single screen.
///
/// Each family exposes a dropdown over its token names (`context.knobs.
/// object.dropdown`, per `usecases/CONVENTIONS.md`'s confirmed API); the
/// type-scale preview additionally exposes a `context.knobs.string` for the
/// sample sentence, mirroring the "label text" knob every atom's Playground
/// has. All knobs are read unconditionally on every build (never gated
/// behind another knob's value), matching the stable-knob-panel convention
/// the other use-case files in this directory follow.
class _FoundationsPlayground extends StatelessWidget {
  const _FoundationsPlayground();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    final String colorName = context.knobs.object.dropdown<String>(
      label: 'Color token',
      options: _colorTokenNames,
      initialOption: 'accent',
    );
    final String typeStyleName = context.knobs.object.dropdown<String>(
      label: 'Type style',
      options: _typeStyleNames,
      initialOption: 'body',
    );
    final String sampleText = context.knobs.string(
      label: 'Type sample text',
      initialValue: 'はじめまして、ミモザです',
    );
    final String spacingName = context.knobs.object.dropdown<String>(
      label: 'Spacing token',
      options: _spacingTokenNames,
      initialOption: 's16',
    );
    final String radiusName = context.knobs.object.dropdown<String>(
      label: 'Radius token',
      options: _radiusTokenNames,
      initialOption: 'l',
    );

    final Color color = _colorForToken(colorName, colors);
    final TextStyle style = _typeStyleForToken(typeStyleName, type);
    final double spacingValue = _spacingForToken(spacingName);
    final double radiusValue = _radiusForToken(radiusName);
    final TextStyle tokenLabelStyle = type.caption.copyWith(
      color: colors.muted,
    );

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('カラー: $colorName', style: tokenLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            Container(
              width: 200,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(CruxRadii.m),
                border: Border.all(color: colors.separator),
              ),
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text('タイプスケール: $typeStyleName', style: tokenLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            Text(sampleText, style: style.copyWith(color: colors.textPrimary)),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              'スペーシング: $spacingName · ${spacingValue.toInt()}px',
              style: tokenLabelStyle,
            ),
            const SizedBox(height: CruxSpacing.s8),
            Container(
              height: 12,
              width: spacingValue * 3,
              color: colors.accent,
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              radiusName == 'pill'
                  ? 'Radii: pill (9999px)'
                  : 'Radii: $radiusName · ${radiusValue.toInt()}px',
              style: tokenLabelStyle,
            ),
            const SizedBox(height: CruxSpacing.s8),
            Container(
              width: 96,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accentTint,
                borderRadius: BorderRadius.circular(radiusValue),
                border: Border.all(color: colors.accentLine),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single screen listing every color, type-scale, spacing, and radius
/// token at once.
///
/// Takes no [CruxTheme] dependency of its own — it reads colors and type
/// styles only through whatever [CruxTheme.of] resolves to from its
/// surrounding context (falling back to [CruxThemeData.light] if none is
/// provided), so it renders correctly as a bare widget with just a
/// [CruxTheme] (or a plain [Directionality]) above it. This is the
/// widget `widgetbook/test/golden_test.dart` is expected to pump directly.
class FoundationsStatesMatrix extends StatelessWidget {
  /// Creates the foundations token overview.
  const FoundationsStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return ColoredBox(
      color: colors.background,
      // Four token-family sections stacked add up to more height than a
      // small preview pane offers, which used to overflow with Flutter's
      // yellow-and-black stripes instead of just scrolling past the fold.
      // SingleChildScrollView keeps every section reachable regardless of
      // the surrounding viewport's height; at the golden test's generous
      // 900×4000 canvas the content already fits, so this is a no-op there
      // (see `text_form_field.dart`'s Edge cases for the same pattern).
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionHeading('カラー', colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s16),
            _ColorSwatchGrid(colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s40),
            _SectionHeading('タイプスケール', colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s16),
            _TypeScaleList(colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s40),
            _SectionHeading('スペーシング', colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s16),
            _SpacingList(colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s40),
            _SectionHeading('Radii', colors: colors, type: type),
            const SizedBox(height: CruxSpacing.s16),
            _RadiiList(colors: colors, type: type),
          ],
        ),
      ),
    );
  }
}

/// A section label styled with [CruxTypography.headline].
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label, {required this.colors, required this.type});

  final String label;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: type.subheading.copyWith(color: colors.textPrimary),
    );
  }
}

/// Every [CruxColors] semantic token as a swatch + name + hex/rgba value.
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
      ('controlFill', colors.controlFill),
      ('onAccent', colors.onAccent),
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
              borderRadius: BorderRadius.circular(CruxRadii.m),
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

/// Formats [color] the way it is documented in the design token ledger: an
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

/// The six [CruxTypography] styles, each rendered with a Japanese sample
/// sentence.
class _TypeScaleList extends StatelessWidget {
  const _TypeScaleList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String, TextStyle, String)> entries =
        <(String, TextStyle, String)>[
          ('heading', type.heading, 'はじめまして、ミモザです'),
          ('subheading', type.subheading, 'マイページ'),
          ('title', type.title, '今週のハイライト'),
          (
            'body',
            type.body,
            '通知の設定はあとからいつでも変更できます。まずは気になるトピックだけをオンにして、様子を見ながら調整していきましょう。',
          ),
          ('labelSmall', type.labelSmall, 'すべて見る'),
          ('label', type.label, 'はじめる'),
          ('navLabel', type.navLabel, 'ホーム'),
          ('caption', type.caption, '3分前に更新'),
          ('captionStrong', type.captionStrong, '必須項目です'),
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

/// The ten [CruxSpacing] steps, each shown as a name, its pixel value,
/// and a bar whose width is proportional to that value.
class _SpacingList extends StatelessWidget {
  const _SpacingList({required this.colors, required this.type});

  // A fixed multiplier applied to every step, purely so the smallest steps
  // (2px, 4px) still render as a visible bar; the widths stay proportional
  // to each other either way.
  static const double _barScale = 3;

  final CruxColors colors;
  final CruxTypography type;

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

/// The three [CruxRadii] steps, each shown as a name, its pixel value,
/// and a box rounded by that radius.
class _RadiiList extends StatelessWidget {
  const _RadiiList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String, double)> entries = <(String, double)>[
      ('m', CruxRadii.m),
      ('l', CruxRadii.l),
      ('pill', CruxRadii.pill),
    ];

    return Wrap(
      spacing: CruxSpacing.s16,
      runSpacing: CruxSpacing.s16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (name, value) in entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 96,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(value),
                  border: Border.all(color: colors.accentLine),
                ),
              ),
              const SizedBox(height: CruxSpacing.s8),
              Text(
                name == 'pill' ? 'pill (9999px)' : '$name · ${value.toInt()}px',
                style: type.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}

/// A fixed set of layouts chosen to stress the foundations tokens: a
/// color/spacing label crammed into an 80px-wide column, the longest type
/// sample wrapping in that same narrow width, the smallest spacing steps
/// rendered at their true (unscaled) pixel size, and [CruxRadii.pill]
/// applied to a rectangle whose shortest side is much smaller than the
/// radius value itself (proving it still resolves to a full stadium
/// instead of overshooting the corner).
class _FoundationsEdgeCases extends StatelessWidget {
  const _FoundationsEdgeCases();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return ColoredBox(
      color: colors.background,
      // These four stacked cases add up to more height than a small
      // preview pane offers, which used to overflow with Flutter's
      // yellow-and-black stripes instead of just scrolling past the fold.
      // SingleChildScrollView keeps every case reachable regardless of the
      // surrounding viewport's height, mirroring the fix already applied to
      // `text_form_field.dart`'s Edge cases.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '80px 幅: 最長トークン名 + rgba 値',
              style: type.caption.copyWith(color: colors.muted),
            ),
            const SizedBox(height: CruxSpacing.s8),
            SizedBox(
              width: 80,
              child: _ColorSwatchTile(
                name: 'textSecondary',
                color: colors.textSecondary,
                colors: colors,
                type: type,
              ),
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              '80px 幅: 最長の body サンプル文',
              style: type.caption.copyWith(color: colors.muted),
            ),
            const SizedBox(height: CruxSpacing.s8),
            SizedBox(
              width: 80,
              child: Text(
                '通知の設定はあとからいつでも変更できます。まずは気になるトピックだけをオンにして、様子を見ながら調整していきましょう。',
                style: type.body.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              '最小スペーシング (s2/s4) を実寸で並べたバー',
              style: type.caption.copyWith(color: colors.muted),
            ),
            const SizedBox(height: CruxSpacing.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 24,
                  width: CruxSpacing.s2,
                  color: colors.accent,
                ),
                const SizedBox(width: CruxSpacing.s4),
                Container(
                  height: 24,
                  width: CruxSpacing.s4,
                  color: colors.accent,
                ),
                const SizedBox(width: CruxSpacing.s4),
                Container(
                  height: 24,
                  width: CruxSpacing.s8,
                  color: colors.accent,
                ),
              ],
            ),
            const SizedBox(height: CruxSpacing.s32),
            Text(
              'CruxRadii.pill を 28×80px の細長い矩形に適用',
              style: type.caption.copyWith(color: colors.muted),
            ),
            const SizedBox(height: CruxSpacing.s8),
            Container(
              width: 80,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(CruxRadii.pill),
              ),
              child: Text(
                'pill',
                style: type.label.copyWith(color: colors.onAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
