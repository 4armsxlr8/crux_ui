import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// The padding inside the box, applied to the actual [CupertinoTextField]'s
/// own content, whenever a caller of [CruxTextFieldCore] does not override
/// [CruxTextFieldCore.contentPadding].
///
/// This is a private copy of the same `12` logical pixel value
/// `text_form_field.dart`'s own (differently named) content-padding constant
/// uses -- not a shared token, per this package's established convention of
/// each file owning its own private constants rather than importing another
/// file's private ones (see `button.dart`/`chip.dart`/`switch.dart`'s
/// identically-shaped, independently-declared `_minTapTarget` constants for
/// the precedent this follows).
const EdgeInsets _defaultContentPadding = EdgeInsets.all(CruxSpacing.s12);

/// The token-styled [CupertinoTextField] core shared by every Crux text
/// input atom: it turns Crux tokens into a properly styled
/// [CupertinoTextField] (body typography, [CruxColors.textPrimary] text,
/// an empty `BoxDecoration` — not `null`, see the comment at its call site —
/// since the caller draws its own box, an internal `DefaultSelectionStyle`
/// wrapper so the cursor and selection highlight use [CruxColors.accent]
/// instead of an ambient app's Material primary color, and an internal
/// [CupertinoTheme] wrapper so the selection drag handles and text
/// -magnifier ring use [CruxColors.accent] too). It does not know about
/// labels, helper text, or `Form` integration — those stay specific to
/// whichever atom is using this core ([CruxTextFormField] today;
/// `CruxInputBar`/`CruxComposer` are the reason this class lives in its
/// own file rather than as a private class inside `text_form_field.dart`,
/// where it originated — Dart's privacy is scoped per-library, and each
/// `.dart` file that is not a `part` of another is its own library, so a
/// leading-underscore class declared in `text_form_field.dart` is invisible
/// to a plain `import` from a sibling file; confirmed empirically with a
/// minimal two-file reproduction before this class was moved here, not
/// assumed).
///
/// This class is intentionally public (no leading underscore) so sibling
/// files under `lib/src/` can import and use it, but it is never exported
/// from `lib/crux_ui.dart` — the package's single public entry point — so
/// it is not part of this package's public API from a consumer's point of
/// view, the same "internal, not published" status the private class it
/// replaces had.
class CruxTextFieldCore extends StatelessWidget {
  /// Creates the shared, token-styled text field core.
  const CruxTextFieldCore({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.obscureText,
    required this.colors,
    required this.typography,
    required this.brightness,
    this.contentPadding = _defaultContentPadding,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
  }) : assert(
         !obscureText || maxLines == 1,
         'Obscured fields cannot be multiline -- this mirrors '
         "CupertinoTextField's own assert (Flutter SDK "
         '`cupertino/text_field.dart:328`: `assert(!obscureText || maxLines '
         "== 1, 'Obscured fields cannot be multiline.')`) so a caller "
         'mistake (a future CruxInputBar wiring both obscureText and a '
         'multiline maxLines together) fails loudly at this call site '
         "instead of only inside CupertinoTextField's own constructor.",
       );

  /// Controls the text being edited.
  final TextEditingController controller;

  /// Controls whether this field has keyboard focus.
  final FocusNode focusNode;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether to hide the entered text, for password-style input.
  final bool obscureText;

  /// The color palette this field resolves its own colors from.
  final CruxColors colors;

  /// The type scale this field resolves its own text styles from.
  final CruxTypography typography;

  /// The padding applied to the actual [CupertinoTextField]'s own content.
  /// Defaults to [_defaultContentPadding]; a caller widens or otherwise
  /// changes this whenever it needs to reserve room for its own overlaid
  /// controls (for example [CruxTextFormField]'s obscure toggle, or
  /// `CruxInputBar`'s leading/clear/submit slots) so entered text never
  /// renders underneath them.
  final EdgeInsetsGeometry contentPadding;

  /// The theme's brightness, passed straight through to
  /// [CupertinoTextField.keyboardAppearance] so the on-screen keyboard
  /// matches Crux's own light/dark theme instead of the ambient platform
  /// brightness ([CupertinoTextField]'s own default when this is left
  /// unset).
  final Brightness brightness;

  /// The hint text to show inside the field while it is empty.
  final String? placeholder;

  /// The type of keyboard to show. Passed straight through to
  /// [CupertinoTextField.keyboardType].
  final TextInputType? keyboardType;

  /// The action button the keyboard shows for this field. Passed straight
  /// through to [CupertinoTextField.textInputAction].
  final TextInputAction? textInputAction;

  /// Optional input formatters applied to every edit.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional autofill hints (for example `AutofillHints.email`).
  final Iterable<String>? autofillHints;

  /// Called with the new text on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field (for example by pressing the
  /// keyboard's return/done key).
  final ValueChanged<String>? onSubmitted;

  /// The maximum number of lines this field grows to before it starts
  /// scrolling vertically instead. Defaults to `1` -- an ordinary
  /// single-line field that never grows, matching this core's behavior
  /// before this parameter existed. [CruxTextFormField] never passes this
  /// (it always renders single-line), so its own layout and tests are
  /// unaffected; `CruxInputBar` is the intended caller for a value greater
  /// than `1`.
  ///
  /// Passed to [CupertinoTextField.maxLines] together with a fixed
  /// [CupertinoTextField.minLines] of `1` (set in [build], not exposed as a
  /// parameter here) so a value greater than `1` grows the box starting
  /// from one line, rather than reserving [maxLines]' worth of height
  /// up front. This combination is confirmed against the Flutter SDK's own
  /// documented behavior table, not assumed:
  /// `widgets/editable_text.dart:1264-1271` gives `TextField(maxLines: 2)`
  /// (no `minLines`) as "The input's height is large enough for the given
  /// number of lines" -- i.e. already full height on the first build, the
  /// opposite of what a growing input bar needs -- while
  /// `widgets/editable_text.dart:1310-1315` gives
  /// `TextField(minLines: 2, maxLines: 4)` as "Input whose height starts
  /// from 2 lines and grows up to 4 lines", confirming that supplying
  /// `minLines` is what makes the box start small and grow, not `maxLines`
  /// alone. `minLines: 1` is the "start from one line" instance of that
  /// same pattern. Left at `1` (rather than following [maxLines] up to
  /// equal it) when this is also `1`, `minLines: 1` and `maxLines: 1`
  /// together are exactly equivalent to the pre-existing single-line
  /// default (`minLines: null, maxLines: 1`) -- both fix the box at one
  /// line -- so this stays a no-op for [CruxTextFormField].
  final int maxLines;

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
          // The outer box (built by the caller) draws the border; this
          // field must paint no decoration of its own. An *empty*
          // BoxDecoration (rather than `null`) is used deliberately:
          // CupertinoTextField's own build method only special-cases a
          // `null` `decoration` when the field is disabled — its Container's
          // `color` falls back to an ambient-brightness-resolved gray
          // (`_kDisabledBackground`) whenever `decoration == null &&
          // !enabled`, which would paint a stray fill behind this box
          // exactly when disabled, breaking the documented "no fill, ever"
          // invariant. A non-null-but-empty BoxDecoration paints nothing and
          // never triggers that fallback.
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
          // minLines is deliberately always 1, not exposed as a parameter
          // of this widget: see maxLines' own doc comment above for why
          // this specific pairing is what makes the box start at one line
          // and grow up to maxLines, confirmed against the Flutter SDK.
          minLines: 1,
          maxLines: maxLines,
        ),
      ),
    );
  }
}
