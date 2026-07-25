/// Crux UI — a playful Flutter UI kit.
///
/// This release ships the design token layer (colors, spacing, typography,
/// and radii, plus the [CruxTheme] / [CruxThemeData] pair that makes
/// them available to a widget subtree) and six widget atoms: [CruxButton],
/// [CruxChip], [CruxCard], [CruxListTile], [CruxSwitch], and
/// [CruxDivider].
///
/// This file is the single public entry point of the package: every
/// component that Crux UI ships in the future will be exported from here,
/// so consumers only ever need one import.
///
/// ```dart
/// import 'package:crux_ui/crux_ui.dart';
/// ```
library;

export 'src/button.dart';
export 'src/card.dart';
export 'src/chip.dart';
export 'src/colors.dart';
export 'src/divider.dart';
export 'src/list_tile.dart';
export 'src/motion.dart';
export 'src/radii.dart';
export 'src/spacing.dart';
export 'src/switch.dart';
export 'src/theme.dart';
export 'src/typography.dart';
