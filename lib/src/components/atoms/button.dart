import 'package:flutter/widgets.dart';

import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';
import 'spinner.dart';

/// The minimum tap target size for any [CruxButton], regardless of its
/// visual [CruxButtonSize]: 44 logical pixels, matching the common
/// iOS/Material accessibility guidance for a comfortably tappable target.
const double _minTapTarget = 44;

/// The opacity of the state layer laid over a pressed [CruxButton]'s
/// background: [CruxColors.textPrimary] at 8%, which reads as darkening
/// in light mode and lightening in dark mode without a second,
/// brightness-specific token.
const double _pressedOverlayOpacity = 0.08;

/// The pressed-state overlay opacity for [CruxButtonVariant.filled]
/// specifically, lower than [_pressedOverlayOpacity].
///
/// [CruxColors.onAccent] (the filled variant's label color) and the
/// overlay color ([CruxColors.textPrimary]) are the exact same value in
/// both palettes, so any overlay alpha moves the pressed background
/// directly toward the label color and can only shrink their contrast,
/// never grow it. The shared 8% overlay would drop filled's
/// onAccent-vs-background contrast to 4.353:1 -- under the 4.5:1 AA floor
/// for normal-size text; 5% keeps it at 4.549:1 (light) / 5.163:1 (dark).
const double _pressedOverlayOpacityFilled = 0.05;

/// The background/emphasis treatment a [CruxButton] renders with.
///
/// New values may be added in a future minor release; an exhaustive
/// `switch` over this enum can break when that happens, so prefer a
/// `default` case (or an equivalent fallback) at call sites that don't need
/// to special-case every variant.
enum CruxButtonVariant {
  /// An [CruxColors.accent]-filled pill with [CruxColors.onAccent] text.
  /// The highest-emphasis variant, for a screen's primary action.
  filled,

  /// An [CruxColors.accentTint]-filled pill with an
  /// [CruxColors.accentLine] border and [CruxColors.textPrimary] text.
  /// Medium emphasis.
  tonal,

  /// No fill and no border, just [CruxColors.textPrimary] text. The
  /// lowest-emphasis variant, for secondary or tertiary actions.
  ghost,
}

/// The visual height a [CruxButton] renders at.
///
/// Every size keeps at least a 44 logical pixel tap target even when its
/// visible pill is shorter than that. New values may be added in a future
/// minor release; see [CruxButtonVariant] for the same non-exhaustiveness
/// note.
enum CruxButtonSize {
  /// A 36 logical pixel tall pill.
  small,

  /// A 44 logical pixel tall pill. The default.
  medium,

  /// A 52 logical pixel tall pill.
  large,
}

/// The fixed visual metrics (pill height and horizontal padding) for a
/// [CruxButtonSize].
({double height, double horizontalPadding}) _metricsFor(CruxButtonSize size) {
  switch (size) {
    case CruxButtonSize.small:
      return (height: 36, horizontalPadding: CruxSpacing.s16);
    case CruxButtonSize.medium:
      return (height: 44, horizontalPadding: CruxSpacing.s20);
    case CruxButtonSize.large:
      return (height: 52, horizontalPadding: CruxSpacing.s24);
  }
}

