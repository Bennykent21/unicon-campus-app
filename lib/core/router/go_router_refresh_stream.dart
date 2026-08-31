import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges a Stream (e.g. Supabase's onAuthStateChange) into a Listenable
/// that go_router's `refreshListenable` can use, so the router automatically
/// re-evaluates `redirect` whenever auth state changes — no manual
/// navigation needed after login/logout.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
