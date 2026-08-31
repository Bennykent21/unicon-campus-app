import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_service.dart';

enum CreateStatus { idle, loading, success, error }

class CreateState {
  final CreateStatus status;
  final String? errorMessage;
  const CreateState({this.status = CreateStatus.idle, this.errorMessage});
}

class CreatePostNotifier extends StateNotifier<CreateState> {
  CreatePostNotifier() : super(const CreateState());

  Future<String?> submit({
    required String type,
    required String title,
    required String body,
    required List<String> tags,
    List<File> images = const [],
    double? price,
    String? jobLocation,
    bool? isInternship,
    String? salary,
    DateTime? eventDate,
    String? eventLocation,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    state = const CreateState(status: CreateStatus.loading);
    try {
      final imageUrls = <String>[];
      for (final file in images) {
        final ext = file.path.split('.').last.toLowerCase();
        final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

        await SupabaseService.client.storage
            .from(AppConstants.postImagesBucket)
            .upload(path, file);

        final url = SupabaseService.client.storage
            .from(AppConstants.postImagesBucket)
            .getPublicUrl(path);

        imageUrls.add(url);
      }

      final response = await SupabaseService.client
          .from('posts')
          .insert({
            'author_id': userId,
            'type': type,
            'title': title.trim(),
            'body': body.trim(),
            'tags': tags,
            'image_urls': imageUrls,
            if (price != null) 'price': price,
            if (jobLocation != null) 'job_location': jobLocation,
            if (isInternship != null) 'is_internship': isInternship,
            if (salary != null && salary.isNotEmpty) 'salary': salary,
            if (eventDate != null) 'event_date': eventDate.toIso8601String(),
            if (eventLocation != null) 'event_location': eventLocation,
          })
          .select('id')
          .single();

      state = const CreateState(status: CreateStatus.success);
      return response['id'] as String;
    } catch (e) {
      state = CreateState(
        status: CreateStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void reset() => state = const CreateState();
}

final createPostProvider =
    StateNotifierProvider.autoDispose<CreatePostNotifier, CreateState>(
        (ref) => CreatePostNotifier());
