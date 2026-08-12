import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../../internal/text_field_core.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';

/// The minimum tap target size for this field's box. In practice the
/// box's own content is already taller than this, so this mostly acts as
/// a floor rather than something that visibly changes the box.
const double _minTapTarget = 44;

/// The opacity the whole field renders at when [CruxTextFormField.enabled]
/// is `false`.
const double _disabledOpacity = 0.55;

/// The gap between the label row and the box below it. Only relevant when
/// [CruxTextFormField.label] is non-`null` — that is the only case a
/// label row exists at all.
const double _labelRowGap = CruxSpacing.s8;

/// The padding inside the box, applied to the actual [CupertinoTextField]'s
/// own content.
const EdgeInsets _boxContentPadding = EdgeInsets.all(CruxSpacing.s12);

/// The gap between the box and the helper/error caption row below it.
const double _helperRowGap = CruxSpacing.s8;

/// The width -- and, via [PositionedDirectional]'s `top`/`bottom` stretch
/// in [_CruxTextFormFieldState._buildContent], also the minimum height
/// -- of [CruxTextFormField.obscureToggle]'s tap target.
const double _obscureToggleTapTarget = 44;

/// Bundles the icons and screen-reader labels a product supplies for
/// [CruxTextFormField]'s optional password show/hide toggle.
///
/// This package never draws its own glyph for this toggle -- different
/// products ship different icon sets, so [obscuredIcon] and [revealedIcon]
/// are plain [Widget]s (an `Icon`, an `Image`, even a `Text` glyph), not
/// [IconData]. Pass an [CruxObscureToggle] to
/// [CruxTextFormField.obscureToggle] to render the toggle; leave it
/// `null` to render none.
///
/// [obscuredLabel] and [revealedLabel] are `required` [String]s: this
/// package has no fixed language to announce, and the toggle is icon-only
/// with no descendant text to fall back to, so an omitted label would mean
/// either no accessible name (failing WCAG 4.1.2) or hardcoded English --
/// requiring both up front pushes that choice to the call site.
@immutable
class CruxObscureToggle {
  /// Creates a bundle of icons and screen-reader labels for
  /// [CruxTextFormField.obscureToggle].
  const CruxObscureToggle({
    required this.obscuredIcon,
    required this.revealedIcon,
    required this.obscuredLabel,
    required this.revealedLabel,
  });

  /// The icon shown while the field's text is hidden. Tapping it reveals
  /// the text (and swaps the visible icon to [revealedIcon]).
  final Widget obscuredIcon;

  /// The icon shown while the field's text is visible. Tapping it hides
  /// the text again (and swaps the visible icon to [obscuredIcon]).
  final Widget revealedIcon;

  /// The label a screen reader announces for the toggle button while the
  /// text is hidden (for example "Show password" / "パスワードを表示").
  final String obscuredLabel;

  /// The label a screen reader announces for the toggle button while the
  /// text is visible (for example "Hide password" / "パスワードを隠す").
  final String revealedLabel;
}

