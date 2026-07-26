import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A show/hide toggle built from plain text glyphs rather than any real
/// icon system -- demonstrating [CruxObscureToggle]'s "any [Widget]
/// works" contract (see its class doc) without pulling an icon font
/// dependency into this catalog file. Shared by every use case below that
/// demonstrates the toggle.
CruxObscureToggle get _demoObscureToggle => const CruxObscureToggle(
  obscuredIcon: Text('👁'),
  revealedIcon: Text('🙈'),
  obscuredLabel: '表示する',
  revealedLabel: '隠す',
);

/// The `CruxTextFormField` entry in the catalog: Playground, States
/// matrix, and Edge cases use cases. See `usecases/CONVENTIONS.md` for the
/// contract this file follows.
WidgetbookComponent get textFormFieldComponent => WidgetbookComponent(
  name: 'TextFormField',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final String label = context.knobs.string(
          label: 'label',
          initialValue: 'メールアドレス',
        );
        final String placeholder = context.knobs.string(
          label: 'placeholder',
          initialValue: 'you@example.com',
        );
        final bool hasHelperText = context.knobs.boolean(
          label: 'Has helper text',
          initialValue: true,
        );
        final String helperText = context.knobs.string(
          label: 'helperText',
          initialValue: 'ログインに使用します',
        );
        final String initialValue = context.knobs.string(
          label: 'initialValue',
          initialValue: '',
        );
        final bool enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final bool obscureText = context.knobs.boolean(
          label: 'obscureText',
          initialValue: false,
        );
        final bool showObscureToggle = context.knobs.boolean(
          label: 'Show obscure toggle',
          initialValue: false,
        );
        final bool hasError = context.knobs.boolean(
          label: 'Show error',
          initialValue: false,
        );
        final String errorText = context.knobs.string(
          label: 'errorText',
          initialValue: '必須項目です',
        );

        // Keyed on initialValue alone: that is the only knob here that
        // seeds _TextFormFieldPlayground's own mutable state (the
        // TextEditingController's starting text). Every other knob
        // (label/placeholder/helperText/enabled/obscureText/hasError/
        // errorText) is forwarded straight through to CruxTextFormField
        // on every rebuild, the same way _buildPlayground does in card.dart
        // / list_tile.dart, so changing them updates the live field in
        // place instead of restarting the demo.
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(CruxSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _TextFormFieldPlayground(
                key: ValueKey<String>(initialValue),
                initialValue: initialValue,
                label: label,
                placeholder: placeholder,
                helperText: hasHelperText ? helperText : null,
                enabled: enabled,
                obscureText: obscureText,
                obscureToggle: showObscureToggle ? _demoObscureToggle : null,
                hasError: hasError,
                errorText: errorText,
              ),
            ),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const TextFormFieldStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _TextFormFieldEdgeCases(),
    ),
  ],
);

/// Backs the Playground use case: renders one [CruxTextFormField] the
/// visitor can actually type into, seeded from the `initialValue` knob. A
/// plain [CruxTextFormField] built straight from knobs would need its own
/// `controller`, and nothing would own that controller across rebuilds
/// (each knob change would otherwise hand the field a brand-new, empty
/// controller) — so this small [StatefulWidget] owns the live
/// [TextEditingController] the same way any real caller of
/// [CruxTextFormField] with a controller must, mirroring switch_.dart's
/// `_SwitchPlayground`.
class _TextFormFieldPlayground extends StatefulWidget {
  const _TextFormFieldPlayground({
    super.key,
    required this.initialValue,
    required this.label,
    required this.placeholder,
    required this.helperText,
    required this.enabled,
    required this.obscureText,
    required this.obscureToggle,
    required this.hasError,
    required this.errorText,
  });

  final String initialValue;
  final String label;
  final String placeholder;
  final String? helperText;
  final bool enabled;
  final bool obscureText;
  final CruxObscureToggle? obscureToggle;
  final bool hasError;
  final String errorText;

  @override
  State<_TextFormFieldPlayground> createState() =>
      _TextFormFieldPlaygroundState();
}

