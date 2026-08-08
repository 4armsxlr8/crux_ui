import 'dart:async';

import 'package:flutter/foundation.dart';

/// The minimum time a press's visual "pressed" state is held, even if the
/// underlying gesture's down and up arrive back-to-back with no frame
/// rendered in between.
///
/// Inside a scrollable list, Flutter's `TapGestureRecognizer` frequently
/// resolves the gesture arena and delivers `onTapDown` immediately followed
/// by `onTapUp` -- a naive `_pressed = true` then `_pressed = false`
/// collapses to a no-op before any frame ever paints the pressed state, so
/// a fast tap shows no press feedback at all. 80ms is long enough that the
/// press spring has moved measurably away from rest by the time it's
/// sampled, short enough not to perceptibly delay release.
const Duration kMinimumPressFeedbackDuration = Duration(milliseconds: 80);

/// A tiny state machine that guarantees a pressable Crux UI atom's visual
/// "pressed" state stays on screen for at least [minimumHoldDuration] once
/// it starts, even if the underlying gesture releases (or cancels)
/// immediately after -- see [kMinimumPressFeedbackDuration]'s doc for the
/// bug this fixes.
///
/// A [State] wires [down]/[up]/[cancel] to its `GestureDetector`'s
/// `onTapDown`/`onTapUp`/`onTapCancel`, passing an [onChanged] callback that
/// mirrors [pressed] into its own pressed field via `setState`, and calls
/// [dispose] from its own `dispose()` so a guarantee timer scheduled by
/// [down] can never fire after the widget has been torn down. This class
/// never touches `BuildContext`, `Widget`, or `setState` itself.
///
/// Deliberately not wired into `CruxSwitch`: its thumb's liquid-travel
/// flight already makes a fast tap visibly respond, so the switch keeps
/// its own inline pressed state
/// (see unknowns/atoms-batch-1/implementation-notes.md).
class PressFeedbackController {
  /// Creates a press feedback controller. [onChanged] is called
  /// synchronously, from inside [down]/[up]/[cancel] or from a [Timer]
  /// callback, whenever [pressed] flips.
  PressFeedbackController({
    required this.onChanged,
    this.minimumHoldDuration = kMinimumPressFeedbackDuration,
  });

  /// Called synchronously whenever [pressed] flips, so the owning [State]
  /// can mirror it into its own state via `setState`.
  final ValueChanged<bool> onChanged;

  /// How long [pressed] is guaranteed to stay `true` once [down] starts it,
  /// even if [up] or [cancel] arrives sooner. Defaults to
  /// [kMinimumPressFeedbackDuration].
  final Duration minimumHoldDuration;

  /// The current guaranteed-visible pressed state.
  ///
  /// This is not simply the raw "is a finger currently down" signal: once
  /// [down] sets it `true`, it keeps reading `true` until at least
  /// [minimumHoldDuration] has elapsed, even if [up]/[cancel] was called
  /// well before that -- see the class doc.
  bool get pressed => _pressed;
  bool _pressed = false;

  Timer? _minimumHoldTimer;
  bool _minimumHoldElapsed = false;
  bool _releasePending = false;

  /// Starts (or restarts) a press.
  ///
  /// Safe to call again while a previous press's minimum-hold guarantee is
  /// still pending (e.g. a fast repeat tap): the stale timer is canceled
  /// and a fresh guarantee window starts from now. [pressed] simply stays
  /// `true` across the join -- it was already `true` -- so [onChanged] is
  /// not called again.
  void down() {
    _minimumHoldTimer?.cancel();
    _minimumHoldTimer = Timer(minimumHoldDuration, _handleMinimumHoldElapsed);
    _minimumHoldElapsed = false;
    _releasePending = false;
    if (!_pressed) {
      _pressed = true;
      onChanged(true);
    }
  }

  /// Ends the current press (mirrors `onTapUp`).
  ///
  /// If [minimumHoldDuration] has already elapsed since [down], [pressed]
  /// resolves back to `false` immediately. Otherwise the release is
  /// deferred until the guarantee window elapses, so the pressed state was
  /// visible on screen for at least that long.
  void up() => _requestRelease();

  /// Cancels the current press (mirrors `onTapCancel`).
  ///
  /// Resolves the same way [up] does: it's the *visual* pressed state that
  /// is guaranteed a minimum lifetime, regardless of whether the gesture
  /// underneath it ended in a tap or a cancel.
  void cancel() => _requestRelease();

  void _requestRelease() {
    if (!_pressed) {
      return;
    }
    if (_minimumHoldElapsed) {
      _resolveRelease();
    } else {
      _releasePending = true;
    }
  }

  void _handleMinimumHoldElapsed() {
    _minimumHoldTimer = null;
    _minimumHoldElapsed = true;
    if (_releasePending) {
      _resolveRelease();
    }
  }

  void _resolveRelease() {
    _releasePending = false;
    _minimumHoldElapsed = false;
    if (_pressed) {
      _pressed = false;
      onChanged(false);
    }
  }

  /// Cancels any pending guarantee timer.
  ///
  /// Must be called from the owning [State]'s `dispose()` so a timer
  /// scheduled by [down] never fires after the widget has been unmounted.
  void dispose() {
    _minimumHoldTimer?.cancel();
    _minimumHoldTimer = null;
  }
}
