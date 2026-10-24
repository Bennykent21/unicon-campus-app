import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../supabase/supabase_service.dart';
import '../widgets/bottom_nav_shell.dart';
import 'go_router_refresh_stream.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/post_detail_screen.dart';
import '../../features/home/screens/feed_search_screen.dart';
import '../../features/chats/screens/chats_screen.dart';
import '../../features/chats/screens/chat_thread_screen.dart';
import '../../features/chats/screens/new_message_screen.dart';
import '../../features/create/screens/create_screen.dart';
import '../../features/create/screens/post_composer_screen.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/discover/screens/discover_category_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/profile/screens/my_posts_screen.dart';
import '../../features/profile/screens/user_profile_screen.dart';
import '../../features/profile/screens/follow_list_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/internships/screens/internships_screen.dart';
import '../../features/internships/screens/internship_detail_screen.dart';
import '../../features/internships/screens/applications_screen.dart';

/// Cache for the profile-completeness check so the redirect callback does
/// NOT hit the database on every single navigation.
///
/// Once a user's profile is known to be complete it can only become
/// incomplete via account deletion, so caching `true` per user id is safe.
/// Call [invalidateProfileCompleteCache] after profile setup/edit saves.
String? _profileCompleteForUserId;

/// Invalidate the cached profile-completeness result (e.g. after the user
/// saves their profile in ProfileSetupScreen, or on sign-out).
void invalidateProfileCompleteCache() {
  _profileCompleteForUserId = null;
}

final appRouter = GoRouter(
  initialLocation: '/home',
  refreshListenable: GoRouterRefreshStream(SupabaseService.authStateChanges),
  redirect: (context, state) async {
    final loggedIn = SupabaseService.isLoggedIn;
    final location = state.matchedLocation;
    final isAuth = location == '/login' || location == '/signup';

    if (!loggedIn && !isAuth) return '/login';
    if (loggedIn && isAuth) return '/home';

    if (loggedIn && location != '/profile-setup') {
      final userId = SupabaseService.currentUserId!;

      // Cached "complete" for this user — skip the DB round-trip entirely.
      if (_profileCompleteForUserId == userId) return null;

      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name, username')
          .eq('id', userId)
          .maybeSingle();
      final incomplete = profile == null ||
          (profile['full_name'] as String?)?.isEmpty != false ||
          (profile['username'] as String?)?.isEmpty != false;
      if (incomplete) return '/profile-setup';

      // Profile is complete — remember it for subsequent navigations.
      _profileCompleteForUserId = userId;
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
    GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(isFirstTime: true)),

    GoRoute(
      path: '/create',
      pageBuilder: (_, __) =>
          const MaterialPage(fullscreenDialog: true, child: CreateScreen()),
    ),
    GoRoute(
      path: '/compose/:type',
      pageBuilder: (_, state) {
        final type = state.pathParameters['type'] ?? 'general';
        return MaterialPage(
            fullscreenDialog: true, child: PostComposerScreen(postType: type));
      },
    ),
    GoRoute(
      path: '/profile-edit',
      pageBuilder: (_, __) => const MaterialPage(
          fullscreenDialog: true,
          child: ProfileSetupScreen(isFirstTime: false)),
    ),
    GoRoute(
      path: '/post/:id',
      builder: (_, state) =>
          PostDetailScreen(postId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/feed-search',
      builder: (_, __) => const FeedSearchScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/my-posts',
      builder: (_, state) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
        return MyPostsScreen(initialTab: tab);
      },
    ),
    GoRoute(
      path: '/user/:id',
      builder: (_, state) =>
          UserProfileScreen(userId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/followers/:id',
      builder: (_, state) => FollowListScreen(
          userId: state.pathParameters['id']!, type: FollowListType.followers),
    ),
    GoRoute(
      path: '/following/:id',
      builder: (_, state) => FollowListScreen(
          userId: state.pathParameters['id']!, type: FollowListType.following),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (_, state) =>
          ChatThreadScreen(conversationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/new-message',
      builder: (_, __) => const NewMessageScreen(),
    ),
    GoRoute(
      path: '/internships',
      builder: (_, __) => const InternshipsScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              InternshipDetailScreen(internshipId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/applications',
      builder: (_, __) => const ApplicationsScreen(),
    ),
    GoRoute(
      path: '/discover/:category',
      builder: (_, state) => DiscoverCategoryScreen(
          categoryKey: state.pathParameters['category']!),
    ),

    // Main shell — 4 tabs: Home(0) Chats(1) Discover(2) Profile(3)
    ShellRoute(
      builder: (context, state, child) {
        final index = switch (state.matchedLocation) {
          '/home' => 0,
          '/chats' => 1,
          '/discover' => 2,
          '/profile' => 3,
          _ => 0,
        };
        return BottomNavShell(currentIndex: index, child: child);
      },
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/chats', builder: (_, __) => const ChatsScreen()),
        GoRoute(path: '/discover', builder: (_, __) => const DiscoverScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
  ],
);
