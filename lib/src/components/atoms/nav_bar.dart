import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../internal/press_feedback.dart';
import '../../tokens/colors.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/shadows.dart';
import '../../tokens/theme.dart';

/// The floating pill's own visible height, in logical pixels -- the
/// confirmed 2026-08-05 "バーの高さ64" spec (`unknowns/navigation-bars/mock-
/// bottomnav.html`'s `--bar-height` default). Unlike [CruxSegmentedControl]
/// (whose 40px visible pill is shorter than its own 44px minimum tap
/// target, forcing a two-layer "reported size vs. visible size" split -- see
/// that file's `_minTapTarget` doc), [_barHeight] alone already comfortably
/// exceeds [_minTapTarget], so every tab's real cell is tall enough on its
/// own without needing that same split.
const double _barHeight = 64;

/// The icon a caller-supplied [CruxNavItem.icon] is forced to render at --
/// the confirmed 2026-08-05 "アイコン 24px" spec (mock's `--icon-size`
/// default). Unlike [CruxIconButton.icon] (whose glyph size is left
/// entirely to the caller, since that button's circle comes in more than one
/// size -- see `icon_button.dart`'s own class doc), [CruxNavBar] has
/// exactly one confirmed icon size, so it is enforced here rather than left
/// as a caller convention. Enforced two ways, not one: an ambient
/// [IconThemeData.size] hint (for a bare [Icon] descendant that reads it,
/// the common case) *and* a hard [_CruxNavTabButtonState] `SizedBox` +
/// `FittedBox` bound around the whole icon slot -- the ambient hint alone
/// only ever *suggests* a size, and [CruxNavItem.icon] accepts any
/// [Widget] (an `Image`, an SVG package widget, a `Text` glyph, an `Icon`
/// with its own explicit `size`), none of which are obligated to honor it.
/// Without the hard bound, a caller-supplied icon taller than the tab cell's
/// available height would overflow [Column] below rather than shrink to fit.
const double _iconSize = 24;

/// The padding between the floating pill's own outer edge and the row of
/// tabs inside it, matching the mock's `.tabs-row { padding: 4px; }` --
/// plays the same "padding inside the outer shell, around the row of
/// interactive cells" role [CruxSegmentedControl]'s `_controlPadding`
/// plays for its own pill, even though [_barHeight] (unlike that pill's 40px
/// visible height) is already taller than [_minTapTarget].
const double _barInnerPadding = 4;

/// The gap left, on the left/right edges only, between a tab's own cell and
/// its selection plate/kira sheen mask, matching the mock's `.plate`/`.sheen
/// { inset: 2px; }` on those two edges. [CruxSegmentedControl]'s
/// equivalent plate has no such inset at all (it is `Positioned.fill`,
/// edge-to-edge with its own tighter 32px-tall cell) -- [_barHeight]'s
/// taller, more generous cell has room to spare, and the mock's own "案A"
/// reaction deliberately leaves a sliver of the tab's own background visible
/// around the plate rather than filling the cell completely. See
/// [_plateInsetVertical]'s own doc for why the *vertical* edges no longer
/// share this same value, unlike the mock.
const double _plateInsetHorizontal = 2;

/// The gap left, on the top/bottom edges only, between a tab's own cell and
/// its selection plate/kira sheen mask -- `0`, deliberately **not** the same
/// [_plateInsetHorizontal] value the mock's own `.plate`/`.sheen { inset:
/// 2px; }` uses on all four edges. This is a 2026-08-05 user-requested
/// override of that mock value: "ピル（選択プレート）の高さを上下一杯まで
/// 広がるようにしてほしい" -- the plate/sheen should reach the tab cell's
/// full available height (56, [_barHeight] minus [_barInnerPadding] on both
/// the top and bottom edges) rather than stopping 2px short of it on each
/// side. The horizontal inset is untouched: only the vertical spec changed.
///
/// This split only bites because of how [Stack] sizes itself. Every
/// [Positioned] inset here is relative to the tab's own [Stack] size, not
/// directly to the cell's available height -- and a loose (`StackFit.loose`,
/// the default) [Stack] with only one non-positioned child (the icon+label
/// [FittedBox] below) sizes itself to *that child's* natural size, not to
/// the full incoming constraint, the same "loose Stack shrinks to its one
/// non-positioned child" behavior [CruxSegmentedControl]'s own
/// `_CruxSegmentButtonState.build` works around with an explicit
/// `SizedBox(width: double.infinity, height: _visibleSegmentHeight)`
/// wrapper. This file works around the identical problem the same way, but
/// with a twist: [CruxSegmentedControl] forces its Stack to one *fixed*
/// height ([_visibleSegmentHeight], deliberately shorter than its own tap
/// target -- see that constant's doc), while this tab's Stack is forced,
/// via the `SizedBox.expand()` around it in
/// [_CruxNavTabButtonState.build], to whatever *loose* max height its
/// parent [Row] actually offers -- always exactly 56 here, since
/// [_barHeight] gives that [Row] a tight incoming height that it then
/// loosens for each tab. With the Stack now reliably sized to that full 56,
/// a `0` vertical inset is what makes the plate/sheen reach it edge to edge;
/// a nonzero value (like [_plateInsetHorizontal]) would instead leave the
/// same margin the mock specified, which is exactly what this override
/// removes.
const double _plateInsetVertical = 0;

/// The minimum tappable hit-region height/width for a single tab, matching
/// [CruxSegmentedControl]'s identically-named, independently-declared
/// `_minTapTarget`: 44 logical pixels. A purely defensive floor here (see
/// [_barHeight]'s own doc -- the bar's real 64px height, minus
/// [_barInnerPadding] on both edges, already clears this on its own), kept
/// as a real [ConstrainedBox] anyway so a future retuning of [_barHeight]
/// downward could never silently shrink a tab's tap target below this floor
/// without deliberately touching this constant too.
const double _minTapTarget = 44;

/// The gap between a tab's icon and its label, matching the mock's `.tab {
/// gap: 2px; }`.
const double _tabContentGap = 2;

/// The horizontal padding inside a single tab, around its icon+label
/// content -- a 2026-08-06 addition, matching
/// [CruxSegmentedControl]'s own `_segmentHorizontalPadding` (same value,
/// same role: breathing room between a cell's interactive content and its
/// own edge). Originally sized the pill itself, back when the 2026-08-06
/// "compact width" decision (see [CruxNavBar]'s own doc of that name)
/// made the whole pill hug its tabs' own content via an [IntrinsicWidth]
/// that measured this padding as part of each tab's content width; a
/// 2026-08-07 follow-up user decision replaced that scheme with a fixed
/// per-tab width ([_tabWidth], `88` -- see that constant's own doc for its
/// full provenance) that no longer depends on this padding's own
/// contribution to any measurement. This constant now purely governs how
/// much of that fixed 88px cell is left over for the icon+label content
/// once this padding is subtracted from both edges (`88 - 12 * 2 = 64`px)
/// -- the width a label must fit inside before its own already-configured
/// [TextOverflow.ellipsis] (the `Text` in [_CruxNavTabButtonState.build])
/// kicks in.
///
/// This value also happens to double as a defensive floor:
/// `_iconSize (24) + _tabHorizontalPadding * 2 (24) = 48`, comfortably
/// above [_minTapTarget] (`44`) -- so even setting [_tabWidth] itself
/// aside, the icon alone plus this padding never demands less than the
/// tap-target floor. This is a happy consequence of matching
/// [CruxSegmentedControl]'s value, not the reason `12` was chosen.
const double _tabHorizontalPadding = 12;

