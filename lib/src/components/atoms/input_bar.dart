import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey,
        TextInputFormatter;

import '../../internal/text_field_core.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';
import '../../tokens/typography.dart';

/// The fixed size of every interactive slot [CruxInputBar] renders inside
/// its own box: the leading decoration, the clear button, and the submit
/// button. Matches this package's usual 44 logical pixel minimum tap target
/// (see `button.dart`/`chip.dart`/`switch.dart`/`text_form_field.dart`'s
/// identically-shaped, independently-declared constants — per this
/// package's established convention, this is a fresh, file-local copy, not
/// a shared token).
///
/// [CruxInputBarLeading] is not tappable, but it still occupies this same
/// 44px slot: doing so keeps its icon vertically and horizontally aligned
/// with the clear/submit buttons on the opposite edge, in both the pill
/// (single-line) and expanded (multi-line) shapes.
const double _slotSize = 44;

/// The diameter of [CruxInputBar]'s submit button's *visible* filled
/// circle -- smaller than its own [_slotSize] tap target, per IB-D02. The
/// gap between the two is transparent, invisible padding: the circle reads
/// as a comfortably sized, uncluttered button while the actual tappable area
/// stays at the package's usual 44px minimum.
const double _submitVisibleDiameter = 32;

/// The padding applied inside [CruxInputBar]'s own box, on every edge that
/// is not already occupied by a 44px slot (see [_slotSize]). Matches
/// `text_field_core.dart`'s own default content padding value -- again, a
/// fresh file-local copy rather than an import of that file's private
/// constant, per this package's per-file-constant convention.
const double _boxPadding = CruxSpacing.s12;

/// The height reserved, once [CruxInputBar] is fully expanded into its
/// two-row shape (IB-A05), for the action row below the text -- tall enough
/// to hold a [_slotSize] tap target plus a small gap above it separating it
/// from the text above.
const double _actionRowHeight = _slotSize + CruxSpacing.s8;

/// The opacity [CruxInputBarLeading]'s icon renders at while
/// [CruxInputBar.enabled] is `false`. Matches
/// `text_form_field.dart`'s own `_disabledOpacity` value -- again, a fresh
/// file-local copy of the same agreed number, not a shared token.
const double _disabledOpacity = 0.55;

/// A small, decorative icon shown at the leading edge of a [CruxInputBar]
/// -- for example a magnifying glass on a search bar. Purely decorative:
/// unlike [CruxInputBarClear] and [CruxInputBarSubmit], it is never
/// tappable and carries no screen-reader label of its own (a decoration has
/// nothing to announce).
///
/// This package never draws its own glyph for this slot -- the same reason
/// [CruxTextFormField.obscureToggle] takes caller-supplied icons rather
/// than a built-in icon font (see [CruxObscureToggle]'s class doc):
/// different products ship completely different icon sets, and `crux_ui`
/// has no way to know which one any given consumer uses.
@immutable
class CruxInputBarLeading {
  /// Creates a leading decoration for [CruxInputBar.leading].
  const CruxInputBarLeading({required this.icon});

  /// The decorative icon to render. A caller-supplied [Widget], not an
  /// [IconData] -- this package draws whatever it is given without caring
  /// which icon system (if any) produced it.
  final Widget icon;
}

/// The button [CruxInputBar] shows at its trailing edge only while its
/// text is non-empty (IB-D03), letting the user empty the field in one tap.
/// Tapping it clears [CruxInputBar.controller]'s text and calls
/// [CruxInputBar.onChanged] with the empty string.
///
/// [icon] and [label] are both required and caller-supplied, for the same
/// reason [CruxObscureToggle]'s icons and labels are (see that class's
/// doc): this package has no fixed glyph or language of its own to fall
/// back to, and an icon-only button with no accessible name would fail
/// WCAG 4.1.2.
@immutable
class CruxInputBarClear {
  /// Creates a clear button for [CruxInputBar.clear].
  const CruxInputBarClear({required this.icon, required this.label});

  /// The icon to render (for example an "x-in-circle" glyph).
  final Widget icon;

  /// The label a screen reader announces for this button (for example
  /// "消去" / "Clear").
  final String label;
}

