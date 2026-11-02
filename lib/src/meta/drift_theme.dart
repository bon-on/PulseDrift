/// Cosmetic road palettes and ship skins, unlocked by pilot level.
/// Themes never change rules.
enum DriftTheme {
  neon(requiredLevel: 1, label: 'Neon', shipName: 'Arrow'),
  sunset(requiredLevel: 3, label: 'Sunset', shipName: 'Comet'),
  aurora(requiredLevel: 6, label: 'Aurora', shipName: 'Glider'),
  voidline(requiredLevel: 10, label: 'Void', shipName: 'Phantom');

  const DriftTheme({
    required this.requiredLevel,
    required this.label,
    required this.shipName,
  });

  /// Pilot level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  /// Name of the ship skin that comes with the theme.
  final String shipName;

  /// Parses a stored theme name; unknown values fall back to [neon].
  static DriftTheme fromName(String? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return neon;
  }
}
