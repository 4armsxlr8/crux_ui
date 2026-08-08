import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';

import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';

/// [CruxDialogCard]'s maximum width. Not in [CruxSpacing]'s 4px scale,
/// so it lives here as a private constant.
const double _maxCardWidth = 340;

const EdgeInsets _defaultCardPadding = EdgeInsets.fromLTRB(
  CruxSpacing.s24,
  CruxSpacing.s24,
  CruxSpacing.s24,
  CruxSpacing.s20,
);

/// The exit fade's duration. Unlike the entrance, the exit is a plain fade
/// -- no spring.
const Duration _exitFadeDuration = Duration(milliseconds: 140);

/// The entrance spring's starting scale: [_CruxDialogOverlayState] renders
/// its very first frame at this value so the spring has somewhere to fly
/// *from*, instead of mounting already at rest with nothing to animate.
const double _entranceStart = 0.9;

/// The entrance spring's resting/target value: fully open, unscaled.
const double _entranceEnd = 1.0;

/// The "blank card" Crux UI's dialog layer floats: a [child]-agnostic
/// surface -- filled with the theme's surface color, clipped to a
/// superellipse corner, and lifted with [CruxThemeData.shadows]' `lg`
/// shadow -- with no border in either theme (the scrim draws the card's
/// edge) and no scrim or open/close animation of its own.
///
/// This is deliberately renderable entirely on its own, with no [Overlay] or
/// [CruxDialog.show] call involved -- passing it straight to
/// [WidgetTester.pumpWidget] renders the exact same static "floating card"
/// look [CruxDialog.show] wraps with a scrim and entrance animation.
class CruxDialogCard extends StatelessWidget {
  /// Creates a Crux dialog card.
  const CruxDialogCard({
    super.key,
    required this.child,
    this.padding = _defaultCardPadding,
  });

  /// The card's content.
  final Widget child;

