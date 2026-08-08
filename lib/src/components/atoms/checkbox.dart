import 'package:flutter/widgets.dart';

import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/theme.dart';

/// The minimum tap target size for any [CruxCheckbox] (matching
/// [CruxButton]'s and [CruxSwitch]'s minimum tap target rule): 44
/// logical pixels, even though the visible box is smaller than that.
const double _minTapTarget = 44;

/// The visible box's side length at rest, before any pulse.
const double _boxSize = 22;

/// The box's corner radius: a small rounding (as opposed to
/// [CruxRadii.m]'s 14, which would read as a rounded-square rather than a
/// checkbox on a 22-logical-pixel box) drawn as a superellipse, matching
/// every other rounded corner in this package.
const double _boxCornerRadius = 6;

/// The width of the box's outline while unchecked.
const double _boxBorderWidth = 2;

/// The stroke width the checkmark itself is painted with.
const double _checkStrokeWidth = 2.2;

/// How far the box's side length grows, in logical pixels, at the peak of
/// the checkmark spring's overshoot -- see [_CruxCheckboxState.build]'s
/// `overshoot` local for how this is driven off the same spring that scales
/// the checkmark in, rather than a second independent animation. Combined
/// with [CruxMotion.animatedValue]'s `playful` spring (which peaks at
/// roughly a 15% overshoot), the box grows by a little over a logical pixel
/// at its peak -- small enough to read as a subtle pulse rather than a
/// bounce of its own.
const double _boxPulseAmplitude = 8;

/// A tappable box that shows a spring-animated checkmark: Crux UI's
/// checkbox atom.
///
/// ```dart
/// CruxCheckbox(
///   checked: isSelected,
///   onChanged: (bool next) => setState(() => isSelected = next),
/// )
/// ```
///
/// [CruxCheckbox] is a controlled widget, the same convention
/// [CruxSwitch] and Flutter's own `Checkbox` use: it always reflects
/// [checked] and never mutates it itself, notifying [onChanged] with the
/// flipped value on tap so the caller decides whether and how to update its
/// state. Set [onChanged] to `null` to render a disabled checkbox (Flutter
/// convention, matching [CruxButton]'s `onPressed` and [CruxSwitch]'s
/// `onChanged`).
///
/// This is a bare control: no label and no tristate ("indeterminate")
/// support in this release. Both are additive, non-breaking API surface a
/// future release can add without touching this constructor's existing
/// parameters.
///
/// The checkmark expresses its own semantics, distinct from
/// [CruxSwitch]'s: this widget exposes Flutter's *checked* semantics
/// trait (`hasCheckedState` + `isChecked`/`isNotChecked`, via [Semantics]'s
/// `checked` parameter) rather than the *toggled* trait a switch uses --
/// screen readers announce the two differently ("checked"/"unchecked" vs.
/// "on"/"off"), and `checked`/`toggled` are mutually exclusive on the same
/// [Semantics] node, so this widget must pick exactly one.
///
/// Tapping anywhere in the checkbox's 44 logical pixel hit area toggles it.
/// The checkmark itself is drawn by this widget (a [CustomPaint], not an
/// [Icon]): when [checked] turns true, it springs in from a 0 scale,
/// overshooting to roughly 1.15 before settling back to 1.0 (via
/// [CruxMotion.animatedValue]'s `playful` spring, a deliberately bouncier
/// spring reserved for this one moment); the box itself grows by a little
/// over a logical pixel at the same overshoot peak and shrinks back with
/// it, reading as a small pulse rather than a second, separate animation.
///
/// Like [CruxButton] and [CruxSwitch], this widget is built from plain
/// [GestureDetector] and painting widgets rather than Material's
/// `Checkbox`, so it never depends on or is affected by an ambient Material
/// `ThemeData`.
class CruxCheckbox extends StatefulWidget {
  /// Creates a Crux checkbox.
  const CruxCheckbox({super.key, required this.checked, this.onChanged});

  /// Whether the checkbox is checked. [CruxCheckbox] never changes this
  /// itself; the caller owns this state and updates it from [onChanged].
  final bool checked;

  /// Called with the flipped value when the checkbox is tapped. Pass `null`
  /// to disable the checkbox.
  final ValueChanged<bool>? onChanged;

  @override
  State<CruxCheckbox> createState() => _CruxCheckboxState();
}

class _CruxCheckboxState extends State<CruxCheckbox> {
  bool _pressed = false;

  // Guarantees the pressed scale stays visible for a minimum duration even
  // when a tap's down and up arrive back-to-back (e.g. inside a scroll
  // view) -- see press_feedback.dart's class doc for the bug this fixes.
  // Same mechanism CruxButton and CruxIconButton use.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  bool get _enabled => widget.onChanged != null;

