import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zkteco/flutter_zkteco.dart';
// ignore: implementation_imports
import 'package:flutter_zkteco/src/util.dart';

void main() {
  test('probe fingerprints', () async {
    final device = ZKTeco(
      '192.168.1.203',
      debug: true,
      timeout: const Duration(seconds: 5),
      password: '0',
    );
    final connected = await device.connect();
    // ignore: avoid_print
    print('CONNECTED: $connected');
    if (!connected) return;

    try {
      final sizes = await Util.readSizes(device);
      // ignore: avoid_print
      print('SIZES users=${sizes?.users} fingers=${sizes?.fingers} records=${sizes?.records}');

      for (var uid = 0; uid <= 5; uid++) {
        for (var finger = 0; finger < 10; finger++) {
          final Map<String, dynamic> response;
          try {
            response = await device
                .command(
                  Util.CMD_USER_TEMP_RRQ,
                  commandString: Uint8List.fromList([
                    uid & 0xFF,
                    uid >> 8,
                    finger,
                  ]),
                )
                .timeout(const Duration(seconds: 3));
          } catch (e) {
            // ignore: avoid_print
            print('uid=$uid finger=$finger THREW $e');
            continue;
          }

          final raw = Uint8List.fromList(device.data);
          final kind = device.header.isEmpty ? 0 : device.header[0];
          final size = raw.length >= 4
              ? ByteData.sublistView(raw, 0, 4).getUint32(0, Endian.little)
              : -1;
          // ignore: avoid_print
          print(
            'uid=$uid finger=$finger status=${response['status']} code=${response['code']} '
            'kind=$kind raw=${raw.length} declared=$size head=${raw.take(12).toList()}',
          );

          try {
            final free = await device
                .command(Util.CMD_FREE_DATA)
                .timeout(const Duration(seconds: 2));
            // ignore: avoid_print
            print('  free=${free['status']}/${free['code']}');
          } catch (e) {
            // ignore: avoid_print
            print('  free THREW $e');
          }
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
