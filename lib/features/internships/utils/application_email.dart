import '../models/internship.dart';

/// A ready-to-edit application email.
class ApplicationEmail {
  final String to;
  final String subject;
  final String body;
  const ApplicationEmail(
      {required this.to, required this.subject, required this.body});

  /// `mailto:` URI. Uses %20 for spaces: many mail apps show `+` literally.
  Uri toMailtoUri() {
    String enc(String s) => Uri.encodeComponent(s);
    return Uri.parse('mailto:$to?subject=${enc(subject)}&body=${enc(body)}');
  }

  /// Builds the email from the listing and what we know about the student.
  /// Missing profile details are left as bracketed placeholders the student
  /// fills in, rather than guessed.
  factory ApplicationEmail.forListing(
    Internship i, {
    required String? studentName,
    required String? department,
    required String? level,
  }) {
    final name = _orPlaceholder(studentName, 'Your full name');
    final dept = _orPlaceholder(department, 'your department');
    final lvl = _orPlaceholder(level, 'your level');
    final greeting = i.contactName != null && i.contactName!.isNotEmpty
        ? 'Dear ${i.contactName},'
        : 'Dear Hiring Team,';

    final isSiwes = i.kind == InternshipKind.siwes;
    final subject = switch (i.kind) {
      InternshipKind.siwes =>
        'SIWES placement request: $name, $dept, University of Benin',
      InternshipKind.graduateTrainee => 'Application for ${i.title}: $name',
      _ => 'Application for ${i.title}: $name, University of Benin',
    };

    final ask = isSiwes
        ? 'I am writing to request a place on your industrial training (SIWES) programme'
        : 'I am writing to apply for the ${i.title} at ${i.companyName}';
    final duration = i.duration != null && i.duration!.isNotEmpty
        ? ' I am available for the full ${i.duration!.toLowerCase()}.'
        : '';

    final attachments = i.requirements.isNotEmpty
        ? 'I have attached the documents you ask for, including my CV.'
        : 'I have attached my CV.';

    final body = [
      greeting,
      '',
      'I am a $lvl $dept student at the University of Benin, Benin City. '
          '$ask.$duration',
      '',
      '$attachments I would be glad to provide anything else you need, and to attend an interview at your convenience.',
      '',
      'Thank you for considering my application.',
      '',
      'Yours faithfully,',
      name,
      '[Your phone number]',
    ].join('\n');

    return ApplicationEmail(
        to: i.applyEmail ?? '', subject: subject, body: body);
  }

  static String _orPlaceholder(String? v, String placeholder) =>
      v != null && v.trim().isNotEmpty ? v.trim() : '[$placeholder]';
}
