import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/features/profile/models/profile_model.dart';
import 'package:university_community_app/features/universities/university.dart';

void main() {
  const uniben = University(
      id: 24,
      name: 'University of Benin',
      shortName: 'UNIBEN',
      city: 'Benin City');

  test('search matches name, short name and city, ignoring case', () {
    expect(uniben.matches('benin'), isTrue);
    expect(uniben.matches('uniben'), isTrue);
    expect(uniben.matches('Benin City'), isTrue);
    expect(uniben.matches('  '), isTrue);
    expect(uniben.matches('lagos'), isFalse);
  });

  test('parses a row from the universities table', () {
    final u = University.fromJson({
      'id': 3,
      'name': 'University of Lagos',
      'short_name': 'UNILAG',
      'city': null
    });
    expect(u.id, 3);
    expect(u.shortName, 'UNILAG');
    expect(u.city, isNull);
  });

  test('profile reads university_id, and a missing one stays null', () {
    final withUni = ProfileModel.fromJson(
        {'id': 'a', 'university': 'University of Benin', 'university_id': 24});
    expect(withUni.universityId, 24);
    expect(withUni.university, 'University of Benin');
    expect(ProfileModel.fromJson({'id': 'b'}).universityId, isNull);
  });
}
