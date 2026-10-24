import 'package:intl/intl.dart';

/// What kind of opening a listing is. Stored as `internships.kind`.
enum InternshipKind {
  siwes('siwes', 'SIWES / IT'),
  internship('internship', 'Internship'),
  graduateTrainee('graduate_trainee', 'Graduate trainee'),
  remoteProgram('remote_program', 'Remote programme'),
  training('training', 'Free training');

  final String value;
  final String label;
  const InternshipKind(this.value, this.label);

  static InternshipKind parse(String? v) => InternshipKind.values
      .firstWhere((k) => k.value == v, orElse: () => InternshipKind.internship);
}

/// Where a listing is in its hiring cycle. Stored as `internships.status`.
enum ListingStatus {
  open('open'),
  rolling('rolling'),
  contact('contact'),
  expected('expected'),
  closed('closed');

  final String value;
  const ListingStatus(this.value);

  static ListingStatus parse(String? v) => ListingStatus.values
      .firstWhere((s) => s.value == v, orElse: () => ListingStatus.open);
}

/// A student's progress on one listing. Stored as
/// `internship_applications.stage`; null means "not tracked".
enum ApplicationStage {
  saved('saved', 'Saved'),
  applied('applied', 'Applied'),
  interview('interview', 'Interview'),
  offer('offer', 'Offer'),
  declined('declined', 'Not this time');

  final String value;
  final String label;
  const ApplicationStage(this.value, this.label);

