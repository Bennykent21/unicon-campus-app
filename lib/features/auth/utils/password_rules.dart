/// Password rules, matching the project's Supabase Auth settings
/// (Authentication → Sign In / Providers → Email): at least 8 characters,
/// with a lowercase letter, an uppercase letter, a digit and a symbol.
/// Change both together, or students get past this check and are then
/// rejected by the server.
const kPasswordMinLength = 8;

/// Symbols Supabase Auth counts towards the symbol requirement.
const _symbols = r'''!@#$%^&*()_+-=[]{};'\:"|<>?,./`~''';

const kPasswordRuleText =
    'Use at least $kPasswordMinLength characters, with upper and lowercase letters, a number and a symbol.';

/// Returns what [password] is missing, or null if it meets every rule.
String? passwordProblem(String password) {
  final missing = <String>[
    if (!password.contains(RegExp('[a-z]'))) 'a lowercase letter',
    if (!password.contains(RegExp('[A-Z]'))) 'an uppercase letter',
    if (!password.contains(RegExp('[0-9]'))) 'a number',
    if (!password.split('').any(_symbols.contains)) 'a symbol such as ! or #',
  ];
  final short = password.length < kPasswordMinLength;
  if (!short && missing.isEmpty) return null;

  final parts = [
    if (short) 'at least $kPasswordMinLength characters',
    ...missing,
  ];
  final list = parts.length == 1
      ? parts.first
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  return 'Needs $list';
}