/// A single tab's own fixed width, in logical pixels -- the pill's overall
/// width is this value times the tab count plus [_barInnerPadding] on both
/// edges (see [CruxNavBar]'s own "Compact width" doc for the exact
/// formula), never driven by any [CruxNavItem.label]'s own text. A
/// 2026-08-07 user decision, replacing the 2026-08-06 "widest tab's own
/// content, measured via [IntrinsicWidth]" scheme this file previously
/// used (see `unknowns/navigation-bars/ledger.md`'s 2026-08-07 entry for the
/// superseded design and the reasoning behind this change): the value
/// first landed on the confirmed reference design's own measured
/// single-tab cell, `102` (width) x `54` (height), from a 2026-08-07 mock
/// the user supplied. Only the width half of that measurement was ever
/// used here -- the height half never was: [_barHeight] minus
/// [_barInnerPadding] on both edges already independently fixes each tab's
/// own available height at `56` (confirmed 2026-08-05, well before this
/// decision; see [_barHeight]'s own doc), and this file leaves that
/// untouched.
///
/// That `102` did not stay the final value: a same-day 2026-08-07
/// side-by-side comparison on a real device, across `102`/`88`/`76`/`68`,
/// settled on **`88`** instead (see `unknowns/navigation-bars/ledger.md`'s own
/// 2026-08-07 entry on this re-tuning for the full record). `68` was
/// rejected specifically: at that width a tab's own label column narrows
/// to `68 - _tabHorizontalPadding * 2 (24) = 44`px (see
/// [_tabHorizontalPadding]'s own doc for that subtraction), too narrow to
/// hold this package's own four-character "チャット" catalog label
/// (`widgetbook/lib/usecases/nav_bar.dart`'s own `_navItemPool`) without
/// its already-configured [TextOverflow.ellipsis] firing -- a label
/// silently truncating on an ordinary destination name is exactly the
/// failure this fixed-width scheme exists to avoid.
///
/// `88` comfortably clears both of a tab's own minimum-width floors:
/// [_minTapTarget] (`44`, the tappable hit region) and
/// `_iconSize (24) + _tabHorizontalPadding * 2 (24) = 48` (the icon plus
/// its own horizontal padding, [_tabHorizontalPadding]'s own defensive
/// -floor doc) -- so no tab ever needs to widen itself past this fixed
/// value to stay tappable or to fit its icon, and a caller never sees this
/// value shrink except when [_barMarginX]'s own host-width clamp forces
/// every tab to shrink together (see that constant's own doc).
const double _tabWidth = 88;

/// A tab's label font size, matching the mock's `.tab-label { font-size:
/// 11px; }` -- smaller than [CruxSegmentedControl]'s own 13px segment
/// label (`segmented_control.dart`'s `_CruxSegmentButtonState.build`),
/// since a nav tab's label sits underneath a 24px icon rather than being the
/// only content in its cell.
const double _labelFontSize = 11;

/// The floating pill's own **minimum** left/right margin from whatever it
/// is placed inside (a host [Stack]/[Column]'s own bounds) -- originally
/// the confirmed 2026-08-05 mock reaction (mock's `--bar-margin-x`
/// default), when the pill always filled its host's full available width
/// and this was therefore also the *exact* margin, never merely a floor.
///
/// A 2026-08-06 user decision ("（タブの）数に応じてコンパクトになるように
/// したい") changed what the pill itself measures: it now sizes to its own
/// tab count (see [CruxNavBar]'s own "Compact width" doc for the exact
/// formula, a fixed-per-tab-width formula since a 2026-08-07 follow-up
/// decision) instead of always stretching to fill the host, so its actual
/// on-screen margin is usually *wider* than this constant -- whatever
/// space is left over once the compact pill is centered in the host. This
/// constant still bounds the *narrow* end: [_CruxNavBarState.build]
/// reads its own incoming [BoxConstraints] via a [LayoutBuilder] and
/// computes the pill's actual rendered width as `math.min` of its own
/// fixed tab-count width and `hostWidth - _barMarginX * 2`, so that width
/// can never push its margin *below* this value -- a host too narrow for
/// every tab's fixed [_tabWidth] instead clamps the pill down to exactly
/// this margin on each side, and every tab (still an [Expanded] child of
/// the pill's own [Row]) shrinks equally below [_tabWidth], its label
/// falling back to its own already-configured ellipsis, rather than the
/// margin ever shrinking further or the pill overflowing its host.
const double _barMarginX = 16;

/// The floating pill's own bottom margin, added on top of whatever bottom
/// safe-area inset [MediaQuery] reports (see [CruxNavBar]'s class doc for
/// why this widget reads that inset itself rather than leaving it to its
/// host) -- the confirmed 2026-08-06 final value, `0`. This overrides the
/// mock's own `--bar-bottom-offset` default of `24`
/// (`unknowns/navigation-bars/mock-bottomnav.html`): the 2026-08-05 mock
/// reaction confirmed `24` first, but a 2026-08-06 side-by-side comparison
/// against `16`/`8`/`0` on a real device settled on `0` -- the pill now
/// floats flush with the safe-area inset itself, with no further gap added
/// on top of it.
const double _barBottomOffset = 0;

/// How tall [CruxNavBar]'s own backdrop-fade band is, in logical pixels,
/// measured up from this widget's own bottom edge -- the counterpart to
/// [CruxTopFade]'s `_fadeBandHeight` (`top_fade.dart`), reusing that same
/// confirmed `160` value rather than deriving a new one. `160` was chosen
/// there as a fixed spec value; it is reused here because it happens to
/// comfortably clear this widget's own worst-case vertical footprint with
/// real headroom to spare: [_barHeight] (`64`) plus a generous safe-area
/// allowance (a home-indicator inset is typically `~34`, and even a
/// landscape/foldable outlier sits in the `~40-50` range) leaves the pill's
/// own top edge at roughly `100-115`px up from this widget's bottom edge --
/// `160` still leaves `45-60`px of band *above* the pill's own top edge for
/// the scrim and blur to have visibly finished dissolving well before
/// reaching it, rather than the fade still being mid-transition right where
/// the pill begins. Unlike [CruxTopFade] (whose band is measured against
/// its *child's* actual rendered height, since that child can be
/// arbitrarily tall or short), this band's height is never clamped against
/// anything -- [CruxNavBar] has no content of its own to measure, so this
/// constant is simply this widget's fixed vertical footprint whenever
/// [CruxNavBar.backdropFade] is `true` (see [_CruxNavBarState.build]'s
/// own `math.max` against the pill's own floating total height, a
/// defensive fallback for the case where an exotic safe-area inset somehow
/// exceeds this constant's own headroom).
const double _backdropBandHeight = 160;

/// How many color stops the backdrop scrim's gradient uses -- identical
/// value and role to [CruxTopFade]'s own `_fadeStopCount` (`top_fade
/// .dart`). Duplicated rather than imported, the same "no shared refactor
/// this milestone" choice every other constant in this file already makes
/// relative to `segmented_control.dart` -- here the mirrored file is
/// `top_fade.dart` instead. See [_buildBackdropScrimDecoration]'s own doc
/// for how this constant is actually used.
const int _backdropScrimStopCount = 5;

/// The power-curve exponent the backdrop scrim's per-stop alpha is raised
/// to -- identical value and role to [CruxTopFade]'s own
/// `_fadeCurveStrength`. See [_buildBackdropScrimDecoration]'s own doc for
/// how this file's version of that curve is actually wired up (this widget
/// paints its own opaque-to-transparent scrim directly, rather than
/// masking a child's alpha via `BlendMode.dstIn` the way [CruxTopFade]
/// does, since it has no child of its own to mask).
const double _backdropScrimCurveStrength = 1.6;

/// How many compounding blur layers [CruxNavBar] stacks behind the pill
/// whenever [CruxNavBar.backdropBlurSigma] is greater than zero --
/// identical value and role to [CruxTopFade]'s own `_blurLayerCount`.
/// Six layers is [CruxTopFade]'s own proven "no visible banding" recipe
/// (extracted from the confirmed mock's six `.blur-layer` divs -- see that
/// constant's own doc); reused verbatim here rather than re-deriving a new
/// layer count, since the same "sharper near the true edge, near
/// -imperceptible farther away" look, and the same "no banding" bar, apply
/// to this band too.
const int _backdropBlurLayerCount = 6;

/// Each backdrop blur layer's own blur radius, as a fraction of
/// [CruxNavBar.backdropBlurSigma] -- identical values and role to
/// [CruxTopFade]'s own `_blurLayerRadiusFractions`. Index 0 is the
/// weakest layer (reaches furthest up the band, per
/// [_backdropBlurLayerDecayFractions]'s matching index); index
/// [_backdropBlurLayerCount] - 1 is the strongest (`1.0`, the full
/// [CruxNavBar.backdropBlurSigma]) but stays concentrated closest to this
/// band's own bottom edge (this widget's true edge -- see
/// [_buildBackdropBlurLayerDecayShader]'s own doc for why that is the
/// *opposite* physical side from [CruxTopFade]'s own true edge).
const List<double> _backdropBlurLayerRadiusFractions = <double>[
  0.17,
  0.33,
  0.5,
  0.67,
  0.83,
  1.0,
];