class _TextFormFieldPlaygroundState extends State<_TextFormFieldPlayground> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CruxTextFormField(
      controller: _controller,
      label: widget.label,
      placeholder: widget.placeholder,
      helperText: widget.helperText,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      obscureToggle: widget.obscureToggle,
      // AutovalidateMode.always makes CruxTextFormField call validator on
      // every build (confirmed against the Flutter SDK's
      // FormFieldState.build, which does this regardless of whether a Form
      // ancestor exists), so toggling the "Show error" knob surfaces
      // errorText's caption immediately without needing a surrounding Form
      // or a manual validate() call.
      autovalidateMode: widget.hasError
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      validator: widget.hasError ? (String? _) => widget.errorText : null,
    );
  }
}

/// The States matrix widget for `CruxTextFormField`: 空 (empty) / 入力済み
/// (filled) / エラー (error) / 無効 (disabled) / 補助文言つき (with helper
/// text), laid out in a [Wrap] so all five are visible on one screen. Every
/// cell but 無効 combines [CruxTextFormField.label] (static, always above
/// the box) with [CruxTextFormField.placeholder] (visible only in the
/// three cells whose value is empty: 空, エラー, 補助文言つき), so the
/// matrix demonstrates both roles together rather than only one at a time.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own — it only reads colors/spacing/typography through
/// whatever [CruxTheme.of] resolves to from its surrounding context — so
/// it renders correctly with just a [CruxTheme] (or bare [Directionality],
/// exercising the light fallback) above it. This is the widget
/// `widgetbook/test/golden_test.dart` pumps directly, without going through
/// Widgetbook.
///
/// Deliberately has no focused cell: per plan.md section 5 and TF-A04, focus
/// changes nothing about [CruxTextFormField]'s appearance (same border,
/// same everything), so a focused cell would look identical to the 空 cell
/// while adding a blinking cursor to the golden — pure flakiness for zero
/// visual signal.
class TextFormFieldStatesMatrix extends StatelessWidget {
  /// Creates the states matrix.
  const TextFormFieldStatesMatrix({super.key});

