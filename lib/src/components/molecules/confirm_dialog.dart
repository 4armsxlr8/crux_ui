import 'package:flutter/widgets.dart';

import '../atoms/button.dart';
import '../atoms/dialog.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';

/// The gap [CruxConfirmDialog] inserts between its message and its action
/// row, matching mock case B's `.dialog-body` bottom margin (22px -- not
/// itself a value in [CruxSpacing]'s 4px-based scale, so expressed as a
/// sum of two tokens that already are, the same technique `composer.dart`
/// uses for its own off-scale 6px gap).
const double _messageToActionsGap = CruxSpacing.s20 + CruxSpacing.s2;

/// The gap [CruxConfirmDialog] inserts between its cancel and confirm
/// actions (2026-08-02 user decision: the action row now splits the card's
/// full content width in half between the two buttons, replacing the
/// earlier space-between layout). [CruxSpacing.s12] matches the gap
/// `list_tile.dart` already uses between two adjacent horizontal elements
/// (its leading/trailing icon and the label column), the closest existing
/// precedent for "small gap between two side-by-side pieces" in this
/// package.
const double _actionsGap = CruxSpacing.s12;

/// Crux UI's confirmation dialog content: a title, a message, and an
/// action row where cancel and confirm each fill half of the available
/// width (cancel on the left, confirm on the right -- the confirmed "cancel
/// left / confirm right" order, now stretched full-width instead of
/// hugging each label).
///
/// This renders only the dialog's *content*, not the floating card, scrim,
/// or open/close animation around it -- it is meant to be handed to
/// [CruxDialog.show]'s `builder`, which wraps it in a [CruxDialogCard]
/// itself:
///
/// ```dart
/// CruxDialog.show(
///   context,
///   builder: (context, close) => CruxConfirmDialog(
///     title: '下書きを削除しますか？',
///     message: '削除すると元に戻せません。',
///     cancelLabel: 'キャンセル',
///     onCancel: close,
///     confirmLabel: '削除する',
///     onConfirm: () {
///       delete();
///       close();
///     },
///   ),
/// );
/// ```
///
/// Or, more simply, via [CruxConfirmDialog.show], which wires the same
/// call for you -- title/message/labels/callbacks are all this widget needs
/// to complete mock case B's confirmation-dialog look (per this package's
/// plan: "title / message / キャンセルと実行のラベル + 各コールバックを渡す
/// だけでモックの見た目が完成する").
///
/// All wording is caller-supplied (H1): this package never decides [title],
/// [message], or either action's label.
class CruxConfirmDialog extends StatelessWidget {
  /// Creates Crux confirmation dialog content.
  const CruxConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    this.onCancel,
    required this.confirmLabel,
    required this.onConfirm,
  });

  /// The dialog's heading.
  final String title;

  /// The dialog's body copy.
  final String message;

  /// The leading (cancel) action's label.
  final String cancelLabel;

  /// Called when the leading action is tapped. Pass `null` to render a
  /// disabled cancel action (this package's usual "nullable callback means
  /// disabled" convention) -- [CruxConfirmDialog.show] always supplies a
  /// non-null callback here, so this only matters when constructing
  /// [CruxConfirmDialog] directly.
  final VoidCallback? onCancel;

  /// The trailing (confirm) action's label.
  final String confirmLabel;

  /// Called when the trailing action is tapped.
  ///
  /// Deliberately non-nullable, breaking this package's usual "nullable
  /// callback means disabled" convention (see [onCancel]): a confirmation
  /// dialog's entire reason for existing is to gate one committed action
  /// behind an explicit "are you sure", so a caller with no [onConfirm] to
  /// run has nothing to confirm and should not open this dialog at all,
  /// rather than open it with its one meaningful action rendered disabled.
  final VoidCallback onConfirm;

  /// Opens [CruxConfirmDialog] as a [CruxDialog.show] modal -- the
  /// convenience form of the example on this class's own doc.
  ///
  /// Both actions close the dialog once tapped: [onCancel] (if supplied) or
  /// [onConfirm] runs first, then the dialog closes the same way
  /// [CruxDialog.show]'s `close` callback would. Closing on confirm
  /// (rather than leaving that decision to the caller) matches mock case
  /// B's own reference behavior, where the confirm button closes the dialog
  /// immediately on tap.
  ///
  /// Names the dialog's semantics route after [title] automatically (see
  /// [CruxDialog.show]'s `routeSemanticLabel`), with no separate argument
  /// needed here: unlike [CruxDialog.show], which has no content of its
  /// own and so has nothing to name a route after without asking the
  /// caller, [CruxConfirmDialog.show] already requires [title] as
  /// caller-supplied wording for the card itself -- reusing it for the
  /// route's announced name costs the caller nothing extra, stays
  /// consistent with H1 (still the caller's own words, never this
  /// package's), and matches what a screen reader user would want
  /// announced first in either case.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String cancelLabel,
    VoidCallback? onCancel,
    required String confirmLabel,
    required VoidCallback onConfirm,
    bool barrierDismissible = true,
    String? barrierSemanticLabel,
  }) {
    return CruxDialog.show(
      context,
      barrierDismissible: barrierDismissible,
      barrierSemanticLabel: barrierSemanticLabel,
      routeSemanticLabel: title,
      builder: (BuildContext context, VoidCallback close) {
        return CruxConfirmDialog(
          title: title,
          message: message,
          cancelLabel: cancelLabel,
          onCancel: () {
            onCancel?.call();
            close();
          },
          confirmLabel: confirmLabel,
          onConfirm: () {
            onConfirm();
            close();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
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
        const SizedBox(height: _messageToActionsGap),
        Row(
          children: <Widget>[
            Expanded(
              child: CruxButton(
                label: cancelLabel,
                variant: CruxButtonVariant.ghost,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: _actionsGap),
            Expanded(
              child: CruxButton(label: confirmLabel, onPressed: onConfirm),
            ),
          ],
        ),
      ],
    );
  }
}
