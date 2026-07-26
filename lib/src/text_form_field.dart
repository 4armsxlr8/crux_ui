import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import 'colors.dart';
import 'motion.dart';
import 'radii.dart';
import 'spacing.dart';
import 'theme.dart';
import 'typography.dart';

/// The minimum tap target size for the interactive box of a
/// [CruxTextFormField], matching the other atoms' K B9-style rule: 44
/// logical pixels. In practice the box's own content (body-sized text plus
/// its padding) is already taller than this, so the constraint mostly acts
/// as a floor rather than something that visibly changes the box.
const double _minTapTarget = 44;

/// The opacity the whole field renders at when [CruxTextFormField.enabled]
/// is `false`, per handoff.md's agreed "見た目" decision.
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
/// same color the box's border switches to, per "The box" above. That row's
/// height is also always reserved, so showing or clearing an error never
/// shifts anything else in the layout.
///
/// **Error shake.** Whenever a validation error appears (`errorText` goes
/// from `null` to non-`null`) the *box* — and only the box, not the label
/// row above it or the caption row below it — plays a brief horizontal
/// shake, the familiar "wrong password" wobble, via [CruxMotion.shake].
/// The label and caption/helper text stay perfectly still while the box
/// shakes under them. (This reverses an earlier version of this field, in
/// which the whole field shook as one piece; see
/// `unknowns/textfield-atom/implementation-notes.md`'s 2026-07-26 entry for
/// why — in short, the user reviewed the whole-field shake on a physical
/// device and asked for box-only instead.) Pressing the same submit button
/// again while an identical error is already showing shakes again too —
/// `errorText` itself does not change between the two calls, but this is
/// the common real case (the user presses the button again), so this
/// field's [FormFieldState.validate] override shakes on every failed call,
/// not only the first. An error already showing the very first time this
/// field is ever built (for example an [AutovalidateMode.always] field
/// whose initial value is already invalid) does not shake on mount: from
/// this field's own lifetime, there was no prior successful, error-free
/// build for that state to have changed away from. The shake is a
/// paint-time transform only — it never changes this field's own size or
/// shifts anything around it — and is fully suppressed (never merely
/// shortened) when the OS "reduce motion" accessibility setting is on
/// ([MediaQuery.disableAnimationsOf]).
///
/// **Disabled.** Set [enabled] to `false` to render the whole field (box,
/// label, helper/error text) at 55% opacity and reject input. Unlike the
/// package's other five atoms, this is a plain `bool` rather than "pass
/// `null` to a callback": a text field is commonly used with only a
/// [controller] and no [onChanged] at all, so a nullable-callback
/// convention would have no way to represent "enabled, callback-less" and
/// "disabled" as different states.
///
/// **Overflow.** Deliberately departs from this package's usual
/// "overflow → ellipsis" rule (see [CruxButton], [CruxChip],
/// [CruxListTile]): a very long value scrolls horizontally to follow the
/// cursor, the same as any single-line text field, rather than being
/// truncated with an ellipsis — ellipsizing entered text while it's being
/// edited would hide what the user just typed.
///
/// **Selection.** Text selection handles and the copy/paste menu use the
/// iOS ("Cupertino") style on every platform — [CupertinoTextField]'s own
/// default behavior, not something this widget adds — and the text cursor,
/// selection highlight, and drag handles all use [CruxColors.accent]
/// rather than iOS's default blue or (inside a consuming app's Material
/// `MaterialApp`/`Theme`) that app's own primary color. The cursor and
/// selection highlight are sealed with an internal `DefaultSelectionStyle`
/// wrapper — required because `CupertinoTextField` consults an ambient
/// `DefaultSelectionStyle` (which `MaterialApp`/`Theme` install from the
/// app's `ColorScheme`) *before* falling back to `CupertinoTheme
/// .primaryColor` — and the drag handles and text-magnifier ring use an
/// internal [CupertinoTheme] wrapper. Both wrappers are scoped to this
/// widget's own subtree only; neither changes an ambient `CupertinoTheme`,
/// `DefaultSelectionStyle`, or any Material theming outside this widget.
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
  final bool obscureText;

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

