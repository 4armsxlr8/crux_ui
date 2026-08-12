// Behavior tests for CruxNavBar, following the same front-loaded pattern
// segmented_control_test.dart established: onChanged wiring, disabled
// safety, the "at least two items" assert, the selection plate's presence,
// the "kira" sheen one-shot (direction-aware, gated to real selection
// changes only, delayed ~90ms), reduce motion, safe-area-driven margins with
// no MediaQuery ancestor, the 44px minimum tap target, the pill's fixed,
// tab-count-driven width (88px per tab, label-independent -- a 2026-08-07
// user decision, re-tuned down from an initial 102px reference-design
// measurement after a real-device comparison; see the "compact width" group
// below), and the selected tab's bold label weight (also a 2026-08-07
// decision; see the "selected label weight" group below).
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// Wraps [child] with the minimum ancestry CruxNavBar needs to lay out and
/// paint (a [Directionality]), matching segmented_control_test.dart's `_wrap`.
/// No [CruxTheme] or [MediaQuery] is provided deliberately, exercising the
/// documented fallback to [CruxThemeData.light] and a zero safe area.
Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

/// A tiny emoji [Text] used as every item's icon in these tests -- keeps the
/// tests independent of any real icon system, matching the package's own
/// "icon is a caller-supplied Widget" convention.
Widget _icon(String emoji) => Text(emoji);

/// Three items shared by every test: values 'a'/'b'/'c' at ascending
/// indices, labels 'A'/'B'/'C' -- mirrors segmented_control_test.dart's
/// `_segments`.
List<CruxNavItem<String>> _items() => <CruxNavItem<String>>[
  CruxNavItem<String>(value: 'a', icon: _icon('🏠'), label: 'A'),
  CruxNavItem<String>(value: 'b', icon: _icon('💬'), label: 'B'),
  CruxNavItem<String>(value: 'c', icon: _icon('⚙️'), label: 'C'),
];

/// A pool of (value, label) pairs long enough to build up to five items
/// without repeating one, every label a single character -- used by the
/// "compact width" group below wherever a test needs short, unremarkable
/// labels that are not themselves under test. The pill's own width is a
/// 2026-08-07 fixed, per-tab value (`_tabWidth` in `nav_bar.dart`) that no
/// longer depends on label length at all -- see that group's own intro
/// comment and [_longLabelItemPool] below, its label-length counterpart used
/// specifically to prove that independence. Mirrors
/// `widgetbook/lib/usecases/nav_bar.dart`'s own `_navItemPool`/`_navItems`,
/// kept as this file's own independent copy rather than a shared import
/// (this package has no precedent for sharing test fixtures across `test/`
/// and `widgetbook/`, two separate packages).
const List<(String value, String label)> _itemPool = <(String, String)>[
  ('a', 'A'),
  ('b', 'B'),
  ('c', 'C'),
  ('d', 'D'),
  ('e', 'E'),
];

List<CruxNavItem<String>> _itemsOfCount(int count) => <CruxNavItem<String>>[
  for (int i = 0; i < count; i++)
    CruxNavItem<String>(
      value: _itemPool[i].$1,
      icon: _icon('🏠'),
      label: _itemPool[i].$2,
    ),
];

/// [_itemPool]'s label-length counterpart: the same five (value, label)
/// slots, but every label deliberately long instead of a single character --
/// used by the "compact width" group below to prove the pill's own fixed
/// width truly never depends on label length, by comparing a bar built from
/// this pool against the identically-sized [_itemPool] bar.
const List<(String value, String label)> _longLabelItemPool =
    <(String, String)>[
      ('a', 'とても長いラベルのタブその1'),
      ('b', 'とても長いラベルのタブその2'),
      ('c', 'とても長いラベルのタブその3'),
      ('d', 'とても長いラベルのタブその4'),
      ('e', 'とても長いラベルのタブその5'),
    ];

List<CruxNavItem<String>> _longLabelItemsOfCount(int count) =>
    <CruxNavItem<String>>[
      for (int i = 0; i < count; i++)
        CruxNavItem<String>(
          value: _longLabelItemPool[i].$1,
          icon: _icon('🏠'),
          label: _longLabelItemPool[i].$2,
        ),
    ];

