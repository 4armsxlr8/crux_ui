import 'package:flutter/widgets.dart';

import 'button.dart';
import 'divider.dart';
import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';

/// The minimum tap target size for an interactive [CruxCard] (same rule
/// as [CruxButton]'s `_minTapTarget`): 44 logical pixels.
const double _minTapTarget = 44;

/// The opacity of the state layer laid over a pressed, interactive
/// [CruxCard]'s background: [CruxColors.textPrimary] at 8%, the same
/// value [CruxButton] uses for its non-filled variants.
const double _pressedOverlayOpacity = 0.08;

/// A bordered, block-level content container: Crux UI's general-purpose
/// surface atom.
///
/// ```dart
/// CruxCard(
///   child: Text('内容'),
/// )
/// ```
///
/// Unlike [CruxButton], a [CruxCard] does **not** hug its content's
/// width: it is a block-level surface that fills whatever bounded width its
/// parent gives it (the same way a [CruxDivider] or a plain [Container]
/// would), so it reads correctly as a full-width row in a list or a
/// full-width section in a form rather than shrinking to wrap around
/// whatever [child] happens to measure.
///
/// [onTap] is optional. Leaving it `null` renders a purely decorative
/// container with no press feedback of any kind — no state layer, no
/// press-scale animation, and no button semantics — because a card with no
/// action to perform has nothing to give feedback about. Passing a callback
/// makes the whole card (down to its 44x44 minimum tap target) pressable:
/// pressing shows a translucent state layer plus a scale-down to
/// [CruxMotion.pressedScaleSubtle], the subtler of the two press scales
/// ([CruxMotion.pressedScale] is reserved for compact pills such as
/// [CruxButton], where a stronger scale doesn't read as an exaggerated
/// wobble the way it would across a whole card).
///
/// [child] is always clipped to the card's own rounded-corner shape (the
/// same rounded rect [radius] draws the border along) — this is a
/// documented behavioral guarantee, not an implementation detail. Without
/// it, a full-bleed child that paints edge-to-edge (for example a pressed
/// [CruxListTile]'s state-layer overlay) would paint straight through the
/// card's rounded corners as a visible square poking out past the border.
class CruxCard extends StatefulWidget {
  /// Creates a Crux card.
  const CruxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CruxSpacing.s16),
    this.onTap,
    this.radius = CruxRadii.l,
  });

  /// The card's content.
  final Widget child;

  /// The space between the card's border and [child]. Defaults to
  /// [CruxSpacing.s16] on every side.
  final EdgeInsetsGeometry padding;

  /// Called when the card is tapped. Leave `null` for a non-interactive,
  /// purely decorative card (no press feedback, no button semantics).
  final VoidCallback? onTap;

  /// The corner radius. Defaults to [CruxRadii.l].
  final double radius;

  @override
  State<CruxCard> createState() => _CruxCardState();
}

class _CruxCardState extends State<CruxCard> {
  bool _pressed = false;

  // Guarantees the pressed scale/state-layer stays visible for a minimum
  // duration even when a tap's down and up arrive back-to-back (e.g. inside
  // a scroll view) -- see press_feedback.dart's class doc for the bug this
  // fixes. Same wiring as CruxButton's identically-named field.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  bool get _interactive => widget.onTap != null;

  // Keeps the interactive (Semantics + GestureDetector) shape mounted for as
  // long as a press might still be in flight, even if `onTap` flips to null
  // mid-press. `_pressed` can only become true while `_interactive` was true
  // at the moment the finger went down (see _handleTapDown below), so this
  // only ever keeps the interactive shape mounted a little *longer* than
  // `_interactive` alone would, never shorter. Swapping the whole widget
  // subtree while a gesture is still down would tear out the active
  // TapGestureRecognizer mid-gesture and crash; waiting until `_pressed`
  // resolves back to false (on tap-up/cancel) avoids that without giving up
  // the "pure container, zero interactive scaffolding" shape a
  // never-interactive card needs.
  bool get _showInteractiveTree => _interactive || _pressed;

  // Only _handleTapDown checks `_interactive`, since it is the only handler
  // that *starts* a press. _handleTapUp and _handleTapCancel always resolve
  // any in-flight press unconditionally -- gating them by `_interactive`
  // instead would tear the in-flight TapGestureRecognizer out of the
  // gesture arena if `onTap` is cleared mid-press.
  void _handleTapDown(TapDownDetails details) {
    if (_interactive) {
      _pressFeedback.down();
    }
  }

  void _handleTapUp(TapUpDetails details) => _pressFeedback.up();

  void _handleTapCancel() => _pressFeedback.cancel();

  @override
  void dispose() {
    _pressFeedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool interactive = _interactive;

    final Color background = interactive && _pressed
        ? Color.alphaBlend(
            colors.textPrimary.withValues(alpha: _pressedOverlayOpacity),
            colors.surface,
          )
        : colors.surface;

    final Widget surface = Container(
      // `alignment` (rather than leaving it unset) is what makes this
      // Container fill a bounded-but-loose incoming width instead of
      // shrink-wrapping [child], since CruxCard is block-level and not a
      // hug widget. AlignmentDirectional.centerStart keeps content anchored
      // to the reading-direction start edge (not centered) within that
      // full width, matching normal block/list-item flow.
      alignment: AlignmentDirectional.centerStart,
      padding: widget.padding,
      // Clips `child` to this same rounded (superellipse) shape. Without
      // this, Container defaults to Clip.none and never clips at all, so a
      // full-bleed child (e.g. a pressed CruxListTile's state-layer
      // overlay) paints straight through the rounded corners as a visible
      // square poking out past the border. Container derives the clip path
      // from `decoration.getClipPath()`, which for a ShapeDecoration
      // defers to `shape.getOuterPath()` (this same
      // RoundedSuperellipseBorder), and paints the border on top of the
      // clip afterward, so the border itself is never clipped away.
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(widget.radius),
          side: BorderSide(color: colors.separator),
        ),
      ),
      child: widget.child,
    );

    if (!_showInteractiveTree) {
      return surface;
    }

    return Semantics(
      container: true,
      button: interactive,
      enabled: interactive,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: CruxMotion.scale(
            value: _pressed ? CruxMotion.pressedScaleSubtle : 1.0,
            child: surface,
          ),
        ),
      ),
    );
  }
}
