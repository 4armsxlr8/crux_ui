import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The `CruxButton` entry in the catalog: Playground, States matrix, and
/// Edge cases use cases. See `usecases/CONVENTIONS.md` for the contract this
/// file follows.
WidgetbookComponent get buttonComponent => WidgetbookComponent(
  name: 'CruxButton',
  useCases: [
    WidgetbookUseCase(name: 'Playground', builder: _buildPlayground),
    WidgetbookUseCase(
      name: 'States matrix',
      builder: (context) => const ButtonStatesMatrix(),
    ),
    WidgetbookUseCase.child(
      name: 'Edge cases',
      child: const _ButtonEdgeCases(),
    ),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final String label = context.knobs.string(
    label: 'Label',
    initialValue: 'はじめる',
  );
  final CruxButtonVariant variant = context.knobs.object.segmented(
    label: 'Variant',
    options: CruxButtonVariant.values,
    initialOption: CruxButtonVariant.filled,
    labelBuilder: (CruxButtonVariant v) => v.name,
  );
  final CruxButtonSize size = context.knobs.object.segmented(
    label: 'Size',
    options: CruxButtonSize.values,
    initialOption: CruxButtonSize.medium,
    labelBuilder: (CruxButtonSize v) => v.name,
  );
  final bool enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );
  final bool loading = context.knobs.boolean(
    label: 'Loading',
    initialValue: false,
  );

  return Center(
    child: CruxButton(
      label: label,
      variant: variant,
      size: size,
      loading: loading,
      onPressed: enabled ? () {} : null,
    ),
  );
}

/// The states-matrix body for `CruxButton`: every [CruxButtonVariant]
/// crossed with enabled/disabled, crossed with every [CruxButtonSize], all
/// visible at once.
///
/// Deliberately theme-independent beyond `CruxTheme.of(context)`: it
/// builds no [CruxTheme] of its own, so the future golden test can pump it
/// directly under its own [CruxTheme] ancestor without going through
/// Widgetbook.
class ButtonStatesMatrix extends StatelessWidget {
  /// Creates the button states matrix.
  const ButtonStatesMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return ColoredBox(
      color: theme.colors.background,
      // Three variants stacked (each with an enabled and a disabled row)
      // add up to more height than a small preview pane offers, which used
      // to overflow with Flutter's yellow-and-black stripes instead of
      // just scrolling past the fold. SingleChildScrollView keeps every
      // variant reachable regardless of the surrounding viewport's height;
      // at the golden test's generous 900×4000 canvas the content already
      // fits, so this is a no-op there.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CruxSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final CruxButtonVariant variant in CruxButtonVariant.values)
              Padding(
                padding: const EdgeInsets.only(bottom: CruxSpacing.s24),
                child: _VariantSection(variant: variant),
              ),
          ],
        ),
      ),
    );
  }
}

class _VariantSection extends StatelessWidget {
  const _VariantSection({required this.variant});

  final CruxButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          variant.name,
          style: theme.typography.title.copyWith(
            color: theme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: CruxSpacing.s8),
        _StateRow(variant: variant, enabled: true),
        const SizedBox(height: CruxSpacing.s12),
        _StateRow(variant: variant, enabled: false),
        const SizedBox(height: CruxSpacing.s12),
        _LoadingRow(variant: variant),
      ],
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.variant, required this.enabled});

  final CruxButtonVariant variant;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    // This row lists every CruxButtonSize side by side, which used to
    // claim the full available width via the implicit
    // `mainAxisSize: MainAxisSize.max` default (so the row filled the
    // golden test's 900×4000 canvas exactly as before) and overflow with
    // Flutter's yellow-and-black stripes once that available width dropped
    // below what the three size columns need. LayoutBuilder measures the
    // width this row is actually given; ConstrainedBox's `minWidth`
    // reproduces the same full-width claim so nothing shifts when the
    // content already fits (as it does at golden width); the horizontal
    // SingleChildScrollView only starts scrolling once the content
    // genuinely needs more room than that, instead of overflowing.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    enabled ? 'enabled' : 'disabled',
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.muted,
                    ),
                  ),
                ),
                for (final CruxButtonSize size in CruxButtonSize.values)
                  Padding(
                    padding: const EdgeInsets.only(right: CruxSpacing.s12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CruxButton(
                          label: '${variant.name} ${size.name}',
                          variant: variant,
                          size: size,
                          onPressed: enabled ? () {} : null,
                        ),
                        const SizedBox(height: CruxSpacing.s4),
                        Text(
                          size.name,
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The loading state for [variant], on its own row below the
/// enabled/disabled × size grid.
///
/// `loading` only makes sense paired with a live `onPressed` (the "request
/// in flight" state a real caller would show), so there is exactly one cell
/// per variant rather than a size sweep. It used to be appended as a
/// trailing column inside the enabled [_StateRow]'s horizontal scroller,
/// which pushed it past the golden canvas's fixed 900px width — the row's
/// own horizontal `SingleChildScrollView` could reach it by scrolling, but
/// the golden capture only ever shows the canvas's unscrolled viewport, so
/// the loading cell never appeared in the image. Giving it its own row below
/// keeps every cell within the 900px width the golden test captures.
class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.variant});

  final CruxButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final CruxThemeData theme = CruxTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            'loading',
            style: theme.typography.caption.copyWith(color: theme.colors.muted),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CruxButton(
              label: '${variant.name} loading',
              variant: variant,
              loading: true,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// Fixed, knob-free layouts chosen to break `CruxButton`: an 80px-wide
/// container forcing its ellipsis truncation, across all three variants.
class _ButtonEdgeCases extends StatelessWidget {
  const _ButtonEdgeCases();

  static const String _longLabel = 'これはとても長いボタンのラベルテキストです';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CruxSpacing.s16),
      child: Wrap(
        spacing: CruxSpacing.s16,
        runSpacing: CruxSpacing.s16,
        children: [
          for (final CruxButtonVariant variant in CruxButtonVariant.values)
            SizedBox(
              width: 80,
              child: CruxButton(
                label: _longLabel,
                variant: variant,
                onPressed: () {},
              ),
            ),
          SizedBox(
            width: 80,
            child: CruxButton(
              label: _longLabel,
              variant: CruxButtonVariant.filled,
              size: CruxButtonSize.large,
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }
}
