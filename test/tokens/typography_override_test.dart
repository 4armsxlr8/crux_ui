// Token-level overrides on CruxTypography: the merge semantics of the nine
// optional TextStyle overrides, the fontFamily precedence they create, the
// "tokens carry no color" assert, const construction, and copyWith.
//
// The default value of each token is pinned by token_scale_test.dart and
// checked against its upstream source by native_scale_parity_test.dart. This
// file never restates those numbers: every "unchanged" expectation is read off
// a no-override CruxTypography instead, so the two files cannot disagree.
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux_ui/crux_ui.dart';

/// The nine tokens of [scale], keyed by their token name so a mismatch names
/// the token that drifted.
Map<String, TextStyle> _tokensOf(CruxTypography scale) => <String, TextStyle>{
  'heading': scale.heading,
  'subheading': scale.subheading,
  'title': scale.title,
  'body': scale.body,
  'caption': scale.caption,
  'captionStrong': scale.captionStrong,
  'labelSmall': scale.labelSmall,
  'label': scale.label,
  'navLabel': scale.navLabel,
};

/// Asserts every token of [actual] equals the same token of [expected], apart
/// from the tokens named in [except].
void _expectTokensMatch(
  CruxTypography actual,
  CruxTypography expected, {
  Set<String> except = const <String>{},
}) {
  final Map<String, TextStyle> actualTokens = _tokensOf(actual);
  final Map<String, TextStyle> expectedTokens = _tokensOf(expected);
  for (final String token in expectedTokens.keys) {
    if (except.contains(token)) {
      continue;
    }
    expect(
      actualTokens[token],
      equals(expectedTokens[token]),
      reason: '$token should still resolve to the platform default',
    );
  }
}

