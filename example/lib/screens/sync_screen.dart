import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

/// The simulated round-trip [SyncScreen]'s pseudo sync runs for -- this
/// sample has no backend to actually sync against (the same honest limit
/// `login_screen.dart`'s own doc comment documents for its submit), so this
/// stands in for however long a real sync would take.
const Duration _syncDuration = Duration(seconds: 3);

/// The synced items [_SyncedList] lists once a pseudo sync completes: a
/// title and a short description of what changed, real-data-flavored the
/// same way `task_list_screen.dart`'s own sample rows are.
const List<(String, String)> _syncedItems = <(String, String)>[
  ('写真ライブラリ', '128枚の新しい写真を同期しました'),
  ('連絡先', '42件を更新しました'),
  ('カレンダー', '9件の予定を追加しました'),
  ('メモ', '3件を同期しました'),
];

/// The [CruxDivider.indent] that aligns a divider's start with where each
/// synced item's title text starts: [CruxListTile]'s own default
/// horizontal padding ([CruxSpacing.s16]) plus its 44 logical pixel
/// `leading` frame width plus the [CruxSpacing.s12] gap between `leading`
/// and the title -- the same formula `task_list_screen.dart`'s own
/// `_demoListDividerIndent` documents (a fresh, file-local copy, not a
/// shared token, per this package's established convention).
const double _syncedListDividerIndent =
    CruxSpacing.s16 + 44 + CruxSpacing.s12;

/// Extra bottom padding appended under [_SyncedList] so its last row never
/// sits underneath [SyncScreen]'s floating re-sync button: that button's own
/// 56 logical pixel diameter ([CruxIconButtonSize.large]) plus
/// [CruxSpacing.s20] of breathing room above it.
const double _fabClearance = 56 + CruxSpacing.s20;

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a "sync status" screen reached from the home index's "同期" row, built
/// specifically to give [CruxSpinner] a screen of its own to be seen on --
/// every other screen in this gallery only shows it briefly, replacing a
/// button's label (`login_screen.dart`'s own `CruxButton.loading`).
///
/// A pseudo sync starts the moment this screen opens, and again every time
/// its "再同期" (re-sync) button is tapped: for [_syncDuration], the whole
/// body is a single centered, large [CruxSpinner] with a "同期中…"
/// caption ([_SyncingView]); once it resolves, the body swaps to a short
/// list of synced items plus a "最終同期: たった今" line ([_SyncedView]),
/// with the re-sync button overlaid as a floating action button (FAB) in
/// the bottom-right corner of the content -- a [CruxIconButton] with
/// `tone: primary` and `size: large`, this gallery's worked example of that
/// size/tone combination (see `icon_button.dart`'s own doc comment). This
/// sample has no backend to sync against -- the same honest limit
/// `login_screen.dart`'s own success view documents for its submit -- so
/// "syncing" only ever means waiting out [_syncDuration].
///
/// This screen is deliberately a "this is what it looks like in a real
/// screen" demo, not a token or atom-state catalog -- those full listings
/// live in `widgetbook/` instead. See root `CLAUDE.md`'s catalog operating
/// rule.
class SyncScreen extends StatefulWidget {
  /// Creates the sync-status sample screen.
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  /// Whether a pseudo sync is currently in flight. Starts `true`: this
  /// class's own doc comment promises a sync begins the moment the screen
  /// opens, so the very first frame already needs to show [_SyncingView]
  /// without waiting on an async gap first.
  bool _syncing = true;

  @override
  void initState() {
    super.initState();
    unawaited(_runSync());
  }

  /// Runs one pseudo sync: waits out [_syncDuration], then flips [_syncing]
  /// back to `false`. Callers are responsible for having already set
  /// [_syncing] to `true` before calling this -- either the field's own
  /// initial value, for the one call from [initState], or [_handleResync]'s
  /// own `setState` before it calls this again. This method only ever
  /// resolves the flag, never starts it, so [_handleResync] is the one place
  /// that needs to guard against starting a second sync while the first is
  /// still in flight.
  Future<void> _runSync() async {
    await Future<void>.delayed(_syncDuration);
    if (!mounted) {
      // The screen was popped/disposed while the simulated sync was in
      // flight -- bail out instead of calling setState on an unmounted
      // State (mirrors `login_screen.dart`'s own `_submit`).
      return;
    }
    setState(() => _syncing = false);
  }

