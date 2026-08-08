/// The world content for this sample app: an AI companion, "ミモザ" 🦊,
/// that helps its one user keep their daily life in order.
///
/// Every piece of copy, seed record, and reply template the app shows lives
/// in this one file, so re-theming the sample to a different premise is a
/// diff to this file alone -- no screen or state file hardcodes its own
/// flavor text or starting data.
library;

/// The app's display name, shown on the login screen.
const String mimosaAppName = 'ミモザ';

/// The emoji used as ミモザ's avatar/logo throughout the app.
const String mimosaAvatarEmoji = '🦊';

/// The login screen's tagline, shown under [mimosaAppName].
const String mimosaLoginCatchphrase = 'ミモザと、きょうを整える。';

/// The login screen's footnote, shown below the sign-in form.
const String mimosaLoginFootnote = 'ミモザが毎日の暮らしをそっと整えます';

/// The demo value the login screen's email field starts pre-filled with, so
/// launching the app and tapping ログイン alone reaches [MainShell] with no
/// typing required.
const String mimosaDemoEmail = 'crux@example.com';

/// The demo value the login screen's password field starts pre-filled with.
/// Meets [LoginScreen]'s own minimum-length check.
const String mimosaDemoPassword = 'crux1234';

/// ミモザ's greeting on the home tab.
const String mimosaHomeGreeting = 'おかえり!来週火曜、歯医者さんの予約があるよ。忘れないでね';

/// ミモザ's aside note on the household ledger tab.
const String mimosaLedgerNote = '🦊 今月はカフェ多めかも?';

/// The [MimosaTask.dueLabel] a newly added task starts with -- it has no
/// due date until the user (or a later screen) sets one.
const String mimosaUnscheduledDueLabel = '期限未設定';

/// The [MimosaTask.dueSort] a newly added task starts with -- sorts after
/// every seeded task's real due date under [TaskSortOrder.dueDate].
const int mimosaUnscheduledDueSort = 99;

/// ミモザ's reply when a task is added, naming the task back.
String mimosaTaskAddedReply(String taskTitle) =>
    '「$taskTitle」をリストに入れたよ!応援してるね💪';

/// ミモザ's reply when a きろく (record) is posted.
const String mimosaRecordAddedReply = 'きょうのきろく、読んだよ。教えてくれてありがとう🦊';

/// The section label above the ホーム tab's きろく list.
const String mimosaRecordsSectionTitle = 'きょうのきろく';

/// Shown in place of the ホーム tab's task list when the current filter
/// matches no tasks.
const String mimosaEmptyTasksMessage = 'タスクはまだないよ';

/// The accessible label for the ホーム tab's floating きろく-posting button.
const String mimosaComposeButtonLabel = 'きろくを書く';

/// The きろく posting modal's header title.
const String mimosaRecordModalTitle = 'きろく';

/// The きろく posting modal's composer placeholder text.
const String mimosaRecordPlaceholder = '今日のできごとをミモザに教えてね';

/// The きろく posting modal's submit button label.
const String mimosaRecordSubmitLabel = '投稿する';

/// The confirmation toast shown after a きろく is posted.
const String mimosaRecordToastMessage = 'きろくを残したよ';

/// The household ledger tab's month label, shown above the monthly total.
/// Matches the month [initialMimosaExpenses]'s dates fall in -- update
/// alongside that data if it ever moves to a different month.
const String mimosaLedgerMonthLabel = '8月の支出';

/// The ログアウト confirmation dialog's body text.
const String mimosaLogoutConfirmMessage = 'もう一度ログインが必要になります。';

/// ミモザ's canned replies to a typed chat message, cycled in order by
/// whichever screen sends user messages.
const List<String> mimosaCannedReplies = <String>[
  'なるほど、教えてくれてありがとう🦊',
  'それは大事だね、覚えておくよ',
  'うんうん、聞いてるよ。無理しないでね',
  'いいね!応援してる💪',
  'そうなんだ、また詳しく聞かせて',
];

/// The task sort orders the settings tab's並び順 control offers.
enum TaskSortOrder {
  /// Soonest due date first, ties broken by [MimosaTask.createdOrder].
  dueDate,

  /// Oldest added first.
  createdOrder,

  /// Alphabetical by [MimosaTask.title].
  name,
}

/// [TaskSortOrder]'s Japanese display label, for the settings segmented
/// control.
extension TaskSortOrderLabel on TaskSortOrder {
  /// The label shown for this sort order in the settings tab.
  String get label => switch (this) {
    TaskSortOrder.dueDate => '期限順',
    TaskSortOrder.createdOrder => '追加順',
    TaskSortOrder.name => '名前順',
  };
}

