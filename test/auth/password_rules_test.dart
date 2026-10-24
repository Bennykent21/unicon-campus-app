import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/features/auth/providers/auth_provider.dart';
import 'package:university_community_app/features/auth/utils/password_rules.dart';

void main() {
  test('accepts a password that meets every rule', () {
    expect(passwordProblem('Uniben#2026'), isNull);
    expect(passwordProblem('aB3~xxxx'), isNull);
  });

  test('names the one thing missing', () {
    expect(passwordProblem('uniben#2026'), 'Needs an uppercase letter');
    expect(passwordProblem('UNIBEN#2026'), 'Needs a lowercase letter');
    expect(passwordProblem('Uniben#abcd'), 'Needs a number');
    expect(passwordProblem('Uniben2026'), 'Needs a symbol such as ! or #');
    expect(passwordProblem('Ub#2'), 'Needs at least 8 characters');
  });

  test('lists several missing things in one sentence', () {
    expect(passwordProblem('abc'),
        'Needs at least 8 characters, an uppercase letter, a number and a symbol such as ! or #');
    expect(passwordProblem(''),
        'Needs at least 8 characters, a lowercase letter, an uppercase letter, a number and a symbol such as ! or #');
  });

  test('only counts the symbols Supabase counts', () {
    expect(passwordProblem('Uniben2026£'), 'Needs a symbol such as ! or #');
    expect(passwordProblem(r'Uniben2026\'), isNull);
    expect(passwordProblem('Uniben2026"'), isNull);
  });

  test('server weak-password errors explain the rules', () {
    expect(
        friendlyAuthError(
            Exception('Password should be at least 8 characters.')),
        kPasswordRuleText);
    expect(
        friendlyAuthError(Exception(
            'Password should contain at least one character of each: abc')),
        kPasswordRuleText);
  });
}
