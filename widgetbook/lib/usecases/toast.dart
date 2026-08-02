import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// A small emoji glyph used as [CruxToastCard.leading] throughout this
/// file — the same "plain [Text] glyph, not a real icon font" convention
/// `icon_button.dart`'s `_demoIcon` and `list_tile.dart`'s
/// `_ListTileLeadingIcon` already use, since [CruxToastCard.leading] is
/// caller-supplied (H1) and rendered exactly as given.
const Widget _toastLeadingIcon = Text('✅');

/// The `CruxToast` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
///
/// This entry covers all of `toast.dart`'s public surface: [CruxToastCard]
/// (the static card body), [CruxToastHost] + [showCruxToast] (the
/// stacking/timer/swipe machinery), and [CruxToastAction].
WidgetbookComponent get toastComponent => WidgetbookComponent(
  name: 'Toast',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const ToastStatesMatrix(),
    ),
    WidgetbookUseCase.child(name: 'Edge cases', child: const _ToastEdgeCases()),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final String message = context.knobs.string(
    label: 'message',
    initialValue: '同期が完了しました',
  );
  final bool withLeading = context.knobs.boolean(
    label: 'leading icon',
    initialValue: false,
  );
  final bool withAction = context.knobs.boolean(
    label: 'action',
    initialValue: false,
  );
  final String actionLabel = context.knobs.string(
    label: 'action label',
    initialValue: '元に戻す',
  );

  // Keyed on every knob so changing one starts a fresh demo host with no
  // toasts already queued from a previous knob combination, rather than the
  // knob values changing underneath an already-showing toast mid-flight.
  return _ToastPlayground(
    key: ValueKey<(String, bool, bool, String)>((
      message,
      withLeading,
      withAction,
      actionLabel,
    )),
    message: message,
    withLeading: withLeading,
    withAction: withAction,
    actionLabel: actionLabel,
  );
}

/// Backs the Playground use case: a [CruxToastHost] with two buttons.
///
/// "積む" shows a *new, distinct* toast every tap (an incrementing counter
/// suffixed onto [message]) -- demonstrating the stack itself, including the
/// "a 4th distinct message evicts the oldest" rule once three are already
/// showing. "重複を積む" always shows the exact same [message] -- repeated
/// taps demonstrate [CruxToastHost]'s duplicate handling instead
/// (`CruxMotion.shake`, and moving back to the front with a reset timer if
/// the existing toast isn't already frontmost) rather than stacking a second
/// card.
class _ToastPlayground extends StatefulWidget {
  const _ToastPlayground({
    super.key,
    required this.message,
    required this.withLeading,
    required this.withAction,
    required this.actionLabel,
  });

  final String message;
  final bool withLeading;
  final bool withAction;
  final String actionLabel;

  @override
  State<_ToastPlayground> createState() => _ToastPlaygroundState();
}

class _ToastPlaygroundState extends State<_ToastPlayground> {
  int _distinctCount = 0;

  CruxToastAction? _buildAction() {
    if (!widget.withAction) {
      return null;
    }
    return CruxToastAction(label: widget.actionLabel, onPressed: () {});
  }

  void _showDistinct(BuildContext context) {
    _distinctCount++;
    showCruxToast(
      context,
      message: '${widget.message} #$_distinctCount',
      leading: widget.withLeading ? _toastLeadingIcon : null,
      action: _buildAction(),
    );
  }

