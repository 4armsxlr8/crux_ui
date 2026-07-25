import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'spacing.dart';
import 'theme.dart';

/// The minimum tap target size for any interactive Crux atom, matching
/// [CruxListTile]'s minimum row height and its [leading] frame width.
const double _minTapTarget = 44;

/// The opacity of the state layer laid over a pressed [CruxListTile]'s
/// background: [CruxColors.textPrimary] at 8%, the same value
/// `CruxButton` uses for its non-filled variants (see button.dart).
const double _pressedOverlayOpacity = 0.08;

/// Flex weight given to the title/subtitle column when it and [trailing]
/// can't both fit at their natural size, vs. [_trailingFlex] for
/// [trailing]'s own weight. See the class doc's "Width distribution"
/// paragraph for what this trade-off means.
const int _titleFlex = 4;

/// Flex weight given to [trailing]. Deliberately smaller than [_titleFlex]
/// so trailing shrinks — and ellipsizes — before the title column does,
/// once the row runs out of room for both.
const int _trailingFlex = 1;

/// A single row of content — an optional [leading] widget, a required
/// [title], an optional [subtitle], and an optional [trailing] label — for
/// building lists such as settings screens, message inboxes, or menus.
///
/// ```dart
/// CruxListTile(
///   leading: const Icon(Icons.notifications),
///   title: '通知',
///   subtitle: 'すべての通知を受け取る',
///   trailing: 'ON',
///   onTap: () {},
/// )
/// ```
///
/// [title], [subtitle], and [trailing] are plain [String]s, not arbitrary
/// widgets: each is always rendered with `maxLines: 1` and an ellipsis, so a
/// [CruxListTile] can never overflow its layout no matter how narrow its
/// constraints or how long the text is — not even [leading]'s fixed 44x44
/// frame at a container narrower than 44 pixels.
///
/// **Width distribution.** As long as [trailing] fits at its natural,
/// un-squeezed size, it's laid out exactly as if it weren't flexible at all
/// (the same layout this widget has always produced), so the title column's
/// width is unaffected by this in the common case. Only once the title
/// column and [trailing] can't both fit at their natural size does
/// [trailing] start sharing space with the title column — and even then it
/// shrinks (and ellipsizes) well before the title column does, because the
/// title column's `Expanded` carries a larger flex weight than the
/// `Flexible` wrapping [trailing]. This weighting is an approximation, not
/// a strict two-phase priority (Flutter's `Flex` layout splits the
/// remaining space by flex ratio simultaneously — it can't express "give
/// the title column its natural size first, then let trailing have
/// whatever's left"), but it visibly favors the title once space runs out
/// for both.
///
/// **The pathological case.** If the available width is narrower than
/// [leading]'s frame plus its surrounding gaps, no amount of flexible
/// sizing can rescue the row — those are fixed, not flexible. Rather than
/// let the row overflow (Flutter's yellow-and-black striped warning), it is
/// laid out with just enough width for its fixed content and then clipped
/// back down to the real, narrower width, so it quietly loses whatever
/// doesn't fit instead of visibly overflowing.
///
/// Set [onTap] to `null` to render a non-interactive, informational row —
/// it neither reports itself as a button to assistive technology nor shows
/// any press feedback. When [onTap] is set, tapping shows a translucent
/// state layer over the whole row, the same overlay `CruxButton` uses for
/// its pressed state. Unlike `CruxButton` and `CruxCard`, a
/// [CruxListTile] never scales down on press: a full-width row visibly
/// shrinking on tap reads as an unnatural wobble, so its only press cue is
/// the state layer.
///
/// A [CruxListTile] always fills its parent's width (like `CruxCard`,
/// unlike `CruxButton`, which hugs its label) — it is a block element,
/// not a pill.
///
/// [padding] defaults to [CruxSpacing.s16] horizontal and
/// [CruxSpacing.s12] vertical (the iOS Settings-app look: the row bakes in
/// its own horizontal inset instead of leaving it to a surrounding
/// container). The pressed-state highlight is painted by the same
/// [Container] that applies [padding], so it always spans the tile's
/// *entire* border box, padding included, not just the area inside
/// [padding] — that's why passing `EdgeInsets.zero` recreates the previous
/// flush-to-edge look (the highlight touches the tile's own left/right
/// edges directly), while a nonzero [padding] insets the highlight together
/// with the content.
///
/// This widget is deliberately built from plain [GestureDetector] and
/// painting widgets rather than Material's `ListTile`/`InkWell`, so it never
/// depends on or is affected by an ambient Material `ThemeData`.
class CruxListTile extends StatefulWidget {
  /// Creates a Crux list row.
  const CruxListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: CruxSpacing.s16,
      vertical: CruxSpacing.s12,
    ),
  });

  /// An optional leading widget (for example an icon or avatar), centered
  /// in a fixed 44x44 logical pixel frame.
  final Widget? leading;

  /// The row's primary text. Always rendered on a single line with an
  /// ellipsis, so an overly long title is truncated rather than
  /// overflowing.
  final String title;

  /// Optional secondary text shown below [title]. Always rendered on a
  /// single line with an ellipsis, same as [title].
  final String? subtitle;

  /// Optional text shown at the row's trailing edge (for example a
  /// timestamp or a value like "ON"). Always rendered on a single line with
  /// an ellipsis.
  final String? trailing;

  /// Called when the row is tapped. Leave as `null` (the default) to render
  /// a non-interactive, informational row with no press feedback and no
  /// button semantics.
  final VoidCallback? onTap;

  /// The space around the row's content, and also the extent of the
  /// pressed-state highlight beyond the content (see the class doc).
  /// Defaults to [CruxSpacing.s16] horizontal and [CruxSpacing.s12]
  /// vertical. Pass `EdgeInsets.zero` for the previous flush-to-edge look.
  final EdgeInsetsGeometry padding;

  @override
  State<CruxListTile> createState() => _CruxListTileState();
}