/// Each backdrop blur layer's own decay reach, as a fraction of
/// [_backdropBandHeight] -- identical values and role to [CruxTopFade]'s
/// own `_blurLayerDecayFractions`, paired index-for-index with
/// [_backdropBlurLayerRadiusFractions] the same way that file pairs its own
/// two arrays. Unlike [CruxTopFade] (whose true edge sits at its band's
/// own *top*, so a layer's decay reach is measured growing *downward* from
/// position `0`), this widget's true edge is this band's own *bottom*
/// (this widget's screen-bottom edge) -- see
/// [_buildBackdropBlurLayerDecayShader]'s own doc for how the decay math is
/// actually mirrored to grow *upward* from the bottom instead, using these
/// same reach fractions.
const List<double> _backdropBlurLayerDecayFractions = <double>[
  1.0,
  0.87,
  0.74,
  0.61,
  0.48,
  0.35,
];

/// How many steps each backdrop blur layer's own decay gradient is sampled
/// at -- identical value and role to [CruxTopFade]'s own
/// `_blurLayerDecaySteps`.
const int _backdropBlurLayerDecaySteps = 10;

/// The power-curve exponent each backdrop blur layer's own decay gradient
/// is raised to -- identical value and role to [CruxTopFade]'s own
/// `_blurLayerDecayCurveStrength`.
const double _backdropBlurLayerDecayCurveStrength = 1.6;

/// [CruxNavBar.backdropBlurSigma]'s default -- identical value and role
/// to [CruxTopFade]'s own `_defaultBlurSigma` (`top_fade.dart`).
const double _defaultBackdropBlurSigma = 8;

/// How long the newly selected tab's plate takes to fade in, once it starts
/// appearing -- identical value and role to
/// [CruxSegmentedControl]'s `_plateFadeInDuration`; see that constant's
/// doc for the confirmed spec this mirrors. Duplicated here, not imported,
/// per `unknowns/navigation-bars/impact.md`: this milestone deliberately does
/// not refactor [CruxSegmentedControl]'s plate/sheen into shared code.
const Duration _plateFadeInDuration = Duration(milliseconds: 200);

/// The just-deselected tab's plate fade-out duration -- identical value and
/// role to [CruxSegmentedControl]'s `_plateFadeOutDuration`.
const Duration _plateFadeOutDuration = Duration(milliseconds: 140);

/// The plate's scale immediately before it starts appearing -- identical
/// value and role to [CruxSegmentedControl]'s `_plateAppearStartScale`.
const double _plateAppearStartScale = 0.8;

/// The kira sheen's tilt, in degrees -- identical value and role to
/// [CruxSegmentedControl]'s `_sheenTiltDegrees`.
const double _sheenTiltDegrees = 4;

/// The kira sheen's peak highlight opacity -- identical value and role to
/// [CruxSegmentedControl]'s `_sheenPeakAlpha`.
const double _sheenPeakAlpha = 0.24;

/// The kira sheen's edge-shadow opacity -- identical value and role to
/// [CruxSegmentedControl]'s `_sheenEdgeAlpha`.
const double _sheenEdgeAlpha = 0.05;

/// The kira sheen's blur, in logical pixels -- identical value and role to
/// [CruxSegmentedControl]'s `_sheenBlurSigma`.
const double _sheenBlurSigma = 8;

/// The kira sheen's sweep duration -- identical value and role to
/// [CruxSegmentedControl]'s `_sheenDuration`.
const Duration _sheenDuration = Duration(milliseconds: 300);

/// How long after a real selection change the kira sheen starts sweeping --
/// identical value and role to [CruxSegmentedControl]'s `_sheenDelay`.
const Duration _sheenDelay = Duration(milliseconds: 90);

/// The sheen band's width as a fraction of its tab's own width -- identical
/// value and role to [CruxSegmentedControl]'s `_sheenWidthFraction`.
const double _sheenWidthFraction = 0.38;

/// How far past each edge of a tab the sheen band travels before/after the
/// sweep, as a multiple of the band's own width -- identical value and role
/// to [CruxSegmentedControl]'s `_sheenOvertravel`.
const double _sheenOvertravel = 1.3;

/// A single destination inside a [CruxNavBar].
///
/// [value] is the destination this item represents (compared with `==`
/// against [CruxNavBar.selected] to decide which item is selected, and
/// passed to [CruxNavBar.onChanged] when tapped) -- the same "caller's [T]
/// needs a meaningful `==`" assumption [CruxSegment] documents. [icon] is
/// a caller-supplied [Widget], never an `IconData` -- the same convention
/// [CruxIconButton.icon] and [CruxInputBarSubmit] already use, so this
/// package never needs to know which icon system (Material, Cupertino, a
/// custom SVG) produced it. [label] is always shown underneath [icon] (see
/// [CruxNavBar]'s class doc: unlike [CruxSegmentedControl], a nav item's
/// label is never optional or conditionally hidden).
@immutable
class CruxNavItem<T> {
  /// Creates a nav bar destination.
  const CruxNavItem({
    required this.value,
    required this.icon,
    required this.label,
  });

  /// The destination this item represents.
  final T value;

  /// The icon shown above [label], rendered at a fixed [_iconSize] via an
  /// ambient [IconThemeData] -- see [CruxNavItem]'s own doc.
  final Widget icon;

  /// The item's visible label, always shown (never hidden), on a single
  /// line with an ellipsis.
  final String label;
}