  // Only _handleTapDown checks `_enabled`, since it is the only handler
  // that *starts* a press. _handleTapUp and _handleTapCancel always resolve
  // any in-flight press unconditionally -- gating them by `enabled` instead
  // would tear the in-flight TapGestureRecognizer out of the gesture arena
  // if the checkbox becomes disabled mid-press.
  void _handleTapDown(TapDownDetails details) {
    if (_enabled) {
      _pressFeedback.down();
    }
  }

  void _handleTapUp(TapUpDetails details) => _pressFeedback.up();

  void _handleTapCancel() => _pressFeedback.cancel();

  void _handleTap() {
    widget.onChanged!(!widget.checked);
  }

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
    final bool checked = widget.checked;

    final Color? fillColor = _resolveFillColor(
      colors: colors,
      checked: checked,
      enabled: enabled,
    );

    return Semantics(
      container: true,
      checked: checked,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: enabled ? _handleTap : null,
        child: CruxMotion.scale(
          value: _pressed ? CruxMotion.pressedScale : 1.0,
          child: SizedBox(
            width: _minTapTarget,
            height: _minTapTarget,
            child: Center(
              child: CruxMotion.animatedValue(
                value: checked ? 1.0 : 0.0,
                playful: true,
                builder:
                    (
                      BuildContext context,
                      double checkFraction,
                      Widget? child,
                    ) {
                      // How far past the checkmark's resting scale (1.0) the
                      // spring has overshot on its way in: 0 whenever the
                      // spring hasn't reached 1.0 yet or has already settled
                      // back down to it, positive only during the brief
                      // overshoot peak. Deriving the box's pulse from this
                      // same value -- rather than driving a second,
                      // independent spring -- is what keeps the pulse
                      // synchronized to the checkmark's own overshoot instead
                      // of reading as a separate, disconnected wobble.
                      final double overshoot = (checkFraction - 1.0).clamp(
                        0.0,
                        double.infinity,
                      );
                      final double boxSize =
                          _boxSize + overshoot * _boxPulseAmplitude;
                      // Springs can dip below their start value before
                      // settling, which would otherwise flip
                      // Transform.scale's sign and mirror-paint the
                      // checkmark for a frame while unchecking; clamped to
                      // a non-negative scale to guard against that.
                      final double checkScale = checkFraction.clamp(
                        0.0,
                        double.infinity,
                      );

                      return Container(
                        width: boxSize,
                        height: boxSize,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: fillColor,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(_boxCornerRadius),
                            ),
                            side: fillColor == null
                                ? BorderSide(
                                    color: colors.muted,
                                    width: _boxBorderWidth,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                        child: Transform.scale(
                          scale: checkScale,
                          child: SizedBox(
                            width: _boxSize,
                            height: _boxSize,
                            child: CustomPaint(
                              painter: _CheckmarkPainter(
                                color: colors.onAccent,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves the box's fill color: `null` (no fill, just the outline
/// [_boxBorderWidth]/[CruxColors.muted] drawn in [_CruxCheckboxState.
/// build]) while unchecked, [CruxColors.accent] while checked and
/// enabled, and [CruxColors.muted] while checked and disabled, so a
/// disabled-and-checked checkbox still visibly differs from a
/// disabled-and-unchecked one instead of collapsing both into the same
/// look.
///
/// The unchecked outline is [CruxColors.muted] rather than
/// [CruxColors.accentLine] -- despite [CruxColors.accentLine] being the
/// token this package otherwise reserves for a state-identifying,
/// 3:1-contrast outline -- because [CruxColors.accentLine] measures only
/// ~2.90:1 against [CruxColors.controlFill] in the light palette, below
/// WCAG 1.4.11's 3:1 non-text contrast floor. [CruxColors.muted] is the
/// nearest token that clears 3:1 against both [CruxColors.background]
/// and [CruxColors.controlFill] in both palettes. It stays the outline
/// color regardless of [enabled] because it is already a quiet,
/// low-emphasis color, so disabling it needs no further desaturation.
Color? _resolveFillColor({
  required CruxColors colors,
  required bool checked,
  required bool enabled,
}) {
  if (!checked) {
    return null;
  }
  return enabled ? colors.accent : colors.muted;
}

/// Paints the checkmark inside a [CruxCheckbox]'s box, at whatever
/// [Size] the [CustomPaint] it is given is laid out at (see
/// [_CruxCheckboxState.build], which sizes that [CustomPaint] to a fixed
/// [_boxSize] and instead scales the whole thing via [Transform.scale] --
/// so this painter itself never needs to know about the checkmark's
/// animated progress).
class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.color});

  /// The checkmark's stroke color -- always [CruxColors.onAccent], the
  /// token this package uses for content painted on top of a filled accent
  /// surface.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _checkStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.80, size.height * 0.30);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