/// Finds the [Stack] that is a single tab's own root -- scoping every other
/// finder below to exactly one tab's subtree, the same "walk up from a known
/// descendant" technique segmented_control_test.dart's `_segmentStack` uses.
Finder _tabStack(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(Stack))
      .first;
}

/// Finds the nearest [Semantics] ancestor of a tab's label.
Finder _tabSemantics(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(Semantics))
      .first;
}

/// Finds a tab's selection-plate [AnimatedOpacity].
Finder _plateOpacityFinder(String label) {
  return find.descendant(
    of: _tabStack(label),
    matching: find.byType(AnimatedOpacity),
  );
}

double _plateOpacity(WidgetTester tester, String label) {
  return tester.widget<AnimatedOpacity>(_plateOpacityFinder(label)).opacity;
}

/// Finds a tab's plate box: the only [DecoratedBox] in its subtree whose
/// decoration is a [ShapeDecoration] -- previously narrowed further to
/// "carries a non-null `shadows` list", but the plate no longer paints a
/// shadow at all (2026-08-06 confirmed "影なし" decision -- see
/// `nav_bar.dart`'s own "Color mapping" doc), so [ShapeDecoration] alone is
/// now the distinguishing feature. It still uniquely identifies the plate
/// box within a tab's own subtree: nothing else under [_tabStack] paints a
/// [ShapeDecoration] (the sheen band uses a plain [BoxDecoration] gradient).
Finder _plateBoxFinder(String label) {
  return find.descendant(
    of: _tabStack(label),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox && widget.decoration is ShapeDecoration,
    ),
  );
}

/// Finds [CruxNavBar]'s own backdrop-fade scrim: the sole [DecoratedBox]
/// in the whole tree whose decoration is a [BoxDecoration] carrying a
/// [LinearGradient] -- nothing else this widget paints uses [BoxDecoration]
/// (the pill and the plate both use [ShapeDecoration]; the sheen band uses
/// [BoxDecoration] too, but with no [Positioned] ancestor sized to the full
/// band -- in practice the sheen's own gradient is never mounted at the
/// same time as an idle scrim in these tests, since none of them trigger a
/// sheen sweep).
Finder _backdropScrimFinder() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.gradient is LinearGradient;
  });
}

/// Finds [CruxNavBar]'s own floating pill: the sole [DecoratedBox] in the
/// whole tree whose decoration is a [ShapeDecoration] carrying a non-null
/// `shadows` list. This uniquely identifies the pill and nothing else: a
/// tab's own selection plate also uses [ShapeDecoration] (see
/// [_plateBoxFinder]), but paints with **no shadow** at all (the 2026-08-06
/// "影なし" decision `_plateBoxFinder`'s own doc records), so `shadows !=
/// null` alone separates the two without needing to scope the search to one
/// tab's subtree the way [_plateBoxFinder] does. Used by the "compact
/// width" group below to measure the pill's own real rendered size --
/// distinct from [CruxNavBar]'s own reported widget size, which (per
/// `nav_bar.dart`'s class doc) still always fills its host's available
/// width even now that the pill itself is a fixed, tab-count-driven width
/// rather than the host's full width.
Finder _pillBoxFinder() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    return decoration is ShapeDecoration && decoration.shadows != null;
  });
}

/// Finds any actively-skewed [Transform] in a tab's subtree -- the sheen
/// sweep's skew, the only [Transform] this widget ever builds with a
/// non-zero (0,1) matrix entry. Empty whenever no sheen is currently
/// mid-flight for that tab.
Finder _sheenSkewFinder(String label) {
  return find.descendant(
    of: _tabStack(label),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Transform && widget.transform.entry(0, 1) != 0,
    ),
  );
}

/// Finds a tab's own [GestureDetector] -- the widget whose rendered size is
/// that tab's real, hit-testable tap region.
Finder _tabHitRegion(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first;
}