/// A single-line, `Form`-integrated text input field: Crux UI's form text
/// field atom.
///
/// ```dart
/// CruxTextFormField(
///   label: 'メールアドレス',
///   placeholder: 'you@example.com',
///   keyboardType: TextInputType.emailAddress,
///   validator: (String? value) =>
///       (value == null || value.isEmpty) ? '必須項目です' : null,
///   onSaved: (String? value) => _email = value,
/// )
/// ```
///
/// This is a real `FormField<String>`: wrap several of these (and other
/// `FormField`s) in a Flutter [Form] to get batched [FormState.validate] and
/// [FormState.save].
///
/// **The label.** [label] and [placeholder] are two separate things: [label]
/// is the field's name (e.g. `メールアドレス`) and [placeholder] is a hint at
/// the expected format (e.g. `you@example.com`), the same distinction any
/// ordinary form makes between a field's caption and its greyed-out example
/// text. [label], when present, always renders in a row above the box —
/// there is no floating or moving; a field's label sits in the same place
/// whether the value is empty or not, and this row's height is reserved
/// only when [label] is non-`null`, since a `null` label has nothing to
/// reserve space for. [placeholder], when present, renders inside the box
/// itself and disappears the moment the value becomes non-empty, exactly
/// like [CupertinoTextField.placeholder] (which is what it is passed
/// through to). Both render in [CruxColors.textSecondary].
///
/// **The box.** Drawn with a 1 logical pixel outline ([CruxRadii.m]
/// corners) and filled with [CruxColors.controlFill] — a fixed fill that
/// does not change on focus, while typing, or while disabled. The one thing
/// that does change is the border color, on a validation error: it is
/// [CruxColors.separator] while resting and [CruxColors.error] while
/// [FormFieldState.errorText] is non-null, matching the caption row below.
/// Focus and typing still change nothing, even while an error is showing —
/// the border only ever tracks the error state, never focus.
/// [CupertinoTextField]'s own decoration is suppressed (an empty
/// `BoxDecoration`, so it paints neither a border nor — while disabled —
/// the gray fill it would otherwise fall back to) so this outer box is the
/// only thing that paints a border or a fill.
///
/// **Helper text and errors.** [helperText] renders in a caption row below
/// the box; a validation error (surfaced through the field's `validator`,
/// or [FormFieldState.errorText]) replaces it in [CruxColors.error] — the
/// same color the box's border switches to, per "The box" above — and in
/// [CruxTypography.captionStrong] rather than [CruxTypography.caption],
/// so the message reads as louder than plain helper text. Those two tokens
/// share a size and differ only in weight, so the row's height never
/// changes; it is also always reserved, so showing or clearing an error
/// never shifts anything else in the layout.
///
/// **Error shake.** Whenever a validation error appears (`errorText` goes
/// from `null` to non-`null`) the *box* — and only the box, not the label
/// row or caption row — plays a brief horizontal shake via
/// [CruxMotion.shake]. Pressing the same submit button again while an
/// identical error is already showing shakes again too: this field's
/// [FormFieldState.validate] override shakes on every failed call, not
/// only the first, since `errorText`'s value does not change between the
/// two calls but a repeated failed submit is the common real case. An
/// error already showing on this field's very first build (for example an
/// [AutovalidateMode.always] field whose initial value is already invalid)
/// does not shake on mount — there was no prior error-free build to have
/// changed away from. The shake is a paint-time transform only — it never
/// resizes this field or shifts anything around it — and is fully
/// suppressed, never merely shortened, when the OS "reduce motion"
/// accessibility setting is on ([MediaQuery.disableAnimationsOf]).
///
/// **Disabled.** Set [enabled] to `false` to render the whole field (box,
/// label, helper/error text) at 55% opacity and reject input. Unlike the
/// package's other five atoms, this is a plain `bool` rather than "pass
/// `null` to a callback": a text field is commonly used with only a
/// [controller] and no [onChanged] at all, so a nullable-callback
/// convention would have no way to represent "enabled, callback-less" and
/// "disabled" as different states.
///
/// **Obscure toggle.** Set [obscureToggle] to a [CruxObscureToggle] to
/// render a show/hide button at the box's trailing edge (mirrored under
/// RTL). Leaving it `null` (the default) renders no toggle: [obscureText]
/// is then this field's fixed, unchanging obscured state.
///
/// The toggle always occupies a fixed 44x44 logical pixel slot for as long
/// as [obscureToggle] is non-`null` -- toggling swaps the icon in place
/// but never resizes anything, so the box, label row, and caption row stay
/// put. The field's content padding reserves that same 44 pixels on the
/// trailing edge so entered text is never drawn underneath it.
///
/// The toggle sets an explicit `Semantics(label: ...)` and excludes
/// descendant semantics, unlike every other interactive Crux atom (which
/// relies on a descendant `Text` to supply its label): it is icon-only,
/// and its icon is an arbitrary caller-supplied [Widget] that may carry
/// unrelated or absent semantics of its own.
///
/// Tapping the toggle never steals focus or dismisses the keyboard: it is
/// wrapped in a [TextFieldTapRegion], so it counts as "inside" the field
/// for Flutter's focus-handling purposes rather than an outside tap that
/// would unfocus it.
///
/// Toggling is a plain [State.setState] flip of an internal flag -- it
/// never calls [FormFieldState.didChange] or touches the field's actual
/// text [value], since it only changes how the value is *displayed*.
///
/// While [enabled] is `false`, the toggle dims along with the rest of the
/// field and stops responding to taps.
///
/// **Overflow.** Deliberately departs from this package's usual
/// "overflow → ellipsis" rule (see [CruxButton], [CruxChip],
/// [CruxListTile]): a very long value scrolls horizontally to follow the
/// cursor, the same as any single-line text field, rather than being
/// truncated with an ellipsis — ellipsizing entered text while it's being
/// edited would hide what the user just typed.
///
/// **Selection.** Text selection handles and the copy/paste menu use the
/// iOS ("Cupertino") style on every platform -- [CupertinoTextField]'s own
/// default, not something this widget adds. The cursor, selection
/// highlight, and drag handles all use [CruxColors.accent] instead of
/// iOS's default blue or a consuming app's Material primary color, scoped
/// to this widget's own subtree only.
///
/// **Localization.** The selection menu's button wording ("Paste", "Copy",
/// ...) has two separate sources depending on platform, and a non-English
/// app needs to cover both. On iOS 16+, `CupertinoTextField` hands the menu
/// to the OS itself (`SystemContextMenu`, not something this package or
/// even Flutter draws), so its wording follows the **app bundle's**
/// declared languages — the `CFBundleLocalizations` array in `Info.plist` —
/// not anything Dart-side; see `example/ios/Runner/Info.plist` for a
/// working setup. Everywhere else (older iOS, Android, desktop), Flutter
/// draws the menu itself and reads its wording from whichever
/// `CupertinoLocalizations` the host app's widget tree supplies, falling
/// back to the English-only `DefaultCupertinoLocalizations` if
/// unconfigured — add the `flutter_localizations` package and its
/// `GlobalCupertinoLocalizations.delegate` (alongside the Material/Widgets
/// equivalents and a matching `supportedLocales`) to fix that path; see
/// `example/lib/main.dart` for a working setup.

