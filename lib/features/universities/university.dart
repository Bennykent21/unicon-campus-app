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
