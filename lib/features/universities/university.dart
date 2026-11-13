import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/supabase_service.dart';

/// A university students can belong to. Each one sees only its own posts.
class University {
  final int id;
  final String name;
  final String shortName;
  final String? city;

  const University({
    required this.id,
    required this.name,
    required this.shortName,
    this.city,
  });

  factory University.fromJson(Map<String, dynamic> json) => University(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        shortName: json['short_name'] as String,
        city: json['city'] as String?,
      );

  /// True when [query] matches the name, the short name or the city.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        shortName.toLowerCase().contains(q) ||
        (city?.toLowerCase().contains(q) ?? false);
  }
}

/// Every university, A to Z. Readable before signing in, for the signup form.
final universitiesProvider = FutureProvider<List<University>>((ref) async {
  final rows = await SupabaseService.client
      .from('universities')
      .select('id, name, short_name, city')
      .order('name');
  return [for (final r in rows) University.fromJson(r)];
});

/// True when the signed-in student is a curator (manages listings and
/// universities). Curators are added in Supabase, in the curators table.
final isCuratorProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (SupabaseService.currentUserId == null) return false;
  final r = await SupabaseService.client.rpc('is_curator');
  return r == true;
});

/// A student's request to add a university that isn't listed.
class UniversityRequest {
  final int id;
  final String name;
  final String? city;
  final String? email;
  final DateTime createdAt;

  const UniversityRequest({
    required this.id,
    required this.name,
    this.city,
    this.email,
    required this.createdAt,
  });

  factory UniversityRequest.fromJson(Map<String, dynamic> json) =>
      UniversityRequest(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        city: json['city'] as String?,
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Pending requests, oldest first, for curators.
final pendingUniversityRequestsProvider =
    FutureProvider.autoDispose<List<UniversityRequest>>((ref) async {
  final rows = await SupabaseService.client
      .from('university_requests')
      .select('id, name, city, email, created_at')
      .eq('status', 'pending')
      .order('created_at');
  return [for (final r in rows) UniversityRequest.fromJson(r)];
});

/// Writes for university requests and the university list.
class UniversityActions {
  const UniversityActions();

  /// Anyone can ask, signed in or not (signup happens before an account).
  Future<void> request({required String name, String? city, String? email}) {
    return SupabaseService.client.from('university_requests').insert({
      'name': name.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (SupabaseService.currentUserId != null)
        'requested_by': SupabaseService.currentUserId,
    });
  }

  /// Curators only. Returns the new university's id.
  Future<int> add(
      {required String name, required String shortName, String? city}) async {
    final row = await SupabaseService.client
        .from('universities')
        .insert({
          'slug': slugFor(shortName),
          'name': name.trim(),
          'short_name': shortName.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        })
        .select('id')
        .single();
    return (row['id'] as num).toInt();
  }

  /// Curators only: marks a request added (linked to [universityId]) or declined.
  Future<void> review(int requestId, {int? universityId}) {
    return SupabaseService.client.from('university_requests').update({
      'status': universityId == null ? 'declined' : 'added',
      'university_id': universityId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }
}

final universityActionsProvider =
    Provider<UniversityActions>((ref) => const UniversityActions());

/// URL-safe id from a short name: "FUT Minna" -> "fut-minna".
String slugFor(String shortName) => shortName
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
