import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../data/mimosa_world.dart';
import '../state/app_state.dart';
import 'compose_screen.dart';

/// [CruxNavBar]'s own rendered height plus a breathing-room gap.
/// [MainShell] floats that bar as an overlay above this screen's content
/// rather than this screen laying it out itself, so this is a local
/// estimate (the bar exposes no public height constant), not a value read
/// from the bar itself.
const double _navBarClearance = 64 + CruxSpacing.s16;

/// [CruxIconButtonSize.large]'s own circle diameter, matching the きろく
/// button below.
const double _fabDiameter = 56;

/// Bottom padding for the scrollable content so its last row never sits
/// underneath the floating きろく button, which itself floats above
/// [_navBarClearance].
const double _scrollBottomClearance =
    _navBarClearance + _fabDiameter + CruxSpacing.s20;

/// Fixed white, since the delete-swipe background always sits on
/// [CruxColors.error]'s red regardless of theme (mirrors
/// `main_shell.dart`'s own `_navBadgeTextColor`).
const Color _deleteSwipeIconColor = Color(0xFFFFFFFF);

/// Which [MimosaTask]s the home tab's filter chips show.
enum _HomeTaskFilter {
  /// Every task.
  all,

  /// Only tasks with [MimosaTask.dueToday] set, regardless of completion.
  today,

  /// Only tasks with [MimosaTask.done] set.
  done,
}

extension _HomeTaskFilterLabel on _HomeTaskFilter {
  String get label => switch (this) {
    _HomeTaskFilter.all => 'すべて',
    _HomeTaskFilter.today => '今日',
    _HomeTaskFilter.done => '完了',
  };
}

/// The ホーム tab of [MainShell]: ミモザ's greeting, the [AppState.records]
/// list, a filter chip row, [AppState.sortedTasks] below that, and a
/// floating きろく button.
///
/// Task data comes entirely from [AppState]: checking a row calls
/// [AppState.toggleTaskDone], adding one through the bottom form calls
/// [AppState.addTask] (which also queues ミモザ's chat reaction and bumps
/// the unread badge -- both are [MainShell]'s and `ChatScreen`'s concern,
/// not this screen's), and [AppState.sortOrder] (set from the settings tab)
/// decides the list's order via [AppState.sortedTasks].
///
/// **Deleting a task.** Swiping a row end-to-start opens a
/// [CruxConfirmDialog]; confirming hides the row and shows a
/// [showCruxToast] with a "元に戻す" action. That hide is local to this
/// screen's own [State] (a set of hidden ids over [AppState.sortedTasks]),
/// not [AppState.deleteTask] -- [AppState] has no way to reinsert a task
/// with its original id, due label, and completion state, so hiding rather
/// than truly deleting is what lets "元に戻す" restore the exact row.
///
/// The floating きろく button pushes `ComposeScreen` as a full-screen modal
/// (`MaterialPageRoute(fullscreenDialog: true)`); what that screen does
/// with a submitted きろく is its own concern, not this screen's.
class TaskListScreen extends StatefulWidget {
  /// Creates the ホーム tab.
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  _HomeTaskFilter _filter = _HomeTaskFilter.all;

  /// [MimosaTask.id]s hidden by a confirmed swipe-delete -- see this
  /// widget's own class doc for why this is local, hide-only state rather
  /// than an [AppState.deleteTask] call.
  final Set<int> _hiddenTaskIds = <int>{};

  /// Ids in [_hiddenTaskIds] still awaiting restore by a "元に戻す" tap,
  /// keyed by the exact toast message they were hidden under.
  ///
  /// `CruxToastHost` (`lib/src/components/atoms/toast.dart`) treats two
  /// toasts with the same message as one card and keeps only the action
  /// from that message's first `showCruxToast` call -- so deleting two
  /// same-titled tasks in a row shares a single toast and a single "元に戻
  /// す" tap, and that tap must restore every id queued under that message,
  /// not just the id the first delete's closure captured.
  final Map<String, List<int>> _pendingRestoreIds = <String, List<int>>{};

  bool _matchesFilter(MimosaTask task) => switch (_filter) {
    _HomeTaskFilter.all => true,
    _HomeTaskFilter.today => task.dueToday,
    _HomeTaskFilter.done => task.done,
  };

  /// Opens the delete confirmation for [task], returning whether it was
  /// confirmed. Used both by [Dismissible.confirmDismiss] (the swipe path)
  /// and [_requestDelete] (the accessibility path) so the dialog's wording
  /// and behavior stay in exactly one place.
  Future<bool> _confirmDelete(MimosaTask task) async {
    bool confirmed = false;
    await CruxConfirmDialog.show(
      context,
      title: '「${task.title}」を削除しますか？',
      message: 'この操作はあとで「元に戻す」から取り消せます。',
      cancelLabel: 'キャンセル',
      confirmLabel: '削除',
      onConfirm: () => confirmed = true,
    );
    return confirmed;
  }

