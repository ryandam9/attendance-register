/// The interface fonts a user can choose in Appearance. All are bundled, so
/// they work offline. Most use one family throughout; Fraunces pairs serif
/// headings with DM Sans text.
enum AppFont {
  figtree('Figtree', 'Friendly and clear', 'Figtree', 'Figtree'),
  dmSans('DM Sans', 'Soft and calm', 'DM Sans', 'DM Sans'),
  manrope('Manrope', 'Crisp and modern', 'Manrope', 'Manrope'),
  plusJakartaSans(
    'Plus Jakarta Sans',
    'Polished and open',
    'Plus Jakarta Sans',
    'Plus Jakarta Sans',
  ),
  nunito('Nunito', 'Rounded and gentle', 'Nunito', 'Nunito'),
  fraunces('Fraunces & DM Sans', 'Soft serif headings', 'Fraunces', 'DM Sans');

  const AppFont(this.label, this.description, this.headingFamily, this.body);

  final String label;
  final String description;
  final String headingFamily;

  /// Family for body text, controls and numbers.
  final String body;

  static const fallback = AppFont.figtree;

  static AppFont fromName(String? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => fallback);
}

/// Each bundled family's licence file stem, for the licence registry.
const bundledFontFiles = <String, String>{
  'Figtree': 'Figtree',
  'DM Sans': 'DMSans',
  'Manrope': 'Manrope',
  'Plus Jakarta Sans': 'PlusJakartaSans',
  'Nunito': 'Nunito',
  'Fraunces': 'Fraunces',
};