  void _handleResync() {
    if (_syncing) {
      // Already mid-flight: the re-sync button that calls this is only
      // rendered in the completed, non-syncing view ([_SyncedView]), so this
      // branch should be unreachable in practice -- but it guards against a
      // stray re-entrant call the same belt-and-suspenders way
      // `login_screen.dart`'s own `_submit` guards its simulated submit
      // against firing twice while the first is still awaiting.
      return;
    }
    setState(() => _syncing = true);
    unawaited(_runSync());
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: '同期ステータス'),
            Expanded(
              child: _syncing
                  ? _SyncingView(colors: colors, type: type)
                  // Stack layers the scrollable synced-item content under a
                  // floating re-sync button pinned to the bottom-right
                  // corner of the content area, rather than scrolling away
                  // with it -- the usual FAB behavior (see this class's own
                  // doc comment).
                  : Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            CruxSpacing.s20,
                            CruxSpacing.s20,
                            CruxSpacing.s20,
                            CruxSpacing.s20 + _fabClearance,
                          ),
                          child: _SyncedView(colors: colors, type: type),
                        ),
                        Positioned(
                          right: CruxSpacing.s20,
                          bottom: CruxSpacing.s20,
                          child: CruxIconButton(
                            icon: const Icon(Icons.sync, size: 24),
                            label: '再同期',
                            // This is the one action this screen offers
                            // once a sync has completed --
                            // CruxIconButtonTone.primary paired with
                            // CruxIconButtonSize.large is this gallery's
                            // worked FAB example (see icon_button.dart's
                            // own doc comment).
                            tone: CruxIconButtonTone.primary,
                            size: CruxIconButtonSize.large,
                            onPressed: _handleResync,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The in-flight view [SyncScreen] shows for [_syncDuration] after it opens
/// or its re-sync button is tapped: a single centered, large [CruxSpinner]
/// with a "同期中…" caption, and nothing else -- no list, no button -- so
/// the spinner is the one thing on screen to look at, which is this
/// screen's whole reason to exist (see [SyncScreen]'s own doc comment).
class _SyncingView extends StatelessWidget {
  const _SyncingView({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A stand-alone spinner (not sitting inside another control the
          // way `CruxButton.loading`'s own spinner does) needs its own
          // accessible name -- see `CruxSpinner.semanticsLabel`'s own doc
          // comment for why that parameter defaults to `null` everywhere
          // else in this gallery.
          const CruxSpinner(
            size: CruxSpinnerSize.large,
            semanticsLabel: '同期中',
          ),
          const SizedBox(height: CruxSpacing.s16),
          Text('同期中…', style: type.body.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// The completed view [SyncScreen] shows once a pseudo sync resolves: a
/// "最終同期: たった今" line and the synced items ([_syncedItems]) below as
/// a [_SyncedList]. The re-sync button that starts the whole cycle over
/// isn't part of this widget -- [SyncScreen]'s own `build` overlays it as a
/// floating action button on top of this view instead (see [SyncScreen]'s
/// own doc comment).
class _SyncedView extends StatelessWidget {
  const _SyncedView({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '最終同期: たった今',
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: CruxSpacing.s20),
        Text('同期済みの項目', style: type.title.copyWith(color: colors.textPrimary)),
        const SizedBox(height: CruxSpacing.s12),
        _SyncedList(colors: colors, type: type),
      ],
    );
  }
}

/// The bordered, rounded list of [_syncedItems]: a plain [Container] (not
/// [CruxCard], whose own padding would double up with each row's) around
/// flush-to-edge [CruxListTile] rows -- the same rounded-container-plus
/// -flush-rows shape `task_list_screen.dart`'s own `_DemoList` section uses.
class _SyncedList extends StatelessWidget {
  const _SyncedList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: CruxSpacing.s8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.separator),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _syncedItems.length; i++) ...[
            CruxListTile(
              leading: Icon(
                Icons.check_circle,
                size: 20,
                color: colors.success,
              ),
              title: _syncedItems[i].$1,
              subtitle: _syncedItems[i].$2,
            ),
            if (i != _syncedItems.length - 1)
              const CruxDivider(indent: _syncedListDividerIndent),
          ],
        ],
      ),
    );
  }
}
