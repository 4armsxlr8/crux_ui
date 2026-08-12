import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A no-op callback for every demo [CruxComposerAction] below that does
/// not need to visibly react to a tap (the States matrix and Edge cases use
/// cases just show the action row's appearance, not a wired-up behavior).
/// A top-level function tear-off, not an anonymous closure, so
/// [_demoAttach]/[_demoCamera] below can stay `const`.
void _noop() {}

/// The attachment-button action shared by every use case below -- a plain
/// emoji [Text], not a real icon system, matching [CruxComposerAction]'s
/// "the package draws whatever it is given" contract (H1; see that class's
/// own doc) the same way `input_bar.dart`'s `_demoLeading` demonstrates
/// [CruxInputBarLeading] without pulling in an icon font dependency.
/// Unlike [CruxInputBarLeading]/[CruxInputBarClear], [onPressed] is part
/// of this bundle rather than a separate [CruxComposer]-level callback --
/// see [CruxComposerAction]'s own doc for why.
const CruxComposerAction _demoAttach = CruxComposerAction(
  icon: Text('📎'),
  label: '添付ファイルを追加',
  onPressed: _noop,
);

/// A second demo action, used only where a use case below wants to show
/// more than one [CruxComposerAction] side by side in the action row (the
/// action row's left edge budgets one [_slotSize]-wide tap target per
/// action, in a [Row], so this is what stresses that with real width
/// pressure rather than a single slot).
const CruxComposerAction _demoCamera = CruxComposerAction(
  icon: Text('📷'),
  label: '写真を追加',
  onPressed: _noop,
);

/// The submit ("post") button shared by every use case below -- same
/// emoji-free reasoning as [input_bar.dart]'s own `_demoSubmit`, except
/// [CruxComposerSubmit] carries only a [CruxComposerSubmit.label]:
/// tapping it is wired through [CruxComposer.onSubmit] instead, a plain
/// widget-level callback (there is only ever one submit button, unlike
/// [CruxComposer.actions]' variable-length list).
CruxComposerSubmit get _demoSubmit => const CruxComposerSubmit(label: '投稿');

/// The `CruxComposer` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get composerComponent => WidgetbookComponent(
  name: 'Composer',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final String placeholder = context.knobs.string(
          label: 'placeholder',
          initialValue: 'いまどうしてる？',
        );
        final bool enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final bool hasAttach = context.knobs.boolean(
          label: 'Show attach action',
          initialValue: true,
        );
        final bool hasSubmit = context.knobs.boolean(
          label: 'Show submit button',
          initialValue: true,
        );
        final bool hasCounter = context.knobs.boolean(
          label: 'Show counter (maxLength)',
          initialValue: true,
        );
        final int maxLength = context.knobs.int.slider(
          label: 'maxLength',
          initialValue: 140,
          min: 5,
          max: 500,
        );

        // A fixed-height ConstrainedBox, not a bare ConstrainedBox(maxWidth:
        // ...) the way the other atoms' Playgrounds use: CruxComposer
        // fills whatever height its parent gives it (CP-D02) rather than
        // sizing to its content, so this preview needs a tight height, not
        // just a tight width, or it has nothing to fill at all.
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(CruxSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SizedBox(
                height: 280,
                child: _ComposerPlayground(
                  placeholder: placeholder,
                  enabled: enabled,
                  hasAttach: hasAttach,
                  hasSubmit: hasSubmit,
                  maxLength: hasCounter ? maxLength : null,
                ),
              ),
            ),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const ComposerStatesMatrix(),
    ),
    WidgetbookUseCase(
      name: 'Edge cases',
      builder: (context) => const _ComposerEdgeCases(),
    ),
  ],
);

