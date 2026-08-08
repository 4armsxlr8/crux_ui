import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/mimosa_world.dart';

/// How long [AppState.sendUserMessage] waits before ミモザ's canned reply
/// arrives, simulating a real reply delay.
const Duration mimosaReplyDelay = Duration(milliseconds: 1000);

/// Ambient access to this app's shared, in-memory state -- the task list,
/// きろく records, the ミモザ chat log, and the task sort order -- plus the
/// mutation API that changes it.
///
/// Shaped like `ThemeModeScope`: the mutable data lives in
/// [AppStateScope]'s own [State], and a fresh [AppState] is rebuilt with
/// new field values on every mutation. Every list field is replaced
/// wholesale (never mutated in place) on each change, so
/// [updateShouldNotify]'s identity comparisons are meaningful. Every
/// mutator is a plain callback field rather than a method resolved through
/// [BuildContext] at call time, so a widget can capture `AppState.of
/// (context)` once in `build` and pass its callbacks down.
///
/// State is memory-only: it resets on every process launch and is never
/// written to disk.
class AppState extends InheritedWidget {
  /// Creates a state scope. Built internally by [AppStateScope] -- screens
  /// never construct this directly.
  const AppState({
    super.key,
    required this.tasks,
    required this.sortOrder,
    required this.records,
    required this.chatMessages,
    required this.chatUnreadCount,
    required this.addTask,
    required this.toggleTaskDone,
    required this.deleteTask,
    required this.setSortOrder,
    required this.addRecord,
    required this.sendUserMessage,
    required this.markChatRead,
    required super.child,
  });

  /// Every task, in insertion order. Use [sortedTasks] for the order the
  /// home tab actually displays.
  final List<MimosaTask> tasks;

  /// The sort order the settings tab's並び順 control currently has selected.
  final TaskSortOrder sortOrder;

  /// Every きろく record, newest first.
  final List<MimosaRecord> records;

  /// The full ミモザ chat log, oldest first.
  final List<MimosaChatMessage> chatMessages;

  /// How many ミモザ messages have arrived since the チャット tab was last
  /// viewed. The main shell shows this as that tab's badge and clears it
  /// via [markChatRead] once the tab is selected.
  final int chatUnreadCount;

  /// Adds a task titled [title] with no due date, appends a ミモザ chat
  /// reaction naming it, and increments [chatUnreadCount].
  final void Function(String title) addTask;

  /// Flips the `done` flag of the task whose [MimosaTask.id] is [id]. A no-op
  /// if no task has that id.
  final void Function(int id) toggleTaskDone;

  /// Removes the task whose [MimosaTask.id] is [id]. A no-op if no task has
  /// that id.
  final void Function(int id) deleteTask;

  /// Changes [sortOrder]; [sortedTasks] reflects it on the next read.
  final void Function(TaskSortOrder order) setSortOrder;

  /// Adds a きろく record with text [text], appends a light ミモザ chat
  /// reaction, and increments [chatUnreadCount].
  final void Function(String text) addRecord;

  /// Appends a user chat message with text [text], then -- after
  /// [mimosaReplyDelay] -- appends one of [mimosaCannedReplies] and
  /// increments [chatUnreadCount].
  final void Function(String text) sendUserMessage;

  /// Resets [chatUnreadCount] to zero. Call when the チャット tab becomes
  /// selected (or, for a message that arrives while it is already selected,
  /// whenever that screen wants the badge to stay clear).
  final VoidCallback markChatRead;

  /// [tasks] ordered by [sortOrder]: soonest due date first
  /// ([TaskSortOrder.dueDate], ties broken by [MimosaTask.createdOrder]),
  /// oldest added first ([TaskSortOrder.createdOrder]), or alphabetical by
  /// title ([TaskSortOrder.name]).
  List<MimosaTask> get sortedTasks {
    final List<MimosaTask> sorted = List<MimosaTask>.of(tasks);
    switch (sortOrder) {
      case TaskSortOrder.dueDate:
        sorted.sort(
          (MimosaTask a, MimosaTask b) => a.dueSort != b.dueSort
              ? a.dueSort.compareTo(b.dueSort)
              : a.createdOrder.compareTo(b.createdOrder),
        );
      case TaskSortOrder.createdOrder:
        sorted.sort(
          (MimosaTask a, MimosaTask b) =>
              a.createdOrder.compareTo(b.createdOrder),
        );
      case TaskSortOrder.name:
        sorted.sort((MimosaTask a, MimosaTask b) => a.title.compareTo(b.title));
    }
    return sorted;
  }

  /// Finds the nearest [AppState] above [context].
  static AppState of(BuildContext context) {
    final AppState? state = context
        .dependOnInheritedWidgetOfExactType<AppState>();
    assert(state != null, 'No AppState found in context');
    return state!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) {
    return tasks != oldWidget.tasks ||
        sortOrder != oldWidget.sortOrder ||
        records != oldWidget.records ||
        chatMessages != oldWidget.chatMessages ||
        chatUnreadCount != oldWidget.chatUnreadCount;
  }
}

