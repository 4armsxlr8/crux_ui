import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Default value for [CruxTextFieldCore.contentPadding].
const EdgeInsets _defaultContentPadding = EdgeInsets.all(CruxSpacing.s12);

/// The token-styled [CupertinoTextField] core shared by every Crux text
/// input atom: body typography, [CruxColors.textPrimary] text, an empty
/// `BoxDecoration` (the caller draws its own box), and cursor/selection
/// -highlight/drag-handle colors sealed to [CruxColors.accent] regardless
/// of any ambient Material theme. It does not know about labels, helper
/// text, or `Form` integration -- those stay specific to whichever atom
/// uses it ([CruxTextFormField], `CruxInputBar`, `CruxComposer`).
///
/// Public (no leading underscore) so sibling files under `lib/src/` can
/// import it -- Dart privacy is scoped per file/library -- but never
/// exported from `lib/crux_ui.dart`, so it is not part of this package's
/// public API.
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
    this.expands = false,
    this.textAlignVertical,
  }) : assert(
         !obscureText || (!expands && maxLines == 1),
         'Obscured fields cannot be multiline -- this mirrors '
         "CupertinoTextField's own assert (Flutter SDK "
         '`cupertino/text_field.dart:328`: `assert(!obscureText || maxLines '
         "== 1, 'Obscured fields cannot be multiline.')`) so a caller "
         'mistake (a future CruxInputBar wiring both obscureText and a '
         'multiline maxLines together) fails loudly at this call site '
         "instead of only inside CupertinoTextField's own constructor. "
         'Strengthened to also reject `obscureText: true` together with '
         '`expands: true`: the original check alone (`!obscureText || '
         'maxLines == 1`) can still pass at this call site with `expands: '
         "true` -- [maxLines] keeps whatever value a caller left it at "
         "(commonly its default of `1`) even when [expands] is what "
         "actually controls what reaches CupertinoTextField -- only to "
         "fail deeper inside the SDK once build() forces both minLines and "
         'maxLines to `null` for `expands: true` (see the doc on '
         "[expands] and on build() below), tripping "
         '`widgets/editable_text.dart`\'s own `assert(!expands || '
         '(maxLines == null && minLines == null))` instead. Requiring '
         '`!expands` here too closes that gap at this class\'s own entry '
         'point.',
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
  /// scrolling vertically instead. Defaults to `1`, an ordinary single-line
  /// field that never grows. [CruxTextFormField] never passes this;
  /// `CruxInputBar` is the intended caller for a value greater than `1`.
  ///
  /// Paired in [build] with a fixed `minLines: 1`: that combination is what
  /// makes the box start at one line and grow, rather than reserving
  /// [maxLines]' worth of height up front.
  ///
  /// Ignored entirely whenever [expands] is `true` -- see that field's doc.
  final int maxLines;

  /// Whether this field expands to fill the height its parent gives it,
  /// instead of sizing itself from [maxLines]. Defaults to `false`.
  /// `CruxComposer` is the intended caller for `true`: it fills whatever
  /// height its parent gives it and scrolls its own content internally,
  /// rather than growing line-by-line the way `CruxInputBar` does.
  ///
  /// The Flutter SDK asserts `!expands || (maxLines == null && minLines ==
  /// null)`, so [build] passes `minLines: null, maxLines: null` whenever
  /// this is `true` ([maxLines] is then ignored) and the ordinary
  /// `minLines: 1, maxLines: maxLines` otherwise.
  ///
  /// Side effect: with [expands] `true`, [CupertinoTextField] defaults
  /// [keyboardType] to a multiline keyboard instead of single-line
  /// whenever a caller leaves it unset -- the behavior `CruxComposer`
  /// wants (return key inserts a newline rather than submitting).
  final bool expands;

  /// How the text and placeholder are aligned vertically within the field.
  /// Passed straight through to [CupertinoTextField.textAlignVertical].
  /// Defaults to `null` (vertically centered). `CruxComposer` is the
  /// intended caller of [TextAlignVertical.top], so its text starts at the
  /// top of the field once [expands] makes it taller than one line.
  final TextAlignVertical? textAlignVertical;

  @override
  Widget build(BuildContext context) {
    // Seals cursor/selection colors against an ambient Material
    // `Theme`/`MaterialApp`: `CupertinoTextField` resolves both via
    // `DefaultSelectionStyle.of(context)` *before* falling back to
    // `CupertinoTheme.primaryColor`, and `Theme`/`MaterialApp` install a
    // `DefaultSelectionStyle` sourced from the app's `ColorScheme` -- so a
    // `CupertinoTheme` wrapper alone would not override it inside a
    // Material app.
    return DefaultSelectionStyle(
      cursorColor: colors.accent,
      selectionColor: colors.accentTint,
      child: CupertinoTheme(
        // Not redundant with DefaultSelectionStyle above: this wrapper
        // still supplies `selectionHandleColor` (drag handles) and the
        // magnifier ring's color, neither of which DefaultSelectionStyle
        // intercepts. Both are painted through an Overlay entry outside
        // this subtree, but Flutter re-applies this CupertinoTheme there
        // via `InheritedTheme.capture`, so it still reaches them.
        data: CupertinoThemeData(
          primaryColor: colors.accent,
          selectionHandleColor: colors.accent,
        ),
        child: CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          // Empty BoxDecoration, not null: CupertinoTextField falls back to
          // a gray fill when `decoration == null && !enabled`, which would
          // paint a stray fill behind this box. An empty decoration paints
          // nothing and avoids that fallback; the caller's own box draws
          // the real border/fill.
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
          // See [expands] and [maxLines] docs for why this branches.
          minLines: expands ? null : 1,
          maxLines: expands ? null : maxLines,
          expands: expands,
          textAlignVertical: textAlignVertical,
        ),
      ),
    );
  }
}