class _CruxListTileState extends State<CruxListTile> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  // Mirrors CruxButton's gating pattern (see button.dart): only
  // _handleTapDown checks `_enabled`, so a disabled tile can never enter the
  // pressed state, while _handleTapUp/_handleTapCancel always resolve an
  // in-flight press unconditionally and stay wired even when disabled, so
  // GestureDetector's Tap recognizer is never torn out of the gesture arena
  // mid-press.
  void _handleTapDown(TapDownDetails details) {
    if (_enabled) {
      _setPressed(true);
    }
  }

  void _handleTapUp(TapUpDetails details) => _setPressed(false);

  void _handleTapCancel() => _setPressed(false);

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool enabled = _enabled;

    final Color? overlay = (enabled && _pressed)
        ? colors.textPrimary.withValues(alpha: _pressedOverlayOpacity)
        : null;

    final Widget titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        if (widget.subtitle != null)
          Text(
            widget.subtitle!,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(color: colors.textSecondary),
          ),
      ],
    );

    final TextStyle? trailingStyle = widget.trailing == null
        ? null
        : theme.typography.caption.copyWith(color: colors.textSecondary);

    Widget buildTrailingText() => Text(
      widget.trailing!,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: trailingStyle,
    );

    // The combined width of every element in this row that can't shrink no
    // matter how little space is available: `leading`'s fixed 44x44 frame
    // plus the gap after it, and the gap before `trailing`. Below this
    // width, even squeezing every flexible child down to zero can't make
    // the row fit — see the class doc's "OverflowBox" paragraph.
    final double fixedNonFlexWidth =
        (widget.leading != null ? _minTapTarget + CruxSpacing.s12 : 0) +
        (widget.trailing != null ? CruxSpacing.s12 : 0);

    // How much room `trailing` would need to render at its natural,
    // un-squeezed size — the same measurement `Text` itself performs
    // internally when it's laid out with no upper bound on its width (which
    // is exactly the constraint a plain, non-flexible Row child gets: see
    // RenderFlex._constraintsForNonFlexChild). Measuring it directly here
    // (rather than assuming a fixed budget) is what lets the check below
    // reproduce, pixel for pixel, whether today's non-flexible layout would
    // already fit — so the common case where it does can keep using that
    // exact layout, unchanged.
    final double trailingNaturalWidth = widget.trailing == null
        ? 0
        : (TextPainter(
            text: TextSpan(text: widget.trailing, style: trailingStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout()).width;

    return Semantics(
      container: true,
      button: enabled,
      // No explicit `label` here, for the same reason as CruxButton (see
      // button.dart): the descendant title/subtitle/trailing Text widgets
      // already supply their own automatic semantics labels.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapTarget),
          child: Container(
            color: overlay,
            padding: widget.padding,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // The common case: `trailing` already fits at its natural
                // size, so lay this out exactly as if neither the title
                // column nor `trailing` were flexible at all — the same
                // layout this widget has always produced. `Expanded`'s
                // default flex (1) and a plain, non-flexible `trailing`
                // Text reproduce that unchanged.
                final bool fitsAtNaturalSize =
                    constraints.maxWidth >=
                    fixedNonFlexWidth + trailingNaturalWidth;

                final List<Widget> children = <Widget>[
                  if (widget.leading != null) ...<Widget>[
                    SizedBox(
                      width: _minTapTarget,
                      height: _minTapTarget,
                      child: Center(child: widget.leading),
                    ),
                    const SizedBox(width: CruxSpacing.s12),
                  ],
                  fitsAtNaturalSize
                      ? Expanded(child: titleColumn)
                      : Expanded(flex: _titleFlex, child: titleColumn),
                  if (widget.trailing != null) ...<Widget>[
                    const SizedBox(width: CruxSpacing.s12),
                    fitsAtNaturalSize
                        ? buildTrailingText()
                        : Flexible(
                            flex: _trailingFlex,
                            child: buildTrailingText(),
                          ),
                  ],
                ];

                final Widget row = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: children,
                );

                if (constraints.maxWidth >= fixedNonFlexWidth) {
                  return row;
                }

                // The pathological case: not even the row's fixed content
                // fits. Give `Row` just enough width to lay out its fixed
                // content without complaint (every flexible child collapses
                // to zero), then clip the result back down to the real,
                // narrower width instead of letting `RenderFlex` paint the
                // yellow-and-black overflow warning.
                return ClipRect(
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: 0,
                    maxWidth: fixedNonFlexWidth,
                    child: row,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
