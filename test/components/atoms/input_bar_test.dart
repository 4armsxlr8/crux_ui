// Behavior tests for CruxInputBar, per unknowns/input-bar/plan.md section 5
// ("テストで固定する") and handoff.md's frozen public API / behavior list.
// Written RED-first: CruxInputBar does not exist yet at the time this file
// is written (a separate implementation session builds it against these
// tests). Following text_form_field_test.dart's established conventions:
// an Overlay-inclusive `_wrap` (EditableText unconditionally needs one once
// focus or the text value changes), a predicate-based `_boxFinder` for the
// package's own decorated box (never a raw `find.byType(Container)`, which
// would also match CupertinoTextField's internal, undecorated one), and
// `debugDefaultTargetPlatformOverride` reset via `try`/`finally` rather than
// `addTearDown` -- see this file's own note on that below, a deviation from
// what the task briefing suggested, discovered by actually running the
// suite (not assumed).
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart'
    show
        ColorScheme,
        Colors,
        MaterialApp,
        Scaffold,
        TextSelectionThemeData,
        ThemeData;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxInputBar needs to lay out,
/// paint, focus, and accept typed input -- the same shape
/// text_form_field_test.dart's `_wrap`/`_OverlayHost` pair uses, and for the
/// same reason: `EditableText` unconditionally tries to build a selection
/// overlay as soon as its focus or selection changes (confirmed against the
/// Flutter SDK, `EditableTextState._handleSelectionChanged` ->
/// `_createSelectionOverlay`, which asserts an `Overlay` ancestor
/// unconditionally), and that includes programmatic `controller.text =`
/// assignments, not just user-driven typing. Every test in this file goes
/// through this helper rather than picking case-by-case, to avoid having to
/// reason about which specific tests need it.
Widget _wrap(
  Widget child, {
  double width = 320,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: textDirection,
    child: Center(
      child: SizedBox(
        width: width,
        child: _OverlayHost(child: child),
      ),
    ),
  );
}

/// See [_wrap]'s doc comment. Routes `child` through a `State`'s live
/// `widget.child` property (kept in sync by Flutter's own
/// `StatefulElement.update()` on every rebuild) rather than a value frozen
/// inside a closure passed straight to `OverlayEntry.builder` -- `Overlay`
/// only ever consumes `initialEntries` once
/// (`OverlayState.initState`), so a naive inline builder would keep
/// rendering whatever `child` was at the *first* `pumpWidget` call forever.
/// See text_form_field_test.dart's identically-shaped `_OverlayHost` for the
/// full history of the bug this avoids.
class _OverlayHost extends StatefulWidget {
  const _OverlayHost({required this.child});

  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: <OverlayEntry>[
        OverlayEntry(
          builder: (BuildContext context) =>
              Align(alignment: Alignment.topLeft, child: widget.child),
        ),
      ],
    );
  }
}

/// Reads the [Decoration] off a [Container] or [DecoratedBox], or `null` for
/// any other widget. Both are plausible choices for how
/// `CruxInputBar`'s implementation paints its own box (plan.md's "実装設計"
/// section describes the box as `ShapeDecoration(color: colors.controlFill,
/// shape: <a ShapeBorder>)` without pinning which of the two host widgets
/// carries it), so [_boxFinder] checks both rather than assuming one.
Decoration? _decorationOf(Widget widget) {
  if (widget is Container) {
    return widget.decoration;
  }
  if (widget is DecoratedBox) {
    return widget.decoration;
  }
  return null;
}

/// Finds the box (the one with the fill/shape CruxInputBar itself draws)
/// inside a rendered [CruxInputBar]. Distinguished from
/// [CupertinoTextField]'s own internal, undecorated container by requiring
/// a [ShapeDecoration] whose fill is exactly [CruxColors.controlFill] --
/// the fill color `lib/src/tokens/colors.dart`'s own doc comment on
/// `controlFill` names as the one other in-package consumer besides
/// `CruxTextFormField`, and plan.md section 2-2 pins as this box's fill --
/// rather than by its `shape`'s concrete type, which plan.md section 2-2's
/// "実装設計" deliberately leaves as a to-be-created (and possibly private)
/// `ShapeBorder` subclass, not `RoundedSuperellipseBorder` itself. This
/// keeps the finder from ever needing to name or cast to that subclass.
Finder _boxFinder({CruxColors colors = CruxColors.light}) {
  return find.byWidgetPredicate((Widget widget) {
    final Decoration? decoration = _decorationOf(widget);
    if (decoration is! ShapeDecoration) {
      return false;
    }
    return decoration.color == colors.controlFill;
  });
}

/// Reads the [ShapeDecoration] off whatever [_boxFinder] found. Asserts
/// (rather than silently returning `null`) because every test that calls
/// this has already confirmed the box exists via a `tester.getRect`/
/// `tester.getSize` call on the same finder, or is happy to fail loudly if
/// it does not.
ShapeDecoration _boxShapeDecoration(WidgetTester tester, Finder boxFinder) {
  return _decorationOf(tester.widget(boxFinder))! as ShapeDecoration;
}

