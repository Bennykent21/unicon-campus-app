import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/features/internships/models/internship.dart';
import 'package:university_community_app/features/internships/utils/application_email.dart';

void main() {
  const siwes = Internship(
    id: '1',
    companyId: 'c',
    companyName: 'Azura-Edo Independent Power Plant',
    title: 'Engineering industrial training',
    kind: InternshipKind.siwes,
    duration: '6 months',
    requirements: ['CV'],
    applyEmail: 'hr@example.com',
  );

  test('SIWES email uses the student profile', () {
    final e = ApplicationEmail.forListing(siwes,
        studentName: 'Oghosa Benedict',
        department: 'Computer Engineering',
        level: '400L');
    expect(e.to, 'hr@example.com');
    expect(e.subject,
        'SIWES placement request: Oghosa Benedict, Computer Engineering, University of Benin');
    expect(
        e.body,
        contains(
            'I am a 400L Computer Engineering student at the University of Benin'));
    expect(e.body, contains('industrial training (SIWES)'));
    expect(e.body, contains('available for the full 6 months'));
    expect(e.body, contains('Dear Hiring Team,'));
  });

  test('missing profile details become placeholders, not guesses', () {
    final e = ApplicationEmail.forListing(siwes,
        studentName: null, department: '', level: null);
    expect(e.subject, contains('[Your full name]'));
    expect(e.body, contains('[your level] [your department]'));
  });

  test('mailto encodes spaces as %20 and keeps line breaks', () {
    const e = ApplicationEmail(
        to: 'a@b.com', subject: 'Hi there', body: 'Line 1\nLine 2');
    final uri = e.toMailtoUri().toString();
    expect(
        uri,
        startsWith(
            'mailto:a@b.com?subject=Hi%20there&body=Line%201%0ALine%202'));
    expect(uri, isNot(contains('+')));
  });

  test('graduate trainee subject names the programme', () {
    const grad = Internship(
        id: '2',
        companyId: 'c',
        companyName: 'MTN',
        title: 'Global Graduate Programme',
        kind: InternshipKind.graduateTrainee);
    final e = ApplicationEmail.forListing(grad,
        studentName: 'Ada', department: 'EEE', level: '500L');
    expect(e.subject, 'Application for Global Graduate Programme: Ada');
  });
}
