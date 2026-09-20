@Tags(['probe'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';

/// Manual diagnostic against the real terminal — not part of the normal suite.
///
/// `flutter_zkteco` reports a failed handshake as a bare `false` and only
/// prints the underlying cause when `debug: true`, so this walks the plausible
/// combinations and shows what each one actually does.
///
///   flutter test test/device_connection_probe.dart --tags probe
const _ip = String.fromEnvironment('ZK_IP', defaultValue: '192.168.1.201');
const _port = int.fromEnvironment('ZK_PORT', defaultValue: 4370);
const _commKey = String.fromEnvironment('ZK_KEY', defaultValue: '');

void main() {
  test('probe the terminal', () async {
    stdout.writeln(
      '\n=== target $_ip:$_port  key="${_commKey.isEmpty ? '(none)' : _commKey}" ===',
    );

    // Raw socket first: proves reachability independently of the library.
    try {
      final socket = await Socket.connect(
        _ip,
        _port,
        timeout: const Duration(seconds: 5),
      );
      stdout.writeln(
        '[raw tcp] connected from ${socket.address.address}:${socket.port}',
      );
      await socket.close();
      socket.destroy();
    } catch (e) {
      stdout.writeln('[raw tcp] FAILED: $e');
    }

    for (final attempt in _attempts) {
      stdout.writeln('\n--- ${attempt.label} ---');
      final device = ZKTeco(
        _ip,
        port: _port,
        tcp: attempt.tcp,
        timeout: const Duration(seconds: 8),
        password: attempt.key.isEmpty ? null : attempt.key,
        debug: true,
      );

      try {
        final ok = await device
            .connect(ommitPing: attempt.skipPing)
            .timeout(const Duration(seconds: 20));
        stdout.writeln('connect() -> $ok');

        if (ok) {
          stdout.writeln(
            '  name     : ${await _try(() => device.getDeviceName())}',
          );
          stdout.writeln(
            '  serial   : ${await _try(() => device.serialNumber())}',
          );
          stdout.writeln('  firmware : ${await _try(() => device.version())}');
          stdout.writeln('  time     : ${await _try(() => device.getTime())}');
          stdout.writeln(
            '  users    : ${await _try(() async => (await device.getUsers()).length)}',
          );
          stdout.writeln(
            '  punches  : ${await _try(() async => (await device.getAttendanceLogs()).length)}',
          );
        }
      } catch (e, s) {
        stdout.writeln('THREW: $e');
        stdout.writeln(s.toString().split('\n').take(4).join('\n'));
      } finally {
        try {
          await device.disconnect();
        } catch (_) {}
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

typedef _Attempt = ({String label, bool tcp, bool skipPing, String key});

const List<_Attempt> _attempts = [
  (label: 'TCP, ping check on,  no key', tcp: true, skipPing: false, key: ''),
  (label: 'TCP, ping skipped,   no key', tcp: true, skipPing: true, key: ''),
  (label: 'UDP, ping skipped,   no key', tcp: false, skipPing: true, key: ''),
  (label: 'TCP, ping skipped,   key=0', tcp: true, skipPing: true, key: '0'),
];

Future<Object?> _try(Future<Object?> Function() action) async {
  try {
    return await action().timeout(const Duration(seconds: 15));
  } catch (e) {
    return 'ERR: $e';
  }
}