/// Approximates the corner radius [shape] currently paints at [rect]'s
/// top-left corner, using nothing but [ShapeBorder]'s own public
/// `getOuterPath`/`Path.contains` surface -- this works for *any*
/// [ShapeBorder], including a private wrapper class that only delegates to
/// [RoundedSuperellipseBorder] internally (exactly what plan.md section
/// 2-2's "実装設計" describes CruxInputBar's box shape as), without ever
/// needing to name or cast to that concrete type.
///
/// Method, validated against known-radius [RoundedSuperellipseBorder]s
/// (including one wrapped in a throwaway delegating [ShapeBorder], to prove
/// this survives exactly the kind of wrapping plan.md's design calls for)
/// before being trusted here:
///
/// 1. Binary-search along the top-left corner's 45-degree diagonal
///    (`rect.topLeft + Offset(d, d)`) for the offset `d` at which [shape]'s
///    own outer path stops excluding that point -- the point where the
///    corner's rounded-away cut ends and the shape's bulk interior begins.
///    This is monotonic (a point closer to the corner is excluded for
///    *any* positive radius; a point far enough from the corner is
///    eventually included for *any* radius short of the whole rect), so
///    bisection finds it regardless of the corner's exact curve family.
/// 2. That transition offset alone does not directly reveal the radius --
///    the offset-to-radius relationship for a superellipse ("continuous"/
///    squircle) corner is not the same closed-form relationship a circular
///    arc has, and is not published. So instead of assuming a formula, a
///    second nested binary search asks the exact same question of
///    reference [RoundedSuperellipseBorder]s at a range of candidate radii,
///    using the *same* diagonal-offset probe, and finds the candidate
///    radius whose own transition lands at the same offset. Because both
///    the probed shape and the references are the same curve family (true
///    whenever the implementation follows plan.md's own "組み立て直して
///    委譲する" design), this converges on the exact radius rather than an
///    approximation biased by a circular-arc assumption.
///
/// Confirmed capable of catching the exact regression this package's
/// impact.md warns about: fed a shape built by naively calling
/// `ShapeBorder.lerp` between a 9999-radius and a 16-radius
/// [RoundedSuperellipseBorder] at `t = 0.5`, this reports a radius within a
/// fraction of a pixel of the *un-lerped* 9999 shape's own clamped-to-pill
/// radius (`rect.height / 2`) -- reproducing, at the measurement level, the
/// "clamped to the pill shape for nearly the whole animation" failure
/// mode -- rather than reporting something close to the naive midpoint.
double _measureCornerRadius(ShapeBorder shape, Rect rect) {
  bool actualContainsAt(double d) =>
      shape.getOuterPath(rect).contains(rect.topLeft + Offset(d, d));

  double dLo = 0;
  double dHi = rect.shortestSide / 2;
  for (int i = 0; i < 30; i++) {
    final double mid = (dLo + dHi) / 2;
    if (actualContainsAt(mid)) {
      dHi = mid;
    } else {
      dLo = mid;
    }
  }
  final double transitionOffset = (dLo + dHi) / 2;

  bool referenceContainsAt(double radius, double d) =>
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
      ).getOuterPath(rect).contains(rect.topLeft + Offset(d, d));

  double rLo = 0;
  double rHi = rect.shortestSide / 2;
  for (int i = 0; i < 30; i++) {
    final double mid = (rLo + rHi) / 2;
    // A larger candidate radius cuts the corner further out, so its own
    // transition point moves further from the corner too -- meaning
    // "the candidate radius's cut has not yet reached transitionOffset"
    // (still contains the probe there) implies the candidate is *smaller*
    // than the radius actually being measured.
    if (referenceContainsAt(mid, transitionOffset)) {
      rLo = mid;
    } else {
      rHi = mid;
    }
  }
  return (rLo + rHi) / 2;
}

/// A small, non-icon-system widget usable as a leading/clear/submit icon --
/// deliberately not a real icon font, matching
/// text_form_field_test.dart's `buildToggle`'s reasoning: this package
/// places no expectations on what kind of [Widget] a caller passes for an
/// icon, and a plain [ColoredBox] (rather than an empty [SizedBox]) still
/// paints something and is a genuine hit-test target for `tester.tap`.
Widget _icon(Key key, Color color) {
  return SizedBox(
    width: 20,
    height: 20,
    child: ColoredBox(key: key, color: color),
  );
}

/// Finds the nearest [GestureDetector] ancestor of [iconFinder] -- the
/// same "find the tap-target wrapper by walking up from the icon"
/// convention text_form_field_test.dart's obscure-toggle group uses.
Finder _gestureDetectorAncestorOf(Finder iconFinder) {
  return find.ancestor(of: iconFinder, matching: find.byType(GestureDetector));
}

/// Finds the nearest ancestor of [iconFinder] that paints a circular fill
/// (either a [BoxDecoration] with `shape: BoxShape.circle` or a
/// [ShapeDecoration] with a [CircleBorder] shape) -- the widget expected to
/// be the submit button's visible 32px circle, per IB-D02. This does not
/// assume a specific host widget type (`Container`/`DecoratedBox`) or a
/// specific circle-decoration style, only that *some* ancestor paints one.
Finder _circleAncestorOf(Finder iconFinder) {
  return find.ancestor(
    of: iconFinder,
    matching: find.byWidgetPredicate((Widget widget) {
      final Decoration? decoration = _decorationOf(widget);
      if (decoration is BoxDecoration) {
        return decoration.shape == BoxShape.circle;
      }
      if (decoration is ShapeDecoration) {
        return decoration.shape is CircleBorder;
      }
      return false;
    }),
  );
}

