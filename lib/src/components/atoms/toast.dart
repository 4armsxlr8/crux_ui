import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/shadows.dart';
import '../../tokens/spacing.dart';
import '../../tokens/theme.dart';

/// The minimum tap target size for a [CruxToastCard]'s action button
/// (matching every other pressable Crux atom's K B9 rule): 44 logical
/// pixels, even though the visible label is smaller than that.
const double _minTapTarget = 44;

/// The most toasts [CruxToastHost] shows at once (plan's "画面下部・最大3件").
/// A 4th distinct message evicts the oldest currently-active toast.
const int _maxToasts = 3;

/// The most toast cards -- active *and* still mid-exit ([_ToastEntry.
/// leaving]) combined -- [CruxToastHost] ever mounts at once (self-decided,
/// codex review's "画面を溢れうる" finding: a rapid burst of distinct
/// messages, each one arriving faster than [_exitAnimationDuration], can pile
/// up more leaving entries than [_maxToasts] alone bounds, since a leaving
/// entry keeps occupying a slot in the stack until its exit animation
/// finishes).
///
/// [_maxToasts] (3) plus 2: normal operation already produces at most one
/// leaving entry beyond the 3 active ones (a single 4th-message eviction), so
/// this cap only ever engages for a burst well outside that steady state --
/// exactly the runaway case this guards against -- while still giving a
/// second leaving card room to overlap the first's exit before anything gets
/// force-evicted. Once [_entries] would exceed this count,
/// [_CruxToastHostState._enforceRenderCap] removes the oldest
/// [_ToastEntry.leaving] entry immediately, skipping its exit animation --
/// unlike [_CruxToastHostState._dismiss]'s normal path, there is no room
/// left on screen to animate it out gracefully.
const int _maxRenderedTotal = _maxToasts + 2;

/// How long a toast with no [CruxToastAction] stays on screen before
/// auto-dismissing (plan's "約3秒"), once shown or re-shown while already
/// frontmost.
const Duration _defaultDismissDuration = Duration(seconds: 3);

/// How long a toast *with* a [CruxToastAction] stays on screen before
/// auto-dismissing.
///
/// Twice [_defaultDismissDuration]: long enough to register that an action
/// exists, decide whether to use it, and actually tap it, without leaving a
/// stale toast on screen indefinitely -- self-decided (the plan leaves this
/// duration to be "調整して記録"), recorded here rather than in a design doc
/// per this package's existing convention of documenting tuned constants
/// alongside their declaration (see motion.dart's shake constants).
const Duration _actionDismissDuration = Duration(seconds: 6);

/// How long a dismissed toast is kept mounted (rendering its fade/shrink
/// exit) after being marked as leaving, before it is spliced out of
/// [_CruxToastHostState.entries] for good.
///
/// [CruxMotion.animatedValue]'s shared spring has a nominal 200ms
/// duration; this pads that by a small margin so the exit has visibly
/// settled by the time the entry is actually removed, the same "un-tuned
/// but reasonable, revisit on a device" spirit motion.dart's own shake
/// constants use for a similar approximation.
const Duration _exitAnimationDuration = Duration(milliseconds: 220);

/// The fraction of a toast card's own width a horizontal swipe must cross
/// before it counts as a dismiss (self-decided, plan's "しきい値...は自分で
/// 決めて記録"): a percentage-of-width threshold scales with message length
/// (a short "OK" toast and a long sentence both need "about 40% of my own
/// width" rather than a fixed pixel count that would feel too easy on a
/// wide card and too hard on a narrow one).
const double _swipeDismissWidthFraction = 0.4;

/// The release velocity (logical pixels/second along the drag axis) that
/// counts as a dismiss on its own, even if [_swipeDismissWidthFraction]
/// wasn't crossed (self-decided): lets a fast flick dismiss a toast that's
/// released early, matching the common "flick away" gesture apps like Mail
/// use for swipe-to-dismiss notifications.
const double _swipeDismissVelocity = 800;

/// The vertical gap between stacked toast cards, matching the mock's
/// `.toast-stack { gap: 10px }` (`unknowns/atoms-batch-3/mock-b-shadow.html`).
const double _stackGap = 10;

/// The gap kept clear below the lowest (frontmost) toast card and the
/// bottom of [CruxToastHost]'s bounds, matching the mock's
/// `.toast-stack { bottom: 28px }`.
const double _stackBottomInset = 28;

/// The gap kept clear on both sides of the toast stack.
///
/// The mock instead caps each toast's own width at `86vw` (a
/// screen-relative bound). A fixed inset here achieves the same "never
/// touches the screen edges" outcome without needing a [LayoutBuilder] at
/// the stack level -- [_cardMaxWidth] (see its own doc) is what actually
/// keeps [CruxToastCard] safe to render in an unbounded-width context, so
/// this only needs to add breathing room on a real, bounded screen.
const double _stackHorizontalInset = 24;

/// A [CruxToastCard]'s own maximum content width.
///
/// `Row`'s [Flexible]-wrapped message [Text] (below) requires a *bounded*
/// incoming width constraint -- a `Row` with a non-zero-flex child throws if
/// its own incoming width is unbounded (`double.infinity`), which is exactly
/// the ambient constraint an unwrapped [Center]/[Directionality]-only
/// context (the kind a golden-test harness or a bare preview might use)
/// hands down. Capping the card's own width here, rather than relying on
/// whatever ancestor happens to wrap it, is what makes [CruxToastCard]
/// safe to render standalone with *no* bounding ancestor at all -- the
/// explicit "must be paintable entirely on its own" requirement this class's
/// own doc describes. 320 logical pixels comfortably fits a phone-width
/// screen with [_stackHorizontalInset] margins on each side while still
/// reading as a compact, phone-sized notification rather than one that
/// spans a tablet's full width.
const double _cardMaxWidth = 320;

