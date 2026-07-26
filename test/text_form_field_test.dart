// Behavior tests for CruxTextFormField, per
// unknowns/textfield-atom/plan.md section 4 and handoff.md's agreed seams:
// the public CruxTextFormField widget boundary (rendered geometry, visible
// text, decoration, callback invocations), its integration with Flutter's
// Form (validate()/save()/onSaved), and (in contrast_test.dart) pure color
// math on CruxColors. Private classes, internal state fields, and
// implementation details are never reached into.
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxTextFormField needs to lay
/// out and paint (a [Directionality] plus a bounded width, since the field
/// is a block element that fills its parent) without pulling in a full app
/// shell. No [CruxTheme] is provided deliberately in most tests,
/// exercising the documented fallback to [CruxThemeData.light] (same
/// convention as button_test.dart / switch_test.dart / list_tile_test.dart).
///
/// Also supplies an [Overlay] ancestor: unlike this package's other atoms,
/// [CruxTextFormField] is built on [CupertinoTextField] /
/// `EditableText`, which unconditionally tries to build a selection overlay
/// as soon as it gains focus or its selection changes (confirmed against
/// the Flutter SDK — `EditableTextState._handleSelectionChanged` calls
/// `_createSelectionOverlay`, which asserts an `Overlay` ancestor exists,
/// regardless of whether handles actually end up shown). A plain
/// `Directionality` alone is enough for the geometry-only tests, but any
/// test that focuses the field or enters text needs this.
///
/// The overlay entry's child is wrapped in an [Align]: `Overlay` forces its
/// non-`Positioned` entries to fill its own resolved size with **tight**
/// constraints (confirmed against the Flutter SDK), so without this `Align`
/// every geometry read through this helper (`getSize`, `getTopLeft`,
/// `getRect`) would report a size derived from the fixed test viewport
/// rather than from `CruxTextFormField`'s actual content — a bug that let
/// `test/text_form_field_test.dart`'s "error does not change height" test
/// pass vacuously (it was comparing two readings of the same viewport
/// constant). `Align.performLayout` always calls `constraints.loosen()`
/// before laying out its child, regardless of whether `Align` itself was
/// given tight or loose constraints, so the child underneath — here, the
/// whole `CruxTextFormField` — gets a *bounded* but *loose* box
/// (`0 <= width <= [width]`, `0 <= height <= viewport height`) and sizes
/// itself to its own content, the way it would inside any ordinary,
/// non-`Overlay` parent such as a `Column`. `topLeft` keeps the widget
/// pinned to the corner so its absolute on-screen position stays
/// predictable across states with different content heights (a centered
/// `Align` would otherwise shift the whole field vertically whenever total
/// height changed, adding noise to `getTopLeft`/`getRect` comparisons).
///
/// Routes [child] through [_OverlayHost] rather than passing it straight
/// into an `OverlayEntry` built inline here. `OverlayState.initState`
/// consumes `Overlay.initialEntries` exactly once (confirmed against the
/// Flutter SDK — there is no `OverlayState.didUpdateWidget` that re-syncs
/// its entry list from a later, different `initialEntries` value), so a
/// **second** `tester.pumpWidget(_wrap(aDifferentChild))` call in the same
/// test — a pattern several tests in this file use, to observe a widget
/// after some external input changes — would otherwise silently keep
/// rendering the *first* call's `child` forever: the first call's
/// `OverlayEntry` stays permanently installed, and a closure that captured
/// `child` as `_wrap`'s own local parameter can never see the second call's
/// value (confirmed with a minimal repro: `find.text('B')` found nothing
/// after `pumpWidget(wrap(Text('A')))` then `pumpWidget(wrap(Text('B')))`
/// through the equivalent of this helper's original, pre-`_OverlayHost`
/// form). `_OverlayHost` avoids this because its `OverlayEntry.builder`
/// reads `widget.child` — a live property lookup on its own, preserved
/// `State`, which Flutter's ordinary `StatefulElement.update()` keeps in
/// sync on every rebuild — instead of a value frozen inside `_wrap`'s own
/// closure.
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

/// See [_wrap]'s doc comment for why this exists instead of building the
/// `Overlay`/`OverlayEntry` directly inline in `_wrap`.
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