void main() {
  group('single line (maxLines: 1, the default)', () {
    testWidgets(
      'keeps the same box height whether the field is empty or holds a '
      'very long value -- a single-line CruxInputBar never grows',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrap(CruxInputBar(controller: controller)));
        final double emptyHeight = tester.getSize(_boxFinder()).height;

        controller.text =
            'とても長い入力値です。とても長い入力値です。とても長い入力値です。'
            'とても長い入力値です。とても長い入力値です。とても長い入力値です。';
        await tester.pumpAndSettle();

        final double filledHeight = tester.getSize(_boxFinder()).height;
        expect(filledHeight, emptyHeight);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the return key calls onSubmit with the current text -- per IB-A04, '
      'a single-line bar always treats the return key as "submit", with no '
      'platform-dependent behavior (unlike the maxLines >= 2 case, see the '
      '"newline key environment switching" group below)',
      (WidgetTester tester) async {
        final List<String> submissions = <String>[];
        final TextEditingController controller = TextEditingController();
        final FocusNode focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              focusNode: focusNode,
              onSubmit: submissions.add,
            ),
          ),
        );

        // `tester.testTextInput.receiveAction` only reaches a field that
        // currently has an attached platform text-input connection, which
        // `EditableText` only opens once it actually has focus -- confirmed
        // empirically (not assumed) with a throwaway bare `CupertinoTextField`
        // before writing this test: sending the same action to an unfocused
        // field delivers to no client at all and silently calls no callback.
        // This deviates from this file's task briefing, which omitted the
        // `requestFocus()` call here -- a genuine test oversight caught by
        // actually running it, not a hint about CruxInputBar's own design
        // (nothing about this bar's frozen behavior calls for autofocusing
        // by default, and doing so would be poor UX for an ordinary search
        // bar).
        focusNode.requestFocus();
        await tester.pump();

        controller.text = 'こんにちは';
        await tester.pump();

        // The SDK's own recommended way to trigger a text field's onSubmit
        // in a widget test -- see `EditableText.onSubmitted`'s dartdoc's
        // "Testing" section: sending a raw `LogicalKeyboardKey.enter` via
        // `tester.sendKeyEvent` does *not* reach `onSubmitted`, because on a
        // real device the platform/engine translates the physical enter key
        // into a `TextInputAction`, and `tester.sendKeyEvent` only ever
        // delivers a raw key event to the framework, bypassing that
        // translation -- confirmed by actually running this technique
        // against a bare `CupertinoTextField` before writing this test.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(submissions, <String>['こんにちは']);
      },
    );
  });

  group('multi-line (maxLines: 5)', () {
    testWidgets('grows the box taller as more lines are entered', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxInputBar(controller: controller, maxLines: 5)),
      );
      await tester.pumpAndSettle();
      final double oneLineHeight = tester.getSize(_boxFinder()).height;

      controller.text = 'line1\nline2\nline3';
      await tester.pumpAndSettle();
      final double threeLineHeight = tester.getSize(_boxFinder()).height;

      expect(threeLineHeight, greaterThan(oneLineHeight));
      expect(tester.takeException(), isNull);

      // The height increase above could, in principle, be explained
      // entirely by the two-row morph's own action-row reservation (a
      // fixed amount of space this bar adds once text needs more than one
      // line) rather than the text field itself actually growing -- both
      // "the field grows like an ordinary multi-line field" and "the field
      // stays frozen at one line, only the action row's appearance grows
      // the box" would make the two lines above pass. Checking
      // EditableText.maxLines directly against widget.maxLines (the same
      // check text_form_field_test.dart's own "overflow" group makes)
      // confirms `maxLines: 5` genuinely reached CupertinoTextField, not
      // merely swallowed on the way there.
      final EditableText editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.maxLines, 5);
    });

    testWidgets(
      'stops growing once the text exceeds 5 lines -- the box caps at the '
      "5-line height and scrolls internally beyond that, it doesn't keep "
      'growing without bound',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxInputBar(controller: controller, maxLines: 5)),
        );

        controller.text = List<String>.generate(
          5,
          (int i) => 'line$i',
        ).join('\n');
        await tester.pumpAndSettle();
        final double fiveLineHeight = tester.getSize(_boxFinder()).height;

        controller.text = List<String>.generate(
          12,
          (int i) => 'line$i',
        ).join('\n');
        await tester.pumpAndSettle();
        final double twelveLineHeight = tester.getSize(_boxFinder()).height;

        expect(twelveLineHeight, closeTo(fiveLineHeight, 0.5));
        expect(tester.takeException(), isNull);

        // Same reasoning as the "grows the box taller" test above: without
        // this direct check, a field that never actually grows past one
        // line at all (only the fixed action-row reservation changing the
        // box's height) would make the height comparison above pass too,
        // for the wrong reason.
        final EditableText editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        expect(editableText.maxLines, 5);
      },
    );
  });

  group('shape transformation (IB-A01 / A05 / A07)', () {
    testWidgets('the box corner radius equals exactly half its own height when '
        'maxLines is 1 (the pill shape) -- IB-A01', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CruxInputBar()));
      await tester.pumpAndSettle();

      final Finder boxFinder = _boxFinder();
      final Rect boxRect = tester.getRect(boxFinder);
      final ShapeBorder shape = _boxShapeDecoration(tester, boxFinder).shape;

      final double measuredRadius = _measureCornerRadius(shape, boxRect);
      expect(measuredRadius, closeTo(boxRect.height / 2, 1.5));
    });

    testWidgets('the box corner radius becomes CruxRadii.l (16), not the box '
        'height, once the text wraps to 2+ lines -- IB-A01/A05', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxInputBar(controller: controller, maxLines: 5)),
      );
      controller.text = 'line1\nline2';
      await tester.pumpAndSettle();

      final Finder boxFinder = _boxFinder();
      final Rect boxRect = tester.getRect(boxFinder);
      final ShapeBorder shape = _boxShapeDecoration(tester, boxFinder).shape;

      final double measuredRadius = _measureCornerRadius(shape, boxRect);
      expect(measuredRadius, closeTo(CruxRadii.l, 1.5));
    });

    testWidgets(
      'collapsing from the two-row shape back to the pill never throws -- the '
      "morph spring's undershoot below 0.0 must not reach a SizedBox as a "
      'negative height',
      (WidgetTester tester) async {
        // Found on a physical iPhone, not by this suite: collapsing the bar
        // threw "BoxConstraints has a negative minimum height ...
        // h=-0.2; NOT NORMALIZED" from SizedBox.updateRenderObject, followed
        // by a cascade of secondary render-tree assertions. The cause is the
        // morph spring itself: CruxMotion drives this value with
        // CupertinoMotion.snappy, whose 0.15 bounce makes it overshoot *past*
        // its target at both ends -- so a 1.0 -> 0.0 collapse briefly reports
        // a slightly negative progress, and any width/height/alignment
        // derived from it by plain multiplication goes negative with it.
        //
        // Every previous test in this group only ever expands (0.0 -> 1.0),
        // where the same overshoot lands above 1.0 and merely rounds a corner
        // a little too far rather than producing an illegal constraint --
        // which is exactly why the whole suite stayed green while a real
        // device threw on the first collapse.
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxInputBar(controller: controller, maxLines: 5)),
        );
        controller.text = 'line1\nline2';
        await tester.pumpAndSettle();

        controller.text = '';
        // Step in small increments rather than pumpAndSettle: the undershoot
        // occupies only a few frames near the end of the spring's travel, and
        // pumpAndSettle's own 100ms default step can step straight over them.
        for (int frame = 0; frame < 150; frame++) {
          await tester.pump(const Duration(milliseconds: 4));
          expect(
            tester.takeException(),
            isNull,
            reason: 'frame $frame of the collapse threw',
          );
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'mid-transformation, the corner radius is genuinely between the pill '
      'radius and 16 -- not clamped near the pill shape until the last '
      'instant, the exact "linear-lerp of raw radii" failure mode '
      'impact.md documents (a naive lerp from 9999 down to 16 is still '
      'clamped to ~9999 at t=0.5, since RSuperellipse.scaleRadii clamps a '
      'corner radius to fit the rect at *paint* time, not before)',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxInputBar(controller: controller, maxLines: 5)),
        );
        await tester.pumpAndSettle();
        final double pillRadius = tester.getRect(_boxFinder()).height / 2;

        controller.text = 'line1\nline2';
        // Starts the spring (a zero-duration pump lets the pending setState
        // actually rebuild and start the animation ticking from elapsed
        // zero -- the same two-pump sampling pattern button_test.dart's and
        // switch_test.dart's own mid-flight tests use), then samples
        // partway through -- not settled.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final Finder boxFinder = _boxFinder();
        final Rect midRect = tester.getRect(boxFinder);
        final ShapeBorder midShape = _boxShapeDecoration(
          tester,
          boxFinder,
        ).shape;
        final double midRadius = _measureCornerRadius(midShape, midRect);

        expect(midRadius, greaterThan(CruxRadii.l));
        expect(midRadius, lessThan(pillRadius));

        // Not merely "somewhere in between" (a value 0.1% of the way from
        // the pill radius toward 16 would technically satisfy the two
        // checks above too) -- at least 15% of the way in from *both*
        // ends, directly ruling out the "stuck at the pill shape, then
        // jumps at the very end" failure mode.
        final double span = pillRadius - CruxRadii.l;
        expect(midRadius, greaterThan(CruxRadii.l + span * 0.15));
        expect(midRadius, lessThan(pillRadius - span * 0.15));
      },
    );
  });

  group('submit button', () {
    testWidgets('does nothing when tapped while the text is empty', (
      WidgetTester tester,
    ) async {
      final List<String> submissions = <String>[];
      const Key iconKey = Key('submit-icon');

      await tester.pumpWidget(
        _wrap(
          CruxInputBar(
            submit: CruxInputBarSubmit(
              icon: _icon(iconKey, const Color(0xFF336699)),
              label: '送信',
            ),
            onSubmit: submissions.add,
          ),
        ),
      );

      await tester.tap(find.byKey(iconKey), warnIfMissed: false);
      await tester.pump();

      expect(submissions, isEmpty);
    });

    testWidgets(
      'calls onSubmit with the current text once tapped while the field '
      'has content',
      (WidgetTester tester) async {
        final List<String> submissions = <String>[];
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        const Key iconKey = Key('submit-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              submit: CruxInputBarSubmit(
                icon: _icon(iconKey, const Color(0xFF336699)),
                label: '送信',
              ),
              onSubmit: submissions.add,
            ),
          ),
        );

        controller.text = 'こんにちは';
        await tester.pump();

        await tester.tap(find.byKey(iconKey));
        await tester.pump();

        expect(submissions, <String>['こんにちは']);
      },
    );

    testWidgets('keeps a tap target of at least 44x44, even though the visible '
        'circle is smaller -- IB-D02', (WidgetTester tester) async {
      const Key iconKey = Key('submit-icon');
      await tester.pumpWidget(
        _wrap(
          CruxInputBar(
            submit: CruxInputBarSubmit(
              icon: _icon(iconKey, const Color(0xFF336699)),
              label: '送信',
            ),
          ),
        ),
      );

      final Size tapTargetSize = tester.getSize(
        _gestureDetectorAncestorOf(find.byKey(iconKey)),
      );
      expect(tapTargetSize.width, greaterThanOrEqualTo(44));
      expect(tapTargetSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets(
      'paints its visible circle at exactly 32 logical pixels in diameter '
      '-- IB-D02',
      (WidgetTester tester) async {
        const Key iconKey = Key('submit-icon');
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              submit: CruxInputBarSubmit(
                icon: _icon(iconKey, const Color(0xFF336699)),
                label: '送信',
              ),
            ),
          ),
        );
        // Measured with text present (the enabled/accent-colored state) --
        // the circle's own size is not expected to depend on enabled state,
        // but this avoids any doubt about whether a disabled circle is
        // rendered differently.
        controller.text = 'こんにちは';
        await tester.pumpAndSettle();

        final Size circleSize = tester.getSize(
          _circleAncestorOf(find.byKey(iconKey)),
        );
        expect(circleSize.width, closeTo(32, 0.5));
        expect(circleSize.height, closeTo(32, 0.5));
      },
    );
  });

  group('clear button', () {
    testWidgets('is not present at all while the field is empty', (
      WidgetTester tester,
    ) async {
      const Key iconKey = Key('clear-icon');
      await tester.pumpWidget(
        _wrap(
          CruxInputBar(
            clear: CruxInputBarClear(
              icon: _icon(iconKey, const Color(0xFF996633)),
              label: '消去',
            ),
          ),
        ),
      );

      expect(find.byKey(iconKey), findsNothing);
    });

    testWidgets(
      'appears once the field has content, and tapping it empties the '
      'text and calls onChanged with the empty string',
      (WidgetTester tester) async {
        final List<String> changes = <String>[];
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        const Key iconKey = Key('clear-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              clear: CruxInputBarClear(
                icon: _icon(iconKey, const Color(0xFF996633)),
                label: '消去',
              ),
              onChanged: changes.add,
            ),
          ),
        );

        controller.text = 'こんにちは';
        await tester.pump();
        expect(find.byKey(iconKey), findsOneWidget);

        await tester.tap(find.byKey(iconKey));
        await tester.pump();

        expect(controller.text, isEmpty);
        expect(changes, contains(''));
        // Once cleared, the button disappears again.
        expect(find.byKey(iconKey), findsNothing);
      },
    );

    testWidgets('keeps a tap target of at least 44x44', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      const Key iconKey = Key('clear-icon');

      await tester.pumpWidget(
        _wrap(
          CruxInputBar(
            controller: controller,
            clear: CruxInputBarClear(
              icon: _icon(iconKey, const Color(0xFF996633)),
              label: '消去',
            ),
          ),
        ),
      );
      controller.text = 'こんにちは';
      await tester.pump();

      final Size tapTargetSize = tester.getSize(
        _gestureDetectorAncestorOf(find.byKey(iconKey)),
      );
      expect(tapTargetSize.width, greaterThanOrEqualTo(44));
      expect(tapTargetSize.height, greaterThanOrEqualTo(44));
    });
  });

  group('newline key environment switching (IB-A03, maxLines >= 2)', () {
    // debugDefaultTargetPlatformOverride is reset via try/finally, not
    // addTearDown, in every test in this group -- a deliberate deviation
    // from the task briefing's suggested addTearDown-based pattern,
    // discovered by actually running it: `addTearDown` callbacks run once
    // package:test considers the *whole* testWidgets callback finished, but
    // TestWidgetsFlutterBinding's own `debugAssertAllFoundationVarsUnset`
    // invariant check (which fails the test if
    // debugDefaultTargetPlatformOverride is still non-null) runs *inside*
    // that same callback, strictly before an addTearDown registered inside
    // the test body gets a chance to run -- confirmed with a minimal
    // reproduction (a bare `debugDefaultTargetPlatformOverride = X;
    // addTearDown(() => ... = null);` with no other code) that fails this
    // same invariant every time. The override *is* still reset in time for
    // the *next* test (addTearDown does run eventually, just too late for
    // this test's own invariant check), so this is a spurious
    // self-inflicted failure, not a real leak -- but it would still show
    // every test in this group as failing. try/finally, run synchronously
    // before the test function returns, avoids it -- matching the pattern
    // Flutter's own SDK test suite actually uses for this exact variable
    // (see e.g. `flutter/test/rendering/proxy_box_test.dart`,
    // `flutter/test/material/text_field_test.dart`), not the
    // addTearDown-based one.
    //
    // Sending a raw hardware Enter key via `tester.sendKeyEvent` cannot
    // make real text-insertion happen in this test environment -- per
    // `EditableText.onSubmitted`'s own dartdoc, quoted in the single-line
    // group above, the engine's translation of a physical Enter keystroke
    // into either a `TextInputAction` or an inserted character both happen
    // outside the framework, and `tester.sendKeyEvent` only ever delivers a
    // raw `KeyEvent` to the widget tree's `Focus`/`Shortcuts` machinery.
    // Confirmed empirically (not assumed) before writing these tests: a
    // bare `CupertinoTextField(maxLines: 5)` with no interception at all
    // leaves its text completely unchanged after `sendKeyEvent(...enter)`,
    // on every platform. That means CruxInputBar's own handling of this
    // key must itself be implemented as a `Focus`/`Shortcuts`-level
    // interceptor around the field (not solely a `CupertinoTextField
    // .onSubmitted` wiring, the way the maxLines: 1 case can be) for these
    // tests to be able to observe anything at all -- confirmed with a
    // throwaway prototype (a `Focus(onKeyEvent: ...)` wrapper calling
    // `onSubmit` directly and returning `KeyEventResult.handled`) before
    // writing this group, which these tests' shape mirrors. See this
    // group's own tests for exactly what each platform is expected to do;
    // the "does not insert a newline" assertions below hold trivially in
    // this test harness regardless of whether the implementation is
    // correct (raw `sendKeyEvent` never inserts characters here on *any*
    // platform, interceptor or not) -- they are kept because the task
    // asked for them and they cost nothing, but the assertion that
    // actually exercises the interception logic is "onSubmit was called".
    testWidgets('macOS: the hardware Enter key alone calls onSubmit with the '
        'current text', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final List<String> submissions = <String>[];
        final TextEditingController controller = TextEditingController();
        final FocusNode focusNode = FocusNode();

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              focusNode: focusNode,
              maxLines: 5,
              onSubmit: submissions.add,
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        await tester.pump();

        controller.text = 'こんにちは';
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(submissions, <String>['こんにちは']);
        expect(controller.text, 'こんにちは');

        controller.dispose();
        focusNode.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'macOS: Shift+Enter does not call onSubmit (it is the documented way '
      'to enter a literal newline on desktop platforms)',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          final List<String> submissions = <String>[];
          final TextEditingController controller = TextEditingController();
          final FocusNode focusNode = FocusNode();

          await tester.pumpWidget(
            _wrap(
              CruxInputBar(
                controller: controller,
                focusNode: focusNode,
                maxLines: 5,
                onSubmit: submissions.add,
              ),
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          controller.text = 'こんにちは';
          await tester.pump();

          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();

          expect(submissions, isEmpty);

          controller.dispose();
          focusNode.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'macOS: a KeyRepeatEvent -- the OS holding the key down, not only its '
      'initial KeyDownEvent -- also calls onSubmit, and does not leak into '
      'DefaultTextEditingShortcuts\' "let the IME insert a newline" Return '
      'binding (Flutter SDK `default_text_editing_shortcuts.dart`, the '
      'binding a `Shortcuts.SingleActivator` for Return would otherwise '
      'fall through to on every repeat frame after the first, since '
      '`SingleActivator.includeRepeats` defaults to true and would '
      'otherwise keep re-registering "handled" only on the very first '
      'frame -- see this package\'s own review notes for the SDK line '
      'numbers this was confirmed against)',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          final List<String> submissions = <String>[];
          final TextEditingController controller = TextEditingController();
          final FocusNode focusNode = FocusNode();

          await tester.pumpWidget(
            _wrap(
              CruxInputBar(
                controller: controller,
                focusNode: focusNode,
                maxLines: 5,
                onSubmit: submissions.add,
              ),
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          controller.text = 'こんにちは';
          await tester.pump();

          // `tester.sendKeyEvent`/`sendKeyDownEvent` has no way to
          // synthesize the OS-generated KeyRepeatEvent a real held-down key
          // produces -- confirmed empirically before writing this test,
          // `WidgetController` only exposes down/up helpers. This bar's own
          // interceptor is a single `Focus(onKeyEvent: _handleKeyEvent)`
          // wrapper (see that method's doc comment), found here and
          // invoked directly with a synthetic `KeyRepeatEvent` instead.
          final Focus interceptor = tester.widget<Focus>(
            find.byWidgetPredicate(
              (Widget widget) => widget is Focus && widget.onKeyEvent != null,
            ),
          );
          final KeyEventResult result = interceptor.onKeyEvent!(
            focusNode,
            const KeyRepeatEvent(
              physicalKey: PhysicalKeyboardKey.enter,
              logicalKey: LogicalKeyboardKey.enter,
              timeStamp: Duration.zero,
            ),
          );

          expect(result, KeyEventResult.handled);
          expect(submissions, <String>['こんにちは']);

          controller.dispose();
          focusNode.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'iOS: the Enter key does not call onSubmit -- on a phone, the return '
      'key always means "insert a newline"; submitting only ever happens '
      'through the on-screen submit button',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          final List<String> submissions = <String>[];
          final TextEditingController controller = TextEditingController();
          final FocusNode focusNode = FocusNode();

          await tester.pumpWidget(
            _wrap(
              CruxInputBar(
                controller: controller,
                focusNode: focusNode,
                maxLines: 5,
                onSubmit: submissions.add,
              ),
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          controller.text = 'こんにちは';
          await tester.pump();

          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();

          expect(submissions, isEmpty);

          controller.dispose();
          focusNode.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  group('enabled: false', () {
    testWidgets('rejects typed input', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await tester.pumpWidget(
        _wrap(CruxInputBar(enabled: false, onChanged: changes.add)),
      );

      final CupertinoTextField field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.enabled, isFalse);

      await tester.enterText(find.byType(CupertinoTextField), 'x');
      await tester.pump();

      expect(changes, isEmpty);
    });

    testWidgets(
      'does not invoke onSubmit or onChanged when the submit/clear buttons '
      'are tapped',
      (WidgetTester tester) async {
        final List<String> submissions = <String>[];
        final List<String> changes = <String>[];
        final TextEditingController controller = TextEditingController(
          text: 'こんにちは',
        );
        addTearDown(controller.dispose);
        const Key submitIconKey = Key('submit-icon');
        const Key clearIconKey = Key('clear-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              enabled: false,
              submit: CruxInputBarSubmit(
                icon: _icon(submitIconKey, const Color(0xFF336699)),
                label: '送信',
              ),
              clear: CruxInputBarClear(
                icon: _icon(clearIconKey, const Color(0xFF996633)),
                label: '消去',
              ),
              onSubmit: submissions.add,
              onChanged: changes.add,
            ),
          ),
        );

        await tester.tap(find.byKey(submitIconKey), warnIfMissed: false);
        await tester.pump();
        await tester.tap(find.byKey(clearIconKey), warnIfMissed: false);
        await tester.pump();

        expect(submissions, isEmpty);
        expect(changes, isEmpty);
        expect(controller.text, 'こんにちは');
      },
    );
  });

  group('ambient theme isolation (regression)', () {
    // Same class of bug, and the same wrap-in-a-garish-MaterialApp
    // technique, as text_form_field_test.dart's identically named group:
    // CruxInputBar shares `_CruxTextFieldCore` (per handoff.md's H5),
    // whose whole reason for existing is to seal exactly this leak once so
    // every field built on top of it (this one included) inherits the
    // fix -- these tests exist to confirm CruxInputBar actually goes
    // through that shared core rather than talking to `CupertinoTextField`
    // directly.
    Widget wrapInGarishMaterialApp(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: Colors.purple),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.purple,
            selectionColor: Colors.purple,
          ),
        ),
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      );
    }

    testWidgets(
      "resolves the cursor and selection-highlight colors from Crux's "
      'own accent token even inside a garish ambient MaterialApp theme',
      (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          wrapInGarishMaterialApp(CruxInputBar(focusNode: focusNode)),
        );

        focusNode.requestFocus();
        await tester.pump();

        final EditableText editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        expect(editableText.cursorColor, CruxColors.light.accent);
        expect(editableText.selectionColor, CruxColors.light.accentTint);
      },
    );

    testWidgets(
      "matches the on-screen keyboard's brightness to Crux's own theme "
      'brightness rather than the ambient platform brightness',
      (WidgetTester tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

        // No CruxTheme is provided, so this falls back to
        // CruxThemeData.light() -- the opposite of the platform
        // brightness forced above.
        await tester.pumpWidget(_wrap(CruxInputBar()));

        final EditableText editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        expect(editableText.keyboardAppearance, Brightness.light);
      },
    );
  });

  group('semantics', () {
    testWidgets(
      'exposes the submit button as button:true with the supplied label',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        const Key iconKey = Key('submit-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              submit: CruxInputBarSubmit(
                icon: _icon(iconKey, const Color(0xFF336699)),
                label: '送信',
              ),
            ),
          ),
        );

        final Semantics semantics = tester.widget<Semantics>(
          find.ancestor(
            of: find.byKey(iconKey),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is Semantics && widget.properties.button == true,
            ),
          ),
        );
        expect(semantics.properties.button, isTrue);
        expect(semantics.properties.label, '送信');

        handle.dispose();
      },
    );

    testWidgets(
      'exposes the clear button as button:true with the supplied label',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final TextEditingController controller = TextEditingController(
          text: 'こんにちは',
        );
        addTearDown(controller.dispose);
        const Key iconKey = Key('clear-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              clear: CruxInputBarClear(
                icon: _icon(iconKey, const Color(0xFF996633)),
                label: '消去',
              ),
            ),
          ),
        );

        final Semantics semantics = tester.widget<Semantics>(
          find.ancestor(
            of: find.byKey(iconKey),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is Semantics && widget.properties.button == true,
            ),
          ),
        );
        expect(semantics.properties.button, isTrue);
        expect(semantics.properties.label, '消去');

        handle.dispose();
      },
    );

    testWidgets('exposes the field itself as a text field, following enabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(CruxInputBar(enabled: false)));

      final SemanticsNode node = tester.getSemantics(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics && widget.properties.textField == true,
        ),
      );
      expect(node.flagsCollection.isTextField, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('right-to-left layout (RTL)', () {
    testWidgets(
      'places leading at the trailing (right) edge and clear/submit at the '
      'leading (left) edge under RTL -- the implementation uses '
      'AlignmentDirectional/EdgeInsetsDirectional throughout rather than '
      'plain Alignment specifically so this flips; this confirms it '
      'actually does, rather than leaving that claim untested',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController(
          text: 'こんにちは',
        );
        addTearDown(controller.dispose);
        const Key leadingIconKey = Key('leading-icon');
        const Key clearIconKey = Key('clear-icon');
        const Key submitIconKey = Key('submit-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              leading: CruxInputBarLeading(
                icon: _icon(leadingIconKey, const Color(0xFF888888)),
              ),
              clear: CruxInputBarClear(
                icon: _icon(clearIconKey, const Color(0xFF996633)),
                label: '消去',
              ),
              submit: CruxInputBarSubmit(
                icon: _icon(submitIconKey, const Color(0xFF336699)),
                label: '送信',
              ),
            ),
            textDirection: TextDirection.rtl,
          ),
        );
        await tester.pumpAndSettle();

        final double boxCenterX = tester.getRect(_boxFinder()).center.dx;
        final double leadingCenterX = tester
            .getRect(find.byKey(leadingIconKey))
            .center
            .dx;
        final double clearCenterX = tester
            .getRect(find.byKey(clearIconKey))
            .center
            .dx;
        final double submitCenterX = tester
            .getRect(find.byKey(submitIconKey))
            .center
            .dx;

        // In RTL, "start" is the box's right edge and "end" is its left
        // edge -- the opposite of LTR. Leading sits at the start edge,
        // clear/submit at the end edge (see the class doc's "The morph
        // itself" section).
        expect(leadingCenterX, greaterThan(boxCenterX));
        expect(clearCenterX, lessThan(boxCenterX));
        expect(submitCenterX, lessThan(boxCenterX));
        // Clear and submit also keep their own relative reading order along
        // that edge (clear nearer the box's center, submit nearest the true
        // left edge) rather than both landing on the correct side but in a
        // scrambled order relative to each other.
        expect(clearCenterX, greaterThan(submitCenterX));
      },
    );
  });

  group('narrow width (IB-D12 / IB-08)', () {
    testWidgets(
      'lays out without throwing under a 200 logical pixel width, even '
      'with a leading icon, a clear button, and a submit button all '
      'present at once',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        const Key leadingIconKey = Key('leading-icon');
        const Key clearIconKey = Key('clear-icon');
        const Key submitIconKey = Key('submit-icon');

        await tester.pumpWidget(
          _wrap(
            CruxInputBar(
              controller: controller,
              leading: CruxInputBarLeading(
                icon: _icon(leadingIconKey, const Color(0xFF888888)),
              ),
              clear: CruxInputBarClear(
                icon: _icon(clearIconKey, const Color(0xFF996633)),
                label: '消去',
              ),
              submit: CruxInputBarSubmit(
                icon: _icon(submitIconKey, const Color(0xFF336699)),
                label: '送信',
              ),
            ),
            width: 200,
          ),
        );
        expect(tester.takeException(), isNull);

        controller.text = 'こんにちは';
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // "Throws no exception" alone is not enough: `Align`/`Positioned`
        // (what leading/clear/submit are each built on -- see the class
        // doc's "The morph itself" section) never raise a `RenderFlex`
        // -style overflow error the way a `Row` does when a child wants
        // more room than it is given. Confirmed empirically before writing
        // this assertion (not assumed): deliberately widening the leading
        // slot's own inner `SizedBox` well past its intended 44 logical
        // pixels, at this same 200-pixel box width, throws nothing and
        // does not even push the icon outside the box's own bounds --
        // `BoxConstraints` clamps the oversized request back down to
        // whatever room the box actually has, so a plain "is this icon's
        // rect contained within the box's rect" check cannot tell the two
        // cases apart. What *does* differ is where inside the box the icon
        // ends up: correctly, each icon sits within its own 44px slot
        // hugging the box's respective edge; with that slot silently
        // ballooned, the icon drifts in from the edge toward the box's
        // horizontal center instead (because Align now has no room left to
        // offset a same-size child within). Checking each icon's distance
        // from its expected edge, rather than mere containment, is what
        // actually catches that.
        final Rect boxRect = tester.getRect(_boxFinder());
        final double leadingCenterX = tester
            .getRect(find.byKey(leadingIconKey))
            .center
            .dx;
        final double clearCenterX = tester
            .getRect(find.byKey(clearIconKey))
            .center
            .dx;
        final double submitCenterX = tester
            .getRect(find.byKey(submitIconKey))
            .center
            .dx;
        // Thresholds picked from this test's own actually-measured, correct
        // positions at this exact 200px box width (leading ~22px from the
        // left edge; submit ~22px, clear ~66px from the right edge, being
        // the trailing group's first, so furthest-in, child) -- each given
        // comfortable headroom above its own correct distance, but every
        // one still well short of 100 (half this 200px box's own width),
        // so none of them can be satisfied by an icon that has drifted all
        // the way in to the box's center.
        expect(
          leadingCenterX - boxRect.left,
          lessThan(60),
          reason:
              "leading icon drifted away from the box's own leading "
              'edge, toward its center',
        );
        expect(
          boxRect.right - clearCenterX,
          lessThan(90),
          reason:
              "clear icon drifted away from the box's own trailing "
              'edge, toward its center',
        );
        expect(
          boxRect.right - submitCenterX,
          lessThan(60),
          reason:
              "submit icon drifted away from the box's own trailing "
              'edge, toward its center',
        );
      },
    );
  });
}