/// A pill-shaped, spring-pressable button: Crux UI's first interactive
/// atom.
///
/// ```dart
/// CruxButton(
///   label: 'はじめる',
///   onPressed: () {},
/// )
/// ```
///
/// Set [onPressed] to `null` to render a disabled button (Flutter
/// convention). [label] is a plain [String], not an arbitrary widget: it is
/// always rendered with `maxLines: 1` and an ellipsis, so a [CruxButton]
/// can never overflow its layout no matter how narrow its constraints or how
/// long the label is. Pressing shows two combined cues, both driven by
/// [CruxMotion]: the pill scales down to [CruxMotion.pressedScale] and
/// springs back on release, and a translucent state layer darkens (light
/// mode) or lightens (dark mode) its background.
///
/// This widget is deliberately built from plain [GestureDetector] and
/// painting widgets rather than Material's `InkWell`/`ElevatedButton`, so it
/// never depends on or is affected by an ambient Material `ThemeData`.
///
/// Set [loading] to `true` to show a submitting/sending state: the label is
/// replaced by a small [CruxSpinner] and the button stops responding to
/// taps (even if [onPressed] is non-null), while keeping the exact same
/// background, border, and size it would have without [loading] -- only the
/// label's content and the button's interactivity change.
class CruxButton extends StatefulWidget {
  /// Creates a Crux pill button.
  const CruxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CruxButtonVariant.filled,
    this.size = CruxButtonSize.medium,
    this.loading = false,
  });

  /// The button's text. Always rendered on a single line with an ellipsis,
  /// so overly long labels are truncated rather than overflowing.
  final String label;

  /// Called when the button is tapped. Pass `null` to disable the button.
  ///
  /// Ignored while [loading] is `true`: the button does not invoke this even
  /// when it is non-null.
  final VoidCallback? onPressed;

  /// The background/emphasis treatment. Defaults to
  /// [CruxButtonVariant.filled].
  final CruxButtonVariant variant;

  /// The visual height. Defaults to [CruxButtonSize.medium].
  final CruxButtonSize size;

  /// Whether the button is showing a submitting/sending state. Defaults to
  /// `false`.
  ///
  /// While `true`, [label] is replaced by a small [CruxSpinner] and the
  /// button becomes unpressable -- taps neither invoke [onPressed] nor show
  /// the press-scale/state-layer feedback -- but the button's background,
  /// border, and overall size are unchanged from its non-loading appearance,
  /// so a caller can flip this flag without the surrounding layout shifting.
  final bool loading;

  @override
  State<CruxButton> createState() => _CruxButtonState();
}

class _CruxButtonState extends State<CruxButton> {
  bool _pressed = false;

  // Guarantees the pressed scale/state-layer stays visible for a minimum
  // duration even when a tap's down and up arrive back-to-back (e.g. inside
  // a scroll view).
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  // Whether a callback was supplied at all -- governs the button's *visual*
  // enabled/disabled treatment only. Deliberately independent of
  // [_interactive]: a loading button keeps looking exactly like its enabled
  // self, it just stops responding to taps.
  bool get _hasOnPressed => widget.onPressed != null;

  // Whether the button actually responds to taps right now: gates semantics
  // `enabled`, `onTap`, and starting press-scale feedback. Unlike
  // [_hasOnPressed], this also requires not being in the loading state.
  bool get _interactive => _hasOnPressed && !widget.loading;

  // Only this handler checks `_interactive`: it is the only one that
  // *starts* a press, so gating it here is enough to keep a disabled or
  // loading button from ever entering the pressed state. Up/cancel below
  // always resolve any in-flight press unconditionally so a press started
  // while interactive still ends cleanly even if that changes before
  // release (see the GestureDetector wiring comment in build()).
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
    final bool hasOnPressed = _hasOnPressed;
    final bool interactive = _interactive;
    final ({double height, double horizontalPadding}) metrics = _metricsFor(
      widget.size,
    );

    final Color? background = _resolveBackground(
      colors: colors,
      variant: widget.variant,
      enabled: hasOnPressed,
      pressed: _pressed,
    );
    final BorderSide side =
        hasOnPressed && widget.variant == CruxButtonVariant.tonal
        ? BorderSide(color: colors.accentLine)
        : BorderSide.none;
    // Also doubles as the loading spinner's color: this is exactly the
    // label's own foreground color for whichever variant/enabled state is
    // showing, so reusing it keeps the spinner visually consistent with the
    // label it temporarily replaces.
    final Color textColor = _resolveTextColor(
      colors: colors,
      variant: widget.variant,
      enabled: hasOnPressed,
    );
    final TextStyle labelStyle =
        (widget.size == CruxButtonSize.small
                ? theme.typography.label.copyWith(fontSize: 13)
                : theme.typography.label)
            .copyWith(color: textColor);