/// A floating, pill-shaped bottom navigation bar: Crux UI's tab-switcher
/// atom for 3-5 top-level destinations, each rendered as an icon over an
/// always-visible label.
///
/// ```dart
/// Stack(
///   alignment: Alignment.bottomCenter,
///   children: [
///     content,
///     CruxNavBar<AppTab>(
///       items: const <CruxNavItem<AppTab>>[
///         CruxNavItem(value: AppTab.home, icon: Icon(...), label: 'ホーム'),
///         CruxNavItem(value: AppTab.chat, icon: Icon(...), label: 'チャット'),
///         CruxNavItem(value: AppTab.settings, icon: Icon(...), label: '設定'),
///       ],
///       selected: currentTab,
///       onChanged: (AppTab next) => setState(() => currentTab = next),
///     ),
///   ],
/// )
/// ```
///
/// **Controlled widget**: the same convention [CruxSegmentedControl] uses.
/// [CruxNavBar] always reflects [selected] and never mutates it itself,
/// notifying [onChanged] with the tapped item's value so the caller decides
/// whether and how to update its state. Set [onChanged] to `null` to render
/// every item disabled (Flutter convention). Tapping the *already-selected*
/// item does not call [onChanged] -- there is nothing new to notify, and it
/// keeps this widget's selection-changed effects (the plate and the kira
/// sheen below) correctly gated to real changes, exactly like
/// [CruxSegmentedControl]'s own identically-reasoned contract.
/// [items] must have at least two entries (an `assert`, matching
/// [CruxSegmentedControl]'s own "at least two" floor) -- 3-5 is the
/// intended range for a real bottom nav, but nothing below this widget's own
/// layout enforces an upper bound.
///
/// **Visual language**: this pill borrows [CruxSegmentedControl]'s
/// confirmed "案A" selection language (2026-08-05 mock reaction,
/// `unknowns/navigation-bars/mock-bottomnav.html`) rather than a sliding thumb:
/// the selected item's own plate fades and scale-springs in
/// (`0.8 -> ~1.02 -> 1.0`) while every other item's plate stays hidden, and
/// about [_sheenDelay] after a real selection change, a diagonal "kira"
/// light sweep plays once across the newly selected item's plate, tilted
/// and swept in the direction of travel. Nothing ever slides or translates
/// between items. This file re-implements that plate/sheen machinery
/// locally rather than importing `segmented_control.dart`
/// (`unknowns/navigation-bars/impact.md`: this milestone does not refactor
/// [CruxSegmentedControl] into shared code) -- every constant above notes
/// which of `segmented_control.dart`'s own constants it mirrors.
///
/// **Floating shape and safe area**: unlike every other Crux component,
/// [CruxNavBar] reads [MediaQuery]'s bottom safe-area inset itself
/// (falling back to zero with no [MediaQuery] ancestor, via
/// `MediaQuery.maybePaddingOf`) and bakes its own outer margin
/// ([_barMarginX] left/right, that inset plus [_barBottomOffset] on the
/// bottom) into its own layout, rather than expecting a host to place and
/// margin it. A host only needs to put this widget at the bottom of a
/// [Stack] or [Column] -- for example `Stack(alignment:
/// Alignment.bottomCenter, children: [content, CruxNavBar(...)])` -- and
/// the floating gap on all sides, including safe area, is already built in.
/// This is deliberately a first-of-its-kind pattern for this package (see
/// `unknowns/navigation-bars/ledger.md`): it does not change how any existing
/// component (for example [CruxToastHost]'s own, differently-shaped fixed
/// insets) reads safe area. With [backdropFade] at its default `true`, this
/// widget's own reported size grows taller than just the pill's own margin
/// box (see this class's own "Backdrop fade" doc below) -- a host stacking
/// [CruxNavBar] at the bottom of a [Stack]/[Column] does not need to
/// account for that itself, the same "host only needs to place it" contract
/// above still holds, since the extra height is purely this widget's own
/// band and never shifts where the pill itself ends up.
///
/// **Compact width**: the floating pill's own width is driven purely by
/// how many tabs it has, never by any tab's own label. A 2026-08-06 user
/// decision ("（タブの）数に応じてコンパクトになるようにしたい") first made
/// the pill hug its tabs' content instead of always stretching to fill
/// this widget's own full available width; a 2026-08-07 follow-up
/// decision (a reference design the user supplied, its own single-tab
/// cell measured at 102x54 -- see [_tabWidth]'s own doc for the full
/// provenance, including that same day's later real-device re-tuning of
/// the value itself down to `88`) replaced that content-hugging
/// measurement with a fixed per-tab width, so two bars with the *same*
/// item count always float the identical pill width regardless of how
/// long or short either one's labels are. The pill's own natural width is
/// exactly `_tabWidth * items.length + _barInnerPadding * 2` -- so a
/// 3-item bar's pill is visibly narrower than a 4-item bar's by exactly
/// one [_tabWidth]. Every tab still shares that one equal [_tabWidth], as
/// an [Expanded] child of the pill's own [Row] (unchanged since before
/// either decision) -- a label too wide for its own tab
/// (`_tabWidth - _tabHorizontalPadding * 2` = 64px of content width, see
/// that constant's own doc) falls back to its existing single-line
/// [TextOverflow.ellipsis], never widening the tab or the pill to
/// accommodate it. The pill is then centered horizontally in this
/// widget's own full width via `Center(heightFactor: 1.0)` -- the same
/// `heightFactor: 1.0` fix `unknowns/navigation-bars/implementation-notes.md`
/// already used once this milestone, on the now-removed
/// `CruxFloatingHeader`, for the identical reason: a bare [Center]
/// (or [Align] without an explicit `heightFactor`) expands to fill *both*
/// axes of any bounded incoming constraint, not just the axis being
/// centered on, which would have silently inflated this widget's own
/// reported height to match its ambient host's height instead of staying
/// snug around the pill.
///
/// [_barMarginX] still bounds the *narrowest* this pill is ever allowed to
/// get relative to its host (see that constant's own doc for the exact
/// [LayoutBuilder] mechanism): [_CruxNavBarState.build] computes
/// `math.min` of the pill's own fixed tab-count width above and
/// `hostWidth - _barMarginX * 2`, so a host too narrow for every tab's
/// fixed [_tabWidth] clamps the pill down to that minimum margin rather
/// than overflowing it, and every tab shrinks below [_tabWidth] by the
/// same equal share (each [Expanded] child still receiving an identical
/// fraction of that clamped width), falling back to its own
/// already-configured single-line ellipsis rather than throwing a layout
/// exception. The backdrop-fade band (below) is **not** affected by any of
/// this: it stays this widget's own full, edge-to-edge width regardless of
/// how compact the pill itself gets -- only the pill compacts and
/// re-centers.
///
/// **Color mapping**: the confirmed mock renders the pill's own background
/// as an opaque, unelevated fill and each selected item's plate as a
/// separately-lifted surface sitting on top of it -- mapped here to
/// [CruxColors.surface] for the pill (matching the mock's `--c-surface`)
/// and, for the plate, a brightness-split fill computed by the private
/// [_plateColor] helper (see that function's own doc for the full
/// 2026-08-06 reasoning): [CruxColors.controlFill] in light,
/// [CruxColors.controlPlate] in dark -- the same plate token
/// [CruxSegmentedControl]'s own selection plate uses for dark, but not
/// for light, where that token is defined identical to [CruxColors
/// .surface] (see that token's own doc) and would otherwise leave a
/// selected item's plate on this pill completely indistinguishable from
/// the pill itself. The plate is painted with **no shadow of its own** --
/// a 2026-08-06 confirmed decision (an earlier cut carried
/// [CruxShadows.xs], the same "barely lifted" shadow
/// [CruxSegmentedControl]'s own selection plate still uses, but a
/// side-by-side comparison on a real device settled on dropping it
/// entirely): with [_plateColor] already giving the plate a real, visible
/// fill difference from the pill's own [CruxColors.surface] background
/// in both themes, a shadow on top added no further legibility, only
/// visual noise on a control this small. The pill's own outer floating
/// shadow is [CruxShadows.sm] (the confirmed mock reaction) --
/// unaffected by this change, since the whole pill, not just its selected
/// item, still needs to visibly lift off whatever content scrolls beneath
/// it (now doubly so with the backdrop-fade band below also leaning on
/// that same background/surface distinction -- see this class's own
/// "Backdrop fade" doc). An item's icon and label color is resolved the
/// same way [CruxSegmentedControl]'s own label color is (never a
/// fractional icon opacity, unlike the mock's own CSS approximation):
/// [CruxColors.textPrimary] while selected, [CruxColors.textSecondary]
/// while unselected, [CruxColors.muted] while disabled -- propagated to
/// the caller-supplied [CruxNavItem.icon] via an ambient
/// [IconThemeData]/[DefaultTextStyle], the same [CruxIconButton]
/// mechanism [CruxNavItem.icon]'s own doc cites.
///
/// **Label weight**: on top of that selected/unselected color distinction,
/// a 2026-08-07 user decision also makes the *selected* tab's own label
/// bold. [CruxTypography.label] (the type-scale entry this label's style
/// is built from, in [_CruxNavTabButtonState.build]) carries its own base
/// weight, `FontWeight.w600` -- unchanged for an unselected label. A
/// selected label overrides that to `FontWeight.bold` (`w700`), one step
/// up the scale. This is a deliberate departure from
/// [CruxSegmentedControl]'s own segment label, which distinguishes
/// selected from unselected by color alone and was left untouched by this
/// decision -- chosen here because this label's own [_labelFontSize]
/// (`11`px) is smaller than that segment label's (`13`px), small enough
/// that a color-only difference reads too subtly on some devices/lighting,
/// while a one-step weight bump stays visibly legible even at `11`px.
/// Because [_tabWidth] is a fixed value that a label's own measured width
/// never feeds back into (see that constant's own doc), a selected label's
/// slightly wider bold glyphs never move or resize its own tab or the pill
/// around it -- only the label repaints heavier, in place.
///
/// **Backdrop fade**: whenever [backdropFade] is `true` (the default),
/// this widget also draws a full-width, edge-to-edge band directly behind
/// the floating pill, anchored to this widget's own bottom edge and
/// reaching [_backdropBandHeight] logical pixels up from it -- comfortably
/// covering the pill's own worst-case height plus a generous safe-area
/// allowance, with room to spare (see that constant's own doc for the
/// exact headroom math). Scrolling content placed behind [CruxNavBar] in
/// a host [Stack] therefore appears to melt into the page as it approaches
/// the screen's bottom edge -- the same "progressive fade" effect
/// [CruxTopFade] gives the *top* edge of a scrolling child, mirrored
/// top-to-bottom, except this band paints its *own*
/// [CruxColors.background]-colored scrim rather than masking a child it
/// wraps: unlike [CruxTopFade], [CruxNavBar] has no child of its own to
/// mask -- whatever should melt away is an entirely separate sibling
/// elsewhere in the host's own [Stack]. Two layers, identical in spirit to
/// [CruxTopFade]'s own two ([_buildBackdropScrimDecoration]'s and
/// [_BackdropBlurLayer]'s own docs spell out exactly how each mirrors its
/// `top_fade.dart` counterpart): a [CruxColors.background] gradient
/// scrim (fully transparent [_backdropBandHeight] pixels up from this
/// widget's bottom edge, fully opaque exactly at it, [_backdropScrimStopCount]
/// stops biased by a [_backdropScrimCurveStrength] power curve -- the same
/// "no visible banding" recipe [CruxTopFade]'s own fade uses), and, when
/// [backdropBlurSigma] is greater than zero (the default is
/// [_defaultBackdropBlurSigma] (`8`), matching [CruxTopFade]'s own
/// default), [_backdropBlurLayerCount] compounding, gradient-masked
/// [BackdropFilter] layers reusing that same recipe's blur-layer
/// counterpart. Set [backdropBlurSigma] to `0` to keep the scrim but skip
/// building any [BackdropFilter] at all (no backdrop-filter compositing
/// cost paid for an effect nobody asked for -- the same escape hatch
/// [CruxTopFade.blurSigma] documents), or set [backdropFade] to `false`
/// to skip the *entire* band, scrim included -- for a caller that, for
/// example, floats [CruxNavBar] over content that is not
/// [CruxColors.background] and would rather have no fade than a visibly
/// mistinted one (see the next paragraph). The whole band is wrapped in
/// [IgnorePointer]: it never intercepts a tap or a scroll gesture meant
/// for whatever sits behind it, and the pill itself (a separate sibling in
/// this widget's own internal [Stack], never nested inside the band)
/// keeps its own tap handling and [Semantics] completely unaffected by any
/// of this.
///
/// Because the scrim is a flat [CruxColors.background] wash rather than
/// a true blur-through of whatever is actually behind it, this backdrop
/// fade only reads correctly when the host's own content actually sits on
/// [CruxColors.background]. Over a full-bleed image or any other surface,
/// the scrim will visibly tint it the wrong color as it approaches full
/// opacity near the bottom edge -- pass `backdropFade: false` in that case
/// rather than accepting the mismatch.
///
/// Set [MediaQuery.disableAnimationsOf] (read via
/// `MediaQuery.maybeDisableAnimationsOf(context) ?? false`, so this widget
/// still works with no [MediaQuery] ancestor at all) to suppress both the
/// plate's spring/fade and the kira sheen: the plate then jumps directly to
/// its resting opacity/scale and the sheen never sweeps, the same
/// [CruxSegmentedControl] reduce-motion contract.
///
/// Built from plain [GestureDetector] and painting widgets, never Material's
/// `BottomNavigationBar`, so it never depends on or is affected by an
/// ambient Material `ThemeData` -- and, like every Crux component, never
/// imports `package:flutter/material.dart` or `package:flutter/cupertino.dart`.
class CruxNavBar<T> extends StatefulWidget {
  /// Creates a Crux floating nav bar.
  const CruxNavBar({
    super.key,
    required this.items,
    required this.selected,
    this.onChanged,
    this.backdropFade = true,
    this.backdropBlurSigma = _defaultBackdropBlurSigma,
  });

