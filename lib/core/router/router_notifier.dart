import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(sessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final bool loggedIn =
        _ref.read(sessionProvider).userName.isNotEmpty;
    final bool onLogin = state.matchedLocation == '/login';

    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/dashboard';
    return null;
  }
}