/// Owns this app's shared in-memory state and exposes it to [child]'s
/// subtree via [AppState]. Wrap the app once, above [AppState]'s first
/// reader -- `main.dart` wraps the whole [MaterialApp] with this, below
/// `ThemeModeScope`.
class AppStateScope extends StatefulWidget {
  /// Wraps [child] with the shared app state.
  const AppStateScope({super.key, required this.child});

  /// The subtree given access to [AppState.of].
  final Widget child;

  @override
  State<AppStateScope> createState() => _AppStateScopeState();
}

class _AppStateScopeState extends State<AppStateScope> {
  List<MimosaTask> _tasks = List<MimosaTask>.of(initialMimosaTasks);
  List<MimosaRecord> _records = List<MimosaRecord>.of(initialMimosaRecords);
  List<MimosaChatMessage> _chatMessages = List<MimosaChatMessage>.of(
    initialMimosaChatLog,
  );
  TaskSortOrder _sortOrder = TaskSortOrder.dueDate;
  int _chatUnreadCount = 0;

  int _nextTaskId = initialMimosaTasks.length + 1;
  int _nextRecordId = initialMimosaRecords.length + 1;
  int _nextCreatedOrder = initialMimosaTasks.length + 1;
  int _cannedReplyIndex = 0;

  /// Every still-pending ミモザ reply timer from [_sendUserMessage],
  /// cancelled on [dispose] so none of them call [setState] after this
  /// [State] is gone.
  final List<Timer> _pendingReplyTimers = <Timer>[];

  @override
  void dispose() {
    for (final Timer timer in _pendingReplyTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _addTask(String title) {
    final MimosaTask task = MimosaTask(
      id: _nextTaskId++,
      title: title,
      dueLabel: mimosaUnscheduledDueLabel,
      dueSort: mimosaUnscheduledDueSort,
      dueToday: false,
      done: false,
      createdOrder: _nextCreatedOrder++,
    );
    setState(() {
      _tasks = <MimosaTask>[..._tasks, task];
      _pushMimosaMessage(mimosaTaskAddedReply(title));
    });
  }

  void _toggleTaskDone(int id) {
    setState(() {
      _tasks = <MimosaTask>[
        for (final MimosaTask task in _tasks)
          if (task.id == id) task.copyWith(done: !task.done) else task,
      ];
    });
  }

  void _deleteTask(int id) {
    setState(() {
      _tasks = _tasks.where((MimosaTask task) => task.id != id).toList();
    });
  }

  void _setSortOrder(TaskSortOrder order) {
    if (order == _sortOrder) {
      return;
    }
    setState(() => _sortOrder = order);
  }

  void _addRecord(String text) {
    final MimosaRecord record = MimosaRecord(
      id: _nextRecordId++,
      text: text,
      timeLabel: 'たった今',
    );
    setState(() {
      _records = <MimosaRecord>[record, ..._records];
      _pushMimosaMessage(mimosaRecordAddedReply);
    });
  }

  void _sendUserMessage(String text) {
    setState(() {
      _chatMessages = <MimosaChatMessage>[
        ..._chatMessages,
        MimosaChatMessage(
          sender: MimosaChatSender.user,
          text: text,
          timeLabel: _nowLabel(),
        ),
      ];
    });
    final String reply =
        mimosaCannedReplies[_cannedReplyIndex % mimosaCannedReplies.length];
    _cannedReplyIndex++;
    late final Timer timer;
    timer = Timer(mimosaReplyDelay, () {
      _pendingReplyTimers.remove(timer);
      if (!mounted) {
        return;
      }
      setState(() => _pushMimosaMessage(reply));
    });
    _pendingReplyTimers.add(timer);
  }

  /// Appends a ミモザ message and bumps the unread badge count. Must be
  /// called from inside a [setState] call -- it does not call [setState]
  /// itself, so a caller that also touches other fields in the same
  /// mutation (see [_addTask], [_addRecord]) triggers only one rebuild.
  void _pushMimosaMessage(String text) {
    _chatMessages = <MimosaChatMessage>[
      ..._chatMessages,
      MimosaChatMessage(
        sender: MimosaChatSender.mimosa,
        text: text,
        timeLabel: _nowLabel(),
      ),
    ];
    _chatUnreadCount++;
  }

  void _markChatRead() {
    if (_chatUnreadCount == 0) {
      return;
    }
    setState(() => _chatUnreadCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    return AppState(
      tasks: _tasks,
      sortOrder: _sortOrder,
      records: _records,
      chatMessages: _chatMessages,
      chatUnreadCount: _chatUnreadCount,
      addTask: _addTask,
      toggleTaskDone: _toggleTaskDone,
      deleteTask: _deleteTask,
      setSortOrder: _setSortOrder,
      addRecord: _addRecord,
      sendUserMessage: _sendUserMessage,
      markChatRead: _markChatRead,
      child: widget.child,
    );
  }
}

/// The current wall-clock time as an `h:mm` label, matching this app's
/// other chat timestamps (for example `'10:02'`).
String _nowLabel() {
  final DateTime now = DateTime.now();
  final String minute = now.minute.toString().padLeft(2, '0');
  return '${now.hour}:$minute';
}