  static ApplicationStage? parse(String? v) {
    if (v == null) return null;
    for (final s in ApplicationStage.values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

/// How urgent the deadline label should look.
enum DeadlineTone { positive, warning, neutral }

class DeadlineLabel {
  final String text;
  final DeadlineTone tone;
  const DeadlineLabel(this.text, this.tone);
}

class Internship {
  final String id;
  final String companyId;
  final String companyName;
  final String? companyIndustry;
  final String? companyCity;
  final String? companyAddress;
  final String? companyWebsite;
  final String? companyLogoUrl;
  final String title;
  final InternshipKind kind;
  final String workMode; // onsite | hybrid | remote
  final String? location;
  final String summary;
  final String? duration;
  final String? stipend;
  final bool? isPaid;
  final List<String> fields;
  final List<String> levels;
  final List<String> requirements;
  final List<String> howToApply;
  final String? applyUrl;
  final String? applyEmail;
  final String? applyPhone;
  final String? contactName;
  final ListingStatus status;
  final String? opensNote;
  final DateTime? deadline;
  final String? unibenNote;
  final String? sourceUrl;
  final DateTime? lastChecked;
  final int alumniCount;
  final ApplicationStage? myStage;

  const Internship({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.companyIndustry,
    this.companyCity,
    this.companyAddress,
    this.companyWebsite,
    this.companyLogoUrl,
    required this.title,
    required this.kind,
    this.workMode = 'onsite',
    this.location,
    this.summary = '',
    this.duration,
    this.stipend,
    this.isPaid,
    this.fields = const [],
    this.levels = const [],
    this.requirements = const [],
    this.howToApply = const [],
    this.applyUrl,
    this.applyEmail,
    this.applyPhone,
    this.contactName,
    this.status = ListingStatus.open,
    this.opensNote,
    this.deadline,
    this.unibenNote,
    this.sourceUrl,
    this.lastChecked,
    this.alumniCount = 0,
    this.myStage,
  });

  static List<String> _strings(Object? v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String);

  /// Parses a row from the `internships_with_company` view.
  factory Internship.fromJson(Map<String, dynamic> json) => Internship(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        companyName: json['company_name'] as String? ?? 'Unknown company',
        companyIndustry: json['company_industry'] as String?,
        companyCity: json['company_city'] as String?,
        companyAddress: json['company_address'] as String?,
        companyWebsite: json['company_website'] as String?,
        companyLogoUrl: json['company_logo_url'] as String?,
        title: json['title'] as String? ?? '',
        kind: InternshipKind.parse(json['kind'] as String?),
        workMode: json['work_mode'] as String? ?? 'onsite',
        location: json['location'] as String?,
        summary: json['summary'] as String? ?? '',
        duration: json['duration'] as String?,
        stipend: json['stipend'] as String?,
        isPaid: json['is_paid'] as bool?,
        fields: _strings(json['fields']),
        levels: _strings(json['levels']),
        requirements: _strings(json['requirements']),
        howToApply: _strings(json['how_to_apply']),
        applyUrl: json['apply_url'] as String?,
        applyEmail: json['apply_email'] as String?,
        applyPhone: json['apply_phone'] as String?,
        contactName: json['contact_name'] as String?,
        status: ListingStatus.parse(json['status'] as String?),
        opensNote: json['opens_note'] as String?,
        deadline: _date(json['deadline']),
        unibenNote: json['uniben_note'] as String?,
        sourceUrl: json['source_url'] as String?,
        lastChecked: _date(json['last_checked']),
        alumniCount: (json['alumni_count'] as num?)?.toInt() ?? 0,
        myStage: ApplicationStage.parse(json['my_stage'] as String?),
      );

  Internship copyWith({ApplicationStage? myStage, bool clearStage = false}) =>
      Internship(
        id: id,
        companyId: companyId,
        companyName: companyName,
        companyIndustry: companyIndustry,
        companyCity: companyCity,
        companyAddress: companyAddress,
        companyWebsite: companyWebsite,
        companyLogoUrl: companyLogoUrl,
        title: title,
        kind: kind,
        workMode: workMode,
        location: location,
        summary: summary,
        duration: duration,
        stipend: stipend,
        isPaid: isPaid,
        fields: fields,
        levels: levels,
        requirements: requirements,
        howToApply: howToApply,
        applyUrl: applyUrl,
        applyEmail: applyEmail,
        applyPhone: applyPhone,
        contactName: contactName,
        status: status,
        opensNote: opensNote,
        deadline: deadline,
        unibenNote: unibenNote,
        sourceUrl: sourceUrl,
        lastChecked: lastChecked,
        alumniCount: alumniCount,
        myStage: clearStage ? null : (myStage ?? this.myStage),
      );

  String get workModeLabel => switch (workMode) {
        'remote' => 'Remote',
        'hybrid' => 'Hybrid',
        _ => 'On-site',
      };

  /// Two-letter initials for the logo tile ("Shell Nigeria" -> "SN").
  String get initials {
    final words = companyName
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .split(RegExp(r'[\s-]+'))
        .where((w) => w.isNotEmpty && w[0].toUpperCase() != w[0].toLowerCase())
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// True when the listing can be applied to right now.
  bool isActionableOn(DateTime today) {
    final d = _day(today);
    return switch (status) {
      ListingStatus.open => deadline == null || !_day(deadline!).isBefore(d),
      ListingStatus.rolling || ListingStatus.contact => true,
      ListingStatus.expected || ListingStatus.closed => false,
    };
  }

  /// Short label for the listing's timing, relative to [today].
  DeadlineLabel deadlineLabel(DateTime today) {
    final d = _day(today);
    switch (status) {
      case ListingStatus.rolling:
        return const DeadlineLabel('Apply any time', DeadlineTone.positive);
      case ListingStatus.contact:
        return const DeadlineLabel('Write to apply', DeadlineTone.positive);
      case ListingStatus.expected:
        return const DeadlineLabel('Opens again later', DeadlineTone.neutral);
      case ListingStatus.closed:
        return const DeadlineLabel('Closed', DeadlineTone.neutral);
      case ListingStatus.open:
        if (deadline == null) {
          return const DeadlineLabel('Open now', DeadlineTone.positive);
        }
        final days = _day(deadline!).difference(d).inDays;
        return switch (days) {
          < 0 => const DeadlineLabel('Closed', DeadlineTone.neutral),
          0 => const DeadlineLabel('Closes today', DeadlineTone.warning),
          1 => const DeadlineLabel('Closes tomorrow', DeadlineTone.warning),
          <= 7 => DeadlineLabel('Closes in $days days', DeadlineTone.warning),
          _ => DeadlineLabel('Closes ${DateFormat('d MMM').format(deadline!)}',
              DeadlineTone.positive),
        };
    }
  }

  /// Sort key: actionable listings first, soonest deadline first.
  int sortRank(DateTime today) => switch (status) {
        ListingStatus.open when isActionableOn(today) => 0,
        ListingStatus.rolling || ListingStatus.contact => 1,
        ListingStatus.expected => 2,
        _ => 3,
      };

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// A row from the student's private tracker, joined with its listing.
class TrackedApplication {
  final Internship internship;
  final ApplicationStage stage;
  final DateTime? appliedOn;
  final DateTime? followUpOn;
  final DateTime? interviewAt;
  final String? notes;

  const TrackedApplication({
    required this.internship,
    required this.stage,
    this.appliedOn,
    this.followUpOn,
    this.interviewAt,
    this.notes,
  });

  /// Builds a tracker row from an `internship_applications` row and its
  /// already-fetched listing.
  factory TrackedApplication.fromRow(
          Map<String, dynamic> row, Internship listing) =>
      TrackedApplication(
        internship: listing,
        stage: ApplicationStage.parse(row['stage'] as String?) ??
            ApplicationStage.saved,
        appliedOn: Internship._date(row['applied_on']),
        followUpOn: Internship._date(row['follow_up_on']),
        interviewAt: Internship._date(row['interview_at'])?.toLocal(),
        notes: row['notes'] as String?,
      );

  /// True when the student said they would follow up and that day has come.
  bool needsFollowUp(DateTime today) =>
      stage == ApplicationStage.applied &&
      followUpOn != null &&
      !Internship._day(followUpOn!).isAfter(Internship._day(today));
}
