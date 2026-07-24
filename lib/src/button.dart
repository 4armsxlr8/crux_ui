import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'motion.dart';
import 'spacing.dart';
import 'theme.dart';

/// The minimum tap target size for any [CruxButton], regardless of its
/// visual [CruxButtonSize] (KB9): 44 logical pixels, matching the common
/// iOS/Material accessibility guidance for a comfortably tappable target.
const double _minTapTarget = 44;

/// The opacity of the state layer laid over a pressed [CruxButton]'s
/// background (KB7): [CruxColors.textPrimary] at 8%, which reads as
/// darkening in light mode and lightening in dark mode without a second,
/// brightness-specific token.
const double _pressedOverlayOpacity = 0.08;

/// The pressed-state overlay opacity for [CruxButtonVariant.filled]
/// specifically, lower than [_pressedOverlayOpacity].
///
/// [CruxColors.onAccent] (the filled variant's label color) and the
/// overlay color ([CruxColors.textPrimary]) happen to be the exact same
/// value in both palettes (see colors.dart), so any overlay alpha moves the
/// pressed background directly toward the label color and can only shrink
/// their contrast, never grow it. WCAG contrast math (verified in
/// contrast_test.dart) shows the shared 8% overlay drops filled's
/// onAccent-vs-background contrast from its unpressed 4.887:1 down to
/// 4.353:1 — under the 4.5:1 AA floor for normal-size text. 5% keeps the
/// pressed contrast at 4.549:1 (light) / 5.163:1 (dark), both still >= 4.5.
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
class CruxButton extends StatefulWidget {
  /// Creates a Crux pill button.
  const CruxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CruxButtonVariant.filled,
    this.size = CruxButtonSize.medium,
  });

  /// The button's text. Always rendered on a single line with an ellipsis,
  /// so overly long labels are truncated rather than overflowing.
  final String label;

  /// Called when the button is tapped. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// The background/emphasis treatment. Defaults to
  /// [CruxButtonVariant.filled].
  final CruxButtonVariant variant;

  /// The visual height. Defaults to [CruxButtonSize.medium].
  final CruxButtonSize size;

  @override
  State<CruxButton> createState() => _CruxButtonState();
}

class _CruxButtonState extends State<CruxButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  // Only _handleTapDown checks `_enabled`: it is the only handler that
  // *starts* a press, so gating it there is enough to keep a disabled
  // button from ever entering the pressed state. _handleTapUp and
  // _handleTapCancel always resolve any in-flight press unconditionally,
  // so a press started while enabled still ends cleanly even if the button
  // becomes disabled before release (see the onTapDown/Up/Cancel wiring
  // comment in build() for why these three callbacks are never gated by
  // `enabled` themselves).
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
    final ({double height, double horizontalPadding}) metrics = _metricsFor(
      widget.size,
    );

    final Color? background = _resolveBackground(
      colors: colors,
      variant: widget.variant,
      enabled: enabled,
      pressed: _pressed,
    );
    final Border? border =
        enabled && widget.variant == CruxButtonVariant.tonal
        ? Border.all(color: colors.accentLine)
        : null;
    final Color textColor = _resolveTextColor(
      colors: colors,
      variant: widget.variant,
      enabled: enabled,
    );
    final TextStyle labelStyle =
        (widget.size == CruxButtonSize.small
                ? theme.typography.label.copyWith(fontSize: 13)
                : theme.typography.label)
            .copyWith(color: textColor);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      // No explicit `label` here: the child `Text` below already supplies
      // its own automatic semantics label (the same value as widget.label),
      // and neither this Semantics nor RenderParagraph creates a semantics
      // boundary between them, so an explicit label here would merge with
      // the Text's and be announced twice ("<label>, <label>"). This
      // mirrors how Flutter's own RawMaterialButton relies on its
      // descendant Text/Icon for the announced label instead of setting one
      // itself.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // These three callbacks stay wired unconditionally (not gated by
        // `enabled`) so the Tap gesture recognizer is never torn out of
        // GestureDetector's gesture arena mid-press: if `enabled` flips to
        // false while a finger is down (e.g. disabling the button from
        // inside its own onPressed), gating these to null here would make
        // GestureDetector dispose the in-flight recognizer, which
        // synchronously resolves it as rejected and calls the *stale*
        // onTapCancel closure — triggering setState() during build. Instead,
        // `_enabled` is checked inside the handlers themselves, so any
        // in-flight press always resolves cleanly regardless of the
        // current enabled state.
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: CruxMotion.scale(
          value: _pressed ? CruxMotion.pressedScale : 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            // IntrinsicWidth (not a bare Center/Align) ties the pill's width
            // to its label's content: an Align-family widget (Center, or the
            // Align that Container inserts internally for `alignment`) sizes
            // itself to *fill* its incoming constraints' maxWidth whenever
            // that maxWidth is finite -- which it almost always is (any Row,
            // Column, Wrap, or Scaffold body gives a bounded, if loose,
            // width) -- and only shrink-wraps when maxWidth is infinite.
            // That greedy-fill behavior was this widget's actual bug: every
            // CruxButton stretched to its parent's full available width
            // instead of hugging its label. IntrinsicWidth instead measures
            // the child's own preferred width first and hands the child a
            // *tight* constraint at that width (clamped against whatever
            // constraints flow in, so the 44px minimum tap target and
            // narrow-parent overflow safety below both still apply), so the
            // inner Container's `alignment: Alignment.center` -- kept for
            // vertical centering within the pill's fixed height, and for
            // horizontal centering on the rare label narrower than the 44px
            // minimum tap target -- never sees a wider-than-content maxWidth
            // to expand into.
            child: IntrinsicWidth(
              child: Container(
                height: metrics.height,
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.horizontalPadding,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  border: border,
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

/// Resolves the pill's background per the table in plan.md section 2,
/// layering the pressed-state overlay (KB7) on top when [pressed] is true.
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

/// Resolves the label color per the table in plan.md section 2.
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
