import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';

import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';

/// The maximum width a [CruxDialogCard] ever grows to, matching mock case
/// B's `.dialog-card`'s `width: min(340px, 100%)` -- a fixed pixel value
/// with no home in [CruxSpacing]'s 4px scale, so (like `button.dart`'s
/// `_minTapTarget`) it lives here as a private, file-local constant instead
/// of a shared token.
const double _maxCardWidth = 340;

/// [CruxDialogCard]'s default padding, matching mock case B's
/// `.dialog-card` padding shorthand (`24px 24px 20px` -- 24 on the top/left
/// /right edges, 20 on the bottom).
const EdgeInsets _defaultCardPadding = EdgeInsets.fromLTRB(
  CruxSpacing.s24,
  CruxSpacing.s24,
  CruxSpacing.s24,
  CruxSpacing.s20,
);

/// The exit fade's duration: [CruxDialog.show]'s leave transition is a
/// plain fade (no spring, unlike the entrance -- see this file's "入場: ...
/// + フェード。退場はフェード" spec), matching mock case B's `dialog-out`
/// keyframe timing.
const Duration _exitFadeDuration = Duration(milliseconds: 140);

/// The entrance spring's starting position for [CruxMotion.animatedValue]:
/// [_CruxDialogOverlayState] renders its very first frame at this value
/// (see its `initState`) so the spring has somewhere to fly *from* toward
/// [_entranceEnd], instead of mounting already at rest with nothing to
/// animate. Matches mock case B's `dialog-in` keyframe start (`scale(0.9)`).
const double _entranceStart = 0.9;

/// The entrance spring's resting/target value: fully open, unscaled.
const double _entranceEnd = 1.0;

/// The "blank card" Crux UI's dialog layer floats: a [child]-agnostic
/// surface -- filled with the theme's surface color, clipped to a
/// superellipse corner, and lifted with [CruxThemeData.shadows]' `lg`
/// shadow -- with no border in either theme (per the confirmed "the scrim
/// draws the card's edge; dark mode does not add a hairline here" decision,
/// see `unknowns/atoms-batch-3/ledger.md`) and no scrim or open/close animation
/// of its own.
///
/// This is deliberately renderable entirely on its own, with no [Overlay] or
/// [CruxDialog.show] call involved -- passing it straight to
/// [WidgetTester.pumpWidget], or a future widgetbook golden, renders the
/// exact same static "floating card" look [CruxDialog.show] wraps with a
/// scrim and entrance animation, satisfying golden testing's "must be a
/// themed-only, non-animated widget" constraint.
class CruxDialogCard extends StatelessWidget {
  /// Creates a Crux dialog card.
  const CruxDialogCard({
    super.key,
    required this.child,
    this.padding = _defaultCardPadding,
  });

  /// The card's content.
  final Widget child;