/// Backs the Playground use case: renders one live [CruxComposer] the
/// visitor can actually type into. A plain [CruxComposer] built straight
/// from knobs would need its own `controller`, and nothing would own that
/// controller across rebuilds (each knob change would otherwise hand it a
/// brand-new, empty controller, wiping out whatever the visitor typed) -- so
/// this small [StatefulWidget] owns the live [CruxComposerController] the
/// same way any real caller of [CruxComposer] with a controller must,
/// mirroring `input_bar.dart`'s `_InputBarPlayground`. It is a
/// [CruxComposerController], not a plain [TextEditingController]: that is
/// the only type [CruxComposer.controller] accepts (see that field's own
/// doc for why).
class _ComposerPlayground extends StatefulWidget {
  const _ComposerPlayground({
    required this.placeholder,
    required this.enabled,
    required this.hasAttach,
    required this.hasSubmit,
    required this.maxLength,
  });

  final String placeholder;
  final bool enabled;
  final bool hasAttach;
  final bool hasSubmit;
  final int? maxLength;

  @override
  State<_ComposerPlayground> createState() => _ComposerPlaygroundState();
}

class _ComposerPlaygroundState extends State<_ComposerPlayground> {
  final CruxComposerController _controller = CruxComposerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CruxComposer(
      controller: _controller,
      placeholder: widget.placeholder,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      actions: widget.hasAttach
          ? const <CruxComposerAction>[_demoAttach]
          : const <CruxComposerAction>[],
      submit: widget.hasSubmit ? _demoSubmit : null,
      onSubmit: (String text) {},
    );
  }
}

/// The fill painted behind every demo [CruxComposer] cell below, standing
/// in for whatever surface a real caller would place a borderless composer
/// on. [CruxComposer] itself draws no box of its own (see its class doc),
/// so without some visible backdrop here neither its bounds nor its
/// "fills the height it is given" behavior (CP-D02) would show up in a
/// screenshot at all -- [CruxColors.controlFill] is the token this
/// package already uses for "the fill behind an interactive control such as
/// a text input" (see `colors.dart`'s own doc on that field), which is
/// exactly [CruxComposer]'s role here.
Widget _composerBackdrop({required CruxColors colors, required Widget child}) {
  return DecoratedBox(
    decoration: BoxDecoration(color: colors.controlFill),
    child: child,
  );
}

/// The States matrix widget for `CruxComposer`: 素の領域（アクション行なし）/
/// 通常（添付・カウンタ・投稿すべて有効）/ 上限超過（カウンタと超過分がerror色、
/// 投稿は押せない）/ 無効状態 / 高さいっぱいに広がる背の高いセル、の5つを
/// [Wrap] で一度に並べる.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors/spacing/typography through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// it renders correctly with just a [CruxTheme] (or bare [Directionality],
/// exercising the light fallback) above it. This is the widget
/// `widgetbook/test/golden_test.dart` pumps directly, without going through
/// Widgetbook.
///
/// Every cell wraps its [CruxComposer] in a [SizedBox] with a *fixed*
/// height, not just a fixed width -- per `unknowns/composer/impact.md`'s
/// golden-capture note: [CruxComposer] fills whatever height it is given
/// (CP-D02) only under *tight* height constraints; under the loose
/// constraints a bare `Column(mainAxisSize: min)` cell would otherwise hand
/// it, the expanding text area collapses to its content height instead, and
/// the golden would never show the "fills the height" behavior this matrix
/// exists to demonstrate.
///
/// A [StatefulWidget], not [StatelessWidget], because several cells need
/// pre-filled text, and [CruxComposer] only accepts a starting value via a
/// caller-supplied [CruxComposerController] -- those controllers need
/// somewhere to live and be disposed rather than being recreated on every
/// rebuild, the same reasoning `input_bar.dart`'s `InputBarStatesMatrix`
/// uses for its own controllers.
class ComposerStatesMatrix extends StatefulWidget {
  /// Creates the states matrix.
  const ComposerStatesMatrix({super.key});

  @override
  State<ComposerStatesMatrix> createState() => _ComposerStatesMatrixState();
}