/// A [CruxToastCard]'s horizontal content padding, matching the mock's
/// `.toast-card { padding: 12px 18px }` (the `12px` is
/// [CruxSpacing.s12], used directly below; `18px` has no matching value in
/// [CruxSpacing]'s scale, so it is kept as its own constant here --
/// mirrors how `checkbox.dart`'s `_boxSize`/`_boxCornerRadius` keep
/// off-scale measurements as their own private constants).
const double _cardHorizontalPadding = 18;

/// A [CruxToastCard]'s vertical content padding when it has a
/// [CruxToastAction] (2026-08-02: "アクション付きトーストの高さも64pxに"): `9`, not
/// [CruxSpacing.s12] (`12`), so the card's total rendered height comes out
/// to exactly `64` -- the same height a plain, two-line toast already uses
/// -- regardless of whether [CruxToastCard.message] itself wraps to 1 or 2
/// lines.
///
/// The action button's own [_minTapTarget] (44) genuinely forces the card's
/// content [Row] to that same 44px cross-axis height (unlike the shorter,
/// 40px-visible/44px-tap-target split [CruxSegmentedControl] uses for its
/// own pill -- see this constant's own doc below for why that split doesn't
/// carry over here), so the padding is what has to give: `9 * 2 + 44 = 62`,
/// not `64`, is *not* a bug -- see the next paragraph for the extra `+1`
/// that closes the gap.
///
/// [Container] silently adds its [ShapeDecoration]'s own border inset into
/// its *effective* padding (`Container._paddingIncludingDecoration`, in
/// Flutter's own `container.dart`: `padding!.add(decoration!.padding)`,
/// where `ShapeDecoration.padding` forwards to `shape.dimensions`, and
/// `OutlinedBorder.dimensions` is `EdgeInsets.all(side.strokeInset)`) --
/// [CruxToastCard]'s own `RoundedSuperellipseBorder`'s `side` carries a
/// default 1px [BorderSide.width], so the card's *rendered* padding is
/// always exactly 1px more per edge than whatever vertical padding value is
/// used here or in [CruxSpacing.s12] above (confirmed empirically: a
/// plain, one-line toast declares `12` but measures `13` per edge, `46` --
/// not `44` -- tall overall; this is pre-existing behavior, unrelated to
/// this constant, and is left exactly as-is). Declaring `9` here therefore
/// renders as `10` per edge, giving `10 + 44 + 10 = 64` -- the actual,
/// on-screen target -- not the naively-expected `9 + 44 + 9 = 62`.
///
/// **Why not the same 40px-visible/44px-tap-target split
/// [CruxSegmentedControl] uses?** That approach -- an [OverflowBox]
/// reporting a smaller size than its child so the visible pill can be
/// shorter than the real tap target -- was tried first here and found not
/// to work for this card: [OverflowBox] (like every [RenderBox] that
/// doesn't override `hitTest`) still gates hit-testing by *its own*
/// reported size before ever recursing into its (larger) child -- confirmed
/// empirically, including that [CruxSegmentedControl]'s own equivalent
/// edge-tap test only passes because its bare-`Directionality` test wrapper
/// hands the whole control a tight-to-viewport (hundreds of pixels) ambient
/// height, not because the trick genuinely survives a properly
/// shrink-wrapped ~40px pill. [CruxToastCard] renders inside a genuinely
/// unbounded-height [Column] in production ([CruxToastHost]'s own toast
/// stack), where that gap would matter, so this card instead keeps the
/// action button's real, always-hit-testable 44px [ConstrainedBox] exactly
/// as it already was, and absorbs the height difference in the padding
/// instead -- no overflow trick, no split between what's visible and what's
/// tappable.
const double _cardVerticalPaddingWithAction = 9;

/// How far, in logical pixels, a [CruxToastCard] travels vertically while
/// entering (rising up into place) or leaving (sinking back down),
/// matching the mock's `toast-in`/`toast-out` keyframes' `translateY`.
const double _cardEnterTravel = 28;

/// Bundles a [CruxToastCard]'s single optional action button: a label and
/// the callback it invokes when tapped.
///
/// A dedicated class (rather than two separate nullable `actionLabel`/
/// `onAction` parameters) so a caller can never end up in the ambiguous
/// state of supplying only one of the two -- pass `action: null` for no
/// action at all, or a fully-formed [CruxToastAction] for one.
@immutable
class CruxToastAction {
  /// Creates a toast action.
  const CruxToastAction({required this.label, required this.onPressed});

  /// The action button's text (for example "元に戻す"). Caller-supplied --
  /// this package draws no conclusions about what a toast's action should
  /// say (H1: wording is never decided by this package).
  final String label;

  /// Called when the action button is tapped.
  ///
  /// [CruxToastHost] also dismisses the toast immediately once this is
  /// invoked (see [CruxToastHost]'s class doc): once a caller has acted on
  /// a notification, there is no reason to keep showing it.
  ///
  /// That immediate dismiss runs right after this callback returns, so if
  /// [onPressed] itself calls `showCruxToast` with the *same* [message]
  /// (for example to show a confirmation reusing the original wording), the
  /// dismiss will tear that freshly re-shown toast right back down again.
  /// Use distinct wording for a post-action confirmation if it needs to
  /// actually stay visible.
  final VoidCallback onPressed;
}

