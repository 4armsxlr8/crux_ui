import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';
import '../state/app_state.dart';
import '../theme_mode_scope.dart';
import 'main_shell.dart';

/// The labels for [SettingsScreen]'s 文字サイズ slider's four discrete steps,
/// in order -- index `i` is the step [CruxSlider] reports as `value ==
/// i.toDouble()`. Four labeled steps (rather than a raw point-size number)
/// read as a real iOS/Android "text size" setting would, not a token scale.
const List<String> _fontSizeSteps = <String>['小', '標準', '大', '特大'];

/// [CruxSlider.divisions] for the 文字サイズ slider: one less than
/// [_fontSizeSteps]'s length, matching [CruxSlider.divisions]'s own
/// "`divisions + 1` positions from min to max inclusive" contract.
final int _fontSizeDivisions = _fontSizeSteps.length - 1;

/// How long the simulated "データを同期" action runs before it resolves.
/// This tab has no backend to actually sync against, so this stands in for
/// however long a real sync would take.
const Duration _syncDuration = Duration(milliseconds: 1500);

/// Extra bottom padding, on top of the safe-area bottom inset [SafeArea]
/// already consumes, so this scroll view's last row clears the main
/// shell's floating [CruxNavBar] pill instead of disappearing under it.
/// The pill's own rendered height is private to the package, so this is a
/// fixed generous clearance rather than a value read from it.
const double _navBarClearance = 96;

/// The 設定 tab: task sort order, display preferences, dark mode, a
/// simulated data sync, and logout.
///
/// 並び順 reads and writes [AppState.sortOrder] directly, so changing it here
/// re-sorts the ホーム tab's task list live. ダークモード reads and writes the
/// ambient [ThemeModeScope], so flipping it re-themes every tab at once.
/// 文字サイズ and 通知音量 remain local, unpersisted [State] with no effect
/// outside this screen -- this app has no settings backend for them to read
/// from or write to.
///
/// データを同期 has no backend either: tapping it shows a [CruxSpinner] for
/// [_syncDuration], then a [showCruxToast] and an updated "最終同期" time
/// below the row. That time is kept in this screen's own [State] rather
/// than [AppState], so it survives tab switches (the main shell never
/// disposes an inactive tab) without being shared app state.
///
/// ログアウト opens a [CruxConfirmDialog]; confirming calls
/// [logoutToLoginScreen], which returns to a fresh login screen.
class SettingsScreen extends StatefulWidget {
  /// Creates the 設定 tab.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The 文字サイズ slider's default step -- "標準", the size an app would
  /// actually ship as default. Both [_fontSizeStep]'s initial value and
  /// [_resetSettings] restore to this.
  static const double _defaultFontSizeStep = 1;

  /// The 通知音量 slider's default value: a reasonable non-zero default
  /// rather than either extreme. Both [_notificationVolume]'s initial value
  /// and [_resetSettings] restore to this.
  static const double _defaultNotificationVolume = 70;

  /// The 文字サイズ slider's current step (an index into [_fontSizeSteps]).
  double _fontSizeStep = _defaultFontSizeStep;

  /// The 通知音量 slider's current value, `0`..`100`.
  double _notificationVolume = _defaultNotificationVolume;

  /// Whether a simulated データを同期 run is currently in flight.
  bool _syncing = false;

  /// When データを同期 last completed, or `null` if it has never run this
  /// session.
  DateTime? _lastSyncedAt;

  String _fontSizeLabel(double value) {
    final int step = value.round().clamp(0, _fontSizeSteps.length - 1);
    return _fontSizeSteps[step];
  }

  String _volumeLabel(double value) => '${value.round()}%';

  /// The データを同期 row's subtitle: "最終同期: 未同期" before the first run
  /// this session, otherwise "最終同期: H:MM" using [_lastSyncedAt].
  String get _lastSyncLabel {
    final DateTime? syncedAt = _lastSyncedAt;
    if (syncedAt == null) {
      return '最終同期: 未同期';
    }
    final String minute = syncedAt.minute.toString().padLeft(2, '0');
    return '最終同期: ${syncedAt.hour}:$minute';
  }

