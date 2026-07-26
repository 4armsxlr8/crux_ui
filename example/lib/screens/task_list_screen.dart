import 'package:flutter/material.dart';
import 'package:crux_ui/crux_ui.dart';

import '../widgets/app_header.dart';

/// One sample screen in this gallery (see `screens/home_index_page.dart`):
/// a small task-list screen composed only from Crux atoms
/// ([CruxCard], [CruxButton], [CruxChip], [CruxTextFormField],
/// [CruxListTile], [CruxDivider]) used together the way a consuming app
/// actually would, reached from the home index's "タスク一覧" row.
///
/// This screen is deliberately a "this is what it looks like in a real
/// screen" demo, not a token or atom-state catalog — those full listings
/// (color/type/spacing tables, per-variant × per-state grids, edge cases)
/// live in `widgetbook/` instead. See root `CLAUDE.md`'s catalog operating
/// rule.
class TaskListScreen extends StatelessWidget {
  /// Creates the task-list sample screen.
  const TaskListScreen({super.key});

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
            const AppHeader(title: 'タスク一覧'),
            Expanded(
              child: Container(
                width: double.infinity,
                color: colors.background,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(CruxSpacing.s20),
                  child: _TaskListBody(colors: colors, type: type),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The real-world sample body: a card, a chip row, an add-task form, and a
/// list, laid out together inside one rounded container.
class _TaskListBody extends StatelessWidget {
  const _TaskListBody({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Only vertical padding here: the list section (_DemoList) must sit
      // flush against this container's own left/right edges, so its
      // CruxListTile rows' own default horizontal padding is what
      // produces the visual inset — and so a pressed row's state-layer
      // highlight runs edge-to-edge of this rounded container, iOS
      // Settings-app style, instead of stopping short at some extra gutter.
      // _DemoCard and _DemoChipRow are not full-bleed, so each wraps itself
      // in its own horizontal Padding below to keep the same inset they had
      // before.
      padding: const EdgeInsets.symmetric(vertical: CruxSpacing.s16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CruxSpacing.s16),
            child: _DemoCard(colors: colors, type: type),
          ),
          const SizedBox(height: CruxSpacing.s24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: CruxSpacing.s16),
            child: _DemoChipRow(),
          ),
          const SizedBox(height: CruxSpacing.s24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: CruxSpacing.s16),
            child: _AddTaskForm(),
          ),
          const SizedBox(height: CruxSpacing.s24),
          _DemoList(colors: colors, type: type),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    return CruxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日のミモザ', style: type.title.copyWith(color: colors.textPrimary)),
          const SizedBox(height: CruxSpacing.s8),
          Text(
            'おすすめのタスクを3件見つけました。空いた時間に少しずつ進めましょう。',
            style: type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: CruxSpacing.s16),
          Align(
            alignment: Alignment.centerLeft,
            child: CruxButton(
              label: 'はじめる',
              variant: CruxButtonVariant.tonal,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of [CruxChip]s: two toggle their own [CruxChip.selected] state
/// on tap, and the third is a fixed disabled example (mirroring the
/// previous mock's "muted" chip).
class _DemoChipRow extends StatefulWidget {
  const _DemoChipRow();

  @override
  State<_DemoChipRow> createState() => _DemoChipRowState();
}

class _DemoChipRowState extends State<_DemoChipRow> {
  bool _recommendedSelected = true;
  bool _dueTodaySelected = false;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CruxSpacing.s8,
      runSpacing: CruxSpacing.s8,
      children: [
        CruxChip(
          label: 'おすすめ',
          selected: _recommendedSelected,
          onTap: () =>
              setState(() => _recommendedSelected = !_recommendedSelected),
        ),
        CruxChip(
          label: '今日中',
          selected: _dueTodaySelected,
          onTap: () => setState(() => _dueTodaySelected = !_dueTodaySelected),
        ),
        const CruxChip(label: '下書き', onTap: null),
      ],
    );
  }
}

/// A small "add a task" form: this is the sample's one natural typing
/// moment, and wraps [CruxTextFormField] in a [Form] so the field's
/// `validator` / [FormState.validate] integration is visible in a real
/// screen, not just in widgetbook's isolated states catalog. Submitting an
/// empty task name surfaces the field's own validation error instead of
/// doing anything; submitting a non-empty one clears the field, the same
/// round trip a real "quick add" box would do.
class _AddTaskForm extends StatefulWidget {
  const _AddTaskForm();

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
                (value == null || value.isEmpty) ? 'タスク名を入力してください' : null,
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

/// The [CruxDivider.indent] that aligns a divider's start with where each
/// row's title text starts: [CruxListTile]'s own default horizontal
/// padding ([CruxSpacing.s16]) + its 44 logical pixel `leading` frame +
/// the [CruxSpacing.s12] gap between `leading` and the title. The list
/// section is full-bleed (no horizontal padding of its own) and each row
/// supplies its own inset instead, so this indent must grow by that same
/// [CruxSpacing.s16] to keep lining up with the title.
const double _demoListDividerIndent =
    CruxSpacing.s16 + 44 + CruxSpacing.s12;

class _DemoList extends StatelessWidget {
  const _DemoList({required this.colors, required this.type});

  final CruxColors colors;
  final CruxTypography type;

  @override
  Widget build(BuildContext context) {
    final List<(String?, String, String?, String?)> rows =
        <(String?, String, String?, String?)>[
          ('📝', '買い物メモを作成', '週末の買い出し用', '10分前'),
          ('📅', '歯医者の予約確認', '来週火曜 14:00', '1時間前'),
          ('💬', '友達からのメッセージ', '週末どこ行く?', '昨日'),
          // Title-only row: no subtitle, showing the single-line variant.
          ('☕', 'コーヒー豆を注文', null, '3日前'),
          // Most compact form: title only, no leading/subtitle/trailing.
          (null, 'アーカイブをすべて見る', null, null),
        ];

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          CruxListTile(
            leading: rows[i].$1 == null
                ? null
                : _DemoListIcon(icon: rows[i].$1!, colors: colors),
            title: rows[i].$2,
            subtitle: rows[i].$3,
            trailing: rows[i].$4,
            onTap: () {},
          ),
          if (i != rows.length - 1)
            const CruxDivider(indent: _demoListDividerIndent),
        ],
      ],
    );
  }
}

/// The small emoji-in-a-circle leading widget for each [_DemoList] row.
class _DemoListIcon extends StatelessWidget {
  const _DemoListIcon({required this.icon, required this.colors});

  final String icon;
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
      child: Text(icon),
    );
  }
}