/// The static, unfloated body of a single Crux toast: a message, an
/// optional caller-supplied leading widget, and an optional single
/// [CruxToastAction] -- Crux UI's notification-card atom.
///
/// ```dart
/// CruxToastCard(
///   message: '同期が完了しました',
///   action: CruxToastAction(label: '元に戻す', onPressed: () {}),
/// )
/// ```
///
/// This widget renders only the card itself: no position, no stacking, no
/// entrance/exit motion, no auto-dismiss timer, and no swipe gesture --
/// those all belong to [CruxToastHost]/[showCruxToast], which build a
/// [CruxToastCard] internally for each visible toast. This split exists so
/// the card body can be rendered on its own, at rest, wherever a "what does
/// a toast look like" preview is needed (for example a golden test) without
/// dragging in [CruxToastHost]'s stacking/timer machinery.
///
/// [message] and [leading] follow H1 (`unknowns/session-handoff-2026-07-26.
/// md`): wording and iconography are always caller-supplied, never decided
/// by this package. [leading] is rendered exactly as given -- unlike
/// [CruxIconButton]'s `icon`, it is not wrapped in an [IconTheme]/
/// [DefaultTextStyle] override, since a toast has no enabled/disabled
/// foreground state for it to resolve against; a caller that wants a
/// specific tint (for example a green checkmark for a success toast, as in
/// the design mock) sets it directly on the widget it passes.
///
/// Renders as a [CruxColors.surface] card with [CruxRadii.l] superellipse
/// corners, [CruxShadows.md]'s shadow, and a 1px border in
/// [CruxShadows.hairline] -- painted unconditionally on every theme.
/// [CruxShadows.hairline] is fully transparent in the light palette and a
/// faint [CruxColors.textPrimary] wash in the dark one, so this single,
/// always-on border reproduces the mock's "no border in light, a hairline
/// outline in dark" result without a brightness-specific branch (matching
/// how [CruxShadows.hairline]'s own doc describes this exact technique).
///
/// Exposes a live-region semantics node ([Semantics.liveRegion]) so a screen
/// reader announces the card's content as soon as it appears -- see
/// [CruxToastHost]'s class doc for the full read-aloud design.
class CruxToastCard extends StatelessWidget {
  /// Creates a Crux toast card.
  const CruxToastCard({
    super.key,
    required this.message,
    this.leading,
    this.action,
    this.onDismiss,
  });

  /// The toast's text. Caller-supplied (H1).
  final String message;

  /// An optional leading widget (typically a small icon), rendered before
  /// [message]. Caller-supplied and rendered as-is (H1) -- see this class's
  /// own doc for why it is not re-themed.
  final Widget? leading;

  /// An optional single action button, rendered after [message]. Leave
  /// `null` for a plain, non-actionable toast.
  final CruxToastAction? action;

  /// Wired to the card's [Semantics.onDismiss], giving assistive technology
  /// (which typically reserves a horizontal swipe for its own navigation
  /// gesture, not this card's swipe-to-dismiss drag) an equivalent way to
  /// dismiss the toast -- the same [SemanticsAction.dismiss] wiring
  /// Flutter's own `Dismissible`/`SnackBar` expose (confirmed against
  /// `packages/flutter/lib/src/material/snack_bar.dart`'s `Semantics(...,
  /// onDismiss: ...)` wrapping its `Dismissible`).
  ///
  /// Left `null` (the default) for a card rendered on its own with no
  /// [CruxToastHost] to dismiss it into -- [CruxToastHost] always
  /// supplies this when it builds a [CruxToastCard] for a live entry.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxToastAction? toastAction = action;

