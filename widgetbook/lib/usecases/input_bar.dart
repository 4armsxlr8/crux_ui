import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The decorative leading icon shared by every use case below that shows a
/// search-style bar -- a plain emoji [Text], not a real icon system,
/// matching [CruxInputBarLeading]'s "the package draws whatever it is
/// given" contract (see that class's doc) the same way
/// `text_form_field.dart`'s `_demoObscureToggle` demonstrates
/// [CruxObscureToggle] without pulling in an icon font dependency. An
/// emoji glyph (rather than a plain ASCII character) is picked deliberately:
/// it paints in its own fixed color regardless of the surrounding text
/// color, so it stays legible against both the light and dark catalog
/// themes without this file having to resolve a theme color for it.
CruxInputBarLeading get _demoLeading =>
    const CruxInputBarLeading(icon: Text('🔍'));

/// The clear-button icon shared by every use case below -- same reasoning
/// as [_demoLeading] for using an emoji glyph.
CruxInputBarClear get _demoClear =>
    const CruxInputBarClear(icon: Text('❌'), label: '消去');

/// The submit-button icon shared by every use case below. Deliberately a
/// plain (non-emoji) glyph, unlike [_demoLeading]/[_demoClear]: CruxInputBar
/// wraps [CruxInputBarSubmit.icon] in its own `IconTheme.merge`/
/// `DefaultTextStyle.merge` (see `input_bar.dart`'s `_buildSubmit`) to
/// animate the icon's color between the accent/onAccent (enabled) and
/// separator/muted (disabled) tones -- a full-color emoji glyph ignores an
/// inherited text color entirely, which would hide that animation. A plain
/// arrow character inherits the merged color instead, so the catalog
/// actually shows the color transition IB-D08 describes.
CruxInputBarSubmit get _demoSubmit =>
    const CruxInputBarSubmit(icon: Text('↑'), label: '送信');

/// The `CruxInputBar` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get inputBarComponent => WidgetbookComponent(
  name: 'InputBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final String placeholder = context.knobs.string(
          label: 'placeholder',
          initialValue: '検索',
        );
        final int maxLines = context.knobs.int.slider(
          label: 'maxLines',
          initialValue: 1,
          min: 1,
          max: 6,
        );
        final bool enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final bool hasLeading = context.knobs.boolean(
          label: 'Show leading icon',
          initialValue: true,
        );
        final bool hasClear = context.knobs.boolean(
          label: 'Show clear button',
          initialValue: true,
        );
        final bool hasSubmit = context.knobs.boolean(
          label: 'Show submit button',
          initialValue: true,
        );

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(CruxSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _InputBarPlayground(
                placeholder: placeholder,
                maxLines: maxLines,
                enabled: enabled,
                hasLeading: hasLeading,
                hasClear: hasClear,
                hasSubmit: hasSubmit,
              ),
            ),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const InputBarStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _InputBarEdgeCases(),
    ),
  ],
);

/// Backs the Playground use case: renders one live [CruxInputBar] the
/// visitor can actually type into. A plain [CruxInputBar] built straight
/// from knobs would need its own `controller`, and nothing would own that
/// controller across rebuilds (each knob change would otherwise hand the bar
/// a brand-new, empty controller, wiping out whatever the visitor typed) --
/// so this small [StatefulWidget] owns the live [TextEditingController] the
/// same way any real caller of [CruxInputBar] with a controller must,
/// mirroring `text_form_field.dart`'s `_TextFormFieldPlayground`.
class _InputBarPlayground extends StatefulWidget {
  const _InputBarPlayground({
    required this.placeholder,
    required this.maxLines,
    required this.enabled,
    required this.hasLeading,
    required this.hasClear,
    required this.hasSubmit,
  });

  final String placeholder;
  final int maxLines;
  final bool enabled;
  final bool hasLeading;
  final bool hasClear;
  final bool hasSubmit;

  @override
  State<_InputBarPlayground> createState() => _InputBarPlaygroundState();
}

class _InputBarPlaygroundState extends State<_InputBarPlayground> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CruxInputBar(
      controller: _controller,
      placeholder: widget.placeholder,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
      leading: widget.hasLeading ? _demoLeading : null,
      clear: widget.hasClear ? _demoClear : null,
      submit: widget.hasSubmit ? _demoSubmit : null,
    );
  }
}

/// The States matrix widget for `CruxInputBar`: 検索欄の空／文字あり、
/// チャット欄の1行状態／2段構え状態、無効状態の5つを [Wrap] で一度に並べる.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors/spacing/typography through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// it renders correctly with just a [CruxTheme] (or bare [Directionality],
/// exercising the light fallback) above it. This is the widget
/// `widgetbook/test/golden_test.dart` pumps directly, without going through
/// Widgetbook.
///
/// A [StatefulWidget], not [StatelessWidget], because two of the five cells
/// need pre-filled text (the "文字あり" search cell, and both chat cells),
/// and [CruxInputBar] only accepts a pre-filled starting value via a
/// caller-supplied [TextEditingController] (unlike [CruxTextFormField],
/// which also takes a plain `initialValue` string) -- those controllers need
/// somewhere to live and be disposed rather than being recreated on every
/// rebuild.
///
/// Deliberately contains no mid-transformation state: the "チャット・2段構え
/// 状態" cell reaches its expanded shape by seeding its controller with a
/// literal `\n` in the initial text (matching
/// `CruxInputBar`'s own "measures `text.contains('\n')` directly"
/// wrap check -- `lib/src/input_bar.dart`'s `_wouldWrapToMultipleLines`) so
/// it renders already-settled on the very first frame, not partway through
/// an animation `pumpAndSettle` would otherwise have to chase -- see
/// `unknowns/input-bar/impact.md`'s note on why a mid-transform state is
/// unsafe to include here.
class InputBarStatesMatrix extends StatefulWidget {
  /// Creates the states matrix.
  const InputBarStatesMatrix({super.key});

