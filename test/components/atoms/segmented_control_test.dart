// Behavior tests for CruxSegmentedControl, following the front-loaded
// pattern established by checkbox_test.dart / chip_test.dart: onChanged
// wiring, disabled safety, the 44 minimum tap target, the selection plate's
// spring-driven appear/disappear, the "kira" sheen one-shot (direction-aware,
// gated to real selection changes only), rapid-tap robustness, and semantics
// (selected + inMutuallyExclusiveGroup).
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxSegmentedControl needs to
/// lay out and paint (a [Directionality]), matching the convention in
/// checkbox_test.dart / chip_test.dart. No [CruxTheme] is provided
/// deliberately, exercising the documented fallback to
/// [CruxThemeData.light].
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// Three segments shared by every test: values 'a'/'b'/'c' at ascending
/// indices, labels 'A'/'B'/'C'. A three-segment control is the minimum
/// needed to exercise "move right" and "move left" separately from the
/// endpoints.
const List<CruxSegment<String>> _segments = <CruxSegment<String>>[
  CruxSegment<String>(value: 'a', label: 'A'),
  CruxSegment<String>(value: 'b', label: 'B'),
  CruxSegment<String>(value: 'c', label: 'C'),
];

/// Finds the [Stack] that is the private per-segment button's own root --
/// scoping every other finder below to exactly one segment's subtree, the
/// same "walk up from a known descendant" technique
/// checkbox_test.dart's finders use, needed here because the per-segment
/// widget itself is a private class this test file cannot reference by type.
Finder _segmentStack(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(Stack))
      .first;
}

/// Finds the nearest [Semantics] ancestor of a segment's label -- the
/// wrapping node [CruxSegmentedControl] builds for that segment.
Finder _segmentSemantics(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(Semantics))
      .first;
}

/// Finds a segment's selection-plate [AnimatedOpacity] (the widget driving
/// the plate's fade in/out).
Finder _plateOpacityFinder(String label) {
  return find.descendant(
    of: _segmentStack(label),
    matching: find.byType(AnimatedOpacity),
  );
}

double _plateOpacity(WidgetTester tester, String label) {
  return tester.widget<AnimatedOpacity>(_plateOpacityFinder(label)).opacity;
}

/// Finds a segment's plate box: the only [DecoratedBox] in its subtree whose
/// [ShapeDecoration] carries a non-null `shadows` list (the plate's small
/// shadow) -- distinct from any other decorated box a segment might paint.
Finder _plateBoxFinder(String label) {
  return find.descendant(
    of: _segmentStack(label),
    matching: find.byWidgetPredicate((Widget widget) {
      if (widget is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = widget.decoration;
      return decoration is ShapeDecoration && decoration.shadows != null;
    }),
  );
}

/// Finds the [Transform] that scales the plate box specifically -- distinct
/// from the outer press-scale [Transform] the whole segment button also
/// builds (mirroring checkbox_test.dart's identical disambiguation
/// technique: [find.ancestor] walks upward from the plate box and returns
/// ancestors nearest-first, so `.first` is the plate's own immediately
/// wrapping [Transform]).
Finder _plateTransformFinder(String label) {
  return find
      .ancestor(of: _plateBoxFinder(label), matching: find.byType(Transform))
      .first;
}

double _plateScale(WidgetTester tester, String label) {
  return tester
      .widget<Transform>(_plateTransformFinder(label))
      .transform
      .entry(0, 0);
}

/// Finds any actively-skewed [Transform] in a segment's subtree -- the sheen
/// sweep's skew, which is the only [Transform] this widget ever builds with
/// a non-zero (0,1) matrix entry (every other [Transform] here is a pure
/// scale). Empty whenever no sheen is currently mid-flight for that segment
/// (including "never triggered" and "already finished").
Finder _sheenSkewFinder(String label) {
  return find.descendant(
    of: _segmentStack(label),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Transform && widget.transform.entry(0, 1) != 0,
    ),
  );
}

