import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

/// Extra vertical space added on top of the safe-area top inset, so the
/// scrolling list's first row starts with a small, deliberate gap below the
/// status bar instead of butting right up against it.
///
/// This screen's [Scaffold.body] leaves its top edge unconsumed by
/// [SafeArea] (see [HouseholdLedgerScreen]'s own doc for why), so the
/// list's own top padding has to do the safe-area job itself:
/// [MediaQuery.paddingOf]'s `top` covers the status bar / notch, and this
/// constant on top of that is nothing more than a breathing-room gap --
/// this screen floats no chrome of its own over the list, so there is no
/// button clearance to account for.
const double _topBreathingRoom = CruxSpacing.s16;

/// One line item in the household ledger: an emoji shown in a small colored
/// circle, the spending category, the store/memo text, and the amount in
/// yen (a positive integer; this sample only ever shows expenses, never
/// income, so there is no sign to track).
class _LedgerEntry {
  const _LedgerEntry({
    required this.emoji,
    required this.category,
    required this.memo,
    required this.amount,
  });

  final String emoji;
  final String category;
  final String memo;
  final int amount;
}

/// One calendar day's worth of [_LedgerEntry] rows, shown under a shared
/// date heading.
class _LedgerDay {
  const _LedgerDay({required this.date, required this.entries});

  final String date;
  final List<_LedgerEntry> entries;
}

/// The categories offered by [_CategoryFilterRow], in display order. Kept
/// as a single source of truth so the filter chips and the sample data
/// below stay in sync.
const List<String> _ledgerCategories = <String>['食費', '交通', '日用品', '娯楽', '光熱費'];

