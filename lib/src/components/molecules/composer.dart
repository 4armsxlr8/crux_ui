import 'package:flutter/cupertino.dart';

import '../atoms/button.dart';
import '../../internal/text_field_core.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';
import '../../tokens/typography.dart';

/// The fixed size of every tappable slot [CruxComposer] renders inside its
/// own action row -- each [CruxComposerAction] and the counter/submit pair
/// on the opposite edge. Matches this package's usual 44 logical pixel
/// minimum tap target; a file-local copy rather than a shared token.
const double _slotSize = 44;

/// The opacity [CruxComposer]'s action-row buttons render at while
/// [CruxComposer.enabled] is `false`. A file-local copy rather than a
/// shared token.
const double _disabledOpacity = 0.55;

/// A single caller-defined button in [CruxComposer]'s action row -- for
/// example an attachment or camera button.
///
/// [icon] and [label] are both caller-supplied: this package has no fixed
/// glyph or language of its own to fall back to. [onPressed] is bundled
/// into this class too rather than living as a separate [CruxComposer]
/// callback, since [CruxComposer.actions] is a variable-length list and a
/// single fixed callback slot on the widget itself couldn't address more
/// than one of them.
@immutable
class CruxComposerAction {
  /// Creates an action-row button for [CruxComposer.actions].
  const CruxComposerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// The icon to render (for example a paperclip glyph).
  final Widget icon;

  /// The label a screen reader announces for this button.
  final String label;

  /// Called when this button is tapped.
  final VoidCallback onPressed;
}

/// The submit ("post") button [CruxComposer] shows at the trailing edge of
/// its action row whenever supplied. Rendered as a
/// [CruxButton](variant: [CruxButtonVariant.filled], size:
/// [CruxButtonSize.small]) internally.
@immutable
class CruxComposerSubmit {
  /// Creates a submit button for [CruxComposer.submit].
  const CruxComposerSubmit({required this.label});

  /// The button's text (for example "投稿" / "Post"). Passed straight
  /// through to the internal [CruxButton.label].
  final String label;
}

/// A [TextEditingController] subclass built for [CruxComposer]: overrides
/// [buildTextSpan] so that whatever text falls beyond a caller-configured
/// grapheme-cluster limit renders in a distinct "overflow" color -- a bare
/// [TextEditingController] cannot express this at all, because
/// [buildTextSpan] is a method [EditableTextState] calls virtually on
/// whatever controller it is given, not something a caller can inject from
/// outside.
///
/// [CruxComposer] is the only intended caller of the package-private
/// configuration this class exposes -- from any other angle, this behaves
/// exactly like a plain [TextEditingController]. In particular, used
/// standalone (for example wired into a different widget, or never handed to
/// a [CruxComposer] at all), the overflow limit stays unset and
/// [buildTextSpan] delegates straight to the base implementation --
/// including its default composing-underline rendering during IME
/// conversion -- so this class is always safe to use exactly like an
/// ordinary [TextEditingController].
class CruxComposerController extends TextEditingController {
  /// Creates a composer controller for an editable text field, with no
  /// initial selection. See [TextEditingController.new] for the exact
  /// semantics this mirrors.
  CruxComposerController({super.text});

  /// Creates a composer controller from an initial [TextEditingValue]. See
  /// [TextEditingController.fromValue] for the exact semantics this mirrors.
  CruxComposerController.fromValue(super.value) : super.fromValue();

  int? _overflowLimit;
  Color? _overflowColor;