  /// The ordered list of destinations this bar presents. Must have at least
  /// two entries -- see this class's own doc.
  final List<CruxNavItem<T>> items;

  /// The currently selected value. Must equal exactly one of [items]' values
  /// for the bar to show a selection.
  final T selected;

  /// Called with an item's value when that item is tapped while a
  /// *different* item is selected. Pass `null` to disable every item in the
  /// bar.
  final ValueChanged<T>? onChanged;

  /// Whether this widget draws its own backdrop-fade band behind the
  /// floating pill -- see this class's own "Backdrop fade" doc for what
  /// that band is and why a caller might turn it off. Defaults to `true`;
  /// pass `false` to draw the pill alone with no band at all, not even the
  /// scrim.
  final bool backdropFade;

  /// The backdrop-fade band's blur strength, passed straight through to
  /// [ImageFilter.blur] as a sigma -- the same "no unit conversion, the
  /// mock's CSS blur px values used verbatim" convention
  /// [CruxTopFade.blurSigma] documents. Defaults to
  /// [_defaultBackdropBlurSigma] (`8`), matching [CruxTopFade]'s own
  /// default. Set to `0` to skip every [BackdropFilter] layer while keeping
  /// the scrim -- see this class's own "Backdrop fade" doc. Has no effect
  /// at all when [backdropFade] is `false`.
  final double backdropBlurSigma;

  @override
  State<CruxNavBar<T>> createState() => _CruxNavBarState<T>();
}

class _CruxNavBarState<T> extends State<CruxNavBar<T>> {
  Timer? _sheenDelayTimer;

  /// Each item's own kira sheen trigger count, keyed by [CruxNavItem.
  /// value] -- identical role to [CruxSegmentedControl]'s own
  /// `_sheenTriggerByValue` (see that field's doc for why an item's count is
  /// never reset once it has one, even after the sheen moves to a different
  /// item: a still-sweeping sheen must be free to finish on its own
  /// schedule).
  final Map<T, int> _sheenTriggerByValue = <T, int>{};