/// Finds the outer pill background [Container] -- the single [Container]
/// [CruxSegmentedControl] itself builds directly (the sheen sweep's own
/// `Container`, built by `_buildSheenMask`, only exists while a sheen is
/// mid-flight, never in the settled states these tests pump to). Its
/// rendered height is the whole control's own visible height.
Finder _pillContainer() => find.byType(Container).first;

/// Finds a segment's own [GestureDetector] -- the widget whose rendered size
/// is that segment's real, hit-testable tap region. Once the visible pill is
/// shorter than the 44px minimum tap target, this is a *different*, taller
/// box than [_segmentStack]'s (the segment's merely-visible content, sized
/// to the shorter pill) -- see segmented_control.dart's `_minTapTarget` doc.
Finder _segmentHitRegion(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first;
}

/// Pumps in small steps across [total], calling [sample] after every step --
/// used to catch a sheen's brief mid-flight window (or confirm one never
/// appears) without coupling to one exact millisecond.
Future<void> _pumpSampling(
  WidgetTester tester,
  Duration total,
  Duration step,
  void Function() sample,
) async {
  int elapsedMs = 0;
  final int totalMs = total.inMilliseconds;
  final int stepMs = step.inMilliseconds;
  while (elapsedMs < totalMs) {
    await tester.pump(step);
    elapsedMs += stepMs;
    sample();
  }
}

