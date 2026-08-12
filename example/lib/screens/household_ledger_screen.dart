import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';

/// Extra vertical space added on top of the safe-area top inset, so the
/// scrolling list's first row starts with a small, deliberate gap below the
/// status bar instead of butting right up against it.
///
/// This screen's [Scaffold.body] leaves its top edge unconsumed by
/// [SafeArea] (see [HouseholdLedgerScreen]'s own doc for why), so the
/// list's own top padding has to do the safe-area job itself:
/// [MediaQuery.paddingOf]'s `top` covers the status bar / notch, and this
/// constant on top of that is nothing more than a breathing-room gap.
const double _topBreathingRoom = CruxSpacing.s16;

/// Extra bottom padding, on top of the safe-area bottom inset, so the
/// list's last row clears the main shell's floating [CruxNavBar] pill
/// instead of disappearing under it. The pill's own rendered height is
/// private to the package, so this is a fixed generous clearance rather
/// than a value read from it.
const double _navBarClearance = 96;

/// One calendar day's worth of [MimosaExpense] rows, shown under a shared
/// date heading. Built by [_groupByDate], which assumes same-day entries
/// already sit consecutively in the source list (true of
/// [initialMimosaExpenses]) rather than re-sorting them.
class _LedgerDaySection {
  _LedgerDaySection(this.dateLabel);

  final String dateLabel;
  final List<MimosaExpense> entries = <MimosaExpense>[];
}

List<_LedgerDaySection> _groupByDate(List<MimosaExpense> expenses) {
  final List<_LedgerDaySection> sections = <_LedgerDaySection>[];
  for (final MimosaExpense expense in expenses) {
    if (sections.isEmpty || sections.last.dateLabel != expense.dateLabel) {
      sections.add(_LedgerDaySection(expense.dateLabel));
    }
    sections.last.entries.add(expense);
  }
  return sections;
}

/// Every category appearing in [expenses], in first-appearance order and
/// without duplicates -- the source for [_CategoryFilterRow]'s chips.
List<String> _uniqueCategories(List<MimosaExpense> expenses) {
  final List<String> categories = <String>[];
  for (final MimosaExpense expense in expenses) {
    if (!categories.contains(expense.category)) {
      categories.add(expense.category);
    }
  }
  return categories;
}

final List<_LedgerDaySection> _ledgerDaySections = _groupByDate(
  initialMimosaExpenses,
);
final List<String> _ledgerCategories = _uniqueCategories(initialMimosaExpenses);

/// The month's total spend across every entry in [initialMimosaExpenses],
/// unaffected by [_HouseholdLedgerScreenState._categoryFilter] -- the
/// filter narrows which rows the list shows, not what the monthly total
/// means.
int _sumAmounts(List<MimosaExpense> expenses) {
  int total = 0;
  for (final MimosaExpense expense in expenses) {
    total += expense.amount;
  }
  return total;
}

final int _ledgerMonthTotal = _sumAmounts(initialMimosaExpenses);

/// Formats [amount] as a yen amount with thousands separators, for example
/// `1200` becomes `¥1,200`. `example/` has no `intl` dependency (the
/// package itself has none either), so this is a small hand-rolled digit
/// grouping rather than pulling in a dependency for one call site.
String _formatYen(int amount) {
  final String digits = amount.toString();
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final int fromEnd = digits.length - i;
    if (i != 0 && fromEnd % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(digits[i]);
  }
  return '¥$grouped';
}

/// The 家計簿 (household ledger) tab: this month's spending, grouped by day,
/// with a category filter row above the list -- see
/// `unknowns/navigation-bars/ledger.md` for why it stays headerless.
///
/// This screen shows nothing but the fading list itself -- no title, no
/// back button, no search/add affordance. It is one of the main shell's
/// four permanent tabs, never pushed with `Navigator`, so there is no
/// previous screen for a back button to return to.
///
/// This tab draws no header chrome of its own -- its [Scaffold.body] is
/// wrapped in a [SafeArea] with both `top:
/// false` and `bottom: false` -- not a plain [SafeArea]. Both choices are
/// deliberate: [CruxTopFade] needs content that actually runs
/// edge-to-edge under the status bar to have anything to dissolve --
/// consuming the top inset here would push the list's first row below the
/// status bar and leave [CruxTopFade]'s fade band dissolving nothing but
/// blank background. The list's own top padding does the safe-area job for
/// the top edge instead ([MediaQuery.paddingOf]'s `top` plus a small
/// [_topBreathingRoom] gap); `bottom` is left unconsumed for the same "not
/// this screen's job" reason -- the list's own bottom padding accounts for
/// both the safe-area inset and [_navBarClearance] instead. Left/right
/// *are* consumed by this [SafeArea]: neither [CruxTopFade] nor this
/// screen's own [ListView] padding reads the device's left/right
/// safe-area inset itself, so on a device whose rounded corners or a
/// landscape notch eat into the left/right edges (for example a landscape
/// iPhone), leaving those two sides unconsumed would let the list's own
/// horizontal padding sit partly under that cutout.
///
/// The body is a single, full-bleed [CruxTopFade] wrapping the scrolling
/// expense list -- no [Stack], since there is no floating chrome left to
/// layer in front of it. The list groups [initialMimosaExpenses] by date
/// under a small heading, each day's rows inside a [CruxCard] built from
/// [CruxListTile] and [CruxDivider], with a monthly-total [CruxCard]
/// and a [CruxChip] category filter row above the grouped list.
class HouseholdLedgerScreen extends StatefulWidget {
  /// Creates the household-ledger tab.
  const HouseholdLedgerScreen({super.key});

