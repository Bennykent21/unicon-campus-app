import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../profile/models/profile_model.dart';

final _userSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final _userSearchResultsProvider =
    FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  final query = ref.watch(_userSearchQueryProvider).trim();
  final myId  = SupabaseService.currentUserId;
  if (query.isEmpty || myId == null) return [];

  final data = await SupabaseService.client
      .from('profiles_with_counts')
      .select()
      .or('full_name.ilike.%$query%,username.ilike.%$query%')
      .neq('id', myId)
      .limit(20);

  return (data as List).map((e) => ProfileModel.fromJson(e)).toList();
});

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool  _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Finds an existing 1:1 DM with [otherUserId], or creates a new one.
  Future<void> _startChat(String otherUserId) async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      final myId = SupabaseService.currentUserId;
      if (myId == null) return;

      final myConvos = await SupabaseService.client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', myId);
      final myConvoIds =
          (myConvos as List).map((e) => e['conversation_id'] as String).toList();

      String? existingId;
      if (myConvoIds.isNotEmpty) {
        final theirConvos = await SupabaseService.client
            .from('conversation_participants')
            .select('conversation_id')
            .eq('user_id', otherUserId)
            .inFilter('conversation_id', myConvoIds);
        if ((theirConvos as List).isNotEmpty) {
          for (final row in theirConvos) {
            final convoId = row['conversation_id'] as String;
            final convo = await SupabaseService.client
                .from('conversations')
                .select('kind')
                .eq('id', convoId)
                .maybeSingle();
            if (convo != null && convo['kind'] == 'dm') {
              existingId = convoId;
              break;
            }
          }
        }
      }

      String conversationId;
      if (existingId != null) {
        conversationId = existingId;
      } else {
        // Generate the ID client-side instead of chaining .select().single()
        // after insert. Chaining .select() makes Postgres try to hand the new
        // row back (INSERT ... RETURNING), which requires it to pass the
        // SELECT policy too — but no participants exist yet at that instant,
        // so the SELECT policy fails and Postgres reports it as an RLS
        // violation on the INSERT, even though the INSERT policy is fine.
        conversationId = const Uuid().v4();
        await SupabaseService.client.from('conversations').insert({
          'id': conversationId,
          'kind': 'dm',
        });
        // Insert one at a time — the 2nd row's RLS check needs the 1st committed.
        await SupabaseService.client.from('conversation_participants')
            .insert({'conversation_id': conversationId, 'user_id': myId});
        await SupabaseService.client.from('conversation_participants')
            .insert({'conversation_id': conversationId, 'user_id': otherUserId});
      }

      if (mounted) {
        context.pushReplacement('/chat/$conversationId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_userSearchResultsProvider);
    final query    = ref.watch(_userSearchQueryProvider);
    final theme    = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message', style: TextStyle(fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            decoration: InputDecoration(
              hintText: 'Search by name or username...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        ref.read(_userSearchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
            ),
            onChanged: (v) => ref.read(_userSearchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? Center(
                  child: Text('Search for someone to message',
                      style: theme.textTheme.bodySmall),
                )
              : results.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error:   (e, _) => Center(child: Text('Error: $e')),
                  data:    (users) {
                    if (users.isEmpty) {
                      return Center(
                        child: Text('No users found for "$query"',
                            style: theme.textTheme.bodySmall),
                      );
                    }
                    return ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: theme.dividerTheme.color),
                      itemBuilder: (context, i) {
                        final user = users[i];
                        return ListTile(
                          enabled: !_starting,
                          onTap: () => _startChat(user.id),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!) : null,
                            child: user.avatarUrl == null
                                ? Text(
                                    user.fullName.isNotEmpty ? user.fullName[0] : '?',
                                    style: const TextStyle(
                                        color: AppColors.primary, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(user.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(
                            user.username.isNotEmpty
                                ? '@${user.username}${user.departmentLevel.isNotEmpty ? " · ${user.departmentLevel}" : ""}'
                                : user.departmentLevel,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: _starting
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                        );
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}