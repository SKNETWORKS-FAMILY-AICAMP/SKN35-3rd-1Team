import 'package:flutter/material.dart';
import '../state.dart';

class AccountGuard extends StatefulWidget {
  const AccountGuard({super.key, required this.state, required this.child});
  final ArtlogState state;
  final Widget child;
  @override
  State<AccountGuard> createState() => _AccountGuardState();
}

class _AccountGuardState extends State<AccountGuard> {
  late final String identity;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    identity = widget.state.userKey;
    widget.state.addListener(check);
  }

  void check() {
    if (!mounted ||
        closing ||
        (widget.state.authenticated && widget.state.userKey == identity)) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null) return;
      final navigator = Navigator.of(context);
      if (route.isCurrent) {
        navigator.pop();
      } else {
        // A discard/confirmation dialog may cover this account's form.
        navigator.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