  /// The space between the card's edge and [child]. Defaults to 24 logical
  /// pixels on three sides, 20 on the bottom.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxCardWidth),
      child: Container(
        padding: padding,
        // Clips `child` to this same superellipse shape; without it, a
        // full-bleed child would paint straight through the rounded
        // corners.
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: theme.colors.surface,
          shadows: theme.shadows.lg,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(CruxRadii.l),
          ),
        ),
        // Sets this card's own DefaultTextStyle baseline. This card floats
        // outside any Scaffold/Material, so without an explicit baseline it
        // (and any bare Text a caller places in [child]) would inherit
        // whatever DefaultTextStyle sits above wherever it's mounted --
        // including MaterialApp's yellow-double-underline "no enclosing
        // Material" warning style. `TextDecoration.none` is explicit here
        // to stop that from leaking through.
        child: DefaultTextStyle(
          style: theme.typography.body.copyWith(
            color: theme.colors.textPrimary,
            decoration: TextDecoration.none,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Crux UI's floating dialog layer: inserts a [CruxDialogCard] wrapping
/// caller-supplied content into the nearest ancestor [Overlay], behind a
/// tap-to-dismiss scrim, with a spring-driven bouncy entrance and a faded
/// exit.
///
/// ```dart
/// CruxDialog.show(
///   context,
///   builder: (context, close) => Column(
///     mainAxisSize: MainAxisSize.min,
///     children: [
///       Text('カスタムな中身'),
///       CruxButton(label: '閉じる', onPressed: close),
///     ],
///   ),
/// );
/// ```
///
/// **Display mechanism**: this finds the nearest ancestor [Overlay] via
/// `Overlay.of(context)` and inserts a plain [OverlayEntry] into it directly
/// -- it never uses Material's `showDialog` and never requires a
/// [Navigator]/`MaterialApp` (a bare [Overlay] is enough). Its look never
/// depends on an ambient Material theme. Trade-off: because there is no
/// [Route]/[ModalRoute] involved, this dialog does not participate in the
/// system back button, does not appear in `Navigator` history, and cannot
/// be popped with `Navigator.pop`.
///
/// **[builder]** receives a `close` callback alongside the usual
/// [BuildContext]: call it from inside your content (for example a Cancel
/// button's `onPressed`) to close the dialog the same way tapping the scrim
/// does. [builder]'s return value is the dialog's *content* only --
/// [CruxDialog.show] wraps it in a [CruxDialogCard] itself, so a
/// [builder] must not wrap its own return value in another
/// [CruxDialogCard].
///
/// **Dismissal**: tapping the scrim closes the dialog when
/// [barrierDismissible] is `true` (the default). Pass `false` to require an
/// explicit in-content action (via `close`) instead.
///
/// **Semantics**: the dialog's content is wrapped in
/// `Semantics(scopesRoute: true, explicitChildNodes: true)`, marking it as
/// its own accessibility route, and the whole floating layer (scrim + card)
/// is wrapped in [BlockSemantics], so a screen reader can no longer reach
/// the page underneath while the dialog is open. The scrim itself carries
/// no semantics label or action by default -- this package never invents
/// read-aloud wording; pass [barrierSemanticLabel] to give it one.
class CruxDialog {
  const CruxDialog._();

  /// Opens a dialog above [context]'s nearest ancestor [Overlay].
  ///
  /// [builder] builds the dialog's content; see this class's own doc for
  /// what it receives and where its return value gets wrapped.
  ///
  /// [barrierDismissible] (default `true`) controls whether tapping the
  /// scrim closes the dialog.
  ///
  /// [barrierSemanticLabel], if supplied, is announced by assistive
  /// technology for the scrim itself and makes it directly activatable from
  /// there (as a `SemanticsAction.tap`) whenever [barrierDismissible] is
  /// also `true`. Left `null` by default -- this package never decides
  /// read-aloud wording on a caller's behalf; with no label, the scrim
  /// still dismisses on a real touch, it is only left out of the semantics
  /// tree. Pass either this or give [builder]'s content an explicit,
  /// clearly-labelled close action: with neither, a screen reader user
  /// inside this dialog's semantics route has no announced way to dismiss
  /// it.
  ///
  /// [routeSemanticLabel], if supplied, names this dialog's semantics route
  /// (`Semantics.namesRoute` + `Semantics.label`) so assistive technology
  /// announces it by that name on entry, the same way a native dialog
  /// announces its title. Left `null` by default for the same reason as
  /// [barrierSemanticLabel]. Regardless of [routeSemanticLabel], the
  /// dialog's semantics route always carries [SemanticsRole.dialog] so
  /// assistive technology can identify it as a dialog even when it has no
  /// name.
  ///
  /// Returns a [Future] that completes once the dialog has fully closed
  /// (after its exit fade finishes and its [OverlayEntry] is removed).
  ///
  /// **Theme capture**: [CruxTheme.of] is read from [context] once, at
  /// the moment [show] is called, and that value is what the dialog renders
  /// with for its entire lifetime. This matters because an [OverlayEntry]'s
  /// content is built as a child of the [Overlay] widget's own position in
  /// the tree, which is often *not* a descendant of [context] (an
  /// [Overlay] is usually supplied once near the app root); without
  /// capturing, the dialog would silently pick up whatever [CruxTheme]
  /// happens to be an ancestor of the [Overlay] instead of the caller's own
  /// local one. Trade-off: a [CruxTheme] change made *after* this dialog
  /// has already opened is not picked up -- close and reopen to pick up a
  /// changed theme.
  static Future<void> show(
    BuildContext context, {
    required Widget Function(BuildContext context, VoidCallback close) builder,
    bool barrierDismissible = true,
    String? barrierSemanticLabel,
    String? routeSemanticLabel,
  }) {
    final OverlayState overlayState = Overlay.of(context);
    final CruxThemeData capturedTheme = CruxTheme.of(context);
    final Completer<void> completer = Completer<void>();
    late final OverlayEntry entry;

    void handleRequestRemove() {
      // remove() then dispose(), back to back: OverlayEntry requires
      // remove() to have already run before dispose(), not that its widget
      // has finished unmounting -- dispose() itself defers releasing its
      // internal listener until that unmount completes, so calling both
      // immediately here is safe (same pattern Flutter's own
      // `_WrappingOverlayState.dispose()` uses).
      entry
        ..remove()
        ..dispose();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    // Covers the path handleRequestRemove doesn't: the Overlay this entry
    // lives in is torn down by an ancestor rebuild before the dialog was
    // ever closed. The framework has already removed the entry by the time
    // this runs, so this only completes the pending Future -- it must never
    // call entry.remove()/dispose() itself, since the Overlay it lived in
    // is already gone.
    void handleDisposedWithoutClosing() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        // Re-provides the captured theme to the OverlayEntry's own subtree
        // -- see the "Theme capture" doc above.
        return CruxTheme(
          data: capturedTheme,
          child: _CruxDialogOverlay(
            builder: builder,
            barrierDismissible: barrierDismissible,
            barrierSemanticLabel: barrierSemanticLabel,
            routeSemanticLabel: routeSemanticLabel,
            onRequestRemove: handleRequestRemove,
            onDisposedWithoutClosing: handleDisposedWithoutClosing,
          ),
        );
      },
    );
    overlayState.insert(entry);
    return completer.future;
  }
}

/// The stateful overlay content [CruxDialog.show] inserts: owns the
/// entrance spring / exit fade and the scrim's tap-to-dismiss wiring, and
/// composes [CruxDialogCard] around whatever [builder] returns.
class _CruxDialogOverlay extends StatefulWidget {
  const _CruxDialogOverlay({
    required this.builder,
    required this.barrierDismissible,
    required this.barrierSemanticLabel,
    required this.routeSemanticLabel,
    required this.onRequestRemove,
    required this.onDisposedWithoutClosing,
  });

  final Widget Function(BuildContext context, VoidCallback close) builder;
  final bool barrierDismissible;
  final String? barrierSemanticLabel;
  final String? routeSemanticLabel;
  final VoidCallback onRequestRemove;

  /// Called from [State.dispose]: completes [CruxDialog.show]'s Future
  /// when this overlay is torn down without ever going through
  /// [onRequestRemove] (e.g. an ancestor rebuild removes the [Overlay]
  /// itself). A no-op if [onRequestRemove] already ran.
  final VoidCallback onDisposedWithoutClosing;

  @override
  State<_CruxDialogOverlay> createState() => _CruxDialogOverlayState();
}

class _CruxDialogOverlayState extends State<_CruxDialogOverlay> {
  // false on the first build (renders at _entranceStart); flips to true one
  // frame later so animatedValue's `value` changes and actually starts the
  // spring, instead of mounting already-settled with nothing to animate.
  bool _entered = false;

  // Once true, `build` renders the exit fade instead of the entrance spring
  // and never goes back to false -- a dialog does not un-close.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        setState(() => _entered = true);
      }
    });
  }

  @override
  void dispose() {
    widget.onDisposedWithoutClosing();
    super.dispose();
  }

  void _close() {
    // Guards a close callback the caller may have stashed and called after
    // this State was disposed (tree torn down without going through this
    // dialog's own close path) -- otherwise setState below throws
    // "setState() called after dispose()".
    if (!mounted || _closing) {
      return;
    }
    setState(() => _closing = true);
  }

  void _handleScrimTap() {
    if (widget.barrierDismissible) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final Widget content = widget.builder(context, _close);
    final Widget card = CruxDialogCard(child: content);

    if (_closing) {
      // Blocks the whole floating layer from hit-testing during the exit
      // fade: `build` keeps calling `widget.builder` while closing, so an
      // in-content action (e.g. CruxConfirmDialog's confirm button) stays
      // tappable and could re-run its callback on a second tap during the
      // fade. `_close`'s own `_closing` guard stops a second *close*, but
      // not the button's callback -- only refusing the tap here does.
      return IgnorePointer(
        ignoring: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: 0.0),
          duration: _exitFadeDuration,
          curve: Curves.easeIn,
          onEnd: widget.onRequestRemove,
          builder: (BuildContext context, double opacity, Widget? child) {
            return _buildLayer(theme: theme, opacity: opacity, card: card);
          },
        ),
      );
    }

    return CruxMotion.animatedValue(
      value: _entered ? _entranceEnd : _entranceStart,
      playful: true,
      builder: (BuildContext context, double value, Widget? child) {
        // Derived from the same spring value that drives the scale (not a
        // second animation), so the fade and bounce stay in lockstep.
        final double opacity =
            ((value - _entranceStart) / (_entranceEnd - _entranceStart)).clamp(
              0.0,
              1.0,
            );
        return _buildLayer(
          theme: theme,
          opacity: opacity,
          card: Transform.scale(scale: value, child: card),
        );
      },
    );
  }

  /// Assembles the scrim + centered card at a shared [opacity], wrapped in
  /// this dialog's modal semantics -- see [CruxDialog]'s class doc for the
  /// [BlockSemantics] / `scopesRoute` reasoning.
  Widget _buildLayer({
    required CruxThemeData theme,
    required double opacity,
    required Widget card,
  }) {
    final String? label = widget.barrierSemanticLabel;

    Widget scrim = Opacity(
      opacity: opacity,
      child: ColoredBox(color: theme.shadows.scrim),
    );
    scrim = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleScrimTap,
      child: scrim,
    );
    scrim = label != null
        ? Semantics(
            label: label,
            button: widget.barrierDismissible,
            onTap: widget.barrierDismissible ? _handleScrimTap : null,
            child: scrim,
          )
        : ExcludeSemantics(child: scrim);

    final String? routeLabel = widget.routeSemanticLabel;
    return BlockSemantics(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        // Always applied: identifies this route as a dialog to assistive
        // technology even when it has no name.
        role: SemanticsRole.dialog,
        namesRoute: routeLabel != null,
        label: routeLabel,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: scrim),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(CruxSpacing.s24),
                child: Opacity(opacity: opacity, child: card),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