  /// The space between the card's edge and [child]. Defaults to mock case
  /// B's `.dialog-card` padding (24 logical pixels on three sides, 20 on
  /// the bottom).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxCardWidth),
      child: Container(
        padding: padding,
        // Clips `child` to this same superellipse shape -- the same reason
        // `card.dart`'s CruxCard clips its own content (see that file's
        // longer comment on the identical mechanism): without it, a
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
        // Establishes this card's own DefaultTextStyle baseline -- the same
        // "a subtree floating outside Material resets its own ambient text
        // style" fix Material's own `Material` widget makes for ordinary,
        // in-Scaffold content. Without this, both this package's own Text
        // widgets inside [child] (none of which set `decoration` -- see
        // typography.dart) and any bare, unstyled Text a caller places
        // straight into a blank dialog inherit whatever `DefaultTextStyle`
        // happens to sit above wherever this card is mounted -- which, for
        // a card shown via [CruxDialog.show], is the [Overlay]'s own
        // position in the tree. `MaterialApp` always installs a garish
        // "no enclosing Material" warning style (yellow double-underline)
        // at its root, well above the Overlay; an ordinary screen never
        // sees it because its `Scaffold` builds a `Material` that resets
        // `DefaultTextStyle` first, but this floating card sits outside
        // any Scaffold entirely. `TextDecoration.none` is explicit (not
        // left to default) precisely to stop that ambient decoration from
        // leaking through, matching H3: this package's look must never
        // depend on an ambient Material theme.
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
/// -- it never uses Material's `showDialog`, never touches an ambient
/// `ThemeData`, and never requires a [Navigator]/`MaterialApp` (a bare
/// [Overlay] is enough, which is also how this package's own tests exercise
/// it). This keeps the same guarantee every other Crux component makes:
/// its look never depends on or is affected by an ambient Material theme.
/// The trade-off, recorded for whoever revisits this later: because there is
/// no [Route]/[ModalRoute] involved, this dialog does not participate in the
/// system back button, does not appear in `Navigator` history, and cannot be
/// popped with `Navigator.pop`. Adding an alternate `Navigator`-route-based
/// display path later, if that trade-off ever needs revisiting, is a
/// non-breaking addition -- [CruxDialogCard] and [CruxConfirmDialog]
/// would both stay exactly as-is either way, since neither one knows how it
/// is being displayed.
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
/// **Semantics**: this package's first modal semantics design. The dialog's
/// content is wrapped in `Semantics(scopesRoute: true, explicitChildNodes:
/// true)`, marking it as its own accessibility route the same way a native
/// dialog would be announced, and the whole floating layer (scrim + card) is
/// wrapped in [BlockSemantics], which drops the semantics of whatever
/// painted behind it in the same [Overlay] -- so a screen reader can no
/// longer reach the page underneath while the dialog is open, even though
/// this package never touches a [Navigator]/route to get that isolation for
/// free. The scrim itself carries no semantics label or action by default
/// (per this package's "never decide read-aloud wording for a caller" rule
/// -- see [barrierSemanticLabel]'s own doc); pass [barrierSemanticLabel] to
/// give it one.
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
  /// also `true`. Left `null` (the default) since this package never decides
  /// read-aloud wording on a caller's behalf (H1) -- with no label, the
  /// scrim still dismisses on a real touch, it is only left out of the
  /// semantics tree.
  ///
  /// Assistive technology recommendation: pass either [barrierSemanticLabel]
  /// or give [builder]'s content an explicit, clearly-labelled close action.
  /// With neither, a screen reader user who has landed inside this dialog's
  /// semantics route has no announced way to dismiss it -- the scrim still
  /// dismisses on a real touch, but that gesture is undiscoverable without
  /// some spoken affordance pointing to it.
  ///
  /// [routeSemanticLabel], if supplied, names this dialog's semantics route
  /// (`Semantics.namesRoute` + `Semantics.label`) so assistive technology
  /// announces it by that name on entry, the same way a native dialog
  /// announces its title. Left `null` (the default), again per H1: this
  /// package never invents wording, so an unnamed route is simply left
  /// unnamed rather than guessing at one. Regardless of
  /// [routeSemanticLabel], the dialog's semantics route always carries
  /// [SemanticsRole.dialog] so assistive technology can identify it as a
  /// dialog even when it has no name.
  ///
  /// Returns a [Future] that completes once the dialog has fully closed
  /// (after its exit fade finishes and its [OverlayEntry] is removed).
  ///
  /// **Theme capture**: [CruxTheme.of] is read from [context] once, at the
  /// moment [show] is called, and that value is what the dialog renders
  /// with for its entire lifetime -- not whatever [CruxTheme] happens to
  /// sit above the [Overlay] the entry is inserted into. This matters
  /// because an [OverlayEntry]'s content is built as a child of the
  /// [Overlay] widget's own position in the tree, which is very often *not*
  /// a descendant of [context] (an [Overlay] is usually much higher up,
  /// e.g. supplied once near the app root); without capturing, the dialog
  /// would silently pick up whatever [CruxTheme] (or none, falling back
  /// to light) happens to be an ancestor of the [Overlay] instead of the
  /// caller's own local one -- the same "same-shaped bug" `showDialog` in
  /// Material solves with `InheritedTheme.captureAll`. The trade-off: a
  /// [CruxTheme] change made *after* this dialog has already opened is
  /// not picked up by an already-open dialog, even if [context] stays
  /// mounted under a new one -- close and reopen to pick up a changed
  /// theme.
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
      // remove() then dispose(), back to back: OverlayEntry's own contract
      // ("The remove method must be called before this method if the
      // OverlayEntry is inserted into an Overlay") only requires remove()
      // to have already run, not that its widget has finished unmounting --
      // dispose() itself defers releasing its internal listener notifier
      // until that unmount completes if it hasn't yet (see its own "If
      // we're still mounted when disposed..." handling), so calling both
      // immediately here is safe. This matches the SDK's own internal
      // `_entry..remove()..dispose();` pattern for a widget that owns its
      // own OverlayEntry (`_WrappingOverlayState.dispose()`). Previously
      // this only called remove(), leaving every closed dialog's entry
      // never disposed -- a lifecycle contract violation that also delayed
      // releasing its resources until garbage collection instead of
      // immediately.
      entry
        ..remove()
        ..dispose();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    // Covers the path _handleRequestRemove doesn't: the Overlay this entry
    // lives in gets torn down by an ancestor rebuild (e.g. the whole route,
    // or in tests a fresh pumpWidget) before the dialog was ever closed via
    // the scrim or the builder's close callback. The framework has already
    // removed the entry by the time this runs, so this only completes the
    // still-pending Future -- it must never call entry.remove() (or
    // entry.dispose(), which requires remove() to have already run) itself:
    // by this point the Overlay this entry lived in is itself gone, and
    // calling either could reach into that now-defunct OverlayState.
    void handleDisposedWithoutClosing() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        // Re-provides the theme captured above to the OverlayEntry's own
        // subtree, which otherwise only sees whatever CruxTheme sits
        // above the Overlay itself -- see this method's own "Theme
        // capture" doc.
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
  // false on the very first build (rendering at _entranceStart), flipped to
  // true one frame later so CruxMotion.animatedValue sees its `value`
  // change from _entranceStart to _entranceEnd and actually starts the
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
    // Guards against a close callback that a caller kept a reference to
    // (e.g. captured inside `builder` and stashed for later) outliving this
    // State -- if the whole tree (Overlay included) was torn down without
    // ever going through this dialog's own close path, calling setState
    // below would throw "setState() called after dispose()".
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
      // Blocks the whole floating layer -- scrim and card alike -- from
      // hit-testing for the entire exit fade: `build` above still calls
      // `widget.builder` on every rebuild while closing, so a still-mounted
      // in-content action (for example CruxConfirmDialog's confirm
      // button) keeps its `onPressed` wired up and would otherwise stay
      // tappable for the full 140ms fade. Without this, a second real tap
      // landing in that window reaches the button again and re-runs its
      // callback -- observed as, e.g., a confirm dialog's onConfirm firing
      // twice for two fast taps on the same button. `_close` itself already
      // guards against a second *close* (see its own `_closing` check), but
      // that guard cannot stop the button's own callback from running a
      // second time; only refusing the tap at the hit-test level does.
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
        // Derived from the same spring value that drives the scale, rather
        // than a second, independent animation: this keeps the fade and the
        // bounce perfectly in lockstep (no risk of the two ever drifting out
        // of sync), and reaches full opacity by the time the spring first
        // crosses its resting value, before any of its overshoot plays out.
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
        // Always applied (regardless of routeLabel): identifies this route
        // as a dialog to assistive technology even when it has no name --
        // see [CruxDialog.show]'s own "routeSemanticLabel" doc.
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
