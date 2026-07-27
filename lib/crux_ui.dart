/// Crux UI — a playful Flutter UI kit.
///
/// This release ships the design token layer (colors, spacing, typography,
/// and radii, plus the [CruxTheme] / [CruxThemeData] pair that makes
/// them available to a widget subtree), eight widget atoms —
/// [CruxButton], [CruxChip], [CruxCard], [CruxListTile],
/// [CruxSwitch], [CruxDivider], [CruxTextFormField], and
/// [CruxInputBar] — and one molecule built from them, [CruxComposer].
///
/// This file is the single public entry point of the package: every
/// component that Crux UI ships in the future will be exported from here,
/// so consumers only ever need one import.
///
/// ```dart
/// import 'package:crux_ui/crux_ui.dart';
/// ```
library;

export 'src/components/atoms/button.dart';
export 'src/components/atoms/card.dart';
export 'src/components/atoms/chip.dart';
export 'src/tokens/colors.dart';
export 'src/components/molecules/composer.dart';
export 'src/components/atoms/divider.dart';
export 'src/components/atoms/input_bar.dart';
export 'src/components/atoms/list_tile.dart';
export 'src/tokens/motion.dart';
export 'src/tokens/radii.dart';
export 'src/tokens/spacing.dart';
export 'src/components/atoms/switch.dart';
export 'src/components/atoms/text_form_field.dart';
export 'src/tokens/theme.dart';
export 'src/tokens/typography.dart';