  /// Opens the reset confirmation -- [_resetSettings] runs only if the
  /// dialog's "リセット" action is tapped; canceling leaves every value
  /// untouched. [CruxConfirmDialog.show] closes the dialog itself either
  /// way (see its own doc), so [_resetSettings] does not need to.
  void _confirmReset() {
    unawaited(
      CruxConfirmDialog.show(
        context,
        title: '設定をリセットしますか？',
        message: '文字サイズ・通知音量が初期値に戻ります。',
        cancelLabel: 'キャンセル',
        confirmLabel: 'リセット',
        onConfirm: _resetSettings,
      ),
    );
  }

  /// Shows an immediate, action-less [showCruxToast] reporting whatever
  /// [_notificationVolume] currently reads -- the 通知音量 row's "確認"
  /// button's handler. No [CruxConfirmDialog] first (unlike
  /// [_confirmReset]): this changes no setting, so there is nothing to
  /// confirm before showing it. Reads [_notificationVolume] directly (not a
  /// value captured earlier) so the message always reflects whatever the
  /// slider reads at the moment this is actually invoked.
  void _testNotificationVolume() {
    showCruxToast(
      context,
      message: '通知音量は${_volumeLabel(_notificationVolume)}です',
    );
  }

  /// Resets 文字サイズ and 通知音量 to their defaults and shows a toast whose
  /// "元に戻す" action restores exactly the values captured here, from just
  /// before the reset -- not necessarily this screen's own defaults, in
  /// case a future setting starts non-default. 並び順 is not part of this
  /// reset: it is shared [AppState], not a local display preference, so a
  /// "reset this screen" action has no business rewinding what the ホーム
  /// tab shows.
  void _resetSettings() {
    final double previousFontSizeStep = _fontSizeStep;
    final double previousNotificationVolume = _notificationVolume;

    setState(() {
      _fontSizeStep = _defaultFontSizeStep;
      _notificationVolume = _defaultNotificationVolume;
    });

    showCruxToast(
      context,
      message: '設定をリセットしました',
      action: CruxToastAction(
        label: '元に戻す',
        // Guards against CruxToastHost (main.dart) outliving this screen
        // -- for example a logout that pops SettingsScreen while this
        // action-bearing toast is still on screen -- and firing this after
        // dispose.
        onPressed: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _fontSizeStep = previousFontSizeStep;
            _notificationVolume = previousNotificationVolume;
          });
        },
      ),
    );
  }

  /// Starts a simulated sync unless one is already in flight -- the row
  /// that calls this is a [GestureDetector], not a [CruxButton], so
  /// nothing else disables re-entrant taps while [_syncing] is `true`.
  void _startSync() {
    if (_syncing) {
      return;
    }
    setState(() => _syncing = true);
    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    await Future<void>.delayed(_syncDuration);
    if (!mounted) {
      // Guards against a stray setState if this tab were ever torn down
      // mid-sync -- bail out instead of calling setState on an unmounted
      // State.
      return;
    }
    setState(() {
      _syncing = false;
      _lastSyncedAt = DateTime.now();
    });
    showCruxToast(context, message: '同期しました');
  }

  /// Opens the ログアウト confirmation; confirming calls
  /// [logoutToLoginScreen], which returns to a fresh login screen.
  void _confirmLogout() {
    unawaited(
      CruxConfirmDialog.show(
        context,
        title: 'ログアウトしますか？',
        message: mimosaLogoutConfirmMessage,
        cancelLabel: 'キャンセル',
        confirmLabel: 'ログアウト',
        onConfirm: () => unawaited(logoutToLoginScreen(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final AppState appState = AppState.of(context);
    final ThemeModeScope themeMode = ThemeModeScope.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CruxSpacing.s20,
            CruxSpacing.s20,
            CruxSpacing.s20,
            CruxSpacing.s20 + _navBarClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '設定',
                style: type.headline.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: CruxSpacing.s24),
              _SectionHeader(title: 'タスクの並び順', colors: colors, type: type),
              const SizedBox(height: CruxSpacing.s12),
              CruxSegmentedControl<TaskSortOrder>(
                segments: <CruxSegment<TaskSortOrder>>[
                  for (final TaskSortOrder order in TaskSortOrder.values)
                    CruxSegment<TaskSortOrder>(
                      value: order,
                      label: order.label,
                    ),
                ],
                selected: appState.sortOrder,
                onChanged: appState.setSortOrder,
              ),
              const SizedBox(height: CruxSpacing.s32),
              _SectionHeader(title: '表示', colors: colors, type: type),
              const SizedBox(height: CruxSpacing.s16),
              _SliderSettingRow(
                label: '文字サイズ',
                valueText: _fontSizeLabel(_fontSizeStep),
                colors: colors,
                type: type,
                slider: CruxSlider(
                  value: _fontSizeStep,
                  min: 0,
                  max: _fontSizeDivisions.toDouble(),
                  divisions: _fontSizeDivisions,
                  valueLabelBuilder: _fontSizeLabel,
                  onChanged: (double value) =>
                      setState(() => _fontSizeStep = value),
                ),
              ),
              const SizedBox(height: CruxSpacing.s24),
              _SliderSettingRow(
                label: '通知音量',
                valueText: _volumeLabel(_notificationVolume),
                colors: colors,
                type: type,
                slider: CruxSlider(
                  value: _notificationVolume,
                  min: 0,
                  max: 100,
                  valueLabelBuilder: _volumeLabel,
                  onChanged: (double value) =>
                      setState(() => _notificationVolume = value),
                ),
                trailing: CruxButton(
                  label: '確認',
                  variant: CruxButtonVariant.ghost,
                  size: CruxButtonSize.small,
                  onPressed: _testNotificationVolume,
                ),
              ),
              const SizedBox(height: CruxSpacing.s32),
              _SectionHeader(title: 'その他', colors: colors, type: type),
              const SizedBox(height: CruxSpacing.s16),
              // Merges "ダークモード" (an implicit Text label) with
              // CruxSwitch's own toggled/tap semantics into one node, so a
              // screen reader announces them together instead of a static
              // label followed by a separate, unlabeled switch. CruxSwitch
              // declares its own container: true Semantics boundary, which
              // an ancestor Semantics(label:) alone cannot cross -- only
              // MergeSemantics does.
              MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ダークモード',
                        style: type.body.copyWith(color: colors.textPrimary),
                      ),
                    ),
                    CruxSwitch(
                      value: themeMode.isDark,
                      onChanged: themeMode.onDarkChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CruxSpacing.s24),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _startSync,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'データを同期',
                            style: type.body.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: CruxSpacing.s4),
                          Text(
                            _lastSyncLabel,
                            style: type.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_syncing)
                      const CruxSpinner(
                        size: CruxSpinnerSize.small,
                        semanticsLabel: '同期中',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CruxSpacing.s32),
              Align(
                alignment: Alignment.center,
                child: CruxButton(
                  label: '設定をリセット',
                  variant: CruxButtonVariant.tonal,
                  onPressed: _confirmReset,
                ),
              ),
              const SizedBox(height: CruxSpacing.s32),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _confirmLogout,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  child: Text(
                    'ログアウト',
                    style: type.body.copyWith(color: colors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section title inside [SettingsScreen]'s scrollable body (for example
/// "表示" or "その他") -- a grouping label, not a control.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colors,
    required this.type,
  });

  final String title;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: type.title.copyWith(color: colors.textPrimary));
  }
}

