import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The `CruxDialog` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
///
/// This entry covers all three public layers `dialog.dart`/
/// `confirm_dialog.dart` ship: [CruxDialogCard] (the blank floating card),
/// [CruxDialog.show] (the overlay mechanism), and [CruxConfirmDialog] /
/// [CruxConfirmDialog.show] (the confirm-specific content built from it).
WidgetbookComponent get dialogComponent => WidgetbookComponent(
  name: 'Dialog',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const DialogStatesMatrix(),
    ),
    WidgetbookUseCase.child(
      name: 'Edge cases',
      child: const _DialogEdgeCases(),
    ),
  ],
);

/// Which of the two public dialog layers the Playground's "開く" button
/// opens: [CruxDialog.show] with hand-built content (the blank-card
/// layer), or [CruxConfirmDialog.show] (the confirm-specific layer built
/// on top of it).
enum _DialogPlaygroundKind {
  /// [CruxDialog.show] with custom content built directly in this file —
  /// exercises the "child-agnostic floating card" layer on its own.
  blankCard,

  /// [CruxConfirmDialog.show] — exercises the title/message/two-action
  /// layer.
  confirmDialog,
}

String _dialogKindLabel(_DialogPlaygroundKind kind) => switch (kind) {
  _DialogPlaygroundKind.blankCard => 'blank card',
  _DialogPlaygroundKind.confirmDialog => 'confirm dialog',
};

Widget _buildPlayground(BuildContext context) {
  final _DialogPlaygroundKind kind = context.knobs.object
      .segmented<_DialogPlaygroundKind>(
        label: 'kind',
        options: _DialogPlaygroundKind.values,
        initialOption: _DialogPlaygroundKind.confirmDialog,
        labelBuilder: _dialogKindLabel,
      );
  final String title = context.knobs.string(
    label: 'title',
    initialValue: '下書きを削除しますか?',
  );
  final String message = context.knobs.string(
    label: 'message',
    initialValue: '削除すると元に戻せません。',
    maxLines: 3,
  );
  final String cancelLabel = context.knobs.string(
    label: 'cancelLabel',
    initialValue: 'キャンセル',
  );
  final String confirmLabel = context.knobs.string(
    label: 'confirmLabel',
    initialValue: '削除する',
  );
  final bool barrierDismissible = context.knobs.boolean(
    label: 'barrierDismissible',
    initialValue: true,
  );

  return Center(
    child: CruxButton(
      label: '開く',
      onPressed: () {
        switch (kind) {
          case _DialogPlaygroundKind.blankCard:
            CruxDialog.show(
              context,
              barrierDismissible: barrierDismissible,
              builder: (BuildContext dialogContext, VoidCallback close) {
                final CruxThemeData theme = CruxTheme.of(dialogContext);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.typography.title.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: CruxSpacing.s8),
                    Text(
                      message,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CruxSpacing.s20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CruxButton(label: '閉じる', onPressed: close),
                    ),
                  ],
                );
              },
            );
          case _DialogPlaygroundKind.confirmDialog:
            CruxConfirmDialog.show(
              context,
              barrierDismissible: barrierDismissible,
              title: title,
              message: message,
              cancelLabel: cancelLabel,
              onCancel: () {},
              confirmLabel: confirmLabel,
              onConfirm: () {},
            );
        }
      },
    ),
  );
}

/// The States matrix widget for `CruxDialog`/`CruxConfirmDialog`: per
/// `plans/atoms-batch-3.md`'s widgetbook step, this is built entirely from
/// the *static* layers ([CruxDialogCard] wrapping hand-built content, and
/// [CruxConfirmDialog]'s bare content widget) rather than the
/// [CruxDialog.show]/[CruxConfirmDialog.show] overlay path — a dialog
/// mid-flight (scrim, entrance spring) has no rest frame a golden test could
/// capture deterministically, but the floating card at rest is exactly what
/// [CruxDialogCard] alone renders.
///
/// Per `usecases/CONVENTIONS.md`, this widget takes no [CruxTheme]
/// dependency of its own -- it only reads colors and spacing through
/// whatever [CruxTheme.of] resolves to from its surrounding context -- so
/// the golden test (`widgetbook/test/golden_test.dart`) can pump it directly
/// under its own bare [CruxTheme] ancestor without going through
/// Widgetbook or [Overlay] at all.
///
/// The "state" axis here is [CruxConfirmDialog.onCancel]'s enabled/
/// disabled dichotomy (the same nullable-callback-disables convention every
/// other Crux atom uses) -- a dialog has no other per-instance enabled
/// state to vary.
class DialogStatesMatrix extends StatelessWidget {
  /// Creates the dialog states matrix.
  const DialogStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final TextStyle rowLabelStyle = theme.typography.label.copyWith(
      color: colors.textPrimary,
    );