  /// Each item's own sweep direction (`true` for left-to-right) -- identical
  /// role to [CruxSegmentedControl]'s own `_sheenLtrByValue`.
  final Map<T, bool> _sheenLtrByValue = <T, bool>{};

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(covariant CruxNavBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) {
      return;
    }
    final int oldIndex = widget.items.indexWhere(
      (CruxNavItem<T> item) => item.value == oldWidget.selected,
    );
    final int newIndex = widget.items.indexWhere(
      (CruxNavItem<T> item) => item.value == widget.selected,
    );
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) {
      // Same gate [CruxSegmentedControl] applies: either endpoint isn't in
      // the current item list, or nothing actually moved -- no sheen.
      return;
    }
    _scheduleSheen(target: widget.selected, movesRight: newIndex > oldIndex);
  }

  /// Schedules [target]'s kira sheen to start after [_sheenDelay] -- the
  /// same delayed-trigger mechanism, and the same "never reset a
  /// no-longer-targeted item's own trigger" rapid-retarget fix,
  /// [CruxSegmentedControl]'s own `_scheduleSheen` documents in full.
  void _scheduleSheen({required T target, required bool movesRight}) {
    _sheenDelayTimer?.cancel();
    _sheenDelayTimer = Timer(_sheenDelay, () {
      setState(() {
        _sheenTriggerByValue[target] = (_sheenTriggerByValue[target] ?? 0) + 1;
        _sheenLtrByValue[target] = movesRight;
      });
    });
  }

  void _handleItemTap(T value) {
    if (value == widget.selected) {
      // Re-tapping the already-selected item notifies nothing -- see this
      // class's own doc for why.
      return;
    }
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    _sheenDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.length >= 2,
      'CruxNavBar needs at least two items to be a meaningful tab '
      'switcher.',
    );
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final bool enabled = _enabled;

    // Read safe area with the "maybe" family (never the asserting
    // `MediaQuery.paddingOf`) so this widget still lays out with no
    // MediaQuery ancestor at all -- see this class's own "Floating shape
    // and safe area" doc.
    final double safeAreaBottom =
        MediaQuery.maybePaddingOf(context)?.bottom ?? 0;

    // A LayoutBuilder rather than reading `constraints` some other way: this
    // is the one place this widget needs its own incoming BoxConstraints
    // (specifically their maxWidth) to compute the pill's own clamp -- see
    // _barMarginX's own doc for the full "minimum margin" contract this
    // implements.
    final Widget pill = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // `constraints.maxWidth - _barMarginX * 2`, floored at 0 -- when
        // maxWidth is unbounded (double.infinity), infinity minus a finite
        // amount is still infinity, so this naturally degrades to "no
        // clamp" with no separate branch needed.
        final double maxPillWidth = math.max(
          0.0,
          constraints.maxWidth - _barMarginX * 2,
        );
        // The pill's own natural width: a fixed _tabWidth per tab plus the
        // inner padding on both edges -- see CruxNavBar's own "Compact
        // width" doc and _tabWidth's own doc for the full 2026-08-07
        // reference-design provenance this formula implements. `math.min`
        // against maxPillWidth above is the entire clamp: when the natural
        // width already fits, it wins outright and every tab renders at
        // exactly _tabWidth; otherwise every tab (still Expanded below)
        // shrinks by an equal share of the clamped total instead of the
        // pill overflowing its host.
        final double pillWidth = math.min(
          _tabWidth * widget.items.length + _barInnerPadding * 2,
          maxPillWidth,
        );

        return Padding(
          padding: EdgeInsets.only(bottom: safeAreaBottom + _barBottomOffset),
          // heightFactor: 1.0 keeps this Center snug to the pill's own
          // height rather than expanding to fill this widget's own ambient
          // height too -- see CruxNavBar's own "Compact width" doc for
          // the `floating_header.dart` precedent this mirrors.
          child: Center(
            heightFactor: 1.0,
            // A SizedBox at the exact computed pillWidth, not merely a
            // maxWidth constraint: the pill's own width is now fully
            // determined by tab count above, never measured from its
            // tabs' own content the way an earlier [IntrinsicWidth]-based
            // scheme once did -- see CruxNavBar's own "Compact width"
            // doc for the 2026-08-07 decision this replaces.
            child: SizedBox(
              width: pillWidth,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.surface,
                  shadows: theme.shadows.sm,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(CruxRadii.pill),
                    ),
                  ),
                ),
                child: SizedBox(
                  height: _barHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(_barInnerPadding),
                    child: Row(
                      children: <Widget>[
                        for (final CruxNavItem<T> item in widget.items)
                          Expanded(
                            key: ValueKey<T>(item.value),
                            child: _CruxNavTabButton<T>(
                              icon: item.icon,
                              label: item.label,
                              selected: item.value == widget.selected,
                              enabled: enabled,
                              onTap: enabled
                                  ? () => _handleItemTap(item.value)
                                  : null,
                              sheenTrigger:
                                  _sheenTriggerByValue[item.value] ?? 0,
                              sheenLtr: _sheenLtrByValue[item.value] ?? true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!widget.backdropFade) {
      // No band at all -- return the pill exactly as this widget always
      // returned it before the backdrop-fade band existed, byte-for-byte
      // the same widget tree (see this class's own "Backdrop fade" doc for
      // when a caller would want this).
      return pill;
    }

    // The band is a fixed _backdropBandHeight regardless of safe area (see
    // that constant's own doc); math.max guards the defensive edge case
    // where an exotic safe-area inset would otherwise leave the pill's own
    // margin box taller than the band meant to sit behind it.
    final double pillTotalHeight =
        _barHeight + safeAreaBottom + _barBottomOffset;

    return SizedBox(
      height: math.max(pillTotalHeight, _backdropBandHeight),
      // `alignment: bottomCenter` bottom-aligns both children without
      // needing an explicit `Positioned` on either: the band already
      // requests its own full width/fixed height via the `SizedBox` inside
      // _buildBackdropBand, and the pill already requests its own full
      // width/fixed height via the Padding/DecoratedBox/SizedBox chain
      // above -- both simply need to be pinned to this outer SizedBox's
      // bottom edge, which `bottomCenter` does for any non-positioned Stack
      // child regardless of its own size.
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          _buildBackdropBand(theme, widget.backdropBlurSigma),
          pill,
        ],
      ),
    );
  }

  /// Builds [CruxNavBar]'s own backdrop-fade band -- see that class's own
  /// "Backdrop fade" doc for what it is and why. Always [_backdropBandHeight]
  /// tall and this widget's own full width (ignoring [_barMarginX] entirely,
  /// unlike the pill itself -- the band must reach this widget's own left
  /// /right edges to read as edge-to-edge, per the confirmed spec), anchored
  /// to this widget's own bottom edge by the outer [Stack]'s own
  /// `alignment: bottomCenter` in [build] above, not by anything in this
  /// function itself. Always wrapped in [IgnorePointer]: this band is
  /// purely decorative, and every tap or scroll gesture aimed at whatever
  /// sits behind [CruxNavBar] in its host's own [Stack] must reach it
  /// completely unobstructed -- the same contract [CruxTopFade]'s own
  /// blur overlay documents (`top_fade.dart`), applied here to the *entire*
  /// band (scrim included) since, unlike that file, this band has no child
  /// of its own that already sits underneath it in the same subtree.
  ///
  /// Painted blur-first, scrim-on-top (when both are present): the blur
  /// layers blur whatever is already composited behind this band (a
  /// sibling widget elsewhere in the host's own tree, never anything in
  /// this subtree), and the scrim's own increasingly-opaque wash then tints
  /// that already-blurred result -- the familiar "frosted glass with a
  /// tint on top" layering, rather than tinting first and then blurring the
  /// tint itself.
  Widget _buildBackdropBand(CruxThemeData theme, double backdropBlurSigma) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: _backdropBandHeight,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (backdropBlurSigma > 0)
              for (int i = 0; i < _backdropBlurLayerCount; i++)
                _BackdropBlurLayer(
                  sigma:
                      backdropBlurSigma * _backdropBlurLayerRadiusFractions[i],
                  decayFraction: _backdropBlurLayerDecayFractions[i],
                ),
            DecoratedBox(
              decoration: _buildBackdropScrimDecoration(theme.colors),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the backdrop scrim's own gradient decoration: a vertical
/// [LinearGradient] of [CruxColors.background], fully transparent at
/// this band's own top edge and fully opaque at its own bottom edge (this
/// widget's true, screen-bottom edge) -- painted directly as a filled box
/// rather than a `ShaderMask` over some child, since (unlike
/// [CruxTopFade], which fades an actual scrollable child it wraps) this
/// widget has no child of its own to mask: whatever should visually melt
/// away is an entirely separate sibling in the host's own [Stack], sitting
/// *behind* this band in paint order, and a solid, increasingly-opaque
/// [CruxColors.background] wash achieves the same "melts into the page"
/// look for it without this widget ever needing a reference to it.
///
/// Reuses [CruxTopFade]'s own `_buildFadeShader` stop construction
/// (`top_fade.dart`) essentially unchanged -- [_backdropScrimStopCount]
/// stops at `t = i / (stopCount - 1)`, each alpha biased by `pow(t,
/// [_backdropScrimCurveStrength])` -- needing no "flip" of its own despite
/// this band's true edge sitting at the opposite physical side from
/// [CruxTopFade]'s: a [LinearGradient]'s own `stops` are always read
/// relative to *this gradient's own box*, top-to-bottom, and this box's
/// bottom already *is* this widget's true edge (anchored there by
/// [_CruxNavBarState._buildBackdropBand]'s own placement inside the
/// bottom-aligned outer [Stack], not by anything in this function). So
/// stop `0` (this box's own top, alpha `0`) already lands away from the
/// edge, and stop `1` (this box's own bottom, alpha `1`) already lands
/// exactly at it, with no further inversion needed. Contrast
/// [_buildBackdropBlurLayerDecayShader], whose own decay math *does* need
/// an explicit mirror -- see that function's own doc for why the two
/// differ.
BoxDecoration _buildBackdropScrimDecoration(CruxColors colors) {
  final List<double> stops = <double>[];
  final List<Color> gradientColors = <Color>[];
  for (int i = 0; i < _backdropScrimStopCount; i++) {
    final double t = i / (_backdropScrimStopCount - 1);
    final double alpha = math.pow(t, _backdropScrimCurveStrength).toDouble();
    stops.add(t);
    gradientColors.add(colors.background.withValues(alpha: alpha));
  }
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradientColors,
      stops: stops,
    ),
  );
}

/// One compounding backdrop blur layer inside [CruxNavBar]'s band:
/// mirrors [CruxTopFade]'s own private `_BlurLayer` (`top_fade.dart`)
/// almost exactly -- a [BackdropFilter] at [sigma], masked by its own decay
/// gradient reaching [decayFraction] of the way up this band before hitting
/// zero alpha. The only real difference from that file's version is the
/// decay gradient's own direction: see
/// [_buildBackdropBlurLayerDecayShader]'s own doc for why this layer's
/// decay must be mirrored (grown upward from this band's own bottom)
/// rather than reused unchanged the way [_buildBackdropScrimDecoration]
/// above is. Returns a [Positioned.fill] directly from [build] for the
/// same reason [CruxTopFade]'s own `_BlurLayer` does -- see that class's
/// own doc.
class _BackdropBlurLayer extends StatelessWidget {
  const _BackdropBlurLayer({required this.sigma, required this.decayFraction});

  /// This layer's own [ImageFilter.blur] sigma -- already
  /// [CruxNavBar.backdropBlurSigma] scaled by this layer's
  /// [_backdropBlurLayerRadiusFractions] entry.
  final double sigma;

  /// How far up this band (as a fraction of this layer's own rendered
  /// height) this layer's decay gradient reaches before hitting zero alpha
  /// -- this layer's own [_backdropBlurLayerDecayFractions] entry.
  final double decayFraction;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) =>
            _buildBackdropBlurLayerDecayShader(bounds, decayFraction),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          // Same "needs a child only to be given a size, paints nothing of
          // its own" reasoning as CruxTopFade's own _BlurLayer -- see
          // that class's own doc.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Builds one [_BackdropBlurLayer]'s own decay-mask shader. Mirrors