  static const double _cellWidth = 260;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );

    Widget cell(String caption, Widget field) {
      return SizedBox(
        width: _cellWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(caption, style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            field,
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Wrap(
          spacing: CruxSpacing.s24,
          runSpacing: CruxSpacing.s24,
          children: <Widget>[
            cell(
              '空',
              CruxTextFormField(
                label: _sampleLabel,
                placeholder: _samplePlaceholder,
              ),
            ),
            cell(
              '入力済み',
              CruxTextFormField(
                label: _sampleLabel,
                placeholder: _samplePlaceholder,
                initialValue: 'crux@example.com',
              ),
            ),
            cell(
              'エラー',
              CruxTextFormField(
                label: _sampleLabel,
                placeholder: _samplePlaceholder,
                autovalidateMode: AutovalidateMode.always,
                validator: (String? _) => '必須項目です',
              ),
            ),
            cell(
              '無効',
              CruxTextFormField(
                label: _sampleLabel,
                initialValue: '編集できない値',
                enabled: false,
              ),
            ),
            cell(
              '補助文言つき',
              CruxTextFormField(
                label: _sampleLabel,
                placeholder: _samplePlaceholder,
                helperText: 'ログインに使用します',
              ),
            ),
            cell(
              'パスワード（表示切替あり）',
              CruxTextFormField(
                label: 'パスワード',
                obscureText: true,
                obscureToggle: _demoObscureToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The label used by every plain (non-error) cell in [TextFormFieldStatesMatrix]
/// and by most of [_TextFormFieldEdgeCases]'s cases, kept as one constant so
/// the matrix reads as states of a single field rather than five different
/// fields.
const String _sampleLabel = 'メールアドレス';

/// The placeholder used alongside [_sampleLabel] wherever a cell's value is
/// empty, so the two roles (static label above the box, in-box hint that
/// disappears once typed) are visible side by side.
const String _samplePlaceholder = 'you@example.com';

/// A very long label, chosen to be longer than [_TextFormFieldEdgeCases]'s
/// 320px demo width so it must either wrap or clip inside the label's
/// single-line [Text] (`maxLines: 1, overflow: TextOverflow.clip` in
/// text_form_field.dart).
const String _veryLongLabel =
    'これは非常に長い項目名です。項目名の行がどこまで伸びても崩れずに済むかを確認するための見本テキストです。';

/// A very long value, long enough that — per TF-A04's "overflow ellipsis で
/// はなく横スクロール" decision — the box must scroll horizontally to keep
/// the cursor visible rather than ellipsizing it.
const String _veryLongValue =
    'これはとても長い入力値です。とても長い入力値です。とても長い入力値です。とても長い入力値です。とても長い入力値です。';

/// A fixed (no knobs) set of layouts chosen to stress the parts of
/// [CruxTextFormField]'s layout most likely to break in a real form: a
/// label long enough to challenge the reserved label row, a value long
/// enough to force horizontal scrolling, a box narrower than its own
/// content padding budget, an ambient right-to-left [Directionality] (the
/// label and placeholder are both laid out in normal document flow — a
/// plain [Text] in a [Column] for the label, [CupertinoTextField]'s own
/// placeholder handling for the hint — so there is no custom positioning
/// code of this widget's own that could fail to mirror under RTL; covered
/// by a passing regression test in `test/text_form_field_test.dart`'s `RTL
/// (regression, now structural)` group), and several fields stacked back to
/// back the way a real form lays them out. Several cases combine
/// [CruxTextFormField.label] with [CruxTextFormField.placeholder] to
/// show both roles together, not just one at a time. Two further cases
/// demonstrate [CruxTextFormField.obscureToggle]: one under RTL (the
/// toggle *does* have custom positioning of its own,
/// [PositionedDirectional], unlike the label/placeholder above, so this is
/// the one part of this widget an RTL case must actually exercise) and one
/// showing the documented `obscureText: false` + a real toggle
/// combination (starts revealed, toggle still works).
class _TextFormFieldEdgeCases extends StatelessWidget {
  const _TextFormFieldEdgeCases();

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );

    Widget labeled(String caption, Widget child) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(caption, style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            child,
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      // The five stacked sections below (especially the last one, three
      // fields stacked the way a real form lays them out) add up to more
      // height than a small preview pane offers, which used to overflow
      // with Flutter's yellow-and-black stripes instead of just scrolling
      // past the fold. SingleChildScrollView keeps every section reachable
      // regardless of the surrounding viewport's height.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            labeled(
              '非常に長い項目名',
              SizedBox(
                width: 320,
                child: CruxTextFormField(
                  label: _veryLongLabel,
                  placeholder: _samplePlaceholder,
                ),
              ),
            ),
            labeled(
              '非常に長い入力値（横スクロールする想定）',
              SizedBox(
                width: 320,
                child: CruxTextFormField(
                  label: 'メモ',
                  initialValue: _veryLongValue,
                ),
              ),
            ),
            labeled(
              '幅 200px に制約',
              SizedBox(
                width: 200,
                child: CruxTextFormField(
                  label: _sampleLabel,
                  initialValue: 'crux@example.com',
                  helperText: 'you@example.com',
                ),
              ),
            ),
            labeled(
              'RTL Directionality 下（項目名は行内、プレースホルダは枠内 -- '
              'どちらも通常の Column レイアウトなので特別な位置合わせは不要）',
              SizedBox(
                width: 320,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: CruxTextFormField(
                    label: _sampleLabel,
                    placeholder: _samplePlaceholder,
                    helperText: 'ログインに使用します',
                  ),
                ),
              ),
            ),
            labeled(
              '表示切替つきパスワード欄（RTL 下でも枠の反対側にミラーする -- '
              'PositionedDirectional で位置指定しているため）',
              SizedBox(
                width: 320,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: CruxTextFormField(
                    label: 'パスワード',
                    obscureText: true,
                    obscureToggle: _demoObscureToggle,
                  ),
                ),
              ),
            ),
            labeled(
              'obscureText: false + 表示切替あり（開始時から表示された状態 -- '
              'obscureToggle が指定されている限りトグルは常に働くので、この組み合わせを '
              '矛盾として無視しない、という決定のデモ）',
              SizedBox(
                width: 320,
                child: CruxTextFormField(
                  label: 'PIN コード',
                  initialValue: '1234',
                  obscureToggle: _demoObscureToggle,
                ),
              ),
            ),
            labeled(
              '3つ縦積み（実際のフォームに近い並び）',
              SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CruxTextFormField(label: '姓', placeholder: '山田'),
                    const SizedBox(height: CruxSpacing.s16),
                    CruxTextFormField(label: '名', placeholder: '太郎'),
                    const SizedBox(height: CruxSpacing.s16),
                    CruxTextFormField(
                      label: _sampleLabel,
                      placeholder: _samplePlaceholder,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
