import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

/// The grapheme-cluster limit [ComposeScreen] enforces on a single post --
/// an arbitrary, screen-chosen number (this sample has no backend format to
/// match), well short of [CruxComposer.maxLength]'s own default of "no
/// limit at all".
const int _composePostMaxLength = 140;

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a "new post" composer reached from the home index's "新規投稿" row.
///
/// Unlike every other screen here, this one is pushed as the app's first
/// modal route (`MaterialPageRoute(fullscreenDialog: true)`, see
/// `home_index_page.dart`): composing a post is a transient,
/// cancel-or-commit task, the kind of thing iOS conventionally presents as
/// a sheet over the current screen rather than another push in the same
/// stack, unlike browsing the other sample screens.
///
/// This demonstrates [CruxComposer] filling the height an [Expanded]
/// hands it and scrolling its own text internally rather than growing
/// line-by-line, its `maxLength`-gated character counter and over-limit
/// highlight, one caller-supplied [CruxComposerAction] for attaching an
/// image (the icon and its screen-reader label are this app's own, not the
/// package's -- [CruxComposer] never assumes either), and its `submit`
/// button. Posting shows a visible, dismissible confirmation banner instead
/// of pretending to publish anywhere -- the same "no backend, so flip to a
/// visible result in place" honesty [LoginScreen]'s own success view
/// documents for its own submit.
///
/// Keyboard avoidance is this screen's own responsibility, not
/// [CruxComposer]'s: [Scaffold]'s own default `resizeToAvoidBottomInset`
/// is what keeps the composer's action row (attach button, counter, post
/// button) above the on-screen keyboard instead of hidden underneath it --
/// named explicitly below the same way `chat_screen.dart` does for its own
/// composer.
///
/// This screen is deliberately a "this is what it looks like in a real
/// screen" demo, not a token or atom-state catalog -- those full listings
/// live in `widgetbook/` instead. See root `CLAUDE.md`'s catalog operating
/// rule.
class ComposeScreen extends StatefulWidget {
  /// Creates the new-post sample screen.
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final CruxComposerController _controller = CruxComposerController();
  bool _hasAttachment = false;
  String? _postedText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleToggleAttachment() {
    setState(() => _hasAttachment = !_hasAttachment);
  }

  void _handleRemoveAttachment() {
    setState(() => _hasAttachment = false);
  }

  void _handleSubmit(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      // CruxComposer's own submit button already refuses to fire this
      // callback while its text is empty or over the limit, but guarding
      // here keeps a post of only whitespace from ever producing a
      // confirmation -- the same belt-and-suspenders check ChatScreen's own
      // `_handleSend` makes for its send button.
      return;
    }
    setState(() {
      _postedText = trimmed;
      _hasAttachment = false;
    });
    _controller.clear();
  }

  void _handleDismissConfirmation() {
    setState(() => _postedText = null);
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final String? postedText = _postedText;

    return Scaffold(
      backgroundColor: colors.background,
      // Scaffold's own default (true) already resizes this body to avoid
      // the on-screen keyboard, which is what keeps the composer's action
      // row above it instead of hidden underneath -- named explicitly here
      // since that behavior is exactly what this screen relies on (keyboard
      // avoidance is the screen's responsibility, not CruxComposer's).
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '新規投稿'),
            if (postedText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CruxSpacing.s20,
                  CruxSpacing.s12,
                  CruxSpacing.s20,
                  0,
                ),
                child: _PostedConfirmation(
                  colors: colors,
                  type: type,
                  text: postedText,
                  onDismiss: _handleDismissConfirmation,
                ),
              ),
            if (_hasAttachment)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CruxSpacing.s20,
                  CruxSpacing.s12,
                  CruxSpacing.s20,
                  0,
                ),
                child: _AttachmentPreview(
                  colors: colors,
                  type: type,
                  onRemove: _handleRemoveAttachment,
                ),
              ),
            Expanded(
              child: CruxComposer(
                controller: _controller,
                placeholder: 'いま何してる?',
                maxLength: _composePostMaxLength,
                actions: <CruxComposerAction>[
                  CruxComposerAction(
                    icon: Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    label: '画像を添付',
                    onPressed: _handleToggleAttachment,
                  ),
                ],
                submit: const CruxComposerSubmit(label: '投稿'),
                onSubmit: _handleSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dismissible confirmation [ComposeScreen] shows once a post has gone
/// through: this sample has no backend to actually publish to, so -- the
/// same honest limit [LoginScreen]'s own success view documents for its own
/// submit -- a successful post only reveals this banner in place rather
/// than pretending to navigate anywhere. Tapping its close control (via
/// [onDismiss]) hides it again without affecting the composer underneath.
class _PostedConfirmation extends StatelessWidget {
  const _PostedConfirmation({
    required this.colors,
    required this.type,
    required this.text,
    required this.onDismiss,
  });

  final CruxColors colors;
  final CruxTypography type;
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: colors.success),
          const SizedBox(width: CruxSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '投稿しました',
                  style: type.body.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: CruxSpacing.s4),
                Text(
                  text,
                  style: type.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: CruxSpacing.s8),
          CruxIconButton(
            icon: const Icon(Icons.close, size: 18),
            label: '閉じる',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The placeholder image-attachment preview [ComposeScreen] shows above the
/// composer once its "画像を添付" action has been tapped: this sample has no
/// real image picker to invoke, so a plain colored tile stands in for
/// whatever a real app's picker would return, with its own remove control
/// (via [onRemove]).
class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.colors,
    required this.type,
    required this.onRemove,
  });

  final CruxColors colors;
  final CruxTypography type;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accentTint,
            borderRadius: BorderRadius.circular(CruxRadii.m),
          ),
          child: Icon(Icons.image, size: 24, color: colors.accent),
        ),
        const SizedBox(width: CruxSpacing.s12),
        Expanded(
          child: Text(
            '画像1件を添付中',
            style: type.caption.copyWith(color: colors.textSecondary),
          ),
        ),
        CruxIconButton(
          icon: const Icon(Icons.close, size: 18),
          label: '添付を外す',
          onPressed: onRemove,
        ),
      ],
    );
  }
}