/// The submit button [CruxInputBar] shows at its trailing edge, drawn as
/// [icon] centered over an [CruxColors.accent]-filled circle. Tapping it
/// while the field has text calls [CruxInputBar.onSubmit] with the current
/// text; tapping it while the field is empty does nothing (the button
/// renders in a visibly disabled tone instead, per IB-D08 -- see
/// [CruxInputBar]'s class doc, "Submit button" section, for the exact
/// colors and how the transition between them animates).
///
/// [icon] and [label] are both required and caller-supplied, for the same
/// reason [CruxInputBarClear]'s are.
@immutable
class CruxInputBarSubmit {
  /// Creates a submit button for [CruxInputBar.submit].
  const CruxInputBarSubmit({required this.icon, required this.label});

  /// The icon to render (for example an upward arrow).
  final Widget icon;

  /// The label a screen reader announces for this button (for example
  /// "送信" / "Send").
  final String label;
}

/// A compact, pill-shaped text input bar for search boxes and chat
/// composers: Crux UI's second text-input atom, built on the same shared
/// [CruxTextFieldCore] [CruxTextFormField] uses, but a plain
/// [StatefulWidget] rather than a `Form`-integrated [FormField] (IB-D05) --
/// this bar has no label, no helper/error caption row, and no validation
/// concept at all (IB-D04).
///
/// ```dart
/// CruxInputBar(
///   placeholder: '検索',
///   leading: CruxInputBarLeading(icon: const Icon(CupertinoIcons.search)),
///   clear: CruxInputBarClear(
///     icon: const Icon(CupertinoIcons.clear_circled_solid),
///     label: '消去',
///   ),
///   onSubmit: (String query) => runSearch(query),
/// )
/// ```
///
/// **Single line vs. multi-line.** [maxLines] defaults to `1`: the bar never
/// grows, and stays a pill (its corner radius is always exactly half its own
/// height) no matter how much text is entered -- text scrolls horizontally
/// inside it instead, exactly like an ordinary single-line field. Set
/// [maxLines] to `2` or higher (for example for a chat composer) to let the
/// bar grow: it starts as the same one-line pill, then the moment the
/// entered text needs more than one line to display, it morphs smoothly
/// (IB-A07) into a two-row shape -- text on top (using the box's full
/// width), a compact action row underneath (leading on the start edge,
/// clear/submit on the end edge) -- and its corner radius settles at a
/// fixed [CruxRadii.l] (16px) instead of continuing to track the box's
/// growing height. The box keeps growing, one line at a time, until it
/// reaches [maxLines] lines, then stops and scrolls internally beyond that.
///
/// Whether the current text needs more than one line is measured directly
/// (via a throwaway [TextPainter] laid out at the width the text area would
/// have *in the one-line shape*), not inferred from whichever shape the bar
/// currently happens to be in -- measuring against a fixed reference width
/// like this is what keeps the two shapes from oscillating (grow -> now
/// fits on one line at the wider shape's width -> shrink -> overflows again
/// -> grow ...).
///
/// **The morph itself.** Only ever driven by a single animated `0.0`-`1.0`
/// double (via [CruxMotion.animatedValue]), never by interpolating between
/// two [RoundedSuperellipseBorder]s directly -- linearly interpolating a
/// pill's ~huge corner radius down to 16 gets clamped to the pill shape for
/// almost the entire animation and only visibly changes shape in the last
/// instant, since the corner gets scaled back down to fit the rect at paint
/// time regardless of the requested radius (see
/// `unknowns/input-bar/impact.md`'s opening section for the full SDK-sourced
/// explanation). Instead, this bar's own private [ShapeBorder] computes its
/// *effective* radius fresh at paint time, from the box's actual laid-out
/// height and the current animated progress, so it is never clamped, and the
/// corner genuinely passes through every radius between the pill's and 16 on
/// its way from one shape to the other. The two action-row buttons' vertical
/// position (dead center in the one-line shape, bottom-aligned once
/// expanded) and the text area's own reserved side padding (room for the
/// leading/clear/submit slots in the one-line shape, full width once
/// expanded) both animate from the exact same progress value, so every part
/// of the transformation moves in lockstep.
///
/// **Newline key behavior (IB-A03).** Only relevant once [maxLines] is `2`
/// or higher -- a single-line bar always treats the return key as "submit"
/// (IB-A04), the same as an ordinary search field. For a multi-line bar, the
/// return key's meaning switches automatically by platform, and this switch
/// cannot be overridden by a caller:
///
/// | Platform | Return key | How to enter a literal newline |
/// |---|---|---|
/// | macOS, Windows, Linux, Fuchsia | Calls [onSubmit] | Shift+Return |
/// | iOS, Android | Inserts a newline | Return |
///
/// The judgment is [defaultTargetPlatform], not a live check of whether a
/// physical keyboard is actually attached -- Flutter has no reliable way to
/// tell the two apart. This is a known, accepted approximation with real
/// edge cases: opening the web build of an app in a phone's mobile browser
/// reports a desktop-shaped platform in some circumstances (see
/// flutter/flutter#80505 and flutter/flutter#58171), Android cannot
/// distinguish an on-screen keyboard's keystrokes from a physical one (see
/// flutter/flutter#148375), and a phone or tablet with a physical keyboard
/// attached is judged as a phone regardless. All three are accepted
/// trade-offs (agreed as IB-A03 in `unknowns/input-bar/ledger.md`), not bugs
/// to fix here.
///
/// **Submit button.** Rendered from [submit] as [CruxInputBarSubmit.icon]
/// centered over a filled circle: [_submitVisibleDiameter] logical pixels
/// across, inside a [_slotSize] (44px) tap target -- the difference is
/// transparent padding, not a smaller hit area (IB-D02). While the field's
/// text is empty, the button is visibly disabled (background
/// [CruxColors.separator], icon [CruxColors.muted], matching
/// [CruxButton]'s own disabled treatment) and does nothing when tapped;
/// the moment the field has any text, it switches to an enabled look
/// (background [CruxColors.accent], icon [CruxColors.onAccent]) and
/// starts calling [onSubmit] with the current text. Both colors animate
/// smoothly between their two states (via [CruxMotion.animatedColor],
/// IB-D08) rather than snapping, so this reads as the same responsive
/// "material" as the rest of this bar's motion instead of a disconnected
/// flicker.
///
/// **Clear button.** Rendered from [clear] only while the field's text is
/// non-empty (IB-D03) -- there is nothing to clear otherwise. Tapping it
/// empties [controller]'s text and calls [onChanged] with the empty string.
///
/// **Disabled ([enabled] = `false`).** The field stops accepting input.
/// [leading]'s icon dims to 55% opacity (matching
/// [CruxTextFormField]'s own disabled treatment) since it is purely
/// decorative and has nothing else to communicate the disabled state with.
/// [clear] and [submit], by contrast, are never hidden or dimmed by
/// `enabled` directly -- they simply stop responding to taps, and
/// [submit] already renders in its own "disabled" tone (see "Submit
/// button" above) whenever the bar as a whole is disabled, exactly as it
/// does when the field is merely empty; there is no third, bar-disabled
/// -specific tone to introduce.
///
/// **What this bar never does.** No border-color change of any kind --
/// there is no validation-error concept here at all (IB-D04), unlike
/// [CruxTextFormField]. No focus-triggered appearance change (IB-D06,
/// consistent with every other Crux atom). No `Form` participation
/// (IB-D05) -- wrap a plain [StatefulWidget] tree around this instead of a
/// [Form] if a caller needs to coordinate it with other fields.
///
/// **Semantics.** The field itself exposes the standard `textField: true`
/// semantics flag, following [enabled]. [clear] and [submit] are each
/// wrapped in `Semantics(button: true, label: ..., excludeSemantics: true)`
/// using their own supplied [CruxInputBarClear.label] /
/// [CruxInputBarSubmit.label] -- the same "no descendant text to rely on,
/// so this button must set its own explicit label" reasoning
/// [CruxTextFormField]'s obscure toggle uses. Both are wrapped in
/// [TextFieldTapRegion] so tapping them never unfocuses the field or
/// dismisses the keyboard, the same mechanism
/// [CruxTextFormField]'s obscure toggle relies on.
class CruxInputBar extends StatefulWidget {
  /// Creates a Crux input bar.
  const CruxInputBar({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.enabled = true,
    this.maxLines = 1,
    this.leading,
    this.clear,
    this.submit,
    this.onChanged,
    this.onSubmit,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
  });