/// Wraps [child] in a [MaterialApp] whose [ThemeData] uses a loud,
/// obviously-not-Crux color for text selection (an explicit
/// `textSelectionTheme`, not left to Material 3's own baseline-purple
/// default, so this test's expectations don't depend on Flutter's internal
/// default-derivation logic ever changing).
///
/// Used to catch the class of bug where an ambient Material `Theme` leaks
/// into Crux's own look: both `Theme` and `MaterialApp` install a
/// `DefaultSelectionStyle` (`material/theme.dart`'s `_wrapsWidgetThemes`,
/// sourced from `ThemeData.textSelectionTheme`) that `CupertinoTextField`
/// consults *before* its own `CupertinoTheme.primaryColor` fallback
/// (`cupertino/text_field.dart`'s `cursorColor`/`selectionColor`
/// resolution). None of this file's other tests pump with a `MaterialApp`
/// ancestor, so none of them can install a `DefaultSelectionStyle` and this
/// class of bug was invisible to the existing suite — see
/// `unknowns/textfield-atom/implementation-notes.md`'s "Defects found in
/// review" section.
Widget _wrapInGarishMaterialApp(Widget child) {
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

/// Finds the box [Container] (the one with a border, drawn by
/// CruxTextFormField itself) inside a rendered [CruxTextFormField].
/// Distinguished from [CupertinoTextField]'s own internal (undecorated,
/// since an empty `BoxDecoration` is passed to it) [Container] by requiring
/// a [ShapeDecoration] whose shape is a [RoundedSuperellipseBorder] with an
/// actual border side present, the same predicate-finder convention
/// switch_test.dart's `_trackFinder` uses.
Finder _boxFinder() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! Container) {
      return false;
    }
    final Decoration? decoration = widget.decoration;
    if (decoration is! ShapeDecoration) {
      return false;
    }
    final ShapeBorder shape = decoration.shape;
    return shape is RoundedSuperellipseBorder &&
        shape.side.style != BorderStyle.none;
  });
}