  /// Hides [task] and shows the undo toast. Called once a swipe-delete has
  /// actually been confirmed -- by [Dismissible.onDismissed] after its own
  /// dismiss animation finishes, or directly by [_requestDelete].
  void _handleDismissed(MimosaTask task) {
    final String message = '「${task.title}」を削除しました';
    setState(() => _hiddenTaskIds.add(task.id));
    _pendingRestoreIds.putIfAbsent(message, () => <int>[]).add(task.id);
    showCruxToast(
      context,
      message: message,
      action: CruxToastAction(
        label: '元に戻す',
        onPressed: () => _restorePending(message),
      ),
    );
  }

  /// Restores every id queued in [_pendingRestoreIds] under [message] --
  /// see that field's own doc for why a single "元に戻す" tap must restore
  /// more than one id. Guarded by [mounted]: `CruxToastHost` (main.dart)
  /// sits above the app's `Navigator`, so this can still fire after this
  /// screen itself has been popped and disposed, e.g. by a logout.
  void _restorePending(String message) {
    if (!mounted) {
      return;
    }
    final List<int>? ids = _pendingRestoreIds.remove(message);
    if (ids == null) {
      return;
    }
    setState(() => _hiddenTaskIds.removeAll(ids));
  }

  /// The accessibility fallback for deleting a row without a swipe gesture
  /// -- wired to [Semantics.onDismiss] below, so VoiceOver/TalkBack's own
  /// "dismiss" custom action reaches the same confirm-then-hide flow a
  /// swipe does.
  Future<void> _requestDelete(MimosaTask task) async {
    final bool confirmed = await _confirmDelete(task);
    if (!mounted) {
      return;
    }
    if (confirmed) {
      _handleDismissed(task);
    }
  }

  void _openComposeScreen() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext context) => const ComposeScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    final CruxColors colors = theme.colors;
    final CruxTypography type = theme.typography;
    final AppState appState = AppState.of(context);

    final List<MimosaTask> visibleTasks = <MimosaTask>[
      for (final MimosaTask task in appState.sortedTasks)
        if (!_hiddenTaskIds.contains(task.id) && _matchesFilter(task)) task,
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CruxSpacing.s20,
                CruxSpacing.s12,
                CruxSpacing.s20,
                _scrollBottomClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ホーム',
                    style: type.subheading.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: CruxSpacing.s16),
                  _GreetingCard(colors: colors, type: type),
                  const SizedBox(height: CruxSpacing.s20),
                  _RecordsSection(
                    records: appState.records,
                    colors: colors,
                    type: type,
                  ),
                  const SizedBox(height: CruxSpacing.s16),
                  _FilterChipRow(
                    selected: _filter,
                    onChanged: (_HomeTaskFilter filter) =>
                        setState(() => _filter = filter),
                  ),
                  const SizedBox(height: CruxSpacing.s16),
                  if (visibleTasks.isEmpty)
                    _EmptyTasksMessage(colors: colors, type: type)
                  else
                    for (final MimosaTask task in visibleTasks)
                      _buildTaskRow(task, colors, type, appState),
                  const SizedBox(height: CruxSpacing.s20),
                  _AddTaskForm(onAdd: appState.addTask),
                ],
              ),
            ),
            Positioned(
              right: CruxSpacing.s20,
              bottom: _navBarClearance,
              child: CruxIconButton(
                icon: const Icon(Icons.add, size: 26),
                label: mimosaComposeButtonLabel,
                tone: CruxIconButtonTone.primary,
                size: CruxIconButtonSize.large,
                onPressed: _openComposeScreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One swipeable task row: a [_TaskRow] wrapped in a [Dismissible] (see
  /// this class's own doc for the confirm/hide flow it drives) clipped to
  /// the row's own [CruxRadii.l] corner radius so [_DeleteSwipeBackground]
  /// never pokes past a rounded corner mid-swipe.
  Widget _buildTaskRow(
    MimosaTask task,
    CruxColors colors,
    CruxTypography type,
    AppState appState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CruxSpacing.s8),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(CruxRadii.l)),
        child: Dismissible(
          key: ValueKey<int>(task.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (DismissDirection _) => _confirmDelete(task),
          onDismissed: (DismissDirection _) => _handleDismissed(task),
          background: _DeleteSwipeBackground(colors: colors),
          child: Semantics(
            onDismiss: () => unawaited(_requestDelete(task)),
            child: _TaskRow(
              task: task,
              colors: colors,
              type: type,
              onToggle: (_) => appState.toggleTaskDone(task.id),
            ),
          ),
        ),
      ),
    );
  }
}

