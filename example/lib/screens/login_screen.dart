import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';
import 'main_shell.dart';

/// A deliberately non-exhaustive email shape check for [LoginScreen]'s email
/// field: it rejects obviously malformed input (no `@`, no dot-separated
/// domain) without attempting the full RFC 5322 grammar, which is more than
/// a client-side form needs.
final RegExp _loginEmailShapePattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The minimum password length [LoginScreen]'s password field accepts. Kept
/// as a named constant so the length check and its Japanese error message
/// (which spells the number out, since string interpolation would need an
/// awkward `${}` to stay unambiguous next to Japanese text) are easy to
/// keep in sync by hand.
const int _loginMinPasswordLength = 8;

/// This app's launch screen: a real client-side sign-in form (a [Form]
/// wrapping two [CruxTextFormField]s, each with its own `validator`), not
/// a fake network round trip -- this sample app has no backend to
/// authenticate against, so a validated submit simulates the round trip a
/// real one would take (see [_LoginScreenState._submit]) and then replaces
/// this screen with `MainShell` rather than checking credentials against a
/// server. That is the honest limit of what a form with no backend can
/// promise. Both fields start pre-filled with [mimosaDemoEmail]/
/// [mimosaDemoPassword], so launching the app and tapping ログイン alone
/// signs in; the validators still run and reject a field that's been
/// cleared.
class LoginScreen extends StatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController(
    text: mimosaDemoEmail,
  );
  final TextEditingController _passwordController = TextEditingController(
    text: mimosaDemoPassword,
  );
  final FocusNode _passwordFocusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    if (!_loginEmailShapePattern.hasMatch(value)) {
      return 'メールアドレスの形式が正しくありません';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'パスワードを入力してください';
    }
    if (value.length < _loginMinPasswordLength) {
      return 'パスワードは8文字以上で入力してください';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) {
      // Already mid-flight: `CruxButton.loading` disables the button
      // itself, but the password field's `onSubmitted` (the keyboard's
      // "Done" key) calls this same method directly and isn't gated by the
      // button's disabled state, so a second submit could otherwise start
      // while the first is still awaiting its simulated round trip.
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    form.save();
    // See this class's own doc comment: there is no backend to
    // authenticate against, so this simulates the round trip a real submit
    // would make instead -- a brief [CruxButton.loading] spell -- before
    // moving on to `MainShell`. `CruxButton` itself already ignores taps
    // while `loading` is `true`, so there's no separate guard needed
    // against a second tap firing this again mid-flight.
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) {
      // The screen was popped/disposed while the simulated network delay
      // was in flight -- bail out instead of using a stale BuildContext.
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const MainShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          // SingleChildScrollView (rather than a fixed-height Column) is
          // what keeps both fields reachable once the on-screen keyboard
          // opens on a phone: this lets the content scroll within whatever
          // space is left instead of the password field being pushed
          // off-screen behind the keyboard.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CruxSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mimosaAvatarEmoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: CruxSpacing.s8),
                Text(
                  mimosaAppName,
                  textAlign: TextAlign.center,
                  style: type.heading.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: CruxSpacing.s4),
                Text(
                  mimosaLoginCatchphrase,
                  textAlign: TextAlign.center,
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: CruxSpacing.s24),
                _LoginForm(
                  colors: colors,
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  passwordFocusNode: _passwordFocusNode,
                  validateEmail: _validateEmail,
                  validatePassword: _validatePassword,
                  submitting: _submitting,
                  onSubmit: _submit,
                ),
                const SizedBox(height: CruxSpacing.s20),
                Text(
                  mimosaLoginFootnote,
                  textAlign: TextAlign.center,
                  style: type.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.colors,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.validateEmail,
    required this.validatePassword,
    required this.submitting,
    required this.onSubmit,
  });

  final CruxColors colors;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  /// Whether the simulated submit round trip (see
  /// `_LoginScreenState._submit`) is currently in flight -- forwarded
  /// straight to [CruxButton.loading] below.
  final bool submitting;

  /// Starts the simulated submit round trip. Returns a [Future] so callers
  /// that need to wait for it can (none currently do); call sites here
  /// intentionally fire-and-forget it via [unawaited], since a form submit
  /// button's own tap handler has nothing useful to do with the result.
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CruxCard(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                CruxTextFormField(
                  label: 'メールアドレス',
                  placeholder: 'you@example.com',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: validateEmail,
                  onSubmitted: (_) => passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: CruxSpacing.s12),
                CruxTextFormField(
                  label: 'パスワード',
                  obscureText: true,
                  // crux_ui never bundles its own icon set (different
                  // apps ship different icon fonts), so this app -- not
                  // the package -- supplies the eye/eye-slash glyphs and
                  // their Japanese screen-reader labels. Material's own
                  // `Icons.visibility`/`Icons.visibility_off` are used here
                  // simply because this screen already depends on
                  // `material.dart` for its `Scaffold`; a Cupertino-only
                  // app could pass `CupertinoIcons.eye`/`eye_slash` instead
                  // with no change to crux_ui itself.
                  obscureToggle: CruxObscureToggle(
                    obscuredIcon: Icon(
                      Icons.visibility_outlined,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    revealedIcon: Icon(
                      Icons.visibility_off_outlined,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    obscuredLabel: 'パスワードを表示',
                    revealedLabel: 'パスワードを隠す',
                  ),
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  validator: validatePassword,
                  onSubmitted: (_) => unawaited(onSubmit()),
                ),
                const SizedBox(height: CruxSpacing.s20),
                Align(
                  alignment: Alignment.centerRight,
                  child: CruxButton(
                    label: 'ログイン',
                    loading: submitting,
                    onPressed: () => unawaited(onSubmit()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