  @override
  State<InputBarStatesMatrix> createState() => _InputBarStatesMatrixState();
}

class _InputBarStatesMatrixState extends State<InputBarStatesMatrix> {
  static const double _cellWidth = 300;

  final TextEditingController _searchFilledController = TextEditingController(
    text: 'ラーメン 渋谷',
  );
  final TextEditingController _chatOneLineController = TextEditingController(
    text: 'こんにちは',
  );
  // The literal newline is what settles this cell straight into the
  // expanded (two-row) shape on its very first frame -- see this class's
  // own doc comment above.
  final TextEditingController _chatWrappedController = TextEditingController(
    text: '今日はありがとう\nまた明日ね',
  );
  final TextEditingController _disabledController = TextEditingController(
    text: '編集できない値',
  );

  @override
  void dispose() {
    _searchFilledController.dispose();
    _chatOneLineController.dispose();
    _chatWrappedController.dispose();
    _disabledController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );

    Widget cell(String caption, Widget bar) {
      return SizedBox(
        width: _cellWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(caption, style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            bar,
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
              '検索欄・空',
              CruxInputBar(
                placeholder: '検索',
                leading: _demoLeading,
                clear: _demoClear,
              ),
            ),
            cell(
              '検索欄・文字あり',
              CruxInputBar(
                controller: _searchFilledController,
                leading: _demoLeading,
                clear: _demoClear,
              ),
            ),
            cell(
              'チャット欄・1行状態',
              CruxInputBar(
                controller: _chatOneLineController,
                maxLines: 5,
                submit: _demoSubmit,
              ),
            ),
            cell(
              'チャット欄・2段構え状態',
              CruxInputBar(
                controller: _chatWrappedController,
                maxLines: 5,
                submit: _demoSubmit,
              ),
            ),
            cell(
              '無効状態',
              CruxInputBar(
                controller: _disabledController,
                enabled: false,
                leading: _demoLeading,
                clear: _demoClear,
                submit: _demoSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single, very long word with no spaces or soft-wrap opportunities --
/// long enough to stress [CruxInputBar]'s line-wrap measurement
/// (`_wouldWrapToMultipleLines` in `lib/src/input_bar.dart`) with text that
/// cannot break at a word boundary the way ordinary prose does.
const String _veryLongWord =
    'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんあいうえおかきくけこさしすせそ';

/// Six lines of chat-style text -- more than [_InputBarEdgeCases]'s
/// `maxLines: 3` bar allows, so this exercises "stops growing at the cap and
/// scrolls internally beyond it" (see `CruxInputBar`'s class doc, "Single
/// line vs. multi-line" section).
const String _longChatText =
    'おはようございます\nお疲れ様です\n今日は何時に集合ですか\n了解しました\n'
    'ありがとうございます\nよろしくお願いします';

/// A fixed (no knobs) set of layouts chosen to stress the parts of
/// [CruxInputBar]'s layout and line-wrap measurement most likely to break
/// in a real app: a box narrower than its own slot-reservation budget, a
/// single unbreakable word, text well past the configured line cap, every
/// accessory slot filled at once inside a narrow box, and an ambient
/// right-to-left [Directionality] (covered by a passing regression test in
/// `test/input_bar_test.dart`'s "right-to-left layout (RTL)" group).
class _InputBarEdgeCases extends StatelessWidget {
  const _InputBarEdgeCases();

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
      // The stacked sections below add up to more height than a small
      // preview pane offers; SingleChildScrollView keeps every section
      // reachable regardless of the surrounding viewport's height, the same
      // reasoning `text_form_field.dart`'s own edge-cases widget uses.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            labeled(
              '幅 200px に制約',
              SizedBox(
                width: 200,
                child: CruxInputBar(placeholder: '検索', leading: _demoLeading),
              ),
            ),
            labeled(
              '極端に長い1語（改行の機会が無い文字列）',
              SizedBox(
                width: 320,
                child: CruxInputBar(
                  controller: TextEditingController(text: _veryLongWord),
                  maxLines: 3,
                  submit: _demoSubmit,
                ),
              ),
            ),
            labeled(
              '最大行数（3行）を超える長文 -- 3行で止まり内部でスクロールする想定',
              SizedBox(
                width: 320,
                child: CruxInputBar(
                  controller: TextEditingController(text: _longChatText),
                  maxLines: 3,
                  submit: _demoSubmit,
                ),
              ),
            ),
            labeled(
              'leading/clear/submit を全部載せた狭い箱（幅260px）',
              SizedBox(
                width: 260,
                child: CruxInputBar(
                  controller: TextEditingController(text: 'こんにちは'),
                  leading: _demoLeading,
                  clear: _demoClear,
                  submit: _demoSubmit,
                ),
              ),
            ),
            labeled(
              'RTL Directionality 下（leading は右端、clear/submit は左端にミラー '
              'する -- AlignmentDirectional/EdgeInsetsDirectional で位置指定し '
              'ているため）',
              SizedBox(
                width: 320,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: CruxInputBar(
                    controller: TextEditingController(text: 'こんにちは'),
                    leading: _demoLeading,
                    clear: _demoClear,
                    submit: _demoSubmit,
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
