// Behavior tests for CruxComposer, per unknowns/composer/plan.md section 4
// ("テストで固定する") and handoff.md's frozen public API / behavior list.
// Written RED-first, one slice at a time, per the tdd skill and this
// package's own established conventions (see test/input_bar_test.dart's file
// -level doc for the same conventions this file follows): an
// Overlay-inclusive `_wrap` (EditableText unconditionally needs one once
// focus or the text value changes), a `_icon` helper for caller-supplied
// action icons, and `find.byType(EditableText)` to inspect the underlying
// field directly.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        ColorScheme,
        Colors,
        MaterialApp,
        Scaffold,
        TextSelectionThemeData,
        ThemeData;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxComposer needs to lay out,
/// paint, focus, and accept typed input -- see test/input_bar_test.dart's
/// identically-shaped `_wrap`/`_OverlayHost` pair for why the `Overlay` is
/// load-bearing (`EditableText` asserts one exists as soon as focus or the
/// text value changes, not just when the user taps to focus).
///
/// Unlike `CruxInputBar`'s own `_wrap`, this defaults to a bounded
/// [height] as well as width: `CruxComposer` fills whatever height it is
/// given (CP-D02), so most of this file's tests need a tight height, not
/// just a tight width, to observe that at all.
Widget _wrap(
  Widget child, {
  double width = 320,
  double height = 400,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: textDirection,
    child: Center(
      child: SizedBox(
        width: width,
        height: height,
        child: _OverlayHost(child: child),
      ),
    ),
  );
}

/// See [_wrap]'s doc comment. Routes `child` through a `State`'s live
/// `widget.child` property, matching the identical helper in
/// text_form_field_test.dart / input_bar_test.dart.
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

/// A small caller-supplied icon widget for [CruxComposerAction] /
/// [CruxComposerSubmit] test fixtures -- matches
/// test/input_bar_test.dart's identically-shaped `_icon` helper.
Widget _icon(Key key, Color color) {
  return SizedBox(
    width: 20,
    height: 20,
    child: ColoredBox(key: key, color: color),
  );
}

