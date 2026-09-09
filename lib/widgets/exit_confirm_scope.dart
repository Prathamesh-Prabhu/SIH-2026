import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a *root* screen (one with nothing beneath it in the stack) so a
/// single back press does not drop straight out of the app.
///
/// Only use this at the root of a role's console. Screens that were pushed
/// must stay freely poppable — intercepting back there would trap the user.
class ExitConfirmScope extends StatefulWidget {
  const ExitConfirmScope({super.key, required this.child});

  final Widget child;

  @override
  State<ExitConfirmScope> createState() => _ExitConfirmScopeState();
}

class _ExitConfirmScopeState extends State<ExitConfirmScope> {
  DateTime? _lastBackPress;

  static const _window = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final now = DateTime.now();
        final recent = _lastBackPress != null &&
            now.difference(_lastBackPress!) < _window;

        if (recent) {
          SystemNavigator.pop();
          return;
        }

        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit ManoFit'),
              duration: _window,
            ),
          );
      },
      child: widget.child,
    );
  }
}