  /// Controls the text being edited. If `null` (the default), this widget
  /// creates and owns a [TextEditingController] internally.
  final TextEditingController? controller;

  /// Controls whether this field has keyboard focus. If `null` (the
  /// default), this widget creates and owns a [FocusNode] internally.
  final FocusNode? focusNode;

  /// The hint text shown inside the box while the value is empty. Passed
  /// straight through to [CruxTextFieldCore.placeholder].
  final String? placeholder;

  /// Whether the field accepts input. See the class doc's "Disabled"
  /// section for exactly what changes (and what does not) while this is
  /// `false`.
  final bool enabled;

  /// The number of lines this bar grows to before it scrolls internally
  /// instead of growing further. Defaults to `1`: the bar never grows and
  /// stays a pill regardless of how much text is entered. `2` or higher
  /// enables the smooth morph into a two-row shape described in the class
  /// doc's "Single line vs. multi-line" section.
  final int maxLines;

  /// An optional decorative icon at the bar's leading edge (for example a
  /// magnifying glass on a search bar). Never tappable. Pass `null` (the
  /// default) to render no leading decoration at all.
  final CruxInputBarLeading? leading;

  /// An optional clear button, shown only while the field has text. Pass
  /// `null` (the default) to never render one, even when the field has
  /// text.
  final CruxInputBarClear? clear;

