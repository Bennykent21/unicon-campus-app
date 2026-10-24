import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/features/internships/models/internship.dart';
import 'package:university_community_app/features/internships/providers/internship_providers.dart';

Map<String, dynamic> row({
  String id = 'i1',
  String company = 'Benin Electricity Distribution Company (BEDC)',
  String title = 'Industrial training (SIWES)',
  String kind = 'siwes',
  String status = 'open',
  String? deadline,
  List<String> fields = const [],
  List<String> levels = const [],
  String workMode = 'onsite',
  bool? isPaid,
  String? location,
}) =>
    {
      'id': id,
      'company_id': 'c-$id',
      'company_name': company,
      'title': title,
      'kind': kind,
      'status': status,
      'deadline': deadline,
      'fields': fields,
      'levels': levels,
      'work_mode': workMode,
      'is_paid': isPaid,
      'location': location,
      'requirements': ['CV'],
      'how_to_apply': ['Write a letter'],
      'alumni_count': 2,
      'my_stage': 'applied',
      'last_checked': '2026-10-24',
    };

void main() {
  final today = DateTime(2026, 10, 24, 15, 30);

  test('fromJson reads the view row', () {
    final i = Internship.fromJson(row(deadline: '2026-11-15'));
    expect(i.kind, InternshipKind.siwes);
    expect(i.status, ListingStatus.open);
    expect(i.deadline, DateTime(2026, 11, 15));
    expect(i.alumniCount, 2);
    expect(i.myStage, ApplicationStage.applied);
    expect(i.requirements, ['CV']);
    expect(i.lastChecked, DateTime(2026, 10, 24));
  });

  test('unknown enum values fall back safely', () {
    final i = Internship.fromJson(row(kind: 'mystery', status: 'weird'));
    expect(i.kind, InternshipKind.internship);
    expect(i.status, ListingStatus.open);
  });

  test('initials ignore bracketed abbreviations', () {
    expect(Internship.fromJson(row()).initials, 'BE');
    expect(Internship.fromJson(row(company: 'Kuda')).initials, 'KU');
    expect(Internship.fromJson(row(company: 'Shell Nigeria')).initials, 'SN');
  });

  group('deadlineLabel', () {
    DeadlineLabel label(String status, [String? deadline]) =>
        Internship.fromJson(row(status: status, deadline: deadline))
            .deadlineLabel(today);

    test('far deadline is positive with a date', () {
      final l = label('open', '2026-11-15');
      expect(l.text, 'Closes 15 Nov');
      expect(l.tone, DeadlineTone.positive);
    });

    test('within a week is a warning', () {
      expect(label('open', '2026-10-27').text, 'Closes in 3 days');
      expect(label('open', '2026-10-27').tone, DeadlineTone.warning);
      expect(label('open', '2026-10-25').text, 'Closes tomorrow');
      expect(label('open', '2026-10-24').text, 'Closes today');
    });

    test('past deadline reads closed', () {
      expect(label('open', '2026-10-01').text, 'Closed');
    });

    test('other statuses', () {
      expect(label('rolling').text, 'Apply any time');
      expect(label('contact').text, 'Write to apply');
      expect(label('expected').tone, DeadlineTone.neutral);
      expect(label('open').text, 'Open now');
    });
  });

  test('isActionableOn', () {
    expect(
        Internship.fromJson(row(status: 'open', deadline: '2026-10-24'))
            .isActionableOn(today),
        isTrue);
    expect(
        Internship.fromJson(row(status: 'open', deadline: '2026-10-23'))
            .isActionableOn(today),
        isFalse);
    expect(Internship.fromJson(row(status: 'expected')).isActionableOn(today),
        isFalse);
    expect(Internship.fromJson(row(status: 'contact')).isActionableOn(today),
        isTrue);
  });

  group('applyInternshipFilter', () {
    final listings = [
      Internship.fromJson(row(id: 'expected', status: 'expected')),
      Internship.fromJson(row(
          id: 'late',
          status: 'open',
          deadline: '2026-12-01',
          fields: ['business'])),
      Internship.fromJson(row(
          id: 'soon',
          status: 'open',
          deadline: '2026-10-30',
          fields: ['engineering'],
          levels: ['300L', '400L'])),
      Internship.fromJson(row(
          id: 'remote',
          company: 'Outreachy',
          status: 'rolling',
          workMode: 'remote',
          isPaid: true,
          location: 'Remote')),
      Internship.fromJson(row(
          id: 'edo',
          status: 'contact',
          location: 'Akpakpava Street, Benin City')),
    ];

    List<String> ids(InternshipFilter f, {String? dept, String? level}) =>
        applyInternshipFilter(listings, f,
                department: dept, level: level, today: today)
            .map((i) => i.id)
            .toList();

    test('sorts open-now by deadline, then rolling/contact, then expected', () {
      expect(ids(const InternshipFilter(matchesOnly: false)),
          ['soon', 'late', 'edo', 'remote', 'expected']);
    });

    test('matches a CPE 400L student', () {
      expect(ids(const InternshipFilter(), dept: 'CPE', level: '400L'),
          ['soon', 'edo', 'remote', 'expected']);
    });

    test('level outside the listing range is excluded', () {
      expect(ids(const InternshipFilter(), dept: 'CPE', level: '100L'),
          isNot(contains('soon')));
    });

    test('quick filters', () {
      expect(ids(const InternshipFilter(matchesOnly: false, remoteOnly: true)),
          ['remote']);
      expect(ids(const InternshipFilter(matchesOnly: false, paidOnly: true)),
          ['remote']);
      expect(ids(const InternshipFilter(matchesOnly: false, edoOnly: true)),
          ['edo']);
      expect(ids(const InternshipFilter(matchesOnly: false, openNowOnly: true)),
          isNot(contains('expected')));
      expect(ids(const InternshipFilter(matchesOnly: false, query: 'benin')),
          contains('edo'));
    });
  });

  test('TrackedApplication.needsFollowUp', () {
    final listing = Internship.fromJson(row());
    final due = TrackedApplication.fromRow(
        {'stage': 'applied', 'follow_up_on': '2026-10-24'}, listing);
    final later = TrackedApplication.fromRow(
        {'stage': 'applied', 'follow_up_on': '2026-10-31'}, listing);
    final interview = TrackedApplication.fromRow(
        {'stage': 'interview', 'follow_up_on': '2026-10-01'}, listing);
    expect(due.needsFollowUp(today), isTrue);
    expect(later.needsFollowUp(today), isFalse);
    expect(interview.needsFollowUp(today), isFalse);
  });
}
