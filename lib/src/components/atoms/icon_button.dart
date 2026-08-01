import 'package:flutter/widgets.dart';

import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/theme.dart';

/// The visual size a [CruxIconButton] renders at.
///
/// Unlike [CruxButtonSize] (whose visible pill is often taller than its
/// own 44 logical pixel tap target requirement), a [CruxIconButton]'s
/// visible circle *is* its tap target at every size offered today: there is
/// no extra invisible padding around a smaller glyph the way this widget's
/// first shipped version (a fixed 32 logical pixel circle inside a 44
/// logical pixel target -- the same split `CruxInputBar`'s submit button
/// still uses) worked. New values may be added in a future minor release;
/// an exhaustive `switch` over this enum can break when that happens, so
/// prefer a `default` case (or an equivalent fallback) at call sites that
/// don't need to special-case every size, the same non-exhaustiveness note
/// [CruxSpinnerSize] documents.
enum CruxIconButtonSize {
  /// A 44 logical pixel circle -- this package's usual 44 logical pixel
  /// minimum tap target (see
  /// `button.dart`/`chip.dart`/`switch.dart`/`input_bar.dart`'s
  /// identically-shaped, independently-declared constants), doubling here
  /// as the visible circle itself. The default.
  medium,

  /// A 56 logical pixel circle. Already at or above the 44 logical pixel
  /// minimum tap target on its own, so no extra invisible tap padding
  /// surrounds it. Pair with [CruxIconButtonTone.primary] for a floating
  /// action button (FAB) -- see `example/`'s sync screen for a worked
  /// example. A somewhat larger [CruxIconButton.icon] than usual keeps
  /// the glyph in visual balance with the bigger circle.
  large,
}

/// Resolves the fixed layout metrics (tap target side length and visible
/// circle diameter) for a [CruxIconButtonSize].
///
/// The two are equal for every size offered today -- see
/// [CruxIconButtonSize]'s own doc -- but are modeled as independent
/// fields rather than a single `double` so a future size whose visible
/// circle is again smaller than its own tap target (the shape both current
/// sizes moved away from) could be added without changing this function's
/// return shape, the same forward-compatible intent
/// [CruxIconButtonSize]'s non-exhaustiveness note calls out for the enum
/// itself.
({double tapTarget, double circleDiameter}) _metricsFor(
  CruxIconButtonSize size,
) {
  switch (size) {
    case CruxIconButtonSize.medium:
      return (tapTarget: 44, circleDiameter: 44);
    case CruxIconButtonSize.large:
      return (tapTarget: 56, circleDiameter: 56);
  }
}

/// The background/foreground treatment a [CruxIconButton] renders with.
///
/// New values may be added in a future minor release; an exhaustive
/// `switch` over this enum can break when that happens, so prefer a
/// `default` case (or an equivalent fallback) at call sites that don't need
/// to special-case every tone.
enum CruxIconButtonTone {
  /// An [CruxColors.mutedFill]-filled circle with an
  /// [CruxColors.textPrimary] icon foreground. The default, low-emphasis
  /// tone for secondary actions (for example a "close" or "remove
  /// attachment" button).
  neutral,

  /// An [CruxColors.accent]-filled circle with an [CruxColors.onAccent]
  /// icon foreground -- the same colors [CruxInputBar]'s enabled submit
  /// button uses. The higher-emphasis tone, for a screen's primary icon
  /// action.
  primary,
}

/// Resolves [CruxIconButton]'s visible circle's background color.
Color _resolveBackground({
  required CruxColors colors,
  required CruxIconButtonTone tone,
  required bool enabled,
}) {
  // Disabled renders the same mutedFill circle regardless of tone -- the
  // same "disabled fill is mutedFill, not separator" reasoning
  // `CruxInputBar`'s submit button uses (see colors.dart's
  // [CruxColors.mutedFill] doc): this circle can sit on top of another
  // filled surface, where a fainter token like `separator` would risk
  // disappearing.
  if (!enabled) {
    return colors.mutedFill;
  }
  return switch (tone) {
    CruxIconButtonTone.neutral => colors.mutedFill,
    CruxIconButtonTone.primary => colors.accent,
  };
}

/// Resolves [CruxIconButton]'s icon foreground color.
Color _resolveForeground({
  required CruxColors colors,
  required CruxIconButtonTone tone,
  required bool enabled,
}) {
  if (!enabled) {
    return colors.muted;
  }
  return switch (tone) {
    CruxIconButtonTone.neutral => colors.textPrimary,
    CruxIconButtonTone.primary => colors.onAccent,
  };
}