  @override
  State<HouseholdLedgerScreen> createState() => _HouseholdLedgerScreenState();
}

class _HouseholdLedgerScreenState extends State<HouseholdLedgerScreen> {
  /// The currently selected category filter, or `null` for "すべて" (every
  /// category). Purely local UI state -- this tab has no add/edit affordance
  /// of its own, so nothing else in the app needs to observe it.
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final EdgeInsets safeArea = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      // `top`/`bottom: false`: see this class's own doc for why those two
      // edges are deliberately left for `CruxTopFade` (top) and this
      // screen's own padding (bottom) to handle, while left/right -- read
      // by neither of those -- fall through to this `SafeArea`'s default
      // handling instead.
      body: SafeArea(
        top: false,
        bottom: false,
        child: CruxTopFade(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CruxSpacing.s20,
              safeArea.top + _topBreathingRoom,
              CruxSpacing.s20,
              safeArea.bottom + _navBarClearance,
            ),
            children: [
              _SummaryCard(colors: colors, type: type),
              const SizedBox(height: CruxSpacing.s20),
              _CategoryFilterRow(
                selected: _categoryFilter,
                onChanged: (String? value) =>
                    setState(() => _categoryFilter = value),
              ),
              const SizedBox(height: CruxSpacing.s24),
              for (final _LedgerDaySection section in _ledgerDaySections)
                _DaySection(
                  section: section,
                  categoryFilter: _categoryFilter,
                  colors: colors,
                  type: type,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The totals card sitting above the filter row and grouped list: the
/// month's fixed total plus ミモザ's small aside, unaffected by which
/// category chip is selected below it.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mimosaLedgerMonthLabel,
            style: type.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: CruxSpacing.s2),
          Text(
            _formatYen(_ledgerMonthTotal),
            style: type.heading.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: CruxSpacing.s4),
          Text(
            mimosaLedgerNote,
            style: type.caption.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// A row of [CruxChip]s picking [selected] exclusively (an "すべて" chip
/// plus one per [_ledgerCategories] entry) -- unlike
/// `task_list_screen.dart`'s independent toggle chips, at most one of these
/// is ever selected at a time, which [onChanged] enforces by always
/// reporting the newly tapped chip's category (or `null` for "すべて")
/// rather than flipping a single chip's own boolean.
class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CruxSpacing.s8,
      runSpacing: CruxSpacing.s8,
      children: [
        CruxChip(
          label: 'すべて',
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final String category in _ledgerCategories)
          CruxChip(
            label: category,
            selected: selected == category,
            onTap: () => onChanged(category),
          ),
      ],
    );
  }
}

/// One date-grouped section of the ledger: a small date heading followed by
/// a [CruxCard] containing that day's matching [MimosaExpense] rows
/// ([_LedgerRow], separated by indented [CruxDivider]s). Renders nothing
/// at all when [categoryFilter] excludes every entry in [section], so
/// selecting a category collapses days with no matching spending instead of
/// showing an empty card.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.section,
    required this.categoryFilter,
    required this.colors,
    required this.type,
  });

  final _LedgerDaySection section;
  final String? categoryFilter;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<MimosaExpense> entries = <MimosaExpense>[
      for (final MimosaExpense expense in section.entries)
        if (categoryFilter == null || expense.category == categoryFilter)
          expense,
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: CruxSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: CruxSpacing.s8),
            child: Text(
              section.dateLabel,
              style: type.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CruxCard(
            padding: const EdgeInsets.symmetric(vertical: CruxSpacing.s4),
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  _LedgerRow(expense: entries[i]),
                  if (i != entries.length - 1)
                    const CruxDivider(indent: CruxSpacing.s16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One expense line: [CruxListTile] with the store as the title, the
/// category as the subtitle, and the formatted amount as the trailing text.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.expense});

  final MimosaExpense expense;

  @override
  Widget build(BuildContext context) {
    return CruxListTile(
      title: expense.store,
      subtitle: expense.category,
      trailing: _formatYen(expense.amount),
    );
  }
}