    Widget row(String label, Widget card) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
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
      child: Padding(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            row(
              '白紙カード（テキストのみ）',
              CruxDialogCard(
                child: Text(
                  '中身は呼び出し側が組み立てる、カード本体だけの層です。',
                  style: theme.typography.body.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            row(
              '白紙カード（タイトル + 本文 + ボタン）',
              CruxDialogCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'カスタムな中身',
                      style: theme.typography.title.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: CruxSpacing.s8),
                    Text(
                      'CruxDialogCard は child を選ばない、白紙のカードです。',
                      style: theme.typography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CruxSpacing.s20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CruxButton(label: '閉じる', onPressed: () {}),
                    ),
                  ],
                ),
              ),
            ),
            row(
              '確認ダイアログ（両方有効）',
              CruxDialogCard(
                child: CruxConfirmDialog(
                  title: '下書きを削除しますか?',
                  message: '削除すると元に戻せません。',
                  cancelLabel: 'キャンセル',
                  onCancel: () {},
                  confirmLabel: '削除する',
                  onConfirm: () {},
                ),
              ),
            ),
            row(
              '確認ダイアログ（キャンセル無効）',
              CruxDialogCard(
                child: CruxConfirmDialog(
                  title: '同期中です',
                  message: '完了するまでキャンセルできません。',
                  cancelLabel: 'キャンセル',
                  confirmLabel: '待つ',
                  onConfirm: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed (no knobs) layouts chosen to stress [CruxDialogCard]/
/// [CruxConfirmDialog]'s text wrapping and its 340px max width: a
/// long title and multi-sentence message, very long action labels (which
/// must ellipsize inside their half-width buttons rather than overflow the
/// action row), and the card squeezed inside a container narrower than its
/// own 340px cap.
class _DialogEdgeCases extends StatelessWidget {
  const _DialogEdgeCases();

  static const String _longTitle = 'とても長いタイトルテキストがここに入るとどうなるかの確認';
  static const String _longMessage =
      'これは複数の文にまたがる長い本文です。カードは最大 340 ピクセルまでしか広がらないので、'
      'その中で折り返しがどう起きるかをここで確認します。三行目まで届くかどうかも見どころです。';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      child: Wrap(
        spacing: CruxSpacing.s16,
        runSpacing: CruxSpacing.s16,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: <Widget>[
          CruxDialogCard(
            child: CruxConfirmDialog(
              title: _longTitle,
              message: _longMessage,
              cancelLabel: 'キャンセル',
              onCancel: () {},
              confirmLabel: '削除する',
              onConfirm: () {},
            ),
          ),
          CruxDialogCard(
            child: CruxConfirmDialog(
              title: '長いボタンラベルの確認',
              message: '両方のアクションラベルが長い場合、左右半分ずつの全幅ボタン行が崩れないかを見ます。',
              cancelLabel: 'このまま何もしない',
              onCancel: () {},
              confirmLabel: 'すべて削除して最初からやり直す',
              onConfirm: () {},
            ),
          ),
          SizedBox(
            width: 200,
            child: CruxDialogCard(
              child: CruxConfirmDialog(
                title: '狭い親幅',
                message: 'カード自身の 340px 上限より狭い親に置いた場合の見た目です。',
                cancelLabel: 'キャンセル',
                onCancel: () {},
                confirmLabel: 'OK',
                onConfirm: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