/// [CruxTopFade]'s own `_buildBlurLayerDecayShader` (`top_fade.dart`),
/// but grown from this band's own *bottom* instead of its top: that
/// function concentrates full alpha (`1`, maximum blur strength) at
/// position `0` (its own band's own top, which is [CruxTopFade]'s true
/// edge) and decays it toward `0` moving *down*, by [decayFraction] of the
/// way, pinning everything below that at `0`. This band's true edge is the
/// *opposite* physical side of its own box (its bottom, this widget's
/// screen-bottom edge -- see [_buildBackdropScrimDecoration]'s own doc for
/// why), so reusing that formula completely unmirrored would concentrate
/// full blur strength at this band's *top* -- the farthest point from the
/// true edge, exactly backwards from the desired "strongest right at the
/// edge, fading out away from it" look.
///
/// This function instead concentrates full alpha (`1`) at position `1`
/// (this band's own bottom) and decays it toward `0` moving *up*, by
/// [decayFraction] of the way: a leading stop is pinned to `0` alpha at
/// position `0` (this band's own top) for the region beyond this layer's
/// own reach, followed by [_backdropBlurLayerDecaySteps] evenly spaced
/// samples sweeping the trailing `decayFraction` share of this band's own
/// height (from position `1 - decayFraction` up to `1`), each alpha `pow(t,
/// [_backdropBlurLayerDecayCurveStrength])` for `t` in `0..1` -- `0`
/// (transparent) where the sweep begins, `1` (opaque) at position `1`,
/// this band's own bottom/true edge.
Shader _buildBackdropBlurLayerDecayShader(Rect bounds, double decayFraction) {
  final double height = bounds.height > 0 ? bounds.height : _backdropBandHeight;
  final double decayHeight = height * decayFraction;
  final List<double> stops = <double>[0.0];
  final List<Color> colors = <Color>[const Color.fromRGBO(0, 0, 0, 0)];
  for (int i = 0; i <= _backdropBlurLayerDecaySteps; i++) {
    final double t = i / _backdropBlurLayerDecaySteps;
    final double alpha = math
        .pow(t, _backdropBlurLayerDecayCurveStrength)
        .toDouble();
    final double positionPx = height - decayHeight + t * decayHeight;
    stops.add((positionPx / height).clamp(0.0, 1.0));
    colors.add(Color.fromRGBO(0, 0, 0, alpha));
  }
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
    stops: stops,
  ).createShader(bounds);
}

/// The private per-item button: press feedback, the selection plate, the
/// kira sheen, and the icon+label -- the same architectural split
/// [CruxSegmentedControl]'s own `_CruxSegmentButton` uses. Not exported
/// -- callers only ever see [CruxNavBar].
class _CruxNavTabButton<T> extends StatefulWidget {
  const _CruxNavTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.sheenTrigger,
    required this.sheenLtr,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  /// This item's own running kira trigger count -- identical role to
  /// [CruxSegmentedControl]'s own `_CruxSegmentButton.sheenTrigger`.
  final int sheenTrigger;

  /// This item's next kira sheen sweep direction -- identical role to
  /// [CruxSegmentedControl]'s own `_CruxSegmentButton.sheenLtr`.
  final bool sheenLtr;

  @override
  State<_CruxNavTabButton<T>> createState() => _CruxNavTabButtonState<T>();
}

class _CruxNavTabButtonState<T> extends State<_CruxNavTabButton<T>> {
  bool _pressed = false;

  // Same PressFeedbackController wiring CruxSegmentedControl's own
  // _CruxSegmentButtonState uses -- see press_feedback.dart's class doc
  // for the fast-tap bug this guards against.
  late final PressFeedbackController _pressFeedback = PressFeedbackController(
    onChanged: (bool value) => setState(() => _pressed = value),
  );

