import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

/// The labels for [SettingsScreen]'s 文字サイズ slider's four discrete steps,
/// in order -- index `i` is the step [CruxSlider] reports as `value ==
/// i.toDouble()`. Four labeled steps (rather than a raw point-size number)
/// read as a real iOS/Android "text size" setting would, not a token scale.
const List<String> _fontSizeSteps = <String>['小', '標準', '大', '特大'];

/// [CruxSlider.divisions] for the 文字サイズ slider: one less than
/// [_fontSizeSteps]'s length, matching [CruxSlider.divisions]'s own
/// "`divisions + 1` positions from min to max inclusive" contract.
final int _fontSizeDivisions = _fontSizeSteps.length - 1;

/// The task sort orders [SettingsScreen]'s 並び順 segmented control offers.
enum _TaskSortOrder {
  /// Newest task added first.
  createdAt,

  /// Soonest due date first.
  dueDate,

  /// Highest priority first.
  priority,
}

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a "設定" (settings) screen reached from the home index's "設定" row,
/// built to give [CruxSlider] and [CruxSegmentedControl] a natural,
/// real-world home the same way `task_list_screen.dart` gives
/// [CruxCard]/[CruxChip]/[CruxListTile] one -- and, via its own
/// footer "設定をリセット" action, [CruxConfirmDialog] and
/// [showCruxToast] one too, the same natural "confirm a change, then
/// offer to undo it" shape `task_list_screen.dart`'s delete flow already
/// gives those two.
///
/// Two sliders (文字サイズ: a discrete slider using [CruxSlider.divisions];
/// 通知音量: a continuous one with no `divisions` at all, so both of
/// [CruxSlider]'s modes are represented) and one three-way
/// [CruxSegmentedControl] (並び順) sit inside ordinary labeled settings
/// rows, each control appearing exactly once doing the one job a settings
/// screen would actually ask it to do. There is deliberately no per-variant
/// state grid or token table here -- that catalog lives in `widgetbook/`
/// instead, per root `CLAUDE.md`'s catalog operating rule.
///
/// Below both sections sits a "設定をリセット" button: tapping it opens a
/// [CruxConfirmDialog.show] confirmation (a real settings screen never
/// resets state on a single tap) naming what will change; confirming
/// resets all three settings to their defaults and shows a
/// [showCruxToast] with a "元に戻す" [CruxToastAction] that restores
/// whatever values were in effect immediately before the reset. Resetting
/// twice in a row without changing anything in between shows the same
/// "設定をリセットしました" message twice, which is also this gallery's one
/// worked example of [CruxToastHost]'s duplicate-message shake (see its
/// own class doc) -- an incidental side effect of this button's wording
/// being reset-invariant, not something built for on purpose.
///
/// The 通知音量 row also carries a small "テスト" button (a
/// [CruxButtonVariant.ghost], [CruxButtonSize.small] [CruxButton] --
/// chosen over a filled/tonal or larger size so this secondary, purely
/// exploratory action reads as quieter than the row's own slider and value
/// text, and never competes with "設定をリセット" for emphasis). Unlike
/// "設定をリセット", tapping it shows a [showCruxToast] immediately, with no
/// [CruxConfirmDialog] in between -- there is nothing to confirm, since it
/// changes no setting. Its message always reports whatever 通知音量 currently
/// reads, so this one button doubles as a hands-on demo of two
/// [CruxToastHost] behaviors its own class doc describes: changing the
/// slider between taps shows a new message each time, stacking up to 3
/// distinct toasts, while tapping it twice in a row with no change in
/// between reshows the same message and plays [CruxToastHost]'s duplicate
/// -message shake instead of stacking a second card.
///
/// All three settings are local, unpersisted [State]: this sample has no
/// settings backend to read from or write to, the same honest limit
/// `sync_screen.dart`'s pseudo sync documents for itself. They also have no
/// effect on any other screen in this gallery (`task_list_screen.dart`'s
/// task list does not actually re-sort itself when 並び順 changes here) --
/// wiring cross-screen state is outside what a single component's use-case
/// screen needs to demonstrate.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings sample screen.
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

  /// The 並び順 segmented control's default selection. Both [_sortOrder]'s
  /// initial value and [_resetSettings] restore to this.
  static const _TaskSortOrder _defaultSortOrder = _TaskSortOrder.createdAt;

  /// The 文字サイズ slider's current step (an index into [_fontSizeSteps]).
  double _fontSizeStep = _defaultFontSizeStep;

  /// The 通知音量 slider's current value, `0`..`100`.
  double _notificationVolume = _defaultNotificationVolume;

  _TaskSortOrder _sortOrder = _defaultSortOrder;

  String _fontSizeLabel(double value) {
    final int step = value.round().clamp(0, _fontSizeSteps.length - 1);
    return _fontSizeSteps[step];
  }

  String _volumeLabel(double value) => '${value.round()}%';

  /// Opens the reset confirmation -- [_resetSettings] runs only if the
  /// dialog's "リセット" action is tapped; canceling leaves every value
  /// untouched. [CruxConfirmDialog.show] closes the dialog itself either
  /// way (see its own doc), so [_resetSettings] does not need to.
  void _confirmReset() {
    unawaited(
      CruxConfirmDialog.show(
        context,
        title: '設定をリセットしますか？',
        message: '文字サイズ・通知音量・並び順が初期値に戻ります。',
        cancelLabel: 'キャンセル',
        confirmLabel: 'リセット',
        onConfirm: _resetSettings,
      ),
    );
  }

  /// Shows an immediate, action-less [showCruxToast] reporting whatever
  /// [_notificationVolume] currently reads -- the 通知音量 row's "テスト"
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

  /// Resets all three settings to their defaults and shows a toast whose
  /// "元に戻す" action restores exactly the values captured here, from just
  /// before the reset -- not necessarily this screen's own defaults, in
  /// case a future setting starts non-default (mirrors
  /// `task_list_screen.dart`'s `_DemoListState._delete`, which likewise
  /// captures what it is about to change before changing it).
  void _resetSettings() {
    final double previousFontSizeStep = _fontSizeStep;
    final double previousNotificationVolume = _notificationVolume;
    final _TaskSortOrder previousSortOrder = _sortOrder;

    setState(() {
      _fontSizeStep = _defaultFontSizeStep;
      _notificationVolume = _defaultNotificationVolume;
      _sortOrder = _defaultSortOrder;
    });

    showCruxToast(
      context,
      message: '設定をリセットしました',
      action: CruxToastAction(
        label: '元に戻す',
        onPressed: () => setState(() {
          _fontSizeStep = previousFontSizeStep;
          _notificationVolume = previousNotificationVolume;
          _sortOrder = previousSortOrder;
        }),
      ),
    );
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
            const AppHeader(title: '設定'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(CruxSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        label: 'テスト',
                        variant: CruxButtonVariant.ghost,
                        size: CruxButtonSize.small,
                        onPressed: _testNotificationVolume,
                      ),
                    ),
                    const SizedBox(height: CruxSpacing.s32),
                    _SectionHeader(title: 'タスク一覧', colors: colors, type: type),
                    const SizedBox(height: CruxSpacing.s16),
                    Text(
                      '並び順',
                      style: type.body.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: CruxSpacing.s8),
                    CruxSegmentedControl<_TaskSortOrder>(
                      segments: const <CruxSegment<_TaskSortOrder>>[
                        CruxSegment<_TaskSortOrder>(
                          value: _TaskSortOrder.createdAt,
                          label: '追加順',
                        ),
                        CruxSegment<_TaskSortOrder>(
                          value: _TaskSortOrder.dueDate,
                          label: '期限順',
                        ),
                        CruxSegment<_TaskSortOrder>(
                          value: _TaskSortOrder.priority,
                          label: '優先度順',
                        ),
                      ],
                      selected: _sortOrder,
                      onChanged: (_TaskSortOrder value) =>
                          setState(() => _sortOrder = value),
                    ),
                    const SizedBox(height: CruxSpacing.s32),
                    _SectionHeader(title: 'その他', colors: colors, type: type),
                    const SizedBox(height: CruxSpacing.s16),
                    Align(
                      alignment: Alignment.center,
                      child: CruxButton(
                        label: '設定をリセット',
                        variant: CruxButtonVariant.tonal,
                        onPressed: _confirmReset,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section title inside [SettingsScreen]'s scrollable body (for example
/// "表示" or "タスク一覧") -- a grouping label, not a control.
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
