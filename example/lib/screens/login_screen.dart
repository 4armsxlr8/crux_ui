import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

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

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a login form demonstrating [CruxTextFormField]'s `Form`/`validator`
/// wiring, reached from the home index's "ログイン" row.
///
/// This is a real client-side form (a [Form] wrapping two
/// [CruxTextFormField]s, each with its own `validator`), not a fake
/// network round trip: this sample app has no backend to authenticate
/// against, so a successful [FormState.validate] only flips this screen to
/// a visible "validated" state in place — see [_LoginScreenState._submit] —
/// rather than pretending to navigate anywhere or check credentials against
/// a server. That is the honest limit of what a form with no backend can
/// promise.
class LoginScreen extends StatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _validated = false;

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

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    form.save();
    // See this class's own doc comment: there is no backend to
    // authenticate against, so this deliberately does not fake a network
    // call or a fake auth result. A form that passes its own validation
    // simply flips to a visible "validated" state below, in place.
    setState(() => _validated = true);
  }

  void _reset() {
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
    setState(() => _validated = false);
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'ログイン'),
            Expanded(
              // SingleChildScrollView (rather than a fixed-height Column) is
              // what keeps both fields reachable once the on-screen keyboard
              // opens on a phone: Scaffold already resizes for the keyboard
              // by default, and this lets the content scroll within
              // whatever space is left instead of the password field being
              // pushed off-screen behind the keyboard.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(CruxSpacing.s20),
                child: _validated
                    ? _LoginSuccessView(
                        colors: colors,
                        type: type,
                        onReset: _reset,
                      )
                    : _LoginForm(
                        colors: colors,
                        type: type,
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        passwordFocusNode: _passwordFocusNode,
                        validateEmail: _validateEmail,
                        validatePassword: _validatePassword,
                        onSubmit: _submit,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.colors,
    required this.type,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.validateEmail,
    required this.validatePassword,
    required this.onSubmit,
  });

  final CruxColors colors;
  final CruxTypography type;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'メールアドレスとパスワードでログインしてください。',
          textAlign: TextAlign.center,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: CruxSpacing.s24),
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
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: CruxSpacing.s20),
                Align(
                  alignment: Alignment.centerRight,
                  child: CruxButton(label: 'ログイン', onPressed: onSubmit),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The visible, honest "success" state [LoginScreen] flips to once its form
/// validates: it says plainly that no server was contacted, rather than
/// implying a real sign-in happened.
class _LoginSuccessView extends StatelessWidget {
  const _LoginSuccessView({
    required this.colors,
    required this.type,
    required this.onReset,
  });

  final CruxColors colors;
  final CruxTypography type;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 40, color: colors.success),
          const SizedBox(height: CruxSpacing.s12),
          Text(
            '入力内容の検証に成功しました',
            textAlign: TextAlign.center,
            style: type.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: CruxSpacing.s8),
          Text(
            'このサンプルに接続先のサーバーはなく、実際の認証は行っていません。'
            'ここまでは CruxTextFormField と Form によるバリデーションだけで完結しています。',
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: CruxSpacing.s20),
          Center(
            child: CruxButton(
              label: 'もう一度試す',
              variant: CruxButtonVariant.tonal,
              onPressed: onReset,
            ),
          ),
        ],
      ),
    );
  }
}
