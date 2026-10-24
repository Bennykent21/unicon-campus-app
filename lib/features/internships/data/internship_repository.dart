import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/internship.dart';

/// All Supabase access for the internship board. Screens and providers go
/// through this class so queries live in one place.
class InternshipRepository {
  InternshipRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _view = 'internships_with_company';
  static const _apps = 'internship_applications';

  Future<List<Internship>> fetchAll() async {
    final rows = await _client
        .from(_view)
        .select()
        .eq('is_published', true)
        .order('deadline', ascending: true, nullsFirst: false)
        .limit(200);
    return (rows as List)
        .map((e) => Internship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Internship?> fetchOne(String id) async {
    final row = await _client.from(_view).select().eq('id', id).maybeSingle();
    return row == null ? null : Internship.fromJson(row);
  }

  Future<List<TrackedApplication>> fetchMyApplications() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];
    final rows = await _client
        .from(_apps)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];

    final ids = list.map((r) => r['internship_id'] as String).toList();
    final listings = await _client.from(_view).select().inFilter('id', ids);
    final byId = {
      for (final l in (listings as List))
        (l as Map<String, dynamic>)['id'] as String: Internship.fromJson(l),
    };
    return [
      for (final r in list)
        if (byId[r['internship_id']] != null)
          TrackedApplication.fromRow(r, byId[r['internship_id']]!),
    ];
  }

  /// Creates or updates the student's tracker row for [internshipId].
  /// Moving to "applied" stamps today's date and a follow-up a week later,
  /// unless they were already set.
  Future<void> setStage(String internshipId, ApplicationStage stage,
      {DateTime? interviewAt}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final today = DateTime.now();
    final data = <String, dynamic>{
      'user_id': userId,
      'internship_id': internshipId,
      'stage': stage.value,
    };
    if (stage == ApplicationStage.applied) {
      final existing = await _client
          .from(_apps)
          .select('applied_on, follow_up_on')
          .eq('user_id', userId)
          .eq('internship_id', internshipId)
          .maybeSingle();
      data['applied_on'] = existing?['applied_on'] ?? _isoDate(today);
      data['follow_up_on'] = existing?['follow_up_on'] ??
          _isoDate(today.add(const Duration(days: 7)));
    }
    if (interviewAt != null) {
      data['interview_at'] = interviewAt.toUtc().toIso8601String();
    }
    await _client.from(_apps).upsert(data, onConflict: 'user_id,internship_id');
  }

  /// Pushes the follow-up reminder back by [days] (after the student has
  /// followed up).
  Future<void> snoozeFollowUp(String internshipId, {int days = 7}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    await _client
        .from(_apps)
        .update({
          'follow_up_on': _isoDate(DateTime.now().add(Duration(days: days))),
        })
        .eq('user_id', userId)
        .eq('internship_id', internshipId);
  }

  Future<void> removeTracking(String internshipId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    await _client
        .from(_apps)
        .delete()
        .eq('user_id', userId)
        .eq('internship_id', internshipId);
  }

  /// UNIBEN students who said they trained at [companyId], newest first.
  Future<List<CompanyAlumnus>> fetchAlumni(String companyId) async {
    final rows = await _client
        .from('internship_alumni')
        .select(
            'user_id, year, profiles(full_name, department, level, avatar_url)')
        .eq('company_id', companyId)
        .order('year', ascending: false)
        .limit(20);
    return (rows as List)
        .map((e) => CompanyAlumnus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setTrainedHere(String companyId, bool trained,
      {int? year}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (trained) {
      await _client.from('internship_alumni').upsert({
        'company_id': companyId,
        'user_id': userId,
        'year': year ?? DateTime.now().year,
      }, onConflict: 'company_id,user_id');
    } else {
      await _client
          .from('internship_alumni')
          .delete()
          .eq('company_id', companyId)
          .eq('user_id', userId);
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class CompanyAlumnus {
  final String userId;
  final int year;
  final String name;
  final String? department;
  final String? level;
  final String? avatarUrl;

  const CompanyAlumnus({
    required this.userId,
    required this.year,
    required this.name,
    this.department,
    this.level,
    this.avatarUrl,
  });

  factory CompanyAlumnus.fromJson(Map<String, dynamic> json) {
    final p = json['profiles'] as Map<String, dynamic>? ?? const {};
    return CompanyAlumnus(
      userId: json['user_id'] as String,
      year: (json['year'] as num?)?.toInt() ?? 0,
      name: p['full_name'] as String? ?? 'Student',
      department: p['department'] as String?,
      level: p['level'] as String?,
      avatarUrl: p['avatar_url'] as String?,
    );
  }
}