/// One slider-based settings row: a label on the left, the slider's current
/// formatted value after it (so the setting's value is visible even while
/// the slider itself isn't being touched -- the same "show the current
/// value next to the control" shape a real iOS/Android settings list uses),
/// an optional [trailing] widget (for example a small action button) after
/// that on the same line, and [slider] beneath all three.
class _SliderSettingRow extends StatelessWidget {
  const _SliderSettingRow({
    required this.label,
    required this.valueText,
    required this.colors,
    required this.type,
    required this.slider,
    this.trailing,
  });

  final String label;
  final String valueText;
  final CruxColors colors;
  final CruxTypography type;
  final CruxSlider slider;

  /// An optional widget (for example a small action button) shown after
  /// [valueText], on the same line. [label] sits in an [Expanded] ahead of
  /// both [valueText] and [trailing], so it is [label] alone that yields
  /// (wrapping onto a second line, never overflowing) if the row's width
  /// runs short -- [valueText] and [trailing] always keep their own natural,
  /// unshrunk size. Left `null` (the default) for a row with no trailing
  /// widget at all.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget? trailingWidget = trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: type.body.copyWith(color: colors.textPrimary),
              ),
            ),
            Text(
              valueText,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: CruxSpacing.s8),
              trailingWidget,
            ],
          ],
        ),
        const SizedBox(height: CruxSpacing.s8),
        slider,
      ],
    );
  }
}