    return Semantics(
      container: true,
      button: true,
      enabled: interactive,
      // No explicit `label` here: the child `Text` below already supplies
      // its own automatic semantics label, and neither this Semantics nor
      // RenderParagraph creates a semantics boundary between them, so an
      // explicit label here would merge with the Text's and be announced
      // twice ("<label>, <label>").
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // These three callbacks stay wired unconditionally (not gated by
        // `interactive`) so the Tap gesture recognizer is never torn out of
        // GestureDetector's gesture arena mid-press: if `interactive` flips
        // to false while a finger is down (e.g. disabling the button from
        // inside its own onPressed), gating these to null here would make
        // GestureDetector dispose the in-flight recognizer, which
        // synchronously resolves it as rejected and calls the *stale*
        // onTapCancel closure -- triggering setState() during build.
        // Instead, `_interactive` is checked inside the handlers themselves,
        // so any in-flight press always resolves cleanly.
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: interactive ? widget.onPressed : null,
        child: CruxMotion.scale(
          value: _pressed ? CruxMotion.pressedScale : 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            // IntrinsicWidth (not a bare Center/Align) ties the pill's width
            // to its label's content: an Align-family widget fills its
            // incoming constraints' maxWidth whenever that is finite (which
            // it almost always is), only shrink-wrapping when maxWidth is
            // infinite -- that greedy-fill behavior would stretch every
            // CruxButton to its parent's full available width instead of
            // hugging its label. IntrinsicWidth measures the child's own
            // preferred width first and hands it a tight constraint at that
            // width instead (clamped against whatever constraints flow in,
            // so the 44px minimum tap target still applies).
            child: IntrinsicWidth(
              child: Container(
                height: metrics.height,
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.horizontalPadding,
                ),
                decoration: ShapeDecoration(
                  color: background,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    side: side,
                  ),
                ),
                alignment: Alignment.center,
                // The label Text is always laid out (as the Stack's only
                // non-Positioned child, it alone determines the Stack's --
                // and therefore the whole button's -- size), just hidden via
                // Opacity while loading, so toggling `loading` never changes
                // the button's dimensions. The spinner is layered on top via
                // Positioned.fill, which Stack sizing ignores entirely.
                //
                // Positioned.fill hands its child tight constraints matching
                // the label's own box, which can be narrower than the
                // spinner's natural 16x16 (e.g. a one-character label). A
                // bare Center would still squeeze the spinner down to fit,
                // since it only loosens the minimum constraint, not the
                // maximum. OverflowBox drops the incoming constraints
                // entirely so the spinner always lays out at its natural
                // size and stays centered, painting into the pill's tap
                // target padding without being clipped.
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Opacity(
                      opacity: widget.loading ? 0 : 1,
                      // alwaysIncludeSemantics keeps the label Text in the
                      // semantics tree even at opacity 0: without it,
                      // RenderOpacity drops a fully-transparent child
                      // entirely while loading, leaving the button with no
                      // accessible name (WCAG 4.1.2).
                      alwaysIncludeSemantics: true,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                    if (widget.loading)
                      Positioned.fill(
                        child: OverflowBox(
                          minWidth: 0,
                          minHeight: 0,
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: CruxSpinner(
                            size: CruxSpinnerSize.small,
                            color: textColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves the pill's background for [variant]/[enabled], layering the
/// pressed-state overlay on top when [pressed] is true.
Color? _resolveBackground({
  required CruxColors colors,
  required CruxButtonVariant variant,
  required bool enabled,
  required bool pressed,
}) {
  final Color? base = !enabled
      ? (variant == CruxButtonVariant.ghost ? null : colors.separator)
      : switch (variant) {
          CruxButtonVariant.filled => colors.accent,
          CruxButtonVariant.tonal => colors.accentTint,
          CruxButtonVariant.ghost => null,
        };

  if (!enabled || !pressed) {
    return base;
  }

  final double overlayOpacity = variant == CruxButtonVariant.filled
      ? _pressedOverlayOpacityFilled
      : _pressedOverlayOpacity;
  final Color overlay = colors.textPrimary.withValues(alpha: overlayOpacity);

  // ghost has no `base` to blend onto (it renders no fill at rest), so its
  // pressed background is just the overlay color at its own alpha.
  if (base == null) {
    return overlay;
  }
  return Color.alphaBlend(overlay, base);
}

/// Resolves the label color for [variant]/[enabled].
Color _resolveTextColor({
  required CruxColors colors,
  required CruxButtonVariant variant,
  required bool enabled,
}) {
  if (!enabled) {
    return colors.muted;
  }
  return variant == CruxButtonVariant.filled
      ? colors.onAccent
      : colors.textPrimary;
}