  /// Configures the grapheme-cluster limit and highlight color
  /// [buildTextSpan] renders overflowing text in. Called by [CruxComposer]
  /// on every build, and reset back to `null` / `null` whenever this
  /// controller stops being that widget's active one, so a caller-owned
  /// controller genuinely reverts to plain, unconfigured behavior once
  /// detached.
  ///
  /// This has no leading underscore -- and so is technically callable by
  /// any importer of `package:crux_ui` -- purely because Dart's privacy is
  /// per-library (per file): this package's own tests exercise
  /// [buildTextSpan] directly, from a separate test file, to pin down the
  /// grapheme-boundary split without going through a full [CruxComposer]
  /// widget tree, and a leading-underscore name would make that impossible
  /// from outside this file. [CruxComposer] is still the only caller this
  /// method is meant to have in ordinary use; calling it directly from
  /// application code is unsupported and its shape may change without
  /// notice.
  void applyOverflowStyle({required int? maxLength, required Color? color}) {
    _overflowLimit = maxLength;
    _overflowColor = color;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final int? maxLength = _overflowLimit;
    final Color? overflowColor = _overflowColor;
    // A negative `maxLength` has no meaningful grapheme boundary to split at
    // (and would crash `Characters.take` below), so it is treated as "no
    // limit". Checked here too (not just as CruxComposer's debug-only
    // assert) since this controller can be driven directly.
    if (maxLength == null || overflowColor == null || maxLength < 0) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final Characters characters = text.characters;
    if (characters.length <= maxLength) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    // The grapheme-cluster boundary at `maxLength`, converted to a UTF-16
    // code-unit offset into `text` -- never split mid-surrogate-pair, which
    // slicing `text` directly at `maxLength` *code units* could do for any
    // multi-code-unit grapheme (an emoji, for example) straddling the limit.
    final int splitOffset = characters.take(maxLength).toString().length;

    final bool composingRegionOutOfRange =
        !value.isComposingRangeValid || !withComposing;

    if (composingRegionOutOfRange) {
      return TextSpan(
        style: style,
        children: <TextSpan>[
          TextSpan(text: text.substring(0, splitOffset)),
          TextSpan(
            text: text.substring(splitOffset),
            style: TextStyle(color: overflowColor),
          ),
        ],
      );
    }

    // The composing (IME conversion) underline and the overflow highlight
    // can both apply to overlapping ranges of the same text -- for example
    // typing past the limit while still mid-conversion. Rather than
    // dropping one in favor of the other, every boundary either concept
    // cares about (the overflow split point, and the composing range's own
    // start/end) is merged into one ordered list of cut points, and each
    // resulting slice gets whichever combination of the overflow color and
    // the underline decoration actually applies to it.
    final int composingStart = value.composing.start;
    final int composingEnd = value.composing.end;
    final List<int> boundaries =
        <int>{
            0,
            splitOffset,
            composingStart,
            composingEnd,
            text.length,
          }.where((int offset) => offset >= 0 && offset <= text.length).toList()
          ..sort();

    final List<TextSpan> children = <TextSpan>[];
    for (int i = 0; i < boundaries.length - 1; i++) {
      final int start = boundaries[i];
      final int end = boundaries[i + 1];
      if (start == end) {
        continue;
      }
      final bool isOverflow = start >= splitOffset;
      final bool isComposing = start >= composingStart && end <= composingEnd;
      TextStyle? segmentStyle = isOverflow
          ? TextStyle(color: overflowColor)
          : null;
      if (isComposing) {
        segmentStyle = (segmentStyle ?? const TextStyle()).merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      children.add(
        TextSpan(text: text.substring(start, end), style: segmentStyle),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

/// A borderless, height-filling text area for composing a post: Crux UI's
/// third and last text-input atom, completing the split alongside
/// [CruxTextFormField] and `CruxInputBar`.
///
/// ```dart
/// CruxComposer(
///   placeholder: 'いまどうしてる？',
///   maxLength: 280,
///   submit: const CruxComposerSubmit(label: '投稿'),
///   onSubmit: (String text) => post(text),
/// )
/// ```
///
/// **Everything below the text itself is optional.** Pass no [actions], no
/// [submit], and no [maxLength], and this renders as a bare, borderless
/// text area with nothing else -- the action row described below does not
/// exist at all in that case, not merely render empty. The row appears the
/// moment any one of the three is supplied.
///
/// **Fills the height it is given, and scrolls internally.** Unlike
/// `CruxInputBar`, this does not grow line-by-line with its content --
/// place it inside an [Expanded] (or any other box that hands it a bounded
/// height) and it fills exactly that height, with its own text scrolling
/// vertically once it outgrows the available room. **A genuinely unbounded
/// height ancestor (a bare [Column] with no [Expanded], a `ListView`, a
/// `SingleChildScrollView`) throws a `RenderFlex` layout error at build
/// time**, the same way any other widget that relies on [Expanded] internally
/// would -- this is not a graceful "shrinks to content" fallback. A merely
/// *loose* (bounded but not tight) ancestor does not crash, but also will not
/// visibly "fill the height" the way a tight one does. Keyboard avoidance is
/// deliberately left to the surrounding screen (for example
/// `Scaffold.resizeToAvoidBottomInset`), not handled here.
///
/// **No border, no fill, no radius, no focus-triggered appearance change.**
/// This is the first Crux atom that draws no box of its own at all: it is
/// expected to sit directly on whatever surface a caller already has
/// (typically [CruxColors.background]).
///
/// **The action row**, when it exists, is a single row pinned to the
/// bottom: [actions] on the start edge (each a [_slotSize] tap target), and
/// the character counter plus [submit] on the end edge.
///
/// **The counter** ("`n / max`") appears only while [maxLength] is
/// non-null, in [CruxTypography.caption], and counts *grapheme clusters*
/// via [Characters] -- an emoji or other combined character counts as one,
/// matching how a person actually perceives "one character". It reads
/// [CruxColors.textSecondary] normally and [CruxColors.error] once the
/// text exceeds [maxLength] (only these two states -- there is no
/// intermediate "running low" warning color), transitioning between them
/// via [CruxMotion.animatedColor] rather than snapping.
///
/// **Going over [maxLength] is accepted, never truncated.** Typing or
/// pasting past the limit keeps every character: the counter turns
/// [CruxColors.error], the text beyond the limit renders in
/// [CruxColors.error] too (via [CruxComposerController.buildTextSpan]),
/// and only [submit] disables -- there is no hard stop.
///
/// **[submit] is enabled iff** [enabled] is `true`, the text is non-empty,
/// the text is not over [maxLength], and [onSubmit] is actually supplied --
/// a [submit] bundle with no [onSubmit] stays disabled rather than looking
/// tappable and silently doing nothing, the same "nullable callback means
/// disabled" convention every other Crux control follows. Tapping it
/// while enabled calls [onSubmit] with the controller's current text; it
/// never clears the text itself.
class CruxComposer extends StatefulWidget {
  /// Creates a Crux composer.
  const CruxComposer({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.enabled = true,
    this.maxLength,
    this.actions = const <CruxComposerAction>[],
    this.submit,
    this.onChanged,
    this.onSubmit,
    this.keyboardType,
    this.autofillHints,
  }) : assert(
         maxLength == null || maxLength >= 0,
         'maxLength must be null or non-negative (was $maxLength).',
       );

  /// Controls the text being edited. If `null` (the default), this widget
  /// creates and owns a [CruxComposerController] internally.
  ///
  /// This is a [CruxComposerController], not a plain
  /// [TextEditingController]: the overflow highlight this widget draws past
  /// [maxLength] can only be expressed through that subclass's
  /// [CruxComposerController.buildTextSpan] override (see that class's own
  /// doc).
  final CruxComposerController? controller;

  /// Controls whether this field has keyboard focus. If `null` (the
  /// default), this widget creates and owns a [FocusNode] internally.
  final FocusNode? focusNode;

  /// The hint text shown inside the text area while its value is empty.
  final String? placeholder;

  /// Whether the field accepts input, and whether the action row's buttons
  /// respond to taps.
  final bool enabled;

  /// The grapheme-cluster limit the counter measures against. `null` (the
  /// default) hides the counter entirely and disables the over-limit
  /// highlight/submit-gating behavior described in this class's own doc --
  /// text can grow to any length. Must be `null` or non-negative; a
  /// negative value fails an `assert` at construction time.
  final int? maxLength;

  /// The caller-defined buttons shown at the action row's start edge (for
  /// example an attachment button). An empty list (the default) renders none
  /// of them.
  final List<CruxComposerAction> actions;

  /// An optional submit ("post") button, shown at the action row's end edge.
  /// Pass `null` (the default) to render none.
  final CruxComposerSubmit? submit;

  /// Called with the new text on every user edit.
  final ValueChanged<String>? onChanged;

  /// Called with the current text whenever [submit] is tapped while enabled.
  final ValueChanged<String>? onSubmit;

  /// The type of keyboard to show. Passed straight through to
  /// [CruxTextFieldCore.keyboardType]. Leaving this unset defaults to a
  /// multiline keyboard (see [CruxTextFieldCore.expands]'s doc for why).
  final TextInputType? keyboardType;

  /// Optional autofill hints (for example [AutofillHints.username]).
  final Iterable<String>? autofillHints;

  @override
  State<CruxComposer> createState() => _CruxComposerState();
}

class _CruxComposerState extends State<CruxComposer> {
  CruxComposerController? _internalController;
  FocusNode? _internalFocusNode;

  CruxComposerController get _controller =>
      widget.controller ?? _internalController!;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = CruxComposerController();
    }
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CruxComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final CruxComposerController oldEffective =
          oldWidget.controller ?? _internalController!;
      oldEffective.removeListener(_handleControllerChanged);
      _resetOverflowStyle(oldEffective);

      if (widget.controller == null) {
        _internalController = CruxComposerController.fromValue(
          oldWidget.controller!.value,
        );
      } else if (oldWidget.controller == null) {
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
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _resetOverflowStyle(_controller);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  /// Clears any overflow-highlight configuration this widget applied to
  /// [controller], restoring it to a plain, unconfigured state. Called
  /// whenever [controller] stops being this state's active controller, so a
  /// caller-owned, externally-supplied [CruxComposerController] genuinely
  /// reverts to ordinary [TextEditingController] behavior once detached
  /// instead of continuing to color text using this composer's
  /// last-applied limit/color.
  void _resetOverflowStyle(CruxComposerController controller) {
    controller.applyOverflowStyle(maxLength: null, color: null);
  }

  void _handleControllerChanged() {
    setState(() {});
  }

  void _handleSubmitTap() {
    widget.onSubmit?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography typography = theme.typography;
    final bool enabled = widget.enabled;
    final String text = _controller.text;
    final bool hasText = text.isNotEmpty;
    final int? maxLength = widget.maxLength;
    final int graphemeCount = text.characters.length;
    final bool overLimit = maxLength != null && graphemeCount > maxLength;

    _controller.applyOverflowStyle(maxLength: maxLength, color: colors.error);

    final bool showActionRow =
        widget.actions.isNotEmpty || widget.submit != null || maxLength != null;

    final Widget textArea = CruxTextFieldCore(
      controller: _controller,
      focusNode: _focusNode,
      enabled: enabled,
      obscureText: false,
      colors: colors,
      typography: typography,
      brightness: theme.brightness,
      placeholder: widget.placeholder,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      // Zero bottom inset, unlike the shared core's default (which pads all
      // four sides equally): the bottom edge is dropped entirely so the
      // last line of typed text sits flush against the hairline separator
      // below.
      contentPadding: const EdgeInsets.only(
        left: CruxSpacing.s12,
        top: CruxSpacing.s12,
        right: CruxSpacing.s12,
      ),
    );

    final List<Widget> children = <Widget>[Expanded(child: textArea)];
    if (showActionRow) {
      children.add(
        _buildActionRow(
          colors: colors,
          typography: typography,
          enabled: enabled,
          hasText: hasText,
          overLimit: overLimit,
          graphemeCount: graphemeCount,
          maxLength: maxLength,
        ),
      );
    }

    return Semantics(
      container: true,
      textField: true,
      enabled: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildActionRow({
    required CruxColors colors,
    required CruxTypography typography,
    required bool enabled,
    required bool hasText,
    required bool overLimit,
    required int graphemeCount,
    required int? maxLength,
  }) {
    final List<Widget> leadingActions = <Widget>[
      for (final CruxComposerAction action in widget.actions)
        _buildAction(action, enabled),
    ];

    final List<Widget> trailing = <Widget>[];
    if (maxLength != null) {
      trailing.add(
        _buildCounter(
          colors: colors,
          typography: typography,
          enabled: enabled,
          overLimit: overLimit,
          graphemeCount: graphemeCount,
          maxLength: maxLength,
        ),
      );
    }

    final CruxComposerSubmit? submit = widget.submit;
    if (submit != null) {
      if (trailing.isNotEmpty) {
        trailing.add(const SizedBox(width: CruxSpacing.s8));
      }
      // Gated on `widget.onSubmit != null` too, not just the other enabled
      // conditions: without it, a caller that supplies `submit` but forgets
      // `onSubmit` would see a button that looks and announces itself as
      // enabled, yet silently does nothing when tapped.
      final bool submitEnabled =
          enabled && hasText && !overLimit && widget.onSubmit != null;
      trailing.add(
        TextFieldTapRegion(
          child: CruxButton(
            label: submit.label,
            onPressed: submitEnabled ? _handleSubmitTap : null,
            size: CruxButtonSize.small,
          ),
        ),
      );
    }

    return DecoratedBox(
      // A stable, private structural marker (not a public API -- there is
      // no exported static field for it) so tests can assert the action row
      // container itself is absent for a bare composer, not merely that its
      // contents are invisible. Without this, a mutant that renders the row
      // unconditionally but empty (no actions, no counter, no submit) passes
      // every existing content-based assertion undetected. Carried on this
      // outermost DecoratedBox (rather than the inner Padding) so the check
      // also covers the hairline separator below, which is this box's own
      // border rather than a standalone widget.
      key: const ValueKey('crux_composer_action_row'),
      // The hairline separator above the action row, drawn as this box's
      // own top border instead of a standalone CruxDivider placed as a
      // sibling Column child. A DecoratedBox border paints inside the box
      // without insetting its child, so this adds zero layout height --
      // unlike a divider widget, which would consume its own row in the
      // Column. It overlaps the first pixel of the row's top padding (8,
      // see below), which is empty space regardless since the row's
      // content is vertically centered within its 44px slots.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.separator, width: 1)),
      ),
      child: Padding(
        // Horizontal padding is 6px; the spacing scale has no single s6
        // token, so it's expressed as the sum of the two tokens that add up
        // to it rather than a bare literal. Top and bottom are both 8: an
        // 8px gap separates the separator above from the row's content, and
        // an 8px gap of breathing room sits below it.
        padding: const EdgeInsets.only(
          left: CruxSpacing.s4 + CruxSpacing.s2,
          right: CruxSpacing.s4 + CruxSpacing.s2,
          top: CruxSpacing.s8,
          bottom: CruxSpacing.s8,
        ),
        child: Row(
          children: <Widget>[
            if (leadingActions.isNotEmpty)
              // A single flex child claims exactly the space the trailing
              // cluster (counter/submit) does not need, and its own
              // horizontal scroll view absorbs an arbitrarily long `actions`
              // list by scrolling instead of forcing the whole Row into a
              // hard RenderFlex overflow. Using exactly one flex child
              // (rather than a `Spacer` *and* a `Flexible` counter both
              // claiming a share of the same leftover space) is also what
              // keeps the counter/submit pair pinned flush against the
              // trailing edge -- two equal-weight flex children would each
              // reserve half the leftover space regardless of how much
              // either one actually renders at.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: leadingActions),
                ),
              )
            else if (trailing.isNotEmpty)
              const Spacer(),
            ...trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildAction(CruxComposerAction action, bool enabled) {
    return TextFieldTapRegion(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: action.label,
        excludeSemantics: true,
        // `excludeSemantics: true` above drops every semantics node the
        // GestureDetector below would otherwise contribute -- including its
        // own tap action -- so this node needs its own `onTap` to stay
        // activatable by assistive technology.
        onTap: enabled ? action.onPressed : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? action.onPressed : null,
          child: Opacity(
            opacity: enabled ? 1.0 : _disabledOpacity,
            child: SizedBox(
              width: _slotSize,
              height: _slotSize,
              child: Center(child: action.icon),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter({
    required CruxColors colors,
    required CruxTypography typography,
    required bool enabled,
    required bool overLimit,
    required int graphemeCount,
    required int maxLength,
  }) {
    final Color color = overLimit ? colors.error : colors.textSecondary;
    // Dimmed the same way _buildAction's action buttons are while disabled,
    // so the whole action row reads as consistently disabled rather than
    // showing one dimmed element (the actions) next to one full-color one
    // (the counter).
    return Opacity(
      opacity: enabled ? 1.0 : _disabledOpacity,
      child: CruxMotion.animatedColor(
        value: color,
        builder: (BuildContext context, Color animatedColor, Widget? child) {
          return Text(
            '$graphemeCount / $maxLength',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: typography.caption.copyWith(color: animatedColor),
          );
        },
      ),
    );
  }
}
