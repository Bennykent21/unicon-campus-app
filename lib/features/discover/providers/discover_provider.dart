import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../home/models/post_model.dart';

/// Sort order for category listings.
enum DiscoverSort { newest, mostHelpful }

final discoverSortProvider =
    StateProvider.autoDispose<DiscoverSort>((ref) => DiscoverSort.newest);

/// Fetches posts for a Discover category.
///
/// [postType] filters by the posts.type column directly (marketplace/job/event).
/// [tag] instead filters by tag overlap, for categories that aren't a distinct
/// post type (e.g. Scholarships — those are just posts tagged "Scholarships").
/// Exactly one of [postType] or [tag] should be provided.
final discoverCategoryPostsProvider = FutureProvider.autoDispose
    .family<List<PostModel>, ({String? postType, String? tag})>(
        (ref, params) async {
  final sort = ref.watch(discoverSortProvider);
  var query = SupabaseService.client.from('posts_with_engagement').select();

  if (params.postType != null) {
    query = query.eq('type', params.postType!);
  } else if (params.tag != null) {
    query = query.contains('tags', [params.tag]);
  }

  final ordered = sort == DiscoverSort.mostHelpful
      ? query.order('helpful_count', ascending: false)
      : query.order('created_at', ascending: false);

  final data = await ordered.limit(50);
  return (data as List).map((e) => PostModel.fromJson(e)).toList();
});
