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

/// The width -- and, since it is stretched to the box's own height via
/// [PositionedDirectional]'s `top`/`bottom` in [_CruxTextFormFieldState
/// ._buildContent], also the minimum height -- of
/// [CruxTextFormField.obscureToggle]'s tap target, matching this
/// package's usual 44 logical pixel minimum (see [_minTapTarget]'s doc
/// above; this field declares its own copy of that constant rather than
/// sharing [_minTapTarget], per this package's established convention of
/// each interactive element owning a private const rather than a shared
/// token -- see `button.dart`/`chip.dart`/`switch.dart`'s identically
/// -named, independently-declared constants).
const double _obscureToggleTapTarget = 44;

/// Bundles the icons and screen-reader labels a product supplies for
/// [CruxTextFormField]'s optional password show/hide toggle.
///
/// This package deliberately never draws its own glyph for this toggle.
/// Different products ship completely different icon sets (a bespoke icon
/// font, Cupertino/Material icon packs, an SVG asset, or even a plain
/// text/emoji glyph) and `crux_ui` has no way to know which one any given
/// consumer uses -- the same reasoning [CruxButton]/[CruxChip] apply to
/// their own text labels, extended here to imagery. Passing an
/// [CruxObscureToggle] to [CruxTextFormField.obscureToggle] is how a
/// caller supplies its own choice; leaving it `null` renders no toggle at
/// all, per that parameter's own doc.
///
/// [obscuredIcon] and [revealedIcon] are plain [Widget]s, not [IconData] --
/// a caller can hand this an `Icon`, an `Image`, or even a `Text` showing a
/// literal glyph, and this package draws whatever it is given without
/// caring which icon system (if any) produced it.
///
/// [obscuredLabel] and [revealedLabel] are `required` [String]s, for the
/// same reason the icons are caller-supplied rather than fixed: this
/// package has no fixed language to announce to a screen reader, and an
/// icon-only button (see [CruxTextFormField]'s "Obscure toggle" class doc
/// section for why this button carries no visible text of its own) has
/// nothing else it could fall back to. Making them `required` rather than
/// nullable-with-an-English-default was a deliberate choice: a nullable
/// label would force this package to silently pick between two bad
/// outcomes whenever a caller omitted one -- announcing nothing at all (an
/// icon-only interactive control with no accessible name, failing WCAG
/// 4.1.2) or inventing English wording (exactly the hardcoding this whole
/// class exists to avoid). Requiring both labels up front pushes that
/// decision to the one place that actually knows the app's language and
/// icon choice: the call site.
///
/// This is a plain, immutable value bundle (not a [Widget] itself) so that
/// adding this whole feature costs [CruxTextFormField] exactly one new
/// constructor parameter, rather than four -- and so a future addition to
/// this bundle (if one is ever needed) stays a non-breaking change to
/// [CruxTextFormField]'s own constructor.
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
/// same color the box's border switches to, per "The box" above — and at
/// `FontWeight.w600` rather than the caption style's normal `w400`, so the
/// message reads as louder than plain helper text. The size stays at the
/// caption style's own 12px; only the weight changes. That row's height is
/// also always reserved, so showing or clearing an error never shifts
/// anything else in the layout.
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
/// **Obscure toggle.** Set [obscureToggle] to a [CruxObscureToggle] to
/// render a show/hide button at the box's trailing edge (mirrored under an
/// RTL [Directionality], via [PositionedDirectional]) -- see
/// [CruxObscureToggle]'s own class doc for why its icons and screen
/// -reader labels are caller-supplied rather than something this package
/// draws itself, and [obscureText]'s doc for exactly how the two arguments
/// combine. Leaving [obscureToggle] `null` (the default) renders no toggle
/// at all: [obscureText] is then this field's fixed, unchanging obscured
/// state for its whole lifetime, exactly as before this feature existed.
///
/// The toggle button always occupies a fixed 44x44 logical pixel slot
/// (this package's usual minimum tap target, matching
/// [CruxButton]/[CruxChip]/[CruxSwitch]'s own private constants) for
/// as long as [obscureToggle] is non-`null`, regardless of which icon is
/// currently showing -- toggling swaps the icon in place but never adds,
/// removes, or resizes anything, so the box's size, the label row, and the
/// helper/error caption row all stay exactly where they were before the
/// tap. The field's own content padding reserves that same 44 logical
/// pixels on the trailing edge (on top of the box's ordinary padding) so
/// entered text can never be drawn underneath the toggle.
///
/// `Semantics(button: true, excludeSemantics: true, label: ...)` marks the
/// toggle as a button whose announced label is whichever of
/// [CruxObscureToggle.obscuredLabel]/[CruxObscureToggle.revealedLabel]
/// matches the current state. This departs from how every other
/// interactive Crux atom (see [CruxButton]/[CruxChip]) handles
/// semantics -- they set no explicit `label` and instead rely on a
/// descendant `Text` to supply one automatically, avoiding a doubled
/// announcement. That convention does not transfer here: the toggle is
/// icon-only and has no descendant text of its own to rely on, and its
/// icon is an arbitrary caller-supplied [Widget] that might carry
/// unrelated or absent semantics of its own (an `Icon` with no
/// `semanticLabel`, or a `Text` glyph whose literal characters are not a
/// meaningful description). `excludeSemantics: true` suppresses whatever
/// the icon subtree would otherwise contribute, so the only label ever
/// announced is the one [CruxObscureToggle] supplies.
///
/// Tapping the toggle never steals focus from the text field or dismisses
/// the on-screen keyboard: it is wrapped in a [TextFieldTapRegion], the
/// same mechanism [CupertinoTextField]'s own selection toolbar and
/// magnifier use to be treated as "inside" the field for focus purposes.
/// Without it, tapping the toggle would count as a tap *outside* the
/// field's [EditableText] and trigger its default "unfocus on outside tap"
/// behavior on desktop platforms (and for a mouse/stylus everywhere) --
/// confirmed against the Flutter SDK,
/// `widgets/editable_text.dart`'s `_EditableTextTapOutsideAction`.
///
/// Toggling is a plain [State.setState] flip of an internal flag -- it
/// never calls [FormFieldState.didChange] and never touches the field's
/// actual text [value], since it only changes how the existing value is
/// *displayed*, not what it is.
///
/// While [enabled] is `false`, the toggle dims along with the rest of the
/// field (it renders inside the same [Opacity] wrapper described in
/// "Disabled" below) and stops responding to taps.
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
  /// obscured state -- there is no way for the user to reveal the text, so
  /// this value is exactly what renders for the field's whole lifetime.
  ///
  /// When [obscureToggle] is non-`null`, this instead supplies only the
  /// field's *starting* obscured state; the rendered toggle then lets the
  /// user flip between hidden and visible from there, regardless of what
  /// [obscureText] itself is set to. In particular, passing
  /// `obscureText: false` together with a non-`null` [obscureToggle] is not
  /// treated as a contradiction that suppresses the toggle -- the toggle
  /// still renders and works, it just starts in its visible state. This is
  /// the least surprising reading of the two arguments together: once a
  /// caller has supplied a whole [CruxObscureToggle] (icons, both
  /// labels), that is a clear, deliberate request for an interactive
  /// toggle, and silently dropping it because of an unrelated flag would
  /// be a more surprising outcome than simply honoring [obscureText] as a
  /// starting point rather than a permanent clamp. (`obscureText: false` +
  /// a real toggle is also a legitimate product choice on its own, not
  /// just an accepted edge case -- for example a PIN field that starts
  /// visible to reduce entry friction, with the toggle offered so the user
  /// can hide it again before, say, taking a screenshot.)
  final bool obscureText;

  /// The icons and screen-reader labels for an optional password show/hide
  /// toggle, rendered at the box's trailing edge (mirrored under RTL). Pass
  /// `null` (the default) to render no toggle at all -- this package never
  /// invents its own glyph or wording, so there is no fallback appearance
  /// to fall back to; see [CruxObscureToggle]'s own class doc for why the
  /// icons and labels must come from the call site. See [obscureText]'s doc
  /// for exactly how the two arguments interact, including the
  /// `obscureText: false` case.
  ///
  /// See the class doc's "Obscure toggle" section for the toggle's full
  /// behavior: tap target size, focus/keyboard handling, layout stability,
  /// and disabled behavior.
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
    this.contentPadding = _boxContentPadding,
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

  /// The padding applied to the actual [CupertinoTextField]'s own content.
  /// Defaults to [_boxContentPadding]; widened on the trailing edge by
  /// [_CruxTextFormFieldState._buildContent] whenever
  /// [CruxTextFormField.obscureToggle] is non-`null`, so entered text
  /// never renders underneath the toggle button.
  final EdgeInsetsGeometry contentPadding;

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
          padding: contentPadding,
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

  /// The toggle's own "is the text currently hidden" state, while
  /// [CruxTextFormField.obscureToggle] is non-`null`. Meaningless (and
  /// never read) whenever [CruxTextFormField.obscureToggle] is `null` --
  /// see [_effectiveObscureText], which reads [CruxTextFormField
  /// .obscureText] directly in that case instead, exactly matching this
  /// field's pre-toggle behavior. Initialized from
  /// [CruxTextFormField.obscureText] in [initState], and re-synced there
  /// from the same source whenever that argument itself changes (see
  /// [didUpdateWidget]) -- see [CruxTextFormField.obscureText]'s own doc
  /// for why a changed `obscureText` argument wins over whatever the user
  /// last toggled to, while an unrelated rebuild leaves this alone.
  bool _obscured = false;

  /// The obscured state actually passed to [_CruxTextFieldCore]: the
  /// live, user-toggleable [_obscured] flag when a toggle exists, or
  /// [CruxTextFormField.obscureText] directly (a fixed value for this
  /// field's whole lifetime) when it does not. See
  /// [CruxTextFormField.obscureText]'s own doc for the reasoning.
  bool get _effectiveObscureText =>
      _field.obscureToggle == null ? _field.obscureText : _obscured;

  /// Flips [_obscured]. Only ever wired to the toggle button's `onTap`, and
  /// only while [CruxTextFormField.enabled] is `true` -- see
  /// [_buildContent]. A plain [State.setState]: this never calls
  /// [FormFieldState.didChange] or touches this field's actual text
  /// [FormFieldState.value], since revealing/hiding only changes how the
  /// existing value is displayed, not what it is.
  void _handleToggleObscured() {
    setState(() => _obscured = !_obscured);
  }

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
    _obscured = _field.obscureText;
  }

  @override
  void didUpdateWidget(covariant FormField<String> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final CruxTextFormField oldField = oldWidget as CruxTextFormField;
    if (_field.obscureText != oldField.obscureText) {
      // A changed `obscureText` argument re-seeds the toggle's own state --
      // see this field's doc comment for why a controlled-prop change wins
      // over whatever the user last toggled to.
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

    final CruxObscureToggle? obscureToggle = _field.obscureToggle;

    // Reserves _obscureToggleTapTarget on the box's trailing edge, on top
    // of the box's ordinary padding, whenever a toggle is configured -- see
    // the class doc's "Obscure toggle" section. EdgeInsetsGeometry.add
    // keeps this direction-aware (an EdgeInsetsDirectional `end` inset
    // mirrors under RTL), matching PositionedDirectional's own
    // direction-awareness below.
    final EdgeInsetsGeometry contentPadding = obscureToggle == null
        ? _boxContentPadding
        : _boxContentPadding.add(
            const EdgeInsetsDirectional.only(end: _obscureToggleTapTarget),
          );

    final Widget textFieldCore = _CruxTextFieldCore(
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

    // The Stack's own size comes entirely from textFieldCore (its only
    // non-positioned child); the toggle button is `Positioned` within
    // whatever size that resolves to, so adding/removing/toggling it never
    // changes the box's own size -- see the class doc's "Obscure toggle"
    // section.
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
            borderRadius: const BorderRadius.all(
              Radius.circular(CruxRadii.m),
            ),
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
              style: theme.typography.label.copyWith(
                color: colors.textSecondary,
              ),
            ),
          );

    // A validation error also renders at FontWeight.w600 -- one step up
    // from caption's own w400 -- so the message reads as louder than plain
    // helper text, on top of the color change above. This is a
    // component-level override (`copyWith(fontWeight:)`), not a change to
    // `caption` itself or a new typography token: `caption` stays a fixed
    // 12px/w400 pair usable elsewhere (timestamps, metadata) without
    // dragging along an emphasis rule that only makes sense for an error.
    // Size deliberately stays at caption's own 12px rather than switching
    // to `label` (14px w600) -- a size change would grow the reserved
    // caption row's height and break the "showing an error never moves
    // anything below it" guarantee this file's "error / helper row" group
    // tests. If a second component later needs this same emphasized-caption
    // look, promote it to a real `CruxTypography` token instead of
    // copy-pasting this `copyWith` again.
    final Widget caption = Text(
      captionText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.caption.copyWith(
        color: errorText != null ? colors.error : colors.textSecondary,
        fontWeight: errorText != null ? FontWeight.w600 : null,
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

/// The show/hide button [_CruxTextFormFieldState._buildContent] renders
/// at the box's trailing edge whenever [CruxTextFormField.obscureToggle]
/// is non-`null` -- see [CruxTextFormField]'s class doc, "Obscure
/// toggle" section, for the full behavior this implements.
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

    // TextFieldTapRegion groups this button with the surrounding
    // CupertinoTextField's own EditableText (both default to
    // `groupId: EditableText`) for the purposes of Flutter's "tap outside
    // a focused text field" handling -- see the class doc's "Obscure
    // toggle" section for exactly which Flutter behavior this prevents.
    // Without it, tapping this button would count as an *outside* tap and
    // could unfocus the field / dismiss the keyboard on some platforms.
    return TextFieldTapRegion(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        // See the class doc's "Obscure toggle" section for why this
        // button -- unlike every other interactive Crux atom -- sets an
        // explicit `label` and excludes descendant semantics: it has no
        // descendant text of its own to rely on, and `icon` is an
        // arbitrary caller-supplied widget that may carry unrelated or
        // absent semantics of its own.
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