/// Sample spending data, newest day first: enough days and rows that the
/// list is taller than one screen, so scrolling it actually exercises
/// [CruxTopFade]'s dissolve at the top edge rather than never reaching it.
const List<_LedgerDay> _ledgerDays = <_LedgerDay>[
  _LedgerDay(
    date: '8月5日（水）',
    entries: <_LedgerEntry>[
      _LedgerEntry(emoji: '🍙', category: '食費', memo: 'コンビニ弁当', amount: 580),
      _LedgerEntry(emoji: '☕', category: '食費', memo: '朝のコーヒー', amount: 420),
      _LedgerEntry(emoji: '🚃', category: '交通', memo: '定期区間外乗車', amount: 260),
    ],
  ),
  _LedgerDay(
    date: '8月4日（火）',
    entries: <_LedgerEntry>[
      _LedgerEntry(emoji: '🛒', category: '日用品', memo: 'ドラッグストア', amount: 1980),
      _LedgerEntry(emoji: '🎬', category: '娯楽', memo: '映画チケット', amount: 1800),
      _LedgerEntry(emoji: '🍜', category: '食費', memo: 'ラーメン店', amount: 950),
      _LedgerEntry(emoji: '⚡', category: '光熱費', memo: '電気料金', amount: 6400),
    ],
  ),
  _LedgerDay(
    date: '8月3日（月）',
    entries: <_LedgerEntry>[
      _LedgerEntry(emoji: '🚕', category: '交通', memo: '深夜タクシー', amount: 2200),
      _LedgerEntry(emoji: '🥗', category: '食費', memo: 'スーパー買い出し', amount: 3140),
    ],
  ),
  _LedgerDay(
    date: '8月2日（日）',
    entries: <_LedgerEntry>[
      _LedgerEntry(emoji: '📚', category: '娯楽', memo: '書店', amount: 1650),
      _LedgerEntry(
        emoji: '🧴',
        category: '日用品',
        memo: 'シャンプー詰め替え',
        amount: 890,
      ),
      _LedgerEntry(emoji: '🍱', category: '食費', memo: 'テイクアウト', amount: 720),
    ],
  ),
  _LedgerDay(
    date: '8月1日（土）',
    entries: <_LedgerEntry>[
      _LedgerEntry(emoji: '🎮', category: '娯楽', memo: 'ゲームソフト', amount: 5980),
      _LedgerEntry(emoji: '🚌', category: '交通', memo: 'バス回数券', amount: 1200),
      _LedgerEntry(emoji: '💧', category: '光熱費', memo: '水道料金', amount: 3200),
    ],
  ),
  _LedgerDay(
    date: '7月31日（金）',
    entries: <_LedgerEntry>[
      _LedgerEntry(emoji: '🍞', category: '食費', memo: 'パン屋', amount: 480),
      _LedgerEntry(
        emoji: '🧻',
        category: '日用品',
        memo: 'ティッシュ・洗剤',
        amount: 1340,
      ),
    ],
  ),
];

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

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a household-ledger-style expense list demonstrating [CruxTopFade],
/// reached from the home index's "家計簿" row.
///
/// This screen shows nothing but the fading list itself -- no title, no
/// back button, no search/add affordance -- matching the reference this
/// milestone follows, https://flutterpro.design/details/progressive-fade,
/// whose own screenshot floats no chrome over the list at all. An earlier
/// version of this screen paired [CruxTopFade] with a floating header
/// (a back button, a "家計簿" title, and 検索/追加 action buttons); that
/// header component was withdrawn after a 2026-08-05 real-device review
/// concluded the reference's chrome-free look was the better fit for this
/// screen -- see `unknowns/navigation-bars/ledger.md`'s dated entry for the
/// decision. Leaving out a back button is deliberate, not an omission:
/// this screen is only ever reached via `Navigator.push` from the home
/// index (`home_index_page.dart`'s "家計簿" row), so the platform's own
/// back affordance -- an edge swipe on iOS, the system back gesture/button
/// on Android -- already returns to the previous screen without this
/// screen needing to draw one of its own.
///
/// Unlike every other screen in this gallery, this one does not use the
/// shared `AppHeader`, and its [Scaffold.body] is wrapped in a [SafeArea]
/// with both `top: false` and `bottom: false` -- not a plain [SafeArea].
/// Both choices are deliberate: [CruxTopFade] needs content that
/// actually runs edge-to-edge under the status bar to have anything to
/// dissolve — consuming the top inset here would push the list's first row
/// below the status bar and leave [CruxTopFade]'s fade band dissolving
/// nothing but blank background. The list's own top padding does the
/// safe-area job for the top edge instead ([MediaQuery.paddingOf]'s `top`
/// plus a small [_topBreathingRoom] gap); `bottom` is left unconsumed for
/// the same "not this screen's job" reason ([CruxTopFade]'s own fade
/// band is a top-edge-only concern, so nothing here reads or reacts to the
/// bottom inset either). Left/right *are* consumed by this [SafeArea],
/// though: neither [CruxTopFade] nor this screen's own [ListView]
/// padding reads the device's left/right safe-area inset itself, so on a
/// device whose rounded corners or a landscape notch eat into the
/// left/right edges (for example a landscape iPhone), leaving those two
/// sides unconsumed would let the list's own horizontal padding sit partly
/// under that cutout. Consuming left/right here (while leaving top/bottom
/// alone) fixes that without touching `top_fade.dart` itself -- the same
/// "wrap in `SafeArea` with only the sides this screen doesn't already
/// handle disabled" pattern `tab_shell_screen.dart` uses for its own
/// bottom-only exception.
///
/// The body is a single, full-bleed [CruxTopFade] wrapping the scrolling
/// expense list -- no [Stack], since there is no floating chrome left to
/// layer in front of it. The list itself groups sample expenses by date
/// under a small heading, each day's rows inside a [CruxCard], built
/// from [CruxListTile] and [CruxDivider] — with a summary [CruxCard]
/// and a [CruxChip] category filter row above the grouped list, giving
/// [CruxChip]'s exclusive-selection use (as opposed to
/// `task_list_screen.dart`'s independent toggle chips) its own natural
/// home.
class HouseholdLedgerScreen extends StatefulWidget {
  /// Creates the household-ledger sample screen.
  const HouseholdLedgerScreen({super.key});

  @override
  State<HouseholdLedgerScreen> createState() => _HouseholdLedgerScreenState();
}

class _HouseholdLedgerScreenState extends State<HouseholdLedgerScreen> {
  /// The currently selected category filter, or `null` for "すべて" (every
  /// category). Purely local UI state, the same "no backend, this sample
  /// just demonstrates the interaction" honesty `settings_screen.dart`'s
  /// own state documents for itself.
  String? _categoryFilter;