  /// An optional submit button. Pass `null` (the default) to render no
  /// submit button at all -- for example a chat composer whose only way to
  /// send is the return key.
  final CruxInputBarSubmit? submit;

  /// Called with the new text on every user edit.
  final ValueChanged<String>? onChanged;

  /// Called with the current text whenever the bar is submitted -- by
  /// tapping [submit], or by the return key, per the class doc's "Newline
  /// key behavior" section.
  final ValueChanged<String>? onSubmit;

  /// The type of keyboard to show. Passed straight through to
  /// [CruxTextFieldCore.keyboardType].
  final TextInputType? keyboardType;

  /// Optional input formatters applied to every edit. Passed straight
  /// through to [CruxTextFieldCore.inputFormatters].
  final List<TextInputFormatter>? inputFormatters;

  /// Optional autofill hints (for example `AutofillHints.email`). Passed
  /// straight through to [CruxTextFieldCore.autofillHints].
  final Iterable<String>? autofillHints;

  @override
  State<CruxInputBar> createState() => _CruxInputBarState();
}

class _CruxInputBarState extends State<CruxInputBar> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? _internalController!;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    // Subscribed regardless of who owns the controller: unlike
    // CruxTextFormField (a real FormField, whose own didChange/setValue
    // plumbing already triggers a rebuild for the internally-owned-
    // controller case), this is a plain StatefulWidget with nothing else
    // that would notice a text change and rebuild -- so this bar always
    // needs its own listener, whether the controller came from the caller
    // or was created just above, to recompute the derived state build()
    // reads every rebuild (whether the field is empty, and -- once
    // maxLines >= 2 -- whether the current text now needs more than one
    // line).
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CruxInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final TextEditingController oldEffective =
          oldWidget.controller ?? _internalController!;
      oldEffective.removeListener(_handleControllerChanged);

      if (widget.controller == null) {
        // Switched from an external controller to none: this bar must own
        // one again from here on, seeded with the outgoing controller's
        // last value so no text is lost across the swap.
        _internalController = TextEditingController.fromValue(
          oldWidget.controller!.value,
        );
      } else if (oldWidget.controller == null) {
        // Switched from none to an external controller: the internally
        // -owned one is no longer needed.
        _internalController?.dispose();
        _internalController = null;
      }
      _controller.addListener(_handleControllerChanged);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      if (widget.focusNode == null) {
        _internalFocusNode = FocusNode();
      } else if (oldWidget.focusNode == null) {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      // A change between two different external nodes needs nothing
      // further: neither side is a node this state owns.
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    // Only ever needed to make this bar's own build() re-run and recompute
    // its derived state (see initState's doc above) -- this is never how
    // widget.onChanged is invoked; that is wired directly from
    // CruxTextFieldCore.onChanged below, matching an ordinary text
    // field's "only fires for user edits, not programmatic controller
    // writes" contract.
    setState(() {});
  }

  void _handleClearTap() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _handleSubmitTap() {
    widget.onSubmit?.call(_controller.text);
  }

  /// Intercepts a bare (non-Shift) hardware Return keystroke on a desktop
  /// platform, while [CruxInputBar.maxLines] is `2` or higher, and turns
  /// it into an [CruxInputBar.onSubmit] call instead of letting it reach
  /// [CruxTextFieldCore]'s [CupertinoTextField] at all -- see the class
  /// doc's "Newline key behavior" section for the full table this
  /// implements.
  ///
  /// This has to intercept at the [Focus]/key-event level, not merely wire
  /// [CruxTextFieldCore.onSubmitted]: a multi-line [CupertinoTextField]'s
  /// own default on-screen keyboard action is "newline", not "done" (
  /// confirmed against the Flutter SDK -- `cupertino/text_field.dart`
  /// defaults `keyboardType` to `TextInputType.multiline` whenever
  /// `maxLines != 1`, and `widgets/editable_text.dart` in turn defaults
  /// `inputAction` to `TextInputAction.newline` whenever `keyboardType ==
  /// TextInputType.multiline`), so a desktop platform's hardware Return key
  /// is handled by the engine's own text-editing channel, never surfacing
  /// through `onSubmitted` at all. A single-line bar has no such gap --
  /// `TextInputType.text`'s own default action is `done`, which does reach
  /// `onSubmitted` -- so this interceptor only ever needs to act once
  /// [CruxInputBar.maxLines] is 2 or higher; see [CruxTextFieldCore
  /// .onSubmitted]'s wiring below for the single-line path.
  ///
  /// Reacts to both a [KeyDownEvent] (the keystroke's first frame) and every
  /// following [KeyRepeatEvent] the OS synthesizes while the key stays held
  /// -- not [KeyDownEvent] alone. [Shortcuts]' own [SingleActivator] defaults
  /// to reacting to repeats too (`includeRepeats` defaults to `true`,
  /// Flutter SDK `widgets/shortcuts.dart`), and
  /// `DefaultTextEditingShortcuts` binds Return to
  /// `DoNothingAndStopPropagationTextIntent` specifically so it reaches
  /// `EditableText`'s IME-backed text insertion instead of being swallowed
  /// as "handled, nothing happens" -- so a `KeyDownEvent`-only guard here
  /// would submit exactly once on the first frame, then leak every
  /// subsequent repeat straight through to that binding, inserting a
  /// newline into the field for as long as Return stayed held. Treating a
  /// repeat the same as the initial key-down closes that gap.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.maxLines < 2) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final bool isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    if (isMobilePlatform) {
      // Return always inserts a newline on a phone; let it fall through
      // to the field unhandled.
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      // Shift+Return is the documented way to enter a literal newline on
      // desktop; let it fall through unhandled too.
      return KeyEventResult.ignored;
    }
    widget.onSubmit?.call(_controller.text);
    return KeyEventResult.handled;
  }

  /// Whether [text] needs more than one line to display at [maxWidth] --
  /// the width the text area would have *in the one-line shape*, per the
  /// class doc's "Single line vs. multi-line" section on why this measures
  /// against a fixed reference width rather than however this bar currently
  /// happens to be shaped (to avoid oscillating between the two shapes).
  /// Only ever called while [CruxInputBar.maxLines] is 2 or higher.
  bool _wouldWrapToMultipleLines({
    required BuildContext context,
    required String text,
    required CruxTypography typography,
    required CruxColors colors,
    required double maxWidth,
  }) {
    if (text.isEmpty) {
      return false;
    }
    if (maxWidth <= 0) {
      // A degenerately narrow parent: treat as already wrapping rather
      // than laying out a TextPainter at a non-positive width.
      return true;
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: typography.body.copyWith(color: colors.textPrimary),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.computeLineMetrics().length > 1 || text.contains('\n');
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool enabled = widget.enabled;
    final String text = _controller.text;
    final bool hasText = text.isNotEmpty;
    final bool clearVisible = widget.clear != null && hasText;
    final bool hasLeading = widget.leading != null;
    final int trailingSlotCount =
        (clearVisible ? 1 : 0) + (widget.submit != null ? 1 : 0);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The width available for the leading/trailing slot reservation
        // math below is this bar's own outer width: nothing sits between
        // this LayoutBuilder and the decorated box, so constraints.maxWidth
        // here is exactly the box's own width.
        final double leadingReserved = hasLeading ? _slotSize : _boxPadding;
        final double trailingReserved = trailingSlotCount == 0
            ? _boxPadding
            : trailingSlotCount * _slotSize;
        final double oneLineTextWidth =
            constraints.maxWidth - leadingReserved - trailingReserved;

        final bool wraps =
            widget.maxLines >= 2 &&
            _wouldWrapToMultipleLines(
              context: context,
              text: text,
              typography: theme.typography,
              colors: colors,
              maxWidth: oneLineTextWidth,
            );

        return CruxMotion.animatedValue(
          value: wraps ? 1.0 : 0.0,
          builder: (BuildContext context, double springValue, Widget? child) {
            // [CruxMotion]'s spring is `CupertinoMotion.snappy`, whose 0.15
            // bounce deliberately overshoots *past* its target at both ends
            // (see motion.dart's `_spring` doc). So this raw value dips
            // slightly below 0.0 while collapsing and rises slightly above
            // 1.0 while expanding.
            //
            // Every geometric quantity below is derived from it by plain
            // multiplication or interpolation, and an out-of-range factor
            // produces an *illegal* value there, not merely an exaggerated
            // one: the action row's reserved height goes negative and reaches
            // `SizedBox` as `BoxConstraints(h: -0.2; NOT NORMALIZED)`, which
            // throws and then cascades into a series of secondary render-tree
            // assertions. That is what a physical iPhone did on the very
            // first collapse of this bar -- while the whole test suite stayed
            // green, because every test written before it only ever expanded,
            // the direction whose overshoot lands harmlessly above 1.0. The
            // regression test is "collapsing from the two-row shape back to
            // the pill never throws" in test/input_bar_test.dart.
            //
            // Clamping here -- at the single point the animated value enters
            // the layout -- leaves the entire visible spring travel untouched
            // and discards only the out-of-range tail, which has no meaning
            // for this morph in any case: there is no shape rounder than the
            // pill, and none more two-row than the two-row one, to overshoot
            // into.
            final double progress = springValue.clamp(0.0, 1.0);
            return _buildBar(
              context: context,
              colors: colors,
              typography: theme.typography,
              brightness: theme.brightness,
              enabled: enabled,
              hasText: hasText,
              clearVisible: clearVisible,
              hasLeading: hasLeading,
              trailingSlotCount: trailingSlotCount,
              progress: progress,
            );
          },
        );
      },
    );
  }

  Widget _buildBar({
    required BuildContext context,
    required CruxColors colors,
    required CruxTypography typography,
    required Brightness brightness,
    required bool enabled,
    required bool hasText,
    required bool clearVisible,
    required bool hasLeading,
    required int trailingSlotCount,
    required double progress,
  }) {
    // The text area's own side padding: room for the leading/trailing slots
    // in the one-line (pill) shape, plain box padding once fully expanded
    // (the action row moves below the text at that point, so the text no
    // longer needs to dodge the buttons horizontally) -- see the class
    // doc's "The morph itself" section.
    final EdgeInsetsDirectional pillTextPadding = EdgeInsetsDirectional.only(
      start: hasLeading ? _slotSize : _boxPadding,
      top: _boxPadding,
      end: trailingSlotCount == 0 ? _boxPadding : trailingSlotCount * _slotSize,
      bottom: _boxPadding,
    );
    const EdgeInsetsDirectional expandedTextPadding = EdgeInsetsDirectional.all(
      _boxPadding,
    );
    final EdgeInsetsDirectional textPadding = EdgeInsetsDirectional.lerp(
      pillTextPadding,
      expandedTextPadding,
      progress,
    )!;

    final Widget textField = Focus(
      canRequestFocus: false,
      onKeyEvent: _handleKeyEvent,
      child: CruxTextFieldCore(
        controller: _controller,
        focusNode: _focusNode,
        enabled: enabled,
        obscureText: false,
        colors: colors,
        typography: typography,
        brightness: brightness,
        contentPadding: textPadding,
        placeholder: widget.placeholder,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onSubmitted: _handleSubmitOnDone,
        maxLines: widget.maxLines,
      ),
    );

    // The Stack's own size is entirely determined by this Column, its only
    // non-positioned child: the text row, plus (once expanded) an empty
    // spacer reserving room for the action row that is Positioned over it
    // below. See the class doc's "The morph itself" section.
    final Widget sizingColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        textField,
        SizedBox(height: _actionRowHeight * progress),
      ],
    );

    final List<Widget> stackChildren = <Widget>[sizingColumn];

    final CruxInputBarLeading? leading = widget.leading;
    if (leading != null) {
      stackChildren.add(
        Positioned.fill(
          child: Align(
            alignment: AlignmentDirectional.lerp(
              AlignmentDirectional.centerStart,
              AlignmentDirectional.bottomStart,
              progress,
            )!,
            child: _buildLeading(leading, enabled),
          ),
        ),
      );
    }

    if (trailingSlotCount > 0) {
      stackChildren.add(
        Positioned.fill(
          child: Align(
            alignment: AlignmentDirectional.lerp(
              AlignmentDirectional.centerEnd,
              AlignmentDirectional.bottomEnd,
              progress,
            )!,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (clearVisible) _buildClear(widget.clear!, enabled),
                if (widget.submit != null)
                  _buildSubmit(
                    submit: widget.submit!,
                    enabled: enabled,
                    hasText: hasText,
                    colors: colors,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // A plain DecoratedBox, not a Container: Container's own build() method
    // internally composes a second DecoratedBox with this exact same
    // decoration whenever only `decoration` is set (no padding/margin/
    // alignment), which would leave *two* widgets in the tree matching
    // "a Container or DecoratedBox painting CruxColors.controlFill" --
    // ambiguous for any test (or future widgetbook/example code) that finds
    // this box by its decoration rather than a key.
    final Widget box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _slotSize),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.controlFill,
          shape: _InputBarBoxShape(
            expandProgress: progress,
            side: BorderSide(color: colors.separator),
          ),
        ),
        child: Stack(children: stackChildren),
      ),
    );

    return Semantics(
      container: true,
      textField: true,
      enabled: enabled,
      child: box,
    );
  }

  /// Wired to [CruxTextFieldCore.onSubmitted]. Reached only via the
  /// on-screen keyboard's own "done" action -- see [_handleKeyEvent]'s doc
  /// for why a hardware Return key on a multi-line bar never reaches this
  /// at all, and instead goes through that separate interceptor.
  void _handleSubmitOnDone(String text) {
    widget.onSubmit?.call(text);
  }

  Widget _buildLeading(CruxInputBarLeading leading, bool enabled) {
    return Opacity(
      opacity: enabled ? 1.0 : _disabledOpacity,
      child: SizedBox(
        width: _slotSize,
        height: _slotSize,
        // Purely decorative (see CruxInputBarLeading's own class doc): a
        // caller-supplied icon widget could carry its own semantics (a
        // semanticLabel, say) without this bar's knowledge, so this must be
        // excluded explicitly rather than relying on "callers happen not to
        // attach any" to keep that doc's "carries no screen-reader label of
        // its own" claim true in practice.
        child: ExcludeSemantics(child: Center(child: leading.icon)),
      ),
    );
  }

  Widget _buildClear(CruxInputBarClear clear, bool enabled) {
    return TextFieldTapRegion(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: clear.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _handleClearTap : null,
          child: Opacity(
            opacity: enabled ? 1.0 : _disabledOpacity,
            child: SizedBox(
              width: _slotSize,
              height: _slotSize,
              child: Center(child: clear.icon),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmit({
    required CruxInputBarSubmit submit,
    required bool enabled,
    required bool hasText,
    required CruxColors colors,
  }) {
    final bool submitEnabled = enabled && hasText;
    // Disabled fill is `mutedFill`, not `separator`: this circle sits inside
    // the bar's own controlFill-filled box, where separator is nearly the
    // same color (~1.03:1) and the circle vanished entirely -- caught by the
    // user on a real device, see colors.dart's [CruxColors.mutedFill] doc
    // for the full reasoning. mutedFill is translucent; animatedColor
    // interpolates alpha along with RGB (see its doc), so the accent circle
    // dissolves into the box's own fill as the bar empties rather than
    // snapping.
    final Color background = submitEnabled ? colors.accent : colors.mutedFill;
    final Color foreground = submitEnabled ? colors.onAccent : colors.muted;

    return TextFieldTapRegion(
      child: Semantics(
        container: true,
        button: true,
        enabled: submitEnabled,
        label: submit.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: submitEnabled ? _handleSubmitTap : null,
          child: SizedBox(
            width: _slotSize,
            height: _slotSize,
            child: Center(
              child: CruxMotion.animatedColor(
                value: background,
                builder: (BuildContext context, Color bg, Widget? child) {
                  return DecoratedBox(
                    decoration: ShapeDecoration(
                      color: bg,
                      shape: const CircleBorder(),
                    ),
                    child: child,
                  );
                },
                child: SizedBox(
                  width: _submitVisibleDiameter,
                  height: _submitVisibleDiameter,
                  child: Center(
                    child: CruxMotion.animatedColor(
                      value: foreground,
                      builder: (BuildContext context, Color fg, Widget? child) {
                        return IconTheme.merge(
                          data: IconThemeData(color: fg),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: fg),
                            child: child!,
                          ),
                        );
                      },
                      child: submit.icon,
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

/// The [ShapeBorder] behind [CruxInputBar]'s own box -- see that class's
/// doc, "The morph itself" section, for why this exists instead of
/// interpolating between two [RoundedSuperellipseBorder]s directly.
///
/// Every method here that needs a concrete shape to delegate to
/// ([getOuterPath], [getInnerPath], [paint]) builds a fresh
/// [RoundedSuperellipseBorder] from [expandProgress] and the incoming
/// `rect`'s own height, rather than storing one -- the height is only known
/// at paint time, not when this object is constructed.
@immutable
class _InputBarBoxShape extends ShapeBorder {
  const _InputBarBoxShape({required this.expandProgress, required this.side});

  /// `0.0` renders the pill shape (radius == the box's own height / 2),
  /// `1.0` renders the fully expanded shape (a fixed [CruxRadii.l]
  /// radius); values in between are a genuine, gradually-changing radius,
  /// not a value clamped near one end -- see this class's own doc.
  final double expandProgress;

  /// The border stroke, drawn at a fixed color regardless of
  /// [expandProgress] -- [CruxInputBar] never changes its border color
  /// (IB-D04).
  final BorderSide side;

  double _effectiveRadius(Rect rect) {
    return lerpDouble(rect.height / 2, CruxRadii.l, expandProgress)!;
  }

  RoundedSuperellipseBorder _delegate(Rect rect) {
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(_effectiveRadius(rect))),
      side: side,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return _InputBarBoxShape(
      expandProgress: expandProgress,
      side: side.scale(t),
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _delegate(rect).getInnerPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _delegate(rect).getOuterPath(rect, textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    _delegate(rect).paint(canvas, rect, textDirection: textDirection);
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is _InputBarBoxShape) {
      return _InputBarBoxShape(
        expandProgress: lerpDouble(a.expandProgress, expandProgress, t)!,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is _InputBarBoxShape) {
      return _InputBarBoxShape(
        expandProgress: lerpDouble(expandProgress, b.expandProgress, t)!,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _InputBarBoxShape &&
        other.expandProgress == expandProgress &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(expandProgress, side);
}