class CruxTextFormField extends FormField<String> {
  /// Creates a Crux form text field.
  ///
  /// If [controller] is provided, [initialValue] must be left `null` — the
  /// controller's own text is the source of truth. If [controller] is
  /// `null`, this widget creates and owns one internally, seeded with
  /// [initialValue].
  CruxTextFormField({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.controller,
    String? initialValue,
    this.focusNode,
    super.enabled = true,
    this.obscureText = false,
    this.obscureToggle,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
    super.restorationId,
  }) : assert(
         initialValue == null || controller == null,
         'Cannot provide both an initialValue and a controller.',
       ),
       super(
         initialValue: controller != null
             ? controller.text
             : (initialValue ?? ''),
         builder: (FormFieldState<String> field) {
           final _CruxTextFormFieldState state =
               field as _CruxTextFormFieldState;
           return state._buildContent(field);
         },
       );

  /// The field's name (for example `メールアドレス`), shown in
  /// [CruxColors.textSecondary] in a row above the box. Static: it always
  /// renders in that same row, regardless of whether the value is empty or
  /// not — it never moves. When `null`, no label row is reserved and the
  /// field is correspondingly shorter. See the class doc's "The label"
  /// section, and [placeholder] for the separate, in-box hint text.
  final String? label;

  /// The hint text shown inside the box, in [CruxColors.textSecondary],
  /// while the value is empty — for example `you@example.com`. Passed
  /// straight through to [CupertinoTextField.placeholder]. Disappears the
  /// moment the value becomes non-empty, the same as any ordinary
  /// placeholder. Unlike [label], this never appears above the box.
  final String? placeholder;

  /// Optional helper text shown in a caption row below the box. Replaced by
  /// the validation error message, in [CruxColors.error], whenever the
  /// field has one.
  final String? helperText;

  /// Controls the text being edited. If `null` (the default), this widget
  /// creates and owns a [TextEditingController] internally.
  final TextEditingController? controller;

  /// Controls whether this field has keyboard focus. If `null` (the
  /// default), this widget creates and owns a [FocusNode] internally.
  ///
  /// Swapping this for a different [FocusNode] instance across a rebuild
  /// is safe (no crash, no leak) but does not carry focus over to the new
  /// node — nothing calls [FocusNode.requestFocus] on it. A plain
  /// [CupertinoTextField] behaves the same way; this is inherent to
  /// Flutter's focus system, not specific to this widget.
  final FocusNode? focusNode;