  int _totalFor(String? category) {
    int total = 0;
    for (final _LedgerDay day in _ledgerDays) {
      for (final _LedgerEntry entry in day.entries) {
        if (category == null || entry.category == category) {
          total += entry.amount;
        }
      }
    }
    return total;
  }

  int _countFor(String? category) {
    int count = 0;
    for (final _LedgerDay day in _ledgerDays) {
      for (final _LedgerEntry entry in day.entries) {
        if (category == null || entry.category == category) {
          count++;
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final double topPadding =
        MediaQuery.paddingOf(context).top + _topBreathingRoom;

    return Scaffold(
      backgroundColor: colors.background,
      // `top`/`bottom: false`: see this class's own doc for why those two
      // edges are deliberately left for `CruxTopFade` (top) and this
      // screen's own unchanged padding (bottom) to handle, while left/right
      // -- read by neither of those -- fall through to this `SafeArea`'s
      // default handling instead.
      body: SafeArea(
        top: false,
        bottom: false,
        child: CruxTopFade(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CruxSpacing.s20,
              topPadding,
              CruxSpacing.s20,
              CruxSpacing.s32,
            ),
            children: [
              _SummaryCard(
                colors: colors,
                type: type,
                label: _categoryFilter ?? 'すべての支出',
                total: _totalFor(_categoryFilter),
                count: _countFor(_categoryFilter),
              ),
              const SizedBox(height: CruxSpacing.s20),
              _CategoryFilterRow(
                selected: _categoryFilter,
                onChanged: (String? value) =>
                    setState(() => _categoryFilter = value),
              ),
              const SizedBox(height: CruxSpacing.s24),
              for (final _LedgerDay day in _ledgerDays)
                _DaySection(
                  day: day,
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

/// The totals card sitting above the filter row and grouped list: shows
/// what [_HouseholdLedgerScreenState._categoryFilter] currently narrows the
/// list down to, so switching the filter chips has a visible effect even
/// before scrolling down to the rows themselves.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.colors,
    required this.type,
    required this.label,
    required this.total,
    required this.count,
  });

  final CruxColors colors;
  final CruxTypography type;
  final String label;
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: type.body.copyWith(color: colors.textSecondary)),
          const SizedBox(height: CruxSpacing.s8),
          Text(
            _formatYen(total),
            style: type.title.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CruxSpacing.s4),
          Text(
            '$count件の記録',
            style: type.caption.copyWith(color: colors.textSecondary),
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
/// a [CruxCard] containing that day's matching [_LedgerEntry] rows
/// ([_LedgerRow], separated by indented [CruxDivider]s). Renders nothing
/// at all when [categoryFilter] excludes every entry for [day], so
/// selecting a category collapses days with no matching spending instead of
/// showing an empty card.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.categoryFilter,
    required this.colors,
    required this.type,
  });

  final _LedgerDay day;
  final String? categoryFilter;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<_LedgerEntry> entries = <_LedgerEntry>[
      for (final _LedgerEntry entry in day.entries)
        if (categoryFilter == null || entry.category == categoryFilter) entry,
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
              day.date,
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
                  _LedgerRow(entry: entries[i], colors: colors, type: type),
                  if (i != entries.length - 1)
                    const CruxDivider(
                      indent: CruxSpacing.s16 + 44 + CruxSpacing.s12,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One expense line: [CruxListTile] with [_EntryIcon] as its leading
/// widget, the category as the title, the store/memo as the subtitle, and
/// the formatted amount as the trailing text.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.entry,
    required this.colors,
    required this.type,
  });

  final _LedgerEntry entry;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return CruxListTile(
      leading: _EntryIcon(emoji: entry.emoji, colors: colors),
      title: entry.category,
      subtitle: entry.memo,
      trailing: _formatYen(entry.amount),
    );
  }
}

/// The small emoji-in-a-circle leading widget for each [_LedgerRow], the
/// same shape `task_list_screen.dart`'s own `_DemoListIcon` uses for its
/// rows -- duplicated locally rather than shared because that class is
/// private to that file.
class _EntryIcon extends StatelessWidget {
  const _EntryIcon({required this.emoji, required this.colors});

  final String emoji;
  final CruxColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accentTint,
        shape: BoxShape.circle,
      ),
      child: Text(emoji),
    );
  }
}
