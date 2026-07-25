import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'motion.dart';
import 'press_feedback.dart';
import 'radii.dart';
import 'spacing.dart';
import 'theme.dart';

/// The minimum tap target size for any [CruxChip], regardless of its
/// 36px visible pill height (matches [CruxButton]'s `_minTapTarget`: 44
/// logical pixels, the common iOS/Material accessibility guidance for a
/// comfortably tappable target).
const double _minTapTarget = 44;

/// The visible height of a [CruxChip]'s pill, independent of its 44px tap
/// target.
const double _visibleHeight = 36;

/// The opacity of the state layer laid over a pressed [CruxChip]'s
/// background: [CruxColors.textPrimary] at 8%, the same token and value
/// [CruxButton] uses for its non-filled variants (see button.dart's
/// `_pressedOverlayOpacity`). Unlike the button, a chip has no filled/onAccent
/// variant whose contrast this could threaten, so the same 8% applies to
/// every chip state.
const double _pressedOverlayOpacity = 0.08;

/// A pill-shaped, optionally-selectable filter/tag chip.
///
/// ```dart
/// CruxChip(
///   label: 'すべて',
///   selected: true,
///   onTap: () {},
/// )
/// ```
///
/// Set [onTap] to `null` to render a disabled chip (Flutter convention,
/// matching [CruxButton]'s `onPressed`). [label] is a plain [String], not
/// an arbitrary widget: it is always rendered with `maxLines: 1` and an
/// ellipsis, so a [CruxChip] can never overflow its layout no matter how
/// narrow its constraints or how long the label is.
///
/// Three states determine the chip's colors, in priority order:
///
///  * disabled ([onTap] is `null`): [CruxColors.surface] background,
///    [CruxColors.separator] border, [CruxColors.muted] text —
///    regardless of [selected].
///  * enabled and [selected]: [CruxColors.accentTint] background,
///    [CruxColors.accentLine] border, [CruxColors.textPrimary] text.
///  * enabled and not [selected]: [CruxColors.surface] background,
///    [CruxColors.separator] border, [CruxColors.textSecondary] text.
///
/// Pressing an enabled chip shows two combined cues, both driven by
/// [CruxMotion]: the pill scales down to [CruxMotion.pressedScale] and
/// springs back on release, and a translucent state layer darkens (light
/// mode) or lightens (dark mode) its background.
///
/// This widget is deliberately built from plain [GestureDetector] and
/// painting widgets rather than Material's `InkWell`/`ChoiceChip`, so it
/// never depends on or is affected by an ambient Material `ThemeData` (same
/// rationale as [CruxButton]).
class CruxChip extends StatefulWidget {
  /// Creates a Crux filter/tag chip.
  const CruxChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  /// The chip's text. Always rendered on a single line with an ellipsis, so
  /// overly long labels are truncated rather than overflowing.
  final String label;

  /// Whether the chip renders in its selected (accented) appearance.
  /// Defaults to `false`.
  final bool selected;

  /// Called when the chip is tapped. Pass `null` to disable the chip, which
  /// always renders its disabled colors regardless of [selected].
  final VoidCallback? onTap;

  @override
  State<CruxChip> createState() => _CruxChipState();
}

class _CruxChipState extends State<CruxChip> {
  bool _pressed = false;

  // Guarantees the pressed scale/state-layer stays visible for a minimum
  // duration even when a tap's down and up arrive back-to-back (e.g. inside
  // a scroll view) -- see press_feedback.dart's class doc for the bug this
  // fixes. Same wiring as CruxButton's identically-named field.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  bool get _enabled => widget.onTap != null;

  // Mirrors CruxButton's handler wiring: only _handleTapDown checks
  // `_enabled` (the only handler that *starts* a press), while
  // _handleTapUp/_handleTapCancel always resolve any in-flight press
  // unconditionally so a disabled-mid-press chip still settles cleanly. See
  // button.dart's identically-named handlers for the full reasoning.
  void _handleTapDown(TapDownDetails details) {
    if (_enabled) {
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
    final bool enabled = _enabled;

    final Color background = _resolveBackground(
      colors: colors,
      selected: widget.selected,
      enabled: enabled,
      pressed: _pressed,
    );
    final Color borderColor = _resolveBorderColor(
      colors: colors,
      selected: widget.selected,
      enabled: enabled,
    );
    final Color textColor = _resolveTextColor(
      colors: colors,
      selected: widget.selected,
      enabled: enabled,
    );
    final TextStyle labelStyle = theme.typography.label.copyWith(
      fontSize: 13,
      color: textColor,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      // No explicit `label` here for the same reason as CruxButton: the
      // child Text below already supplies its own automatic semantics
      // label, and this Semantics/RenderParagraph pair doesn't create a
      // boundary between them, so an explicit label would be announced
      // twice.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Unconditionally wired for the same reason as CruxButton: gating
        // these on `enabled` would let GestureDetector tear out an
        // in-flight recognizer mid-press and call a stale onTapCancel
        // during build. `_enabled` is checked inside the handlers instead.
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: CruxMotion.scale(
          value: _pressed ? CruxMotion.pressedScale : 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            // IntrinsicWidth ties the pill's width to its label's content
            // instead of stretching to fill a loose parent's max width; see
            // button.dart's identical use for the full reasoning (K B8/the
            // "hug" behavior spec.md requires for CruxChip).
            child: IntrinsicWidth(
              child: Container(
                height: _visibleHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: CruxSpacing.s16,
                ),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: borderColor),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CruxRadii.pill),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves the chip's rest-state background per spec.md's state table,
/// then layers the pressed-state overlay (matching [CruxButton]'s KB7
/// treatment) on top when [pressed] is true.
Color _resolveBackground({
  required CruxColors colors,
  required bool selected,
  required bool enabled,
  required bool pressed,
}) {
  final Color base = !enabled
      ? colors.surface
      : (selected ? colors.accentTint : colors.surface);

  if (!enabled || !pressed) {
    return base;
  }

  final Color overlay = colors.textPrimary.withValues(
    alpha: _pressedOverlayOpacity,
  );
  return Color.alphaBlend(overlay, base);
}

/// Resolves the chip's border color per spec.md's state table.
Color _resolveBorderColor({
  required CruxColors colors,
  required bool selected,
  required bool enabled,
}) {
  if (!enabled) {
    return colors.separator;
  }
  return selected ? colors.accentLine : colors.separator;
}

/// Resolves the chip's label color per spec.md's state table.
Color _resolveTextColor({
  required CruxColors colors,
  required bool selected,
  required bool enabled,
}) {
  if (!enabled) {
    return colors.muted;
  }
  return selected ? colors.textPrimary : colors.textSecondary;
}