/// A circular, spring-pressable icon button: Crux UI's icon-only atom, for
/// a single tappable glyph that needs no visible text (for example a
/// composer's close button or a chat bar's attachment button).
///
/// ```dart
/// CruxIconButton(
///   icon: const Icon(CupertinoIcons.xmark),
///   label: '閉じる',
///   onPressed: () => Navigator.of(context).pop(),
/// )
/// ```
///
/// [icon] and [label] are both required and caller-supplied -- this package
/// draws no glyph of its own and has no fixed language to announce to a
/// screen reader, the same reasoning [CruxObscureToggle] and
/// [CruxInputBarSubmit] apply to their own icons and labels. [icon] is a
/// plain [Widget], not an [IconData]: whatever it is, its color is
/// propagated via an ambient [IconTheme]/[DefaultTextStyle] so it inherits
/// this button's resolved foreground color without this package needing to
/// know which icon system produced it.
///
/// Set [onPressed] to `null` to render a disabled button (Flutter
/// convention): the circle renders in a muted tone and stops responding to
/// taps. [tone] selects the enabled circle's emphasis -- [CruxIconButtonTone
/// .neutral] (the default, a muted-fill circle) for secondary actions, or
/// [CruxIconButtonTone.primary] (an accent-filled circle) for a screen's
/// primary icon action. [size] selects the circle's (and, at every size
/// offered today, the tap target's) diameter -- [CruxIconButtonSize
/// .medium] (the default, 44 logical pixels) for a button sitting among
/// other controls, or [CruxIconButtonSize.large] (56 logical pixels,
/// typically paired with [CruxIconButtonTone.primary]) for a floating
/// action button (FAB).
///
/// Pressing shows the same spring feedback [CruxButton] does: the visible
/// circle scales down to [CruxMotion.pressedScale] and springs back on
/// release, guaranteed to stay visible for at least
/// [kMinimumPressFeedbackDuration] even on a very fast tap (see
/// [PressFeedbackController]'s class doc for the bug this fixes).
///
/// This widget is deliberately built from plain [GestureDetector] and
/// painting widgets rather than Material's `IconButton`, so it never depends
/// on or is affected by an ambient Material `ThemeData`.
class CruxIconButton extends StatefulWidget {
  /// Creates a Crux icon button.
  const CruxIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.tone = CruxIconButtonTone.neutral,
    this.size = CruxIconButtonSize.medium,
  });

  /// The icon to render, centered inside the visible filled circle. A
  /// caller-supplied [Widget], not an [IconData] -- see this class's own
  /// doc for why.
  final Widget icon;

  /// The label a screen reader announces for this button (for example
  /// "閉じる" / "Close"). Required: an icon-only button with no accessible
  /// name would fail WCAG 4.1.2, and this package has no fixed language of
  /// its own to fall back to.
  final String label;

  /// Called when the button is tapped. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// The background/foreground treatment. Defaults to
  /// [CruxIconButtonTone.neutral].
  final CruxIconButtonTone tone;

  /// The visible circle's (and tap target's) size. Defaults to
  /// [CruxIconButtonSize.medium].
  final CruxIconButtonSize size;

  @override
  State<CruxIconButton> createState() => _CruxIconButtonState();
}

class _CruxIconButtonState extends State<CruxIconButton> {
  bool _pressed = false;

  // Guarantees the pressed scale stays visible for a minimum duration even
  // when a tap's down and up arrive back-to-back (e.g. inside a scroll
  // view) -- see press_feedback.dart's class doc for the bug this fixes.
  // Same mechanism [CruxButton] uses.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  bool get _enabled => widget.onPressed != null;

  // Only _handleTapDown checks `_enabled`: it is the only handler that
  // *starts* a press, so gating it there is enough to keep a disabled
  // button from ever entering the pressed state. _handleTapUp and
  // _handleTapCancel always resolve any in-flight press unconditionally, so
  // a press started while enabled still ends cleanly even if the button
  // becomes disabled before release -- see button.dart's identical
  // onTapDown/Up/Cancel wiring comment for why these three callbacks stay
  // wired unconditionally rather than gated by `enabled` themselves.
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
    final ({double tapTarget, double circleDiameter}) metrics = _metricsFor(
      widget.size,
    );

    final Color background = _resolveBackground(
      colors: colors,
      tone: widget.tone,
      enabled: enabled,
    );
    final Color foreground = _resolveForeground(
      colors: colors,
      tone: widget.tone,
      enabled: enabled,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      // Unlike CruxButton (whose label comes for free from its child
      // Text's own automatic semantics), this button has no descendant
      // text to rely on and `icon` is an arbitrary caller-supplied widget
      // that may carry unrelated or absent semantics of its own -- so this
      // sets an explicit label and excludes descendant semantics, the same
      // pattern `_ObscureToggleButton` and `CruxInputBarSubmit` use.
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: CruxMotion.scale(
          value: _pressed ? CruxMotion.pressedScale : 1.0,
          child: SizedBox(
            width: metrics.tapTarget,
            height: metrics.tapTarget,
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: background,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      metrics.circleDiameter / 2,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: metrics.circleDiameter,
                  height: metrics.circleDiameter,
                  child: Center(
                    child: IconTheme.merge(
                      data: IconThemeData(color: foreground),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: foreground),
                        child: widget.icon,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