/// 20 グラフィーム分の日本語テキストに絵文字を1つ足した、21グラフィームの本文
/// -- `maxLength: 20` に対して超過分がちょうど末尾の絵文字1文字だけになるよう
/// 選んだサンプル。UTF-16 のコード単位ではなく grapheme cluster で数えたときに
/// 初めて「超過は絵文字1文字だけ」になることを golden で確認できる
/// (`CruxComposerController.buildTextSpan` が UTF-16 境界ではなく
/// `characters` の境界で分割する、というこの実装の中核契約のデモ).
const String _overLimitText = 'あいうえおかきくけこさしすせそたちつてと🎉';

class _ComposerStatesMatrixState extends State<ComposerStatesMatrix> {
  static const double _cellWidth = 300;
  static const double _cellHeight = 160;
  static const double _tallCellHeight = 360;

  final CruxComposerController _normalController = CruxComposerController(
    text: 'こんにちは',
  );
  final CruxComposerController _overLimitController = CruxComposerController(
    text: _overLimitText,
  );
  final CruxComposerController _disabledController = CruxComposerController(
    text: '編集できない値',
  );

  @override
  void dispose() {
    _normalController.dispose();
    _overLimitController.dispose();
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

    Widget cell(String caption, double height, Widget composer) {
      return SizedBox(
        width: _cellWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(caption, style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            SizedBox(
              height: height,
              child: _composerBackdrop(colors: colors, child: composer),
            ),
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
              '素の領域のみ（アクション行なし）',
              _cellHeight,
              const CruxComposer(placeholder: 'いまどうしてる？'),
            ),
            cell(
              '通常（添付・カウンタ・投稿すべて有効）',
              _cellHeight,
              CruxComposer(
                controller: _normalController,
                maxLength: 20,
                actions: const <CruxComposerAction>[_demoAttach],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            cell(
              '上限超過（21 / 20、超過分がerror色、投稿は押せない）',
              _cellHeight,
              CruxComposer(
                controller: _overLimitController,
                maxLength: 20,
                actions: const <CruxComposerAction>[_demoAttach],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            cell(
              '無効状態',
              _cellHeight,
              CruxComposer(
                controller: _disabledController,
                enabled: false,
                maxLength: 20,
                actions: const <CruxComposerAction>[_demoAttach],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            cell(
              '高さいっぱいに広がる（背の高いセル）',
              _tallCellHeight,
              CruxComposer(
                placeholder: 'いまどうしてる？',
                actions: const <CruxComposerAction>[_demoAttach],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A long, sentence-length body -- long enough that inside
/// [_ComposerEdgeCases]' fixed-height narrow cell it must scroll internally
/// rather than growing the box (`CruxComposer` fills its given height and
/// scrolls, it never grows past it -- CP-D02).
const String _longComposerText =
    '今日は朝からずっと調子が良くて、新しい企画のアイデアが次々と浮かんできました。'
    '午後には資料をまとめてチームに共有する予定です。'
    'このまま集中力が続くといいなと思っています。';

/// A short body followed by several consecutive emoji, chosen so a small
/// `maxLength` cuts the overflow highlight across more than one
/// [CruxComposerAction]-adjacent emoji in a row -- stressing that the
/// grapheme-boundary split (`CruxComposerController.buildTextSpan`) never
/// lands mid-emoji even when more than one overflowing grapheme sits back to
/// back.
const String _overLimitEmojiHeavyText = 'こんにちは🎉🎂';

/// 15 グラフィームの日本語テキスト -- 無効状態と上限超過を同時に見せる edge
/// case 用に、`maxLength: 10` に対して確実に超過するだけの長さを持つ.
const String _disabledOverLimitText = 'あいうえおかきくけこさしすせそ';

/// A fixed (no knobs) set of layouts chosen to stress the parts of
/// [CruxComposer] most likely to break in a real screen: a box narrower
/// than its own action-row slot budget, a body long enough to force internal
/// scrolling rather than growth, an over-limit body whose overflow spans
/// several consecutive emoji in a narrow box, an ambient right-to-left
/// [Directionality] (actions mirror to the end edge, the counter/submit
/// pair to the start edge -- covered by a passing regression test in
/// `test/composer_test.dart`'s RTL group), two [CruxComposerAction]s
/// competing for room in a narrow box, and a disabled field that is also
/// over its limit at the same time.
///
/// A [StatefulWidget], not [StatelessWidget], for the same reason
/// [ComposerStatesMatrix] above is one: every cell below needs a
/// pre-filled, caller-supplied [CruxComposerController] (the only way
/// [CruxComposer] accepts a starting value), and those controllers need a
/// stable owner to live on and be disposed from -- creating them inline
/// inside `build()` would both leak a new controller (and its listener)
/// every time this widget rebuilds and silently wipe out anything the
/// visitor had typed, since each rebuild would hand every cell a brand-new,
/// reset-to-initial-text controller.
class _ComposerEdgeCases extends StatefulWidget {
  const _ComposerEdgeCases();

  @override
  State<_ComposerEdgeCases> createState() => _ComposerEdgeCasesState();
}

class _ComposerEdgeCasesState extends State<_ComposerEdgeCases> {
  final CruxComposerController _narrowController = CruxComposerController(
    text: 'こんにちは',
  );
  final CruxComposerController _longTextController = CruxComposerController(
    text: _longComposerText,
  );
  final CruxComposerController _overLimitEmojiController =
      CruxComposerController(text: _overLimitEmojiHeavyText);
  final CruxComposerController _rtlController = CruxComposerController(
    text: 'こんにちは',
  );
  final CruxComposerController _crowdedController = CruxComposerController(
    text: 'こんにちは',
  );
  final CruxComposerController _disabledOverLimitController =
      CruxComposerController(text: _disabledOverLimitText);

  @override
  void dispose() {
    _narrowController.dispose();
    _longTextController.dispose();
    _overLimitEmojiController.dispose();
    _rtlController.dispose();
    _crowdedController.dispose();
    _disabledOverLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle captionStyle = theme.typography.caption.copyWith(
      color: colors.muted,
    );

    Widget labeled(
      String caption,
      double width,
      double height,
      Widget composer,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(caption, style: captionStyle),
            const SizedBox(height: CruxSpacing.s8),
            SizedBox(
              width: width,
              height: height,
              child: _composerBackdrop(colors: colors, child: composer),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      // The stacked sections below add up to more height than a small
      // preview pane offers; SingleChildScrollView keeps every section
      // reachable regardless of the surrounding viewport's height, the same
      // reasoning `input_bar.dart`'s own edge-cases widget uses.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            labeled(
              '幅200px・高さ160pxに制約',
              200,
              160,
              CruxComposer(
                controller: _narrowController,
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            labeled(
              '極端に長い本文（内部でスクロールする想定 -- 箱は伸びない）',
              320,
              160,
              CruxComposer(
                controller: _longTextController,
                actions: const <CruxComposerAction>[_demoAttach],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            labeled(
              '上限超過＋絵文字が連続（grapheme境界を絵文字の途中で割らない '
              '確認、狭い箱）',
              260,
              160,
              CruxComposer(
                controller: _overLimitEmojiController,
                maxLength: 5,
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            labeled(
              'RTL Directionality下（添付は右端、カウンタ・投稿は左端に '
              'ミラーする -- AlignmentDirectional で位置指定しているため）',
              320,
              200,
              Directionality(
                textDirection: TextDirection.rtl,
                child: CruxComposer(
                  controller: _rtlController,
                  maxLength: 20,
                  actions: const <CruxComposerAction>[_demoAttach],
                  submit: _demoSubmit,
                  onSubmit: (String text) {},
                ),
              ),
            ),
            labeled(
              'アクションを2つ＋カウンタ＋投稿を狭い箱（幅260px）に詰め込む',
              260,
              200,
              CruxComposer(
                controller: _crowdedController,
                maxLength: 20,
                actions: const <CruxComposerAction>[_demoAttach, _demoCamera],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
            labeled(
              '無効状態＋上限超過を同時に満たす',
              300,
              160,
              CruxComposer(
                controller: _disabledOverLimitController,
                enabled: false,
                maxLength: 10,
                actions: const <CruxComposerAction>[_demoAttach],
                submit: _demoSubmit,
                onSubmit: (String text) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