    return Semantics(
      container: true,
      liveRegion: true,
      onDismiss: onDismiss,
      child: ConstrainedBox(
        // See _cardMaxWidth's own doc: this is what makes the card safe to
        // lay out even with no bounded-width ancestor at all.
        constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _cardHorizontalPadding,
            // See _cardVerticalPaddingWithAction's own doc: an action
            // button's real 44px minimum tap target already forces the row
            // this padding wraps to that same 44px height, so keeping the
            // ordinary CruxSpacing.s12 (12) here -- the same value a
            // plain, no-action toast still uses -- would push an
            // action-equipped card past the 64px every other toast height
            // uses.
            vertical: toastAction != null
                ? _cardVerticalPaddingWithAction
                : CruxSpacing.s12,
          ),
          decoration: ShapeDecoration(
            color: colors.surface,
            shadows: theme.shadows.md,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(CruxRadii.l),
              side: BorderSide(color: theme.shadows.hairline),
            ),
          ),
          // Establishes this card's own DefaultTextStyle baseline -- the
          // same "a subtree floating outside Material resets its own
          // ambient text style" fix dialog.dart's CruxDialogCard.build
          // makes (see that method's own comment for the full "why", H3:
          // never inherit an ambient Material theme). [CruxToastHost]
          // stacks this card as an ordinary Stack sibling outside any
          // Material widget, so without this, [message]'s Text and
          // [_CruxToastActionButton]'s label (neither of which sets its
          // own `decoration` -- see typography.dart) would inherit whatever
          // `DefaultTextStyle` happens to sit above the host, including
          // MaterialApp's garish "no enclosing Material" warning style.
          //
          // Deliberately narrower than [CruxDialogCard]'s equivalent
          // baseline: only `decoration` is set here, `color`/`fontSize`/
          // `height`/`fontWeight` are all left unset (`null`), rather than
          // also basing this on `theme.typography.body` the way the dialog
          // card does. [leading] sits inside this same DefaultTextStyle
          // scope -- there is no narrower place to put it that still covers
          // [message] and the action label -- and [leading]'s own class doc
          // promises it is "rendered exactly as given ... not wrapped in an
          // IconTheme/DefaultTextStyle override": a caller-supplied Text
          // used as [leading] with no style of its own (this file's own
          // widgetbook use case does exactly this) must keep whatever
          // font size/color it would have had with no ambient override at
          // all, so only the one field actually responsible for this bug
          // is forced here. `TextStyle.merge`'s per-field semantics (a
          // descendant Text's own explicit fields always win; only fields
          // it leaves `null` fall back to this ambient style) mean this is
          // still enough to fix [message] and the action label, both of
          // which already set every other field themselves.
          child: DefaultTextStyle(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: CruxSpacing.s8),
                ],
                Flexible(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.label.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (toastAction != null) ...<Widget>[
                  const SizedBox(width: CruxSpacing.s8),
                  _CruxToastActionButton(
                    label: toastAction.label,
                    onPressed: toastAction.onPressed,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single toast's action button: a hand-rolled, [PressFeedbackController]
/// -driven text button in [CruxColors.accent], the same "compact,
/// non-pill pressable" shape [CruxIconButton]/`CruxInputBar`'s submit
/// button already use rather than embedding a full [CruxButton] -- see
/// [CruxToastCard]'s (well, this file's) top-of-file architecture note for
/// the full atom-vs-molecule reasoning.
class _CruxToastActionButton extends StatefulWidget {
  const _CruxToastActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_CruxToastActionButton> createState() =>
      _CruxToastActionButtonState();
}

class _CruxToastActionButtonState extends State<_CruxToastActionButton> {
  bool _pressed = false;

  // Same PressFeedbackController wiring CruxButton/CruxIconButton use;
  // see press_feedback.dart's class doc for the fast-tap bug this guards
  // against.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  void _handleTapDown(TapDownDetails details) => _pressFeedback.down();
  void _handleTapUp(TapUpDetails details) => _pressFeedback.up();
  void _handleTapCancel() => _pressFeedback.cancel();

  @override
  void dispose() {
    _pressFeedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);

    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: CruxMotion.scale(
          value: _pressed ? CruxMotion.pressedScale : 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.label.copyWith(
                  color: theme.colors.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tracked toast: [CruxToastHost]'s private stack-entry model.
///
/// [id] is a monotonically increasing counter assigned at creation, used
/// only as a stable [ValueKey] for the [_ToastItem] built from this entry
/// (so Flutter's widget reconciliation follows the *same* toast across
/// reorders instead of rebuilding a fresh one, which would restart its
/// entrance animation on every reposition).
class _ToastEntry {
  _ToastEntry({
    required this.id,
    required this.message,
    required this.theme,
    this.leading,
    this.action,
  });

  final int id;
  final String message;
  final Widget? leading;
  final CruxToastAction? action;

  /// The [CruxThemeData] captured from [showCruxToast]'s caller-side
  /// `context` at show time -- see [CruxToastHost]'s class doc ("Theming")
  /// for why this entry carries its own theme snapshot instead of the card
  /// resolving [CruxTheme.of] fresh from wherever [CruxToastHost] itself
  /// sits. Re-captured (not just set once) on a duplicate re-show (see
  /// [_CruxToastHostState.show]), so a caller whose local theme changed
  /// between two shows of the same message is reflected on the next show.
  CruxThemeData theme;

  /// Bumped by exactly 1 every time a duplicate [message] is shown while
  /// this entry is still active -- fed straight to [CruxMotion.shake]'s
  /// `trigger`, which plays a new shake each time this changes.
  int shakeTrigger = 0;

  /// Whether this entry is playing its exit animation. Once `true`, this
  /// entry no longer counts toward [_maxToasts] or duplicate matching (see
  /// [_CruxToastHostState.show]), and [exitTimer] is already scheduled to
  /// splice it out of the entry list for good.
  ///
  /// Excluding a leaving entry from duplicate matching is deliberate, not an
  /// oversight: an entry already mid-exit is visually distinct (fading and
  /// shrinking away), so re-showing the same [message] while it is still
  /// leaving starts a brand-new entry rather than reaching into the old one
  /// and reversing its exit mid-flight. The accepted tradeoff is that both
  /// cards can be on screen at once, bearing identical text, for up to
  /// [_exitAnimationDuration] (about 220ms) until the old one finishes
  /// leaving.
  bool leaving = false;

  /// The pending auto-dismiss timer, scheduled by
  /// [_CruxToastHostState._scheduleDismiss] and canceled/rescheduled on a
  /// duplicate show or a manual dismiss.
  Timer? dismissTimer;

  /// The pending "actually remove this entry" timer, scheduled once
  /// [leaving] flips to `true` -- see [_exitAnimationDuration]'s doc.
  Timer? exitTimer;
}

/// Makes the [_CruxToastHostState] that owns a [CruxToastHost] subtree
/// reachable from [showCruxToast], without exposing that state (or any
/// mutable controller type) as public API.
///
/// [updateShouldNotify] always returns `false`: this scope exists purely as
/// a lookup mechanism for [showCruxToast] (via
/// [BuildContext.getInheritedWidgetOfExactType], a non-dependent lookup that
/// registers no rebuild dependency -- appropriate since [showCruxToast] is
/// normally called from an event handler, not from a `build` method), never
/// as something a descendant's `build` should *depend on* and rebuild in
/// response to; the toast stack's own visible content changes are instead
/// driven entirely by ordinary `setState` calls inside
/// [_CruxToastHostState] itself.
class _CruxToastScope extends InheritedWidget {
  const _CruxToastScope({required this.state, required super.child});

  final _CruxToastHostState state;

  @override
  bool updateShouldNotify(_CruxToastScope oldWidget) => false;
}

/// Hosts a stack of up to [_maxToasts] Crux toasts, shown via
/// [showCruxToast], above [child] -- Crux UI's notification-stack atom.
///
/// ```dart
/// CruxToastHost(
///   child: MyApp(), // or WidgetsApp.builder's returned subtree
/// )
/// ```
///
/// Wrap this near the root of an app (or a screen) once; any descendant can
/// then call `showCruxToast(context, message: '...')` to show a toast on
/// top of everything [child] contains. [CruxToastHost] renders the toast
/// stack as an ordinary widget-tree layer -- a [Stack] with [child] as its
/// base and the toast column painted above it -- rather than by inserting
/// [OverlayEntry]s into an ambient [Overlay]. This is a deliberate choice,
/// distinct from how a one-shot, imperatively-pushed-and-later-popped
/// overlay (for example a dialog) is usually built: a raw [Overlay]'s
/// `initialEntries` list is only ever read once, at that [Overlay]'s own
/// first build (`unknowns/session-handoff-2026-07-26.md`'s Overlay
/// pitfalls); wrapping [child] in an [OverlayEntry]'s `builder` would freeze
/// it against whatever [child] this [CruxToastHost] is rebuilt with later
/// (for example a different screen after navigation), never updating again.
/// A toast, unlike a dialog, is not an imperative one-off push/pop -- it is
/// an ordinary, declaratively-rebuilt list of active toasts -- so a plain
/// [Stack] (where [child] stays a completely normal, always-correctly
/// -updated widget-tree child) is both simpler and safer here. This also
/// means [CruxToastHost] needs no ambient [Overlay]/`Navigator` at all
/// (satisfying "must work under widgetbook's bare `WidgetsApp`, with no
/// Material `ScaffoldMessenger`/`SnackBar` involved"), while still nesting
/// safely *inside* one if a caller's app happens to have one (a bare
/// [Overlay] with no [Navigator] is enough to verify this from a test).
///
/// **Stacking and duplicates.** Toasts stack from the bottom, newest at the
/// bottom, oldest above it, at most [_maxToasts] at once -- showing a 4th
/// distinct message immediately starts dismissing the oldest currently
/// -active one. A card that is mid-dismiss (fading/shrinking out) is still
/// mounted for [_exitAnimationDuration], but is wrapped in [IgnorePointer]
/// for that whole window (see [_ToastItemState.build]) so it can no longer
/// be tapped -- without this, a caller could still reach a leaving card's
/// [CruxToastAction] button and re-invoke a non-idempotent [CruxToastAction
/// .onPressed] a second time on a toast already considered gone. Combined
/// active-and-leaving cards are additionally capped at [_maxRenderedTotal]
/// (see its own doc): a burst of distinct messages arriving faster than
/// [_exitAnimationDuration] can otherwise pile up more leaving cards than fit
/// on screen, so once the cap is hit the oldest leaving card is spliced out
/// immediately, skipping its exit animation. A toast is considered a
/// duplicate of an already-showing one
/// purely by [CruxToastCard.message] equality (not [CruxToastCard.
/// leading] or [CruxToastCard.action] -- self-decided: two toasts sharing
/// exact wording are the same notification in every case this package
/// anticipates, and comparing arbitrary caller-supplied [Widget]s for
/// meaningful equality would be unreliable). Showing a duplicate never stacks
/// a second card: the existing one plays [CruxMotion.shake] instead. If
/// that existing toast is buried (not the frontmost/newest one), it also
/// moves back to the front and its auto-dismiss timer restarts, giving the
/// caller a fresh window to read it again; if it is already frontmost, only
/// the shake plays and its timer is left alone (it was already about to be
/// read).
///
/// **Auto-dismiss.** A toast with no [CruxToastAction] auto-dismisses
/// after [_defaultDismissDuration] (about 3 seconds); one with an action
/// gets the longer [_actionDismissDuration] instead, so there is time to
/// notice and use the action before it disappears. Exception: while
/// `MediaQuery.accessibleNavigationOf` reports accessible navigation is on
/// (TalkBack/VoiceOver-style screen readers), an actioned toast is not
/// auto-dismissed at all -- it is held open until manually dismissed (the
/// action, a swipe, or [CruxToastCard]'s [Semantics.onDismiss] action). A
/// toast with no action keeps its normal [_defaultDismissDuration] regardless
/// of accessible navigation. See [_CruxToastHostState._scheduleDismiss]'s
/// own doc for the full reasoning, including how this compares against
/// Flutter's own `SnackBar` precedent.
///
/// **Swipe to dismiss.** Dragging a toast horizontally past
/// [_swipeDismissWidthFraction] of its own width, or releasing it past
/// [_swipeDismissVelocity], dismisses it immediately. While a drag is in
/// progress, the auto-dismiss timer is paused (not just left running
/// underneath the gesture) -- a toast held under a resting finger must not
/// start disappearing out from under it. Releasing without dismissing
/// restarts the timer from a fresh, full grace period, the same
/// "give the reader a full window" reset a buried duplicate's re-show
/// already uses, rather than resuming whatever fraction of the original
/// period happened to be left.
///
/// **Read-aloud design.** Each [CruxToastCard] sets [Semantics.liveRegion]
/// (see its own class doc), Crux's from-scratch equivalent of an
/// `aria-live="polite"` region (the mock's own `role="status"`/
/// `aria-live="polite"` markup, translated to Flutter's semantics tree): a
/// screen reader announces a toast's content as soon as it is mounted, with
/// no dependency on Material's `SnackBar`/`ScaffoldMessenger` (H3: this
/// package's actual constraint is never taking its *appearance* from an
/// ambient `ThemeData`, not "avoid every Material-adjacent concept" -- but
/// [SnackBar] itself is a Material widget, so it is not used here regardless).
/// A card also wires [CruxToastCard.onDismiss] to [Semantics.onDismiss],
/// the same way Flutter's own `SnackBar` wraps its `Dismissible` in
/// `Semantics(..., onDismiss: ...)`: a screen reader typically claims a plain
/// horizontal swipe for its own navigation gesture, so without this, a
/// screen-reader user would have no way to reproduce this card's
/// swipe-to-dismiss drag at all.
///
/// **Theming.** [showCruxToast] resolves [CruxTheme.of] against its
/// *caller's* `context` -- not [CruxToastHost]'s own -- at the moment it is
/// called, and that snapshot is what the resulting card renders with for as
/// long as it is shown (see [_ToastEntry.theme]'s own doc). This matters
/// because the toast stack itself is built as a [Stack] sibling of [child]
/// (per this class's own "Display mechanism" section above), not a
/// descendant of it -- a caller nested inside a screen-local [CruxTheme]
/// somewhere under [child] would otherwise have its toast card resolve
/// whatever [CruxTheme] (or the [CruxThemeData.light] fallback) happens
/// to be in scope above [CruxToastHost] instead, silently losing that
/// local theme. The accepted trade-off, recorded here for whoever revisits
/// it later (the same trade-off [CruxDialog] independently makes for the
/// same "floats outside the calling subtree" reason): a toast does not
/// follow a *later* theme switch made while it is already on screen -- if a
/// caller flips from light to dark after a toast is already showing, that
/// toast keeps rendering with whichever theme was active the moment it was
/// shown, until it is dismissed and a new one takes its place.
///
/// **Motion.** Every transform this widget (and the [_ToastItem]s it builds)
/// applies goes through [CruxMotion.animatedValue]/[CruxMotion.shake],
/// never a bare `AnimationController` or hand-rolled keyframe restart --
/// including a toast's live swipe-drag offset, which is fed into
/// [CruxMotion.animatedValue] on every drag update rather than tracked
/// with a raw, unsprung [Transform] (`CruxMotion.animatedValue`'s public
/// API -- the only sanctioned channel a component file may drive a `motor`
/// spring through -- has no "hold this value with no animation" escape
/// hatch to track a fast-moving finger exactly, since `motion.dart` is a
/// read-only token file for this change; the shared [_spring]'s snappy,
/// short duration keeps the resulting motion tight enough to still read as
/// attached to the finger).
class CruxToastHost extends StatefulWidget {
  /// Creates a Crux toast host.
  const CruxToastHost({super.key, required this.child});

  /// The content [CruxToastHost] stacks its toasts above.
  final Widget child;

  @override
  State<CruxToastHost> createState() => _CruxToastHostState();
}

class _CruxToastHostState extends State<CruxToastHost> {
  int _nextId = 0;
  final List<_ToastEntry> _entries = <_ToastEntry>[];

  /// Shows a toast, or -- if [message] matches an already-active one --
  /// shakes it (and, if it's buried, moves it to the front and resets its
  /// timer) instead. See [CruxToastHost]'s class doc for the full
  /// duplicate-handling design.
  ///
  /// [context] is the caller's own [showCruxToast] `context`, captured
  /// here (not read later from [CruxToastHost]'s own position in the tree)
  /// so the resulting card renders with whatever [CruxTheme] was actually
  /// active at the call site -- see this class's "Theming" doc section.
  void show({
    required BuildContext context,
    required String message,
    Widget? leading,
    CruxToastAction? action,
  }) {
    final CruxThemeData capturedTheme = CruxTheme.of(context);
    final int existingIndex = _entries.indexWhere(
      (_ToastEntry entry) => entry.message == message && !entry.leaving,
    );

    if (existingIndex != -1) {
      final _ToastEntry existing = _entries[existingIndex];
      final bool isFrontmost = existingIndex == 0;
      setState(() {
        existing.shakeTrigger++;
        existing.theme = capturedTheme;
        if (!isFrontmost) {
          _entries
            ..removeAt(existingIndex)
            ..insert(0, existing);
        }
      });
      if (!isFrontmost) {
        _scheduleDismiss(existing);
      }
      return;
    }

    final _ToastEntry entry = _ToastEntry(
      id: _nextId++,
      message: message,
      leading: leading,
      action: action,
      theme: capturedTheme,
    );
    setState(() => _entries.insert(0, entry));
    _scheduleDismiss(entry);
    _enforceMax();
    _enforceRenderCap();
  }

  /// Schedules (or reschedules) [entry]'s auto-dismiss timer, unless
  /// [entry] has an [CruxToastAction] *and* accessible navigation
  /// (`MediaQuery.accessibleNavigationOf`, TalkBack/VoiceOver-style screen
  /// readers) is on, in which case no timer is scheduled at all -- the toast
  /// is held open until manually dismissed.
  ///
  /// This mirrors Flutter's own `SnackBar`, confirmed against
  /// `packages/flutter/lib/src/material/snack_bar.dart` (`SnackBar.persist`,
  /// defaulting to `action != null`) and `.../material/scaffold.dart`
  /// (`ScaffoldMessengerState`'s auto-hide timer callback: `if (snackBar.
  /// persist) { return; }`, i.e. it never schedules a hide once a
  /// `SnackBar` has an action) plus `packages/flutter/test/material/
  /// snack_bar_test.dart`'s `'accessible navigation behavior with action'`
  /// and `'SnackBar handles updates to accessibleNavigation'` cases, which
  /// together show the *current* stable-channel behavior is: an actioned
  /// `SnackBar` never auto-hides by default, independent of whether
  /// accessible navigation is actually on. This package makes the narrower,
  /// self-decided choice of only holding an actioned toast open while
  /// accessible navigation is actually on (rather than unconditionally
  /// whenever an action exists): [_actionDismissDuration]'s existing ~6s
  /// grace period is already deliberately long for a sighted user with a
  /// pointer (see its own doc), and holding it open forever for every
  /// actioned toast, even outside assistive contexts, would leave a caller
  /// with no way to get the default auto-dismiss behavior back short of
  /// dropping the action entirely.
  ///
  /// A toast with no action is scheduled the same way regardless of
  /// accessible navigation, again matching `SnackBar`: `persist` there
  /// defaults to `false` whenever there is no action, so a plain `SnackBar`
  /// keeps timing out under accessible navigation too -- there is no action
  /// to still be reaching for, so holding it open indefinitely would only
  /// leave a stale, unreachable-by-swipe (see [CruxToastCard.onDismiss])
  /// notification sitting on screen.
  void _scheduleDismiss(_ToastEntry entry) {
    entry.dismissTimer?.cancel();
    entry.dismissTimer = null;
    final bool accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    if (entry.action != null && accessibleNavigation) {
      return;
    }
    entry.dismissTimer = Timer(
      entry.action != null ? _actionDismissDuration : _defaultDismissDuration,
      () => _dismiss(entry),
    );
  }

  void _enforceMax() {
    final List<_ToastEntry> active = _entries
        .where((_ToastEntry entry) => !entry.leaving)
        .toList();
    if (active.length > _maxToasts) {
      // _entries is newest-first, so the last active entry is the oldest.
      _dismiss(active.last);
    }
  }

  /// Enforces [_maxRenderedTotal] (see its own doc): while [_entries] holds
  /// more entries than that -- active and leaving combined -- immediately
  /// (no exit animation) splices out the oldest still-[_ToastEntry.leaving]
  /// entry, repeating until back at the cap.
  ///
  /// [_entries] is newest-first (see [_buildStackChildren]'s own comment),
  /// so, exactly like [_enforceMax]'s `active.last`, the oldest leaving entry
  /// is the last one found scanning from the end. Only ever removes a
  /// *leaving* entry, never an active one -- [_maxToasts] already caps
  /// active entries at 3, comfortably under [_maxRenderedTotal], so an
  /// active entry is never the thing pushing the total over the cap.
  void _enforceRenderCap() {
    while (_entries.length > _maxRenderedTotal) {
      _ToastEntry? oldestLeaving;
      for (int i = _entries.length - 1; i >= 0; i--) {
        if (_entries[i].leaving) {
          oldestLeaving = _entries[i];
          break;
        }
      }
      if (oldestLeaving == null) {
        break;
      }
      oldestLeaving.dismissTimer?.cancel();
      oldestLeaving.exitTimer?.cancel();
      final _ToastEntry toRemove = oldestLeaving;
      setState(() => _entries.remove(toRemove));
    }
  }

  /// Starts (or, if already leaving, no-ops) an entry's exit: cancels its
  /// pending auto-dismiss, marks it [_ToastEntry.leaving] (which drives
  /// [_ToastItem]'s fade/shrink-down exit), then physically removes it from
  /// [_entries] after [_exitAnimationDuration].
  void _dismiss(_ToastEntry entry) {
    if (entry.leaving) {
      return;
    }
    entry.dismissTimer?.cancel();
    setState(() => entry.leaving = true);
    entry.exitTimer = Timer(_exitAnimationDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _entries.remove(entry));
    });
  }

  @override
  void dispose() {
    for (final _ToastEntry entry in _entries) {
      entry.dismissTimer?.cancel();
      entry.exitTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CruxToastScope(
      state: this,
      child: Stack(
        children: <Widget>[
          widget.child,
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: _stackBottomInset,
                  left: _stackHorizontalInset,
                  right: _stackHorizontalInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildStackChildren(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the visible toast column: oldest first (top), newest last
  /// (bottom) -- [_entries] itself is stored newest-first, so this reverses
  /// it, matching the mock's "stack from the bottom, newest at the bottom"
  /// layout.
  List<Widget> _buildStackChildren() {
    final List<_ToastEntry> visualOrder = _entries.reversed.toList();
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < visualOrder.length; i++) {
      if (i > 0) {
        children.add(const SizedBox(height: _stackGap));
      }
      final _ToastEntry entry = visualOrder[i];
      children.add(
        _ToastItem(
          key: ValueKey<int>(entry.id),
          entry: entry,
          onDismiss: () => _dismiss(entry),
          onDragStart: () => entry.dismissTimer?.cancel(),
          onDragEnd: () => _scheduleDismiss(entry),
        ),
      );
    }
    return children;
  }
}

/// Renders one [_ToastEntry] as a positioned, animated [CruxToastCard]:
/// the entrance/exit spring, the duplicate shake, and the swipe-to-dismiss
/// drag gesture all live here -- [_CruxToastHostState] only owns *which*
/// entries exist and in what order.
class _ToastItem extends StatefulWidget {
  const _ToastItem({
    super.key,
    required this.entry,
    required this.onDismiss,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final _ToastEntry entry;
  final VoidCallback onDismiss;

  /// Called as soon as a horizontal drag on this card is recognized --
  /// pauses [_ToastEntry.dismissTimer] for the duration of the drag (see
  /// this file's "dragging pauses the auto-dismiss timer" behavior, guarding
  /// against a toast starting to auto-dismiss while a finger is still
  /// resting on it, mid-swipe-that-never-completes).
  final VoidCallback onDragStart;

  /// Called when a horizontal drag ends *without* triggering [onDismiss] --
  /// reschedules the auto-dismiss timer from a fresh, full grace period
  /// (never a leftover remaining duration), matching the same "give the
  /// reader a full fresh window" reset [CruxToastHost]'s duplicate-show
  /// handling already uses.
  final VoidCallback onDragEnd;

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem> {
  // Starts at 0 (hidden/collapsed) and flips to 1 one frame after the first
  // build -- see the addPostFrameCallback below for why a *later* frame's
  // value change (rather than this widget's very first build already
  // targeting 1.0) is what makes CruxMotion.animatedValue actually play
  // an entrance animation instead of snapping straight to rest.
  double _entrancePresence = 0;

  // The live, raw (unsprung target *value fed into* the spring, not a
  // sprung render value itself) horizontal drag offset -- see
  // CruxToastHost's "Motion" doc section for why this is still routed
  // through CruxMotion.animatedValue rather than a bare Transform.
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        setState(() => _entrancePresence = 1);
      }
    });
  }

  /// The entrance/exit spring's current target: 0 (hidden) once
  /// [_ToastEntry.leaving] is set, regardless of how far
  /// [_entrancePresence]'s own entrance flight had gotten -- changing an
  /// already-mounted [CruxMotion.animatedValue]'s `value` mid-flight
  /// continues smoothly from wherever it currently is (see motion.dart's
  /// own doc), so a toast dismissed mid-entrance reverses cleanly rather
  /// than jumping.
  double get _presence => widget.entry.leaving ? 0 : _entrancePresence;

  void _handleAction() {
    final CruxToastAction? action = widget.entry.action;
    if (action == null) {
      return;
    }
    action.onPressed();
    widget.onDismiss();
  }

  void _handleDragStart(DragStartDetails details) {
    if (widget.entry.leaving) {
      return;
    }
    widget.onDragStart();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.entry.leaving) {
      return;
    }
    setState(() => _dragDx += details.delta.dx);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.entry.leaving) {
      return;
    }
    final double width = context.size?.width ?? 0;
    final double velocity = details.primaryVelocity ?? 0;
    final bool shouldDismiss =
        (width > 0 && _dragDx.abs() > width * _swipeDismissWidthFraction) ||
        velocity.abs() > _swipeDismissVelocity;
    if (shouldDismiss) {
      widget.onDismiss();
    } else {
      setState(() => _dragDx = 0);
      widget.onDragEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final CruxToastAction? entryAction = widget.entry.action;

    Widget card = CruxToastCard(
      message: widget.entry.message,
      leading: widget.entry.leading,
      action: entryAction == null
          ? null
          : CruxToastAction(
              label: entryAction.label,
              onPressed: _handleAction,
            ),
      // See CruxToastCard.onDismiss's own doc: the semantics-only
      // equivalent of this card's swipe-to-dismiss drag gesture.
      onDismiss: widget.onDismiss,
    );

    // Captured at showCruxToast's call site, not resolved fresh here --
    // see CruxToastHost's "Theming" class-doc section and _ToastEntry.
    // theme's own doc for why.
    card = CruxTheme(data: widget.entry.theme, child: card);

    card = CruxMotion.shake(
      trigger: widget.entry.shakeTrigger,
      reduceMotion: reduceMotion,
      child: card,
    );

    card = CruxMotion.animatedValue(
      value: _dragDx,
      builder: (BuildContext context, double dx, Widget? child) {
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: card,
    );

    card = CruxMotion.animatedValue(
      value: _presence,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * _cardEnterTravel),
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
        );
      },
      child: card,
    );

    // A leaving card is on its way off screen (fading/shrinking via the
    // _presence spring above) -- it must not keep accepting taps in the
    // meantime, or a non-idempotent CruxToastAction.onPressed (or the
    // Semantics dismiss action) could fire a second time on a card the
    // caller already considers dismissed (codex review finding).
    // Positioned above the swipe GestureDetector below, not inside it: an
    // opaque GestureDetector's own hit test still adds itself even when
    // every descendant is ignored (HitTestBehavior.opaque's hitTestSelf
    // always returns true), so the outer swipe recognizer stays wired up as
    // normal -- its own handlers already no-op while leaving (see
    // _handleDragStart/_handleDragUpdate/_handleDragEnd above) -- while
    // IgnorePointer(ignoring: true) still fully blocks the action button (or
    // any future interactive content inside CruxToastCard) underneath it.
    card = IgnorePointer(ignoring: widget.entry.leaving, child: card);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: card,
    );
  }
}

/// Shows a toast on the nearest ancestor [CruxToastHost] -- see
/// [CruxToastHost]'s class doc for stacking, duplicate, auto-dismiss, and
/// swipe behavior.
///
/// ```dart
/// showCruxToast(context, message: '同期が完了しました');
/// ```
///
/// [context] must have a [CruxToastHost] ancestor (an assertion fails in
/// debug mode otherwise -- wrap your app, or the relevant screen, in one).
/// [message] and [leading] are caller-supplied (H1); pass [action] for a
/// single action button, or leave it `null` for a plain toast.
///
/// [context]'s own [CruxTheme] (or [CruxThemeData.light] if none is in
/// scope) is captured right here, at call time, and used to render the
/// resulting card -- see [CruxToastHost]'s "Theming" class-doc section for
/// why, and its accepted trade-off.
///
/// If you call this after an `await` (for example once a network request or
/// other asynchronous operation finishes), check `context.mounted` first.
/// A [context] whose widget has since been unmounted throws Flutter's
/// "Looking up a deactivated widget's ancestor is unsafe" error here, the
/// same as it would for any other ancestor lookup performed on a stale
/// context after an async gap.
void showCruxToast(
  BuildContext context, {
  required String message,
  Widget? leading,
  CruxToastAction? action,
}) {
  final _CruxToastScope? scope = context
      .getInheritedWidgetOfExactType<_CruxToastScope>();
  assert(
    scope != null,
    'showCruxToast(context, ...) requires a CruxToastHost ancestor. '
    'Wrap your app (or the relevant screen) in a CruxToastHost.',
  );
  scope?.state.show(
    context: context,
    message: message,
    leading: leading,
    action: action,
  );
}
