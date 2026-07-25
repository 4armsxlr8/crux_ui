import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A hairline horizontal rule, one logical pixel tall, in
/// [CruxColors.separator].
///
/// Fills the width of whatever bounded space it is given (for example a row
/// inside a [Column] or a [CruxCard]'s child), the same "block-level"
/// behavior as [CruxCard]. Purely decorative: it carries no semantics of
/// its own.
///
/// ```dart
/// Column(
///   children: [
///     CruxListTile(title: 'One'),
///     const CruxDivider(),
///     CruxListTile(title: 'Two'),
///   ],
/// )
/// ```
class CruxDivider extends StatelessWidget {
  /// Creates a Crux divider line, optionally inset from the leading edge
  /// by [indent] logical pixels.
  const CruxDivider({super.key, this.indent = 0});

  /// The empty space before the line starts, in logical pixels. Follows
  /// text direction: it insets from the left edge in LTR and the right
  /// edge in RTL. Defaults to 0 (no inset).
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsetsDirectional.only(start: indent),
      color: CruxTheme.of(context).colors.separator,
    );
  }
}