  /// Whether to hide the entered text, for password-style input. Defaults
  /// to `false`.
  ///
  /// When [obscureToggle] is `null`, this is the field's fixed, unchanging
  /// obscured state for its whole lifetime.
  ///
  /// When [obscureToggle] is non-`null`, this instead supplies only the
  /// field's *starting* obscured state; the toggle then lets the user flip
  /// between hidden and visible, regardless of what [obscureText] is set
  /// to. `obscureText: false` together with a non-`null` [obscureToggle]
  /// is not treated as a contradiction that suppresses the toggle -- it
  /// still renders and works, starting in its visible state (for example
  /// a PIN field that starts visible to reduce entry friction, with the
  /// toggle offered to hide it again afterward).
  final bool obscureText;

  /// The icons and screen-reader labels for an optional password show/hide
  /// toggle, rendered at the box's trailing edge (mirrored under RTL). Pass
  /// `null` (the default) to render no toggle at all. See
  /// [CruxObscureToggle]'s class doc for why the icons and labels must
  /// come from the call site, [obscureText]'s doc for how the two
  /// arguments interact, and the class doc's "Obscure toggle" section for
  /// the toggle's full behavior.
  final CruxObscureToggle? obscureToggle;

  /// The type of keyboard to show. Passed straight through to the
  /// underlying [CupertinoTextField].
  final TextInputType? keyboardType;

  /// The action button the keyboard shows for this field. Passed straight
  /// through to the underlying [CupertinoTextField].
  final TextInputAction? textInputAction;

  /// Optional input formatters applied to every edit. Passed straight
  /// through to the underlying [CupertinoTextField].
  final List<TextInputFormatter>? inputFormatters;

  /// Optional autofill hints (for example `AutofillHints.email`). Passed
  /// straight through to the underlying [CupertinoTextField].
  final Iterable<String>? autofillHints;

  /// Called with the new text on every edit, including intermediate
  /// (unconfirmed) IME composition text — the same as Flutter's standard
  /// text field behavior. This fires in addition to, not instead of, the
  /// `Form`-level plumbing ([FormFieldState.didChange]).
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field (for example by pressing the
  /// keyboard's return/done key).
  final ValueChanged<String>? onSubmitted;

  @override
  FormFieldState<String> createState() => _CruxTextFormFieldState();
}

class _CruxTextFormFieldState extends FormFieldState<String> {
  TextEditingController? _controller;
  FocusNode? _focusNode;

  /// The toggle's own "is hidden" state while
  /// [CruxTextFormField.obscureToggle] is non-`null`; unused otherwise
  /// (see [_effectiveObscureText]). Re-synced from
  /// [CruxTextFormField.obscureText] in [didUpdateWidget] whenever that
  /// argument changes.
  bool _obscured = false;

  /// The obscured state passed to [CruxTextFieldCore]: the live,
  /// user-toggleable [_obscured] flag when a toggle exists, or
  /// [CruxTextFormField.obscureText] directly otherwise.
  bool get _effectiveObscureText =>
      _field.obscureToggle == null ? _field.obscureText : _obscured;

  /// Flips [_obscured]. Never calls [FormFieldState.didChange] or touches
  /// [FormFieldState.value] -- revealing/hiding only changes how the
  /// value is displayed, not what it is.
  void _handleToggleObscured() {
    setState(() => _obscured = !_obscured);
  }

  /// Whether [_buildContent] has run before. Guards the shake-trigger
  /// check so the very first build -- which may already show an error --
  /// is treated as a baseline, not an error that "just appeared".
  bool _hasBuiltOnce = false;

  /// The `errorText` observed on the previous build, used to detect a
  /// null -> non-null transition ("an error appears").
  String? _previousErrorText;

  /// Set by [validate] whenever the field turns out invalid, regardless of
  /// whether `errorText`'s value actually changed -- covers a repeated
  /// failed submit with an identical error message, which a plain
  /// null -> non-null comparison on `errorText` alone would miss. Reset to
  /// `false` the next time [_buildContent] runs.
  bool _forceShakeOnNextBuild = false;