void main() {
  group('tap handling', () {
    testWidgets('notifies onChanged with the tapped segment\'s value', (
      WidgetTester tester,
    ) async {
      final List<String> notifications = <String>[];
      await tester.pumpWidget(
        _wrap(
          CruxSegmentedControl<String>(
            segments: _segments,
            selected: 'a',
            onChanged: notifications.add,
          ),
        ),
      );

      await tester.tap(find.text('B'));
      await tester.pump();

      expect(notifications, <String>['b']);
    });

    testWidgets(
      'does not notify when the already-selected segment is tapped again',
      (WidgetTester tester) async {
        final List<String> notifications = <String>[];
        await tester.pumpWidget(
          _wrap(
            CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'a',
              onChanged: notifications.add,
            ),
          ),
        );

        await tester.tap(find.text('A'));
        await tester.pump();

        expect(notifications, isEmpty);
      },
    );
  });

  group('disabled', () {
    testWidgets(
      'does not invoke onChanged and stays tappable-safe when onChanged is '
      'null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'a',
            ),
          ),
        );

        await tester.tap(find.text('B'));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('tap target', () {
    // The visible pill shrank to 40px (2026-08-02, "ピルを 40px に"), shorter
    // than the 44px minimum tap target -- so what this test measures moved
    // from the segment's *visible* Stack (formerly the same box as its tap
    // region, back when both were 44px) to its actual hit-testable
    // GestureDetector, which segmented_control.dart now deliberately keeps
    // taller than the pill via a ConstrainedBox(minHeight: 44).
    //
    // Every test in this group wraps the control in a Center (rather than
    // _wrap's bare Directionality alone) so it shrink-wraps to its real,
    // natural size -- this matters far more here than in most other
    // groups. A bare Directionality pumped directly hands the control the
    // *tight* full test-viewport size (800x600) regardless of this
    // widget's own layout, which stretches every box on the way down to a
    // segment's GestureDetector to roughly that same ~600px-tall size. A
    // real, once-shipped bug here (an ancestor box, OverflowBox, whose
    // *reported* size didn't match the taller size it actually laid its
    // child out at -- RenderBox.hitTest gates every tap against a box's
    // own reported size before it ever recurses into its child) went
    // completely unnoticed by a boundary-tap test run under that
    // artificial ~600px stretch: any reported-vs-actual mismatch of a few
    // px was dwarfed by it, so a tap anywhere near the edge still landed
    // inside every ancestor's inflated reported bounds. Center removes
    // that false safety net.
    testWidgets('keeps each segment\'s hit-testable region at least 44 logical '
        'pixels tall, even though the visible pill is shorter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'a',
              onChanged: (String _) {},
            ),
          ),
        ),
      );

      for (final String label in <String>['A', 'B', 'C']) {
        final Size size = tester.getSize(_segmentHitRegion(label));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets(
      'registers a tap 1px inside the very top edge of the shrink-wrapped '
      'control\'s own 44px-tall hit region -- above the shorter 32px-tall '
      'visible pill it wraps',
      (WidgetTester tester) async {
        final List<String> notifications = <String>[];
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxSegmentedControl<String>(
                segments: _segments,
                selected: 'a',
                onChanged: notifications.add,
              ),
            ),
          ),
        );

        final Rect hitRegion = tester.getRect(_segmentHitRegion('B'));
        await tester.tapAt(Offset(hitRegion.center.dx, hitRegion.top + 1));
        await tester.pump();

        expect(notifications, <String>['b']);
      },
    );

    testWidgets(
      'the shrink-wrapped control\'s own outer layout height is exactly 44 '
      'logical pixels -- 4px taller than the 40px visible pill it wraps',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxSegmentedControl<String>(
                segments: _segments,
                selected: 'a',
                onChanged: (String _) {},
              ),
            ),
          ),
        );

        final Size size = tester.getSize(
          find.byType(CruxSegmentedControl<String>),
        );
        expect(size.height, 44);
      },
    );

    testWidgets(
      'registers a tap 1px above the visible pill\'s own top edge -- still '
      'inside the control\'s outer 44px layout, but above the 40px pill '
      'anyone can actually see',
      (WidgetTester tester) async {
        final List<String> notifications = <String>[];
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxSegmentedControl<String>(
                segments: _segments,
                selected: 'a',
                onChanged: notifications.add,
              ),
            ),
          ),
        );

        final Rect pillRect = tester.getRect(_pillContainer());
        final double tapX = tester.getRect(_segmentStack('B')).center.dx;
        await tester.tapAt(Offset(tapX, pillRect.top - 1));
        await tester.pump();

        expect(notifications, <String>['b']);
      },
    );
  });

  group('visible pill height', () {
    testWidgets('the outer pill background is 40 logical pixels tall '
        '(2026-08-02: "ピルを 40px に")', (WidgetTester tester) async {
      // Wrapped in a Center (rather than _wrap's bare Directionality
      // alone) so the control's own height is loosely constrained and
      // free to shrink-wrap its real content height, the same as it does
      // inside a real screen -- a bare Directionality pumped directly
      // hands the control the *tight* full test-viewport size instead
      // (800x600), which would report 600 here regardless of this
      // widget's own layout, measuring the test surface instead of the
      // pill.
      await tester.pumpWidget(
        _wrap(
          Center(
            child: CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'a',
              onChanged: (String _) {},
            ),
          ),
        ),
      );

      final Size size = tester.getSize(_pillContainer());
      expect(size.height, 40);
    });
  });

  group('selection plate width', () {
    testWidgets(
      'the selected segment\'s plate box fills that segment\'s own cell -- '
      'the control width split evenly across all segments after the '
      'control\'s own outer padding is removed -- not just the width of its '
      'label text',
      (WidgetTester tester) async {
        // A SizedBox pins the control to a known, exact width so the
        // expected cell width below can be computed from public numbers
        // alone (this width, the segment count, and the control's own
        // outer padding) rather than read back from whatever the
        // implementation under test happens to produce. Wrapped in a
        // Center first for the same reason the "visible pill height" test
        // above is: a bare Directionality pumped directly hands the first
        // child the *tight* full test-viewport size, which would force
        // this SizedBox's width request to be clamped straight back up to
        // the viewport's own width instead of taking effect.
        const double controlWidth = 300;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: controlWidth,
                child: CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: 'b',
                  onChanged: (String _) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Matches mock-b-shadow.html's `.segmented { padding: 4px; }`
        // wrapping three equal `flex: 1` `.segment`s -- see
        // segmented_control.dart's `_controlPadding` doc.
        const double controlPadding = 4;
        const int segmentCount = 3;
        final double expectedCellWidth =
            (controlWidth - controlPadding * 2) / segmentCount;

        final double plateWidth = tester.getSize(_plateBoxFinder('B')).width;

        expect(
          plateWidth,
          moreOrLessEquals(expectedCellWidth, epsilon: 0.5),
          reason:
              'the selected plate should span its whole segment cell '
              '(~$expectedCellWidth), not shrink to the "B" label\'s own '
              'text width',
        );
      },
    );
  });

  group('selection plate', () {
    testWidgets(
      'the plate is only opaque for the selected segment, faded for the '
      'others, once settled',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'b',
              onChanged: (String _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_plateOpacity(tester, 'A'), 0.0);
        expect(_plateOpacity(tester, 'B'), 1.0);
        expect(_plateOpacity(tester, 'C'), 0.0);
      },
    );

    testWidgets(
      'moves the opaque plate to the newly selected segment and fades the '
      'previous one out, once settled',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('C'));
        await tester.pumpAndSettle();

        expect(_plateOpacity(tester, 'A'), 0.0);
        expect(_plateOpacity(tester, 'B'), 0.0);
        expect(_plateOpacity(tester, 'C'), 1.0);
      },
    );

    testWidgets(
      'the newly selected plate overshoots past scale 1.0 while appearing '
      '(the confirmed spring bounce), sampled mid-flight',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('B'));
        await tester.pump();

        double peak = 0.0;
        for (int i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 1));
          final double scale = _plateScale(tester, 'B');
          if (scale > peak) {
            peak = scale;
          }
        }

        expect(peak, greaterThan(1.0));
      },
    );
  });

  group('kira sheen gating', () {
    testWidgets('never sweeps on the initial render', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxSegmentedControl<String>(
            segments: _segments,
            selected: 'a',
            onChanged: (String _) {},
          ),
        ),
      );

      bool sawSheen = false;
      await _pumpSampling(
        tester,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 20),
        () {
          if (_sheenSkewFinder('A').evaluate().isNotEmpty) {
            sawSheen = true;
          }
        },
      );

      expect(sawSheen, isFalse);
    });

    testWidgets('never sweeps when the already-selected segment is re-tapped', (
      WidgetTester tester,
    ) async {
      String selected = 'a';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxSegmentedControl<String>(
                segments: _segments,
                selected: selected,
                onChanged: (String next) => setState(() => selected = next),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A'));
      await tester.pump();

      bool sawSheen = false;
      await _pumpSampling(
        tester,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 20),
        () {
          if (_sheenSkewFinder('A').evaluate().isNotEmpty) {
            sawSheen = true;
          }
        },
      );

      expect(sawSheen, isFalse);
    });

    testWidgets(
      'sweeps once on a real selection change, tilted one way moving right '
      'and the mirrored way moving left',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // a -> c: moving right (forward).
        await tester.tap(find.text('C'));
        await tester.pump();

        double? forwardTilt;
        await _pumpSampling(
          tester,
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 10),
          () {
            final Iterable<Element> found = _sheenSkewFinder('C').evaluate();
            if (found.isNotEmpty && forwardTilt == null) {
              forwardTilt = (found.first.widget as Transform).transform.entry(
                0,
                1,
              );
            }
          },
        );
        await tester.pumpAndSettle();

        expect(
          forwardTilt,
          isNotNull,
          reason: 'expected the sheen to sweep across segment C at some point',
        );
        expect(forwardTilt, greaterThan(0));

        // c -> a: moving left (backward) -- the mirrored tilt sign.
        await tester.tap(find.text('A'));
        await tester.pump();

        double? backwardTilt;
        await _pumpSampling(
          tester,
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 10),
          () {
            final Iterable<Element> found = _sheenSkewFinder('A').evaluate();
            if (found.isNotEmpty && backwardTilt == null) {
              backwardTilt = (found.first.widget as Transform).transform.entry(
                0,
                1,
              );
            }
          },
        );

        expect(
          backwardTilt,
          isNotNull,
          reason: 'expected the sheen to sweep across segment A at some point',
        );
        expect(backwardTilt, lessThan(0));
      },
    );

    testWidgets('only the newly selected segment sweeps, never the others', (
      WidgetTester tester,
    ) async {
      String selected = 'a';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxSegmentedControl<String>(
                segments: _segments,
                selected: selected,
                onChanged: (String next) => setState(() => selected = next),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('C'));
      await tester.pump();

      bool sawSheenOnA = false;
      bool sawSheenOnB = false;
      await _pumpSampling(
        tester,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 10),
        () {
          if (_sheenSkewFinder('A').evaluate().isNotEmpty) {
            sawSheenOnA = true;
          }
          if (_sheenSkewFinder('B').evaluate().isNotEmpty) {
            sawSheenOnB = true;
          }
        },
      );

      expect(sawSheenOnA, isFalse);
      expect(sawSheenOnB, isFalse);
    });
  });

  group('kira sheen survives rapid retarget', () {
    testWidgets(
      'a still-sweeping sheen is not cut off when the selection moves on to '
      'a different segment before that sweep finishes (A -> B -> C fast)',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // a -> b: schedules B's sheen after the ~90ms delay.
        await tester.tap(find.text('B'));
        await tester.pump();

        // Step forward in small increments (matching real frame cadence,
        // rather than one big pump -- a single large pump only renders one
        // frame at its very end, which makes a spring/curve that started
        // mid-jump read as if it had barely moved) until B's sheen is
        // confirmed mid-flight.
        bool sawSheenOnB = false;
        for (int i = 0; i < 15 && !sawSheenOnB; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          if (_sheenSkewFinder('B').evaluate().isNotEmpty) {
            sawSheenOnB = true;
          }
        }
        expect(
          sawSheenOnB,
          isTrue,
          reason:
              'sanity check: B\'s kira should be mid-flight before it '
              'gets retargeted away',
        );

        // b -> c, before B's sweep (300ms total) has had a chance to
        // finish.
        await tester.tap(find.text('C'));
        await tester.pump();

        // Step forward well past the moment C's own ~90ms delay elapses --
        // the point an earlier version of this class reset B's
        // sheenTrigger back to `0`, permanently snapping its still
        // mid-flight kira to invisible. Only the tail samples are checked,
        // so a leftover match from *before* that reset moment (still
        // legitimately visible either way) can't make this pass for the
        // wrong reason.
        final List<bool> tailSamples = <bool>[];
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          if (i >= 10) {
            tailSamples.add(_sheenSkewFinder('B').evaluate().isNotEmpty);
          }
        }

        expect(
          tailSamples,
          anyElement(isTrue),
          reason:
              'B\'s kira should still be sweeping well after C becomes '
              'the sheen\'s new target, not permanently truncated the '
              'instant a different segment becomes the target',
        );
      },
    );
  });

  group('kira sheen delay', () {
    testWidgets(
      'has not appeared yet at ~50ms after a real selection change, but has '
      'appeared by ~150ms (pins the confirmed ~90ms delay)',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('B'));
        await tester.pump();

        // Step in small increments (rather than one big pump -- see the
        // "kira sheen survives rapid retarget" group above for why) up to
        // ~50ms: the sheen must not have appeared anywhere in this window.
        bool sawSheenBy50ms = false;
        for (int elapsed = 0; elapsed < 50; elapsed += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          if (_sheenSkewFinder('B').evaluate().isNotEmpty) {
            sawSheenBy50ms = true;
          }
        }
        expect(
          sawSheenBy50ms,
          isFalse,
          reason: 'the kira sheen should not have started yet at ~50ms',
        );

        // Continue stepping up to ~150ms total: the sheen must have
        // appeared by the end of this window.
        for (int elapsed = 50; elapsed < 150; elapsed += 10) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(
          _sheenSkewFinder('B').evaluate(),
          isNotEmpty,
          reason: 'the kira sheen should have appeared by ~150ms',
        );
      },
    );
  });

  group('rapid retarget continuity', () {
    testWidgets(
      'the plate scale and opacity of a segment retargeted away mid-flight '
      'never jump by more than a small step between adjacent sampled '
      'frames',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('B'));
        selected = 'b';
        await tester.pump();
        // Let B's plate get partway into its appear spring before yanking
        // selection away again.
        await tester.pump(const Duration(milliseconds: 40));

        await tester.tap(find.text('C'));
        selected = 'c';
        await tester.pump();

        double? lastScale;
        double? lastOpacity;
        // A tolerant threshold that would still catch a hard snap (e.g. a
        // scale jumping straight from mid-flight to its 0.8 rest value, or
        // an opacity jumping straight to 0) without coupling to motor's own
        // frame-by-frame timing.
        const double maxStepDelta = 0.3;

        for (int i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          final double scale = _plateScale(tester, 'B');
          final double opacity = _plateOpacity(tester, 'B');
          if (lastScale != null) {
            expect(
              (scale - lastScale).abs(),
              lessThanOrEqualTo(maxStepDelta),
              reason: 'plate scale jumped discontinuously at step $i',
            );
          }
          if (lastOpacity != null) {
            expect(
              (opacity - lastOpacity).abs(),
              lessThanOrEqualTo(maxStepDelta),
              reason: 'plate opacity jumped discontinuously at step $i',
            );
          }
          lastScale = scale;
          lastOpacity = opacity;
        }
      },
    );
  });

  group('rapid taps', () {
    testWidgets(
      'repeated fast taps across segments never throw and settle on the '
      'last tapped segment',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxSegmentedControl<String>(
                  segments: _segments,
                  selected: selected,
                  onChanged: (String next) => setState(() => selected = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final String label in <String>['B', 'C', 'A', 'B', 'C']) {
          await tester.tap(find.text(label));
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_plateOpacity(tester, 'A'), 0.0);
        expect(_plateOpacity(tester, 'B'), 0.0);
        expect(_plateOpacity(tester, 'C'), 1.0);
      },
    );
  });

  group('reduce motion', () {
    testWidgets(
      'still reflects the new selection but never sweeps the sheen when '
      'animations are disabled',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _wrap(
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return CruxSegmentedControl<String>(
                    segments: _segments,
                    selected: selected,
                    onChanged: (String next) => setState(() => selected = next),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('C'));
        await tester.pump();

        bool sawSheen = false;
        await _pumpSampling(
          tester,
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 20),
          () {
            if (_sheenSkewFinder('C').evaluate().isNotEmpty) {
              sawSheen = true;
            }
          },
        );

        expect(sawSheen, isFalse);
        expect(_plateBoxFinder('C').evaluate(), isNotEmpty);
        expect(_plateBoxFinder('A').evaluate(), isEmpty);
      },
    );
  });

  group('semantics', () {
    testWidgets(
      'exposes selected + inMutuallyExclusiveGroup per segment, and enabled '
      'follows onChanged',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'b',
              onChanged: (String _) {},
            ),
          ),
        );

        final SemanticsNode selectedNode = tester.getSemantics(
          _segmentSemantics('B'),
        );
        expect(selectedNode.flagsCollection.isSelected, Tristate.isTrue);
        expect(selectedNode.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(selectedNode.flagsCollection.isEnabled, Tristate.isTrue);

        final SemanticsNode unselectedNode = tester.getSemantics(
          _segmentSemantics('A'),
        );
        expect(unselectedNode.flagsCollection.isSelected, Tristate.isFalse);
        expect(
          unselectedNode.flagsCollection.isInMutuallyExclusiveGroup,
          isTrue,
        );

        await tester.pumpWidget(
          _wrap(
            const CruxSegmentedControl<String>(
              segments: _segments,
              selected: 'b',
            ),
          ),
        );
        final SemanticsNode disabledNode = tester.getSemantics(
          _segmentSemantics('B'),
        );
        expect(disabledNode.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      },
    );
  });
}