/// Pumps in small steps across [total], calling [sample] after every step --
/// used to catch a sheen's brief mid-flight window without coupling to one
/// exact millisecond, matching segmented_control_test.dart's `_pumpSampling`.
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
    testWidgets('notifies onChanged with the tapped item\'s value', (
      WidgetTester tester,
    ) async {
      final List<String> notifications = <String>[];
      await tester.pumpWidget(
        _wrap(
          CruxNavBar<String>(
            items: _items(),
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
      'does not notify when the already-selected item is tapped again',
      (WidgetTester tester) async {
        final List<String> notifications = <String>[];
        await tester.pumpWidget(
          _wrap(
            CruxNavBar<String>(
              items: _items(),
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
          _wrap(CruxNavBar<String>(items: _items(), selected: 'a')),
        );

        await tester.tap(find.text('B'));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('exposes enabled=false in semantics when onChanged is null', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(CruxNavBar<String>(items: _items(), selected: 'a')),
      );

      final SemanticsNode node = tester.getSemantics(_tabSemantics('B'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('items assert', () {
    testWidgets('asserts when fewer than two items are supplied', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxNavBar<String>(
            items: <CruxNavItem<String>>[
              CruxNavItem<String>(value: 'a', icon: _icon('🏠'), label: 'A'),
            ],
            selected: 'a',
            onChanged: (String _) {},
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
  });

  group('selection plate', () {
    testWidgets('the plate is only opaque for the selected item, faded for the '
        'others, once settled', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          CruxNavBar<String>(
            items: _items(),
            selected: 'b',
            onChanged: (String _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_plateOpacity(tester, 'A'), 0.0);
      expect(_plateOpacity(tester, 'B'), 1.0);
      expect(_plateOpacity(tester, 'C'), 0.0);
      expect(_plateBoxFinder('B').evaluate(), isNotEmpty);
    });

    testWidgets(
      'moves the opaque plate to the newly selected item and fades the '
      'previous one out, once settled',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxNavBar<String>(
                  items: _items(),
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
  });

  group('selection plate sizing', () {
    testWidgets(
      'the plate fills the tab cell\'s full available height -- 56px, the '
      'confirmed 64px bar height minus the 4px inner padding on both the '
      'top and bottom edges -- per the 2026-08-05 user request that the '
      'pill reach floor-to-ceiling inside its cell instead of hugging the '
      'icon+label content',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: 320,
                child: CruxNavBar<String>(
                  items: _items(),
                  selected: 'b',
                  onChanged: (String _) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Size plateSize = tester.getSize(_plateBoxFinder('B'));
        expect(plateSize.height, 64 - 4 * 2);
      },
    );
  });

  group('selection plate color', () {
    testWidgets(
      'fills the plate with CruxColors.light.controlFill in the light '
      'theme -- 2026-08-06 user request to make the light plate read as a '
      'gray pill instead of relying on the shadow alone',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          CruxTheme(
            data: CruxThemeData.light(),
            child: _wrap(
              CruxNavBar<String>(
                items: _items(),
                selected: 'b',
                onChanged: (String _) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final DecoratedBox plateBox = tester.widget<DecoratedBox>(
          _plateBoxFinder('B'),
        );
        final ShapeDecoration decoration =
            plateBox.decoration as ShapeDecoration;
        expect(decoration.color, CruxColors.light.controlFill);
      },
    );

    testWidgets(
      'keeps filling the plate with CruxColors.dark.controlPlate in the '
      'dark theme -- unchanged by the 2026-08-06 light-only request',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          CruxTheme(
            data: CruxThemeData.dark(),
            child: _wrap(
              CruxNavBar<String>(
                items: _items(),
                selected: 'b',
                onChanged: (String _) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final DecoratedBox plateBox = tester.widget<DecoratedBox>(
          _plateBoxFinder('B'),
        );
        final ShapeDecoration decoration =
            plateBox.decoration as ShapeDecoration;
        expect(decoration.color, CruxColors.dark.controlPlate);
      },
    );
  });

  group('selection plate shadow', () {
    testWidgets(
      'paints the plate with no shadow at all -- 2026-08-06 confirmed '
      '"影なし" decision (the plate/pill color difference alone identifies '
      'the plate now, not a shadow)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxNavBar<String>(
              items: _items(),
              selected: 'b',
              onChanged: (String _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final DecoratedBox plateBox = tester.widget<DecoratedBox>(
          _plateBoxFinder('B'),
        );
        final ShapeDecoration decoration =
            plateBox.decoration as ShapeDecoration;
        expect(decoration.shadows, isNull);
      },
    );
  });

  group('kira sheen gating', () {
    testWidgets('never sweeps on the initial render', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxNavBar<String>(
            items: _items(),
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

    testWidgets('never sweeps when the already-selected item is re-tapped', (
      WidgetTester tester,
    ) async {
      String selected = 'a';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CruxNavBar<String>(
                items: _items(),
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
                return CruxNavBar<String>(
                  items: _items(),
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
          reason: 'expected the sheen to sweep across item C at some point',
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
          reason: 'expected the sheen to sweep across item A at some point',
        );
        expect(backwardTilt, lessThan(0));
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
                return CruxNavBar<String>(
                  items: _items(),
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

  group('reduce motion', () {
    testWidgets(
      'still reflects the new selection immediately but never sweeps the '
      'sheen when animations are disabled',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _wrap(
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return CruxNavBar<String>(
                    items: _items(),
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

        // The plate must already be at its resting, opaque state on the very
        // next frame -- no fade-in animation.
        expect(_plateBoxFinder('C').evaluate(), isNotEmpty);
        expect(_plateBoxFinder('A').evaluate(), isEmpty);

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
      },
    );
  });

  group('no MediaQuery ancestor', () {
    testWidgets('builds and lays out with no exception at all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CruxNavBar<String>(
            items: _items(),
            selected: 'a',
            onChanged: (String _) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('safe area margin', () {
    testWidgets(
      'the bar\'s own total rendered height includes the bottom safe-area '
      'inset plus the confirmed 0px floating offset, on top of the 64px '
      'bar itself -- backdropFade: false here, isolating this margin math '
      'from the backdrop-fade band\'s own, separately tested, much larger '
      'height contribution (see the "backdrop fade" group below)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: _wrap(
              Center(
                child: CruxNavBar<String>(
                  items: _items(),
                  selected: 'a',
                  onChanged: (String _) {},
                  backdropFade: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Size size = tester.getSize(find.byType(CruxNavBar<String>));
        // 64 (bar) + 34 (safe area bottom) + 0 (confirmed floating offset).
        expect(size.height, 64 + 34 + 0);
      },
    );

    testWidgets('falls back to a zero safe-area inset with no MediaQuery', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: CruxNavBar<String>(
              items: _items(),
              selected: 'a',
              onChanged: (String _) {},
              backdropFade: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Size size = tester.getSize(find.byType(CruxNavBar<String>));
      // 64 (bar) + 0 (no safe area) + 0 (confirmed floating offset).
      expect(size.height, 64);
    });
  });

  group('backdrop fade', () {
    testWidgets(
      'by default draws a background-colored scrim plus the documented '
      '6-layer blur stack behind the pill',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxNavBar<String>(
                items: _items(),
                selected: 'a',
                onChanged: (String _) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_backdropScrimFinder().evaluate(), isNotEmpty);
        expect(find.byType(BackdropFilter).evaluate().length, 6);
      },
    );

    testWidgets(
      'backdropFade: false draws neither the scrim nor any blur layer',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxNavBar<String>(
                items: _items(),
                selected: 'a',
                onChanged: (String _) {},
                backdropFade: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_backdropScrimFinder().evaluate(), isEmpty);
        expect(find.byType(BackdropFilter).evaluate(), isEmpty);
      },
    );

    testWidgets(
      'backdropBlurSigma: 0 keeps the scrim but skips every blur layer',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: CruxNavBar<String>(
                items: _items(),
                selected: 'a',
                onChanged: (String _) {},
                backdropBlurSigma: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_backdropScrimFinder().evaluate(), isNotEmpty);
        expect(find.byType(BackdropFilter).evaluate(), isEmpty);
      },
    );

    testWidgets(
      'a tap inside the band-only area (above the pill, still within this '
      'widget\'s own bounds) passes through to whatever sits behind '
      'CruxNavBar in the host\'s own Stack, never intercepted by the band',
      (WidgetTester tester) async {
        int contentTaps = 0;
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: 360,
                height: 400,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => contentTaps++,
                      ),
                    ),
                    CruxNavBar<String>(
                      items: _items(),
                      selected: 'a',
                      onChanged: (String _) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Rect navBarRect = tester.getRect(find.byType(CruxNavBar<String>));
        // A point near the very top of CruxNavBar's own reported bounds:
        // inside the backdrop-fade band (160px tall by default), but well
        // above the floating pill itself (under 90px tall even with a
        // generous safe area, flush with the bottom of this same rect) --
        // so this point can only ever land on the band, never the pill.
        final Offset bandOnlyPoint = Offset(
          navBarRect.center.dx,
          navBarRect.top + 8,
        );
        await tester.tapAt(bandOnlyPoint);
        await tester.pump();

        expect(contentTaps, 1);
      },
    );
  });

  group('compact width', () {
    // 2026-08-06 user decision: the floating pill sizes to its own tab
    // count instead of always stretching to fill the host's full available
    // width -- see `nav_bar.dart`'s own class doc ("Compact width") and
    // `_barMarginX`'s doc (a *minimum* margin, not a fixed one) for the
    // confirmed design. A 2026-08-07 follow-up user decision (a reference
    // design the user supplied, its own single-tab cell measured at
    // 102x54) replaced that decision's original "widest tab's own content"
    // measurement with a fixed per-tab width (`_tabWidth` in
    // `nav_bar.dart`): the pill's width is now exactly
    // `_tabWidth * itemCount + _barInnerPadding * 2` and no longer depends
    // on any label's length at all. That same-day 102 reference-design
    // measurement was itself provisional -- a later 2026-08-07 real-device
    // comparison across 102/88/76/68 settled on the shipped `_tabWidth`
    // value of 88 (see `nav_bar.dart`'s own `_tabWidth` doc for the full
    // provenance, including why 68 was rejected). Every test below gives
    // the bar a generously wide 600px host unless it is deliberately
    // testing the narrow-host clamp, so the pill's own fixed width is
    // never accidentally clamped back down to that host width and masking
    // the very behavior under test.
    testWidgets(
      'the pill\'s width depends only on the item count, never on any '
      'label\'s length -- four short one-character labels and four '
      'extremely long labels both float the pill at the identical fixed '
      '88 * 4 + 4 * 2 width',
      (WidgetTester tester) async {
        Future<double> pillWidthFor(List<CruxNavItem<String>> items) async {
          await tester.pumpWidget(
            _wrap(
              Center(
                child: SizedBox(
                  width: 600,
                  child: CruxNavBar<String>(
                    items: items,
                    selected: items.first.value,
                    onChanged: (String _) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          return tester.getSize(_pillBoxFinder()).width;
        }

        final double shortLabelWidth = await pillWidthFor(_itemsOfCount(4));
        final double longLabelWidth = await pillWidthFor(
          _longLabelItemsOfCount(4),
        );

        // 88 (_tabWidth) * 4 items + 4 (_barInnerPadding) * 2.
        expect(shortLabelWidth, 88 * 4 + 4 * 2);
        expect(longLabelWidth, 88 * 4 + 4 * 2);
      },
    );

    testWidgets(
      'a 3-item bar\'s pill is exactly 88px narrower than a 4-item bar\'s '
      'pill -- one fewer tab at the fixed 88px tab width, with every '
      'label held at the same single-character length so item count is '
      'the only variable',
      (WidgetTester tester) async {
        Future<double> pillWidthFor(int count) async {
          await tester.pumpWidget(
            _wrap(
              Center(
                child: SizedBox(
                  width: 600,
                  child: CruxNavBar<String>(
                    items: _itemsOfCount(count),
                    selected: 'a',
                    onChanged: (String _) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          return tester.getSize(_pillBoxFinder()).width;
        }

        final double width3 = await pillWidthFor(3);
        final double width4 = await pillWidthFor(4);

        expect(width4 - width3, 88);
      },
    );

    testWidgets(
      'the pill is narrower than the bar\'s own full-width bounds and '
      'sits horizontally centered within them, once it no longer needs '
      'the full width to fit its fixed-width tabs',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: 600,
                child: CruxNavBar<String>(
                  items: _itemsOfCount(3),
                  selected: 'a',
                  onChanged: (String _) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Rect barRect = tester.getRect(find.byType(CruxNavBar<String>));
        final Rect pillRect = tester.getRect(_pillBoxFinder());

        expect(pillRect.width, lessThan(barRect.width));
        final double leftMargin = pillRect.left - barRect.left;
        final double rightMargin = barRect.right - pillRect.right;
        expect(leftMargin, closeTo(rightMargin, 1.0));
      },
    );

    testWidgets('every tab is exactly 88px wide regardless of its own label\'s '
        'length, and an extremely long label is ellipsized inside its own '
        'fixed-width tab with no layout exception', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 600,
              child: CruxNavBar<String>(
                items: <CruxNavItem<String>>[
                  CruxNavItem<String>(
                    value: 'a',
                    icon: _icon('🏠'),
                    label: 'A',
                  ),
                  CruxNavItem<String>(
                    value: 'b',
                    icon: _icon('💬'),
                    label: 'とても長いラベルのタブ',
                  ),
                  CruxNavItem<String>(
                    value: 'c',
                    icon: _icon('⚙️'),
                    label: 'C',
                  ),
                ],
                selected: 'a',
                onChanged: (String _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final double widthA = tester.getSize(_tabHitRegion('A')).width;
      final double widthB = tester.getSize(_tabHitRegion('とても長いラベルのタブ')).width;
      final double widthC = tester.getSize(_tabHitRegion('C')).width;

      expect(widthA, 88);
      expect(widthB, 88);
      expect(widthC, 88);

      // Pins the actual ellipsis mechanism, not just its absence of an
      // exception: tester.getSize reads the underlying RenderBox's own
      // layout size, which FittedBox's paint-time scale transform never
      // touches, so this is a direct check of the width the Text widget
      // was actually laid out at -- not the visually-scaled size it
      // paints at. Without the ConstrainedBox this test's own RED probe
      // added around Text in nav_bar.dart, RenderFittedBox hands its
      // child (the whole icon+label Column) fully unbounded constraints,
      // so this label would measure its own natural ~121px width instead
      // of ellipsizing, and the whole Column -- icon included -- would
      // shrink uniformly rather than only the label ellipsizing. 64 is
      // _tabWidth (88) minus _tabHorizontalPadding (12) on both edges.
      final double labelRenderWidth = tester
          .getSize(find.text('とても長いラベルのタブ'))
          .width;
      expect(labelRenderWidth, lessThanOrEqualTo(64));

      // The icon must stay at its full _iconSize regardless of the
      // label's own ellipsis -- the width constraint this test guards
      // above is wrapped around the Text alone, not the icon's own
      // SizedBox, so a long label must never shrink the icon next to it.
      final Finder iconBoxFinder = find
          .ancestor(of: find.text('💬'), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(iconBoxFinder), const Size(24, 24));
    });

    testWidgets('clamps the pill to the host\'s own available width with no '
        'exception when the fixed tab-count width would otherwise demand '
        'more room than the host has, degrading to shrunk, equal-width '
        'tabs instead', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 160,
              child: CruxNavBar<String>(
                items: _itemsOfCount(4),
                selected: 'a',
                onChanged: (String _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final double pillWidth = tester.getSize(_pillBoxFinder()).width;
      // 160 (host) minus the confirmed 16px minimum margin on each side --
      // the natural 88 * 4 + 4 * 2 = 360px width demands far more room
      // than this host has, so the clamp is exact, not merely an upper
      // bound.
      expect(pillWidth, 160 - 16 * 2);

      final double widthA = tester.getSize(_tabHitRegion('A')).width;
      final double widthD = tester.getSize(_tabHitRegion('D')).width;
      expect(widthA, closeTo(widthD, 0.5));
    });
  });

  group('selected label weight', () {
    // 2026-08-07 user decision: on top of the pre-existing selected/
    // unselected color distinction (identical in spirit to
    // CruxSegmentedControl's own segment label), the selected tab's
    // label also switches to FontWeight.bold -- see nav_bar.dart's own
    // "Label weight" class doc for the full reasoning, including why this
    // differs from CruxSegmentedControl (color-only there, no weight
    // change).
    testWidgets(
      'the selected tab\'s label is FontWeight.bold; every unselected '
      'tab\'s label keeps the type scale\'s own base weight untouched',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            CruxNavBar<String>(
              items: _items(),
              selected: 'b',
              onChanged: (String _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final TextStyle? selectedStyle = tester
            .widget<Text>(find.text('B'))
            .style;
        final TextStyle? unselectedStyleA = tester
            .widget<Text>(find.text('A'))
            .style;
        final TextStyle? unselectedStyleC = tester
            .widget<Text>(find.text('C'))
            .style;

        expect(selectedStyle?.fontWeight, FontWeight.bold);
        expect(
          unselectedStyleA?.fontWeight,
          const CruxTypography().label.fontWeight,
        );
        expect(
          unselectedStyleC?.fontWeight,
          const CruxTypography().label.fontWeight,
        );
      },
    );

    testWidgets(
      'moves the bold weight to the newly selected tab and reverts the '
      'previously selected tab to the base weight, on a real selection '
      'change',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return CruxNavBar<String>(
                  items: _items(),
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

        expect(
          tester.widget<Text>(find.text('C')).style?.fontWeight,
          FontWeight.bold,
        );
        expect(
          tester.widget<Text>(find.text('A')).style?.fontWeight,
          const CruxTypography().label.fontWeight,
        );
      },
    );

    testWidgets(
      'the tab width and pill width stay exactly at the fixed 88px-per-tab '
      'formula both before and after the bold weight moves -- the label\'s '
      'own wider bold glyphs never resize the fixed-width tab',
      (WidgetTester tester) async {
        String selected = 'a';
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: 600,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return CruxNavBar<String>(
                      items: _items(),
                      selected: selected,
                      onChanged: (String next) =>
                          setState(() => selected = next),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final double pillWidthBefore = tester.getSize(_pillBoxFinder()).width;
        final double tabWidthBefore = tester.getSize(_tabHitRegion('A')).width;

        await tester.tap(find.text('C'));
        await tester.pumpAndSettle();

        final double pillWidthAfter = tester.getSize(_pillBoxFinder()).width;
        final double tabWidthAfter = tester.getSize(_tabHitRegion('A')).width;

        // 88 (_tabWidth) * 3 items (_items() has 'a'/'b'/'c') + 4
        // (_barInnerPadding) * 2.
        expect(pillWidthBefore, 88 * 3 + 4 * 2);
        expect(pillWidthAfter, 88 * 3 + 4 * 2);
        expect(tabWidthBefore, 88);
        expect(tabWidthAfter, 88);
      },
    );
  });

  group('tap target', () {
    testWidgets(
      'keeps each item\'s hit-testable region at least 44 logical pixels '
      'tall and wide',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: 320,
                child: CruxNavBar<String>(
                  items: _items(),
                  selected: 'a',
                  onChanged: (String _) {},
                ),
              ),
            ),
          ),
        );

        for (final String label in <String>['A', 'B', 'C']) {
          final Size size = tester.getSize(_tabHitRegion(label));
          expect(size.height, greaterThanOrEqualTo(44));
          expect(size.width, greaterThanOrEqualTo(44));
        }
      },
    );
  });

  group('semantics', () {
    testWidgets(
      'exposes selected + inMutuallyExclusiveGroup per item, and enabled '
      'follows onChanged',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            CruxNavBar<String>(
              items: _items(),
              selected: 'b',
              onChanged: (String _) {},
            ),
          ),
        );

        final SemanticsNode selectedNode = tester.getSemantics(
          _tabSemantics('B'),
        );
        expect(selectedNode.flagsCollection.isSelected, Tristate.isTrue);
        expect(selectedNode.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(selectedNode.flagsCollection.isEnabled, Tristate.isTrue);

        final SemanticsNode unselectedNode = tester.getSemantics(
          _tabSemantics('A'),
        );
        expect(unselectedNode.flagsCollection.isSelected, Tristate.isFalse);
        expect(
          unselectedNode.flagsCollection.isInMutuallyExclusiveGroup,
          isTrue,
        );

        handle.dispose();
      },
    );
  });
}