  // Same onTapDown/Up/Cancel wiring CruxSegmentedControl's own
  // _CruxSegmentButtonState uses: only _handleTapDown checks `enabled`,
  // since it is the only handler that *starts* a press.
  void _handleTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _pressFeedback.down();
    }
  }

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
    final CruxColors colors = theme.colors;
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Color contentColor = !widget.enabled
        ? colors.muted
        : (widget.selected ? colors.textPrimary : colors.textSecondary);

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      // No explicit `label` here for the same reason as
      // CruxSegmentedControl's own segment button: the child Text below
      // already supplies its own automatic semantics label, and nothing
      // between this Semantics node and that Text introduces a merge
      // boundary.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _minTapTarget,
          minHeight: _minTapTarget,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          child: CruxMotion.scale(
            value: _pressed ? CruxMotion.pressedScale : 1.0,
            // Forces the Stack below to actually size itself to the tab
            // cell's full loose height (always 56 -- _barHeight minus
            // _barInnerPadding on both edges, tight from the Row above,
            // loosened for this tab by the Row's own cross-axis handling),
            // rather than shrinking to fit its one non-positioned child (the
            // icon+label FittedBox, whose natural size is well under 56) --
            // see _plateInsetVertical's own doc for the full reasoning and
            // the CruxSegmentedControl precedent this mirrors. Both
            // dimensions of this SizedBox.expand() resolve against already-
            // bounded incoming constraints (the outer ConstrainedBox/Row
            // chain never hands this subtree an unbounded max in either
            // axis), so this never throws for an unbounded ancestor.
            child: SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: _plateInsetHorizontal,
                    top: _plateInsetVertical,
                    right: _plateInsetHorizontal,
                    bottom: _plateInsetVertical,
                    child: _buildPlate(theme, reduceMotion),
                  ),
                  Positioned(
                    left: _plateInsetHorizontal,
                    top: _plateInsetVertical,
                    right: _plateInsetHorizontal,
                    bottom: _plateInsetVertical,
                    child: _buildSheenMask(theme, reduceMotion),
                  ),
                  // A Padding(_tabHorizontalPadding) wraps the whole
                  // icon+label group's FittedBox -- purely breathing room
                  // inside this tab's own fixed _tabWidth cell (see
                  // [CruxNavBar]'s own "Compact width" doc): each tab's
                  // rendered width comes from the pill's own fixed,
                  // tab-count-driven width divided evenly by [Expanded]
                  // (see [_CruxNavBarState.build]'s own pillWidth
                  // formula), never from this padding or from this Stack's
                  // own content measurement the way an earlier
                  // [IntrinsicWidth]-based scheme once relied on. Without
                  // this padding a short label's icon/label group would sit
                  // pixel-for-pixel against its own tab's edges with no
                  // breathing room, even though the tab's own width stays
                  // fixed regardless.
                  //
                  // The FittedBox(fit: scaleDown) itself, inside that
                  // padding, wraps the whole icon+label group, not just the
                  // icon: the tab cell's real available height is fixed at
                  // 56 (see the SizedBox.expand() above), but a label's own
                  // line height scales with the caller's
                  // [MediaQuery.textScalerOf], while
                  // [_iconSize]/[_tabContentGap] do not. At a large enough
                  // text scale the unscaled sum would exceed the cell's
                  // available height and this [Column] would overflow --
                  // laying it out inside an unconstrained (scaleDown never
                  // enlarges, so this is a pure no-op at every text scale
                  // this package's own goldens exercise today) [FittedBox]
                  // instead means the [Column] always measures at its true
                  // intrinsic size with no overflow error possible, and
                  // only visibly shrinks (uniformly, never distorting
                  // proportions) once that intrinsic size stops fitting the
                  // cell.
                  //
                  // The [LayoutBuilder] wrapped around that [FittedBox] is
                  // there for one specific reason, discovered while
                  // verifying the 2026-08-07 fixed-[_tabWidth] change:
                  // [RenderFittedBox] always lays out its own child with a
                  // fully unbounded [BoxConstraints] (`const BoxConstraints()`
                  // -- see the Flutter framework's own
                  // `RenderFittedBox.performLayout`), regardless of how
                  // tight or loose the constraints handed to the
                  // [FittedBox] itself are, then scales the child's
                  // resulting (unbounded-measured) size down to fit at
                  // paint time. That means a [Text] with
                  // `overflow: TextOverflow.ellipsis` sitting anywhere
                  // inside this [FittedBox]'s subtree never actually
                  // receives a bounded width to ellipsize against -- it
                  // always measures its own full natural width first, and
                  // only the whole already-natural-sized group gets scaled
                  // down uniformly afterwards. Left alone, a label wider
                  // than this tab's own content width would visibly shrink
                  // (icon included) instead of ellipsizing, silently
                  // breaking the "labels wider than 78px ellipsize inside
                  // the tab" contract from [CruxNavBar]'s own "Compact
                  // width" doc. This [LayoutBuilder] captures this tab's
                  // true available content width (already net of this
                  // [Padding]'s own [_tabHorizontalPadding] on both edges,
                  // whatever it actually is under the current pill width --
                  // the unclamped 78px case included, but also any narrower
                  // value the [_barMarginX] clamp produces) and feeds it
                  // into the [ConstrainedBox] wrapped directly around the
                  // [Text] below. `RenderConstrainedBox` (the render object
                  // [ConstrainedBox] creates) computes its own child's
                  // constraints via `BoxConstraints.enforce`, which clamps
                  // its own declared bound *within* whatever constraints its
                  // parent hands it; since that parent constraint is
                  // [FittedBox]'s unbounded one, the finite bound this
                  // [LayoutBuilder] supplies survives untouched, giving the
                  // [Text] a real bounded width to ellipsize against even
                  // though it is a descendant of an unbounded-layout
                  // [FittedBox]. The icon's own [SizedBox] is unaffected --
                  // it already hard-bounds itself at [_iconSize] -- so this
                  // only changes how the label, specifically, degrades.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _tabHorizontalPadding,
                    ),
                    child: LayoutBuilder(
                      builder:
                          (
                            BuildContext context,
                            BoxConstraints cellConstraints,
                          ) {
                            final double maxLabelWidth = math.max(
                              0.0,
                              cellConstraints.maxWidth,
                            );
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  // A hard [_iconSize] bound around the icon
                                  // slot -- see that constant's own doc for
                                  // why the ambient [IconThemeData] hint
                                  // below is not sufficient on its own for
                                  // an arbitrary caller-supplied icon
                                  // [Widget].
                                  SizedBox(
                                    width: _iconSize,
                                    height: _iconSize,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: IconTheme.merge(
                                        data: IconThemeData(
                                          size: _iconSize,
                                          color: contentColor,
                                        ),
                                        child: DefaultTextStyle.merge(
                                          style: TextStyle(color: contentColor),
                                          child: widget.icon,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: _tabContentGap),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: maxLabelWidth,
                                    ),
                                    child: Text(
                                      widget.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.typography.label.copyWith(
                                        fontSize: _labelFontSize,
                                        color: contentColor,
                                        // Bold only while selected -- a
                                        // 2026-08-07 user decision on top of
                                        // the pre-existing color-only
                                        // distinction; see CruxNavBar's
                                        // own "Label weight" class doc for
                                        // the full reasoning (why w700, why
                                        // this differs from
                                        // CruxSegmentedControl, and why
                                        // the fixed _tabWidth keeps this
                                        // weight change from ever moving
                                        // the tab's own layout). `null`
                                        // here leaves
                                        // theme.typography.label's own base
                                        // weight (FontWeight.w600)
                                        // untouched for an unselected tab,
                                        // rather than redundantly
                                        // re-specifying it.
                                        fontWeight: widget.selected
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the selection plate -- identical spring/fade mechanics to
  /// [CruxSegmentedControl]'s own `_buildPlate` (see that method's doc
  /// for the full spring/fade reasoning this mirrors) and this file's own
  /// [_plateFadeInDuration]/[_plateFadeOutDuration]/[_plateAppearStartScale]
  /// constants, but painted with **no shadow** -- unlike
  /// [CruxSegmentedControl]'s own plate, which keeps [CruxShadows.xs].
  /// This is a 2026-08-06 confirmed decision: see [CruxNavBar]'s own
  /// "Color mapping" doc for the full reasoning (in short, [_plateColor]
  /// already gives this plate a real fill difference from the pill's own
  /// background in both themes, so a shadow on top added no further
  /// legibility).
  Widget _buildPlate(CruxThemeData theme, bool reduceMotion) {
    final Widget plateBox = DecoratedBox(
      decoration: ShapeDecoration(
        color: _plateColor(theme),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(CruxRadii.pill)),
        ),
      ),
    );

    if (reduceMotion) {
      return widget.selected ? plateBox : const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: widget.selected ? 1.0 : 0.0,
      duration: widget.selected ? _plateFadeInDuration : _plateFadeOutDuration,
      curve: Curves.easeOut,
      child: CruxMotion.animatedValue(
        value: widget.selected ? 1.0 : _plateAppearStartScale,
        playful: true,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: plateBox,
      ),
    );
  }

  /// Builds the kira sheen mask -- identical mechanics to
  /// [CruxSegmentedControl]'s own `_buildSheenMask` (see that method's doc
  /// for the full "always mounted, cheap no-op until triggered" reasoning),
  /// using this file's own sheen constants and [_sheenPeakColor].
  Widget _buildSheenMask(CruxThemeData theme, bool reduceMotion) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(CruxRadii.pill)),
      child: CruxMotion.playOnce(
        trigger: widget.sheenTrigger,
        duration: _sheenDuration,
        reduceMotion: reduceMotion,
        builder: (BuildContext context, double progress, Widget? child) {
          if (progress <= 0.0 || progress >= 1.0) {
            return const SizedBox.shrink();
          }
          return IgnorePointer(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double height = constraints.maxHeight;
                final double bandWidth = width * _sheenWidthFraction;
                final double travel = bandWidth * _sheenOvertravel;
                final double startX = widget.sheenLtr
                    ? -travel
                    : width + travel;
                final double endX = widget.sheenLtr ? width + travel : -travel;
                final double bandLeft = startX + (endX - startX) * progress;
                final double tiltDegrees = widget.sheenLtr
                    ? _sheenTiltDegrees
                    : -_sheenTiltDegrees;
                final Color edge = theme.shadows.ink.withValues(
                  alpha: _sheenEdgeAlpha,
                );
                final Color peak = _sheenPeakColor(theme);

                return Transform.translate(
                  offset: Offset(bandLeft, 0),
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.skewX(tiltDegrees * math.pi / 180),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _sheenBlurSigma,
                        sigmaY: _sheenBlurSigma,
                      ),
                      child: Container(
                        width: bandWidth,
                        height: height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              edge.withValues(alpha: 0),
                              edge,
                              peak.withValues(alpha: _sheenPeakAlpha),
                              edge,
                              edge.withValues(alpha: 0),
                            ],
                            stops: const <double>[0.0, 0.30, 0.50, 0.70, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The sheen's peak highlight color -- identical value and reasoning to
/// [CruxSegmentedControl]'s own private `_sheenPeakColor` (see that
/// function's doc for why [CruxColors.surface]/[CruxColors.textPrimary]
/// are reused rather than introducing a new raw color value). Duplicated
/// rather than imported for the same "no shared refactor this milestone"
/// reason every other plate/sheen constant above is.
Color _sheenPeakColor(CruxThemeData theme) {
  return theme.brightness == Brightness.light
      ? theme.colors.surface
      : theme.colors.textPrimary;
}

/// The selection plate's fill color, split by brightness -- the same "reuse
/// an existing [CruxColors] field per [Brightness] rather than introduce a
/// new raw color value" pattern this file's own [_sheenPeakColor] already
/// follows (see that function's doc for the precedent this mirrors).
///
/// This is a 2026-08-06 user request ("ライトテーマの時にピル（選択プレート）
/// をグレーにしたい"). Before this change, both themes filled the plate with
/// [CruxColors.controlPlate] -- but in the light palette that token is
/// defined identical to [CruxColors.surface] (see that token's own doc in
/// `colors.dart`), and this pill's own background is *also*
/// [CruxColors.surface] (see this class's own "Color mapping" doc). So on
/// a light bar, a selected item's plate was distinguished from the pill it
/// sits on only by [CruxShadows.xs]'s shadow -- never by a color
/// difference, unlike every other filled/selected surface this package
/// draws. Light now instead fills with [CruxColors.controlFill], the same
/// warm gray [CruxSegmentedControl] uses for its own track
/// (`segmented_control.dart`'s visible pill background): reusing that
/// existing token gives the plate a real, visible fill against the white
/// bar rather than relying on the shadow alone, with no new token added.
///
/// Dark keeps [CruxColors.controlPlate] rather than making the same swap:
/// [CruxColors.dark.controlFill] (`#262319`) sits close to dark's own
/// [CruxColors.surface] (`#211F18`, ~1.05:1 -- the exact measurement
/// [CruxColors.controlPlate]'s own doc in `colors.dart` cites), so filling
/// this pill's plate with [controlFill] there would leave it nearly
/// invisible against the [CruxColors.surface] pill background it sits on
/// -- reproducing, on this widget, precisely the "plate indistinguishable
/// from what it sits on" problem [CruxColors.controlPlate] was introduced
/// to solve in 0.8.0 (`CHANGELOG.md`'s 0.8.0 entry: added specifically
/// because plain [CruxColors.surface] measured only ~1.05:1 against
/// [CruxColors.dark.controlFill] for [CruxSegmentedControl]'s own
/// selected plate). Dark is therefore left unchanged by this request, which
/// only ever asked for the light plate to read as gray.
Color _plateColor(CruxThemeData theme) {
  return theme.brightness == Brightness.light
      ? theme.colors.controlFill
      : theme.colors.controlPlate;
}