/// Reads the horizontal component of the shake offset [CruxMotion.shake]
/// applies to the box (2026-07-26: narrowed from the whole field -- see
/// implementation-notes.md's dated reversal entry), by locating the
/// `Transform` it wraps the box in and reading the (0, 3) entry of its 4x4
/// matrix -- the same "read the transform matrix directly" convention
/// button_test.dart's press-animation test uses for its (0, 0) scale entry.
///
/// Returns `null` if no such `Transform` exists at all. This distinguishes
/// "not currently shaking" (a `Transform` present with a zero offset) from
/// "the shake wrapper isn't even in the tree" (the reduce-motion path,
/// which per its own contract bypasses the wrapper entirely rather than
/// animating it to a standstill -- see the "reduce motion" group below).
double? _shakeDx(WidgetTester tester) {
  final Finder finder = find.descendant(
    of: find.byType(CruxTextFormField),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Transform>(finder).transform.entry(0, 3);
}

void main() {
  group('placeholder', () {
    testWidgets('renders inside the box when the value is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxTextFormField(label: 'メールアドレス', placeholder: 'you@example.com'),
        ),
      );

      final Rect boxRect = tester.getRect(_boxFinder());
      final Rect placeholderRect = tester.getRect(find.text('you@example.com'));

      expect(boxRect.top, lessThanOrEqualTo(placeholderRect.top));
      expect(boxRect.bottom, greaterThanOrEqualTo(placeholderRect.bottom));
    });

    testWidgets('is gone once the value is non-empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxTextFormField(
            label: 'メールアドレス',
            placeholder: 'you@example.com',
            initialValue: 'crux@example.com',
          ),
        ),
      );

      // CupertinoTextField keeps the placeholder Text mounted (`Visibility(
      // maintainState: true, maintainAnimation: true, maintainSize: true,
      // ...)`, confirmed against the Flutter SDK,
      // cupertino/text_field.dart's `_buildDecoration`) so it can animate
      // back in without rebuilding from scratch, rather than removing it
      // from the tree -- so `find.text('you@example.com')` still finds a
      // widget instance here. What actually makes it "gone" is that
      // `Visibility.visible` is false; that is the property this asserts.
      final Visibility placeholderVisibility = tester.widget<Visibility>(
        find.ancestor(
          of: find.text('you@example.com'),
          matching: find.byType(Visibility),
        ),
      );
      expect(placeholderVisibility.visible, isFalse);
    });
  });

  group('label', () {
    testWidgets('renders above the box when the value is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

      final Rect boxRect = tester.getRect(_boxFinder());
      final Rect labelRect = tester.getRect(find.text('メールアドレス'));

      expect(labelRect.bottom, lessThanOrEqualTo(boxRect.top));
    });

    testWidgets(
      'still renders above the box once the value is non-empty -- the '
      'label is static per widget configuration and no longer moves',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', controller: controller)),
        );
        final Rect labelRectWhenEmpty = tester.getRect(find.text('メールアドレス'));

        controller.text = 'a';
        await tester.pumpAndSettle();

        final Rect boxRect = tester.getRect(_boxFinder());
        final Rect labelRectWhenFilled = tester.getRect(find.text('メールアドレス'));

        expect(labelRectWhenFilled.bottom, lessThanOrEqualTo(boxRect.top));
        // The label did not move: its position is identical before and
        // after typing, unlike the old floating-label animation this
        // replaced.
        expect(labelRectWhenFilled, labelRectWhenEmpty);
      },
    );
  });

  group('box position (regression guard)', () {
    testWidgets("the box's own top-left position does not move when the value "
        'changes from empty to non-empty -- this used to be the highest'
        '-value invariant in this file, guarding against the label\'s '
        "floating animation nudging the box; now that the label is static, "
        "this is a structurally trivial consequence of a plain Column with "
        "no value-dependent branching above the box. Kept as an explicit "
        "regression guard anyway -- see implementation-notes.md for a "
        'mutation-check confirming it still fails if that ever changes.', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxTextFormField(label: 'メールアドレス', controller: controller)),
      );
      final Offset emptyBoxTopLeft = tester.getTopLeft(_boxFinder());

      controller.text = 'a';
      await tester.pumpAndSettle();

      final Offset filledBoxTopLeft = tester.getTopLeft(_boxFinder());
      expect(filledBoxTopLeft, emptyBoxTopLeft);
    });
  });

  group('label omitted', () {
    testWidgets(
      'a field with no label has no label row, and is shorter than the '
      'same field with a label',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(CruxTextFormField()));
        expect(find.text('メールアドレス'), findsNothing);
        final double heightWithoutLabel = tester
            .getSize(find.byType(CruxTextFormField))
            .height;

        await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));
        final double heightWithLabel = tester
            .getSize(find.byType(CruxTextFormField))
            .height;

        expect(heightWithoutLabel, lessThan(heightWithLabel));
      },
    );
  });

  group('label color', () {
    testWidgets('renders the label in CruxColors.light.textSecondary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

      final Text label = tester.widget<Text>(find.text('メールアドレス'));
      expect(label.style?.color, CruxColors.light.textSecondary);
    });

    testWidgets('renders the label in CruxColors.dark.textSecondary under '
        'a dark CruxTheme', (WidgetTester tester) async {
      await tester.pumpWidget(
        CruxTheme(
          data: CruxThemeData.dark(),
          child: _wrap(CruxTextFormField(label: 'メールアドレス')),
        ),
      );

      final Text label = tester.widget<Text>(find.text('メールアドレス'));
      expect(label.style?.color, CruxColors.dark.textSecondary);
    });
  });

  group('placeholder color', () {
    testWidgets(
      'renders the placeholder in CruxColors.light.textSecondary -- the '
      'user chose textSecondary over muted for contrast, so the '
      'placeholder uses the same token the label does',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxTextFormField(placeholder: 'you@example.com')),
        );

        final CupertinoTextField field = tester.widget<CupertinoTextField>(
          find.byType(CupertinoTextField),
        );
        expect(field.placeholderStyle?.color, CruxColors.light.textSecondary);
      },
    );
  });

  group('RTL (regression, now structural)', () {
    // Previously, the label was drawn with a raw `Positioned`/
    // `PositionedDirectional` overlay whose horizontal offset had to be
    // computed by hand -- exactly the kind of code that can silently fail
    // to mirror under RTL (this test used to catch a real regression of
    // that shape). The label is now a plain `Text` laid out in normal
    // document flow inside a `Column`, with no custom positioning code of
    // any kind, so RTL correctness comes entirely from Flutter's own
    // `Directionality`-aware layout rather than from anything
    // CruxTextFormField writes itself. There is no longer a bespoke
    // positioning calculation for this test to regression-guard; what
    // remains worth asserting is that the field still lays out sanely
    // (label above the box, no exceptions) under RTL. Visual RTL coverage
    // continues to live in widgetbook/lib/usecases/text_form_field.dart's
    // Edge cases use case.
    testWidgets(
      'lays out the label above the box under RTL too, without error',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxTextFormField(label: 'メールアドレス'),
            textDirection: TextDirection.rtl,
          ),
        );

        final Rect boxRect = tester.getRect(_boxFinder());
        final Rect labelRect = tester.getRect(find.text('メールアドレス'));

        expect(labelRect.bottom, lessThanOrEqualTo(boxRect.top));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('typing', () {
    testWidgets('invokes onChanged with the newly entered text', (
      WidgetTester tester,
    ) async {
      final List<String> notifications = <String>[];
      await tester.pumpWidget(
        _wrap(
          CruxTextFormField(label: 'メールアドレス', onChanged: notifications.add),
        ),
      );

      await tester.enterText(find.byType(CupertinoTextField), 'crux');
      await tester.pump();

      expect(notifications, <String>['crux']);
    });
  });

  group('Form integration', () {
    testWidgets(
      'validate() returns false and surfaces the validator message when '
      'the value is invalid',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        );

        final bool isValid = formKey.currentState!.validate();
        await tester.pump();

        expect(isValid, isFalse);
        expect(find.text('必須項目です'), findsOneWidget);
      },
    );

    testWidgets('save() invokes onSaved with the current value', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      String? saved;
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CruxTextFormField(
              label: 'メールアドレス',
              initialValue: 'crux@example.com',
              onSaved: (String? value) => saved = value,
            ),
          ),
        ),
      );

      formKey.currentState!.save();

      expect(saved, 'crux@example.com');
    });
  });

  group('error / helper row', () {
    testWidgets(
      "showing a validation error does not change the field's total height",
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        Widget buildForm() => _wrap(
          Form(
            key: formKey,
            child: CruxTextFormField(
              label: 'メールアドレス',
              helperText: 'you@example.com',
              validator: (String? value) =>
                  (value == null || value.isEmpty) ? '必須項目です' : null,
            ),
          ),
        );

        await tester.pumpWidget(buildForm());
        final double heightBeforeError = tester
            .getSize(find.byType(CruxTextFormField))
            .height;

        formKey.currentState!.validate();
        await tester.pump();

        final double heightWithError = tester
            .getSize(find.byType(CruxTextFormField))
            .height;

        expect(heightWithError, heightBeforeError);
        expect(find.text('必須項目です'), findsOneWidget);
      },
    );
  });

  group('caption weight (validation error)', () {
    // 2026-07-26: user request "エラー文言を太くして目立たせたい" (make the
    // error message bolder so it stands out). The caption row already
    // recolors to CruxColors.error (see the "focus" group above); this
    // adds a second, independent emphasis cue -- weight -- to the error
    // case specifically, while leaving plain helper text at its normal
    // weight. See implementation-notes.md's dated entry for why this is a
    // component-level `copyWith(fontWeight:)` rather than a new typography
    // token or a change to `caption` itself.
    testWidgets('renders the error caption at FontWeight.w600, bolder than the '
        'resting caption style', (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CruxTextFormField(
              label: 'メールアドレス',
              validator: (String? value) =>
                  (value == null || value.isEmpty) ? '必須項目です' : null,
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      final Text caption = tester.widget<Text>(find.text('必須項目です'));
      expect(caption.style?.fontWeight, FontWeight.w600);
    });

    testWidgets(
      'keeps the helper caption (no error showing) at FontWeight.w400 -- '
      'only a showing validation error gets the bolder weight',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxTextFormField(
              label: 'メールアドレス',
              helperText: 'you@example.com',
            ),
          ),
        );

        final Text caption = tester.widget<Text>(find.text('you@example.com'));
        expect(caption.style?.fontWeight, FontWeight.w400);
      },
    );
  });

  group('shake animation (validation error)', () {
    // 2026-07-26: the shake was narrowed from the whole field down to just
    // the box -- the label above and the caption/error row below must stay
    // perfectly still while only the box shakes. This reverses the
    // "whole field shakes together" call recorded in
    // implementation-notes.md's original "Post-milestone addition:
    // validation-error shake animation" entry; see that file's dated
    // reversal entry for the full history. The four tests immediately below
    // assert, with real positional reads (not just "a Transform exists
    // somewhere"), that: (1) the box itself is offset mid-shake, (2) the
    // label does not move, (3) the caption/error text does not move, and
    // (4) the box returns to exactly its resting position once the shake
    // settles.
    testWidgets(
      'an error appearing offsets the box horizontally mid-animation, and '
      'settles back to exactly its resting position once the shake '
      'finishes',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        );

        // Baseline: no error yet, so no shake has ever played.
        expect(_shakeDx(tester), 0.0);
        final Offset restingBoxTopLeft = tester.getTopLeft(_boxFinder());

        formKey.currentState!.validate();
        await tester.pump();
        // Partway into the shake -- mid-animation, not settled.
        await tester.pump(const Duration(milliseconds: 80));

        // isNotNull first: null (no Transform at all) is technically "not
        // 0.0" too, so isNot(0.0) alone would pass vacuously if the shake
        // wrapper vanished entirely rather than genuinely animating.
        expect(_shakeDx(tester), isNotNull);
        expect(_shakeDx(tester), isNot(0.0));

        // The box's actual on-screen position -- not just the raw matrix
        // entry -- is offset from where it rests.
        final Offset midShakeBoxTopLeft = tester.getTopLeft(_boxFinder());
        expect(midShakeBoxTopLeft, isNot(restingBoxTopLeft));

        await tester.pumpAndSettle();

        expect(_shakeDx(tester), 0.0);
        expect(tester.getTopLeft(_boxFinder()), restingBoxTopLeft);
      },
    );

    testWidgets(
      'mid-shake, the label above the box has not moved at all from its '
      'resting position -- only the box shakes',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        );

        final Rect restingLabelRect = tester.getRect(find.text('メールアドレス'));

        formKey.currentState!.validate();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        // Confirm the shake is actually in flight here, so this test can't
        // pass vacuously if the shake never started.
        expect(_shakeDx(tester), isNotNull);
        expect(_shakeDx(tester), isNot(0.0));

        expect(tester.getRect(find.text('メールアドレス')), restingLabelRect);
      },
    );

    testWidgets(
      'mid-shake, the caption/error text below the box has not moved at '
      'all from its resting position -- only the box shakes',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        );

        // First failed validate: let the shake fully settle so the error
        // caption is showing and at rest before capturing its resting
        // position.
        formKey.currentState!.validate();
        await tester.pumpAndSettle();
        final Rect restingCaptionRect = tester.getRect(find.text('必須項目です'));

        // Same invalid value, same validator, same message -- errorText
        // does not change on this second call, but it shakes again anyway
        // (see the "pressing submit a second time" test below), giving a
        // second mid-shake window to sample the caption's position in.
        formKey.currentState!.validate();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        // Confirm the shake is actually in flight here, so this test can't
        // pass vacuously if the shake never started.
        expect(_shakeDx(tester), isNotNull);
        expect(_shakeDx(tester), isNot(0.0));

        expect(tester.getRect(find.text('必須項目です')), restingCaptionRect);
      },
    );

    testWidgets(
      'pressing submit a second time with the identical error message '
      'shakes again, even though errorText itself did not change -- a '
      'naive "did errorText change" trigger would silently do nothing here, '
      'but this is the common real case: the user presses the button again',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pumpAndSettle();
        expect(_shakeDx(tester), 0.0);
        expect(find.text('必須項目です'), findsOneWidget);

        // Same invalid value, same validator, same message -- errorText
        // does not change on this second call.
        formKey.currentState!.validate();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        // isNotNull first: null (no Transform at all) is technically "not
        // 0.0" too, so isNot(0.0) alone would pass vacuously if the shake
        // wrapper vanished entirely rather than genuinely animating.
        expect(_shakeDx(tester), isNotNull);
        expect(_shakeDx(tester), isNot(0.0));
      },
    );

    testWidgets('applies no offset at all, ever, when the OS reduce-motion '
        'accessibility setting is on -- the field still turns red and shows '
        'its error message, but the shake itself is fully suppressed rather '
        'than merely shortened', (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // No Transform wrapper at all: the shake primitive is bypassed
      // entirely rather than animated to a standstill (see _shakeDx's
      // doc for why `null` -- not `0.0` -- is the signal for this).
      expect(_shakeDx(tester), isNull);

      // The rest of the error presentation is unaffected by reduce
      // motion: the message still shows and the box still turns red.
      expect(find.text('必須項目です'), findsOneWidget);
      final ShapeDecoration decoration =
          tester.widget<Container>(_boxFinder()).decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(shape.side, BorderSide(color: CruxColors.light.error));
    });

    testWidgets(
      'shaking mid-animation moves neither a sibling widget below the '
      "field nor the field's own reported size -- it is a paint-time "
      'transform only',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        const Key siblingKey = Key('sibling-below-field');
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CruxTextFormField(
                    label: 'メールアドレス',
                    validator: (String? value) =>
                        (value == null || value.isEmpty) ? '必須項目です' : null,
                  ),
                  const SizedBox(key: siblingKey, height: 20),
                ],
              ),
            ),
          ),
        );

        final Size fieldSizeBefore = tester.getSize(
          find.byType(CruxTextFormField),
        );
        final Offset siblingTopLeftBefore = tester.getTopLeft(
          find.byKey(siblingKey),
        );

        formKey.currentState!.validate();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        // Confirm the shake is actually in flight here, so this test can't
        // pass vacuously if the shake never started.
        // isNotNull first: null (no Transform at all) is technically "not
        // 0.0" too, so isNot(0.0) alone would pass vacuously if the shake
        // wrapper vanished entirely rather than genuinely animating.
        expect(_shakeDx(tester), isNotNull);
        expect(_shakeDx(tester), isNot(0.0));

        expect(
          tester.getSize(find.byType(CruxTextFormField)),
          fieldSizeBefore,
        );
        expect(tester.getTopLeft(find.byKey(siblingKey)), siblingTopLeftBefore);
      },
    );
  });

  group('focus', () {
    testWidgets(
      "focusing the field does not change the box's ShapeDecoration",
      (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', focusNode: focusNode)),
        );
        final ShapeDecoration decorationBeforeFocus =
            tester.widget<Container>(_boxFinder()).decoration!
                as ShapeDecoration;
        final RoundedSuperellipseBorder shapeBeforeFocus =
            decorationBeforeFocus.shape as RoundedSuperellipseBorder;

        // The resting border is exactly CruxColors.light.separator at 1
        // logical pixel, not just "whatever it happens to be" —
        // BorderSide's default width is 1.0, so this equality pins both
        // color and width, against an independent expected value rather
        // than a self-comparison.
        expect(
          shapeBeforeFocus.side,
          BorderSide(color: CruxColors.light.separator),
        );

        focusNode.requestFocus();
        // A second pump is required here, not one.
        // AutomatedTestWidgetsFlutterBinding.pump() checks hasScheduledFrame
        // before flushing the microtask queue that runs the focus manager's
        // deferred notification (confirmed against the Flutter SDK), so a
        // single pump after requestFocus() does not yet reflect a
        // Listenable-driven rebuild keyed off FocusNode.hasFocus. A prior
        // version of this test pumped only once, which let a
        // border-changes-on-focus mutation slip through undetected — see
        // implementation-notes.md.
        await tester.pump();
        await tester.pump();

        final ShapeDecoration decorationAfterFocus =
            tester.widget<Container>(_boxFinder()).decoration!
                as ShapeDecoration;

        expect(decorationAfterFocus, decorationBeforeFocus);
      },
    );

    testWidgets(
      'resolves the resting border from CruxColors.dark.separator under a '
      'dark CruxTheme',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          CruxTheme(
            data: CruxThemeData.dark(),
            child: _wrap(CruxTextFormField(label: 'メールアドレス')),
          ),
        );

        final ShapeDecoration decoration =
            tester.widget<Container>(_boxFinder()).decoration!
                as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;

        expect(shape.side, BorderSide(color: CruxColors.dark.separator));
      },
    );

    testWidgets(
      'turns the border to CruxColors.light.error, matching the caption, '
      'once a validation error is showing — per the revised class doc, the '
      'error state colors both the box and the caption row',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CruxTextFormField(
                label: 'メールアドレス',
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? '必須項目です' : null,
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        final ShapeDecoration decoration =
            tester.widget<Container>(_boxFinder()).decoration!
                as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;
        expect(shape.side, BorderSide(color: CruxColors.light.error));

        final Text caption = tester.widget<Text>(find.text('必須項目です'));
        expect(caption.style?.color, CruxColors.light.error);
      },
    );

    testWidgets(
      'turns the border to CruxColors.dark.error once a validation error '
      'is showing under a dark CruxTheme',
      (WidgetTester tester) async {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          CruxTheme(
            data: CruxThemeData.dark(),
            child: _wrap(
              Form(
                key: formKey,
                child: CruxTextFormField(
                  label: 'メールアドレス',
                  validator: (String? value) =>
                      (value == null || value.isEmpty) ? '必須項目です' : null,
                ),
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        final ShapeDecoration decoration =
            tester.widget<Container>(_boxFinder()).decoration!
                as ShapeDecoration;
        final RoundedSuperellipseBorder shape =
            decoration.shape as RoundedSuperellipseBorder;
        expect(shape.side, BorderSide(color: CruxColors.dark.error));
      },
    );

    testWidgets('does not change the error-state border when the field is also '
        'focused — focus still changes nothing, even on top of an error', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CruxTextFormField(
              label: 'メールアドレス',
              focusNode: focusNode,
              validator: (String? value) =>
                  (value == null || value.isEmpty) ? '必須項目です' : null,
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      final ShapeDecoration decorationBeforeFocus =
          tester.widget<Container>(_boxFinder()).decoration! as ShapeDecoration;
      final RoundedSuperellipseBorder shapeBeforeFocus =
          decorationBeforeFocus.shape as RoundedSuperellipseBorder;
      expect(
        shapeBeforeFocus.side,
        BorderSide(color: CruxColors.light.error),
      );

      focusNode.requestFocus();
      // See the resting-border focus test above for why two pumps are
      // required here.
      await tester.pump();
      await tester.pump();

      final ShapeDecoration decorationAfterFocus =
          tester.widget<Container>(_boxFinder()).decoration! as ShapeDecoration;
      expect(decorationAfterFocus, decorationBeforeFocus);
    });
  });

  group('box fill', () {
    testWidgets('fills the box with CruxColors.light.controlFill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

      final ShapeDecoration decoration =
          tester.widget<Container>(_boxFinder()).decoration! as ShapeDecoration;

      expect(decoration.color, CruxColors.light.controlFill);
    });

    testWidgets('fills the box with CruxColors.dark.controlFill under a dark '
        'CruxTheme', (WidgetTester tester) async {
      await tester.pumpWidget(
        CruxTheme(
          data: CruxThemeData.dark(),
          child: _wrap(CruxTextFormField(label: 'メールアドレス')),
        ),
      );

      final ShapeDecoration decoration =
          tester.widget<Container>(_boxFinder()).decoration! as ShapeDecoration;

      expect(decoration.color, CruxColors.dark.controlFill);
    });
  });

  group('disabled', () {
    testWidgets('rejects input and renders the whole field at 55% opacity', (
      WidgetTester tester,
    ) async {
      final List<String> notifications = <String>[];
      await tester.pumpWidget(
        _wrap(
          CruxTextFormField(
            label: 'メールアドレス',
            enabled: false,
            onChanged: notifications.add,
          ),
        ),
      );

      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(CruxTextFormField),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.55);

      await tester.enterText(find.byType(CupertinoTextField), 'x');
      await tester.pump();

      expect(notifications, isEmpty);
    });
  });

  group('disabling mid-edit (regression)', () {
    testWidgets(
      'does not throw when the field is disabled while it is focused and '
      'mid-edit, mirroring the same hazard covered for CruxButton/'
      'CruxSwitch/CruxListTile',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        final FocusNode focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        Widget buildField(bool enabled) => _wrap(
          CruxTextFormField(
            label: 'メールアドレス',
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
          ),
        );

        await tester.pumpWidget(buildField(true));

        await tester.enterText(find.byType(CupertinoTextField), 'crux');
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        // Disable the field while it is still focused and mid-edit, the
        // same way a common "lock the form while submitting" pattern would.
        await tester.pumpWidget(buildField(false));

        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('focusNode lifecycle (regression)', () {
    // These four cases are the full cross-product of "was focusNode
    // supplied externally before/after a rebuild": null→null (no-op),
    // external→null, null→external, and external→a different external.
    // Confirmed against the Flutter SDK: `EditableText`'s `focusNode` field
    // is passed straight through from `_CruxTextFieldCore`, so
    // `tester.widget<EditableText>(...).focusNode` reads the exact
    // `FocusNode` instance CruxTextFormField is currently using — the
    // same already-established pattern this file's "ambient theme
    // isolation" group uses to read `EditableText.cursorColor` etc.
    // `ChangeNotifier.debugAssertNotDisposed` (public API, not a reach into
    // this package's private state) is used to observe whether a captured
    // node has been disposed, since `FocusNode` exposes no public
    // "isDisposed" getter.

    testWidgets(
      'keeps the same internally-created FocusNode across a rebuild when '
      'focusNode stays null throughout',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', helperText: 'a')),
        );
        final FocusNode before = tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode;

        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', helperText: 'b')),
        );
        final FocusNode after = tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode;

        expect(identical(before, after), isTrue);
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(before),
          returnsNormally,
        );
      },
    );

    testWidgets('falls back to a fresh internally-created FocusNode, without '
        'crashing, when an externally supplied one is later removed '
        '(regression: this used to throw "Null check operator used on a '
        'null value")', (WidgetTester tester) async {
      final FocusNode externalNode = FocusNode();
      addTearDown(externalNode.dispose);

      await tester.pumpWidget(
        _wrap(CruxTextFormField(label: 'メールアドレス', focusNode: externalNode)),
      );

      await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

      expect(tester.takeException(), isNull);

      final FocusNode fallbackNode = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(fallbackNode, isNot(same(externalNode)));

      // The fallback node is a real, live, working FocusNode, not just a
      // non-null placeholder.
      fallbackNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(fallbackNode.hasFocus, isTrue);
    });

    testWidgets(
      'disposes the internally-created FocusNode once an external one is '
      'supplied in its place, instead of leaking it (regression)',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

        final FocusNode internalNode = tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode;

        final FocusNode externalNode = FocusNode();
        addTearDown(externalNode.dispose);

        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', focusNode: externalNode)),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).focusNode,
          same(externalNode),
        );
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(internalNode),
          throwsFlutterError,
        );
      },
    );

    testWidgets(
      'switches straight to a different externally supplied FocusNode '
      'without crashing or disposing either caller-owned node',
      (WidgetTester tester) async {
        final FocusNode nodeA = FocusNode();
        addTearDown(nodeA.dispose);
        final FocusNode nodeB = FocusNode();
        addTearDown(nodeB.dispose);

        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', focusNode: nodeA)),
        );
        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', focusNode: nodeB)),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).focusNode,
          same(nodeB),
        );
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(nodeA),
          returnsNormally,
        );
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(nodeB),
          returnsNormally,
        );
      },
    );
  });

  group('overflow (deliberate departure from the ellipsis rule)', () {
    testWidgets(
      'a very long value scrolls horizontally rather than ellipsizing',
      (WidgetTester tester) async {
        const String longValue =
            'とても長い入力値です。とても長い入力値です。とても長い入力値です。'
            'とても長い入力値です。とても長い入力値です。とても長い入力値です。';

        await tester.pumpWidget(
          _wrap(
            CruxTextFormField(label: 'メモ', initialValue: longValue),
            width: 120,
          ),
        );

        expect(tester.takeException(), isNull);

        // Single-line and horizontally scrollable (Flutter's own single-line
        // EditableText/CupertinoTextField behavior): the full value is
        // still in the tree, unclipped by any ellipsis, and reachable by
        // scrolling rather than truncated.
        final EditableText editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        expect(editableText.maxLines, 1);
        expect(editableText.controller.text, longValue);
        expect(
          find.descendant(
            of: find.byType(CruxTextFormField),
            matching: find.byType(Scrollable),
          ),
          findsWidgets,
        );
      },
    );
  });

  group('semantics', () {
    // CruxTextFormField's own `Semantics(container: true, textField:
    // true, enabled: ...)` is not the outermost Semantics-contributing
    // widget under CruxTextFormField's element: FormFieldState.build
    // (Flutter's own base class) always wraps whatever this widget returns
    // in an extra `Semantics(validationResult: ...)` layer, which does not
    // set `container: true`. tester.getSemantics(find.byType(...)) walks
    // from the *first* render object it finds and only searches upward
    // from there, so anchoring on `find.byType(CruxTextFormField)`
    // resolves to that outer wrapper's node instead of ours. Anchoring on
    // the specific `Semantics` widget that sets `textField: true` (which
    // only our own annotation does -- CupertinoTextField's internal
    // EditableText attaches its semantics via its RenderObject directly,
    // not through a `Semantics` widget) reaches the right node instead.
    Finder ourSemanticsFinder() {
      return find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics && widget.properties.textField == true,
      );
    }

    testWidgets('exposes the textField flag and an enabled=true state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

      final SemanticsNode node = tester.getSemantics(ourSemanticsFinder());
      expect(node.flagsCollection.isTextField, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);

      handle.dispose();
    });

    testWidgets('exposes an enabled=false state when disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxTextFormField(label: 'メールアドレス', enabled: false)),
      );

      final SemanticsNode node = tester.getSemantics(ourSemanticsFinder());
      expect(node.flagsCollection.isTextField, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('ambient theme isolation (regression)', () {
    testWidgets(
      "resolves the cursor and selection-highlight colors from Crux's own "
      'accent token even inside a garish ambient MaterialApp theme, instead '
      "of leaking the app's Material primary color",
      (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrapInGarishMaterialApp(
            CruxTextFormField(label: 'メールアドレス', focusNode: focusNode),
          ),
        );

        // The selection highlight color is only ever passed to EditableText
        // while the field has focus (CupertinoTextField's own build method
        // does `selectionColor: _effectiveFocusNode.hasFocus ? selectionColor
        // : null`), so focus is required to observe it.
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
      'paints no background fill of its own when disabled, honoring the '
      "class doc's stated invariant that the box never gets a fill "
      '(CupertinoTextField internally falls back to a gray fill whenever '
      "decoration is null and the field is disabled, independent of any "
      'ambient theme)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(CruxTextFormField(label: 'メールアドレス', enabled: false)),
        );

        final Finder filledContainers = find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byWidgetPredicate((Widget widget) {
            if (widget is! Container) {
              return false;
            }
            final Color? directColor = widget.color;
            final Decoration? decoration = widget.decoration;
            final Color? decorationColor = decoration is BoxDecoration
                ? decoration.color
                : null;
            return directColor != null || decorationColor != null;
          }),
        );

        expect(filledContainers, findsNothing);
      },
    );

    testWidgets(
      "colors the text-selection drag handles to match Crux's accent "
      "token, not the default CupertinoTheme fallback (iOS's system blue) "
      "(cupertino/text_selection.dart's buildHandle paints the handle with "
      'CupertinoTheme.of(context).selectionHandleColor, so this widget must '
      'set it explicitly on its own CupertinoTheme wrapper rather than '
      'leaving it unset)',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

        final CupertinoTheme cupertinoTheme = tester.widget<CupertinoTheme>(
          find.ancestor(
            of: find.byType(CupertinoTextField),
            matching: find.byType(CupertinoTheme),
          ),
        );

        expect(
          cupertinoTheme.data.selectionHandleColor,
          CruxColors.light.accent,
        );
      },
    );

    testWidgets(
      "matches the on-screen keyboard's light/dark appearance to Crux's "
      'own theme brightness rather than the ambient platform brightness '
      "(CupertinoTextField's default is `widget.keyboardAppearance ?? "
      'CupertinoTheme.brightnessOf(context)`, which falls back to '
      "`MediaQuery.platformBrightnessOf` — a different ambient source than "
      "Material's DefaultSelectionStyle, found during the same audit)",
      (WidgetTester tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

        // No CruxTheme is provided, so this falls back to
        // CruxThemeData.light() (brightness: Brightness.light) — the
        // opposite of the platform brightness forced above.
        await tester.pumpWidget(_wrap(CruxTextFormField(label: 'メールアドレス')));

        final EditableText editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );

        expect(editableText.keyboardAppearance, Brightness.light);
      },
    );
  });
}