  void _showDuplicate(BuildContext context) {
    showCruxToast(
      context,
      message: widget.message,
      leading: widget.withLeading ? _toastLeadingIcon : null,
      action: _buildAction(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return SizedBox(
      height: 420,
      child: CruxToastHost(
        child: ColoredBox(
          color: theme.colors.background,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Builder(
                  builder: (BuildContext hostContext) => CruxButton(
                    label: '積む',
                    onPressed: () => _showDistinct(hostContext),
                  ),
                ),
                const SizedBox(height: CruxSpacing.s12),
                Builder(
                  builder: (BuildContext hostContext) => CruxButton(
                    label: '重複を積む（シェイク確認）',
                    variant: CruxButtonVariant.ghost,
                    onPressed: () => _showDuplicate(hostContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The States matrix widget for `CruxToast`: built entirely from
/// [CruxToastCard] at rest -- per `plans/atoms-batch-3.md`'s widgetbook
/// step, the overlay path ([CruxToastHost]/[showCruxToast], which drives
/// timers and a live drag gesture) is never touched here, since neither has
/// a deterministic rest frame a golden test could capture.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the golden test can pump it directly under its own bare [CruxTheme]
/// ancestor.
///
/// Two sections: every leading/action combination as an individually
/// labeled card, and a static column of three cards spaced by the same 10px
/// gap [CruxToastHost] itself uses ([CruxToastCard]'s own file's
/// `_stackGap`), previewing what a real notification stack looks like
/// without needing the host's timer/drag machinery.
class ToastStatesMatrix extends StatelessWidget {
  /// Creates the toast states matrix.
  const ToastStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );
    final TextStyle sectionLabelStyle = theme.typography.title.copyWith(
      color: colors.textPrimary,
    );

    Widget row(String label, Widget card) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: rowLabelStyle),
            const SizedBox(height: CruxSpacing.s8),
            card,
          ],
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      // Four single cards plus a three-card stack preview run taller than a
      // small preview pane, the same shape of problem button.dart's
      // ButtonStatesMatrix solves -- SingleChildScrollView keeps every
      // section reachable regardless of the surrounding viewport's height,
      // and is a no-op once the content already fits (as at the golden
      // test's generous canvas).
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('単体カード', style: sectionLabelStyle),
            const SizedBox(height: CruxSpacing.s12),
            row('メッセージのみ', const CruxToastCard(message: '同期が完了しました')),
            row(
              'リーディングアイコン付き',
              const CruxToastCard(
                message: '写真を保存しました',
                leading: _toastLeadingIcon,
              ),
            ),
            row(
              'アクション付き',
              CruxToastCard(
                message: 'メッセージを削除しました',
                action: CruxToastAction(label: '元に戻す', onPressed: () {}),
              ),
            ),
            row(
              'アイコン + アクション',
              CruxToastCard(
                message: 'すべての変更を保存しました',
                leading: _toastLeadingIcon,
                action: CruxToastAction(label: '元に戻す', onPressed: () {}),
              ),
            ),
            const SizedBox(height: CruxSpacing.s8),
            Text('スタック風プレビュー（静的・タイマーなし）', style: sectionLabelStyle),
            const SizedBox(height: CruxSpacing.s12),
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CruxToastCard(message: '一番奥のトースト'),
                SizedBox(height: 10),
                CruxToastCard(
                  message: '真ん中のトースト',
                  leading: _toastLeadingIcon,
                ),
                SizedBox(height: 10),
                CruxToastCard(message: '一番手前（最新）のトースト'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed (no knobs) layouts chosen to stress [CruxToastCard]'s 320px max
/// width and two-line ellipsis: a message long enough to hit the ellipsis, a
/// full leading+message+action combination squeezed into a container
/// narrower than the card's own cap, and an action label long enough to
/// exercise its own single-line ellipsis.
class _ToastEdgeCases extends StatelessWidget {
  const _ToastEdgeCases();

  static const String _longMessage =
      'これはとても長い通知メッセージで、2 行に折り返した上でさらに省略記号が入るかどうかを確認するための'
      '文章です。カードの幅は最大でも 320 ピクセルしかありません。';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      child: Wrap(
        spacing: CruxSpacing.s16,
        runSpacing: CruxSpacing.s16,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: <Widget>[
          const CruxToastCard(message: _longMessage),
          SizedBox(
            width: 180,
            child: CruxToastCard(
              message: _longMessage,
              leading: _toastLeadingIcon,
              action: CruxToastAction(label: '元に戻す', onPressed: () {}),
            ),
          ),
          CruxToastCard(
            message: '短いメッセージ',
            action: CruxToastAction(
              label: 'とても長いアクションボタンのラベル',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
