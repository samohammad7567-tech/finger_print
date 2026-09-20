import 'dart:async';

import 'package:flutter/material.dart';
import '../style/theme/context_extension.dart';

/// Transient messages, shown through the app's [Overlay].
///
/// Replaces `fluttertoast`, which has no Windows implementation and threw
/// `MissingPluginException` on every call in the desktop build. An overlay is
/// used rather than a SnackBar because the login screen sits outside any
/// [Scaffold], so `ScaffoldMessenger.of` would have the same problem in a
/// different disguise.
enum AppToastKind { info, success, error }

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    // No overlay means no Navigator yet; dropping the message is better than
    // taking down the frame for something purely informational.
    if (overlay == null || message.trim().isEmpty) return;

    _dismiss();

    final entry = OverlayEntry(
      builder: (_) => _ToastView(message: message, kind: kind),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, _dismiss);
  }

  static void success(BuildContext context, String message) =>
      show(context, message, kind: AppToastKind.success);

  static void error(BuildContext context, String message) => show(
    context,
    message,
    kind: AppToastKind.error,
    // Errors are worth reading twice.
    duration: const Duration(seconds: 4),
  );

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.kind});

  final String message;
  final AppToastKind kind;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _background => switch (widget.kind) {
    AppToastKind.success => context.color.success,
    AppToastKind.error => context.color.destructive,
    AppToastKind.info => context.color.muted,
  };

  IconData get _icon => switch (widget.kind) {
    AppToastKind.success => Icons.check_circle_outline,
    AppToastKind.error => Icons.error_outline,
    AppToastKind.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 40,
      child: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              ),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.effects.scrim,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icon,
                      size: 18,
                      color: context.color.primaryForeground,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.color.primaryForeground,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