  /// Bumped by exactly 1, in [_buildContent], every time this field should
  /// play its shake. Fed to [CruxMotion.shake] as its `trigger`, which
  /// plays a new shake whenever this value changes across a rebuild.
  int _shakeGeneration = 0;

  @override
  bool validate() {
    final bool isValid = super.validate();
    if (!isValid) {
      // super.validate() already called setState; no extra setState
      // needed here to schedule the rebuild that will consume this flag.
      _forceShakeOnNextBuild = true;
    }
    return isValid;
  }

  CruxTextFormField get _field => widget as CruxTextFormField;

  TextEditingController get _effectiveController =>
      _field.controller ?? _controller!;

  FocusNode get _effectiveFocusNode => _field.focusNode ?? _focusNode!;

  @override
  void initState() {
    super.initState();
    if (_field.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
    } else {
      _field.controller!.addListener(_handleControllerChanged);
    }
    if (_field.focusNode == null) {
      _focusNode = FocusNode();
    }
    _obscured = _field.obscureText;
  }

  @override
  void didUpdateWidget(covariant FormField<String> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final CruxTextFormField oldField = oldWidget as CruxTextFormField;
    if (_field.obscureText != oldField.obscureText) {
      // A changed `obscureText` argument re-seeds the toggle's state.
      _obscured = _field.obscureText;
    }
    if (_field.controller != oldField.controller) {
      oldField.controller?.removeListener(_handleControllerChanged);
      _field.controller?.addListener(_handleControllerChanged);

      if (oldField.controller != null && _field.controller == null) {
        _controller = TextEditingController.fromValue(
          oldField.controller!.value,
        );
      }
      if (_field.controller != null) {
        setValue(_field.controller!.text);
        if (oldField.controller == null) {
          _controller?.dispose();
          _controller = null;
        }
      }
    }
    if (_field.focusNode != oldField.focusNode) {
      if (oldField.focusNode == null && _field.focusNode != null) {
        // An internally-owned node is no longer needed now that an
        // external one has been supplied: dispose it immediately instead
        // of leaving it orphaned until this state itself is disposed.
        _focusNode?.dispose();
        _focusNode = null;
      } else if (oldField.focusNode != null && _field.focusNode == null) {
        // The caller stopped supplying a node: create a fresh
        // internally-owned one so _effectiveFocusNode keeps working.
        _focusNode = FocusNode();
      }
      // A change between two different external nodes needs nothing
      // further here: neither side is a node this state owns.
    }
  }

