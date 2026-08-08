import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';
import '../state/app_state.dart';

/// The grapheme-cluster limit a single きろく post is held to.
const int _composePostMaxLength = 140;

/// The モーダル for posting a きろく: a short freeform note about the day that
/// ミモザ reacts to.
///
/// Pushed as a fullscreenDialog route (`MaterialPageRoute(fullscreenDialog:
/// true)`) from the ホーム tab's FAB. Posting calls [AppState.addRecord],
/// which both adds the record (shown newest-first in the ホーム tab's
/// 「きょうのきろく」 list) and queues ミモザ's chat reaction -- this screen
/// itself only shows a confirmation toast and closes.
class ComposeScreen extends StatefulWidget {
  /// Creates the きろく posting modal.
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final CruxComposerController _controller = CruxComposerController();
  bool _hasAttachment = false;

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
      // here keeps a post of only whitespace from ever reaching AppState.
      return;
    }
    final AppState appState = AppState.of(context);
    appState.addRecord(trimmed);
    showCruxToast(context, message: mimosaRecordToastMessage);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      // Scaffold's own default (true) already resizes this body to avoid
      // the on-screen keyboard, which is what keeps the composer's action
      // row above it instead of hidden underneath.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _ComposeHeader(colors: colors, type: type),
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
                placeholder: mimosaRecordPlaceholder,
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
                submit: const CruxComposerSubmit(
                  label: mimosaRecordSubmitLabel,
                ),
                onSubmit: _handleSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// This modal's own header: a title and a close control, sized for a
/// dismiss-or-post sheet rather than a pushed screen.
class _ComposeHeader extends StatelessWidget {
  const _ComposeHeader({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: CruxSpacing.s20,
        vertical: CruxSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.separator)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              mimosaRecordModalTitle,
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
          ),
          CruxIconButton(
            icon: const Icon(Icons.close, size: 18),
            label: '閉じる',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// The placeholder image-attachment preview shown above the composer once
/// its 画像を添付 action has been tapped: this app has no real image picker
/// to invoke, so a plain colored tile stands in for whatever one would
/// return, with its own remove control (via [onRemove]).
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