void main() {
  const CruxTypography appleDefaults = CruxTypography(
    platform: TargetPlatform.iOS,
  );
  const CruxTypography materialDefaults = CruxTypography(
    platform: TargetPlatform.android,
  );

  // The two tiers, keyed by the name that reads in a test description. Every
  // expectation below is read off the tier's own no-override scale, so the
  // loops never restate a platform's numbers.
  const Map<String, CruxTypography> tiers = <String, CruxTypography>{
    'Apple': appleDefaults,
    'Material': materialDefaults,
  };

  group('CruxTypography with no overrides', () {
    for (final MapEntry<String, CruxTypography> tier in tiers.entries) {
      test('leaves all nine tokens at the ${tier.key} default when every '
          'override is null (null means "no override", not "clear this '
          'token")', () {
        final CruxTypography scale = CruxTypography(
          platform: tier.value.platform,
          heading: null,
          subheading: null,
          title: null,
          body: null,
          caption: null,
          captionStrong: null,
          labelSmall: null,
          label: null,
          navLabel: null,
        );

        _expectTokensMatch(scale, tier.value);
      });
    }
  });

  group('CruxTypography with one token overridden', () {
    for (final MapEntry<String, CruxTypography> tier in tiers.entries) {
      test('leaves the other eight tokens untouched on the ${tier.key} '
          'tier', () {
        final CruxTypography scale = CruxTypography(
          platform: tier.value.platform,
          body: const TextStyle(fontSize: 15),
        );

        // Guard the premise: if the override did nothing, the eight assertions
        // below would pass while proving nothing.
        expect(scale.body, isNot(equals(tier.value.body)));
        _expectTokensMatch(scale, tier.value, except: <String>{'body'});
      });
    }

    test('changes only the attributes the override names, on the Apple '
        'tier (merge, not replacement)', () {
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.iOS,
        body: TextStyle(fontSize: 15),
      );

      expect(scale.body.fontSize, 15);
      expect(scale.body.fontWeight, appleDefaults.body.fontWeight);
      expect(scale.body.letterSpacing, appleDefaults.body.letterSpacing);
      expect(scale.body.fontFamily, appleDefaults.body.fontFamily);
      expect(scale.body.height, appleDefaults.body.height);
    });

    test('changes only the attributes the override names, on the Material '
        'tier — the line height and even leading distribution survive, '
        'because dropping them shifts text inside fixed-height controls', () {
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.android,
        body: TextStyle(fontSize: 15),
      );

      expect(scale.body.fontSize, 15);
      expect(scale.body.fontWeight, materialDefaults.body.fontWeight);
      expect(scale.body.letterSpacing, materialDefaults.body.letterSpacing);
      expect(scale.body.fontFamily, materialDefaults.body.fontFamily);
      expect(scale.body.height, materialDefaults.body.height);
      expect(
        scale.body.leadingDistribution,
        materialDefaults.body.leadingDistribution,
      );
      expect(scale.body.textBaseline, materialDefaults.body.textBaseline);
    });
  });

  group('CruxTypography with all nine tokens overridden', () {
    test('applies every one of them', () {
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.iOS,
        heading: TextStyle(fontSize: 41),
        subheading: TextStyle(fontSize: 42),
        title: TextStyle(fontSize: 43),
        body: TextStyle(fontSize: 44),
        caption: TextStyle(fontSize: 45),
        captionStrong: TextStyle(fontSize: 46),
        labelSmall: TextStyle(fontSize: 47),
        label: TextStyle(fontSize: 48),
        navLabel: TextStyle(fontSize: 49),
      );

      expect(scale.heading.fontSize, 41);
      expect(scale.subheading.fontSize, 42);
      expect(scale.title.fontSize, 43);
      expect(scale.body.fontSize, 44);
      expect(scale.caption.fontSize, 45);
      expect(scale.captionStrong.fontSize, 46);
      expect(scale.labelSmall.fontSize, 47);
      expect(scale.label.fontSize, 48);
      expect(scale.navLabel.fontSize, 49);
    });
  });

  group('CruxTypography with an inherit: false override', () {
    test('takes the override verbatim, dropping the platform line height and '
        'ignoring the scale-wide fontFamily', () {
      const TextStyle verbatim = TextStyle(
        inherit: false,
        fontFamily: 'Verbatim',
        fontSize: 15,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.5,
      );
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.android,
        fontFamily: 'ScaleWide',
        body: verbatim,
      );

      // Guard the premise: the Material tier is the one that carries a line
      // height, so it is where "no height at all" is observable.
      expect(materialDefaults.body.height, isNotNull);

      expect(scale.body, equals(verbatim));
      expect(scale.body.height, isNull);
      expect(scale.body.fontFamily, 'Verbatim');
    });
  });

  group('CruxTypography fontFamily precedence', () {
    test('the scale-wide family reaches both non-overridden tokens and the '
        'attributes an override leaves unset', () {
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.iOS,
        fontFamily: 'ScaleWide',
        body: TextStyle(fontSize: 15),
      );

      expect(scale.heading.fontFamily, 'ScaleWide');
      expect(scale.body.fontFamily, 'ScaleWide');
    });

    test("an override's own family beats the scale-wide family", () {
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.iOS,
        fontFamily: 'ScaleWide',
        body: TextStyle(fontFamily: 'OwnFamily'),
      );

      expect(scale.body.fontFamily, 'OwnFamily');
      expect(scale.heading.fontFamily, 'ScaleWide');
    });
  });

  group('CruxTypography rejects color in an override', () {
    // The assert lives in the resolution path, so constructing the scale is
    // silent and reading the token is what fails. Each test builds the scale
    // first: if construction threw, the test would error before reaching the
    // expectation.

    // Builders rather than plain styles because foreground and background take
    // a Paint, which is not a compile-time constant.
    final Map<String, TextStyle Function()> bannedProperties =
        <String, TextStyle Function()>{
          'color': () => const TextStyle(color: Color(0xFF123456)),
          'backgroundColor': () =>
              const TextStyle(backgroundColor: Color(0xFF123456)),
          'foreground': () => TextStyle(foreground: Paint()),
          'background': () => TextStyle(background: Paint()),
          'decorationColor': () =>
              const TextStyle(decorationColor: Color(0xFF123456)),
          // Rejected however the list is filled: every Shadow carries a color
          // even when it leaves it implicit, as this one does.
          'shadows': () =>
              const TextStyle(shadows: <Shadow>[Shadow(blurRadius: 4)]),
        };

    for (final MapEntry<String, TextStyle Function()> property
        in bannedProperties.entries) {
      test('trips an assert when the override sets ${property.key}', () {
        final CruxTypography scale = CruxTypography(
          platform: TargetPlatform.iOS,
          body: property.value(),
        );

        expect(() => scale.body, throwsAssertionError);
      });
    }

    // One builder per token slot, so a slot the check forgets to inspect — or
    // spells wrong in its message — fails here rather than shipping.
    final Map<String, CruxTypography Function(TextStyle)>
    scaleOverriding = <String, CruxTypography Function(TextStyle)>{
      'heading': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, heading: override),
      'subheading': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, subheading: override),
      'title': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, title: override),
      'body': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, body: override),
      'caption': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, caption: override),
      'captionStrong': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, captionStrong: override),
      'labelSmall': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, labelSmall: override),
      'label': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, label: override),
      'navLabel': (TextStyle override) =>
          CruxTypography(platform: TargetPlatform.iOS, navLabel: override),
    };

    for (final MapEntry<String, CruxTypography Function(TextStyle)> token
        in scaleOverriding.entries) {
      test('names ${token.key} in the assertion message when that token\'s '
          'override carries a color', () {
        final CruxTypography scale = token.value(
          const TextStyle(color: Color(0xFF123456)),
        );

        expect(
          () => _tokensOf(scale),
          throwsA(
            isA<AssertionError>().having(
              (AssertionError error) => error.message.toString(),
              'message',
              contains('"${token.key}"'),
            ),
          ),
        );
      });
    }
  });

  group('CruxTypography checks every override on any token read', () {
    test('trips an assert on a token whose own override is legal, when a '
        'different token carries the illegal one', () {
      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.iOS,
        heading: TextStyle(color: Color(0xFF123456)),
      );

      // No component in the package reads heading or subheading, so a check
      // that only inspected the token being read would let a color baked into
      // either of them survive both this suite and a real app.
      expect(() => scale.body, throwsAssertionError);
    });
  });

  group('CruxTypography label and labelSmall override slots', () {
    test('are independent even on Material, where both tokens resolve to the '
        'same default style', () {
      // Guard the premise: on Material these two share one default style, so
      // a single shared override slot would be invisible without this test.
      expect(materialDefaults.label, equals(materialDefaults.labelSmall));

      const CruxTypography scale = CruxTypography(
        platform: TargetPlatform.android,
        label: TextStyle(fontSize: 20),
      );

      expect(scale.label.fontSize, 20);
      expect(scale.labelSmall, equals(materialDefaults.labelSmall));
    });
  });

  group('CruxTypography const construction', () {
    test('a scale carrying an override is a compile-time constant', () {
      const CruxTypography first = CruxTypography(
        platform: TargetPlatform.iOS,
        body: TextStyle(fontSize: 15),
      );
      const CruxTypography second = CruxTypography(
        platform: TargetPlatform.iOS,
        body: TextStyle(fontSize: 15),
      );

      // Two identical const expressions are canonicalised to one instance,
      // which only happens if the constructor really is const.
      expect(identical(first, second), isTrue);
      expect(first.body.fontSize, 15);
    });
  });

  group('CruxTypography.copyWith', () {
    test('keeps the fields it is not given', () {
      const CruxTypography original = CruxTypography(
        platform: TargetPlatform.iOS,
        fontFamily: 'ScaleWide',
        body: TextStyle(fontSize: 15),
        label: TextStyle(fontWeight: FontWeight.w900),
      );

      final CruxTypography updated = original.copyWith(
        caption: const TextStyle(fontSize: 9),
      );

      expect(updated.platform, TargetPlatform.iOS);
      expect(updated.fontFamily, 'ScaleWide');
      expect(updated.body.fontSize, 15);
      expect(updated.label.fontWeight, FontWeight.w900);
      expect(updated.caption.fontSize, 9);
    });

    test('keeps the token overrides when the platform and family change', () {
      const CruxTypography original = CruxTypography(
        platform: TargetPlatform.iOS,
        fontFamily: 'ScaleWide',
        body: TextStyle(fontSize: 15),
      );

      final CruxTypography updated = original.copyWith(
        platform: TargetPlatform.android,
        fontFamily: 'Replacement',
      );

      expect(updated.platform, TargetPlatform.android);
      expect(updated.fontFamily, 'Replacement');
      expect(updated.body.fontSize, 15);
      expect(updated.body.height, materialDefaults.body.height);
    });

    test('returns an equal scale when given no arguments', () {
      const CruxTypography original = CruxTypography(
        platform: TargetPlatform.iOS,
        fontFamily: 'ScaleWide',
        body: TextStyle(fontSize: 15),
      );

      final CruxTypography copy = original.copyWith();

      expect(copy, equals(original));
      expect(copy.hashCode, equals(original.hashCode));
    });

    test('adds an override to a scale that already carries one', () {
      const CruxTypography original = CruxTypography(
        platform: TargetPlatform.android,
        body: TextStyle(fontSize: 15),
      );

      final CruxTypography updated = original.copyWith(
        navLabel: const TextStyle(fontSize: 8),
      );

      expect(updated.body.fontSize, 15);
      expect(updated.navLabel.fontSize, 8);
      expect(updated.heading, equals(materialDefaults.heading));
    });
  });
}