  @override
  void dispose() {
    _field.controller?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  void didChange(String? value) {
    super.didChange(value);
    if (_effectiveController.text != value) {
      _effectiveController.text = value ?? '';
    }
  }

  @override
  void reset() {
    _effectiveController.text = widget.initialValue ?? '';
    super.reset();
  }

  void _handleControllerChanged() {
    if (_effectiveController.text != value) {
      didChange(_effectiveController.text);
    }
  }

  Widget _buildContent(FormFieldState<String> field) {
    final CruxThemeData theme = CruxTheme.of(field.context);
    final CruxColors colors = theme.colors;
    final bool enabled = _field.enabled;
    final String? errorText = field.errorText;
    final String captionText = errorText ?? _field.helperText ?? '';

    // Derives _shakeGeneration for the tree this build produces; never
    // calls setState (build() may not do that) -- relies on whatever
    // triggered this rebuild (an explicit validate() call, or Flutter's
    // own autovalidate path) having already scheduled it.
    final bool errorJustAppeared =
        errorText != null && _previousErrorText == null;
    final bool shouldShake =
        _hasBuiltOnce && (errorJustAppeared || _forceShakeOnNextBuild);
    _forceShakeOnNextBuild = false;
    _hasBuiltOnce = true;
    _previousErrorText = errorText;
    if (shouldShake) {
      _shakeGeneration++;
    }

    final CruxObscureToggle? obscureToggle = _field.obscureToggle;

    // Reserves _obscureToggleTapTarget on the box's trailing edge whenever
    // a toggle is configured. EdgeInsetsGeometry.add keeps this
    // direction-aware (mirrors under RTL), matching PositionedDirectional
    // below.
    final EdgeInsetsGeometry contentPadding = obscureToggle == null
        ? _boxContentPadding
        : _boxContentPadding.add(
            const EdgeInsetsDirectional.only(end: _obscureToggleTapTarget),
          );

    final Widget textFieldCore = CruxTextFieldCore(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      enabled: enabled,
      obscureText: _effectiveObscureText,
      colors: colors,
      typography: theme.typography,
      brightness: theme.brightness,
      contentPadding: contentPadding,
      placeholder: _field.placeholder,
      keyboardType: _field.keyboardType,
      textInputAction: _field.textInputAction,
      inputFormatters: _field.inputFormatters,
      autofillHints: _field.autofillHints,
      onChanged: (String text) {
        field.didChange(text);
        _field.onChanged?.call(text);
      },
      onSubmitted: _field.onSubmitted,
    );

    // The Stack's size comes entirely from textFieldCore (its only
    // non-positioned child); the toggle is Positioned within that size, so
    // toggling it never changes the box's own size.
    final Widget boxContent = obscureToggle == null
        ? textFieldCore
        : Stack(
            children: <Widget>[
              textFieldCore,
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                child: _ObscureToggleButton(
                  obscured: _effectiveObscureText,
                  toggle: obscureToggle,
                  enabled: enabled,
                  onPressed: _handleToggleObscured,
                ),
              ),
            ],
          );

    final Widget box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTapTarget),
      child: Container(
        decoration: ShapeDecoration(
          color: colors.controlFill,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(Radius.circular(CruxRadii.m)),
            side: BorderSide(
              color: errorText != null ? colors.error : colors.separator,
            ),
          ),
        ),
        child: boxContent,
      ),
    );

    final String? label = _field.label;
    final Widget? labelRow = label == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: _labelRowGap),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.typography.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          );

    // captionStrong shares caption's size and differs only in weight, which
    // is what keeps the "showing an error never moves anything below it"
    // guarantee this file's tests pin.
    final Widget caption = Text(
      captionText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          (errorText != null
                  ? theme.typography.captionStrong
                  : theme.typography.caption)
              .copyWith(
                color: errorText != null ? colors.error : colors.textSecondary,
              ),
    );

    // Only the box itself shakes -- see the class doc's "Error shake"
    // section.
    final Widget shakingBox = CruxMotion.shake(
      trigger: _shakeGeneration,
      reduceMotion: MediaQuery.disableAnimationsOf(field.context),
      child: box,
    );

    return Semantics(
      container: true,
      textField: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : _disabledOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ?labelRow,
            shakingBox,
            const SizedBox(height: _helperRowGap),
            caption,
          ],
        ),
      ),
    );
  }
}

/// The show/hide button rendered at the box's trailing edge whenever
/// [CruxTextFormField.obscureToggle] is non-`null` -- see that class's
/// "Obscure toggle" doc section for the full behavior.
class _ObscureToggleButton extends StatelessWidget {
  const _ObscureToggleButton({
    required this.obscured,
    required this.toggle,
    required this.enabled,
    required this.onPressed,
  });

  /// Whether the field's text is currently hidden. Selects which of
  /// [toggle]'s icon/label pair renders.
  final bool obscured;

  final CruxObscureToggle toggle;

  /// Whether the field as a whole is enabled. While `false`, [onPressed] is
  /// not wired to the [GestureDetector] at all, so this button stops
  /// responding to taps; dimming is handled by the ambient [Opacity] this
  /// button renders inside (see `_buildContent`), not by this widget.
  final bool enabled;

  /// Flips the obscured state. Never called while [enabled] is `false`.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget icon = obscured ? toggle.obscuredIcon : toggle.revealedIcon;
    final String label = obscured ? toggle.obscuredLabel : toggle.revealedLabel;

    // TextFieldTapRegion groups this button with the field's own
    // EditableText for Flutter's "tap outside a focused text field"
    // handling -- without it, tapping here would unfocus the field /
    // dismiss the keyboard on some platforms.
    return TextFieldTapRegion(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        // Explicit label + excludeSemantics: this button has no
        // descendant text, and `icon` may carry unrelated semantics of
        // its own.
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: _obscureToggleTapTarget,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _obscureToggleTapTarget,
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
