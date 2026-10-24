/// Maps a student's free-text department (e.g. "CPE", "Computer Engineering",
/// "Mass Comm") to the broad fields used on internship listings
/// (`internships.fields`).
///
/// Listings use broad fields rather than exact department names because
/// companies describe eligibility broadly ("engineering students") and
/// students type their department in many different ways.
class FieldMatcher {
  FieldMatcher._();

  static const engineering = 'engineering';
  static const computing = 'computing';
  static const science = 'science';
  static const business = 'business';
  static const socialScience = 'social_science';
  static const arts = 'arts';
  static const agriculture = 'agriculture';
  static const health = 'health';
  static const law = 'law';
  static const education = 'education';

  static const labels = {
    engineering: 'Engineering',
    computing: 'Computing',
    science: 'Sciences',
    business: 'Business',
    socialScience: 'Social sciences',
    arts: 'Arts and media',
    agriculture: 'Agriculture',
    health: 'Health',
    law: 'Law',
    education: 'Education',
  };

  /// Keyword (lowercase, matched as a whole word or prefix) -> fields.
  /// UNIBEN department abbreviations are included alongside full names.
  static const _rules = <String, List<String>>{
    // Engineering
    'cpe': [engineering, computing],
    'computer engineering': [engineering, computing],
    'eee': [engineering],
    'electrical': [engineering],
    'electronic': [engineering],
    'mee': [engineering],
    'mechanical': [engineering],
    'cve': [engineering],
    'civil': [engineering],
    'structural': [engineering],
    'pet': [engineering, science],
    'petroleum': [engineering, science],
    'che': [engineering, science],
    'chemical engineering': [engineering, science],
    'pre': [engineering],
    'production engineering': [engineering],
    'industrial': [engineering],
    'mme': [engineering],
    'materials': [engineering],
    'metallurg': [engineering],
    'marine engineering': [engineering],
    'mechatronic': [engineering, computing],
    'agricultural engineering': [engineering, agriculture],
    'engineering': [engineering],
    // Computing
    'csc': [computing, science],
    'computer science': [computing, science],
    'software': [computing],
    'information technology': [computing],
    'cybersecurity': [computing],
    'data science': [computing, science],
    // Sciences
    'physics': [science],
    'chemistry': [science],
    'biochemistry': [science, health],
    'microbiology': [science, health],
    'mathematics': [science, computing],
    'statistics': [science, computing],
    'geology': [science],
    'geophysics': [science],
    'botany': [science],
    'zoology': [science],
    'plant biology': [science],
    'animal': [science, agriculture],
    'environmental': [science],
    'science': [science],
    // Health
    'medicine': [health],
    'mbbs': [health],
    'nursing': [health],
    'pharmacy': [health, science],
    'medical laboratory': [health, science],
    'mls': [health, science],
    'physiotherapy': [health],
    'radiography': [health],
    'dentistry': [health],
    'anatomy': [health, science],
    'physiology': [health, science],
    'optometry': [health],
    // Agriculture
    'agric': [agriculture],
    'agronomy': [agriculture],
    'soil': [agriculture, science],
    'fisheries': [agriculture],
    'forestry': [agriculture],
    // Business
    'accounting': [business],
    'acc': [business],
    'banking': [business],
    'finance': [business],
    'business': [business],
    'bus admin': [business],
    'marketing': [business],
    'insurance': [business],
    'actuarial': [business, science],
    'entrepreneurship': [business],
    // Social sciences
    'economics': [socialScience, business],
    'eco': [socialScience, business],
    'political': [socialScience],
    'sociology': [socialScience],
    'psychology': [socialScience, health],
    'geography': [socialScience, science],
    'social work': [socialScience],
    'mass comm': [arts, socialScience],
    'mass communication': [arts, socialScience],
    'journalism': [arts, socialScience],
    // Arts
    'english': [arts],
    'linguistics': [arts],
    'history': [arts],
    'philosophy': [arts],
    'theatre': [arts],
    'fine art': [arts],
    'fine and applied': [arts],
    'music': [arts],
    'religion': [arts],
    'french': [arts],
    'architecture': [engineering, arts],
    // Law and education
    'law': [law],
    'llb': [law],
    'education': [education],
  };

  /// Returns the broad fields for [department]; empty if unknown.
  static Set<String> fieldsFor(String? department) {
    if (department == null || department.trim().isEmpty) return {};
    final d =
        ' ${department.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ')} ';
    final result = <String>{};
    for (final entry in _rules.entries) {
      // Whole word / phrase at a word boundary, so "eco" doesn't hit "geology"
      // and "acc" matches "acc" but not "access".
      if (d.contains(' ${entry.key} ') ||
          (entry.key.length > 4 && d.contains(' ${entry.key}'))) {
        result.addAll(entry.value);
      }
    }
    return result;
  }

  /// Whether a listing open to [listingFields] fits a student in
  /// [department]. An empty listing list means "any field". An unknown
  /// department matches everything, so students are never hidden from
  /// listings just because we couldn't read their department.
  static bool matchesDepartment(
      List<String> listingFields, String? department) {
    if (listingFields.isEmpty) return true;
    final mine = fieldsFor(department);
    if (mine.isEmpty) return true;
    return listingFields.any(mine.contains);
  }

  /// Whether [listingLevels] (e.g. ['300L','400L']) includes [level].
  /// Empty or unknown means a match.
  static bool matchesLevel(List<String> listingLevels, String? level) {
    if (listingLevels.isEmpty || level == null || level.isEmpty) return true;
    return listingLevels.contains(level);
  }
}