/// The token-styled [CupertinoTextField] core, factored out on its own (per
/// plan.md section 3) so a future `CruxInputBar` / `CruxComposer` can
/// share it: it is the piece that turns Crux tokens into a properly
/// styled [CupertinoTextField] (body typography, [CruxColors.textPrimary]
/// text, an empty `BoxDecoration` — not `null`, see the comment at its call
/// site — since the caller draws its own box, an internal
/// `DefaultSelectionStyle` wrapper so the cursor and selection highlight use
/// [CruxColors.accent] instead of an ambient app's Material primary color,
/// and an internal [CupertinoTheme] wrapper so the selection drag handles
/// and text-magnifier ring use [CruxColors.accent] too). It does not know
/// about labels, helper text, or `Form` integration — those stay specific
/// to [CruxTextFormField].
class _CruxTextFieldCore extends StatelessWidget {
  const _CruxTextFieldCore({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.obscureText,
    required this.colors,
    required this.typography,
    required this.brightness,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool obscureText;
  final CruxColors colors;
  final CruxTypography typography;

  /// The theme's brightness, passed straight through to
  /// [CupertinoTextField.keyboardAppearance] so the on-screen keyboard
  /// matches Crux's own light/dark theme instead of the ambient platform
  /// brightness ([CupertinoTextField]'s own default when this is left
  /// unset).
  final Brightness brightness;

  /// The hint text to show inside the field while it is empty. See
  /// [CruxTextFormField.placeholder].
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // Seals the cursor and selection-highlight colors against whatever
    // ambient Material `Theme`/`MaterialApp` a consuming app has installed.
    // `CupertinoTextField` resolves both as `widget.cursorColor ??
    // DefaultSelectionStyle.of(context).cursorColor ?? themeData.primaryColor`
    // (and the equivalent for `selectionColor`) — `DefaultSelectionStyle` is
    // consulted *before* `CupertinoTheme.primaryColor`, and both `Theme` and
    // `MaterialApp` install one sourced from the app's `ColorScheme`, so a
    // plain `CupertinoTheme` wrapper alone never reaches its own fallback
    // inside a `MaterialApp`. Providing our own `DefaultSelectionStyle` here
    // shadows the ambient one for this subtree, the same "seal at the
    // boundary" approach `CupertinoTheme` below already uses for the values
    // it does control. See `unknowns/textfield-atom/implementation-notes.md`
    // "Defects found in review" for how this was found.
    return DefaultSelectionStyle(
      cursorColor: colors.accent,
      selectionColor: colors.accentTint,
      child: CupertinoTheme(
        // Does not affect the cursor or selection highlight (sealed above,
        // and `DefaultSelectionStyle` wins before `CupertinoTheme
        // .primaryColor` is ever consulted). This wrapper is still load
        // -bearing for two other ambient lookups `CupertinoTextField` makes
        // that are *not* intercepted by `DefaultSelectionStyle`:
        // `selectionHandleColor` (the drag-handle color painted by
        // `cupertino/text_selection.dart`'s `buildHandle`, read via
        // `CupertinoTheme.of(context).selectionHandleColor`) and the
        // magnifier loupe's ring color (`cupertino/magnifier.dart`, read via
        // `CupertinoTheme.of(context).primaryColor`). Both are built through
        // an `Overlay` entry outside this widget's own subtree, but Flutter
        // re-applies this `CupertinoTheme` there anyway because
        // `InheritedCupertinoTheme extends InheritedTheme`, and both
        // `SelectionOverlay.showHandles`/`MagnifierController.show` capture
        // ancestor `InheritedTheme`s (`InheritedTheme.capture`) before
        // inserting into the overlay.
        data: CupertinoThemeData(
          primaryColor: colors.accent,
          selectionHandleColor: colors.accent,
        ),
        child: CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          // The outer box (built by CruxTextFormField) draws the border;
          // this field must paint no decoration of its own. An *empty*
          // BoxDecoration (rather than `null`) is used deliberately:
          // CupertinoTextField's own build method only special-cases a
          // `null` `decoration` when the field is disabled — its Container's
          // `color` falls back to an ambient-brightness-resolved gray
          // (`_kDisabledBackground`) whenever `decoration == null &&
          // !enabled`, which would paint a stray fill behind this box
          // exactly when disabled, breaking the documented "no fill, ever"
          // invariant below. A non-null-but-empty BoxDecoration paints
          // nothing and never triggers that fallback.
          decoration: const BoxDecoration(),
          padding: _boxContentPadding,
          style: typography.body.copyWith(color: colors.textPrimary),
          placeholder: placeholder,
          placeholderStyle: typography.body.copyWith(
            color: colors.textSecondary,
          ),
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          keyboardAppearance: brightness,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

class _CruxTextFormFieldState extends FormFieldState<String> {
  TextEditingController? _controller;
  FocusNode? _focusNode;

  /// Whether [_buildContent] has run at least once yet. Guards the shake
  /// -trigger detection below so the *very first* build -- which may
  /// already show an error (an `AutovalidateMode.always` field whose
  /// initial value is already invalid, as in the widgetbook catalog's error
  /// cell) -- establishes a baseline rather than being treated as an error
  /// that "just appeared": from this field's own lifetime, there was no
  /// prior null `errorText` to transition away from, so nothing plays on
  /// mount.
  bool _hasBuiltOnce = false;

  /// The `errorText` observed on the previous build, used to detect a null
  /// -> non-null transition ("an error appears", trigger 1 in
  /// implementation-notes.md's "Error shake" section).
  String? _previousErrorText;

  /// Set by [validate] whenever it is called and the field turns out
  /// invalid, regardless of whether `errorText`'s *value* actually changed
  /// -- trigger 2 in implementation-notes.md's "Error shake" section: a
  /// repeated failed submit with an identical error message. A plain null
  /// -> non-null comparison on `errorText` alone would miss this case,
  /// since `errorText` never goes back to null between the two `validate()`
  /// calls -- it stays the same non-null string throughout, so nothing
  /// about the *value* changes for [_buildContent]'s own comparison to
  /// notice. Consumed (reset to `false`) the next time [_buildContent]
  /// runs, whether or not it was the reason that build shook.
  bool _forceShakeOnNextBuild = false;

  /// Bumped by exactly 1, in [_buildContent], every time this field should
  /// play its shake. Fed to [CruxMotion.shake] as its `trigger`, which
  /// plays a new shake whenever this value changes across a rebuild.
  int _shakeGeneration = 0;

  @override
  bool validate() {
    final bool isValid = super.validate();
    if (!isValid) {
      // super.validate() already called setState (updating errorText), so a
      // rebuild -- and therefore a future _buildContent call that will
      // consume this flag -- is already scheduled; no extra setState is
      // needed here.
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
  }

  @override
  void didUpdateWidget(covariant FormField<String> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final CruxTextFormField oldField = oldWidget as CruxTextFormField;
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

    // Decide whether this build should play a new shake -- see
    // _hasBuiltOnce's and _previousErrorText's doc comments for what each
    // check means. This only ever *derives* _shakeGeneration for the
    // widget tree this same method is about to build; it never calls
    // setState (which build() may not do), so it relies on whatever caused
    // this rebuild (an explicit validate() call, or Flutter's own
    // FormFieldState.build() running the validator for an autovalidate
    // mode just before invoking this builder) having already been
    // scheduled through a setState of its own.
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

    final Widget box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTapTarget),
      child: Container(
        decoration: ShapeDecoration(
          color: colors.controlFill,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(CruxRadii.m),
            ),
            side: BorderSide(
              color: errorText != null ? colors.error : colors.separator,
            ),
          ),
        ),
        child: _CruxTextFieldCore(
          controller: _effectiveController,
          focusNode: _effectiveFocusNode,
          enabled: enabled,
          obscureText: _field.obscureText,
          colors: colors,
          typography: theme.typography,
          brightness: theme.brightness,
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
        ),
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
              style: theme.typography.label.copyWith(
                color: colors.textSecondary,
              ),
            ),
          );

    final Widget caption = Text(
      captionText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.caption.copyWith(
        color: errorText != null ? colors.error : colors.textSecondary,
      ),
    );

    // Only the box itself shakes -- see the class doc's "Error shake"
    // section and implementation-notes.md's 2026-07-26 reversal entry for
    // why this no longer wraps the label row and caption row too.
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