/// One to-do item on the home tab.
///
/// Immutable: [AppState]'s mutators replace an entry with a
/// [copyWith]-derived one rather than mutating fields in place, so identity
/// comparisons on the containing list stay meaningful.
class MimosaTask {
  /// Creates a task.
  const MimosaTask({
    required this.id,
    required this.title,
    required this.dueLabel,
    required this.dueSort,
    required this.dueToday,
    required this.done,
    required this.createdOrder,
  });

  /// Stable identity, assigned once at creation.
  final int id;

  /// The task's title text.
  final String title;

  /// The human-readable due date/time shown under the title.
  final String dueLabel;

  /// Sort key for [TaskSortOrder.dueDate]: lower sorts sooner. Today's
  /// tasks share the lowest value; [mimosaUnscheduledDueSort] sorts last.
  final int dueSort;

  /// Whether this task is due today.
  final bool dueToday;

  /// Whether this task has been checked off.
  final bool done;

  /// Insertion order, `1` for the first seeded task and incrementing from
  /// there -- the sort key for [TaskSortOrder.createdOrder] and the
  /// tiebreaker for [TaskSortOrder.dueDate].
  final int createdOrder;

  /// Returns a copy with [done] replaced, all other fields unchanged.
  MimosaTask copyWith({bool? done}) => MimosaTask(
    id: id,
    title: title,
    dueLabel: dueLabel,
    dueSort: dueSort,
    dueToday: dueToday,
    done: done ?? this.done,
    createdOrder: createdOrder,
  );
}

/// One きろく (record) entry on the home tab: a short freeform note the
/// user posts about their day.
class MimosaRecord {
  /// Creates a record.
  const MimosaRecord({
    required this.id,
    required this.text,
    required this.timeLabel,
  });

  /// Stable identity, assigned once at creation.
  final int id;

  /// The record's freeform text.
  final String text;

  /// The human-readable time label shown under the text (for example
  /// `'8/7 21:40'` or `'たった今'` for one just posted).
  final String timeLabel;
}

/// Who sent a [MimosaChatMessage].
enum MimosaChatSender {
  /// The app's one human user.
  user,

  /// ミモザ, the AI companion.
  mimosa,
}

/// One message in the ミモザ chat log.
class MimosaChatMessage {
  /// Creates a chat message.
  const MimosaChatMessage({
    required this.sender,
    required this.text,
    required this.timeLabel,
  });

  /// Who sent this message.
  final MimosaChatSender sender;

  /// The message text.
  final String text;

  /// The human-readable time label shown under the bubble (for example
  /// `'10:02'`).
  final String timeLabel;
}

/// One spending entry on the household ledger tab.
class MimosaExpense {
  /// Creates an expense entry.
  const MimosaExpense({
    required this.dateLabel,
    required this.store,
    required this.category,
    required this.amount,
  });

  /// The human-readable date label rows are grouped under (for example
  /// `'8/8(土)'`).
  final String dateLabel;

  /// The store or payee name.
  final String store;

  /// The spending category (for example `'カフェ'`, `'食費'`).
  final String category;

  /// The amount in yen.
  final int amount;
}

/// The task list a fresh app session starts with, oldest-added first.
const List<MimosaTask> initialMimosaTasks = <MimosaTask>[
  MimosaTask(
    id: 1,
    title: '歯医者の予約確認',
    dueLabel: '来週火曜 14:00',
    dueSort: 9,
    dueToday: false,
    done: false,
    createdOrder: 1,
  ),
  MimosaTask(
    id: 2,
    title: '牛乳とパンを買う',
    dueLabel: '今日中',
    dueSort: 0,
    dueToday: true,
    done: false,
    createdOrder: 2,
  ),
  MimosaTask(
    id: 3,
    title: 'レポート提出',
    dueLabel: '8/10(月)まで',
    dueSort: 2,
    dueToday: false,
    done: false,
    createdOrder: 3,
  ),
  MimosaTask(
    id: 4,
    title: '洗濯物を取り込む',
    dueLabel: '今日中',
    dueSort: 0,
    dueToday: true,
    done: true,
    createdOrder: 4,
  ),
  MimosaTask(
    id: 5,
    title: '母に電話する',
    dueLabel: '今日中',
    dueSort: 0,
    dueToday: true,
    done: false,
    createdOrder: 5,
  ),
  MimosaTask(
    id: 6,
    title: '部屋の掃除',
    dueLabel: '週末までに',
    dueSort: 3,
    dueToday: false,
    done: false,
    createdOrder: 6,
  ),
  MimosaTask(
    id: 7,
    title: '図書館の本を返却',
    dueLabel: '8/12(水)まで',
    dueSort: 4,
    dueToday: false,
    done: false,
    createdOrder: 7,
  ),
  MimosaTask(
    id: 8,
    title: 'ヨガ教室の予約',
    dueLabel: '来週木曜',
    dueSort: 8,
    dueToday: false,
    done: true,
    createdOrder: 8,
  ),
];