/// ミモザ's avatar and a static greeting line, atop the home tab.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(mimosaAvatarEmoji, style: TextStyle(fontSize: 28)),
          const SizedBox(width: CruxSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mimosaAppName,
                  style: type.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: CruxSpacing.s4),
                Text(
                  mimosaHomeGreeting,
                  style: type.body.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The [mimosaRecordsSectionTitle] label followed by every [AppState.records]
/// entry, each as its own compact card.
class _RecordsSection extends StatelessWidget {
  const _RecordsSection({
    required this.records,
    required this.colors,
    required this.type,
  });

  final List<MimosaRecord> records;
  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mimosaRecordsSectionTitle,
          style: type.caption.copyWith(
            color: colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: CruxSpacing.s8),
        for (final MimosaRecord record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: CruxSpacing.s8),
            child: CruxCard(
              padding: const EdgeInsets.symmetric(
                horizontal: CruxSpacing.s16,
                vertical: CruxSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    record.text,
                    style: type.body.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: CruxSpacing.s4),
                  Text(
                    record.timeLabel,
                    style: type.caption.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The すべて/今日/完了 filter row, [_HomeTaskFilter]'s three values shown
/// as mutually exclusive [CruxChip]s.
class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.selected, required this.onChanged});

  final _HomeTaskFilter selected;
  final ValueChanged<_HomeTaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CruxSpacing.s8,
      runSpacing: CruxSpacing.s8,
      children: [
        for (final _HomeTaskFilter filter in _HomeTaskFilter.values)
          CruxChip(
            label: filter.label,
            selected: filter == selected,
            onTap: () => onChanged(filter),
          ),
      ],
    );
  }
}

/// Shown instead of the task list when the current filter matches nothing.
class _EmptyTasksMessage extends StatelessWidget {
  const _EmptyTasksMessage({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CruxSpacing.s24),
      child: Center(
        child: Text(
          mimosaEmptyTasksMessage,
          style: type.body.copyWith(color: colors.muted),
        ),
      ),
    );
  }
}

/// One task row's static content: a [CruxCheckbox], the title
/// (strikethrough once [MimosaTask.done]), and [MimosaTask.dueLabel] --
/// [_TaskListScreenState._buildTaskRow] wraps this in the [Dismissible]
/// that gives it its swipe-to-delete behavior.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.colors,
    required this.type,
    required this.onToggle,
  });

  final MimosaTask task;
  final CruxColors colors;
  final CruxTypography type;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = type.body.copyWith(
      fontWeight: FontWeight.w600,
      color: task.done ? colors.textSecondary : colors.textPrimary,
      decoration: task.done ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: colors.textSecondary,
    );

    return CruxCard(
      padding: const EdgeInsets.symmetric(
        horizontal: CruxSpacing.s16,
        vertical: CruxSpacing.s12,
      ),
      // Merges the checkbox's checked/unchecked semantics with the title
      // and due label into one node, so a screen reader announces them
      // together rather than an unlabeled "checkbox" with no task name.
      child: MergeSemantics(
        child: Row(
          children: [
            CruxCheckbox(checked: task.done, onChanged: onToggle),
            const SizedBox(width: CruxSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: CruxSpacing.s2),
                  Text(
                    task.dueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: colors.muted),
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

/// The red delete affordance revealed behind a [_TaskRow] mid-swipe.
class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground({required this.colors});

  final CruxColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: CruxSpacing.s20),
      child: const Icon(
        Icons.delete_outline,
        color: _deleteSwipeIconColor,
        size: 22,
      ),
    );
  }
}

/// The bottom "add a task" form: a [Form] wrapping one
/// [CruxTextFormField] with a non-empty-title validator, calling [onAdd]
/// (bound to [AppState.addTask] by the caller) on a valid submit and
/// clearing the field afterward.
class _AddTaskForm extends StatefulWidget {
  const _AddTaskForm({required this.onAdd});

  /// Called with the trimmed title once a non-empty submit validates.
  final ValueChanged<String> onAdd;

  @override
  State<_AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<_AddTaskForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form != null && form.validate()) {
      form.save();
      widget.onAdd(_controller.text.trim());
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CruxTextFormField(
            label: '新しいタスク',
            placeholder: '牛乳を買う',
            controller: _controller,
            textInputAction: TextInputAction.done,
            validator: (String? value) =>
                (value == null || value.trim().isEmpty)
                ? 'タスク名を入力してください'
                : null,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: CruxSpacing.s12),
          Align(
            alignment: Alignment.centerRight,
            child: CruxButton(label: '追加', onPressed: _submit),
          ),
        ],
      ),
    );
  }
}
