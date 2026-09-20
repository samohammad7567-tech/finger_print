import 'dart:async';

/// Serialises every connection to the terminal.
///
/// ZKTeco standalone units accept **one SDK session at a time**. Live capture
/// holds a session open indefinitely, so without this a manual sync, an
/// enrolment or a delete would find the device busy and fail — or worse, half
/// succeed. Device work goes through [run], which queues and suspends live
/// capture for the duration, then restarts it.
///
/// [acquire] is the same thing held open across several calls, for work that
/// cannot survive the session being closed between steps — fingerprint
/// enrolment being the case that forced it.
class ZkDeviceGate {
  /// No suspend or resume hook may hold the queue longer than this.
  static const _hookTimeout = Duration(seconds: 8);

  /// The tail of the queue. Each new operation chains onto it.
  Future<void> _queue = Future<void>.value();

  /// Installed by the live-capture source so the gate can stand it down.
  Future<void> Function()? onSuspend;
  Future<void> Function()? onResume;

  bool _busy = false;

  /// True while something holds the device.
  bool get isBusy => _busy;

  /// Takes the device until the returned lease is released.
  ///
  /// The caller **must** release it, or every later operation queues behind it
  /// forever. Prefer [run], which does that for you; use this only when the
  /// session has to outlive a single call.
  Future<ZkGateLease> acquire() {
    final ready = Completer<ZkGateLease>();
    final released = Completer<void>();

    _queue = _queue.then((_) async {
      _busy = true;
      var suspended = false;

      try {
        final suspend = onSuspend;
        if (suspend != null) {
          // Bounded on purpose. A hook that never returns would wedge the
          // queue and every later device operation with it, which is exactly
          // how a stuck live-capture session used to freeze enrolment.
          await suspend().timeout(_hookTimeout, onTimeout: () {});
          suspended = true;
        }
      } catch (_) {
        // A failed suspend must not stop the caller getting the device.
      }

      ready.complete(ZkGateLease._(released));
      await released.future;

      _busy = false;

      // Live capture is resumed even when the operation threw, otherwise one
      // failed sync would silently stop punches arriving until a restart.
      if (suspended) {
        final resume = onResume;
        if (resume != null) {
          try {
            await resume().timeout(_hookTimeout, onTimeout: () {});
          } catch (_) {
            // Nothing useful to do here; the next operation retries.
          }
        }
      }
    });

    return ready.future;
  }

  /// Runs [action] with sole access to the terminal.
  Future<T> run<T>(Future<T> Function() action) async {
    final lease = await acquire();
    try {
      return await action();
    } finally {
      lease.release();
    }
  }
}

/// A held claim on the terminal. Releasing it lets the queue move on.
class ZkGateLease {
  ZkGateLease._(this._done);

  final Completer<void> _done;
  bool _released = false;

  bool get isReleased => _released;

  void release() {
    if (_released) return;
    _released = true;
    _done.complete();
  }
}
