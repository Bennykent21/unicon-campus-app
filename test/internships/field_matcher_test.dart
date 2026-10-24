import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/features/internships/utils/field_matcher.dart';

void main() {
  group('FieldMatcher.fieldsFor', () {
    test('reads UNIBEN abbreviations and full names', () {
      expect(FieldMatcher.fieldsFor('CPE'), {'engineering', 'computing'});
      expect(FieldMatcher.fieldsFor('Computer Engineering'),
          containsAll(['engineering', 'computing']));
      expect(FieldMatcher.fieldsFor('Mass Comm'), contains('arts'));
      expect(FieldMatcher.fieldsFor('Accounting'), {'business'});
      expect(FieldMatcher.fieldsFor('Medical Laboratory Science'),
          containsAll(['health', 'science']));
    });

    test('does not match short keys inside longer words', () {
      // "eco" must not fire for geology; "acc" must not fire for "access".
      expect(FieldMatcher.fieldsFor('Geology'), {'science'});
      expect(FieldMatcher.fieldsFor('Access studies'), isEmpty);
    });

    test('unknown or empty department gives no fields', () {
      expect(FieldMatcher.fieldsFor(null), isEmpty);
      expect(FieldMatcher.fieldsFor('   '), isEmpty);
      expect(FieldMatcher.fieldsFor('Underwater basket weaving'), isEmpty);
    });
  });

  group('matching', () {
    test('empty listing fields means open to everyone', () {
      expect(FieldMatcher.matchesDepartment([], 'Law'), isTrue);
    });

    test('unknown department is never hidden from listings', () {
      expect(FieldMatcher.matchesDepartment(['engineering'], null), isTrue);
      expect(FieldMatcher.matchesDepartment(['engineering'], 'Xyz'), isTrue);
    });

    test('known department must overlap', () {
      expect(FieldMatcher.matchesDepartment(['engineering'], 'EEE'), isTrue);
      expect(
          FieldMatcher.matchesDepartment(['engineering'], 'English'), isFalse);
    });

    test('levels', () {
      expect(FieldMatcher.matchesLevel([], '200L'), isTrue);
      expect(FieldMatcher.matchesLevel(['300L', '400L'], '400L'), isTrue);
      expect(FieldMatcher.matchesLevel(['300L', '400L'], '100L'), isFalse);
      expect(FieldMatcher.matchesLevel(['300L'], null), isTrue);
    });
  });
}
