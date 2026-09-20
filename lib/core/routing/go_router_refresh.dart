import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Bloc/Cubit stream into the [Listenable] GoRouter wants for
/// `refreshListenable`, so a sign-in or sign-out re-runs the redirect.
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
