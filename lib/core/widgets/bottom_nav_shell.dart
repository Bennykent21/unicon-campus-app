import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../supabase/realtime_sync.dart';
import '../theme/app_colors.dart';
import '../../features/chats/providers/chats_provider.dart';
import '../../features/home/providers/home_provider.dart';

class BottomNavShell extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;

  const BottomNavShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell>
    with WidgetsBindingObserver {
  bool _navVisible = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Realtime (see realtimeSyncProvider) handles instant updates. This
    // 30s poll is a FALLBACK: realtime WebSockets can silently drop when
    // the app is backgrounded or the network blips, so polling guarantees
    // the chat list and notification badge eventually self-heal even if
    // the channel dies.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(chatsProvider);
      ref.invalidate(unreadNotificationsProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The realtime socket is usually dead after backgrounding — refresh
    // immediately on resume so the user never sees stale badges/lists.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(chatsProvider);
      ref.invalidate(unreadNotificationsProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta > 4  && _navVisible)  setState(() => _navVisible = false);
      if (delta < -4 && !_navVisible) setState(() => _navVisible = true);
    }
    if (n is ScrollEndNotification && n.metrics.pixels <= 0 && !_navVisible) {
      setState(() => _navVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Activates the app-wide realtime channel (messages + notifications).
    // Watching it here keeps the subscription alive for the whole session,
    // since BottomNavShell wraps every main screen.
    ref.watch(realtimeSyncProvider);

    final unreadChats = ref.watch(unreadChatsCountProvider);

    final tabs = [
      (path: '/home',     icon: Icons.home_outlined,      activeIcon: Icons.home,        label: 'Home',    badge: 0),
      (path: '/chats',    icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chats',   badge: unreadChats),
      (path: '/discover', icon: Icons.explore_outlined,    activeIcon: Icons.explore,     label: 'Discover',badge: 0),
      (path: '/profile',  icon: Icons.person_outline,      activeIcon: Icons.person,      label: 'Profile', badge: 0),
    ];

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) { _onScroll(n); return false; },
        child: widget.child,
      ),
      floatingActionButton: AnimatedScale(
        scale: _navVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: FloatingActionButton(
          onPressed: () => context.push('/create'),
          elevation: 2,
          child: const Icon(Icons.add, size: 26),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: _navVisible
            ? BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 6,
                padding: EdgeInsets.zero,
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ..._buildTab(context, tabs, 0),
                    ..._buildTab(context, tabs, 1),
                    const SizedBox(width: 48),
                    ..._buildTab(context, tabs, 2),
                    ..._buildTab(context, tabs, 3),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  List<Widget> _buildTab(
    BuildContext context,
    List<({String path, IconData icon, IconData activeIcon, String label, int badge})> tabs,
    int i,
  ) {
    final tab      = tabs[i];
    final selected = widget.currentIndex == i;
    return [
      Expanded(
        child: InkWell(
          onTap: () => context.go(tab.path),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? tab.activeIcon : tab.icon,
                    size: 20,
                    color: selected ? AppColors.primary : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  if (tab.badge > 0)
                    Positioned(
                      right: -6, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.event, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          tab.badge > 9 ? '9+' : '${tab.badge}',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