void main() {
  group('bare composer (CP-A01: nothing supplied)', () {
    testWidgets(
      'renders no action row at all when actions is empty, submit is null, '
      'and maxLength is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxComposer()));

        expect(find.byType(CruxButton), findsNothing);
        expect(find.textContaining('/'), findsNothing);
        // Structural, not just content-based: the action row container
        // itself must not exist, not merely render with nothing visible
        // inside it. This single check now also covers the hairline
        // separator, which is painted as a border on this same container
        // (see the maxLength case below) rather than as a standalone
        // widget, so a bare composer staying free of this key proves it
        // stays completely bare (CP-A01), not "bare text area plus a
        // stray line".
        expect(
          find.byKey(const ValueKey('crux_composer_action_row')),
          findsNothing,
        );
      },
    );
  });

  group('maxLength validation', () {
    testWidgets('throws an assertion error when maxLength is negative', (
      WidgetTester tester,
    ) async {
      expect(() => CruxComposer(maxLength: -1), throwsA(isA<AssertionError>()));
    });

    testWidgets('maxLength: 0 lays out without throwing, and the counter reads '
        '"0 / 0" while the text is empty', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const CruxComposer(maxLength: 0)));

      expect(tester.takeException(), isNull);
      expect(find.text('0 / 0'), findsOneWidget);
    });

    testWidgets('buildTextSpan treats a negative overflow limit as "no limit" '
        'instead of crashing -- a defense-in-depth guard for a controller '
        'driven directly, bypassing the widget-level assert', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _captureContext(tester);
      final CruxComposerController controller = CruxComposerController(
        text: 'a' * 5,
      );
      addTearDown(controller.dispose);
      controller.applyOverflowStyle(
        maxLength: -1,
        color: const Color(0xFFFF0000),
      );

      final TextSpan span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );

      expect(span.children, isNull);
      expect(span.text, 'a' * 5);
    });
  });

  group('fills the given height (CP-D02)', () {
    testWidgets(
      'takes exactly the height of a tight parent (an Expanded inside a '
      'fixed-height Column), rather than shrinking to its own content',
      (WidgetTester tester) async {
        const double parentHeight = 300;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                height: parentHeight,
                child: _OverlayHost(
                  child: Column(
                    children: <Widget>[Expanded(child: CruxComposer())],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final double composerHeight = tester
            .getSize(find.byType(CruxComposer))
            .height;
        expect(composerHeight, parentHeight);
      },
    );

    testWidgets(
      'stays exactly the given height with a long, multi-line body instead '
      'of growing past it -- the body scrolls internally rather than the '
      'box growing, unlike CruxInputBar',
      (WidgetTester tester) async {
        const double parentHeight = 120;
        final CruxComposerController controller = CruxComposerController(
          text: List<String>.generate(30, (int i) => 'line $i').join('\n'),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                height: parentHeight,
                child: _OverlayHost(
                  child: Column(
                    children: <Widget>[
                      Expanded(child: CruxComposer(controller: controller)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final double composerHeight = tester
            .getSize(find.byType(CruxComposer))
            .height;
        expect(composerHeight, parentHeight);
      },
    );
  });

  group('top-aligned text (regression)', () {
    testWidgets(
      'renders the underlying CupertinoTextField with textAlignVertical: '
      'top, so short text and the placeholder both start at the top of the '
      "field instead of CupertinoTextField's own default of vertically "
      'centered -- every real-world composer starts at the top (see '
      'unknowns/composer docs, mock-c layout). Asserting the underlying '
      "CupertinoTextField's own config property, per this repo's "
      'established convention (see the maxLines regression anchors in '
      'test/input_bar_test.dart).',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxComposer()));

        final CupertinoTextField field = tester.widget<CupertinoTextField>(
          find.byType(CupertinoTextField),
        );
        expect(field.textAlignVertical, TextAlignVertical.top);
      },
    );
  });

  group('action row appearance (CP-A01)', () {
    testWidgets('appears when actions is non-empty, even with no submit and '
        'no maxLength', (WidgetTester tester) async {
      const Key iconKey = Key('action-icon');
      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            actions: <CruxComposerAction>[
              CruxComposerAction(
                icon: _icon(iconKey, const Color(0xFF888888)),
                label: '添付',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(iconKey), findsOneWidget);
    });

    testWidgets('appears when submit is supplied, even with no actions and no '
        'maxLength', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const CruxComposer(submit: CruxComposerSubmit(label: '投稿'))),
      );

      expect(find.byType(CruxButton), findsOneWidget);
    });

    testWidgets(
      'appears when maxLength is supplied, even with no actions and no '
      'submit',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CruxComposer(maxLength: 20)));

        expect(find.text('0 / 20'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('crux_composer_action_row')),
          findsOneWidget,
        );
        // The hairline separator above the action row appears alongside it
        // (this change's own spec): it is drawn as a top border on the row's
        // own container rather than a standalone CruxDivider, so the
        // row's presence is exactly what gates the separator's presence
        // too, with zero extra layout height.
        final DecoratedBox actionRowBox = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('crux_composer_action_row')),
        );
        final BoxDecoration decoration =
            actionRowBox.decoration as BoxDecoration;
        final Border border = decoration.border! as Border;
        expect(border.top.width, 1);
        expect(border.top.color, CruxColors.light.separator);
      },
    );
  });

  group('submit button gating (CP-A02)', () {
    testWidgets('disabled while the text is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CruxComposer(submit: CruxComposerSubmit(label: '投稿'))),
      );

      final CruxButton button = tester.widget<CruxButton>(
        find.byType(CruxButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('enabled once the text is non-empty, and calls onSubmit with '
        'the current text', (WidgetTester tester) async {
      final CruxComposerController controller = CruxComposerController(
        text: 'こんにちは',
      );
      addTearDown(controller.dispose);
      String? submitted;

      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            controller: controller,
            submit: const CruxComposerSubmit(label: '投稿'),
            onSubmit: (String text) => submitted = text,
          ),
        ),
      );

      final CruxButton button = tester.widget<CruxButton>(
        find.byType(CruxButton),
      );
      expect(button.onPressed, isNotNull);

      button.onPressed!();
      expect(submitted, 'こんにちは');
    });

    testWidgets('disabled again once the text goes over maxLength', (
      WidgetTester tester,
    ) async {
      final CruxComposerController controller = CruxComposerController(
        text: 'a' * 25,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            controller: controller,
            maxLength: 20,
            submit: const CruxComposerSubmit(label: '投稿'),
          ),
        ),
      );

      final CruxButton button = tester.widget<CruxButton>(
        find.byType(CruxButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('disabled while enabled: false, even with non-empty, '
        'within-limit text', (WidgetTester tester) async {
      final CruxComposerController controller = CruxComposerController(
        text: 'こんにちは',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            controller: controller,
            enabled: false,
            submit: const CruxComposerSubmit(label: '投稿'),
          ),
        ),
      );

      final CruxButton button = tester.widget<CruxButton>(
        find.byType(CruxButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'stays disabled with non-empty, within-limit text if onSubmit is '
      'not supplied -- a button that looks tappable but silently does '
      'nothing on tap would be a footgun',
      (WidgetTester tester) async {
        final CruxComposerController controller = CruxComposerController(
          text: 'こんにちは',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              controller: controller,
              submit: const CruxComposerSubmit(label: '投稿'),
            ),
          ),
        );

        final CruxButton button = tester.widget<CruxButton>(
          find.byType(CruxButton),
        );
        expect(button.onPressed, isNull);
      },
    );
  });

  group('onChanged', () {
    testWidgets('fires with the newly entered text on user edit', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(CruxComposer(focusNode: focusNode, onChanged: changes.add)),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'こんにちは');
      await tester.pump();

      expect(changes, contains('こんにちは'));
    });
  });

  group('counter (CP-D07)', () {
    testWidgets('reads "n / max" using the literal supplied maxLength', (
      WidgetTester tester,
    ) async {
      final CruxComposerController controller = CruxComposerController(
        text: 'hello',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxComposer(controller: controller, maxLength: 20)),
      );

      expect(find.text('5 / 20'), findsOneWidget);
    });

    testWidgets('counts an emoji as exactly one grapheme (CP-D03)', (
      WidgetTester tester,
    ) async {
      // "abc" (3) + one flag emoji (a 2-codepoint, 4-UTF16-code-unit
      // grapheme cluster, counted as 1) + "de" (2) = 6 graphemes, even
      // though `String.length` (UTF-16 code units) would read higher.
      final CruxComposerController controller = CruxComposerController(
        text: 'abc🇯🇵de',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxComposer(controller: controller, maxLength: 20)),
      );

      expect(find.text('6 / 20'), findsOneWidget);
    });

    testWidgets('reads the over-limit count in error color once text '
        'exceeds maxLength', (WidgetTester tester) async {
      final CruxComposerController controller = CruxComposerController(
        text: 'a' * 21,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxComposer(controller: controller, maxLength: 20)),
      );
      await tester.pumpAndSettle();

      expect(find.text('21 / 20'), findsOneWidget);
      final Text counterText = tester.widget<Text>(find.text('21 / 20'));
      expect(counterText.style!.color, CruxColors.light.error);
    });
  });

  group('overflow highlight (CP-A02, buildTextSpan output)', () {
    testWidgets(
      'splits text at the exact grapheme boundary: the normal part keeps '
      'the base style, the overflow part is colored',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        final CruxComposerController controller = CruxComposerController(
          text: 'a' * 21,
        );
        addTearDown(controller.dispose);
        controller.applyOverflowStyle(
          maxLength: 20,
          color: const Color(0xFFFF0000),
        );

        final TextSpan span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(fontSize: 16),
          withComposing: false,
        );

        expect(span.children, hasLength(2));
        final TextSpan normal = span.children![0] as TextSpan;
        final TextSpan overflow = span.children![1] as TextSpan;
        expect(normal.text, 'a' * 20);
        expect(normal.style, isNull);
        expect(overflow.text, 'a');
        expect(overflow.style!.color, const Color(0xFFFF0000));
      },
    );

    testWidgets(
      'splits at the grapheme boundary even when an emoji straddles the '
      'limit -- the emoji is never cut in half',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        // 20 'a's (within limit) + one flag emoji (over limit, 1 grapheme
        // but 4 UTF-16 code units).
        final CruxComposerController controller = CruxComposerController(
          text: '${'a' * 20}🇯🇵',
        );
        addTearDown(controller.dispose);
        controller.applyOverflowStyle(
          maxLength: 20,
          color: const Color(0xFFFF0000),
        );

        final TextSpan span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );

        expect(span.children, hasLength(2));
        final TextSpan normal = span.children![0] as TextSpan;
        final TextSpan overflow = span.children![1] as TextSpan;
        expect(normal.text, 'a' * 20);
        expect(overflow.text, '🇯🇵');
      },
    );

    testWidgets(
      'counts a multi-code-unit grapheme *before* the limit as one grapheme, '
      'not several UTF-16 code units -- a naive `text.substring(0, '
      'maxLength)` (code units, not graphemes) would split this text one '
      'character earlier than it should',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        // One flag emoji (1 grapheme, 4 UTF-16 code units) + 20 'a's = 21
        // graphemes total, one over the limit. The correct grapheme split
        // keeps the emoji plus the first 19 'a's on the normal side and
        // only the 20th 'a' overflows; splitting at UTF-16 code unit 20
        // instead would cut after the emoji plus only 16 'a's, leaving the
        // last 4 'a's as "overflow" -- a different, wrong split this test
        // distinguishes from the correct one.
        final CruxComposerController controller = CruxComposerController(
          text: '🇯🇵${'a' * 20}',
        );
        addTearDown(controller.dispose);
        controller.applyOverflowStyle(
          maxLength: 20,
          color: const Color(0xFFFF0000),
        );

        final TextSpan span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );

        expect(span.children, hasLength(2));
        final TextSpan normal = span.children![0] as TextSpan;
        final TextSpan overflow = span.children![1] as TextSpan;
        expect(normal.text, '🇯🇵${'a' * 19}');
        expect(overflow.text, 'a');
      },
    );

    testWidgets('renders as a single, unsplit span (delegating to the base '
        'implementation) while at or under the limit', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _captureContext(tester);
      final CruxComposerController controller = CruxComposerController(
        text: 'a' * 20,
      );
      addTearDown(controller.dispose);
      controller.applyOverflowStyle(
        maxLength: 20,
        color: const Color(0xFFFF0000),
      );

      final TextSpan span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );

      expect(span.children, isNull);
      expect(span.text, 'a' * 20);
    });

    testWidgets(
      'behaves exactly like a plain TextEditingController (no split, no '
      'color) when never configured by a CruxComposer',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        final CruxComposerController controller = CruxComposerController(
          text: 'a' * 25,
        );
        addTearDown(controller.dispose);

        final TextSpan span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );

        expect(span.children, isNull);
        expect(span.text, 'a' * 25);
      },
    );

    testWidgets(
      'merges the overflow split with a composing range that straddles it, '
      'keeping the composing underline and the overflow color on whichever '
      'segments actually need each',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        final CruxComposerController controller = CruxComposerController();
        addTearDown(controller.dispose);
        controller.value = TextEditingValue(
          text: 'a' * 21,
          selection: const TextSelection.collapsed(offset: 21),
          composing: const TextRange(start: 18, end: 21),
        );
        controller.applyOverflowStyle(
          maxLength: 20,
          color: const Color(0xFFFF0000),
        );

        final TextSpan span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: true,
        );

        // Cut points at 0, 18 (composing start), 20 (overflow split), 21
        // (composing end / text end) produce three non-empty segments.
        expect(span.children, hasLength(3));
        final TextSpan plain = span.children![0] as TextSpan;
        final TextSpan composingOnly = span.children![1] as TextSpan;
        final TextSpan composingAndOverflow = span.children![2] as TextSpan;

        expect(plain.text, 'a' * 18);
        expect(plain.style, isNull);

        expect(composingOnly.text, 'a' * 2);
        expect(composingOnly.style?.decoration, TextDecoration.underline);
        expect(composingOnly.style?.color, isNull);

        expect(composingAndOverflow.text, 'a');
        expect(
          composingAndOverflow.style?.decoration,
          TextDecoration.underline,
        );
        expect(composingAndOverflow.style?.color, const Color(0xFFFF0000));
      },
    );

    testWidgets('keeps a composing range that sits entirely before the split '
        'underlined but not colored, leaving the overflow segment colored '
        'but not underlined', (WidgetTester tester) async {
      final BuildContext context = await _captureContext(tester);
      final CruxComposerController controller = CruxComposerController();
      addTearDown(controller.dispose);
      controller.value = TextEditingValue(
        text: 'a' * 25,
        selection: const TextSelection.collapsed(offset: 10),
        composing: const TextRange(start: 5, end: 10),
      );
      controller.applyOverflowStyle(
        maxLength: 20,
        color: const Color(0xFFFF0000),
      );

      final TextSpan span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: true,
      );

      // Cut points at 0, 5, 10, 20 (split), 25 (end) produce four segments.
      expect(span.children, hasLength(4));
      final TextSpan composingSegment = span.children![1] as TextSpan;
      final TextSpan overflowSegment = span.children![3] as TextSpan;

      expect(composingSegment.text, 'a' * 5);
      expect(composingSegment.style?.decoration, TextDecoration.underline);
      expect(composingSegment.style?.color, isNull);

      expect(overflowSegment.text, 'a' * 5);
      expect(overflowSegment.style?.decoration, isNull);
      expect(overflowSegment.style?.color, const Color(0xFFFF0000));
    });
  });

  group('compound over-limit scenario (through the full widget)', () {
    testWidgets(
      'maxLength: 20 with a 21-grapheme, emoji-including body shows the '
      'error-colored "21 / 20" counter and disables submit, all together',
      (WidgetTester tester) async {
        final CruxComposerController controller = CruxComposerController(
          text: '${'a' * 20}🇯🇵',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              controller: controller,
              maxLength: 20,
              submit: const CruxComposerSubmit(label: '投稿'),
              onSubmit: (String text) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('21 / 20'), findsOneWidget);
        final Text counterText = tester.widget<Text>(find.text('21 / 20'));
        expect(counterText.style!.color, CruxColors.light.error);

        final CruxButton button = tester.widget<CruxButton>(
          find.byType(CruxButton),
        );
        expect(button.onPressed, isNull);
      },
    );
  });

  group('exactly at maxLength (boundary, regression)', () {
    testWidgets(
      'stays within limit at exactly maxLength graphemes -- a flag emoji '
      '(1 grapheme, 4 UTF-16 code units) plus 4 letters -- keeping the '
      'counter in textSecondary (not error) and the submit button enabled: '
      'proves overLimit is graphemeCount > maxLength, not >=',
      (WidgetTester tester) async {
        final CruxComposerController controller = CruxComposerController(
          text: '🇯🇵${'a' * 4}',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              controller: controller,
              maxLength: 5,
              submit: const CruxComposerSubmit(label: '投稿'),
              onSubmit: (String text) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('5 / 5'), findsOneWidget);
        final Text counterText = tester.widget<Text>(find.text('5 / 5'));
        expect(counterText.style!.color, CruxColors.light.textSecondary);

        final CruxButton button = tester.widget<CruxButton>(
          find.byType(CruxButton),
        );
        expect(button.onPressed, isNotNull);
      },
    );
  });

  group('paste past the limit is accepted, never truncated (CP-A02)', () {
    testWidgets('setting text past maxLength via the controller keeps every '
        'character', (WidgetTester tester) async {
      final CruxComposerController controller = CruxComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(CruxComposer(controller: controller, maxLength: 5)),
      );

      // Simulates a paste: programmatically setting text far past the
      // limit in one shot, the same shape a paste event produces.
      controller.text = 'この文章は5文字よりずっと長い';
      await tester.pumpAndSettle();

      expect(controller.text, 'この文章は5文字よりずっと長い');
      final EditableText editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.controller.text, 'この文章は5文字よりずっと長い');
    });
  });

  group('enabled: false', () {
    testWidgets('rejects typed input', (WidgetTester tester) async {
      final CruxComposerController controller = CruxComposerController();
      addTearDown(controller.dispose);
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            controller: controller,
            focusNode: focusNode,
            enabled: false,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'hello');
      await tester.pump();

      expect(controller.text, isEmpty);
    });

    testWidgets('dims each action button', (WidgetTester tester) async {
      const Key iconKey = Key('action-icon');
      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            enabled: false,
            actions: <CruxComposerAction>[
              CruxComposerAction(
                icon: _icon(iconKey, const Color(0xFF888888)),
                label: '添付',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final Opacity opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byKey(iconKey), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets(
      'dims the counter the same way it dims action buttons, instead of '
      'leaving it at full color while the rest of the row is disabled',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(const CruxComposer(enabled: false, maxLength: 20)),
        );

        final Opacity opacity = tester.widget<Opacity>(
          find.ancestor(
            of: find.text('0 / 20'),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, lessThan(1.0));
      },
    );
  });

  group('ambient theme isolation (regression)', () {
    testWidgets(
      "resolves the cursor and selection-highlight colors from Crux's "
      'own accent token even inside a garish ambient MaterialApp theme',
      (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(primary: Colors.purple),
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: Colors.purple,
                selectionColor: Colors.purple,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 300,
                  child: CruxComposer(focusNode: focusNode),
                ),
              ),
            ),
          ),
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
  });

  group('accessibility', () {
    testWidgets(
      'exposes a tap action on each action button so assistive technology '
      'can activate it, not just a physical touch',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        const Key iconKey = Key('action-icon');
        bool tapped = false;

        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              actions: <CruxComposerAction>[
                CruxComposerAction(
                  icon: _icon(iconKey, const Color(0xFF888888)),
                  label: '添付',
                  onPressed: () => tapped = true,
                ),
              ],
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(
          find.ancestor(
            of: find.byKey(iconKey),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is Semantics && widget.properties.button == true,
            ),
          ),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        // Uses the node's own SemanticsOwner (rather than a binding-level
        // pipeline owner accessor) to actually invoke the action a screen
        // reader's double-tap gesture would trigger.
        node.owner!.performAction(node.id, SemanticsAction.tap);
        expect(tapped, isTrue);

        handle.dispose();
      },
    );
  });

  group('44x44 tap targets', () {
    testWidgets('each action button keeps a tap target of at least 44x44', (
      WidgetTester tester,
    ) async {
      const Key iconKey = Key('action-icon');
      await tester.pumpWidget(
        _wrap(
          CruxComposer(
            actions: <CruxComposerAction>[
              CruxComposerAction(
                icon: _icon(iconKey, const Color(0xFF888888)),
                label: '添付',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final Size tapTargetSize = tester.getSize(
        find.ancestor(
          of: find.byKey(iconKey),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(tapTargetSize.width, greaterThanOrEqualTo(44));
      expect(tapTargetSize.height, greaterThanOrEqualTo(44));
    });
  });

  group('right-to-left layout (RTL)', () {
    testWidgets(
      'places actions at the trailing (right) edge and the counter/submit '
      'at the leading (left) edge under RTL',
      (WidgetTester tester) async {
        const Key iconKey = Key('action-icon');
        final CruxComposerController controller = CruxComposerController(
          text: 'hello',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              controller: controller,
              maxLength: 20,
              actions: <CruxComposerAction>[
                CruxComposerAction(
                  icon: _icon(iconKey, const Color(0xFF888888)),
                  label: '添付',
                  onPressed: () {},
                ),
              ],
            ),
            textDirection: TextDirection.rtl,
          ),
        );
        await tester.pumpAndSettle();

        final double composerCenterX = tester
            .getRect(find.byType(CruxComposer))
            .center
            .dx;
        final double actionCenterX = tester
            .getRect(find.byKey(iconKey))
            .center
            .dx;
        final double counterCenterX = tester
            .getRect(find.text('5 / 20'))
            .center
            .dx;

        expect(actionCenterX, greaterThan(composerCenterX));
        expect(counterCenterX, lessThan(composerCenterX));
      },
    );
  });

  group('narrow width', () {
    testWidgets(
      'lays out without throwing under a 200 logical pixel width, with an '
      'action, a counter, and a submit button all present at once',
      (WidgetTester tester) async {
        const Key iconKey = Key('action-icon');
        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              maxLength: 20,
              actions: <CruxComposerAction>[
                CruxComposerAction(
                  icon: _icon(iconKey, const Color(0xFF888888)),
                  label: '添付',
                  onPressed: () {},
                ),
              ],
              submit: const CruxComposerSubmit(label: '投稿'),
            ),
            width: 200,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'does not overflow with several actions at once at a realistic phone '
      'width -- the leading actions scroll horizontally instead of forcing '
      'a hard RenderFlex overflow',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              maxLength: 20,
              submit: const CruxComposerSubmit(label: '投稿'),
              onSubmit: (String text) {},
              actions: List<CruxComposerAction>.generate(
                6,
                (int index) => CruxComposerAction(
                  icon: _icon(Key('action-$index'), const Color(0xFF888888)),
                  label: 'action $index',
                  onPressed: () {},
                ),
              ),
            ),
            width: 320,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('action row trailing edge (regression)', () {
    testWidgets(
      'pins the counter/submit pair flush against the trailing edge (the '
      'action row\'s own horizontal padding aside), regardless of how many '
      'actions are present -- a single flex child on the leading side, not '
      'two independently-sized ones splitting the same leftover space',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxComposer(
              maxLength: 20,
              submit: const CruxComposerSubmit(label: '投稿'),
              onSubmit: (String text) {},
              actions: <CruxComposerAction>[
                CruxComposerAction(
                  icon: _icon(
                    const Key('action-icon'),
                    const Color(0xFF888888),
                  ),
                  label: '添付',
                  onPressed: () {},
                ),
              ],
            ),
            width: 375,
          ),
        );

        final Rect submitRect = tester.getRect(find.byType(CruxButton));
        final Rect composerRect = tester.getRect(find.byType(CruxComposer));

        // The action row's horizontal padding is half of the original 12
        // (there is no single s6 token, so it is expressed as s4 + s2).
        expect(
          composerRect.right - submitRect.right,
          CruxSpacing.s4 + CruxSpacing.s2,
        );
      },
    );
  });

  group('detached controller stays safe to reuse (CP-D04)', () {
    testWidgets(
      'clears the overflow style once its CruxComposer unmounts, so the '
      'same controller instance behaves like a plain TextEditingController '
      'if reused elsewhere afterward',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        final CruxComposerController controller = CruxComposerController(
          text: 'a' * 25,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(CruxComposer(controller: controller, maxLength: 20)),
        );
        await tester.pumpAndSettle();

        final TextSpan attachedSpan = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );
        expect(attachedSpan.children, hasLength(2));

        await tester.pumpWidget(const SizedBox.shrink());

        final TextSpan detachedSpan = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );
        expect(detachedSpan.children, isNull);
        expect(detachedSpan.text, 'a' * 25);
      },
    );

    testWidgets(
      'clears the overflow style on the controller being swapped away '
      'from, not just the one swapped to',
      (WidgetTester tester) async {
        final BuildContext context = await _captureContext(tester);
        final CruxComposerController first = CruxComposerController(
          text: 'a' * 25,
        );
        addTearDown(first.dispose);
        final CruxComposerController second = CruxComposerController(
          text: 'b' * 5,
        );
        addTearDown(second.dispose);

        await tester.pumpWidget(
          _wrap(CruxComposer(controller: first, maxLength: 20)),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          _wrap(CruxComposer(controller: second, maxLength: 20)),
        );
        await tester.pumpAndSettle();

        final TextSpan firstSpan = first.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );
        expect(firstSpan.children, isNull);
        expect(firstSpan.text, 'a' * 25);
      },
    );
  });
}

/// Captures a real, live [BuildContext] via a throwaway [Builder], for tests
/// that call [CruxComposerController.buildTextSpan] directly rather than
/// through a full [CruxComposer] widget tree. [TextEditingController
/// .buildTextSpan]'s own base implementation never actually reads anything
/// from `context` on the paths these tests exercise, but a plain [BuildContext]
/// has no public constructor and no built-in fake in this package's
/// dependencies (no mocking package is a dependency, and this package adds
/// none per its own rules) -- pumping one real widget and capturing its
/// context is the simplest way to get a genuine instance to pass through.
Future<BuildContext> _captureContext(WidgetTester tester) async {
  late final BuildContext context;
  await tester.pumpWidget(
    Builder(
      builder: (BuildContext innerContext) {
        context = innerContext;
        return const SizedBox.shrink();
      },
    ),
  );
  return context;
}
