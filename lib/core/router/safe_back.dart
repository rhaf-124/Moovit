import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back handling for pages that can be entered with a *replacing* navigation.
///
/// [FcmService.navigate] and the deep-link handler both use `context.go()`,
/// which replaces the whole route stack. A page opened that way has nothing
/// beneath it, so `context.pop()` pops the last route and the app exits —
/// which is what happened when tapping back after opening a booking or a
/// tracking screen from a notification.
///
/// Both the AppBar button and the system back gesture must be handled: the
/// AppBar calls [popOrGo], and [SafeBackScope] covers the gesture.
extension SafeBack on BuildContext {
  /// Pops if there is a route underneath, otherwise navigates to [fallback].
  void popOrGo(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}

/// Wraps a page so the system back gesture falls back to [fallback] instead of
/// leaving the app when the stack is empty.
class SafeBackScope extends StatelessWidget {
  const SafeBackScope({
    super.key,
    required this.fallback,
    required this.child,
  });

  /// Route to go to when there is nothing to pop.
  final String fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // When there is something to pop, let the framework do it normally.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(fallback);
      },
      child: child,
    );
  }
}