/// The きろく list a fresh app session starts with, newest first.
const List<MimosaRecord> initialMimosaRecords = <MimosaRecord>[
  MimosaRecord(id: 1, text: '今日は涼しくて気持ちいい朝だった', timeLabel: '8/7 21:40'),
  MimosaRecord(id: 2, text: '新しいカフェを見つけた、また行きたい', timeLabel: '8/6 19:15'),
];

/// The ミモザ chat log a fresh app session starts with, oldest first.
const List<MimosaChatMessage> initialMimosaChatLog = <MimosaChatMessage>[
  MimosaChatMessage(
    sender: MimosaChatSender.mimosa,
    text: 'おはよう!来週火曜、歯医者さんの予約があるよ。忘れないでね',
    timeLabel: '10:02',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.user,
    text: '覚えてる、ありがとう!',
    timeLabel: '10:05',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.mimosa,
    text: 'えらい!当日は14時だから、13時半には家を出てね',
    timeLabel: '10:06',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.user,
    text: '了解。当日の朝にもリマインドしてくれる?',
    timeLabel: '10:10',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.mimosa,
    text: 'もちろん!前日の夜と当日の朝、両方声かけるね🦊',
    timeLabel: '10:11',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.user,
    text: 'たすかる〜、いつもありがとう',
    timeLabel: '10:12',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.mimosa,
    text: 'どういたしまして。無理しすぎないでね',
    timeLabel: '10:13',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.user,
    text: 'がんばりすぎない程度にがんばるよ',
    timeLabel: '10:20',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.mimosa,
    text: 'それでいい!今日もおつかれさま',
    timeLabel: '10:21',
  ),
  MimosaChatMessage(
    sender: MimosaChatSender.user,
    text: 'おやすみ、また明日',
    timeLabel: '22:40',
  ),
];

/// The household ledger's spending entries a fresh app session starts with,
/// newest date first.
const List<MimosaExpense> initialMimosaExpenses = <MimosaExpense>[
  MimosaExpense(
    dateLabel: '8/8(土)',
    store: 'スターバックス',
    category: 'カフェ',
    amount: 580,
  ),
  MimosaExpense(
    dateLabel: '8/8(土)',
    store: 'セブンイレブン',
    category: '食費',
    amount: 420,
  ),
  MimosaExpense(
    dateLabel: '8/7(金)',
    store: '成城石井',
    category: '食費',
    amount: 3240,
  ),
  MimosaExpense(
    dateLabel: '8/7(金)',
    store: '蔦屋書店',
    category: '書籍',
    amount: 1650,
  ),
  MimosaExpense(
    dateLabel: '8/6(木)',
    store: 'ローソン',
    category: '食費',
    amount: 350,
  ),
  MimosaExpense(
    dateLabel: '8/6(木)',
    store: 'ドトールコーヒー',
    category: 'カフェ',
    amount: 490,
  ),
  MimosaExpense(
    dateLabel: '8/5(水)',
    store: '東京メトロ',
    category: '交通',
    amount: 310,
  ),
  MimosaExpense(
    dateLabel: '8/5(水)',
    store: 'マツモトキヨシ',
    category: '日用品',
    amount: 1280,
  ),
  MimosaExpense(
    dateLabel: '8/4(火)',
    store: 'スターバックス',
    category: 'カフェ',
    amount: 620,
  ),
  MimosaExpense(dateLabel: '8/4(火)', store: '丸善', category: '書籍', amount: 2200),
  MimosaExpense(
    dateLabel: '8/3(月)',
    store: 'ユニクロ',
    category: '日用品',
    amount: 3990,
  ),
  MimosaExpense(
    dateLabel: '8/3(月)',
    store: 'タリーズコーヒー',
    category: 'カフェ',
    amount: 540,
  ),
  MimosaExpense(
    dateLabel: '8/2(日)',
    store: 'セブンイレブン',
    category: '食費',
    amount: 280,
  ),
  MimosaExpense(dateLabel: '8/2(日)', store: 'JR', category: '交通', amount: 420),
];
